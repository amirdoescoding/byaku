import AppKit
import CoreImage
import simd
import Vision

// Guided face scan (docs/designs/face-scan.md; prototype design/scan/prototype.html, ported 1:1). A low-poly face mask
// follows the user's head while they look straight, then left, then right. The camera shows only at the start: alone,
// then under the mask as it fades on, until the sweep wipes it away. Nothing from the camera is stored.

typealias Scn = Tokens.Scan

/// One camera frame for the scan, made on the camera queue. Angles in degrees: + = the user's own left, chin up,
/// counter-clockwise in the camera image. Points: one per Vision landmark point in ScanGeometry.regions order, image px, top-left.
struct ScanFrame {
    var faces: Int, yaw = 0.0, pitch = 0.0, roll = 0.0
    var points: [CGPoint]? = nil, size = CGSize.zero

    /// Vision's yaw/roll signs match ours (measured: nose offset and eye-line angle on the parity faces, 2026-11-27).
    /// ponytail: pitch sign unmeasured (stills had no nods); flip here if the mask nods the wrong way.
    static let pitchSign = 1.0

    init(faces: Int, landmarks lm: VNFaceObservation?, size: CGSize, rect: VNFaceObservation?) {
        self.faces = faces
        let pose = lm ?? rect
        let deg = { (n: NSNumber?) in (n?.doubleValue ?? 0) * 180 / .pi }
        yaw = deg(pose?.yaw); pitch = Self.pitchSign * deg(pose?.pitch); roll = deg(pose?.roll)
        points = lm.flatMap { ScanGeometry.points($0, size: size) }
        self.size = size
    }
}

// MARK: - geometry (canonical face → mask on screen)

enum ScanGeometry {
    static let regions = ["faceContour", "leftEye", "rightEye", "leftEyebrow", "rightEyebrow", "nose", "noseCrest", "medianLine",
                          "outerLips", "innerLips", "leftPupil", "rightPupil"]
    static let V: [SIMD3<Double>] = stride(from: 0, to: ScanMesh.xyz.count, by: 3).map {
        SIMD3(Double(ScanMesh.xyz[$0]), Double(ScanMesh.xyz[$0 + 1]), Double(ScanMesh.xyz[$0 + 2]))
    }
    static let T: [[Int]] = stride(from: 0, to: ScanMesh.tri.count, by: 3).map { Array(ScanMesh.tri[$0..<$0 + 3]) }
    /// Mesh vertex of each Vision point; the distinct vertices; each point's slot among them.
    static let refs: [Int] = regions.flatMap { ScanMesh.vision[$0]! }
    static let contour: [Bool] = regions.flatMap { r in ScanMesh.vision[r]!.map { _ in r == "faceContour" } }
    static let mapped: [Int] = Array(Set(refs)).sorted()
    static let slot: [Int] = refs.map { mapped.firstIndex(of: $0)! }
    static let vnorm: [SIMD3<Double>] = {
        var n = [SIMD3<Double>](repeating: .zero, count: V.count)
        for t in T { let c = cross(V[t[1]] - V[t[0]], V[t[2]] - V[t[0]]); for k in t { n[k] += c } }
        return n.map { normalize($0) }
    }()
    /// Pull kernel: a vertex on a Vision point takes that point's residual (expressions); others blend nearby residuals
    /// (Gaussian over canonical distance) with a "stay" weight, so far vertices move less.
    static let kernel: [[(Int, Double)]] = V.indices.map { k in
        if let own = mapped.firstIndex(of: k) { return [(own, 1)] }
        let s2 = 2 * Scn.sigma * Scn.sigma, stay = exp(-2.25)
        let w = mapped.enumerated().map { ($0.offset, exp(-length_squared(V[k] - V[$0.element]) / s2)) }.filter { $0.1 > 0.01 }
        let sum = w.reduce(stay) { $0 + $1.1 }
        return w.map { ($0.0, $0.1 / sum) }
    }
    /// Fill regions (0 straight, 1 left, 2 right) and each triangle's 0…1 rank inside its region, inner edge first.
    static let (region, order): ([Int], [Double]) = {
        func nz(_ t: [Int], _ yaw: Double) -> Double {
            let R = rot(yaw: yaw, pitch: 0, roll: 0), c = cross(R * V[t[1]] - R * V[t[0]], R * V[t[2]] - R * V[t[0]])
            return c.z / length(c)
        }
        let region = T.map { t -> Int in
            let g0 = nz(t, 0), gl = nz(t, Scn.regionYaw) - g0, gr = nz(t, -Scn.regionYaw) - g0
            return gl > Scn.regionMargin && gl >= gr ? 1 : gr > Scn.regionMargin ? 2 : 0
        }
        let cx = T.map { t in abs(t.reduce(0) { $0 + V[$1].x } / 3) }
        var order = [Double](repeating: 0, count: T.count)
        for r in 0...2 {
            let ids = T.indices.filter { region[$0] == r }.sorted { cx[$0] < cx[$1] }
            for (k, t) in ids.enumerated() { order[t] = Double(k + 1) / Double(ids.count) }
        }
        return (region, order)
    }()

