import AVFoundation
import CoreAudio

// Away actions (docs/designs/away-mode.md): lock the screen, sound the alarm. No audio file ships: the siren is computed,
// the other tones are macOS's own alert sounds, and the line is the system voice or the user's recording.

func screenIsLocked() -> Bool {
    (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

/// Locks via private SACLockScreenImmediate (same call BLEUnlock-style tools use). Returns whether the call was made;
/// check `screenIsLocked()` a moment later to confirm (the session flag lags the call).
@discardableResult
func lockScreen() -> Bool {
    guard let h = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
          let sym = dlsym(h, "SACLockScreenImmediate") else { return false }
    typealias Lock = @convention(c) () -> Int32
    _ = unsafeBitCast(sym, to: Lock.self)()
    return true
}

/// Two-tone siren at time t (s): 960 / 770 Hz, switching every 0.4 s, soft-clipped toward a square for loudness. Range ±0.9.
func siren(_ t: Double) -> Float {
    let f = Int(t / 0.4) % 2 == 0 ? 960.0 : 770.0
    return Float(tanh(3 * sin(2 * .pi * f * t)) * 0.9)
}

/// The alarm tone (the siren, or the picked system sound) loops from the first moment, and the message (the user's
/// recording, else the spoken line) plays over it, then again every `Tokens.Away.messageGap` after it ends, until stop(). While it plays the default output is unmuted at the alarm
/// volume; stop() puts both back.
final class Alarm: NSObject, AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    static let line = "byaku spotted a threat!"
    static let soundsDir = URL(fileURLWithPath: "/System/Library/Sounds")
    /// The macOS alert sounds (names without .aiff), sorted. Read at runtime: the set differs between macOS versions.
    static func systemSounds(in dir: URL = soundsDir) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "aiff" }.map { $0.deletingPathExtension().lastPathComponent }.sorted()
    }

    var sound = ""  // "" = the siren; else a name from systemSounds(). Unreadable = the siren.
    var message = MessageStore()
    private var engine: AVAudioEngine?  // built per alarm (the output's sample rate can change in between), nil when quiet
    private let voice = AVSpeechSynthesizer()
    private var msg: AVAudioPlayer?  // the recording while it plays
    private var t = 0.0  // render thread only
    private var saved: (device: AudioObjectID, volume: Float32?, mute: UInt32?)?
    private var run = 0  // bumps on stop so a pending repeat of the message is dropped
    private var inTone = false
    private(set) var playing = false
    private var testing = false  // a preview: tone only, and a real alarm takes over from it

    override init() {
        super.init()
        voice.delegate = self
        // Headphones unplugged / output switched: the engine stops itself. Rebuild it so the alarm keeps sounding.
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] n in
            guard let self, let e = n.object as? AVAudioEngine, e === self.engine else { return }
            self.engine = nil
            if self.inTone { self.startTone() }
        }
    }

    /// `level` = output volume while it plays (Tokens.Away.minVolume…1). A real alarm replaces a running preview.
    func start(level: Float, voice: Bool = true) {
        if playing { guard testing, voice else { return }; stop() }
        playing = true; testing = !voice
        takeOutput(level)
        cycle(run)
    }

    /// The recording once, at `level` (the message panel's Play). Returns its length, or nil if it can't play.
    /// `done` runs on main when it ends by itself; not after stop().
    func previewMessage(level: Float, done: @escaping () -> Void) -> Double? {
        guard !playing || testing else { return nil }
        if testing { stop() }
        guard let p = try? AVAudioPlayer(contentsOf: message.url) else { return nil }
        playing = true; testing = true
        takeOutput(level)
        p.delegate = self
        guard p.play() else { stop(); return nil }
        msg = p; previewDone = done
        return p.duration
    }

    private var previewDone: (() -> Void)?

    private func takeOutput(_ level: Float) {
        let dev = defaultOutput()
        saved = (dev, get(dev, volumeSel) as Float32?, get(dev, kAudioDevicePropertyMute) as UInt32?)
        set(dev, kAudioDevicePropertyMute, UInt32(0)); set(dev, volumeSel, Float32(level))
    }

    /// Tone only, for `seconds`, at `level` (Play test), with the picked sound. Then the volume goes back.
    func preview(level: Float, seconds: Double) {
        guard !playing || testing else { return }  // never cut into a real alarm
        if testing { stop() }  // a second Play test restarts, with the sound picked since
        start(level: level, voice: false)
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in if r == self?.run, self?.testing == true { self?.stop() } }
    }

    func stop() {
        guard playing else { return }
        playing = false; testing = false; inTone = false; run += 1
        engine?.stop(); engine = nil
        voice.stopSpeaking(at: .immediate)
        msg?.stop(); msg = nil; previewDone = nil
        if let s = saved {
            if let v = s.volume { set(s.device, volumeSel, v) }
            if let m = s.mute { set(s.device, kAudioDevicePropertyMute, m) }
        }
        saved = nil
    }

    private func cycle(_ r: Int) {
        guard playing, r == run else { return }
        inTone = true
        startTone()
        if !testing { speak() }  // together with the tone, not after it
    }

    /// The message ended: say it again after a breath, over the tone that keeps going.
    private func again(_ r: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Away.messageGap) { [weak self] in
            guard let self, self.playing, !self.testing, r == self.run else { return }
            self.speak()
        }
    }

    private func startTone() {
        let e = engine ?? makeEngine()
        engine = e
        try? e.start()  // ponytail: no output device = no sound; the lock already happened, so nothing else to do
        e.attachedNodes.lazy.compactMap { $0 as? AVAudioPlayerNode }.first?.play()
    }

    /// The recording if there is one and it plays, else the spoken line: never a silent gap.
    private func speak() {
        if let p = try? AVAudioPlayer(contentsOf: message.url) {
            p.delegate = self
            if p.play() { msg = p; return }
        }
        voice.speak(AVSpeechUtterance(string: Self.line))
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        let r = run
        DispatchQueue.main.async { [weak self] in self?.again(r) }
    }

    func audioPlayerDidFinishPlaying(_ p: AVAudioPlayer, successfully: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, p === self.msg else { return }  // stop() clears msg: a late callback is dropped
            self.msg = nil
            if self.testing { let d = self.previewDone; self.stop(); d?() } else { self.again(self.run) }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ p: AVAudioPlayer, error: Error?) { audioPlayerDidFinishPlaying(p, successfully: false) }

    /// The picked system sound, looped, or the computed siren. The tone sits at `toneGain` so the message after it
    /// isn't dwarfed (speech is far quieter than a clipped square wave at the same output volume).
    private func makeEngine() -> AVAudioEngine {
        let e = AVAudioEngine()
        e.mainMixerNode.outputVolume = Tokens.Away.toneGain
        if let buf = loadSound() {
            let p = AVAudioPlayerNode()
            e.attach(p)
            e.connect(p, to: e.mainMixerNode, format: buf.format)  // the file's own format; the mixer converts
            p.scheduleBuffer(buf, at: nil, options: .loops)
            return e
        }
        let rate = e.outputNode.inputFormat(forBus: 0).sampleRate
        let src = AVAudioSourceNode { [weak self] _, _, frames, abl in
            guard let self else { return noErr }
            for b in UnsafeMutableAudioBufferListPointer(abl) {
                let p = b.mData!.assumingMemoryBound(to: Float.self)
                for i in 0..<Int(frames) { p[i] = Byaku.siren(self.t + Double(i) / rate) }
            }
            self.t += Double(frames) / rate
            return noErr
        }
        e.attach(src)
        e.connect(src, to: e.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        return e
    }

    private func loadSound() -> AVAudioPCMBuffer? {
        guard !sound.isEmpty, !sound.contains("/"),
              let f = try? AVAudioFile(forReading: Self.soundsDir.appendingPathComponent(sound + ".aiff")), f.length > 0,
              let buf = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length)),
              (try? f.read(into: buf)) != nil else { return nil }
        return buf
    }

    // MARK: CoreAudio: default output, its volume and mute

    private let volumeSel = kAudioHardwareServiceDeviceProperty_VirtualMainVolume

    private func address(_ sel: AudioObjectPropertySelector, output: Bool = true) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: sel, mScope: output ? kAudioDevicePropertyScopeOutput : kAudioObjectPropertyScopeGlobal,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func defaultOutput() -> AudioObjectID {
        var id = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size)
        var a = address(kAudioHardwarePropertyDefaultOutputDevice, output: false)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id)
        return id
    }

    /// nil when the device has no such control (e.g. HDMI without volume).
    private func get<T: BitwiseCopyable>(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector) -> T? {
        var a = address(sel)
        guard AudioObjectHasProperty(dev, &a) else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        let p = UnsafeMutablePointer<T>.allocate(capacity: 1); defer { p.deallocate() }
        return AudioObjectGetPropertyData(dev, &a, 0, nil, &size, p) == noErr ? p.pointee : nil
    }

    private func set<T: BitwiseCopyable>(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ v: T) {
        var a = address(sel), v = v
        guard AudioObjectHasProperty(dev, &a) else { return }
        AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<T>.size), &v)
    }
}

