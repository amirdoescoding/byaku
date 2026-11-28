import AppKit

// Components from docs/designs/menubar.md §6. Every prop is an enum; colours and timings come from Tokens.

// MARK: - StatusIcon

/// The brand mark (design/brand/final/menubar-template.svg, 56-unit viewBox at 4,4) with the per-state change.
enum StatusIcon {
    static func image(_ state: GuardState) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            // 16 pt mark centred in an 18 pt canvas; SVG units, y down.
            let t = NSAffineTransform()
            t.translateX(by: 1, yBy: 1); t.scale(by: 16 / 56); t.translateX(by: -4, yBy: -4)
            t.concat()
            (state == .off || state == .error ? NSColor.black : Tokens.accent).set()
            NSGraphicsContext.saveGraphicsState()
            if state == .error {  // knock out 1.5 units either side of the slash
                let clip = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64))
                clip.append(slash(width: 7.5))
                clip.windingRule = .evenOdd
                clip.addClip()
            }
            if state == .away {  // solid iris: the ring's outer disc (r 28) with the blades knocked out
                let iris = NSBezierPath(ovalIn: NSRect(x: 4, y: 4, width: 56, height: 56))
                blades.forEach(iris.append)
                iris.windingRule = .evenOdd
                iris.fill()
            } else {
                let ring = NSBezierPath(ovalIn: NSRect(x: 32 - 25.75, y: 32 - 25.75, width: 51.5, height: 51.5))
                ring.lineWidth = 4.5
                ring.stroke()
                blades.forEach { $0.fill() }
                if state == .alert || state == .alarm { NSBezierPath(ovalIn: NSRect(x: 26, y: 26, width: 12, height: 12)).fill() }
            }
            NSGraphicsContext.restoreGraphicsState()  // drops the knockout clip, keeps the transform
            if state == .error { slash(width: 4.5).fill() }
            return true
        }
        img.isTemplate = state == .off || state == .error  // violet states carry their own colour
        img.accessibilityDescription = label(state, reason: nil)
        return img
    }

    static func label(_ state: GuardState, reason: String?) -> String {
        switch state {
        case .off: "byaku, Guard off"
        case .guarding: "byaku, guarding, camera on"
        case .alert: "byaku, alert, someone else is looking"
        case .error: "byaku, not guarding, \(reason ?? "camera unavailable")"
        case .away: "byaku, away, locks if anyone looks"
        case .alarm: "byaku, alarm, someone looked while you were away"
        }
    }

    /// Slash along x+y=64, clipped to the ring's outer edge (r 28), as a filled band (butt caps).
    private static func slash(width w: CGFloat) -> NSBezierPath {
        let s = 28 / 2.0.squareRoot(), n = w / 2 / 2.0.squareRoot()  // n = half-width along the normal (1,1)/√2
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 32 - s + n, y: 32 + s + n))
        p.line(to: NSPoint(x: 32 + s + n, y: 32 - s + n))
        p.line(to: NSPoint(x: 32 + s - n, y: 32 - s - n))
        p.line(to: NSPoint(x: 32 - s - n, y: 32 + s - n))
        p.close()
        return p
    }

    /// The two blade crescents: an r 17 arc around the centre, closed by a wide SVG arc (polyline; exact at 16 pt).
    private static let blades: [NSBezierPath] = [
        crescent(NSPoint(x: 19.367, y: 43.375), NSPoint(x: 26.747, y: 15.832), back: 82.511),
        crescent(NSPoint(x: 40.500, y: 17.278), NSPoint(x: 47.975, y: 37.814), back: 100.374),
    ]

    static func crescent(_ a: NSPoint, _ b: NSPoint, back r: CGFloat) -> NSBezierPath {
        let p = NSBezierPath()
        p.move(to: a)
        svgArc(p, from: a, to: b, r: 17, sweep: true)
        svgArc(p, from: b, to: a, r: r, sweep: false)
        p.close()
        return p
    }

    /// SVG small arc (large-arc 0) from a to b, y-down; sweep = increasing angle (SVG spec F.6.5 centre).
    static func svgArc(_ p: NSBezierPath, from a: NSPoint, to b: NSPoint, r: CGFloat, sweep: Bool) {
        let mx = (a.x + b.x) / 2, my = (a.y + b.y) / 2, dx = b.x - a.x, dy = b.y - a.y, d = hypot(dx, dy)
        let h = (max(r * r - d * d / 4, 0)).squareRoot(), sign: CGFloat = sweep ? 1 : -1  // large-arc 0: sign = +1 iff large != sweep
        let c = NSPoint(x: mx + sign * h / d * (a.y - b.y), y: my + sign * h / d * (b.x - a.x))
        var t0 = atan2(a.y - c.y, a.x - c.x), t1 = atan2(b.y - c.y, b.x - c.x)
        if sweep, t1 < t0 { t1 += 2 * .pi }
        if !sweep, t1 > t0 { t1 -= 2 * .pi }
        for i in 1...24 {
            let t = t0 + (t1 - t0) * CGFloat(i) / 24
            p.line(to: NSPoint(x: c.x + r * cos(t), y: c.y + r * sin(t)))
        }
    }
}

// MARK: - shared layer helpers

/// Resolve dynamic Tokens for a view's current appearance.
func cg(_ c: NSColor, in v: NSView) -> CGColor {
    var out = c.cgColor
    v.effectiveAppearance.performAsCurrentDrawingAppearance { out = c.cgColor }
    return out
}

