import AppKit
import AVFoundation
import ServiceManagement
import Vision

/// The menu-bar app (docs/designs/menubar.md): `Byaku.app` (scripts/bundle.sh), or `byaku app [model]` from a terminal,
/// where camera TCC goes to the terminal instead.
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

    private var state = GuardState.off
    private var errorReason: String?
    private var guardCam: Camera?

    // Guard actions (docs/designs/guard-actions.md). Settings live in UserDefaults; the rest resets per alert.
    private let defaults = UserDefaults.standard
    private let banner = BannerPanel(), overlay = WatchOverlay()
    private var lifted = false, bannerClosed = false  // "Lift for now" / × : until the next separate alert
    private enum Key { static let mode = "mode", banner = "banner", sound = "sound", guardOn = "guard" }
    /// Persisted so Guard resumes at launch (and at login) if it was on at quit.
    private var guardOn: Bool {
        get { defaults.bool(forKey: Key.guardOn) }
        set { defaults.set(newValue, forKey: Key.guardOn) }
    }
    private var mode: Mode { Mode(rawValue: defaults.integer(forKey: Key.mode)) ?? .iris }

    // Away (docs/designs/away-mode.md). Guard pauses while armed (guardOn kept) and resumes on disarm.
    private var awayOn = false
    private var awayCam: Camera?
    private var awayRun = 0  // bumps on disarm so a stale countdown or frame is dropped
    private var armingLeft = 0  // seconds left in the arming countdown; 0 = watching
    private var lastFrame = Date.distantPast
    private var watchdog: Timer?
    private let alarm = Alarm()
    private var awayNote: String?  // why a fail-closed lock happened; shown once in the next menu

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
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(screenUnlocked),
                                                            name: .init("com.apple.screenIsUnlocked"), object: nil)
        render()
        if guardOn { if owner != nil { startGuard() } else { guardOn = false } }
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
        if let awayNote { return awayNote }
        if let errorReason { return "Not guarding: \(errorReason)" }
        if owner == nil { return "Set up your face to turn on Guard" }
        switch state {
        case .alert: return "Someone else is looking"
        case .guarding: return "Guarding. Camera is on"
        case .away: return armingLeft > 0 ? "Away in \(armingLeft) s. Step away" : "Away. Locks if anyone looks"
        case .alarm: return "Someone looked. Locked"
        default: return "Guard is off"
        }
    }

    func menuDidClose(_ menu: NSMenu) { awayNote = nil }

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
        g.isEnabled = owner != nil && enrollCam == nil && !awayOn  // one camera user at a time
        menu.addItem(g)
        let a = entry("Away", #selector(toggleAway), key: "a")
        a.state = awayOn ? .on : .off
        a.isEnabled = owner != nil && embedder != nil && enrollCam == nil && panel?.isVisible != true
        menu.addItem(a)
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
        modeItem.isEnabled = !awayOn
        menu.addItem(modeItem)
        let b = entry("Banner", #selector(toggleBanner)); b.state = defaults.bool(forKey: Key.banner) ? .on : .off
        let snd = entry("Sound", #selector(toggleSound)); snd.state = defaults.bool(forKey: Key.sound) ? .on : .off
        b.isEnabled = !awayOn; snd.isEnabled = !awayOn
        menu.addItem(b); menu.addItem(snd)
        menu.addItem(.separator())
        let setup = entry(owner == nil ? "Set up face…" : "Set up face again…", #selector(setUpFace), key: "e")
        setup.isEnabled = !awayOn
        menu.addItem(setup)
        let del = entry("Delete face data", #selector(deleteFace))
        del.isEnabled = owner != nil && !awayOn
        menu.addItem(del)
        menu.addItem(.separator())
        if Bundle.main.bundleURL.pathExtension == "app" {  // a terminal-run CLI has no bundle to register
            let login = entry("Open at login", #selector(toggleLogin))
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }
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
                DispatchQueue.main.async { if cam !== self?.guardCam, cam !== self?.enrollCam, cam !== self?.awayCam { cam.stop() } }
            } catch { DispatchQueue.main.async { failed(error) } }
        }
    }

    // MARK: Away

    @objc private func toggleAway() { awayOn ? disarm() : arm() }

    private func arm() {
        guard owner != nil, embedder != nil, !awayOn else { return }
        awayOn = true; awayRun += 1; awayNote = nil
        guardCam?.stop(); guardCam = nil  // Guard pauses; guardOn stays so disarm resumes it
        countdown(away: awayRun, Tokens.Away.armSeconds)
    }

    /// Arming: a few seconds to stand up and leave before frames count. Then watch.
    private func countdown(away run: Int, _ n: Int) {
        guard run == awayRun else { return }
        armingLeft = n
        if n == 0 { return watch(run) }
        set(.away)
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.countStep) { [weak self] in self?.countdown(away: run, n - 1) }
    }

    /// Same pipeline as Guard (1 fps, gaze gate, SFace, 2-of-3 debounce); only the rule (any non-owner face, unembeddable
    /// included) and the action differ. Fails closed: camera error or stall → lock.
    private func watch(_ run: Int) {
        guard let owner, let embedder else { return failClosed() }
        let cam = Camera(fps: 1)
        cam.embed = embedder
        var debounce = Debounce()  // touched only on cam.queue
        cam.onFrame = { [weak self] embeddings in
            let fire = debounce.add(frameHasLooker(embeddings.map { $0.map { cosine(unit($0), owner) } }, away: true))
            DispatchQueue.main.async {
                guard let self, run == self.awayRun, self.awayCam != nil else { return }
                self.lastFrame = Date()
                if fire { self.trigger() }
            }
        }
        awayCam = cam; lastFrame = Date()
        set(.away)
        start(cam) { [weak self] _ in if run == self?.awayRun, self?.awayCam === cam { self?.failClosed() } }
        let t = Timer(timeInterval: Tokens.Away.watchdog, repeats: true) { [weak self] _ in
            guard let self, self.awayCam != nil else { return }
            if Date().timeIntervalSince(self.lastFrame) > Tokens.Away.stallLimit { self.failClosed() }  // no frames: camera died
        }
        RunLoop.main.add(t, forMode: .common)  // keeps firing while the menu is open
        watchdog = t
    }

    private func stopWatching() {
        awayCam?.stop(); awayCam = nil
        watchdog?.invalidate(); watchdog = nil
    }

    /// A stranger looked: lock, then siren + voice until the owner unlocks (screenUnlocked → disarm).
    private func trigger() {
        stopWatching()
        set(.alarm)
        lockScreen()
        alarm.start()
    }

    /// The pipeline can't watch: lock without the siren (nobody looked), then Away is off. If the lock call itself is
    /// missing, sound the alarm instead; never leave an armed Mac unwatched and unlocked.
    private func failClosed() {
        stopWatching()
        let run = awayRun
        lockScreen()
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Away.lockCheck) { [weak self] in  // the session flag lags the call
            guard let self, run == self.awayRun else { return }
            if screenIsLocked() { self.awayNote = "Away locked: camera unavailable"; self.disarm() }
            else { self.set(.alarm); self.alarm.start() }  // the lock didn't take: be loud instead
        }
    }

    private func disarm() {
        awayOn = false; awayRun += 1; armingLeft = 0
        stopWatching()
        alarm.stop()
        set(.off)
        if guardOn, owner != nil { startGuard() }
    }

    /// Unlocking takes the owner's password or Touch ID, so it is the disarm (user decision 2026-11-26).
    @objc private func screenUnlocked() { if awayOn { disarm() } }

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
        if guardOn, guardCam == nil, owner != nil, !awayOn { startGuard() }  // Away armed: disarm resumes Guard
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

    /// The system holds the login item; no copy in UserDefaults. Needs approval or failed → let the user see Login Items.
    @objc private func toggleLogin() {
        let app = SMAppService.mainApp
        let wasOn = app.status == .enabled
        do { try wasOn ? app.unregister() : app.register() } catch { SMAppService.openSystemSettingsLoginItems(); return }
        if app.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    @objc private func openCameraSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
    }

    @objc private func quit() {
        guardCam?.stop(); enrollCam?.stop(); stopWatching(); alarm.stop()  // alarm.stop restores the volume
        NSApp.terminate(nil)
    }
}
