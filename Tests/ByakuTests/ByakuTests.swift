import CoreGraphics
import AppKit
import Testing
@testable import Byaku

@Test(arguments: [("1", 1.0), ("0.2", 1.0), ("5", 5.0), ("120", 30.0)])
func parseFPSClamps(input: String, expected: Double) {
    #expect(parseFPS(input) == expected)
}

@Test(arguments: ["", "abc", "nan", "inf"])
func parseFPSRejectsGarbage(input: String) {
    #expect(parseFPS(input) == nil)
}

@Test func cosineKnownValues() {
    #expect(abs(cosine([1, 2, 3], [1, 2, 3]) - 1) < 1e-6)
    #expect(abs(cosine([1, 0], [0, 1])) < 1e-6)
    #expect(abs(cosine([1, 0], [-1, 0]) + 1) < 1e-6)
    #expect(cosine([0, 0], [1, 1]) == 0)
}

@Test func similarityRecoversKnownTransform() {
    let t = CGAffineTransform(rotationAngle: 0.3).scaledBy(x: 0.4, y: 0.4).translatedBy(x: 120, y: -40)
    let src = [CGPoint(x: 10, y: 20), CGPoint(x: 80, y: 22), CGPoint(x: 45, y: 60), CGPoint(x: 15, y: 90), CGPoint(x: 75, y: 91)]
    let m = similarity(src: src, dst: src.map { $0.applying(t) })
    for (a, b) in [(m.a, t.a), (m.b, t.b), (m.c, t.c), (m.d, t.d), (m.tx, t.tx), (m.ty, t.ty)] { #expect(abs(a - b) < 1e-9) }
}

@Test(arguments: [(0, 0, true), (0.52, 0, true), (-0.52, 0.43, true), (0.53, 0, false), (0, -0.44, false)] as [(Float, Float, Bool)])
func gazeGate(yaw: Float, pitch: Float, facing: Bool) {
    #expect(facesScreen(yaw: yaw, pitch: pitch) == facing)
}

@Test func gazeGateMissingPoseCountsAsFacing() { #expect(facesScreen(yaw: nil, pitch: nil)) }

@Test(arguments: [([], false), ([0.9], false), ([0.1], true), ([nil], false),  // lone unembeddable face fails open
                  ([0.9, 0.9], false), ([0.9, 0.1], true), ([0.9, nil], true), ([nil, nil], true)] as [([Float?], Bool)])
func lookerRules(scores: [Float?], looker: Bool) {
    #expect(frameHasLooker(scores) == looker)
}

@Test(arguments: [([], false), ([0.9], false), ([0.1], true), ([nil], true),  // Away fails closed: a lone unembeddable face counts
                  ([0.9, nil], true)] as [([Float?], Bool)])
func awayLookerRules(scores: [Float?], looker: Bool) {
    #expect(frameHasLooker(scores, away: true) == looker)
}

@Test func sirenIsBoundedAndLoud() {
    let s = (0..<48000).map { siren(Double($0) / 48000) }  // 1 s at 48 kHz: both tones
    #expect(s.allSatisfy { abs($0) <= 0.9 })
    #expect(s.map { $0 * $0 }.reduce(0, +) / Float(s.count) > 0.4)  // RMS² near a square wave, not a quiet sine
}

@Test func debounceFiresOnTwoOfThreeAndClearsAfterThree() {
    func run(_ frames: [Bool]) -> [Bool] { var d = Debounce(); return frames.map { d.add($0) } }
    #expect(run([true, false, false, false]) == [false, false, false, false])      // one stray frame never fires
    #expect(run([true, false, true]) == [false, false, true])                       // 2 of 3
    #expect(run([true, true, false, false, false]) == [false, true, true, true, false])  // clears after 3 clean
    #expect(run([true, true, false, false, true, false, false, false]).last == false)
    #expect(run([true, true, false, false, true, false, false]) == [false, true, true, true, true, true, true])  // a looker resets the clear count
}

@Test func modeRawValuesAndLadderArePinned() {
    #expect(Mode.allCases.map(\.rawValue) == [0, 1, 2, 3])  // persisted in UserDefaults "mode"
    #expect(Mode.allCases.map(\.edges) == [false, true, false, true])
    #expect(Mode.allCases.map(\.dim) == [false, false, true, true])
}

@Test func ownerStoreRejectsWrongLength() throws {
    let s = OwnerStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("byaku-test-\(UUID())/owner.json"))
    try s.save([1, 2, 3])
    #expect(s.load() == nil)
    try s.delete()
}

@Test func ownerTemplateIsUnitMean() {
    let t = ownerTemplate([[1, 0], [0, 1]])!
    #expect(abs(t[0] - t[1]) < 1e-6 && abs(t[0] * t[0] + t[1] * t[1] - 1) < 1e-6)
    #expect(ownerTemplate([]) == nil)
}

@Test func ownerStoreRoundTripAndDelete() throws {
    let s = OwnerStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("byaku-test-\(UUID())/owner.json"))
    #expect(s.load() == nil)
    let v = (0..<128).map { Float($0) / 128 - 0.5 }  // a real template is 128 SFace floats
    try s.save(v)
    #expect(s.load() == v)
    try s.delete()
    #expect(s.load() == nil)
    try s.delete()  // deleting twice is fine
}

