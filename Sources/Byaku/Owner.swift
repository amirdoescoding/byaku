import Foundation
import Vision

/// Swift-path owner threshold (live bar v2, ARCHITECTURE "Swift alignment"). Provisional.
let ownerThreshold: Float = 0.300

enum GuardState { case off, guarding, alert, error }

/// Counting rule (pre-registered in af2f29e, conf amended in 579821d): exactly one face, rect confidence >= 0.5,
/// and an aligned embedding of that face. Returns the unit embedding when the frame counts.
func countedEmbedding(_ faces: [VNFaceObservation], _ pending: (VNFaceObservation, [Float])?) -> [Float]? {
    guard faces.count == 1, let (face, v) = pending, face.confidence >= 0.5 else { return nil }
    return unit(v)
}

func unit(_ v: [Float]) -> [Float] { let n = v.reduce(0) { $0 + $1 * $1 }.squareRoot(); return v.map { $0 / n } }

/// Owner template = unit mean of the counted enrollment frames.
func ownerTemplate(_ frames: [[Float]]) -> [Float]? {
    guard let first = frames.first else { return nil }
    return unit((0..<first.count).map { i in frames.reduce(0) { $0 + $1[i] } })
}

/// One Guard frame → state. `score` = cosine of the largest face to the owner, nil if it couldn't be embedded.
/// ponytail: only the largest face is embedded, so any second face counts as a looker; per-face embedding lands with the policy PR.
func verdict(faces: Int, score: Float?) -> GuardState {
    if faces >= 2 { return .alert }
    if faces == 1, let score, score < ownerThreshold { return .alert }
    return .guarding  // nobody, the owner, or an unembeddable face (Guard fails open)
}

/// Owner data = the 128 floats only, never an image (invariant 5). One file, one-click delete.
struct OwnerStore {
    var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("byaku/owner.json")

    func load() -> [Float]? { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Float].self, from: $0) } }

    func save(_ v: [Float]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(v).write(to: url, options: .atomic)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
