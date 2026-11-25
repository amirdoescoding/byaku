import AVFoundation
import CoreGraphics
import CoreML
import Vision
import Foundation

func detect(fps: Double, embedModel: String?) -> Never {
    let cam = Camera(fps: fps)
    // .cpuAndNeuralEngine: with .all the SFace head runs on the GPU (+~0.1 W while a face is visible).
    if let embedModel { cam.embed = loadEmbedder(embedModel, units: .cpuAndNeuralEngine).request }
    cam.onFaces = { faces in
        let poses = faces.map { f in
            String(format: "[yaw %.0f° pitch %.0f°]",
                   (f.yaw?.doubleValue ?? .nan) * 180 / .pi, (f.pitch?.doubleValue ?? .nan) * 180 / .pi)
        }
        print("faces=\(faces.count) \(poses.joined(separator: " "))")
    }
    cam.start()
    // Delivered (sensor) fps every 10 s: a power row only counts if this matches the label.
    var last = (0, 0, 0)
    let t = DispatchSource.makeTimerSource(queue: cam.queue)
    t.schedule(deadline: .now() + 10, repeating: 10)
    t.setEventHandler {
        print(String(format: "delivered_fps=%.2f processed_fps=%.2f requested=%.2f embed_hz=%.2f",
                     Double(cam.framesDelivered - last.0) / 10, Double(cam.framesProcessed - last.1) / 10, fps,
                     Double(cam.embedsRun - last.2) / 10))
        last = (cam.framesDelivered, cam.framesProcessed, cam.embedsRun)
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

/// Swift parity vs Python (parity.json from ml/convert_sface.py), ANE placement, and latency .all vs .cpuOnly.
func embedCheck(model: String, parityDir: String) -> Never {
    let dir = URL(fileURLWithPath: parityDir)
    guard let data = try? Data(contentsOf: dir.appendingPathComponent("parity.json")),
          let ref = try? JSONDecoder().decode([String: [Float]].self, from: data), !ref.isEmpty
    else { fail("no parity.json in \(parityDir); run `uv run convert_sface.py` in ml/", code: 66) }

    let (req, compiled, _) = loadEmbedder(model, units: .cpuAndNeuralEngine)
    var worst: Float = 1
    for name in ref.keys.sorted() {
        let h = VNImageRequestHandler(url: dir.appendingPathComponent(name))
        do { try h.perform([req]) } catch { fail("\(name): \(error)", code: 70) }
        guard let v = embedding(req), v.count == ref[name]!.count else { fail("\(name): no \(ref[name]!.count)-d output", code: 70) }
        let c = cosine(v, ref[name]!)
        worst = min(worst, c)
        print(String(format: "%@: swift~python cos=%.5f", name, c))
    }
    print(String(format: "parity worst=%.5f bar=0.99 -> %@", worst, worst > 0.99 ? "PASS" : "FAIL"))

    if #available(macOS 14.4, *) {
      for units in [MLComputeUnits.all, .cpuAndNeuralEngine] {
        let sem = DispatchSemaphore(value: 0)
        Task {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = units
            if let plan = try? await MLComputePlan.load(contentsOf: compiled, configuration: cfg),
               case let .program(program) = plan.modelStructure, let ops = program.functions["main"]?.block.operations {
                var count: [String: Int] = [:], offANE: [String] = []
                for op in ops {
                    let dev: String
                    switch plan.deviceUsage(for: op)?.preferred {
                    case .neuralEngine?: dev = "ane"
                    case .gpu?: dev = "gpu"
                    case .cpu?: dev = "cpu"
                    default: dev = "none"  // consts and other ops with no device
                    }
                    count[dev, default: 0] += 1
                    if dev == "gpu" || dev == "cpu" { offANE.append("\(op.operatorName)@\(dev)") }
                }
                print("placement \(units == .all ? "all" : "cpuAndNeuralEngine") (ops by preferred device): \(count.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))")
                print("off-ANE ops: \(offANE.joined(separator: " "))")
            } else { print("placement: MLComputePlan unavailable") }
            sem.signal()
        }
        sem.wait()
      }
    }

    let face = dir.appendingPathComponent(ref.keys.sorted()[0])
    // Time the model itself: a reused Vision handler caches results and would report ~0 ms.
    for (label, units) in [("all", MLComputeUnits.all), ("cpuAndNeuralEngine", .cpuAndNeuralEngine), ("cpuOnly", .cpuOnly)] {
        let m = loadEmbedder(model, units: units).model
        guard let (name, desc) = m.modelDescription.inputDescriptionsByName.first, let constraint = desc.imageConstraint,
              let img = try? MLFeatureValue(imageAt: face, constraint: constraint),
              let input = try? MLDictionaryFeatureProvider(dictionary: [name: img])
        else { fail("cannot build model input", code: 70) }
        _ = try? m.prediction(from: input)  // warm-up
        let t0 = Date()
        for _ in 0..<50 { _ = try? m.prediction(from: input) }
        print(String(format: "latency %@: %.2f ms/embed (mean of 50)", label, Date().timeIntervalSince(t0) * 1000 / 50))
    }
    exit(worst > 0.99 ? 0 : 1)
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
    var embedModel: String? = nil
    if let i = args.firstIndex(of: "--embed") {
        guard i + 1 < args.count else { fail("--embed needs a model path", code: 64) }
        embedModel = args[i + 1]
    }
    detect(fps: fps, embedModel: embedModel)
case "lock-test":
    lockTest()
case "embed":
    guard args.count == 3 else { fail("usage: byaku embed <model.mlpackage> <parity dir>", code: 64) }
    embedCheck(model: args[1], parityDir: args[2])
default:
    fail("usage: byaku detect [--fps N] [--embed model.mlpackage] | embed <model.mlpackage> <parity dir> | lock-test", code: 64)
}
