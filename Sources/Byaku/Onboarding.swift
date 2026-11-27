import AppKit
import AVKit

// First-run onboarding (docs/designs/onboarding.md; motion: design/onboarding/motion.html):
// welcome → face → guided menu tour (on the real menu, one row at a time) → founder video. Timings and springs live in Tokens.Onboarding.

typealias Onb = Tokens.Onboarding

// MARK: - springs

/// Spring a layer key path to `to` from what's on screen (retargets mid-flight). Reduce Motion: jump.
func springTo(_ l: CALayer, _ key: String, _ to: CGFloat, _ s: Onb.Spring) {
    let from = (l.presentation()?.value(forKeyPath: key) as? NSNumber)?.doubleValue
        ?? (l.value(forKeyPath: key) as? NSNumber)?.doubleValue ?? Double(to)
    CATransaction.begin(); CATransaction.setDisableActions(true)
    l.setValue(to, forKeyPath: key)
    CATransaction.commit()
    guard !Tokens.Motion.reduced else { l.removeAnimation(forKey: key); return }
    let a = CASpringAnimation(keyPath: key)
    a.mass = 1; a.stiffness = s.stiffness; a.damping = s.damping
    a.fromValue = from; a.toValue = to
    a.duration = a.settlingDuration
    l.add(a, forKey: key)
}

/// Seconds until the slowest of these springs comes to rest (CASpringAnimation's own estimate).
func settled(_ springs: Onb.Spring...) -> Double {
    springs.map { s in let a = CASpringAnimation(); a.mass = 1; a.stiffness = s.stiffness; a.damping = s.damping; return a.settlingDuration }.max() ?? 0
}

/// Show a view at `origin` and `side` (its frame is the base; scale is about its bottom-left). x leads and y lags, so the path arcs.
func fly(_ v: NSView, to origin: CGPoint, side: CGFloat, x: Onb.Spring = Onb.fly, y: Onb.Spring = Onb.flyY) {
    guard let l = v.layer else { return }
    let k = side / v.frame.width, a = l.anchorPoint  // scaling about the anchor shifts the origin by (1 − k) · anchor · size
    springTo(l, "transform.translation.x", origin.x - v.frame.minX - (1 - k) * a.x * v.frame.width, x)
    springTo(l, "transform.translation.y", origin.y - v.frame.minY - (1 - k) * a.y * v.frame.height, y)
    springTo(l, "transform.scale", k, Onb.flyScale)
}

// MARK: - Sfx

/// Onboarding sounds, computed like the siren (no audio file ships): a filtered-noise whoosh and a short eyebrow flick.
enum Sfx {
    enum Kind { case whooshIn, whooshOut, browUp, browDown, chime }
    static let rate = 44100
    private static var cache: [Kind: NSSound] = [:]

    static func prewarm() { for k in [Kind.whooshIn, .whooshOut, .browUp, .browDown, .chime] where cache[k] == nil { cache[k] = NSSound(data: wav(samples(k))) } }

    static func play(_ k: Kind) {
        let s = cache[k] ?? NSSound(data: wav(samples(k)))
        cache[k] = s
        s?.stop(); s?.play()
    }

    static func samples(_ k: Kind) -> [Float] {
        switch k {
        case .whooshIn: whoosh(rising: true)
        case .whooshOut: whoosh(rising: false)
        case .browUp: flick(up: true)
        case .browDown: flick(up: false)
        case .chime: chime()
        }
    }

    /// Noise through a two-pole low-pass swept 300 → 3000 Hz (arriving: peak late) or back down (leaving: peak early).
    static func whoosh(rising: Bool) -> [Float] {
        let n = Int(Onb.whoosh * Double(rate)), peak = rising ? 0.7 : 0.3
        var seed: UInt32 = 22_695_477, lp = 0.0, lp2 = 0.0
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / Double(n)
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let white = Double(seed >> 8) / Double(1 << 24) * 2 - 1
            let f = rising ? 300 * pow(10, t) : 3000 * pow(10, -t)
            let a = 1 - exp(-2 * .pi * f / Double(rate))
            lp += a * (white - lp); lp2 += a * (lp - lp2)
            let env = t < peak ? pow(t / peak, 2) : pow((1 - t) / (1 - peak), 1.5)
            out[i] = Float(lp2 * env)
        }
        let top = out.map(abs).max() ?? 1
        return out.map { $0 / max(top, 1e-6) * Onb.whooshLevel }
    }

    /// A soft wooden tick whose pitch glides up (brows raise) or down (brows drop).
    static func flick(up: Bool) -> [Float] {
        let n = Int(Onb.flick * Double(rate))
        var ph = 0.0
        return (0..<n).map { i in
            let t = Double(i) / Double(rate), u = Double(i) / Double(n)
            ph += 2 * .pi * (up ? 680 * (1 + 0.6 * u) : 560 * (1 - 0.3 * u)) / Double(rate)
            let env = min(t / 0.003, 1) * exp(-t * 55)
            return Float((sin(ph) + 0.25 * sin(2 * ph)) / 1.25 * env) * Onb.flickLevel
        }
    }

    /// Face saved: two soft sine notes, the second a little later and higher.
    static func chime() -> [Float] {
        let c = Tokens.Scan.chime, n = Int((c.length + c.gap) * Double(rate))
        return (0..<n).map { i in
            let t = Double(i) / Double(rate)
            func note(_ f: Double, _ at: Double) -> Double {
                guard t >= at else { return 0 }
                let u = t - at
                return sin(2 * .pi * f * u) * min(u / 0.006, 1) * exp(-u * 6)
            }
            return Float((note(c.low, 0) + 0.9 * note(c.high, c.gap)) / 1.9) * c.level * 2
        }
    }

    /// 16-bit mono PCM WAV.
    static func wav(_ s: [Float]) -> Data {
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + UInt32(s.count * 2))
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(s.count * 2))
        for x in s { withUnsafeBytes(of: Int16(max(-1, min(1, x)) * 32767).littleEndian) { d.append(contentsOf: $0) } }
        return d
    }
}

