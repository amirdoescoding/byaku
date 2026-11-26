import AppKit
import AVFoundation
import Vision

/// `byaku app [model]`: the menu-bar app (docs/designs/menubar.md). Launch from Terminal for now; camera TCC goes to the host.
func runApp(model: String) -> Never {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)  // no Dock icon
    let controller = AppController(model: model)
    withExtendedLifetime(controller) { app.run() }
    exit(0)
}

final class AppController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let store = OwnerStore()
    private var owner: [Float]?
    private var embedder: VNCoreMLRequest?
    private var modelError: String?

    private var guardOn = false
    private var state = GuardState.off
    private var errorReason: String?
    private var guardCam: Camera?

    // Guard actions (docs/designs/guard-actions.md). Settings live in UserDefaults; the rest resets per alert.
    private let defaults = UserDefaults.standard
    private let banner = BannerPanel(), overlay = WatchOverlay()
    private var lifted = false, bannerClosed = false  // "Lift for now" / × : until the next separate alert
    private enum Key { static let mode = "mode", banner = "banner", sound = "sound" }
    private var mode: Mode { Mode(rawValue: defaults.integer(forKey: Key.mode)) ?? .iris }

    private var panel: EnrollPanel?
    private var enrollCam: Camera?
    private var enrollRun = 0  // bumps on cancel/retry so stale callbacks are dropped
    private var countingRun = -1  // the run whose countdown has begun (main thread)

    init(model: String) {
        super.init()
        defaults.register(defaults: [Key.mode: Mode.iris.rawValue, Key.banner: true, Key.sound: false])
        banner.onClose = { [weak self] in self?.bannerClosed = true; self?.syncActions() }
        owner = store.load()
        do { embedder = try loadEmbedder(model, units: .cpuAndNeuralEngine).request }  // compile once, reuse per run
        catch { modelError = "face model missing" }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false  // our isEnabled (Guard and Delete need a face) must win
        item.menu = menu
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenLocked),
                                                            name: .init("com.apple.screenIsLocked"), object: nil)
        render()
    }

    // MARK: state → icon + menu

    private func set(_ s: GuardState, reason: String? = nil) {
        if s == .alert, state != .alert {  // a new, separate alert
            lifted = false; bannerClosed = false
            banner.advance()
            if defaults.bool(forKey: Key.sound) { NSSound(named: "Submarine")?.play() }  // once, never repeated (§5)
            NSAccessibility.post(element: item.button as Any, notification: .announcementRequested,
                                 userInfo: [.announcement: "Someone else is looking at your screen",
                                            .priority: NSAccessibilityPriorityLevel.high.rawValue])
        }
        state = s; errorReason = s == .error ? reason : nil
        render()
        syncActions()
    }

    /// Banner and overlay follow state + settings. Anything that ends an alert (clear, Guard off, error,
    /// enrollment, delete) goes through set(), so they can't outlive it.
    private func syncActions() {
        let on = state == .alert && !lifted
        if on, defaults.bool(forKey: Key.banner), !bannerClosed, let button = item.button { banner.present(below: button) }
        else { banner.dismiss() }
        if on { overlay.show(mode) } else { overlay.hide() }
    }

    private func render() {
        item.button?.image = StatusIcon.image(state)
        item.button?.setAccessibilityLabel(StatusIcon.label(state, reason: errorReason))
    }

    private var statusLine: String {
        if let errorReason { return "Not guarding: \(errorReason)" }
        if owner == nil { return "Set up your face to turn on Guard" }
        switch state {
        case .alert: return "Someone else is looking"
        case .guarding: return "Guarding. Camera is on"
        default: return "Guard is off"
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status = NSMenuItem(title: statusLine, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if errorReason == "camera access denied" { menu.addItem(entry("Open camera settings…", #selector(openCameraSettings))) }
        if state == .alert, !lifted { menu.addItem(entry("Lift for now", #selector(liftForNow), key: "l")) }
        menu.addItem(.separator())
        let g = entry("Guard", #selector(toggleGuard), key: "g")
        g.state = guardOn ? .on : .off
        g.isEnabled = owner != nil && enrollCam == nil  // one camera user at a time
        menu.addItem(g)
        let modes = NSMenu()
        for m in Mode.allCases {
            let i = entry(m.title, #selector(pickMode(_:)))
            if #available(macOS 14.4, *) { i.subtitle = m.subtitle }  // older: the title alone
            i.tag = m.rawValue
            i.state = m == mode ? .on : .off
            modes.addItem(i)
        }
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeItem.submenu = modes
        menu.addItem(modeItem)
        let b = entry("Banner", #selector(toggleBanner)); b.state = defaults.bool(forKey: Key.banner) ? .on : .off
        let snd = entry("Sound", #selector(toggleSound)); snd.state = defaults.bool(forKey: Key.sound) ? .on : .off
        menu.addItem(b); menu.addItem(snd)
        menu.addItem(.separator())
        menu.addItem(entry(owner == nil ? "Set up face…" : "Set up face again…", #selector(setUpFace), key: "e"))
        let del = entry("Delete face data", #selector(deleteFace))
        del.isEnabled = owner != nil
        menu.addItem(del)
        menu.addItem(.separator())
        menu.addItem(entry("Quit byaku", #selector(quit), key: "q"))
    }

    private func entry(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    // MARK: Guard actions

    @objc private func pickMode(_ sender: NSMenuItem) { defaults.set(sender.tag, forKey: Key.mode); syncActions() }
    @objc private func toggleBanner() { defaults.set(!defaults.bool(forKey: Key.banner), forKey: Key.banner); syncActions() }
    @objc private func toggleSound() { defaults.set(!defaults.bool(forKey: Key.sound), forKey: Key.sound) }
    @objc private func liftForNow() { lifted = true; syncActions() }

    // MARK: Guard

    @objc private func toggleGuard() { guardOn ? stopGuard() : startGuard() }

    private func startGuard() {
        guard let owner, let embedder else { guardOn = true; set(.error, reason: modelError ?? "face model missing"); return }
        guardOn = true
        let cam = Camera(fps: 1)  // 1 fps + embed: ~0.3–0.4 W camera/Vision + ~20–25 mW SFace (ARCHITECTURE power rows)
        cam.embed = embedder
        var debounce = Debounce()  // fresh per Guard start; touched only on cam.queue
        cam.onFrame = { [weak self, weak cam] embeddings in  // weak cam: the camera owns this closure
            let looker = frameHasLooker(embeddings.map { $0.map { cosine(unit($0), owner) } })
            let v: GuardState = debounce.add(looker) ? .alert : .guarding
            DispatchQueue.main.async { if let cam, self?.guardCam === cam, self?.state != v { self?.set(v) } }
        }
        guardCam = cam
        set(.guarding)
        start(cam) { [weak self] error in if self?.guardCam === cam { self?.guardFailed(error) } }
    }

    private func stopGuard() {
        guardOn = false
        guardCam?.stop(); guardCam = nil  // sensor off, LED off
        set(.off)
    }

    /// Guard fails open: show why, keep the toggle on so the user sees it was meant to run.
    private func guardFailed(_ error: Error) {
        guardCam = nil
        set(.error, reason: cameraReason(error))
    }

    private func cameraReason(_ error: Error) -> String {
        AVCaptureDevice.authorizationStatus(for: .video) == .denied ? "camera access denied" : "camera unavailable"
    }

    /// Camera.start blocks (permission prompt, startRunning): run it off main, report failure on main.
    /// If the user cancelled while it was starting (permission prompt, warm-up), stop it: no camera without an owner.
    private func start(_ cam: Camera, failed: @escaping (Error) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try cam.start()
                DispatchQueue.main.async { if cam !== self?.guardCam, cam !== self?.enrollCam { cam.stop() } }
            } catch { DispatchQueue.main.async { failed(error) } }
        }
    }

    // MARK: enrollment

    @objc private func setUpFace() {
        guard let button = item.button else { return }
        let p = panel ?? EnrollPanel()
        panel = p
        p.onCancel = { [weak self] in self?.endEnrollment() }
        p.onRetry = { [weak self] in self?.capture() }
        p.onOpenSettings = { [weak self] in self?.openCameraSettings(); self?.endEnrollment() }
        let shown = p.isVisible && p.alphaValue == 1  // already open (any phase): just bring it forward
        p.present(below: button)
        if !shown { capture() }
    }

    private func capture() {
        guard let embedder else { panel?.show(.failed("The face model is missing.")); return }
        if guardCam != nil { guardCam?.stop(); guardCam = nil; set(.off) }  // one camera user at a time; Guard resumes after
        enrollCam?.stop()
        enrollRun += 1
        let run = enrollRun, seconds = 5
        let cam = Camera(fps: 5)
        cam.embed = embedder
        enrollCam = cam
        panel?.show(.starting)
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.startTimeout) { [weak self] in  // no first frame: give up
            if self?.enrollCam === cam, self?.countingRun != run { self?.finish(run, .failed("The camera didn't start. Try again.")) }
        }
        var pending: (VNFaceObservation, [Float])?, frames: [[Float]] = [], started = false, several = false
        cam.onEmbedding = { pending = ($0, $1) }
        cam.onFaces = { [weak self, weak cam] faces in  // cam.queue; weak cam: the camera owns this closure
            defer { pending = nil }
            if !started {
                started = true
                DispatchQueue.main.async { if let cam { self?.countdown(run: run, cam: cam, from: seconds) { frames } } }
            }
            if faces.count >= 2, !several { several = true; DispatchQueue.main.async { self?.finish(run, .severalFaces) } }
            if let v = countedEmbedding(faces, pending) { frames.append(v) }
        }
        start(cam) { [weak self] error in
            guard let self, run == self.enrollRun else { return }
            self.enrollCam = nil
            self.panel?.show(AVCaptureDevice.authorizationStatus(for: .video) == .denied ? .cameraDenied : .failed("The camera is unavailable."))
        }
    }

    /// 5 s from the first frame; then save the unit-mean template if enough frames counted.
    private func countdown(run: Int, cam: Camera, from n: Int, frames: @escaping () -> [[Float]]) {
        guard run == enrollRun else { return }
        if n == 0 {
            let f = cam.queue.sync { frames() }
            // ponytail: at least 10 counted frames (2 s at 5 fps) = "a face was seen"; tune with real failures.
            guard f.count >= 10, let template = ownerTemplate(f) else { return finish(run, .noFace) }
            do { try store.save(template); owner = template; finish(run, .saved) }
            catch { finish(run, .failed("Couldn't save. Try again.")) }
            return
        }
        countingRun = run
        panel?.show(.counting(n))
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.countStep) { [weak self] in
            self?.countdown(run: run, cam: cam, from: n - 1, frames: frames)
        }
    }

    private func finish(_ run: Int, _ result: EnrollPanel.Phase) {
        guard run == enrollRun else { return }
        enrollRun += 1  // stop the countdown and late callbacks
        enrollCam?.stop(); enrollCam = nil
        panel?.show(result)
        render()
    }

    /// Cancel, Done, Esc, lock: release the camera now, keep nothing partial, resume Guard if it was on.
    private func endEnrollment() {
        enrollRun += 1
        enrollCam?.stop(); enrollCam = nil
        panel?.dismiss()
        if guardOn, guardCam == nil, owner != nil { startGuard() }
    }

    @objc private func screenLocked() {
        if panel?.isVisible == true { endEnrollment() }
        if state == .alert { lifted = true; syncActions() }  // nothing to shield behind the lock screen
    }

    // MARK: other actions

    @objc private func deleteFace() {
        // ponytail: a failed delete only beeps; it's one file in our own folder. Add a real alert if it ever happens.
        do { try store.delete() } catch { NSSound.beep(); return }
        owner = nil
        stopGuard()
    }

    @objc private func openCameraSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
    }

    @objc private func quit() {
        guardCam?.stop(); enrollCam?.stop()
        NSApp.terminate(nil)
    }
}
