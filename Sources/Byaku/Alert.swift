import AppKit

// Guard actions (docs/designs/guard-actions.md): the Mode ladder, the banner, and the edge/dim overlay.

/// What an alert shows besides the banner (§2.1). Stored by raw value in UserDefaults.
enum Mode: Int, CaseIterable {
    case whisper, iris, shade, awaken

    var title: String { ["Whisper", "Iris", "Shade", "Awaken"][rawValue] }
    var subtitle: String { ["banner only", "violet edges", "light dim", "edges + dim"][rawValue] }
    var edges: Bool { self == .iris || self == .awaken }
    var dim: Bool { self == .shade || self == .awaken }
}

// MARK: - BannerPanel

/// 320 × 64 under the status item (§3). Never takes focus; sits above the overlay and below an open menu.
final class BannerPanel: AnchoredPanel {
    var onClose: () -> Void = {}
    /// One line per alert, in turn (§3). Copy, not tokens; each fits the 224 pt column on one line.
    private static let lines = ["Mind your screen.", "Eyes on your screen.", "Be aware.", "Not your face."]
    private var next = 0
    private let body = NSTextField(labelWithString: "")

    init() {
        super.init(size: NSSize(width: 320, height: 64), level: NSWindow.Level(NSWindow.Level.statusBar.rawValue + 1))
        setAccessibilityTitle("byaku alert")
        let v = contentView!
        let mark = NSImageView(image: StatusIcon.image(.alert))  // the symbol in accent: violet = seen
        mark.imageScaling = .scaleProportionallyUpOrDown
        mark.frame = NSRect(x: 15, y: 21, width: 22, height: 22)  // 20 pt mark inside the icon's 1 pt margin
        mark.setAccessibilityElement(false)
        let title = NSTextField(labelWithString: "Someone else is looking")
        title.font = .systemFont(ofSize: 13, weight: .semibold); title.textColor = Tokens.ink
        title.frame = NSRect(x: 48, y: 32, width: 224, height: 20)
        body.font = .systemFont(ofSize: 12); body.textColor = Tokens.mute
        body.lineBreakMode = .byTruncatingTail
        body.frame = NSRect(x: 48, y: 14, width: 224, height: 16)
        let close = PanelButton("", role: .close) { [weak self] in self?.onClose() }
        close.setFrameOrigin(NSPoint(x: 320 - 12 - 24, y: 64 - 8 - 24))
        [mark, title, body, close].forEach(v.addSubview)
    }

    /// Take the next line (the first alert gets the first). Call once per new alert, never while one is showing.
    func advance() {
        body.stringValue = Self.lines[next % Self.lines.count]
        next += 1
    }
}

// MARK: - WatchOverlay

/// Edges and/or dim on every display (§4): click-through, below the menu bar, the banner and NSMenu.
final class WatchOverlay {
    private var windows: [NSWindow] = []
    private(set) var mode: Mode?  // what's showing; nil = hidden

    init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in self?.rebuild() }
    }

    func show(_ m: Mode, animated: Bool = true) {
        guard m != mode else { return }
        mode = m
        guard m.edges || m.dim else { return hideWindows(animated: animated) }  // Whisper: banner only
        if windows.isEmpty { windows = NSScreen.screens.map(Self.window) }
        for w in windows { (w.contentView as? OverlayView)?.set(m, animated: animated); w.orderFrontRegardless() }
    }

    func hide() {
        guard mode != nil else { return }
        mode = nil
        hideWindows(animated: true)
    }

    private func hideWindows(animated: Bool) {
        windows.forEach { ($0.contentView as? OverlayView)?.set(nil, animated: animated) }
        // Order out after the fade so a hidden overlay costs nothing to composite.
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.exit) { [weak self] in
            guard let self, self.mode.map({ !$0.edges && !$0.dim }) ?? true else { return }
            self.windows.forEach { $0.orderOut(nil) }
        }
    }

    /// Displays changed: rebuild one window per screen and restore what was showing, without animating.
    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = []
        if let m = mode { mode = nil; show(m, animated: false) }
    }

    /// Covers the screen except the menu bar, so the status item and its menu stay reachable (DESIGN §5).
    private static func window(for screen: NSScreen) -> NSWindow {
        let f = screen.frame
        let rect = NSRect(x: f.minX, y: f.minY, width: f.width, height: screen.visibleFrame.maxY - f.minY)
        let w = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .statusBar
        w.ignoresMouseEvents = true
        w.isOpaque = false; w.backgroundColor = .clear; w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        w.isReleasedWhenClosed = false
        w.contentView = OverlayView(frame: NSRect(origin: .zero, size: rect.size))
        return w
    }
}

