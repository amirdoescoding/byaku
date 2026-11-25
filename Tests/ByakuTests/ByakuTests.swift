import CoreGraphics
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
