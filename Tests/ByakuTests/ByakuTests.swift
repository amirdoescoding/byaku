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
