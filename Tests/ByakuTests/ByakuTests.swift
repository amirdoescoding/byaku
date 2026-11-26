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