/// Explicit layer animation (backing layers of NSViews don't animate implicitly).
/// `from`: pass it when the start value was set in this same run-loop turn; presentation() still shows the old frame.
func animate(_ layer: CALayer, _ key: String, from: Any? = nil, to value: Any, duration: Double, timing: CAMediaTimingFunction = Tokens.Motion.easeOut) {
    let a = CABasicAnimation(keyPath: key)
    a.fromValue = from ?? layer.presentation()?.value(forKeyPath: key) ?? layer.value(forKeyPath: key)  // start from what's on screen
    a.toValue = value
    a.duration = duration
    a.timingFunction = timing
    layer.setValue(value, forKeyPath: key)
    layer.add(a, forKey: key)
}

/// Scale about a point (layer anchor stays at 0,0 for NSView backing layers).
func scale(_ s: CGFloat, about p: CGPoint) -> CATransform3D {
    CATransform3DTranslate(CATransform3DScale(CATransform3DMakeTranslation(p.x, p.y, 0), s, s, 1), -p.x, -p.y, 0)
}

// MARK: - ProgressRing

/// 48 pt ring: spinner while the camera starts, a drawn-on check, or a seam on failure.
final class ProgressRing: NSView {
    enum Phase: Equatable { case starting, done, failed }

    private let track = CAShapeLayer(), progress = CAShapeLayer(), spinner = CAShapeLayer(), check = CAShapeLayer()
    private(set) var phase = Phase.starting

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: frame.origin, size: NSSize(width: 48, height: 48)))
        wantsLayer = true
        let c = CGPoint(x: 24, y: 24)
        let full = CGMutablePath(); full.addArc(center: c, radius: 22, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        let quarter = CGMutablePath(); quarter.addArc(center: c, radius: 22, startAngle: .pi / 2, endAngle: 0, clockwise: true)
        let tick = CGMutablePath()  // y-up version of (15,25) (21,31) (33,18)
        tick.move(to: CGPoint(x: 15, y: 23)); tick.addLine(to: CGPoint(x: 21, y: 17)); tick.addLine(to: CGPoint(x: 33, y: 30))
        for (l, p, w) in [(track, full, 4.0), (progress, full, 4.0), (spinner, quarter, 4.0), (check, tick, 3.0)] as [(CAShapeLayer, CGPath, CGFloat)] {
            l.path = p; l.lineWidth = w; l.fillColor = nil; l.lineCap = .butt; l.frame = bounds
            layer!.addSublayer(l)
        }
        progress.strokeEnd = 0; check.strokeEnd = 0
        setAccessibilityElement(false)  // the panel announces phases in words
        set(.starting)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        track.strokeColor = cg(Tokens.line, in: self)
        let ink = cg(phase == .failed ? Tokens.mute : Tokens.ink, in: self)
        progress.strokeColor = ink; spinner.strokeColor = ink; check.strokeColor = ink
    }

    func set(_ new: Phase) {
        CATransaction.begin(); CATransaction.setDisableActions(true)  // only the explicit animations below may move
        defer { CATransaction.commit() }
        phase = new
        let reduced = Tokens.Motion.reduced
        spinner.isHidden = new != .starting
        spinner.removeAllAnimations()
        if new == .starting, !reduced {
            let r = CABasicAnimation(keyPath: "transform.rotation.z")  // rotation about the layer's anchor (its centre)
            r.byValue = -2 * CGFloat.pi; r.duration = Tokens.Motion.spinTurn; r.repeatCount = .infinity
            r.timingFunction = CAMediaTimingFunction(name: .linear)
            spinner.anchorPoint = CGPoint(x: 0.5, y: 0.5); spinner.position = CGPoint(x: 24, y: 24)
            spinner.add(r, forKey: "spin")
        }
        track.isHidden = new == .done || new == .failed
        check.strokeEnd = 0
        switch new {
        case .starting:
            progress.strokeStart = 0; progress.strokeEnd = 0
        case .done:
            progress.removeAllAnimations(); progress.strokeStart = 0; progress.strokeEnd = 1
            if reduced { check.strokeEnd = 1 } else { animate(check, "strokeEnd", to: 1, duration: Tokens.Motion.check) }
        case .failed:  // 30° seam centred at 12 o'clock
            progress.removeAllAnimations(); progress.strokeStart = 15.0 / 360; progress.strokeEnd = 345.0 / 360
        }
        recolor()
    }
}

// MARK: - WaveView

/// Message waves: 28 bars that scroll in from the right, one audio-level sample each, over a 1 pt line that fills with
/// time used (recording, of the 8 s cap) or played. Moves only with the audio, so Reduce Motion changes nothing.
final class WaveView: NSView {
    private static let count = 28, barWidth: CGFloat = 3, gap: CGFloat = 3, tall: CGFloat = 32
    static let size = NSSize(width: CGFloat(count) * (barWidth + gap) - gap, height: tall + 9)
    private var levels = [Float](repeating: 0, count: count)
    private let bars = (0..<count).map { _ in CALayer() }, track = CALayer(), fill = CALayer()
    private var progress: Double = 0

