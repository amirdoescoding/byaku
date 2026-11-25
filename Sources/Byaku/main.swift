import AVFoundation
import CoreGraphics
import Foundation

func detect(fps: Double) -> Never {
    let cam = Camera(fps: fps)
    cam.onFaces = { faces in
        let poses = faces.map { f in
            String(format: "[yaw %.0f° pitch %.0f°]",
                   (f.yaw?.doubleValue ?? .nan) * 180 / .pi, (f.pitch?.doubleValue ?? .nan) * 180 / .pi)
        }
        print("faces=\(faces.count) \(poses.joined(separator: " "))")
    }
    cam.start()
    // Delivered (sensor) fps every 10 s: a power row only counts if this matches the label.
    var last = (0, 0)
    let t = DispatchSource.makeTimerSource(queue: cam.queue)
    t.schedule(deadline: .now() + 10, repeating: 10)
    t.setEventHandler {
        print(String(format: "delivered_fps=%.2f processed_fps=%.2f requested=%.2f",
                     Double(cam.framesDelivered - last.0) / 10, Double(cam.framesProcessed - last.1) / 10, fps))
        last = (cam.framesDelivered, cam.framesProcessed)
    }
    t.resume()
    dispatchMain()
}

func screenIsLocked() -> Bool {
    (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
}

/// Locks via private SACLockScreenImmediate (same call BLEUnlock-style tools use), then verifies.
/// Also counts camera frames while locked (does Away keep seeing after lock?).
func lockTest() -> Never {
    let cam = Camera(fps: 1)
    cam.start()
    sleep(3)
    var method = "SACLockScreenImmediate"
    if let h = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY),
       let sym = dlsym(h, "SACLockScreenImmediate") {
        typealias Lock = @convention(c) () -> Int32
        _ = unsafeBitCast(sym, to: Lock.self)()
    } else {
        // ponytail: fallback only counts as a lock if "require password immediately" is on.
        method = "pmset displaysleepnow (symbol missing: \(String(cString: dlerror())))"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["displaysleepnow"]
        try? p.run(); p.waitUntilExit()
    }
    sleep(3)
    let locked = screenIsLocked()
    let before = cam.queue.sync { cam.framesDelivered }
    sleep(10)
    let during = cam.queue.sync { cam.framesDelivered } - before
    let report = "lock-test: method=\(method) locked=\(locked) frames_while_locked_10s=\(during) still_locked=\(screenIsLocked())"
    print(report)
    FileHandle.standardError.write("\(report)\n".data(using: .utf8)!)
    exit(locked ? 0 : 1)
}

setvbuf(stdout, nil, _IOLBF, 0)  // line-buffer so piped output (logs, power.sh) is live
let args = Array(CommandLine.arguments.dropFirst())
switch args.first {
case "detect":
    var fps = 1.0
    if let i = args.firstIndex(of: "--fps") {
        guard i + 1 < args.count, let v = parseFPS(args[i + 1]) else { fail("--fps needs a number", code: 64) }
        fps = v
    }
    detect(fps: fps)
case "lock-test":
    lockTest()
default:
    fail("usage: byaku detect [--fps N] | lock-test", code: 64)
}
