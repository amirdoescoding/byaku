import AppKit

// Guard actions (docs/designs/guard-actions.md): the Mode ladder, the banner, and the edge/dim overlay.

/// What an alert shows besides the banner (§2.1). Stored by raw value in UserDefaults.
enum Mode: Int, CaseIterable {
    case whisper = 0, iris = 1, shade = 2, awaken = 3  // persisted in UserDefaults: never renumber

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
        let top = min(screen.visibleFrame.maxY, f.maxY - NSStatusBar.system.thickness)  // auto-hidden menu bar: visibleFrame reaches the top
        let rect = NSRect(x: f.minX, y: f.minY, width: f.width, height: top - f.minY)
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

/// Dim layer + the Iris mist: four accent gradient strips fading inward from the edges. No blur, no shadow, no
/// hard border: gradients render once and then cost a texture blend (the blurred-shadow version measured +13 mW held
/// and re-blurred on every recomposite).
private final class OverlayView: NSView {
    private enum Edge: CaseIterable { case top, bottom, left, right }
    private let dim = CALayer(), edgeBox = CALayer()
    private let strips = Edge.allCases.map { e in (e, CAGradientLayer()) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
        dim.backgroundColor = NSColor.black.withAlphaComponent(Tokens.Overlay.dimAlpha).cgColor
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for (e, g) in strips {
            // Layer space is y-up: each strip runs from its screen edge (solid) to its inner side (clear).
            switch e {
            case .top: g.anchorPoint = CGPoint(x: 0.5, y: 1); g.startPoint = CGPoint(x: 0.5, y: 1); g.endPoint = CGPoint(x: 0.5, y: 0)
            case .bottom: g.anchorPoint = CGPoint(x: 0.5, y: 0); g.startPoint = CGPoint(x: 0.5, y: 0); g.endPoint = CGPoint(x: 0.5, y: 1)
            case .left: g.anchorPoint = CGPoint(x: 0, y: 0.5); g.startPoint = CGPoint(x: 0, y: 0.5); g.endPoint = CGPoint(x: 1, y: 0.5)
            case .right: g.anchorPoint = CGPoint(x: 1, y: 0.5); g.startPoint = CGPoint(x: 1, y: 0.5); g.endPoint = CGPoint(x: 0, y: 0.5)
            }
            g.locations = Tokens.Overlay.mist.map { NSNumber(value: Double($0.at)) }
            edgeBox.addSublayer(g)
        }
        [dim, edgeBox].forEach { $0.opacity = 0; layer!.addSublayer($0) }
        CATransaction.commit()
        recolor()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Mist depth scales with the display (Tokens.Overlay.edgeDepth × width).
    private var depth: CGFloat { (bounds.width * Tokens.Overlay.edgeDepth).rounded() }

    override func layout() {
        super.layout()
        CATransaction.begin(); CATransaction.setDisableActions(true)
        dim.frame = bounds; edgeBox.frame = bounds
        let w = bounds.width, h = bounds.height, d = depth
        for (e, g) in strips {
            switch e {
            case .top: g.bounds = CGRect(x: 0, y: 0, width: w, height: d); g.position = CGPoint(x: w / 2, y: h)
            case .bottom: g.bounds = CGRect(x: 0, y: 0, width: w, height: d); g.position = CGPoint(x: w / 2, y: 0)
            case .left: g.bounds = CGRect(x: 0, y: 0, width: d, height: h); g.position = CGPoint(x: 0, y: h / 2)
            case .right: g.bounds = CGRect(x: 0, y: 0, width: d, height: h); g.position = CGPoint(x: w, y: h / 2)
            }
        }
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() { recolor() }

    private func recolor() {
        let a = cg(Tokens.accent, in: self)
        let colors = Tokens.Overlay.mist.map { a.copy(alpha: $0.alpha) ?? a }
        strips.forEach { $0.1.colors = colors }
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
        guard edgesOn, !wasOn, animated, !Tokens.Motion.reduced else { return }
        // The mist grows inward from each edge (§6): scale the strip's depth about its screen edge. Reduce Motion: fade only.
        for (e, g) in strips {
            let key = e == .top || e == .bottom ? "transform.scale.y" : "transform.scale.x"
            animate(g, key, from: 0.3, to: 1, duration: Tokens.Motion.edgeIn)
        }
    }
}