    /// R = Ry(yaw) · Rx(pitch) · Rz(roll), degrees. Camera space: x image-right, y up, z toward the camera.
    static func rot(yaw: Double, pitch: Double, roll: Double) -> simd_double3x3 {
        let (y, p, r) = (yaw * .pi / 180, pitch * .pi / 180, roll * .pi / 180)
        let Ry = simd_double3x3(rows: [[cos(y), 0, sin(y)], [0, 1, 0], [-sin(y), 0, cos(y)]])
        let Rx = simd_double3x3(rows: [[1, 0, 0], [0, cos(p), sin(p)], [0, -sin(p), cos(p)]])
        let Rz = simd_double3x3(rows: [[cos(r), -sin(r), 0], [sin(r), cos(r), 0], [0, 0, 1]])
        return Ry * Rx * Rz
    }

    /// Vision landmarks → one point per mesh reference, image px, top-left origin. Nil if a region's count differs.
    static func points(_ lm: VNFaceObservation, size: CGSize) -> [CGPoint]? {
        guard let m = lm.landmarks else { return nil }
        var out: [CGPoint] = []
        for r in regions {
            let reg: VNFaceLandmarkRegion2D? = switch r {
            case "faceContour": m.faceContour
            case "leftEye": m.leftEye
            case "rightEye": m.rightEye
            case "leftEyebrow": m.leftEyebrow
            case "rightEyebrow": m.rightEyebrow
            case "nose": m.nose
            case "noseCrest": m.noseCrest
            case "medianLine": m.medianLine
            case "outerLips": m.outerLips
            case "innerLips": m.innerLips
            case "leftPupil": m.leftPupil
            default: m.rightPupil
            }
            guard let reg, reg.pointCount == ScanMesh.vision[r]!.count else { return nil }
            out += reg.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: size.height - $0.y) }
        }
        return out
    }

    /// The posed mask: q = vertices in cm (x image-right, y down, unmirrored), nz = each triangle's facing, and the
    /// image mapping (img = s·q + t) so the camera layer lines up with it.
    struct Fit { var q: [CGPoint], nz: [Double], s: Double, tx: Double, ty: Double, centre: CGPoint }

    /// Rotate the canonical mesh, fit scale + offset to the visible points (weighted least squares), pull vertices onto them.
    static func fit(_ R: simd_double3x3, _ pts: [CGPoint], _ size: CGSize) -> Fit? {
        let P = V.map { R * $0 }
        let nz = T.map { t -> Double in let c = cross(P[t[1]] - P[t[0]], P[t[2]] - P[t[0]]); return c.z / max(length(c), 1e-9) }
        let vis = refs.indices.map { i in pow(max(0, (R * vnorm[refs[i]]).z), 2) * (contour[i] ? 0.6 : 1) }
        var sw = 0.0, mx = 0.0, my = 0.0, ox = 0.0, oy = 0.0
        for (i, v) in refs.enumerated() {
            let w = vis[i]; sw += w; mx += w * P[v].x; my -= w * P[v].y; ox += w * pts[i].x; oy += w * pts[i].y
        }
        guard sw > 0 else { return nil }
        mx /= sw; my /= sw; ox /= sw; oy /= sw
        var num = 0.0, den = 0.0
        for (i, v) in refs.enumerated() {
            let w = vis[i], ax = P[v].x - mx, ay = -P[v].y - my
            num += w * (ax * (pts[i].x - ox) + ay * (pts[i].y - oy)); den += w * (ax * ax + ay * ay)
        }
        guard den > 0, num > 0 else { return nil }
        let s = num / den, tx = ox - s * mx, ty = oy - s * my
        var res = [SIMD3<Double>](repeating: .zero, count: mapped.count)  // residual per vertex in cm, visibility-weighted
        for (i, v) in refs.enumerated() {
            let w = vis[i]
            res[slot[i]] += SIMD3(w * (pts[i].x - (s * P[v].x + tx)) / s, w * (pts[i].y - (-s * P[v].y + ty)) / s, w)
        }
        res = res.map { $0.z > 0 ? SIMD3($0.x / $0.z, $0.y / $0.z, 1) : .zero }
        let q = P.indices.map { k -> CGPoint in
            var d = SIMD2<Double>.zero
            for (j, w) in kernel[k] { d += w * SIMD2(res[j].x, res[j].y) }
            return CGPoint(x: P[k].x + Scn.pull * d.x, y: -P[k].y + Scn.pull * d.y)
        }
        let W = Double(size.width), H = Double(size.height)
        return Fit(q: q, nz: nz, s: s, tx: tx, ty: ty, centre: CGPoint(x: (tx - W / 2) / W, y: (ty - H / 2) / H))
    }
}