    override init(frame: NSRect) {
        super.init(frame: NSRect(origin: frame.origin, size: Self.size))
        wantsLayer = true
        for l in bars + [track, fill] { layer!.addSublayer(l) }
        bars.forEach { $0.cornerRadius = Self.barWidth / 2 }
        setAccessibilityElement(false)  // the panel announces phases in words
        recolor(); place()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// One sample: the newest bar's level and the line's fill, in one layout pass.
    func push(_ level: Float, progress: Double) { levels.removeFirst(); levels.append(level); self.progress = progress; place() }
    func reset() { levels = levels.map { _ in 0 }; progress = 0; place() }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let ink = cg(Tokens.ink, in: self)
        bars.forEach { $0.backgroundColor = ink }
        track.backgroundColor = cg(Tokens.line, in: self); fill.backgroundColor = ink
    }

    private func place() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        for (i, b) in bars.enumerated() {
            let h = max(Self.barWidth, CGFloat(levels[i]) * Self.tall)
            b.frame = CGRect(x: CGFloat(i) * (Self.barWidth + Self.gap), y: 9 + (Self.tall - h) / 2, width: Self.barWidth, height: h)
        }
        track.frame = CGRect(x: 0, y: 0, width: Self.size.width, height: 1)
        fill.frame = CGRect(x: 0, y: 0, width: Self.size.width * min(1, max(0, progress)), height: 1)
    }
}

// MARK: - PanelButton

/// The only button on custom surfaces: hover tint, press scale on mouse-down, violet focus ring.
final class PanelButton: NSButton {
    enum Role { case primary, secondary, close }  // close: a 24 pt × with no border (banner)
    var role: Role { didSet { restyle(animated: false) } }  // a held button keeps going across a relabel (primary ↔ secondary)
    var onPress: () -> Void
    /// Set = a hold button: true on press (mouse, Space, or VoiceOver's first press), false on release.
    var onHold: ((Bool) -> Void)?
    private(set) var held = false, toggled = false  // toggled: started by a press-to-toggle (VoiceOver), not a real hold
    private var hovering = false
    private let focus = CAShapeLayer()

    init(_ title: String, role: Role, onPress: @escaping () -> Void) {
        self.role = role; self.onPress = onPress
        super.init(frame: .zero)
        self.title = title
        isBordered = false; focusRingType = .none; wantsLayer = true
        target = self; action = #selector(fire)
        layer!.cornerRadius = 6; layer!.borderWidth = 1
        layer!.masksToBounds = false
        focus.fillColor = nil; focus.lineWidth = 2; focus.isHidden = true
        layer!.addSublayer(focus)
        if role == .close {
            image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
            imagePosition = .imageOnly
            setFrameSize(NSSize(width: 24, height: 24))
        }
        setAccessibilityLabel(role == .close ? "Close" : title)
        restyle(animated: false)  // the title didSet ran before the layer existed
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func fire() { onPress() }

    override var title: String {
        didSet {
            restyle(animated: false)
            guard role != .close else { return }
            setFrameSize(NSSize(width: max(80, ceil(attributedTitle.size().width) + 28), height: 32))
            setAccessibilityLabel(title)
        }
    }

    override func viewDidChangeEffectiveAppearance() { restyle(animated: false) }

    override func layout() {
        super.layout()
        focus.frame = bounds
        focus.path = CGPath(roundedRect: bounds.insetBy(dx: -3, dy: -3), cornerWidth: 8, cornerHeight: 8, transform: nil)
    }

    private func restyle(animated: Bool) {
        var fill = NSColor.clear, border = NSColor.clear, text = NSColor.clear
        effectiveAppearance.performAsCurrentDrawingAppearance { [self] in (fill, border, text) = colors() }
        attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: text,
            .paragraphStyle: { let p = NSMutableParagraphStyle(); p.alignment = .center; return p }()])
        contentTintColor = text  // the close role's symbol
        guard let l = layer else { return }
        focus.strokeColor = cg(Tokens.accent, in: self)
        if animated {
            animate(l, "backgroundColor", to: fill.cgColor, duration: Tokens.Motion.hover)
            animate(l, "borderColor", to: border.cgColor, duration: Tokens.Motion.hover)
        } else {
            l.backgroundColor = fill.cgColor; l.borderColor = border.cgColor
        }
    }

    /// Role × hover → (fill, border, text). Call inside the view's drawing appearance (blends resolve there).
    private func colors() -> (NSColor, NSColor, NSColor) {
        let ink = Tokens.ink.usingColorSpace(.sRGB)!, bgc = Tokens.bg.usingColorSpace(.sRGB)!
        let fill: NSColor, border: NSColor, text: NSColor
        switch role {
        case .primary:
            fill = hovering ? ink.blended(withFraction: 0.14, of: bgc) ?? ink : ink
            border = fill; text = bgc
        case .secondary:
            fill = hovering ? ink.withAlphaComponent(0.06) : .clear
            let line = Tokens.line.usingColorSpace(.sRGB)!
            border = hovering ? line.blended(withFraction: 0.22, of: ink) ?? line : line
            text = ink
        case .close:
            fill = hovering ? ink.withAlphaComponent(0.06) : .clear
            border = .clear
            text = hovering ? ink : Tokens.mute.usingColorSpace(.sRGB)!
        }
        return (fill, border, text)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseEntered(with e: NSEvent) { hovering = true; restyle(animated: true) }
    override func mouseExited(with e: NSEvent) { hovering = false; restyle(animated: true) }

    private func pressed(_ down: Bool) {
        guard let l = layer, !Tokens.Motion.reduced else { return }
        let t = down ? scale(Tokens.Motion.pressScale, about: CGPoint(x: bounds.midX, y: bounds.midY)) : CATransform3DIdentity
        animate(l, "transform", to: t, duration: down ? Tokens.Motion.press : Tokens.Motion.release)
    }

    /// Feedback on press, not release. super runs the tracking loop until mouse-up, then fires the action.
    /// A hold button tracks mouse-up itself, polling so `drop()` can end the loop (the panel moved on without a release).
    override func mouseDown(with e: NSEvent) {
        guard onHold != nil else { pressed(true); super.mouseDown(with: e); pressed(false); return }
        guard let w = window else { return }
        hold()
        while held {  // other keys are swallowed while the mouse holds; Esc cancels (drops the take) like everywhere else
            guard let e = w.nextEvent(matching: [.leftMouseUp, .keyDown], until: Date(timeIntervalSinceNow: Tokens.Motion.meterStep),
                                      inMode: .eventTracking, dequeue: true) else { continue }
            if e.type == .leftMouseUp { break }
            if e.keyCode == 53 { drop(); w.cancelOperation(nil) }
        }
        release()
    }

    private static let holdKeys: Set<UInt16> = [49]  // Space; Return stays the panel's default button
    override func keyDown(with e: NSEvent) {
        if held, !toggled, e.keyCode != 53, !Self.holdKeys.contains(e.keyCode) { return }  // Tab mid-hold would strand the key-up
        guard onHold != nil, Self.holdKeys.contains(e.keyCode) else { return super.keyDown(with: e) }
        if !e.isARepeat { hold() }
    }
    override func keyUp(with e: NSEvent) {
        guard onHold != nil, Self.holdKeys.contains(e.keyCode) else { return super.keyUp(with: e) }
        release()
    }

    private func hold(toggle: Bool = false) { guard !held else { return }; held = true; toggled = toggle; pressed(true); onHold?(true) }
    private func release() { guard held else { return }; held = false; pressed(false); onHold?(false) }
    /// The hold ended elsewhere (the cap, a failure): let go without reporting a release.
    func drop() { guard held else { return }; held = false; pressed(false) }

    /// Return / Esc / VoiceOver press: the same feedback, then the action. A hold button toggles (VoiceOver can't hold).
    override func performClick(_ sender: Any?) {
        if onHold != nil { held ? release() : hold(toggle: true); return }
        pressed(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.press) { [weak self] in self?.pressed(false); self?.superClick(sender) }
    }
    private func superClick(_ sender: Any?) { super.performClick(sender) }

    override var acceptsFirstResponder: Bool { true }
    /// Click through on first press: the banner never becomes key and the accessory app is never active.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func becomeFirstResponder() -> Bool {
        focus.isHidden = NSApp.currentEvent?.type != .keyDown  // focus = seen: only when the keyboard put it here
        return super.becomeFirstResponder()
    }
    override func resignFirstResponder() -> Bool { focus.isHidden = true; return super.resignFirstResponder() }
}

