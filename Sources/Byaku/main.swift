import AVFoundation
import CoreGraphics
import CoreML
import Vision
import Foundation

func detect(fps: Double, embedModel: String?) -> Never {
    let cam = Camera(fps: fps)
    // .cpuAndNeuralEngine: with .all the SFace head runs on the GPU (+~0.1 W while a face is visible).
    if let embedModel { cam.embed = must(66) { try loadEmbedder(embedModel, units: .cpuAndNeuralEngine) }.request }
    cam.onFaces = { faces in
        let poses = faces.map { f in
            String(format: "[yaw %.0f° pitch %.0f°]",
                   (f.yaw?.doubleValue ?? .nan) * 180 / .pi, (f.pitch?.doubleValue ?? .nan) * 180 / .pi)
        }
        print("faces=\(faces.count) \(poses.joined(separator: " "))")
    }
    must(69) { try cam.start() }
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
    must(69) { try cam.start() }
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

    let (req, compiled, _) = must(66) { try loadEmbedder(model, units: .cpuAndNeuralEngine) }
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
        let m = must(66) { try loadEmbedder(model, units: units) }.model
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

/// Swift alignment vs OpenCV alignCrop on sample.jpg (refs from ml/convert_sface.py).
/// Warp parity: YuNet points through the Swift solve + vImage warp (bar 0.99). Landmark parity: Vision points (bar 0.98, reported).
func alignCheck(model: String, parityDir: String) -> Never {
    let dir = URL(fileURLWithPath: parityDir)
    guard let ref = try? JSONDecoder().decode([String: [Float]].self, from: Data(contentsOf: dir.appendingPathComponent("parity.json"))),
          let yn = try? JSONDecoder().decode([String: [Double]].self, from: Data(contentsOf: dir.appendingPathComponent("landmarks.json"))),
          let (img, ctx) = bgra(dir.appendingPathComponent("sample.png"))
    else { fail("need parity.json, landmarks.json and sample.png; run `uv run convert_sface.py` in ml/", code: 66) }
    let req = must(66) { try loadEmbedder(model, units: .cpuAndNeuralEngine) }.request
    func embed(_ points: [CGPoint]) -> [Float]? {
        guard let pb = alignedFace(base: ctx.data!, width: img.width, height: img.height, rowBytes: ctx.bytesPerRow, points: points)
        else { return nil }
        try? VNImageRequestHandler(cvPixelBuffer: pb).perform([req])
        return embedding(req)
    }
    let names = ref.keys.sorted()
    func ynPoints(_ n: String) -> [CGPoint] { (0..<5).map { CGPoint(x: yn[n]![4 + 2 * $0], y: yn[n]![5 + 2 * $0]) } }

    var warpWorst: Float = 1
    for n in names {
        guard let v = embed(ynPoints(n)) else { fail("\(n): warp/embed failed", code: 70) }
        let c = cosine(v, ref[n]!)
        warpWorst = min(warpWorst, c)
        print(String(format: "warp %@: swift~alignCrop cos=%.5f", n, c))
    }
    print(String(format: "warp parity worst=%.5f bar=0.99 -> %@", warpWorst, warpWorst > 0.99 ? "PASS" : "FAIL"))

    // Per YuNet face: Vision rects (rev 3) -> landmarks on a 2x crop around it (Vision misses small faces in the
    // full 2048 px crowd; live 640x480 faces are large). Points are mapped back to sample pixels, top-left origin.
    var lmWorst: Float = 1, matched = 0
    var err = [CGFloat](repeating: 0, count: 5)
    for n in names {
        let b = yn[n]!
        let r = CGRect(x: b[0] - b[2] / 2, y: b[1] - b[3] / 2, width: 2 * b[2], height: 2 * b[3])
            .intersection(CGRect(x: 0, y: 0, width: img.width, height: img.height)).integral
        guard let crop = img.cropping(to: r) else { continue }
        let h = VNImageRequestHandler(cgImage: crop)
        let rects = VNDetectFaceRectanglesRequest()
        rects.revision = VNDetectFaceRectanglesRequestRevision3
        try? h.perform([rects])
        let faces = landmarks(rects.results ?? []) { try h.perform([$0]) }
        let c = CGPoint(x: b[0] + b[2] / 2 - r.minX, y: b[1] + b[3] / 2 - r.minY), W = r.width, H = r.height
        guard let f = faces.min(by: { d($0, c, W, H) < d($1, c, W, H) }), d(f, c, W, H) < b[2] / 2,
              let p0 = fivePoints(f, width: crop.width, height: crop.height) else {
            print("landmark \(n): no matching Vision face with landmarks"); continue
        }
        let p = p0.map { CGPoint(x: $0.x + r.minX, y: $0.y + r.minY) }
        matched += 1
        let y = ynPoints(n), iod = hypot(y[1].x - y[0].x, y[1].y - y[0].y)
        let e = (0..<5).map { hypot(p[$0].x - y[$0].x, p[$0].y - y[$0].y) / iod }
        for i in 0..<5 { err[i] += e[i] }
        let cs = embed(p).map { cosine($0, ref[n]!) } ?? 0
        lmWorst = min(lmWorst, cs)
        print(String(format: "landmark %@: cos=%.5f err/IOD eyes %.2f %.2f nose %.2f mouth %.2f %.2f", n, cs, e[0], e[1], e[2], e[3], e[4]))
    }
    let m = err.map { $0 / CGFloat(max(matched, 1)) }
    print(String(format: "landmark parity matched=%d/%d mean err/IOD eyes %.2f %.2f nose %.2f mouth %.2f %.2f worst cos=%.5f bar=0.98 -> %@ (reported, not gating)",
                 matched, names.count, m[0], m[1], m[2], m[3], m[4], lmWorst, matched > 0 && lmWorst > 0.98 ? "PASS" : "FAIL"))
    exit(warpWorst > 0.99 ? 0 : 1)
}

/// Live owner match on the pure-Swift path (Vision landmarks -> align -> SFace), scored by ml/score_segments.py.
/// Prompts go to stderr; stdout carries only `seg <n> <label> <score>` lines. Embeddings stay in memory.
/// Counting rule (pre-registered, see score_segments.py): exactly one face, rect confidence >= 0.5, aligned embedding.
func match(model: String, phases: [String]) -> Never {
    let fps = 5.0, enrollS = 5.0, phaseS = 10.0
    let cam = Camera(fps: fps)
    cam.embed = must(66) { try loadEmbedder(model, units: .cpuAndNeuralEngine) }.request
    var pending: (VNFaceObservation, [Float])? = nil
    var enroll: [[Float]]? = nil, owner: [Float]? = nil, seg: (n: Int, label: String)? = nil
    cam.onEmbedding = { pending = ($0, $1) }
    cam.onFaces = { faces in
        defer { pending = nil }
        if enroll != nil || seg != nil {  // why a frame does or doesn't count, live on stderr
            FileHandle.standardError.write(String(format: "  faces=%d conf=%@ embedded=%@\n", faces.count,
                faces.map { String(format: "%.2f", $0.confidence) }.joined(separator: ","), pending == nil ? "no" : "yes").data(using: .utf8)!)
        }
        guard let v = countedEmbedding(faces, pending) else { return }
        if enroll != nil { enroll!.append(v) }
        if let owner, let seg { print(String(format: "seg %d %@ %.4f", seg.n, seg.label, cosine(v, owner))) }
    }
    func say(_ s: String) { FileHandle.standardError.write("\(s)\n".data(using: .utf8)!) }
    func wait(_ s: Double) { Thread.sleep(forTimeInterval: s) }
    must(69) { try cam.start() }
    say("enroll: you alone, look at the screen. Press Enter to start (\(Int(enrollS)) s).")
    _ = readLine()
    cam.queue.sync { enroll = [] }
    wait(enrollS)
    let e = cam.queue.sync { () -> [[Float]] in defer { enroll = nil }; return enroll! }
    guard let template = ownerTemplate(e) else { fail("no enrollment frame passed the counting rule (see the per-frame lines)", code: 70) }
    cam.queue.sync { owner = template }
    say("enrolled from \(e.count) frames")
    for (i, p) in phases.enumerated() {
        let label = String(p.split(separator: ":")[0])
        say("phase \(i + 1)/\(phases.count): \(p). Set it up, press Enter, hold \(Int(phaseS)) s.")
        _ = readLine()
        cam.queue.sync { seg = (i + 1, label) }
        wait(phaseS)
        cam.queue.sync { seg = nil }
        say("phase \(i + 1) done")
    }
    exit(0)
}

/// Distance from a Vision face's bbox centre to a top-left-origin pixel point.
private func d(_ f: VNFaceObservation, _ c: CGPoint, _ W: CGFloat, _ H: CGFloat) -> CGFloat {
    hypot(f.boundingBox.midX * W - c.x, (1 - f.boundingBox.midY) * H - c.y)
}

/// CLI wrapper: a thrown error exits with `code` (the app shows it as an error state instead).
func must<T>(_ code: Int32, _ f: () throws -> T) -> T {
    do { return try f() } catch { fail("\(error)", code: code) }
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
case "align":
    guard args.count == 3 else { fail("usage: byaku align <model.mlpackage> <parity dir>", code: 64) }
    alignCheck(model: args[1], parityDir: args[2])
case "match":
    guard args.count >= 3 else { fail("usage: byaku match <model.mlpackage> <label[:note]>... (labels: owner, stranger, owner-photo)", code: 64) }
    match(model: args[1], phases: Array(args[2...]))
case "app":
    runApp(model: args.count > 1 ? args[1] : "ml/models/sface.mlpackage")
case "lock-test":
    lockTest()
case "embed":
    guard args.count == 3 else { fail("usage: byaku embed <model.mlpackage> <parity dir>", code: 64) }
    embedCheck(model: args[1], parityDir: args[2])
default:
    fail("usage: byaku detect [--fps N] [--embed model.mlpackage] | embed|align <model.mlpackage> <parity dir> | match <model> <label>... | app [model] | lock-test", code: 64)
}