// MARK: - MascotView

/// The brand mark as a character: the ring stays, the two blades move like eyebrows (rotate about their base, scale for a
/// blink). Geometry is the 64-unit SVG space of design/brand/final/symbol-dark.svg, y down.
final class MascotView: NSView {
    struct Pose { var a = 0.0, r = 0.0, tx = 0.0, ty = 0.0, sx = 1.0, sy = 1.0, gx = 0.0, gy = 0.0 }
    // a: mirrored rotation (+ = inner ends fall inward), r: same-sign rotation, tx mirrored, g = both blades together. Degrees, SVG units.
    static let rest = Pose(), raise = Pose(a: -9, tx: -0.6, ty: -2.5), frown = Pose(a: 16, tx: 0.8, ty: 2.5)
    static let focus = Pose(a: 5, ty: 3, sx: 0.78, sy: 0.96)
    static func look(_ dx: Double, _ dy: Double) -> Pose { Pose(r: 3.5 * dx, ty: dy > 0 ? -1.2 * dy : -0.8 * dy, gx: 1.8 * dx, gy: -1.8 * dy) }

    var tint: NSColor = Tokens.accent { didSet { recolor(animated: true) } }
    private let root = CALayer(), ring = CAShapeLayer()
    private var move: [CALayer] = [], turn: [CALayer] = [], size: [CAShapeLayer] = []
    private var pose = Pose()
    private var blinkTimer: Timer?, stressTimer: Timer?

    private static let blades: [(NSBezierPath, CGPoint)] = [  // path, pivot (the blade's outer base)
        (StatusIcon.crescent(NSPoint(x: 19.367, y: 43.375), NSPoint(x: 26.747, y: 15.832), back: 54.689), CGPoint(x: 19.367, y: 43.375)),
        (StatusIcon.crescent(NSPoint(x: 42.466, y: 18.604), NSPoint(x: 48.495, y: 36.113), back: 104.397), CGPoint(x: 48.495, y: 36.113)),
    ]

    init(side: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: side, height: side))
        wantsLayer = true
        setAccessibilityElement(false)  // decoration: the text beside it carries the meaning
        let space = CGRect(x: 0, y: 0, width: 64, height: 64)
        root.anchorPoint = .zero; root.bounds = space; root.position = .zero
        root.isGeometryFlipped = true
        root.setAffineTransform(CGAffineTransform(scaleX: side / 64, y: side / 64))
        layer!.addSublayer(root)
        ring.frame = space
        ring.path = CGPath(ellipseIn: CGRect(x: 32 - 26.875, y: 32 - 26.875, width: 53.75, height: 53.75), transform: nil)
        ring.lineWidth = 2.25; ring.fillColor = nil
        root.addSublayer(ring)
        for (path, pivot) in Self.blades {
            let m = CALayer(), t = CALayer(), s = CAShapeLayer()
            m.frame = space
            t.bounds = space; t.anchorPoint = CGPoint(x: pivot.x / 64, y: pivot.y / 64); t.position = pivot
            let c = CGPoint(x: path.bounds.midX, y: path.bounds.midY)
            s.bounds = space; s.anchorPoint = CGPoint(x: c.x / 64, y: c.y / 64); s.position = c
            s.path = path.cgPath
            t.addSublayer(s); m.addSublayer(t); root.addSublayer(m)
            move.append(m); turn.append(t); size.append(s)
        }
        recolor(animated: false)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { recolor(animated: false) }

    private func recolor(animated: Bool) {
        let c = cg(tint, in: self)
        if animated, !Tokens.Motion.reduced {
            animate(ring, "strokeColor", to: c, duration: Onb.recolor)
            size.forEach { animate($0, "fillColor", to: c, duration: Onb.recolor) }
        } else {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            ring.strokeColor = c; size.forEach { $0.fillColor = c }
            CATransaction.commit()
        }
    }

    func set(_ p: Pose, _ s: Onb.Spring = Onb.neutral) {
        pose = p
        for i in 0..<2 {
            let mirror: CGFloat = i == 0 ? 1 : -1
            springTo(move[i], "transform.translation.x", p.gx + mirror * p.tx, s)
            springTo(move[i], "transform.translation.y", p.gy + p.ty, s)
            springTo(turn[i], "transform.rotation.z", (mirror * p.a + p.r) * .pi / 180, s)
            springTo(size[i], "transform.scale.x", p.sx, s)
            springTo(size[i], "transform.scale.y", p.sy, s)
        }
        if Tokens.Motion.reduced { animate(root, "opacity", from: 0.35, to: 1, duration: Tokens.Motion.exit) }  // cross-fade, no motion
    }

    /// Start blinking unless it already is (a hover mustn't push the next blink back).
    func keepBlinking() { if blinkTimer == nil { idle(true) } }

    /// One self-contained keyframe (no timer or dispatch): blinks also run while a menu is open (the tour).
    func blink() {
        guard !Tokens.Motion.reduced else { return }
        for l in size {
            let a = CAKeyframeAnimation(keyPath: "transform.scale.y")
            a.values = [pose.sy, pose.sy * 0.12, pose.sy]; a.keyTimes = [0, 0.35, 1]
            a.timingFunctions = [Tokens.Motion.easeOut, Tokens.Motion.easeOut]
            a.duration = Onb.blinkTime
            l.add(a, forKey: "blink")
        }
    }

    /// Stressed: a frantic twitch through the expressions (as the prototype's "stress"), brows flicking, then a frown.
    func stressed() {
        stressTimer?.invalidate()
        guard !Tokens.Motion.reduced else { set(Self.frown, Onb.frown); return }
        let seq = [Self.raise, Self.frown, Self.focus, Self.look(1, 1), Self.look(-1, 0), Self.raise]
        var i = 0
        let t = Timer(timeInterval: Onb.stressStep, repeats: true) { [weak self] t in
            guard let self else { return t.invalidate() }
            if i == Onb.stressSteps { t.invalidate(); self.set(Self.frown, Onb.frown); return }
            let p = seq[i % seq.count]
            self.set(p, p.a < 0 ? Onb.raise : Onb.frown)
            if i % 2 == 0 { Sfx.play(p.a < 0 || p.ty < 0 ? .browUp : .browDown) }
            i += 1
        }
        RunLoop.main.add(t, forMode: .common)
        stressTimer = t
    }

    func calm() { stressTimer?.invalidate(); stressTimer = nil }

    /// Blink every few seconds while shown. Common run-loop modes: keeps blinking while a menu is open.
    func idle(_ on: Bool) {
        blinkTimer?.invalidate(); blinkTimer = nil
        guard on, !Tokens.Motion.reduced else { return }
        let t = Timer(timeInterval: Onb.blinkEvery + .random(in: 0...Onb.blinkJitter), repeats: false) { [weak self] _ in
            self?.blink(); self?.idle(true)
        }
        RunLoop.main.add(t, forMode: .common)
        blinkTimer = t
    }

    /// Intro: the ring draws on, then the blades appear raised and settle ("waking up").
    func wake() {
        let reduced = Tokens.Motion.reduced
        set(Self.raise, Onb.snap)
        move.forEach { $0.opacity = 0 }
        if !reduced { animate(ring, "strokeEnd", from: 0, to: 1, duration: Onb.ringDraw) }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduced ? 0 : Onb.bladesAt)) { [weak self] in
            guard let self else { return }
            self.move.forEach { animate($0, "opacity", from: 0, to: 1, duration: Onb.bladesFade) }
            self.set(Self.rest, Onb.raise)
            Sfx.play(.browDown)
        }
    }
}