/// Renders each status icon at 2x; shape (not only colour) must tell alert and error apart from guarding.
@Test func statusIconShapes() throws {
    func alpha(_ s: GuardState) throws -> (NSBitmapImageRep, (Int, Int) -> CGFloat) {
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8,
                                                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = NSSize(width: 18, height: 18)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        StatusIcon.image(s).draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
        NSGraphicsContext.restoreGraphicsState()
        if let dir = ProcessInfo.processInfo.environment["BYAKU_ICON_DUMP"] {
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/icon-\(s).png"))
        }
        return (rep, { x, y in rep.colorAt(x: x, y: y)!.alphaComponent })
    }
    let (_, guarding) = try alpha(.guarding), (_, alert) = try alpha(.alert), (_, off) = try alpha(.off), (_, error) = try alpha(.error)
    #expect(guarding(18, 18) < 0.2 && alert(18, 18) > 0.8)   // the centre dot
    #expect(off(18, 18) < 0.2)
    #expect(error(18, 18) > 0.8)                              // the slash crosses the centre
    #expect(guarding(4, 18) > 0.5 && off(4, 18) > 0.5)        // the ring is there in every state
    #expect(guarding(1, 1) < 0.1 && guarding(18, 1) < 0.1)     // nothing outside the ring (blade arcs bend inward)
    let (_, away) = try alpha(.away), (_, alarm) = try alpha(.alarm)
    #expect(away(18, 18) > 0.8 && away(18, 26) > 0.8 && guarding(18, 26) < 0.2)  // solid iris fills inside the ring
    #expect(away(1, 1) < 0.1)
    #expect(alarm(18, 18) > 0.8)                                // alarm reuses the alert dot
}

@Test func volumeSliderKnobTracksValue() throws {
    func render(_ v: Float) throws -> NSBitmapImageRep {
        let s = VolumeSlider(value: v)
        s.appearance = NSAppearance(named: .darkAqua)
        let rep = try #require(s.bitmapImageRepForCachingDisplay(in: s.bounds))
        s.cacheDisplay(in: s.bounds, to: rep)
        if let dir = ProcessInfo.processInfo.environment["BYAKU_ICON_DUMP"] {
            try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/slider-\(v).png"))
        }
        return rep
    }
    // Right end of the track, mid-height (rep is y-down): white fill only when full.
    let full = try render(1), low = try render(Tokens.Away.minVolume)
    let px = { (r: NSBitmapImageRep) in r.colorAt(x: Int(CGFloat(r.pixelsWide) * 0.8), y: r.pixelsHigh - Int(20 * CGFloat(r.pixelsHigh) / 62))!.alphaComponent }  // fill is opaque white; the bare track is 16% alpha
    #expect(px(full) > 0.9 && px(low) < 0.5)
}