/// Records the Away message into `MessageStore.tmp`, at most `Tokens.Away.messageSeconds`, and installs it when kept.
/// The mic runs only between start() and finish().
final class MessageRecorder: NSObject, AVAudioRecorderDelegate {
    var store = MessageStore()
    private var rec: AVAudioRecorder?
    var onEnd: (_ saved: Bool) -> Void = { _ in }  // main thread
    var elapsed: Double { rec?.currentTime ?? 0 }

    /// false = couldn't start (no input device, folder not writable).
    func start() -> Bool {
        do {
            try store.prepare()
            let r = try AVAudioRecorder(url: store.tmp, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44_100,
                                                                     AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 64_000])
            r.delegate = self
            guard r.record(forDuration: Tokens.Away.messageSeconds) else { return false }
            rec = r
            return true
        } catch { return false }
    }

    /// Stop (save) or cancel. Idempotent: `rec` clears first, so the delegate echo of stop() is ignored.
    func finish(save: Bool) {
        guard let r = rec else { return }
        rec = nil
        let long = r.currentTime >= Tokens.Away.minMessageSeconds  // read before stop(); a mis-click isn't a message
        r.stop()
        guard save, long, (try? store.install()) != nil else { store.discardTmp(); return onEnd(false) }
        onEnd(true)
    }

    /// The cap: record(forDuration:) stopped by itself. currentTime is 0 by now, so the take counts as full length.
    func audioRecorderDidFinishRecording(_ r: AVAudioRecorder, successfully ok: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self, r === self.rec else { return }
            self.rec = nil
            guard ok, (try? self.store.install()) != nil else { self.store.discardTmp(); return self.onEnd(false) }
            self.onEnd(true)
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ r: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async { [weak self] in if let self, r === self.rec { self.finish(save: false) } }
    }
}