// MARK: - AnchoredPanel

/// A borderless panel that grows from its trigger (the status item) and shrinks back into it (menubar.md §5).
class AnchoredPanel: NSPanel {
    private var origin = CGPoint.zero  // the trigger, in content coordinates

    init(size: NSSize, level: NSWindow.Level) {
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true; self.level = level; hidesOnDeactivate = false
        backgroundColor = .clear; isOpaque = false; hasShadow = true
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]  // show on the Space the user is on
        isReleasedWhenClosed = false
        contentView = SurfaceView(frame: NSRect(origin: .zero, size: size))
    }

    func present(below button: NSStatusBarButton) {
        guard let bw = button.window, let screen = bw.screen ?? NSScreen.main else { return }
        let icon = bw.convertToScreen(button.convert(button.bounds, to: nil))
        let vis = screen.visibleFrame
        let x = min(max(icon.midX - frame.width / 2, vis.minX + 8), vis.maxX - 8 - frame.width)
        setFrameOrigin(NSPoint(x: x, y: icon.minY - 8 - frame.height))
        origin = CGPoint(x: icon.midX - x, y: frame.height + 8)  // the icon's bottom centre, just above the panel
        let l = contentView!.layer!
        if isVisible, alphaValue == 1 { if canBecomeKey { makeKey() }; return }
        alphaValue = 0
        let start = Tokens.Motion.reduced ? CATransform3DIdentity : scale(Tokens.Motion.enterScale, about: origin)
        l.transform = start
        orderFrontRegardless(); if canBecomeKey { makeKey() }
        NSAnimationContext.runAnimationGroup { c in
            c.duration = Tokens.Motion.enter; c.timingFunction = Tokens.Motion.easeOut
            animator().alphaValue = 1
        }
        animate(l, "transform", from: start, to: CATransform3DIdentity, duration: Tokens.Motion.enter)
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.enter) { [weak self] in self?.invalidateShadow() }
    }

    /// Shrink back into the icon, then order out.
    func dismiss() {
        guard isVisible else { return }
        if !Tokens.Motion.reduced { animate(contentView!.layer!, "transform", to: scale(Tokens.Motion.enterScale, about: origin), duration: Tokens.Motion.exit) }
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = Tokens.Motion.exit; c.timingFunction = Tokens.Motion.easeOut
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in if self?.alphaValue == 0 { self?.orderOut(nil) } })
    }
}