// MARK: - WordmarkView

/// "byaku" from design/brand/final/wordmark-dark.svg (ink), `height` pt tall.
final class WordmarkView: NSView {
    private let shape = CAShapeLayer()
    static let box = CGRect(x: 5.1, y: -78, width: 257.5, height: 101)  // the SVG viewBox

    init(height: CGFloat) {
        let k = height / Self.box.height
        super.init(frame: NSRect(x: 0, y: 0, width: Self.box.width * k, height: height))
        wantsLayer = true
        setAccessibilityElement(false)
        let root = CALayer()
        root.anchorPoint = .zero; root.bounds = CGRect(origin: .zero, size: Self.box.size); root.position = .zero
        root.isGeometryFlipped = true
        root.setAffineTransform(CGAffineTransform(scaleX: k, y: k))
        shape.frame = root.bounds
        shape.path = svgPath(Self.d, offset: CGPoint(x: -Self.box.minX, y: -Self.box.minY))
        root.addSublayer(shape); layer!.addSublayer(root)
        shape.fillColor = cg(Tokens.ink, in: self)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidChangeEffectiveAppearance() { shape.fillColor = cg(Tokens.ink, in: self) }

    static let d = "M54.3 -23.5Q54.3 -16.7 51 -11.1Q47.7 -5.5 42.1 -2.2Q36.5 1.1 29.7 1.1Q22.9 1.1 17.3 -2.2Q11.7 -5.5 8.4 -11.1Q5.1 -16.7 5.1 -23.5Q5.1 -30.3 8.4 -35.9Q11.7 -41.5 17.3 -44.8Q22.9 -48.1 29.7 -48.1Q36.5 -48.1 42.1 -44.8Q47.7 -41.5 51 -35.9Q54.3 -30.3 54.3 -23.5ZM44.3 -23.5Q44.3 -27.9 42.35 -31.4Q40.4 -34.9 37.05 -36.95Q33.7 -39 29.5 -39Q25.4 -39 22.05 -36.95Q18.7 -34.9 16.75 -31.4Q14.8 -27.9 14.8 -23.5Q14.8 -19.1 16.75 -15.6Q18.7 -12.1 22.05 -10.05Q25.4 -8 29.5 -8Q33.7 -8 37.05 -10.05Q40.4 -12.1 42.35 -15.6Q44.3 -19.1 44.3 -23.5ZM5.1 0V-78H14.8V0ZM72.7 23 96.3 -47H106.2L82.5 23ZM80.1 0 56.7 -47H67.3L90.7 0ZM159.3 0H149.6V-47H159.3ZM110.1 -23.5Q110.1 -30.3 113.4 -35.9Q116.7 -41.5 122.3 -44.8Q127.9 -48.1 134.7 -48.1Q141.5 -48.1 147.05 -44.8Q152.6 -41.5 155.95 -35.9Q159.3 -30.3 159.3 -23.5Q159.3 -16.7 155.95 -11.1Q152.6 -5.5 147.05 -2.2Q141.5 1.1 134.7 1.1Q127.9 1.1 122.3 -2.2Q116.7 -5.5 113.4 -11.1Q110.1 -16.7 110.1 -23.5ZM120.1 -23.5Q120.1 -19.1 122.05 -15.6Q124 -12.1 127.35 -10.05Q130.7 -8 134.8 -8Q139 -8 142.35 -10.05Q145.7 -12.1 147.65 -15.6Q149.6 -19.1 149.6 -23.5Q149.6 -27.9 147.65 -31.4Q145.7 -34.9 142.35 -36.95Q139 -39 134.8 -39Q130.7 -39 127.35 -36.95Q124 -34.9 122.05 -31.4Q120.1 -27.9 120.1 -23.5ZM169.5 0V-78H179.2V0ZM171.3 -20.9 195.6 -47H208.7L177.4 -15.1ZM197.6 0 180.6 -30.4H191.8L208.7 0ZM262.6 -47V0H252.8V-47ZM262.6 -22.9Q262.6 -17.9 260.7 -13.55Q258.8 -9.2 255.5 -5.95Q252.2 -2.7 247.85 -0.8Q243.5 1.1 238.5 1.1Q233.5 1.1 229.15 -0.8Q224.8 -2.7 221.5 -5.95Q218.2 -9.2 216.35 -13.55Q214.5 -17.9 214.5 -22.9V-47H224.2V-22.9Q224.2 -18.7 226.1 -15.3Q228 -11.9 231.25 -9.95Q234.5 -8 238.5 -8Q242.6 -8 245.85 -9.95Q249.1 -11.9 250.95 -15.3Q252.8 -18.7 252.8 -22.9Z"
}

/// Minimal SVG path reader for the wordmark: absolute M L H V Q Z, implicit repeats (M continues as L).
func svgPath(_ d: String, offset o: CGPoint = .zero) -> CGPath {
    var tokens: [String] = [], num = ""
    func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
    for ch in d {
        if ch.isLetter { flush(); tokens.append(String(ch)) }
        else if ch == " " || ch == "," { flush() }
        else if ch == "-", !num.isEmpty { flush(); num = "-" }
        else { num.append(ch) }
    }
    flush()
    let p = CGMutablePath()
    var cmd: Character = "M", cur = CGPoint.zero, i = 0
    func n() -> CGFloat { defer { i += 1 }; return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0 }
    func pt() -> CGPoint { let x = n(), y = n(); return CGPoint(x: x + o.x, y: y + o.y) }
    while i < tokens.count {
        if let c = tokens[i].first, c.isLetter {
            cmd = c; i += 1
            if c == "Z" { p.closeSubpath() }
            continue
        }
        switch cmd {
        case "M": cur = pt(); p.move(to: cur); cmd = "L"
        case "L": cur = pt(); p.addLine(to: cur)
        case "H": cur.x = n() + o.x; p.addLine(to: cur)
        case "V": cur.y = n() + o.y; p.addLine(to: cur)
        case "Q": let c1 = pt(); cur = pt(); p.addQuadCurve(to: cur, control: c1)
        default: i += 1
        }
    }
    return p
}

// MARK: - OnboardingFlow

/// One window for welcome, face and the founder video. The tour leaves it: the mascot flies to the menu bar, the real
/// menu opens with a coach card as its first item, and Next lights one feature row at a time (AppController calls
/// dress(_:) from menuNeedsUpdate). Only Finish or Skip tour lead on to the video; any other close reopens the menu.
final class OnboardingFlow: NSObject {
    var onScan: () -> Void = {}, onStopScan: () -> Void = {}, onOpenSettings: () -> Void = {}
    var onOpenMenu: () -> Void = {}, onDone: () -> Void = {}
    var statusFrame: () -> NSRect? = { nil }
    private(set) var scanning = false, touring = false

