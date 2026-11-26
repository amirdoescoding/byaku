import Foundation
import Vision

/// Swift-path owner threshold (live bar v2, ARCHITECTURE "Swift alignment"). Provisional.
let ownerThreshold: Float = 0.300

/// away = Away armed (or arming), alarm = Away fired: locked + siren until unlock.
enum GuardState { case off, guarding, alert, error, away, alarm }

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
/// A lone unembeddable face never counts in Guard (fails open); in Away it does (fails closed: any face but the owner's).
func frameHasLooker(_ scores: [Float?], away: Bool = false) -> Bool {
    if scores.count == 1, !away { return scores[0].map { $0 < ownerThreshold } ?? false }
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

/// Guided face scan: straight → left → right. Each pose is captured after `hold` s inside its band (time from frame
/// timestamps, so it is the same on any queue). Leaving the band pauses the hold without resetting it. 0 or 2+ faces
/// pause the scan and those frames never count; `pauseFail` s of pause fails it. Yaw in degrees, + = the user's own left.
struct ScanPose {
    enum Step: Int { case straight, left, right }
    enum Event: Equatable { case pause(lost: Bool), resume, nudge, capture(Step), done, fail(lost: Bool) }
    typealias S = Tokens.Scan

    private(set) var step: Step? = .straight  // nil = done
    private(set) var hold = 0.0, paused: Bool? = nil, failed = false  // paused: true = lost, false = several faces
    /// This frame is inside the current band (feeds the fill; on .straight it also feeds the face print).
    private(set) var counting = false
    private var pausedFor = 0.0, outOfBand = 0.0, prints = 0
    /// 0…1 through the current hold. Straight also waits for minFrames face prints (a slow camera holds longer, never fails late).
    var progress: Double { min(hold / S.hold, step == .straight ? Double(prints) / Double(S.minFrames) : 1) }

    static func inBand(_ s: Step, yaw: Double) -> Bool {
        switch s {
        case .straight: abs(yaw) < S.straight
        case .left: yaw >= S.sideMin
        case .right: -yaw >= S.sideMin  // no ceiling: a full turn counts (side frames never reach the template)
        }
    }

    /// `printed`: this frame produced a face print (exactly one face, embedded). Only straight-step prints are counted.
    mutating func frame(faces: Int, yaw: Double, dt: Double, printed: Bool = true) -> [Event] {
        counting = false
        guard let s = step, !failed else { return [] }
        var ev: [Event] = []
        if faces != 1 {
            let lost = faces == 0
            if paused != lost { ev.append(.pause(lost: lost)) }
            paused = lost; pausedFor += dt
            if pausedFor >= S.pauseFail { failed = true; ev.append(.fail(lost: lost)) }
            return ev
        }
        if paused != nil { paused = nil; pausedFor = 0; ev.append(.resume) }
        guard Self.inBand(s, yaw: yaw) else {
            outOfBand += dt
            if s != .straight, outOfBand >= S.nudgeAfter, outOfBand - dt < S.nudgeAfter { ev.append(.nudge) }
            return ev
        }
        outOfBand = 0; counting = true; hold += dt
        if s == .straight, printed { prints += 1 }
        if progress >= 1 {
            ev.append(.capture(s)); hold = 0
            step = Step(rawValue: s.rawValue + 1)
            if step == nil { ev.append(.done) }
        }
        return ev
    }
}

/// Owner data = the 128 floats only, never an image (invariant 5). One file, one-click delete.
/// The user's recorded Away message (replaces the spoken line). A new take is written to `tmp` and swapped in only
/// when it's kept, so a cancelled re-record leaves the old message. Deleted with one click (AGENTS invariant 5).
struct MessageStore {
    var url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("byaku/message.m4a")
    var tmp: URL { url.deletingLastPathComponent().appendingPathComponent("message-new.m4a") }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }

    func prepare() throws { try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true) }
    /// tmp → url. If it throws, the old message stays.
    func install() throws {
        let fm = FileManager.default
        if exists { _ = try fm.replaceItemAt(url, withItemAt: tmp) } else { try fm.moveItem(at: tmp, to: url) }
    }
    func discardTmp() { try? FileManager.default.removeItem(at: tmp) }
    func delete() throws { if exists { try FileManager.default.removeItem(at: url) } }
}

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