/// One-Euro filter (Casiez et al.): smooth at rest, little lag when moving fast.
struct OneEuro {
    private var x: Double?, dx = 0.0
    mutating func callAsFunction(_ v: Double, _ dt: Double) -> Double {
        guard let px = x else { x = v; return v }
        func a(_ c: Double) -> Double { 1 / (1 + 1 / (2 * .pi * c * dt)) }
        dx += a(1) * ((v - px) / dt - dx)
        let nx = px + a(Scn.minCutoff + Scn.beta * abs(dx)) * (v - px)
        x = nx
        return nx
    }
}

/// Critically-ish damped spring for values the view drives per tick (the collapse, the camera's lock-on). Same ODE as CASpringAnimation.
private struct Spring1 {
    var x = 0.0, v = 0.0, t = 0.0
    let s: Onb.Spring
    mutating func step(_ dt: Double) {
        let n = Int((dt * 240).rounded(.up)), h = dt / Double(max(n, 1))
        for _ in 0..<max(n, 1) { v += (-Double(s.stiffness) * (x - t) - Double(s.damping) * v) * h; x += v * h }
    }
}

// MARK: - ScanView

/// The whole scan UI except the buttons (the host's): mascot, camera, mask, title and body. Used by the onboarding
/// window (480 pt wide) and the Set up face panel (360 pt, `compact`). Feed it frames on main; it reports done / fail.
final class ScanView: NSView {
    enum Phase { case starting, find, mask, sweep, scan, done, failed }

    var onDone: () -> Void = {}, onFail: (EnrollPanel.Phase) -> Void = { _ in }
    /// The camera beat is over (after the sweep, or a stop): the host stops sending images.
    var onCameraDone: () -> Void = {}
    private(set) var phase = Phase.starting

    private let compact: Bool
    let mascot = MascotView(side: 56)
    private let titleLabel = NSTextField(labelWithString: ""), bodyLabel = NSTextField(wrappingLabelWithString: "")
    private let stage = CALayer()  // top-left coordinates, like the prototype's canvas
    private let videoRoot = CALayer(), videoWipe = CALayer(), videoEdge = CAGradientLayer()
    private let camera = CALayer()  // the camera beat: frames drawn as plain contents (no preview layer on the session)
    private var hasImage = false
    private let meshRoot = CALayer(), sweepLine = CAShapeLayer()
    private let wire = CAShapeLayer(), wireDim = CAShapeLayer(), wireSeen = CAShapeLayer(), fillSeen = CAShapeLayer()
    private let wireCap = CAShapeLayer(), fillCap = CAShapeLayer()

    private var pose = ScanPose(), filt = (yaw: OneEuro(), pitch: OneEuro(), roll: OneEuro())
    private var ptsFilt: [(OneEuro, OneEuro)] = []
    private var tracked: ScanGeometry.Fit?, lostAt: Double?
    private var seen: [Bool] = [], captured: [Bool] = []
    private var findFor = 0.0, faceSince: Double?, videoAt: Double?, maskAt = 0.0, sweepAt = 0.0
    private var collapse: (at: Double, u: Spring1)?, vmap = [Spring1(s: Scn.lockOn), Spring1(s: Scn.lockOn), Spring1(s: Scn.lockOn)]
    private var timer: Timer?, jobs: [(at: Double, f: () -> Void)] = [], lastTick = 0.0
    private var shown = ""
    private var lastSize: CGSize?  // camera frame px, from the last frame with landmarks (the camera layer shows the whole frame)