// MARK: - CardPanel

/// The 160 pt tall panel card shared by Set up face and Message: a 48 pt glyph slot (ring), title + body, a right-aligned
/// button row. Subclasses map their phases onto render(). Optional: waves in place of the body, and one hold button.
class CardPanel: AnchoredPanel {
    typealias Spec = (String, PanelButton.Role, () -> Void)
    var onCancel: () -> Void = {}
    var onHold: (Bool) -> Void = { _ in }
    let ring = ProgressRing(frame: NSRect(x: 24, y: 84, width: 48, height: 48))
    let waves = WaveView(frame: NSRect(x: 88, y: 78, width: 0, height: 0))
    private let titleLabel = NSTextField(labelWithString: ""), body = NSTextField(wrappingLabelWithString: "")
    private var buttons: [PanelButton] = []
    private let width: CGFloat

    /// `closable`: a × in the top-right corner (presses onCancel), for panels that wait on the user (Message).
    init(width: CGFloat, title: String, closable: Bool = false) {
        self.width = width
        super.init(size: NSSize(width: width, height: 160), level: .statusBar)
        setAccessibilityTitle(title)
        let v = contentView!
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: 88, y: 116, width: width - 112 - (closable ? 16 : 0), height: 20)
        body.font = .systemFont(ofSize: 12); body.maximumNumberOfLines = 2
        body.frame = NSRect(x: 88, y: 80, width: width - 112, height: 32)
        waves.isHidden = true
        [ring, titleLabel, body, waves].forEach(v.addSubview)
        if closable {
            let close = PanelButton("", role: .close) { [weak self] in self?.onCancel() }
            close.setFrameOrigin(NSPoint(x: width - 12 - 24, y: 160 - 12 - 24))
            v.addSubview(close)
        }
    }

    override var canBecomeKey: Bool { true }  // Esc and VoiceOver; nonactivating, so the user's app keeps focus
    /// Another app took focus mid-hold: its key-up will never come here, so the take is dropped like a Cancel.
    /// A VoiceOver toggle needs no key-up, so it carries on.
    override func resignKey() { super.resignKey(); if buttons.contains(where: { $0.held && !$0.toggled }) { onCancel() } }
    /// Let go of any hold without reporting a release (the panel is closing).
    func letGo() { buttons.forEach { $0.drop() } }
    /// The hold in progress came from a press-to-toggle (VoiceOver), so it ends with a second press, not a release.
    var holdIsToggle: Bool { buttons.contains { $0.held && $0.toggled } }
    /// Esc presses the visible Cancel/Done/Stop button, so it gets the same press feedback.
    override func cancelOperation(_ sender: Any?) {
        if let b = buttons.first(where: { ["Cancel", "Done", "Stop"].contains($0.title) }) { b.performClick(nil) } else { onCancel() }
    }

    /// `hold`: the title of the button that reports press/release to onHold. `holding`: a hold in progress may carry on;
    /// otherwise any held button lets go. `showWaves`: the waves take the body's place.
    func render(_ ringPhase: ProgressRing.Phase, _ title: String, _ text: String, _ specs: [Spec], announce: String?,
                hold: String? = nil, holding: Bool = false, showWaves: Bool = false) {
        ring.set(ringPhase)
        titleLabel.textColor = Tokens.ink; body.textColor = Tokens.mute
        titleLabel.stringValue = title; body.stringValue = text
        body.isHidden = showWaves; waves.isHidden = !showWaves
        // A lone title sits on the ring's centre line; with a body (or waves), the pair fills the 56 pt row.
        titleLabel.setFrameOrigin(NSPoint(x: 88, y: showWaves ? 122 : text.isEmpty ? 98 : 116))  // waves: the block centres on the glyph
        if buttons.map(\.title) != specs.map(\.0) {  // same buttons across re-renders (keeps hover state)
            // The button being held survives its relabel (same view, still first responder), so its release still lands.
            let kept = buttons.first { $0.held }
            buttons = specs.map { t, role, act in
                if t == hold, let kept { kept.role = role; kept.title = t; return kept }
                let b = PanelButton(t, role: role) { act() }
                if t == hold {
                    b.onHold = { [weak self] in self?.onHold($0) }
                    b.setAccessibilityHelp("Press to start recording, press again to save.")
                }
                return b
            }
            contentView!.subviews.forEach { v in
                if let b = v as? PanelButton, b.role != .close, !buttons.contains(where: { $0 === b }) { b.drop(); b.removeFromSuperview() }
            }
            var x = width - 24
            for b in buttons.reversed() {
                x -= b.frame.width; b.setFrameOrigin(NSPoint(x: x, y: 24)); x -= 8
                if b.superview == nil { contentView!.addSubview(b) }
            }
            // Return; focus ring stays off until the keyboard moves focus. A hold button takes focus, so Space holds it.
            buttons.forEach { $0.keyEquivalent = "" }
            buttons.last { $0.role == .primary && $0.onHold == nil }?.keyEquivalent = "\r"
            if let h = buttons.first(where: { $0.onHold != nil }), firstResponder !== h { makeFirstResponder(h) }
        } else {
            for (b, s) in zip(buttons, specs) { b.onPress = s.2 }  // same titles, fresh actions
        }
        if !holding { buttons.forEach { $0.drop() } }
        if let announce {
            NSAccessibility.post(element: self, notification: .announcementRequested,
                                 userInfo: [.announcement: announce, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
    }
}

// MARK: - EnrollPanel

/// Set-up-face panel: the guided scan (compact ScanView) and a button row. Grows from its trigger (the status item) and
/// shrinks back into it. The camera shows only at the start of the scan, then the mask alone (docs/designs/face-scan.md).
final class EnrollPanel: AnchoredPanel {
    typealias Spec = CardPanel.Spec
    enum Phase: Equatable { case starting, saved, noFace, severalFaces, cameraDenied, failed(String) }
    static let size = NSSize(width: 360, height: 352)

    var onCancel: () -> Void = {}, onRetry: () -> Void = {}, onOpenSettings: () -> Void = {}
    let scan = ScanView(frame: NSRect(origin: .zero, size: size), compact: true)
    private var buttons: [PanelButton] = []
    private var autoClose: DispatchWorkItem?

    init() {
        super.init(size: Self.size, level: .statusBar)
        setAccessibilityTitle("Set up face")
        contentView!.addSubview(scan)
    }

    override var canBecomeKey: Bool { true }  // Esc and VoiceOver; nonactivating, so the user's app keeps focus
    override func cancelOperation(_ sender: Any?) {
        if let b = buttons.first(where: { ["Cancel", "Done"].contains($0.title) }) { b.performClick(nil) } else { onCancel() }
    }
    override func dismiss() { autoClose?.cancel(); scan.stop(); super.dismiss() }

    /// Title and body per outcome; the onboarding window's scan shows the same words.
    static func copy(_ p: Phase) -> (String, String) {
        switch p {
        case .starting: ("Starting camera…", "")
        case .saved: ("Face saved", "Stored on this Mac only. Delete it any time from the menu.")
        case .noFace: ("No face seen", "Face the screen in good light, then try again.")
        case .severalFaces: ("More than one face", "Only you should be in view. Try again when you're alone.")
        case .cameraDenied: ("Camera access is off", "Allow byaku in System Settings, then try again.")
        case .failed(let why): ("Couldn't set up face", why)
        }
    }

    func show(_ p: Phase) {
        autoClose?.cancel()
        let cancel = ("Cancel", PanelButton.Role.secondary, onCancel), retry = ("Try again", PanelButton.Role.primary, onRetry)
        switch p {
        case .starting: scan.start(); setButtons([cancel])
        case .saved:
            scan.saved(); setButtons([("Done", .primary, onCancel)])
            let w = DispatchWorkItem { [weak self] in self?.onCancel() }
            autoClose = w
            DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.autoClose, execute: w)
        case .noFace, .severalFaces, .failed: scan.fail(p); setButtons([cancel, retry])
        case .cameraDenied: scan.fail(p); setButtons([cancel, ("Open camera settings…", .primary, onOpenSettings)])
        }
    }

    private func setButtons(_ specs: [Spec]) {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = specs.map { t, role, act in PanelButton(t, role: role) { act() } }
        var x = Self.size.width - 24
        for b in buttons.reversed() { x -= b.frame.width; b.setFrameOrigin(NSPoint(x: x, y: 24)); x -= 8; contentView!.addSubview(b) }
        buttons.last { $0.role == .primary }?.keyEquivalent = "\r"
    }
}

// MARK: - MessagePanel

/// Away message panel (docs/designs/away-mode.md §Message): hold to record (up to 8 s), let go to save; play it back,
/// record again, delete. Waves follow the voice while recording and the file while playing; there is no countdown.
/// Wider than EnrollPanel so Delete / Hold to record / Play fit on one row.
final class MessagePanel: CardPanel {
    /// `short`/`failed` carry the saved message's length (nil = none), so its Play and Delete stay.
    enum Phase: Equatable { case idle, requesting, recording, recorded(Int), playing, denied, short(Int?), failed(String, Int?) }

    var onStop: () -> Void = {}, onPlay: () -> Void = {}, onDelete: () -> Void = {}, onOpenSettings: () -> Void = {}
    private let mic = NSImageView()
    private(set) var phase: Phase?

    init() {
        super.init(width: 352, title: "Alarm message", closable: true)
        mic.image = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 24, weight: .regular))
        mic.contentTintColor = Tokens.ink
        mic.frame = ring.frame
        mic.setAccessibilityElement(false)
        contentView!.addSubview(mic)
    }

    func show(_ p: Phase) {
        let first = p != phase
        phase = p
        let none: () -> Void = {}  // a hold button acts through onHold, not its click
        let holdTitle = "Hold to record", releaseTitle = "Release to save"  // render() finds the hold button by title
        let hidden = ProgressRing.Phase.failed  // the ring is hidden behind the mic in these phases
        let cancel = ("Cancel", PanelButton.Role.secondary, onCancel), hold = (holdTitle, PanelButton.Role.primary, none)
        let saved = { (s: Int) -> [Spec] in [("Delete", .secondary, self.onDelete), (holdTitle, .secondary, none), ("Play", .primary, self.onPlay)] }
        let retry = { (s: Int?) -> [Spec] in s.map(saved) ?? [cancel, hold] }
        let kept = { (s: Int?) -> String in s == nil ? "" : " Your saved message is unchanged." }
        let max = Int(Tokens.Away.messageSeconds)
        let (ringPhase, title, text, specs): (ProgressRing.Phase, String, String, [Spec]) = switch p {
        case .idle: (.failed, "Record a message", "Hold the button and speak. Up to \(max) s.", [cancel, hold])
        case .requesting: (.starting, "Waiting for microphone…", "Choose Allow in the system prompt.", [cancel])
        case .recording: (hidden, "Recording…", "", [(releaseTitle, .primary, none)])
        case .recorded(let s): (.done, "Message saved", "\(s) s. Stored on this Mac only.", saved(s))
        case .playing: (hidden, "Playing…", "", [("Stop", .primary, onStop)])
        case .denied: (.failed, "Microphone access is off", "Allow byaku in System Settings, then try again.",
                       [cancel, ("Open microphone settings…", .primary, onOpenSettings)])
        case .short(let s): (.failed, "Too short", "Hold the button while you speak." + kept(s), retry(s))
        case .failed(let why, let s): (.failed, "Couldn't record", why + kept(s), retry(s))
        }
        let announce: String? = switch p {
        case _ where !first, .idle: nil
        case .requesting: "\(title) \(text)"
        case .recording: holdIsToggle ? "Recording, up to \(max) seconds. Press again to save." : "Recording."
        case .recorded(let s): "Message saved, \(s) seconds. Stored on this Mac only."
        case .playing: "Playing."
        default: "\(title). \(text)"
        }
        let live = p == .recording || p == .playing
        if live, first { waves.reset() }
        mic.isHidden = !(p == .idle || live); ring.isHidden = !mic.isHidden
        render(ringPhase, title, text, specs, announce: announce,
               hold: p == .recording ? releaseTitle : holdTitle, holding: p == .recording, showWaves: live)
    }

    /// One waves sample: level 0…1, progress 0…1 (time used of the cap, or played).
    func meter(level: Float, progress: Double) { waves.push(level, progress: progress) }

    /// Delete returns to idle; VoiceOver hears what plays now.
    func deleted() {
        show(.idle)
        NSAccessibility.post(element: self, notification: .announcementRequested,
                             userInfo: [.announcement: "Message deleted. The spoken line is used.", .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}

/// Panel surface: `surface` fill, 1 pt `line` border, 12 pt radius.
final class SurfaceView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer!.cornerRadius = 12; layer!.borderWidth = 1; layer!.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer!.backgroundColor = cg(Tokens.surface, in: self)
        layer!.borderColor = cg(Tokens.line, in: self)
    }
}

