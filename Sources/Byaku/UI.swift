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
            (state == .guarding || state == .alert ? Tokens.accent : NSColor.black).set()
            NSGraphicsContext.saveGraphicsState()
            if state == .error {  // knock out 1.5 units either side of the slash
                let clip = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64))
                clip.append(slash(width: 7.5))
                clip.windingRule = .evenOdd
                clip.addClip()
            }
            let ring = NSBezierPath(ovalIn: NSRect(x: 32 - 25.75, y: 32 - 25.75, width: 51.5, height: 51.5))
            ring.lineWidth = 4.5
            ring.stroke()
            blades.forEach { $0.fill() }
            if state == .alert { NSBezierPath(ovalIn: NSRect(x: 26, y: 26, width: 12, height: 12)).fill() }
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

    private static func crescent(_ a: NSPoint, _ b: NSPoint, back r: CGFloat) -> NSBezierPath {
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

/// 48 pt ring: spinner while the camera starts, a 5 s countdown, a drawn-on check, or a seam on failure.
final class ProgressRing: NSView {
    enum Phase: Equatable { case starting, counting(remaining: Int), done, failed }

    private let track = CAShapeLayer(), progress = CAShapeLayer(), spinner = CAShapeLayer(), check = CAShapeLayer()
    private let number = NSTextField(labelWithString: "")
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
        number.font = .monospacedDigitSystemFont(ofSize: 20, weight: .semibold)
        number.alignment = .center
        number.setAccessibilityElement(false)
        number.frame = NSRect(x: 0, y: 12, width: 48, height: 24)
        addSubview(number)
        setAccessibilityElement(false)  // the panel announces phases in words
        set(.starting)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        track.strokeColor = cg(Tokens.line, in: self)
        let ink = cg(phase == .failed ? Tokens.mute : Tokens.ink, in: self)
        progress.strokeColor = ink; spinner.strokeColor = ink; check.strokeColor = ink
        number.textColor = Tokens.ink
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
        number.stringValue = ""
        check.strokeEnd = 0
        switch new {
        case .starting:
            progress.strokeStart = 0; progress.strokeEnd = 0
        case .counting(let r):
            number.stringValue = "\(r)"
            progress.strokeStart = 0
            let to = CGFloat(6 - r) / 5  // the ring reaches the next fifth as this second runs out
            if reduced { progress.removeAllAnimations(); progress.strokeEnd = CGFloat(5 - r) / 5 }
            else { animate(progress, "strokeEnd", to: to, duration: Tokens.Motion.countStep, timing: CAMediaTimingFunction(name: .linear)) }
        case .done:
            progress.removeAllAnimations(); progress.strokeStart = 0; progress.strokeEnd = 1
            if reduced { check.strokeEnd = 1 } else { animate(check, "strokeEnd", to: 1, duration: Tokens.Motion.check) }
        case .failed:  // 30° seam centred at 12 o'clock
            progress.removeAllAnimations(); progress.strokeStart = 15.0 / 360; progress.strokeEnd = 345.0 / 360
        }
        recolor()
    }
}

// MARK: - PanelButton

