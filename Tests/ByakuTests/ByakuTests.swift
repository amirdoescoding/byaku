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

@Test(arguments: [(0, nil, GuardState.guarding), (1, Float(0.9), .guarding), (1, Float(0.1), .alert), (1, nil, .guarding),
                  (2, Float(0.9), .alert), (3, nil, .alert)] as [(Int, Float?, GuardState)])
func verdictRules(faces: Int, score: Float?, expected: GuardState) {
    #expect(verdict(faces: faces, score: score) == expected)
}

@Test func ownerTemplateIsUnitMean() {
    let t = ownerTemplate([[1, 0], [0, 1]])!
    #expect(abs(t[0] - t[1]) < 1e-6 && abs(t[0] * t[0] + t[1] * t[1] - 1) < 1e-6)
    #expect(ownerTemplate([]) == nil)
}

@Test func ownerStoreRoundTripAndDelete() throws {
    let s = OwnerStore(url: FileManager.default.temporaryDirectory.appendingPathComponent("byaku-test-\(UUID())/owner.json"))
    #expect(s.load() == nil)
    try s.save([0.5, -0.25])
    #expect(s.load() == [0.5, -0.25])
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
}