@Test func systemSoundsListsAiffSorted() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    for n in ["b.aiff", "a.aiff", "c.txt"] { FileManager.default.createFile(atPath: dir.appendingPathComponent(n).path, contents: Data()) }
    #expect(Alarm.systemSounds(in: dir) == ["a", "b"])
    #expect(Alarm.systemSounds(in: dir.appendingPathComponent("missing")).isEmpty)
}

@Test func messageStoreKeepsOldUntilSwap() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let s = MessageStore(url: dir.appendingPathComponent("message.m4a"))
    let put = { (u: URL, t: String) in try Data(t.utf8).write(to: u) }
    let read = { String(decoding: try Data(contentsOf: s.url), as: UTF8.self) }
    try put(s.tmp, "one"); try s.install()                       // no message yet: move
    #expect(try read() == "one" && !FileManager.default.fileExists(atPath: s.tmp.path))
    try put(s.tmp, "two"); s.discardTmp()                        // cancelled re-record: old one stays
    #expect(try read() == "one")
    try put(s.tmp, "three"); try s.install()                     // kept re-record: replaced
    #expect(try read() == "three")
    try s.delete(); #expect(!s.exists)
}

@Test func onboardingSoundsStayQuietAndShort() {
    for k in [Sfx.Kind.whooshIn, .whooshOut, .browUp, .browDown] {
        let s = Sfx.samples(k)
        #expect(!s.isEmpty && s.count <= Sfx.rate / 2)
        #expect(s.allSatisfy { $0.isFinite && abs($0) <= Tokens.Onboarding.whooshLevel + 1e-6 })
    }
    let w = Sfx.wav(Sfx.samples(.browUp))
    #expect(w.prefix(4) == Data("RIFF".utf8) && w.count == 44 + Sfx.samples(.browUp).count * 2)
}

@Test func wordmarkPathFillsItsViewBox() {
    let b = svgPath(WordmarkView.d).boundingBoxOfPath, v = WordmarkView.box
    #expect(abs(b.minX - v.minX) < 1 && abs(b.maxX - v.maxX) < 1 && abs(b.minY - v.minY) < 1 && abs(b.maxY - v.maxY) < 1)
}

// MARK: ScanPose (guided face scan)

/// Feeds (faces, yaw) frames at 15 fps; returns all events.
private func scan(_ p: inout ScanPose, _ frames: [(Int, Double)]) -> [ScanPose.Event] {
    frames.flatMap { p.frame(faces: $0.0, yaw: $0.1, dt: 1.0 / 15) }
}
private func hold(_ yaw: Double, _ seconds: Double) -> [(Int, Double)] { Array(repeating: (1, yaw), count: Int(seconds * 15)) }

@Test func scanPoseCapturesStraightLeftRightInOrder() {
    var p = ScanPose()
    let ev = scan(&p, hold(0, 1.1) + hold(-20, 1.1) /* wrong way: no capture */ + hold(20, 1.1) + hold(-40, 1.1))  // full right turn counts
    #expect(ev.filter { if case .capture = $0 { true } else { false } } == [.capture(.straight), .capture(.left), .capture(.right)])
    #expect(ev.last == .done && p.step == nil)
}

@Test func scanPoseHoldPausesOutOfBandWithoutResetting() {
    var p = ScanPose()
    _ = scan(&p, hold(0, 0.6) + hold(20, 2))  // leaves the straight band mid-hold
    #expect(p.step == .straight && abs(p.hold - 0.6) < 0.07)
    #expect(scan(&p, hold(2, 0.5)) == [.capture(.straight)])
}