/// Dim layer + the Iris mist: the blurred shadow of an invisible band at the screen's edge. No hard border is drawn.
/// Static once in, so a held alert is a composited layer and costs ~0 GPU.
private final class OverlayView: NSView {
    private let dim = CALayer(), edgeBox = CALayer(), band = CAShapeLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
        dim.backgroundColor = NSColor.black.withAlphaComponent(Tokens.Overlay.dimAlpha).cgColor
        edgeBox.masksToBounds = true  // clip the shadow that falls outside the screen
        band.fillColor = nil  // the band only casts the mist; filled, it read as a solid violet frame over the edges
        band.shadowOffset = .zero; band.shadowRadius = Tokens.Overlay.edgeBlur; band.shadowOpacity = 1
        edgeBox.addSublayer(band)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        [dim, edgeBox].forEach { $0.opacity = 0; layer!.addSublayer($0) }
        CATransaction.commit()
        recolor()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dim.frame = bounds; edgeBox.frame = bounds; band.frame = bounds
        let p = bandPath(edgeBox.opacity > 0 ? Tokens.Overlay.edgeSpread : 0)
        band.path = p; band.shadowPath = p
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        let a = cg(Tokens.accent, in: self)
        band.shadowColor = a
    }

    func set(_ m: Mode?, animated: Bool) {
        let dimOn = m?.dim ?? false, edgesOn = m?.edges ?? false
        func fade(_ l: CALayer, to v: Float, enter: Double) {
            if animated { animate(l, "opacity", to: v, duration: v > 0 ? enter : Tokens.Motion.exit); return }
            CATransaction.begin(); CATransaction.setDisableActions(true); l.removeAllAnimations(); l.opacity = v; CATransaction.commit()
        }
        fade(dim, to: dimOn ? 1 : 0, enter: Tokens.Motion.enter)
        let wasOn = edgeBox.opacity > 0
        fade(edgeBox, to: edgesOn ? Tokens.Overlay.edgeAlpha : 0, enter: Tokens.Motion.edgeIn)
        guard edgesOn, !wasOn else { return }
        // The edge spreads inward from the screen's border (§6); Reduce Motion: fade only.
        // Live, the 90 pt shadow re-blurs on every recomposite (measured +13 mW held, >100 mW while scrolling), so once
        // the spread lands it is cached as a bitmap; each redraw then only blends a texture.
        edgeBox.shouldRasterize = false
        let settle = animated && !Tokens.Motion.reduced ? Tokens.Motion.edgeIn : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            guard let self, self.edgeBox.opacity > 0 else { return }
            self.edgeBox.rasterizationScale = self.window?.backingScaleFactor ?? 2
            self.edgeBox.shouldRasterize = true
        }
        let to = bandPath(Tokens.Overlay.edgeSpread)
        if animated, !Tokens.Motion.reduced {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            let from = bandPath(0); band.path = from; band.shadowPath = from
            CATransaction.commit()
            animate(band, "path", to: to, duration: Tokens.Motion.edgeIn)
            animate(band, "shadowPath", to: to, duration: Tokens.Motion.edgeIn)
        } else {
            CATransaction.begin(); CATransaction.setDisableActions(true)
            band.path = to; band.shadowPath = to
            CATransaction.commit()
        }
    }

    /// A frame from well outside the screen to `inset` inside it. The inner rect winds the other way, so the
    /// shadow path (non-zero rule) leaves the screen open and only the edge casts.
    private func bandPath(_ inset: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addRect(bounds.insetBy(dx: -2 * Tokens.Overlay.edgeBlur, dy: -2 * Tokens.Overlay.edgeBlur))
        let r = bounds.insetBy(dx: inset, dy: inset)
        p.addLines(between: [CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX, y: r.maxY),
                             CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX, y: r.minY)])
        p.closeSubpath()
        return p
    }
}