// MARK: - SoundRow

/// One row of the Alarm sound submenu: checkmark + name, drawn like a menu item. A custom view because a click on a
/// plain NSMenuItem closes the menu; this one picks and previews and the menu stays open (iPhone alarm picker style).
final class SoundRow: NSView {
    let name: String, title: String
    var checked: Bool { didSet { needsDisplay = true; setAccessibilitySelected(checked) } }
    var onPick: (SoundRow) -> Void = { _ in }

    init(name: String, title: String, checked: Bool) {
        self.name = name; self.title = title; self.checked = checked
        super.init(frame: NSRect(x: 0, y: 0, width: 168, height: 22))
        setAccessibilityElement(true); setAccessibilityRole(.menuItem); setAccessibilityLabel(title)
        setAccessibilitySelected(checked)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirty: NSRect) {
        let lit = enclosingMenuItem?.isHighlighted == true  // the menu redraws the view when the highlight moves
        if lit {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 4, yRadius: 4).fill()
        }
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.menuFont(ofSize: 0),
                                                    .foregroundColor: lit ? NSColor.selectedMenuItemTextColor : NSColor.labelColor]
        if checked { ("✓" as NSString).draw(at: NSPoint(x: 11, y: 3), withAttributes: attrs) }
        (title as NSString).draw(at: NSPoint(x: 26, y: 3), withAttributes: attrs)
    }

    override func mouseUp(with event: NSEvent) { onPick(self) }
    override func accessibilityPerformPress() -> Bool { onPick(self); return true }
}

