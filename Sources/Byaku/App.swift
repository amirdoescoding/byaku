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
    private enum Key { static let mode = "mode", banner = "banner", sound = "sound", guardOn = "guard", alarmVolume = "alarmVolume", alarmSound = "alarmSound", onboarded = "onboarded" }
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

    // Away message (docs/designs/away-mode.md §Message). The mic runs only while recording.
    private let recorder = MessageRecorder()
    private var msgPanel: MessagePanel?
    private var msgRun = 0  // bumps when the panel closes or the step changes, so stale permission/lead callbacks drop
    private var recording = false, shortTake = false
    private var tick: Timer?  // the panel's 1 s countdown while recording or playing

    private var panel: EnrollPanel?
    private var enrollCam: Camera?
    private var enrollRun = 0  // bumps on cancel/retry so stale callbacks are dropped
    private var scanStarted = false  // the current run has had a camera frame (main thread)
    private var scanPrints: [[Float]] = []  // straight-hold embeddings of the current scan (main thread); never stored
    private var onboarding: OnboardingFlow?  // first run, or "Welcome tour…"

    init(model: String) {
        super.init()
        defaults.register(defaults: [Key.mode: Mode.iris.rawValue, Key.banner: true, Key.sound: false, Key.alarmVolume: 1.0, Key.alarmSound: ""])
        alarm.sound = defaults.string(forKey: Key.alarmSound) ?? ""
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
        if !defaults.bool(forKey: Key.onboarded) { DispatchQueue.main.async { [weak self] in self?.showOnboarding() } }
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

    func menuDidClose(_ menu: NSMenu) { awayNote = nil; onboarding?.menuClosed() }
    func menuWillOpen(_ menu: NSMenu) { if onboarding?.touring == true { onboarding?.menuOpened(menu) } }

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
        menu.addItem(.separator())
        let vol = NSMenuItem()
        let slider = VolumeSlider(value: alarmVolume)
        slider.onCommit = { [weak self] v in
            self?.defaults.set(v, forKey: Key.alarmVolume)  // no blip on release: Play test is the only preview
        }
        vol.view = slider
        menu.addItem(vol)
        let sounds = NSMenu()
        let picked = Alarm.systemSounds().contains(alarm.sound) ? alarm.sound : ""  // a vanished sound plays (and shows) the siren
        let soundItem = NSMenuItem(title: "Alarm sound", action: nil, keyEquivalent: "")
        var rows: [SoundRow] = []
        for (i, name) in ([""] + Alarm.systemSounds()).enumerated() {
            let row = SoundRow(name: name, title: name.isEmpty ? "Siren" : name, checked: name == picked)
            row.onPick = { [weak self, weak soundItem] r in  // the menu stays open: pick, hear it, pick the next
                guard let self else { return }
                rows.forEach { $0.checked = $0 === r }
                self.defaults.set(r.name, forKey: Key.alarmSound); self.alarm.sound = r.name
                if #available(macOS 14.4, *) { soundItem?.subtitle = r.title }
                self.alarm.preview(level: self.alarmVolume, seconds: Tokens.Away.pickSeconds)
            }
            rows.append(row)
            let s = NSMenuItem(); s.view = row
            sounds.addItem(s)
            if i == 0 { sounds.addItem(.separator()) }
        }
        soundItem.submenu = sounds
        soundItem.isEnabled = !awayOn
        if #available(macOS 14.4, *) { soundItem.subtitle = picked.isEmpty ? "Siren" : picked }
        menu.addItem(soundItem)
        if Bundle.main.bundleURL.pathExtension == "app" {  // terminal run: mic TCC would go to the terminal, which has no plist key
            let m = entry("Message…", #selector(openMessage))
            m.isEnabled = !awayOn
            if #available(macOS 14.4, *) { m.subtitle = messageLength().map { "Recorded · \($0) s" } ?? "Spoken line" }
            menu.addItem(m)
        }
        menu.addItem(.separator())
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
        setup.isEnabled = !awayOn && onboarding == nil  // one face UI at a time (they share enrollCam)
        menu.addItem(setup)
        let del = entry("Delete face data", #selector(deleteFace))
        del.isEnabled = owner != nil && !awayOn
        menu.addItem(del)
        menu.addItem(.separator())
        menu.addItem(entry("Welcome tour…", #selector(showOnboarding)))
        if Bundle.main.bundleURL.pathExtension == "app" {  // a terminal-run CLI has no bundle to register
            let login = entry("Open at login", #selector(toggleLogin))
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(login)
        }
        menu.addItem(entry("Quit byaku", #selector(quit), key: "q"))
        if onboarding?.touring == true { onboarding?.dress(menu) }  // guided tour: coach card first, one row lit
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

    // MARK: Away message

    @objc private func openMessage() {
        guard let button = item.button else { return }
        let p = msgPanel ?? MessagePanel()
        msgPanel = p
        p.onCancel = { [weak self] in self?.endMessage() }
        p.onRecord = { [weak self] in self?.beginRecording() }
        p.onStop = { [weak self] in self?.stopMessageStep() }
        p.onPlay = { [weak self] in self?.playMessage() }
        p.onDelete = { [weak self] in
            guard let self else { return }
            do { try self.recorder.store.delete() } catch { NSSound.beep(); return }  // ponytail: same as Delete face data
            self.msgPanel?.deleted()
        }
        p.onOpenSettings = { [weak self] in self?.openPrivacy("Privacy_Microphone"); self?.endMessage() }
        recorder.onEnd = { [weak self] saved in
            guard let self, self.recording else { return }  // a cancel (endMessage) ends quietly
            self.recording = false; self.tick?.invalidate()
            self.msgPanel?.show(saved ? .recorded(self.messageLength() ?? 0)
                                      : .failed(self.shortTake ? "Too short. Try again." : "The recording failed. Try again."))
        }
        if alarm.playing, !awayOn { alarm.stop() }  // a sound preview mustn't run into the mic
        msgRun += 1
        p.show(messageLength().map { .recorded($0) } ?? .idle)
        p.present(below: button)
    }

    /// Seconds in the saved message, nil when there is none (or it can't be read).
    private func messageLength() -> Int? {
        guard recorder.store.exists, let p = try? AVAudioPlayer(contentsOf: recorder.store.url) else { return nil }
        return max(1, Int(p.duration.rounded()))
    }

    private func beginRecording() {
        msgRun += 1
        let run = msgRun
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: startRecording(run)
        case .notDetermined:
            msgPanel?.show(.requesting)
            AVCaptureDevice.requestAccess(for: .audio) { ok in  // any queue
                DispatchQueue.main.async { [weak self] in
                    guard let self, run == self.msgRun else { return }
                    ok ? self.startRecording(run) : self.msgPanel?.show(.denied)
                }
            }
        default: msgPanel?.show(.denied)
        }
    }

    /// With VoiceOver on, its "Recording, speak now" would land in the take: start the mic once it has been said.
    private func startRecording(_ run: Int) {
        let n = Int(Tokens.Away.messageSeconds)
        msgPanel?.show(.recording(n))
        let lead = NSWorkspace.shared.isVoiceOverEnabled ? Tokens.Away.voiceOverLead : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + lead) { [weak self] in
            guard let self, run == self.msgRun else { return }
            guard self.recorder.start() else { self.msgPanel?.show(.failed("No microphone is available.")); return }
            self.recording = true; self.shortTake = false
            self.countdown(n) { .recording($0) }
        }
    }

    private func playMessage() {
        msgRun += 1
        let run = msgRun
        let len = alarm.previewMessage(level: alarmVolume) { [weak self] in
            guard let self, run == self.msgRun else { return }
            self.tick?.invalidate(); self.msgPanel?.show(self.messageLength().map { .recorded($0) } ?? .idle)
        }
        guard let len else { msgPanel?.show(.failed("The message can't be played. Record it again.")); return }
        let n = max(1, Int(len.rounded()))
        countdown(n) { .playing($0, of: n) }
    }

    /// Stop while recording keeps the take; Stop while playing goes back to the saved message.
    private func stopMessageStep() {
        if recording { shortTake = recorder.elapsed < Tokens.Away.minMessageSeconds; recorder.finish(save: true); return }
        msgRun += 1; tick?.invalidate(); alarm.stop()
        msgPanel?.show(messageLength().map { .recorded($0) } ?? .idle)
    }

    /// The panel's countdown, one step per second. The end comes from the recorder or the player, not from here.
    private func countdown(_ n: Int, _ phase: @escaping (Int) -> MessagePanel.Phase) {
        tick?.invalidate()
        var left = n
        msgPanel?.show(phase(left))
        tick = Timer.scheduledTimer(withTimeInterval: Tokens.Motion.countStep, repeats: true) { [weak self] t in
            left -= 1
            if left < 1 { t.invalidate() } else { self?.msgPanel?.show(phase(left)) }
        }
    }

    /// Close, Esc, lock, Open settings: a take in progress is thrown away (the old message stays).
    private func endMessage() {
        msgRun += 1; tick?.invalidate()
        recording = false; recorder.finish(save: false)
        if alarm.playing, !awayOn { alarm.stop() }
        msgPanel?.dismiss()
    }

    // MARK: Away


    @objc private func toggleAway() { awayOn ? disarm() : arm() }

    private func arm() {
        guard owner != nil, embedder != nil, !awayOn else { return }
        if msgPanel?.isVisible == true { endMessage() }  // arming closes the message panel (and drops a take in progress)
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
        alarm.start(level: alarmVolume)
    }

    private var alarmVolume: Float { min(max(defaults.float(forKey: Key.alarmVolume), Tokens.Away.minVolume), 1) }

    /// The pipeline can't watch: lock without the siren (nobody looked), then Away is off. If the lock call itself is
    /// missing, sound the alarm instead; never leave an armed Mac unwatched and unlocked.
    private func failClosed() {
        stopWatching()
        let run = awayRun
        lockScreen()
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Away.lockCheck) { [weak self] in  // the session flag lags the call
            guard let self, run == self.awayRun else { return }
            if screenIsLocked() { self.awayNote = "Away locked: camera unavailable"; self.disarm() }
            else { self.set(.alarm); self.alarm.start(level: 1) }  // the lock didn't take: be loud instead
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

    /// The guided scan (docs/designs/face-scan.md): 15 fps landmarks drive the mask; every frame is embedded, and only
    /// frames counted during the straight hold make the face print (unit mean, as before). Side poses guide only, for now.
    private func capture() {
        guard let embedder else { showEnroll(.failed("The face model is missing.")); return }
        if guardCam != nil { guardCam?.stop(); guardCam = nil; set(.off) }  // one camera user at a time; Guard resumes after
        enrollCam?.stop()
        enrollRun += 1
        let run = enrollRun
        let cam = Camera(fps: Tokens.Scan.fps)
        cam.embed = embedder
        enrollCam = cam
        scanPrints = []; scanStarted = false
        showEnroll(.starting)
        cam.onImage = { [weak self] pb in  // cam.queue, the camera beat only (onCameraDone turns it off)
            guard let img = ScanView.image(pb) else { return }
            DispatchQueue.main.async { if run == self?.enrollRun { self?.scanView?.show(image: img) } }
        }
        scanView?.onCameraDone = { [weak cam] in cam?.queue.async { cam?.onImage = nil } }
        scanView?.onDone = { [weak self] in self?.scanDone(run) }
        scanView?.onFail = { [weak self] p in self?.finish(run, p) }
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Motion.startTimeout) { [weak self] in  // no first frame: give up
            if self?.enrollCam === cam, self?.scanStarted == false { self?.finish(run, .failed("The camera didn't start. Try again.")) }
        }
        var marks: (VNFaceObservation, CGSize)?, pending: (VNFaceObservation, [Float])?, last: Double?
        cam.onLandmarks = { marks = ($0, $1) }
        cam.onEmbedding = { pending = ($0, $1) }
        cam.onFaces = { [weak self] faces in  // cam.queue
            defer { marks = nil; pending = nil }
            let t = CACurrentMediaTime(), dt = last.map { t - $0 } ?? 1 / Tokens.Scan.fps
            last = t
            let f = ScanFrame(faces: faces.count, landmarks: faces.count == 1 ? marks?.0 : nil, size: marks?.1 ?? .zero, rect: faces.first)
            let print = countedEmbedding(faces, pending)
            DispatchQueue.main.async {
                guard let self, run == self.enrollRun, let v = self.scanView else { return }
                self.scanStarted = true
                if v.frame(f, dt: dt, printed: print != nil), let print { self.scanPrints.append(print) }
            }
        }
        start(cam) { [weak self] error in
            guard let self, run == self.enrollRun else { return }
            self.enrollCam = nil
            self.showEnroll(AVCaptureDevice.authorizationStatus(for: .video) == .denied ? .cameraDenied : .failed("The camera is unavailable."))
        }
    }

    /// All three poses held: save the straight frames' unit mean (the camera stops now; the mask finishes on its own).
    private func scanDone(_ run: Int) {
        guard run == enrollRun else { return }
        guard scanPrints.count >= Tokens.Scan.minFrames, let template = ownerTemplate(scanPrints) else { return finish(run, .noFace) }
        do { try store.save(template); owner = template; finish(run, .saved) }
        catch { finish(run, .failed("Couldn't save. Try again.")) }
    }

    private func finish(_ run: Int, _ result: EnrollPanel.Phase) {
        guard run == enrollRun else { return }
        enrollRun += 1  // drop late callbacks
        scanPrints = []
        enrollCam?.stop(); enrollCam = nil
        showEnroll(result)
        render()
    }

    /// Cancel, Done, Esc, lock: release the camera now, keep nothing partial, resume Guard if it was on.
    private func endEnrollment() {
        stopScan()
        panel?.dismiss()
    }

    /// Stop the camera and drop late callbacks; resume Guard if it was on.
    private func stopScan() {
        enrollRun += 1; scanPrints = []
        enrollCam?.stop(); enrollCam = nil
        if guardOn, guardCam == nil, owner != nil, !awayOn { startGuard() }  // Away armed: disarm resumes Guard
    }

    @objc private func screenLocked() {
        if panel?.isVisible == true { endEnrollment() }
        if onboarding?.scanning == true { stopScan(); onboarding?.scanStopped() }
        if msgPanel?.isVisible == true { endMessage() }
        if state == .alert { lifted = true; syncActions() }  // nothing to shield behind the lock screen
    }

    /// Enrollment phases go to the onboarding window while it hosts the scan, else to the Set up face panel.
    private func showEnroll(_ p: EnrollPanel.Phase) {
        if let o = onboarding, o.scanning { o.showFace(p) } else { panel?.show(p) }
    }

    /// The scan view of whichever host runs the scan.
    private var scanView: ScanView? { onboarding?.scanning == true ? onboarding?.scanView : panel?.scan }

    // MARK: onboarding (docs/designs/onboarding.md)

    @objc private func showOnboarding() {
        if let o = onboarding { o.bringForward(); return }
        if panel?.isVisible == true { endEnrollment() }  // one face UI at a time
        let o = OnboardingFlow(hasOwner: owner != nil)
        o.onScan = { [weak self] in self?.capture() }
        o.onStopScan = { [weak self] in self?.stopScan() }
        o.onOpenSettings = { [weak self] in self?.openCameraSettings() }
        o.onOpenMenu = { [weak self] in self?.item.button?.performClick(nil) }
        o.statusFrame = { [weak self] in
            guard let b = self?.item.button, let w = b.window else { return nil }
            return w.convertToScreen(b.convert(b.bounds, to: nil))
        }
        o.onDone = { [weak self] in self?.defaults.set(true, forKey: Key.onboarded); self?.onboarding = nil }
        onboarding = o
        o.start()
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

    @objc private func openCameraSettings() { openPrivacy("Privacy_Camera") }
    private func openPrivacy(_ pane: String) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }

    @objc private func quit() {
        guardCam?.stop(); enrollCam?.stop(); stopWatching(); recorder.finish(save: false); alarm.stop()  // alarm.stop restores the volume
        NSApp.terminate(nil)
    }
}