    private let window = OnboardingWindow()
    private var mascot = MascotView(side: 112)  // replaced by an 84 pt one for the video step
    private let titleLabel = NSTextField(labelWithString: ""), bodyLabel = NSTextField(wrappingLabelWithString: "")
    private var buttons: [PanelButton] = []
    private var close: PanelButton!
    private var run = 0  // bumps on every step change so stale timed beats drop
    private var leaving = false  // a step is on its way out: a second press of Skip / Show me does nothing
    private let hasOwner: Bool

    init(hasOwner: Bool) {
        self.hasOwner = hasOwner
        super.init()
        Sfx.prewarm()  // the first whoosh must start on the press, not after synthesis
        let v = window.contentView!
        close = PanelButton("", role: .close) { [weak self] in self?.finish() }
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold); titleLabel.alignment = .center; titleLabel.textColor = Tokens.ink
        bodyLabel.font = .systemFont(ofSize: 13); bodyLabel.alignment = .center; bodyLabel.textColor = Tokens.mute
        bodyLabel.maximumNumberOfLines = 2
        [mascot, titleLabel, bodyLabel, close].forEach(v.addSubview)
        window.onEsc = { [weak self] in self?.finish() }
        window.setAccessibilityTitle("Welcome to byaku")
    }

    func start() {
        layoutCard()
        window.center()
        window.alphaValue = 1
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        welcome()
    }

    func bringForward() { if !touring { window.makeKeyAndOrderFront(nil); NSApp.activate() } }

    // MARK: layout

    private static let card = NSSize(width: 480, height: 360), video = NSRect(x: 20, y: 20, width: 640, height: 360)
    private static let founderSize = NSSize(width: 680, height: 424)

    private func layoutCard() {
        resize(Self.card)
        let w = Self.card.width, h = Self.card.height
        resetPlacement(mascot, NSRect(x: (w - 112) / 2, y: h - 48 - 112, width: 112, height: 112))
        titleLabel.frame = NSRect(x: 40, y: 128, width: w - 80, height: 24)
        bodyLabel.frame = NSRect(x: 48, y: 84, width: w - 96, height: 40)
        close.setFrameOrigin(NSPoint(x: w - 12 - 24, y: h - 12 - 24))
    }

    private func resize(_ s: NSSize) {
        guard window.frame.size != s else { return }
        let f = window.frame
        window.setFrame(NSRect(x: f.midX - s.width / 2, y: f.midY - s.height / 2, width: s.width, height: s.height), display: true)
    }

    /// Put a view at a frame and clear any flight transform.
    private func resetPlacement(_ v: NSView, _ f: NSRect) {
        v.frame = f
        v.layer?.removeAllAnimations()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        v.layer?.transform = CATransform3DIdentity
        CATransaction.commit()
    }