// MARK: - VolumeSlider

/// "Alarm volume" row inside the NSMenu (docs/designs/away-mode.md §Volume): Control Center Sound style. A 24 pt pill,
/// filled up to a white knob that carries the speaker glyph. Range Tokens.Away.minVolume…1: the alarm is never silent.
/// `onCommit` fires on mouse-up (and per VoiceOver step) with the final value.
final class VolumeSlider: NSView {
    var onCommit: (Float) -> Void = { _ in }
    /// The onboarding tour dims the row and takes it out of play: clicks fall through to the (disabled) item.
    var inert = false { didSet { alphaValue = inert ? Tokens.Onboarding.dimmed : 1 } }
    private(set) var value: Float
    private let pad = NSEdgeInsets(top: 6, left: 23, bottom: 8, right: 13), knob: CGFloat = 24
    private let title = NSTextField(labelWithString: "Alarm volume")

    init(value: Float, width: CGFloat = 270) {
        self.value = value
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 6 + 16 + 6 + 24 + 8))
        autoresizingMask = .width
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: pad.left, y: bounds.height - pad.top - 16, width: 200, height: 16)
        title.setAccessibilityElement(false)
        addSubview(title)
        setAccessibilityElement(true); setAccessibilityRole(.slider); setAccessibilityLabel("Alarm volume")
    }
    required init?(coder: NSCoder) { fatalError() }

    private var track: NSRect { NSRect(x: pad.left, y: pad.bottom, width: bounds.width - pad.left - pad.right, height: knob) }
    private var frac: CGFloat { CGFloat((value - Tokens.Away.minVolume) / (1 - Tokens.Away.minVolume)) }

    override func draw(_ dirty: NSRect) {
        let t = track, x = t.minX + frac * (t.width - knob)
        Tokens.Away.sliderTrack.setFill()
        NSBezierPath(roundedRect: t, xRadius: knob / 2, yRadius: knob / 2).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: NSRect(x: t.minX, y: t.minY, width: x - t.minX + knob, height: knob), xRadius: knob / 2, yRadius: knob / 2).fill()
        let k = NSRect(x: x, y: t.minY, width: knob, height: knob)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow(); sh.shadowBlurRadius = 3; sh.shadowOffset = NSSize(width: 0, height: -1)
        sh.shadowColor = Tokens.Away.knobShadow; sh.set()
        NSBezierPath(ovalIn: k).fill()
        NSGraphicsContext.restoreGraphicsState()
        let name = value > 0.6 ? "speaker.wave.3.fill" : value > 0.35 ? "speaker.wave.2.fill" : "speaker.wave.1.fill"
        let cfg = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold).applying(.init(paletteColors: [Tokens.Away.knobGlyph]))
        if let g = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
            g.draw(in: NSRect(x: k.midX - g.size.width / 2, y: k.midY - g.size.height / 2, width: g.size.width, height: g.size.height))
        }
    }

    private func set(fromX px: CGFloat) {
        let t = track, f = min(max((px - t.minX - knob / 2) / (t.width - knob), 0), 1)
        value = Tokens.Away.minVolume + Float(f) * (1 - Tokens.Away.minVolume)
        setAccessibilityValue("\(Int((value * 100).rounded())) percent")
        needsDisplay = true
    }

    override func hitTest(_ p: NSPoint) -> NSView? { inert ? nil : super.hitTest(p) }
    override func mouseDown(with e: NSEvent) { set(fromX: convert(e.locationInWindow, from: nil).x) }
    override func mouseDragged(with e: NSEvent) { set(fromX: convert(e.locationInWindow, from: nil).x) }
    override func mouseUp(with e: NSEvent) { set(fromX: convert(e.locationInWindow, from: nil).x); onCommit(value) }

    override func accessibilityPerformIncrement() -> Bool { step(0.25) }
    override func accessibilityPerformDecrement() -> Bool { step(-0.25) }
    private func step(_ d: Float) -> Bool {
        value = min(max(value + d, Tokens.Away.minVolume), 1); needsDisplay = true
        setAccessibilityValue("\(Int((value * 100).rounded())) percent"); onCommit(value)
        return true
    }
}