    private var reduced: Bool { Tokens.Motion.reduced }
    private var now: Double { CACurrentMediaTime() }
    private var area: (x: CGFloat, y: CGFloat, h: CGFloat) {
        compact ? (bounds.width / 2, 158, 136) : (bounds.width / 2, 166, 148)
    }

    init(frame: NSRect, compact: Bool) {
        self.compact = compact
        super.init(frame: frame)
        wantsLayer = true
        stage.frame = bounds; stage.isGeometryFlipped = true
        layer!.addSublayer(stage)
        videoRoot.frame = bounds; videoRoot.opacity = 0
        videoWipe.masksToBounds = true; videoWipe.addSublayer(videoEdge)
        let mask = CALayer(); mask.frame = bounds; mask.addSublayer(videoWipe); videoRoot.mask = mask
        videoEdge.type = .radial; videoEdge.startPoint = CGPoint(x: 0.5, y: 0.5); videoEdge.endPoint = CGPoint(x: 1, y: 1)
        videoEdge.colors = [NSColor.black.cgColor, NSColor.clear.cgColor]; videoEdge.locations = [0.45, 1]
        camera.contentsGravity = .resize
        camera.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        videoRoot.addSublayer(camera)
        meshRoot.frame = bounds
        for l in [wireDim, wire, fillSeen, wireSeen, fillCap, wireCap, sweepLine] {
            l.frame = bounds; l.lineWidth = 0.75; l.lineJoin = .round; l.fillColor = nil; meshRoot.addSublayer(l)
        }
        sweepLine.lineWidth = Scn.sweepLine
        [videoRoot, meshRoot].forEach(stage.addSublayer)
        let h = bounds.height
        mascot.frame = NSRect(x: (bounds.width - 56) / 2, y: h - 22 - 56, width: 56, height: 56)
        titleLabel.font = .systemFont(ofSize: compact ? 13 : 17, weight: .semibold); titleLabel.alignment = .center
        bodyLabel.font = .systemFont(ofSize: compact ? 12 : 13); bodyLabel.alignment = .center; bodyLabel.maximumNumberOfLines = 2
        let top: CGFloat = compact ? 238 : 252
        titleLabel.frame = NSRect(x: 24, y: h - top - 22, width: bounds.width - 48, height: 22)
        bodyLabel.frame = NSRect(x: 24, y: h - top - 26 - 34, width: bounds.width - 48, height: 34)
        [mascot, titleLabel, bodyLabel].forEach(addSubview)
        recolor()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        titleLabel.textColor = Tokens.ink; bodyLabel.textColor = Tokens.mute
        let ink = { (a: CGFloat) in cg(Tokens.ink.withAlphaComponent(a), in: self) }
        let acc = { (a: CGFloat) in cg(Tokens.accent.withAlphaComponent(a), in: self) }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        wire.strokeColor = ink(Scn.lineAlpha); wireDim.strokeColor = ink(Scn.lineAlpha * Scn.dimLine)
        wireSeen.strokeColor = acc(Scn.lineAlpha + (Scn.seenAlpha - Scn.lineAlpha) * Scn.partial)
        fillSeen.fillColor = acc(Scn.fillAlpha * Scn.partial)
        wireCap.strokeColor = acc(Scn.seenAlpha); fillCap.fillColor = acc(Scn.fillAlpha)
        sweepLine.strokeColor = acc(Scn.sweepAlpha)
        CATransaction.commit()
    }

    // MARK: control (main thread)

