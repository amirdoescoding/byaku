import AVFoundation
import CoreAudio

// Away actions (docs/designs/away-mode.md): lock the screen, sound the alarm. No audio file ships: the siren is computed
// and the line is spoken by the system voice, so there is nothing to license.

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

/// Siren for `Tokens.Away.sirenSeconds`, then the spoken line, then again, until stop(). While it plays the default output
/// is unmuted at full volume; stop() puts both back.
final class Alarm: NSObject, AVSpeechSynthesizerDelegate {
    static let line = "byaku spotted a threat!"
    private var engine: AVAudioEngine?  // built on first start: an idle app holds no audio unit
    private let voice = AVSpeechSynthesizer()
    private var t = 0.0  // render thread only
    private var saved: (device: AudioObjectID, volume: Float32?, mute: UInt32?)?
    private var run = 0  // bumps on stop so a pending siren → voice hand-off is dropped
    private(set) var playing = false
    private var testing = false  // a preview: siren only, and a real alarm takes over from it

    override init() { super.init(); voice.delegate = self }

    /// `level` = output volume while it plays (Tokens.Away.minVolume…1). A real alarm replaces a running preview.
    func start(level: Float, voice: Bool = true) {
        if playing { guard testing, voice else { return }; stop() }
        playing = true; testing = !voice
        let dev = defaultOutput()
        saved = (dev, get(dev, volumeSel) as Float32?, get(dev, kAudioDevicePropertyMute) as UInt32?)
        set(dev, kAudioDevicePropertyMute, UInt32(0)); set(dev, volumeSel, Float32(level))
        siren(run)
    }

    /// Siren only, for `seconds`, at `level` (Play test, slider release). Then the volume goes back.
    func preview(level: Float, seconds: Double) {
        guard !playing || testing else { return }  // never cut into a real alarm
        start(level: level, voice: false)
        let r = run
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in if r == self?.run, self?.testing == true { self?.stop() } }
    }

    func stop() {
        guard playing else { return }
        playing = false; testing = false; run += 1
        engine?.stop(); voice.stopSpeaking(at: .immediate)
        if let s = saved {
            if let v = s.volume { set(s.device, volumeSel, v) }
            if let m = s.mute { set(s.device, kAudioDevicePropertyMute, m) }
        }
        saved = nil
    }

    private func siren(_ r: Int) {
        guard playing, r == run else { return }
        let e = engine ?? makeEngine()
        engine = e
        try? e.start()  // ponytail: no output device = no sound; the lock already happened, so nothing else to do
        DispatchQueue.main.asyncAfter(deadline: .now() + Tokens.Away.sirenSeconds) { [weak self] in
            guard let self, self.playing, !self.testing, r == self.run else { return }
            self.engine?.pause()
            self.voice.speak(AVSpeechUtterance(string: Self.line))
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) {
        let r = run
        DispatchQueue.main.async { [weak self] in self?.siren(r) }
    }

    private func makeEngine() -> AVAudioEngine {
        let e = AVAudioEngine()
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
    private func get<T>(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector) -> T? {
        var a = address(sel)
        guard AudioObjectHasProperty(dev, &a) else { return nil }
        var size = UInt32(MemoryLayout<T>.size)
        let p = UnsafeMutablePointer<T>.allocate(capacity: 1); defer { p.deallocate() }
        return AudioObjectGetPropertyData(dev, &a, 0, nil, &size, p) == noErr ? p.pointee : nil
    }

    private func set<T>(_ dev: AudioObjectID, _ sel: AudioObjectPropertySelector, _ v: T) {
        var a = address(sel), v = v
        guard AudioObjectHasProperty(dev, &a) else { return }
        AudioObjectSetPropertyData(dev, &a, 0, nil, UInt32(MemoryLayout<T>.size), &v)
    }
}