// MARK: - CoachRow

/// The onboarding tour's card: the status menu's first item while touring (docs/designs/onboarding.md §3). It's a custom
/// view, like SoundRow, so Next and Skip tour keep the menu open (a plain item always closes it).
final class CoachRow: NSView {
    var onNext: () -> Void = {}, onSkip: () -> Void = {}
    private let name = NSTextField(labelWithString: ""), key = NSTextField(labelWithString: "")
    private let line = NSTextField(wrappingLabelWithString: ""), count = NSTextField(labelWithString: "")
    private var buttons: [PanelButton] = []
    private static let left: CGFloat = 22, right: CGFloat = 14  // text lines up with the menu's row titles

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 300, height: 112))
        autoresizingMask = .width
        name.font = .systemFont(ofSize: 13, weight: .semibold); name.textColor = Tokens.ink
        key.font = .systemFont(ofSize: 12); key.textColor = Tokens.mute
        line.font = .systemFont(ofSize: 12); line.textColor = Tokens.mute; line.maximumNumberOfLines = 2
        count.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular); count.textColor = Tokens.mute
        [name, key, line, count].forEach { addSubview($0); $0.setAccessibilityElement(false) }
    }
    required init?(coder: NSCoder) { fatalError() }

    /// One step: the row's name and shortcut, its line, "n of total", and [Skip tour] [Next] (Finish on the last).
    func show(_ title: String, shortcut: String, _ text: String, step: Int, of total: Int) {
        let w = bounds.width, h = bounds.height
        name.stringValue = title; name.sizeToFit()
        name.setFrameOrigin(NSPoint(x: Self.left, y: h - 8 - name.frame.height))
        key.stringValue = shortcut; key.sizeToFit()
        key.setFrameOrigin(NSPoint(x: name.frame.maxX + 6, y: name.frame.minY + 1))
        line.stringValue = text
        line.frame = NSRect(x: Self.left, y: name.frame.minY - 4 - 32, width: w - Self.left - Self.right, height: 32)
        count.stringValue = "\(step) of \(total)"; count.sizeToFit()
        buttons.forEach { $0.removeFromSuperview() }
        buttons = [PanelButton("Skip tour", role: .secondary) { [weak self] in self?.onSkip() },
                   PanelButton(step == total ? "Finish" : "Next", role: .primary) { [weak self] in self?.onNext() }]
        var x = w - Self.right
        for b in buttons.reversed() {
            b.setFrameSize(NSSize(width: b.frame.width, height: 28))
            x -= b.frame.width; b.setFrameOrigin(NSPoint(x: x, y: 10)); x -= 6
            addSubview(b)
        }
        count.setFrameOrigin(NSPoint(x: Self.left, y: 10 + (28 - count.frame.height) / 2))
    }
}