    /// A new scan: "Starting camera…", nothing tracked, nothing lit.
    func start() {
        stop()
        phase = .starting; pose = ScanPose(); tracked = nil; lostAt = nil; findFor = 0; faceSince = nil; videoAt = nil; lastSize = nil
        filt = (OneEuro(), OneEuro(), OneEuro()); ptsFilt = ScanGeometry.refs.map { _ in (OneEuro(), OneEuro()) }
        seen = Array(repeating: false, count: ScanGeometry.T.count); captured = seen
        collapse = nil; jobs = []; vmap = vmap.map { var s = $0; s.x = 0; s.t = 0; s.v = 0; return s }
        meshRoot.opacity = 1
        say("Starting camera…", "", announce: false)
        mascot.idle(false); mascot.set(MascotView.focus, Onb.focus)
        lastTick = now
        let t = Timer(timeInterval: Scn.tick, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        render()
    }

    /// A camera frame for the camera beat (main thread). Ignored once the sweep has wiped the camera away.
    func show(image: CGImage) {
        guard [.starting, .find, .mask, .sweep].contains(phase) else { return }
        camera.contents = image; hasImage = true
    }

    /// Camera frame → mirrored, monochrome, half-size image for the camera beat (camera queue). Memory only.
    private static let ci = CIContext(options: [.cacheIntermediates: false])
    static func image(_ pb: CVPixelBuffer) -> CGImage? {
        let img = CIImage(cvPixelBuffer: pb).oriented(.upMirrored)
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
            .transformed(by: CGAffineTransform(scaleX: 0.5, y: 0.5))
        return ci.createCGImage(img, from: img.extent)
    }

    /// The template is stored: "Face saved" arrives as the mask lands in the ring.
    func saved() {
        let at = (collapse?.at ?? now + Scn.collapseHold) + (reduced ? 0 : Scn.savedAt)
        later(at - now) { [weak self] in
            guard let self else { return }
            self.mascot.set(MascotView.raise, Onb.raise); Sfx.play(.browUp); Sfx.play(.chime)
            self.say(EnrollPanel.copy(.saved))
            self.later(Scn.restAfter) { [weak self] in self?.mascot.set(MascotView.rest); self?.mascot.idle(true); self?.stopTicking() }
        }
    }

    /// Show a failure (also the ones the host decides: camera denied, save failed) and stop.
    func fail(_ p: EnrollPanel.Phase) {
        guard phase != .failed else { return }  // the scan reported it, then the host echoes it back
        phase = .failed
        dropVideo()
        meshRoot.opacity = 0
        say(EnrollPanel.copy(p))
        mascot.set(MascotView.frown, Onb.frown); Sfx.play(.browDown)
        stopTicking()
    }

    /// Release everything (camera layer, timer). Safe to call twice.
    func stop() { stopTicking(); dropVideo() }

    private func stopTicking() { timer?.invalidate(); timer = nil }
    private func dropVideo() { camera.contents = nil; hasImage = false; videoRoot.opacity = 0; onCameraDone() }
    private func later(_ s: Double, _ f: @escaping () -> Void) { jobs.append((now + s, f)) }

    // MARK: frames

    /// One camera frame. Returns true when this frame feeds the face print (a straight hold, before its capture).
    func frame(_ f: ScanFrame, dt rawDt: Double, printed: Bool) -> Bool {
        guard ![.done, .failed].contains(phase) else { return false }
        let dt = min(max(rawDt, 1 / Scn.fps / 2), 0.2)
        if f.size != .zero { if lastSize == nil { videoAt = now }; lastSize = f.size }  // the camera fades in with the first image
        if phase == .starting { phase = .find; say("Look at the screen", "Be the only person in view.") }
        var yaw = 0.0
        if f.faces == 1 {
            yaw = filt.yaw(f.yaw, dt)
            let R = ScanGeometry.rot(yaw: yaw, pitch: filt.pitch(f.pitch, dt), roll: filt.roll(f.roll, dt))
            if let p = f.points {
                let sm = p.indices.map { i in CGPoint(x: ptsFilt[i].0(p[i].x, dt), y: ptsFilt[i].1(p[i].y, dt)) }
                if let fit = ScanGeometry.fit(R, sm, f.size) { tracked = fit; lostAt = nil }
            }
        } else if tracked != nil, lostAt == nil { lostAt = now }

        var feeds = false
        switch phase {
        case .find:
            faceSince = f.faces == 1 && tracked != nil ? (faceSince ?? now) : nil
            findFor = faceSince == nil ? findFor + dt : 0
            if findFor >= Scn.pauseFail { return fail(f.faces >= 2 ? .severalFaces : .noFace, report: true) }
            if let s = faceSince, now - s >= (hasImage ? Scn.videoHold : 0) { phase = .mask; maskAt = now }
        case .scan:
            let wasStraight = pose.step == .straight
            let ev = pose.frame(faces: f.faces, yaw: yaw, dt: dt, printed: printed)
            feeds = wasStraight && pose.counting
            if pose.counting, let step = pose.step {  // the held pose's region wipes outward (a capture frame lights its region below)
                let p = pose.progress
                for t in seen.indices where ScanGeometry.region[t] == step.rawValue && ScanGeometry.order[t] <= p { seen[t] = true }
            }
            for e in ev { handle(e) }
        default: break
        }
        return feeds
    }

    private func fail(_ p: EnrollPanel.Phase, report: Bool) -> Bool {
        fail(p)
        if report { onFail(p) }
        return false
    }

    private func handle(_ e: ScanPose.Event) {
        switch e {
        case .pause(let lost):
            lost ? say("Lost you", "Face the screen to carry on.") : say("More than one face", "Only you should be in view.")
            mascot.set(MascotView.frown, Onb.frown)
        case .resume: cue()
        case .nudge: say("A little further", "Turn until the other cheek lights up.")
        case .capture(let s):
            for t in captured.indices where ScanGeometry.region[t] == s.rawValue { captured[t] = true }
            Sfx.play(.browUp)
            mascot.set(MascotView.raise, Onb.raise)
            if s != .right { later(Scn.captureCue) { [weak self] in if self?.phase == .scan, self?.pose.paused == nil { self?.cue() } } }  // a pause keeps its words
        case .done:
            phase = .done
            captured = captured.map { _ in true }
            later(Scn.collapseHold) { [weak self] in
                guard let self else { return }
                var u = Spring1(s: Scn.collapse); u.t = 1
                self.collapse = (self.now, u)
            }
            onDone()
        case .fail(let lost): _ = fail(lost ? .noFace : .severalFaces, report: true)
        }
    }

    /// The current step's words and the mascot's look (mirrored display: the user's left is the screen's left).
    private func cue() {
        switch pose.step {
        case .straight: say("Look at the screen", "Hold still for a moment."); mascot.set(MascotView.focus, Onb.focus)
        case .left: say("Turn slowly to your left", "Keep your eyes on the screen."); mascot.set(MascotView.look(-1, 0), Onb.look)
        case .right: say("Now to your right", "Keep your eyes on the screen."); mascot.set(MascotView.look(1, 0), Onb.look)
        case nil: break
        }
    }

    private func say(_ c: (String, String)) { say(c.0, c.1) }
    private func say(_ title: String, _ body: String, announce: Bool = true) {
        guard title + body != shown else { return }
        shown = title + body
        titleLabel.stringValue = title; bodyLabel.stringValue = body
        if !reduced { [titleLabel, bodyLabel].forEach { animate($0.layer ?? CALayer(), "opacity", from: 0, to: 1, duration: Tokens.Motion.enter) } }
        if announce, let w = window {
            NSAccessibility.post(element: w, notification: .announcementRequested,
                                 userInfo: [.announcement: body.isEmpty ? title : "\(title). \(body)", .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    // MARK: tick + render

    private func tick() {
        let t = now, dt = min(t - lastTick, 0.05); lastTick = t
        let due = jobs.filter { $0.at <= t }; jobs.removeAll { $0.at <= t }; due.forEach { $0.f() }
        if phase == .mask, t - maskAt >= (reduced ? Scn.fade : Scn.maskIn) { phase = .sweep; sweepAt = t }
        if phase == .sweep, t - sweepAt >= (reduced ? Scn.fade : Scn.sweep) {
            phase = .scan; dropVideo(); cue()
        }
        if var c = collapse { c.u.step(dt); collapse = c }
        for i in vmap.indices { vmap[i].step(dt) }
        render()
    }

    private func render() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let a = area, w = bounds.width, t = now
        let scale = a.h / 19  // canonical face ≈ 19 cm forehead to chin
        let cx = a.x - (tracked.map { $0.centre.x } ?? 0) * Scn.follow * w * 0.5
        let cy = a.y + (tracked.map { $0.centre.y } ?? 0) * Scn.follow * a.h * 0.6
        let sweepY: CGFloat? = phase == .sweep && !reduced
            ? cy - a.h * 0.8 + a.h * 1.6 * CGFloat(1 - pow(1 - min(1, (t - sweepAt) / Scn.sweep), 3)) : nil
        renderVideo(cx: cx, cy: cy, scale: scale, sweepY: sweepY)

        guard let tr = tracked else { [wire, wireDim, wireSeen, fillSeen, wireCap, fillCap, sweepLine].forEach { $0.path = nil }; return }
        var pts = tr.q.map { CGPoint(x: cx - $0.x * scale, y: cy + $0.y * scale) }  // mirror: image right → screen left
        var alpha: CGFloat = switch phase {
        case .starting, .find: 0
        case .mask: CGFloat(min(1, (t - maskAt) / (reduced ? Scn.fade : Scn.maskIn)))
        default: 1
        }
        if let l = lostAt { alpha *= Scn.lostAlpha + (1 - Scn.lostAlpha) * CGFloat(exp(-(t - l) / Scn.lostFade)) }
        if let c = collapse {  // vertices spring onto the mascot's ring at their own angle; farther ones start a little later
            let m = mascot.frame, rc = CGPoint(x: m.midX, y: bounds.height - m.midY), rr = m.width * 26.875 / 64
            if reduced { alpha *= CGFloat(max(0, 1 - (t - c.at) / Scn.fade)) } else {
                let u = c.u.x, c0 = CGPoint(x: cx, y: cy - a.h * 0.08)
                pts = pts.map { p in
                    let ang = atan2(p.y - c0.y, p.x - c0.x), d = Double(hypot(p.x - c0.x, p.y - c0.y) / a.h)
                    let k = CGFloat(max(0, min(1.08, (u - Scn.stagger * d) / (1 - Scn.stagger))))
                    return CGPoint(x: p.x + (rc.x + rr * cos(ang) - p.x) * k, y: p.y + (rc.y + rr * sin(ang) - p.y) * k)
                }
                alpha *= CGFloat(max(0, min(1, (1 - u) / 0.25)))
            }
        }
        meshRoot.opacity = Float(alpha)
        let paths = [CGMutablePath(), CGMutablePath(), CGMutablePath(), CGMutablePath()]  // wire, dim, seen, captured
        for (i, tri) in ScanGeometry.T.enumerated() {
            let nz = tr.nz[i]
            guard nz > 0.02 || collapse != nil else { continue }  // backface cull
            let k = captured[i] ? 3 : seen[i] ? 2 : (collapse == nil && nz < 0.2 ? 1 : 0)
            paths[k].addLines(between: [pts[tri[0]], pts[tri[1]], pts[tri[2]]]); paths[k].closeSubpath()
        }
        wire.path = paths[0]; wireDim.path = paths[1]; wireSeen.path = paths[2]; fillSeen.path = paths[2]
        wireCap.path = paths[3]; fillCap.path = paths[3]
        if let y = sweepY {
            let l = CGMutablePath(); l.move(to: CGPoint(x: cx - a.h * 0.55, y: y)); l.addLine(to: CGPoint(x: cx + a.h * 0.55, y: y))
            sweepLine.path = l
        } else { sweepLine.path = nil }
    }

    /// The camera layer, aligned to the mask: screen = (cx − k(imgx − tx), cy + k(imgy − ty)), k = pt per image px.
    private func renderVideo(cx: CGFloat, cy: CGFloat, scale: CGFloat, sweepY: CGFloat?) {
        guard hasImage, let start = videoAt, let size = lastSize else { videoRoot.opacity = 0; return }
        let a = area
        let want = tracked.map { [Double(scale) / $0.s, $0.tx, $0.ty] }
            ?? [Double(a.h) * 1.6 / Double(size.height), Double(size.width) / 2, Double(size.height) / 2]
        for i in 0..<3 { if vmap[i].x == 0 { vmap[i].x = want[i] }; vmap[i].t = want[i] }
        let k = CGFloat(vmap[0].x), tx = CGFloat(vmap[1].x), ty = CGFloat(vmap[2].x)
        camera.frame = CGRect(x: cx - k * (size.width - tx), y: cy - k * ty, width: k * size.width, height: k * size.height)
        var alpha = Scn.videoAlpha * CGFloat(min(1, (now - start) / Scn.videoIn))
        if phase == .sweep, reduced { alpha *= CGFloat(max(0, 1 - (now - sweepAt) / Scn.fade)) }
        videoRoot.opacity = Float(alpha)
        let top = sweepY ?? 0, r = a.h * 0.78
        videoWipe.frame = CGRect(x: 0, y: top, width: bounds.width, height: max(0, bounds.height - top))
        videoEdge.frame = CGRect(x: cx - r, y: cy - r - top, width: 2 * r, height: 2 * r)  // soft edge: a fade, not an oval
    }
}