/// The only button on custom surfaces: hover tint, press scale on mouse-down, violet focus ring.
final class PanelButton: NSButton {
    enum Role { case primary, secondary, close }  // close: a 24 pt × with no border (banner)
    let role: Role
    private let onPress: () -> Void
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
        } else {
            setFrameSize(NSSize(width: max(80, ceil(attributedTitle.size().width) + 28), height: 32))
        }
        setAccessibilityLabel(role == .close ? "Close" : title)
        restyle(animated: false)  // the title didSet ran before the layer existed
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func fire() { onPress() }

    override var title: String { didSet { restyle(animated: false) } }

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
    override func mouseDown(with e: NSEvent) { pressed(true); super.mouseDown(with: e); pressed(false) }

    /// Return / Esc / VoiceOver press: the same feedback, then the action.
    override func performClick(_ sender: Any?) {
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

// MARK: - EnrollPanel

/// Set-up-face panel. Grows from its trigger (the status item) and shrinks back into it. No camera preview, ever.
final class EnrollPanel: AnchoredPanel {
    enum Phase: Equatable { case starting, counting(Int), saved, noFace, severalFaces, cameraDenied, failed(String) }

    var onCancel: () -> Void = {}, onRetry: () -> Void = {}, onOpenSettings: () -> Void = {}
    private let ring = ProgressRing(frame: NSRect(x: 24, y: 84, width: 48, height: 48))
    private let titleLabel = NSTextField(labelWithString: ""), body = NSTextField(wrappingLabelWithString: "")
    private var buttons: [PanelButton] = []
    private var autoClose: DispatchWorkItem?

    init() {
        super.init(size: NSSize(width: 320, height: 160), level: .statusBar)
        setAccessibilityTitle("Set up face")
        let v = contentView!
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: 88, y: 116, width: 208, height: 20)
        body.font = .systemFont(ofSize: 12); body.maximumNumberOfLines = 2
        body.frame = NSRect(x: 88, y: 80, width: 208, height: 32)
        [ring, titleLabel, body].forEach(v.addSubview)
    }

    override var canBecomeKey: Bool { true }  // Esc and VoiceOver; nonactivating, so the user's app keeps focus
    override func dismiss() { autoClose?.cancel(); super.dismiss() }
    /// Esc presses the visible Cancel/Done button, so it gets the same press feedback.
    override func cancelOperation(_ sender: Any?) {
        if let b = buttons.first(where: { $0.title == "Cancel" || $0.title == "Done" }) { b.performClick(nil) } else { onCancel() }
    }

    func show(_ p: Phase) {
        autoClose?.cancel()
        let cancel = ("Cancel", PanelButton.Role.secondary, onCancel), retry = ("Try again", PanelButton.Role.primary, onRetry)
        let (ringPhase, title, text, specs): (ProgressRing.Phase, String, String, [(String, PanelButton.Role, () -> Void)]) = switch p {
        case .starting: (.starting, "Starting camera…", "", [cancel])
        case .counting(let r): (.counting(remaining: r), "Look at the screen",
                                "Be the only person in view. Nothing is saved except a face print.", [cancel])
        case .saved: (.done, "Face saved", "Stored on this Mac only. Delete it any time from the menu.", [("Done", .primary, onCancel)])
        case .noFace: (.failed, "No face seen", "Face the screen in good light, then try again.", [cancel, retry])
        case .severalFaces: (.failed, "More than one face", "Only you should be in view. Try again when you're alone.", [cancel, retry])
        case .cameraDenied: (.failed, "Camera access is off", "Allow byaku in System Settings, then try again.",
                             [cancel, ("Open camera settings…", .primary, onOpenSettings)])
        case .failed(let why): (.failed, "Couldn't set up face", why, [cancel, retry])
        }
        ring.set(ringPhase)
        titleLabel.textColor = Tokens.ink; body.textColor = Tokens.mute
        titleLabel.stringValue = title; body.stringValue = text
        // A lone title sits on the ring's centre line; with a body, the pair fills the 56 pt row.
        titleLabel.setFrameOrigin(NSPoint(x: 88, y: text.isEmpty ? 98 : 116))
        if buttons.map(\.title) != specs.map(\.0) {  // same buttons across countdown ticks (keeps hover state)
            buttons.forEach { $0.removeFromSuperview() }
            buttons = specs.map { t, role, act in PanelButton(t, role: role) { act() } }
            var x: CGFloat = 296
            for b in buttons.reversed() { x -= b.frame.width; b.setFrameOrigin(NSPoint(x: x, y: 24)); x -= 8; contentView!.addSubview(b) }
            buttons.last { $0.role == .primary }?.keyEquivalent = "\r"  // Return; focus ring stays off until the keyboard moves focus
        }
        let announcement: String? = switch p {
        case .starting: nil
        case .counting(let r): r == 5 ? "\(title). \(text) 5" : "\(r)"
        default: "\(title). \(text)"
        }
        if let announcement {
            NSAccessibility.post(element: self, notification: .announcementRequested,
                                 userInfo: [.announcement: announcement, .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
        if p == .saved {
            let w = DispatchWorkItem { [weak self] in self?.onCancel() }
            autoClose = w
            DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.autoClose, execute: w)
        }
    }
}

/// Panel surface: `surface` fill, 1 pt `line` border, 12 pt radius.
private final class SurfaceView: NSView {
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