@Test func scanPoseTwoFacesPauseNeverCountAndResume() {
    var p = ScanPose()
    #expect(scan(&p, [(2, 0)]) == [.pause(lost: false)])
    #expect(!p.counting && p.hold == 0)
    #expect(scan(&p, [(1, 0)]) == [.resume])
    #expect(p.counting)
}

@Test func scanPoseFailsAfterPauseLimit() {
    var p = ScanPose()
    let ev = scan(&p, Array(repeating: (0, 0), count: Int(Tokens.Scan.pauseFail * 15) + 1))
    #expect(ev.first == .pause(lost: true) && ev.last == .fail(lost: true))
    #expect(scan(&p, hold(0, 2)).isEmpty)  // failed: nothing more counts
}

@Test func scanPoseOnlyStraightHoldsCountOnTheStraightStep() {
    var p = ScanPose()
    var straightYaws: [Double] = []  // frames the face print would take: counting while the step was .straight
    for f in hold(20, 0.5) + hold(0, 1.2) + hold(20, 1.1) {
        let wasStraight = p.step == .straight
        _ = p.frame(faces: f.0, yaw: f.1, dt: 1.0 / 15)
        if wasStraight, p.counting { straightYaws.append(f.1) }
    }
    #expect(straightYaws.count >= 15 && straightYaws.allSatisfy { $0 == 0 })  // the hold's frames, never a turned one
}

@Test func scanPoseStraightWaitsForEnoughFacePrints() {
    var p = ScanPose()  // a slow camera (7 fps): the hold is long done, but straight waits for the 10th print
    var captured = 0
    for i in 1...12 {
        if p.frame(faces: 1, yaw: 0, dt: 1.0 / 7, printed: true).contains(.capture(.straight)) { captured = i }
    }
    #expect(captured == Tokens.Scan.minFrames)
    var q = ScanPose()  // frames without a print never complete straight
    #expect(!(0..<40).flatMap { _ in q.frame(faces: 1, yaw: 0, dt: 1.0 / 15, printed: false) }.contains(.capture(.straight)))
}

@Test func meterNormMapsDecibelsToBarHeight() {
    #expect(Alarm.norm(-160) == 0)
    #expect(Alarm.norm(-50) == 0)
    #expect(Alarm.norm(0) == 1)
    #expect(Alarm.norm(6) == 1)
    #expect(abs(Alarm.norm(-25) - 0.5) < 1e-6)
}

/// VoiceOver can't hold: press starts, press again saves. A drop (the cap, a failure) ends the hold without a release.
@Test func holdButtonTogglesAndDropIsSilent() {
    let b = PanelButton("Hold to record", role: .primary) {}
    var calls: [Bool] = []
    b.onHold = { calls.append($0) }
    b.performClick(nil)
    #expect(b.held && b.toggled && calls == [true])
    b.performClick(nil)
    #expect(!b.held && calls == [true, false])
    b.performClick(nil); b.drop()
    #expect(!b.held && calls == [true, false, true])
    b.performClick(nil)  // a fresh hold, not a stale release
    #expect(calls.last == true)
}

/// The held button survives its relabel to "Release to save" (its release must still land), and lets go once the take ends.
@MainActor @Test func heldButtonSurvivesRelabel() {
    let p = MessagePanel()
    p.show(.idle)
    let hold = p.contentView!.subviews.compactMap { $0 as? PanelButton }.first { $0.title == "Hold to record" }!
    p.onHold = { if $0 { p.show(.recording) } }
    hold.performClick(nil)
    #expect(hold.held && hold.title == "Release to save" && hold.superview != nil)
    p.show(.recorded(3))
    #expect(!hold.held && hold.title == "Hold to record" && hold.superview != nil)
    p.show(.short(nil))
    let titles = p.contentView!.subviews.compactMap { $0 as? PanelButton }.map(\.title)
    #expect(titles.contains("Cancel"))
}