    private func show(_ title: String, _ body: String, _ specs: [CardPanel.Spec], centered: Bool = false, announce: Bool = true) {
        run += 1; leaving = false
        titleLabel.stringValue = title; bodyLabel.stringValue = body
        titleLabel.isHidden = false; bodyLabel.isHidden = false
        setButtons(specs, centered: centered, y: 24)
        if announce {
            NSAccessibility.post(element: window, notification: .announcementRequested,
                                 userInfo: [.announcement: body.isEmpty ? title : "\(title). \(body)", .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }

    private func setButtons(_ specs: [CardPanel.Spec], centered: Bool, y: CGFloat, in v: NSView? = nil) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = specs.map { t, role, act in PanelButton(t, role: role) { act() } }
        let host = v ?? window.contentView!
        let total = buttons.reduce(0) { $0 + $1.frame.width } + CGFloat(max(buttons.count - 1, 0)) * 8
        var x = centered ? (host.bounds.width - total) / 2 : host.bounds.width - 24 - total
        for b in buttons { b.setFrameOrigin(NSPoint(x: x, y: y)); x += b.frame.width + 8; host.addSubview(b) }
        buttons.last { $0.role == .primary }?.keyEquivalent = "\r"
    }

    private func after(_ t: Double, _ f: @escaping () -> Void) {
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in if self?.run == r { f() } }
    }

    // MARK: 1 welcome

    private func welcome() {
        mascot.set(MascotView.rest); mascot.idle(true)
        show("byaku watches who's looking.", "", [("Start", .primary, { [weak self] () -> Void in self?.hasOwner == true ? self?.tourIntro() : self?.faceIntro() })],
             centered: true)
        titleLabel.frame.origin.y = 120
    }

    // MARK: 2 face (drives AppController's enrollment; same words as the Set up face panel)

    private func faceIntro() {
        scanning = false; endScanView()
        titleLabel.frame.origin.y = 128
        mascot.set(MascotView.rest)
        show("First, your face", "Look straight, then turn left and right. Nothing is saved except a face print.",
             [("Skip", .secondary, { [weak self] () -> Void in self?.tourIntro() }), ("Scan my face", .primary, { [weak self] () -> Void in self?.scan() })])
    }

    /// The guided scan (ScanView) while scanning; the window's own mascot and words are hidden under it.
    private(set) var scanView: ScanView?

    private func scan() {
        scanning = true
        if scanView == nil {
            let v = ScanView(frame: window.contentView!.bounds, compact: false)
            window.contentView!.addSubview(v, positioned: .below, relativeTo: close)
            scanView = v
        }
        mascot.idle(false)
        [mascot, titleLabel, bodyLabel].forEach { $0.isHidden = true }
        onScan()
    }

    private func endScanView() {
        scanView?.stop(); scanView?.removeFromSuperview(); scanView = nil
        mascot.isHidden = false
    }

    private func skipScan() { if scanning { scanning = false; onStopScan() }; tourIntro() }

    /// AppController's enrollment phases while the window hosts the scan; the ScanView shows the words.
    func showFace(_ p: EnrollPanel.Phase) {
        guard let s = scanView else { return }
        run += 1; leaving = false
        let skip = ("Skip", PanelButton.Role.secondary, { [weak self] () -> Void in self?.skipScan() })
        switch p {
        case .starting:
            s.start()
            setButtons([skip], centered: false, y: 24)
        case .saved:
            scanning = false
            s.saved()
            setButtons([("Next", .primary, { [weak self] () -> Void in self?.tourIntro() })], centered: false, y: 24)
        case .cameraDenied:
            scanning = false
            s.fail(p)
            setButtons([skip, ("Open camera settings…", .primary, { [weak self] () -> Void in self?.onOpenSettings() })], centered: false, y: 24)
        case .noFace, .severalFaces, .failed:
            scanning = false
            s.fail(p)
            setButtons([skip, ("Try again", .primary, { [weak self] () -> Void in self?.scan() })], centered: false, y: 24)
        }
    }

    /// The scan was stopped from outside (screen locked): back to the face intro.
    func scanStopped() { scanning = false; faceIntro() }

    // MARK: 3 tour

    private var overlay: CoachOverlay?

    private func tourIntro() {
        endScanView()
        mascot.idle(true)
        titleLabel.frame.origin.y = 128
        show("Here's the menu.", "It lives up here, next to the clock.",
             [("Skip", .secondary, { [weak self] () -> Void in self?.skipTour() }), ("Show me", .primary, { [weak self] () -> Void in self?.launchTour() })])
        after(Tokens.Motion.enter) { [weak self] in self?.mascot.set(MascotView.look(1, 1), Onb.look) }
        // Build the full-screen overlay now, invisible: its first composite is what made the first flight stutter.
        if overlay == nil, let status = statusFrame(),
           let screen = NSScreen.screens.first(where: { $0.frame.contains(CGPoint(x: status.midX, y: status.midY)) }) ?? NSScreen.main {
            overlay = CoachOverlay(screen: screen, status: status)  // the menu bar's screen, not the window's
        }
    }

    private func skipTour() {
        guard !leaving else { return }
        leaving = true
        overlay?.orderOut(nil); overlay = nil
        run += 1
        NSAnimationContext.runAnimationGroup({ c in c.duration = Onb.windowFade; window.animator().alphaValue = 0 },
                                             completionHandler: { [weak self] in self?.founder() })
    }

    private func launchTour() {
        guard !leaving else { return }
        guard let o = overlay else { return skipTour() }
        leaving = true
        run += 1
        o.begin(from: window.convertToScreen(mascot.convert(mascot.bounds, to: nil)), pose: MascotView.look(1, 1))
        mascot.isHidden = true
        NSAnimationContext.runAnimationGroup { c in c.duration = Onb.windowFade; window.animator().alphaValue = 0 }
        touring = true; step = 0; tourDone = false
        after(Onb.menuAfter) { [weak self] in self?.openMenu() }
    }

    /// The status item can be hidden (notch, menu-bar managers): if no menu opened, don't leave an invisible tour.
    private func openMenu() {
        onOpenMenu()
        after(Onb.menuCheck) { [weak self] in if self?.touring == true, self?.overlay?.menuSeen != true { self?.finish() } }
    }

    func menuOpened(_ menu: NSMenu) { overlay?.opened(menu) }

    // MARK: tour steps

    private var step = 0, tourDone = false
    private weak var tourMenu: NSMenu?
    private let card = CoachRow()

    /// Called from menuNeedsUpdate while touring: the coach card goes first, nothing in the menu acts, and only the current
    /// step's row is enabled. The steps are the coached rows this menu actually has (Message… needs the app bundle).
    func dress(_ menu: NSMenu) {
        tourMenu = menu
        for i in menu.items {
            i.target = nil; i.action = nil
            (i.view as? VolumeSlider)?.inert = true
            i.submenu?.items.forEach { $0.isEnabled = false; $0.action = nil; ($0.view as? SoundRow)?.onPick = { _ in } }
        }
        card.onNext = { [weak self] in self?.next() }
        card.onSkip = { [weak self] in self?.endTour() }
        let c = NSMenuItem(); c.view = card
        menu.insertItem(c, at: 0); menu.insertItem(.separator(), at: 1)
        light()
    }

    private var steps: [NSMenuItem] { tourMenu?.items.filter { CoachOverlay.coach[$0.title] != nil } ?? [] }

    /// Live, while the menu is open: the current row enabled and semibold, every other row the native disabled grey.
    private func light() {
        guard let menu = tourMenu else { return }
        let s = steps
        guard !s.isEmpty else { return }
        step = min(step, s.count - 1)
        let size = NSFont.menuFont(ofSize: 0).pointSize
        for i in menu.items where i.view == nil && i.attributedTitle != nil {  // un-light (a nil attributedTitle blanks the row)
            i.attributedTitle = NSAttributedString(string: i.title, attributes: [.font: NSFont.menuFont(ofSize: size)])
        }
        for i in menu.items where i.view == nil { i.isEnabled = false }
        let lit = s[step], text = CoachOverlay.coach[lit.title] ?? ""
        lit.isEnabled = true
        lit.attributedTitle = NSAttributedString(string: lit.title, attributes: [.font: NSFont.systemFont(ofSize: size, weight: .semibold)])
        let key = lit.keyEquivalent.isEmpty ? "" : "⌘\(lit.keyEquivalent.uppercased())"
        card.show(lit.title.replacingOccurrences(of: "…", with: ""), shortcut: key, text, step: step + 1, of: s.count)
        NSAccessibility.post(element: card, notification: .announcementRequested, userInfo: [
            .announcement: "\(lit.title), \(step + 1) of \(s.count). \(text)", .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    private func next() {
        guard step < steps.count - 1 else { return endTour() }
        step += 1
        light()
        overlay?.nudged()
    }

    /// Finish or Skip tour: close the menu; menuClosed() then takes the flight into the video.
    private func endTour() { tourDone = true; tourMenu?.cancelTracking() }

    func menuClosed() {
        guard touring, let o = overlay else { return }
        guard tourDone else {  // a click outside or Esc: back on the same step, never on to the video
            o.closed()
            after(Onb.reopen) { [weak self] in self?.openMenu() }
            return
        }
        touring = false
        // The window is invisible here: set the video step up behind it, then the mascot flies from the menu bar straight
        // into the lockup while the window fades in. No card in between, no size jump.
        guard setUpFounder() else { o.orderOut(nil); overlay = nil; return finish() }
        let spot = lockup(up: false)
        o.flyBack(to: window.convertToScreen(NSRect(origin: spot.mark, size: NSSize(width: 84, height: 84))))
        NSAnimationContext.runAnimationGroup { c in c.duration = Tokens.Motion.enter; window.animator().alphaValue = 1 }
        window.makeKeyAndOrderFront(nil); NSApp.activate()
        after(settled(Onb.fly, Onb.flyY, Onb.flyScale)) { [weak self] in  // once the flight has come to rest: cross-fade, no cut
            guard let self else { return }
            self.mascot.alphaValue = 0; self.mascot.isHidden = false
            NSAnimationContext.runAnimationGroup({ c in
                c.duration = Tokens.Motion.hover
                self.mascot.animator().alphaValue = 1; o.animator().alphaValue = 0
            }, completionHandler: { [weak self] in self?.overlay?.orderOut(nil); self?.overlay = nil })
            self.intro(awake: true)
        }
    }

    // MARK: 4 founder video

    private var player: AVPlayer?, playerView: AVPlayerView?
    private let scrim = NSView(), word = WordmarkView(height: 84 * Lockup.wordHeight)
    private let thanks = NSTextField(labelWithString: "Thanks for trying byaku.")
    private var endObserver: NSObjectProtocol?

    /// From Skip (window faded out): set up, fade in, play the intro.
    private func founder() {
        guard setUpFounder() else { return finish() }
        NSAnimationContext.runAnimationGroup { c in c.duration = Tokens.Motion.enter; window.animator().alphaValue = 1 }
        intro(awake: false)
    }

    /// Lay out the video step (window resized while invisible). False when the video isn't bundled (terminal run).
    private func setUpFounder() -> Bool {
        run += 1
        guard player == nil, let url = Bundle.main.url(forResource: "founder", withExtension: "mp4") else { return false }
        mascot.idle(false)
        [titleLabel, bodyLabel].forEach { $0.isHidden = true }
        buttons.forEach { $0.removeFromSuperview() }; buttons = []
        resize(Self.founderSize)
        let v = window.contentView!, r = Self.video
        close.setFrameOrigin(NSPoint(x: v.bounds.width - 12 - 24, y: v.bounds.height - 12 - 24))
        let pv = AVPlayerView(frame: r)
        pv.controlsStyle = .floating; pv.showsFullScreenToggleButton = false
        pv.wantsLayer = true; pv.layer!.cornerRadius = 10; pv.layer!.masksToBounds = true
        pv.setAccessibilityLabel("Video: a hello from byaku's author")
        let p = AVPlayer(url: url)
        pv.player = p; pv.alphaValue = 0
        player = p; playerView = pv
        scrim.frame = r; scrim.wantsLayer = true; scrim.layer!.cornerRadius = 10
        scrim.layer!.backgroundColor = cg(Tokens.surface, in: v); scrim.alphaValue = 0
        thanks.font = .systemFont(ofSize: 13); thanks.textColor = Tokens.mute; thanks.alignment = .center
        thanks.frame = NSRect(x: r.minX, y: r.midY - 34, width: r.width, height: 20); thanks.isHidden = true
        v.addSubview(pv)
        v.addSubview(scrim, positioned: .above, relativeTo: pv)
        [word, thanks].forEach { v.addSubview($0) }
        endObserver = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: p.currentItem,
                                                             queue: .main) { [weak self] _ in self?.outro() }
        // The video step's own 84 pt mark, placed by frame: at rest there is no layer transform for AppKit to reset, so the
        // tour mascot lands exactly on it.
        let spot = lockup(up: false), hidden = mascot.isHidden
        mascot.idle(false); mascot.removeFromSuperview()
        mascot = MascotView(side: 84)
        mascot.frame = NSRect(origin: spot.mark, size: NSSize(width: 84, height: 84))
        mascot.isHidden = hidden
        v.addSubview(mascot)  // on top: it becomes the corner logo over the video
        v.addSubview(close)
        word.setFrameOrigin(spot.word); word.alphaValue = 0
        return true
    }

    /// Lockup spots inside the video frame: the mark (84 pt) and the wordmark side by side, centred; `up` lifts both for the card.
    /// Brand lockup proportions (design/brand/final/lockup-dark.svg, in units of the 64-unit mark box): the wordmark starts
    /// at x 87.3, spans y 7…65.7, and the lockup ends at x 237.1.
    private enum Lockup { static let wordX: CGFloat = 87.3 / 64, wordHeight: CGFloat = 58.7 / 64, wordDrop: CGFloat = 1.7 / 64, width: CGFloat = 237.1 / 64 }

    /// Lockup spots inside the video frame: the 84 pt mark and the wordmark, centred; `up` lifts both for the thanks card.
    private func lockup(up: Bool) -> (mark: CGPoint, word: CGPoint) {
        let r = Self.video, m: CGFloat = 84, x0 = (r.midX - m * Lockup.width / 2).rounded(), y0 = (r.midY - m / 2).rounded() + (up ? 44 : 0)
        return (CGPoint(x: x0, y: y0), CGPoint(x: (x0 + m * Lockup.wordX).rounded(), y: (y0 - m * Lockup.wordDrop).rounded()))
    }

    private var corner: CGPoint { CGPoint(x: Self.video.maxX - 14 - 28, y: Self.video.maxY - 14 - 28) }

    /// `awake`: the mascot just flew in from the menu bar, so no ring draw-on; it blinks and the wordmark joins it.
    private func intro(awake: Bool) {
        run += 1
        if !awake { mascot.wake() }
        after(Onb.blinkAt) { [weak self] in self?.mascot.blink() }
        after(Onb.wordAt) { [weak self] in self?.rise(self?.word) }
        after(Onb.hold) { [weak self] in self?.handoff() }
    }

    /// The wordmark leaves; the mark flies into the frame's top-right and stays as the corner logo; the video grows in.
    private func handoff() {
        guard let pv = playerView else { return }
        NSAnimationContext.runAnimationGroup { c in c.duration = Onb.wordOut; word.animator().alphaValue = 0 }
        mascot.tint = Tokens.ink
        fly(mascot, to: corner, side: 28)
        Sfx.play(.whooshIn)
        after(Onb.frameDelay) { [weak self] in
            NSAnimationContext.runAnimationGroup { c in c.duration = Onb.frameIn; c.timingFunction = Tokens.Motion.easeOut; pv.animator().alphaValue = 1 }
            self?.player?.play()
        }
    }

    private func outro() {
        run += 1
        let spot = lockup(up: true)
        NSAnimationContext.runAnimationGroup { c in c.duration = Onb.scrim; c.timingFunction = Tokens.Motion.easeOut; scrim.animator().alphaValue = Onb.scrimAlpha }
        word.setFrameOrigin(spot.word)
        after(Onb.backAt) { [weak self] in
            guard let self else { return }
            self.mascot.tint = Tokens.accent
            fly(self.mascot, to: spot.mark, side: 84)
            Sfx.play(.whooshOut)
        }
        after(Onb.backAt + Onb.textRise) { [weak self] in self?.rise(self?.word) }
        after(Onb.smileAt) { [weak self] in
            self?.mascot.blink()
            self?.after(Tokens.Motion.check) { self?.mascot.set(MascotView.raise, Onb.raise); Sfx.play(.browUp) }
            self?.after(Onb.smileHold) { self?.mascot.set(MascotView.rest) }
        }
        after(Onb.thanksAt) { [weak self] in
            guard let self, let v = self.window.contentView else { return }
            self.thanks.isHidden = false; self.rise(self.thanks)
            self.setButtons([("Replay", .secondary, { [weak self] () -> Void in self?.replay() }),
                             ("Contribute on GitHub", .secondary, { NSWorkspace.shared.open(URL(string: "https://github.com/amirdoescoding/byaku")!) }),
                             ("Done", .primary, { [weak self] () -> Void in self?.finish() })],
                            centered: true, y: Self.video.midY - 84, in: v)
            for (i, b) in self.buttons.enumerated() { b.alphaValue = 0; self.after(Double(i + 1) * Onb.buttonStagger) { self.rise(b) } }
            NSAccessibility.post(element: self.window, notification: .announcementRequested,
                                 userInfo: [.announcement: "Thanks for trying byaku.", .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
        after(Onb.idleAfter) { [weak self] in self?.mascot.idle(true) }
    }

    private func replay() {
        run += 1
        buttons.forEach { $0.removeFromSuperview() }; buttons = []
        thanks.isHidden = true; word.alphaValue = 0; mascot.idle(false)
        NSAnimationContext.runAnimationGroup { c in c.duration = Tokens.Motion.exit; scrim.animator().alphaValue = 0 }
        mascot.tint = Tokens.ink
        fly(mascot, to: corner, side: 28); Sfx.play(.whooshIn)
        player?.seek(to: .zero); player?.play()
    }

    /// Fade up and rise 8 pt (ease-out).
    private func rise(_ v: NSView?) {
        guard let v else { return }
        v.alphaValue = 1
        guard let l = v.layer ?? { v.wantsLayer = true; return v.layer }() else { return }
        animate(l, "opacity", from: 0, to: 1, duration: Onb.textRise)
        if !Tokens.Motion.reduced { animate(l, "transform.translation.y", from: -8, to: 0, duration: Onb.textRise) }
    }

    // MARK: finish

    /// Done, ×, Esc: stop everything; nothing runs after onboarding (no timers, no player, no overlay).
    func finish() {
        run += 1
        if scanning { scanning = false; onStopScan() }
        endScanView()
        mascot.idle(false)
        player?.pause(); playerView?.player = nil; player = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        overlay?.orderOut(nil); overlay = nil
        touring = false
        window.orderOut(nil)
        onDone()
    }
}

private final class OnboardingWindow: NSWindow {
    var onEsc: () -> Void = {}
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 480, height: 360), styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = true; isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        level = .floating  // an accessory app can't take focus from the front app (macOS 14 cooperative activation)
        collectionBehavior = [.moveToActiveSpace]
        let s = SurfaceView(frame: NSRect(x: 0, y: 0, width: 480, height: 360))
        s.autoresizingMask = [.width, .height]
        contentView = s
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override func cancelOperation(_ sender: Any?) { onEsc() }
}

// MARK: - CoachOverlay

/// A click-through, full-screen layer above the open menu: the flying mascot, docked beside the coach card.
private final class CoachOverlay: NSPanel {
    /// The tour's steps: row title → one line (≤ 70 chars). Copy from design/onboarding/mockups.html. Order is the menu's.
    static let coach: [String: String] = [
        "Guard": "Watches the camera. If someone else looks, you get a heads-up.",
        "Away": "Stepping away? If anyone looks, the alarm sounds and the Mac locks.",
        "Alarm sound": "Pick the sound the alarm plays. Choosing one plays a short preview.",
        "Message…": "Record a short line to speak over the alarm. Up to 8 seconds.",
        "Mode": "What Guard does besides the banner: nothing, violet edges, or a dim.",
        "Set up face…": "Saves a face print of you, so byaku knows who not to flag.",
        "Set up face again…": "Saves a new face print of you, so byaku knows who not to flag.",
    ]

    private let flyer = MascotView(side: 112)
    private let status: NSRect
    private var impatience: Timer?, frowning = false
    private var gone = false  // flown back or ordered out: pending arrival beats and the stress timer stay quiet
    private(set) var menuSeen = false

    /// Built invisible ahead of the tour (see tourIntro); begin() shows it.
    init(screen: NSScreen, status: NSRect) {
        self.status = status
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(NSWindow.Level.popUpMenu.rawValue + 1)  // above the open menu (spiked 2026-11-26)
        ignoresMouseEvents = true; isOpaque = false; backgroundColor = .clear; hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        let v = NSView(frame: NSRect(origin: .zero, size: screen.frame.size))
        v.wantsLayer = true
        contentView = v
        flyer.isHidden = true
        v.addSubview(flyer)
        alphaValue = 0
        orderFrontRegardless()
    }

    func begin(from start: NSRect, pose: MascotView.Pose) {
        flyer.frame = local(start)
        flyer.set(pose, Onb.snap)
        flyer.isHidden = false
        alphaValue = 1
        flyIn()
    }

    private func local(_ r: NSRect) -> NSRect { r.offsetBy(dx: -frame.minX, dy: -frame.minY) }

    /// The 40 pt mascot's spot (overlay coordinates): a gap left of the menu, level with the coach card at its top.
    private func dock(menuLeft: CGFloat, menuTop: CGFloat) -> CGPoint {
        CGPoint(x: menuLeft - Onb.dockGap - 40 - frame.minX, y: menuTop - 14 - 40 - frame.minY)
    }

    private func flyIn() {
        Sfx.play(.whooshIn)
        fly(flyer, to: dock(menuLeft: min(status.minX, frame.maxX - 300), menuTop: status.minY), side: 40)  // a guess until the menu is on screen
        flyer.set(MascotView.rest)
        // On arrival the brows lift (with their flick), then it turns to the menu. Common modes: the menu is open by then.
        let t = Timer(timeInterval: Onb.menuAfter, repeats: false) { [weak self] _ in
            guard let self, !self.gone else { return }
            self.flyer.set(MascotView.raise, Onb.raise); Sfx.play(.browUp)
            let back = Timer(timeInterval: Onb.smileHold, repeats: false) { [weak self] _ in
                guard let self, !self.gone else { return }
                self.flyer.set(MascotView.look(1, 0), Onb.look); self.flyer.idle(true); self.waitForNext()
            }
            RunLoop.main.add(back, forMode: .common)
        }
        RunLoop.main.add(t, forMode: .common)
    }

    func opened(_ menu: NSMenu) {
        menuSeen = true
        // The menu's window appears during this turn; find it a moment later and dock beside its top-left.
        let t = Timer(timeInterval: Onb.locate, repeats: false) { [weak self] _ in
            guard let self, !self.gone, let m = NSApp.windows.first(where: {
                $0.isVisible && $0 !== self && $0.level.rawValue >= NSWindow.Level.popUpMenu.rawValue })?.frame else { return }
            fly(self.flyer, to: self.dock(menuLeft: m.minX, menuTop: m.maxY), side: 40, x: Onb.follow, y: Onb.follow)
        }
        RunLoop.main.add(t, forMode: .common)
    }

    /// The menu closed on a stray click; it's about to reopen.
    func closed() { menuSeen = false }

    /// Next was pressed: a stressed mascot cheers up, and the wait starts over.
    func nudged() {
        if frowning { frowning = false; flyer.calm(); flyer.set(MascotView.look(1, 0), Onb.look); Sfx.play(.browUp) }
        flyer.keepBlinking()  // also starts it if the arrival beat didn't run
        waitForNext()
    }

    /// No Next for a while: the mascot gets stressed. The next press cheers it up; idle again, it stresses again.
    private func waitForNext() {
        impatience?.invalidate()
        guard !gone else { return }
        let t = Timer(timeInterval: Onb.impatient, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.frowning = true; self.flyer.stressed()
        }
        RunLoop.main.add(t, forMode: .common)
        impatience = t
    }

    override func orderOut(_ sender: Any?) { gone = true; impatience?.invalidate(); flyer.calm(); flyer.idle(false); super.orderOut(sender) }

    func flyBack(to r: NSRect) {
        gone = true; impatience?.invalidate(); flyer.calm(); flyer.idle(false)
        flyer.set(MascotView.rest)
        fly(flyer, to: local(r).origin, side: r.width)
        Sfx.play(.whooshOut)
    }
}
