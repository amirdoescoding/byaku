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

/// Gaze gate v0: a face counts as looking at the screen when its head pose is within these limits (radians, Vision rev 3).
/// Provisional (docs/designs/guard-actions.md §1); tune live with a second person. Missing pose counts as facing (don't miss a looker).
let maxYaw: Float = 30 * .pi / 180, maxPitch: Float = 25 * .pi / 180

func facesScreen(yaw: Float?, pitch: Float?) -> Bool { abs(yaw ?? 0) <= maxYaw && abs(pitch ?? 0) <= maxPitch }

/// One Guard frame. `scores` = owner cosine of every face that passed the gaze gate, nil = couldn't embed.
/// A looker scores below the owner threshold, or can't be embedded while 2+ faces face the screen.
/// A lone unembeddable face never counts (Guard fails open).
func frameHasLooker(_ scores: [Float?]) -> Bool {
    if scores.count == 1 { return scores[0].map { $0 < ownerThreshold } ?? false }
    return scores.contains { $0 == nil || $0! < ownerThreshold }
}

/// Alert fires when n of the last m frames have a looker, clears after `clear` clean frames in a row.
/// At 1 fps: ~2 s to fire, ~3 s to clear. Make a new one when Guard (re)starts.
struct Debounce {
    let n = 2, m = 3, clear = 3
    private var recent: [Bool] = [], clean = 0
    private(set) var alert = false

    mutating func add(_ looker: Bool) -> Bool {
        recent = Array((recent + [looker]).suffix(m))
        clean = looker ? 0 : clean + 1
        if !alert, recent.filter({ $0 }).count >= n { alert = true }
        if alert, clean >= clear { alert = false }
        return alert
    }
}

/// Owner data = the 128 floats only, never an image (invariant 5). One file, one-click delete.
struct OwnerStore {
    var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("byaku/owner.json")

    /// Anything but a 128-float SFace template reads as "no face set up" (a bad file would trip cosine's precondition).
    func load() -> [Float]? {
        (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Float].self, from: $0) }.flatMap { $0.count == 128 ? $0 : nil }
    }

    func save(_ v: [Float]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(v).write(to: url, options: .atomic)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
