import AVFoundation
import CoreML
import Vision

func fail(_ msg: String, code: Int32) -> Never {
    FileHandle.standardError.write("byaku: \(msg)\n".data(using: .utf8)!)
    exit(code)
}

/// Built-in camera → Vision face rectangles. Frames stay in memory; nothing touches disk.
final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "byaku.camera")
    let fps: Double
    var onFaces: ([VNFaceObservation]) -> Void = { _ in }
    private(set) var framesDelivered = 0   // sensor frames, read on `queue`
    private(set) var framesProcessed = 0   // frames Vision ran on
    var embed: VNCoreMLRequest? = nil      // set by `detect --embed` / `match`: SFace on the largest face, aligned
    private(set) var embedsRun = 0
    var onEmbedding: (VNFaceObservation, [Float]) -> Void = { _, _ in }  // largest face (rect) + embedding, before onFaces
    /// Largest face's landmarks (with yaw/pitch/roll) and the frame size in pixels, before onEmbedding. The face scan draws its mask from it.
    var onLandmarks: (VNFaceObservation, CGSize) -> Void = { _, _ in }
    /// App Guard: one entry per face facing the screen (gaze gate first, then embed), nil = couldn't embed. Before onFaces.
    /// When set, it replaces the largest-face path; `detect --embed` and `match` leave it nil and keep their pre-registered behaviour.
    var onFrame: (([[Float]?]) -> Void)? = nil
    private var dropTo: Double? = nil      // software throttle when the sensor can't go this slow
    private var lastProcessed = Date.distantPast
    private let handler = VNSequenceRequestHandler()
    private let request: VNDetectFaceRectanglesRequest = {
        let r = VNDetectFaceRectanglesRequest()
        r.revision = VNDetectFaceRectanglesRequestRevision3   // rev 3 fills yaw + pitch
        return r
    }()

    init(fps: Double) { self.fps = fps }

    struct Failure: Error, CustomStringConvertible { let description: String }

    func start() throws {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let sem = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .video) { _ in sem.signal() }
            sem.wait()
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw Failure(description: "camera access denied for the host app (\(hostApp())). Allow it in System Settings → Privacy & Security → Camera.")
        }
        // .builtInWideAngleCamera excludes Continuity (iPhone) and external webcams.
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified
        ).devices.first else { throw Failure(description: "no built-in camera found") }

        // Smallest format ≥ 640 px wide; prefer one whose min rate reaches the requested fps.
        let formats = device.formats.filter { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width >= 640 }
        func width(_ f: AVCaptureDevice.Format) -> Int32 { CMVideoFormatDescriptionGetDimensions(f.formatDescription).width }
        func minRate(_ f: AVCaptureDevice.Format) -> Double { f.videoSupportedFrameRateRanges.map(\.minFrameRate).min() ?? 30 }
        guard let format = formats.min(by: { (minRate($0), width($0)) < (minRate($1), width($1)) }) else {
            throw Failure(description: "no usable camera format")
        }
        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        print("camera: \(device.localizedName) \(d.width)x\(d.height) ranges=\(format.videoSupportedFrameRateRanges.map { "\($0.minFrameRate)-\($0.maxFrameRate)" }) host=\(hostApp())")

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            throw Failure(description: "cannot open camera input")
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]  // CPU warp reads BGRA
        output.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(output)
        session.startRunning()

        // Set format + rate AFTER startRunning; the session can reset them on start.
        let sensorFPS = max(fps, minRate(format))
        if sensorFPS > fps {
            dropTo = fps
            print("note: sensor min is \(sensorFPS) fps; dropping frames in software (sensor at full rate)")
        }
        do {
            try device.lockForConfiguration()
            device.activeFormat = format
            let dur = CMTime(value: 1000, timescale: CMTimeScale(sensorFPS * 1000))
            device.activeVideoMinFrameDuration = dur
            device.activeVideoMaxFrameDuration = dur
            device.unlockForConfiguration()
        } catch { session.stopRunning(); throw Failure(description: "cannot configure camera: \(error)") }
    }

    /// Stops the sensor (LED off). A Camera is single-use: make a new one to start again.
    func stop() { session.stopRunning() }

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        framesDelivered += 1
        if let dropTo, Date().timeIntervalSince(lastProcessed) < 1 / dropTo { return }
        lastProcessed = Date()
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        framesProcessed += 1
        try? handler.perform([request], on: pb)
        let faces = request.results ?? []
        if let onFrame, let embed {
            // ponytail: at most 4 facing faces, largest first; each costs ~20–25 mW at 1 fps. Raise if crowds matter.
            let facing = faces.filter { facesScreen(yaw: $0.yaw?.floatValue, pitch: $0.pitch?.floatValue) }
                .sorted { $0.boundingBox.width > $1.boundingBox.width }.prefix(4)
            let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
            let marked = facing.isEmpty ? [] : landmarks(Array(facing), perform: { try handler.perform([$0], on: pb) })
            var out: [[Float]?] = marked.map { lm in
                guard let pts = fivePoints(lm, width: w, height: h), let crop = alignedFace(pb, points: pts) else { return nil }
                // A failed perform must not hand back the previous face's vector (the request is reused per face).
                guard (try? VNImageRequestHandler(cvPixelBuffer: crop).perform([embed])) != nil else { return nil }
                embedsRun += 1
                return embedding(embed)
            }
            out += Array(repeating: nil, count: max(0, facing.count - marked.count))  // landmarks missed a face
            onFrame(out)
        } else if let embed, let face = faces.max(by: { $0.boundingBox.width < $1.boundingBox.width }),
           let lm = landmarks([face], perform: { try handler.perform([$0], on: pb) }).first {
            let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb)
            onLandmarks(lm, CGSize(width: w, height: h))
            if let pts = fivePoints(lm, width: w, height: h), let crop = alignedFace(pb, points: pts) {
                try? VNImageRequestHandler(cvPixelBuffer: crop).perform([embed])
                embedsRun += 1
                if let v = embedding(embed) { onEmbedding(face, v) }
            }
        }
        onFaces(faces)
    }
}

/// Camera permission (TCC) belongs to the app that launched us, not this binary.
func hostApp() -> String {
    ProcessInfo.processInfo.environment["__CFBundleIdentifier"]
        ?? ProcessInfo.processInfo.environment["TERM_PROGRAM"] ?? "unknown"
}

/// Compiles an .mlpackage at runtime (no Xcode / coremlcompiler) and wraps it as a Vision request.
// ponytail: recompiles into temp on every launch; cache the .mlmodelc in Application Support if startup matters.
func loadEmbedder(_ path: String, units: MLComputeUnits) throws -> (request: VNCoreMLRequest, compiled: URL, model: MLModel) {
    do {
        let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: path))
        let cfg = MLModelConfiguration()
        cfg.computeUnits = units
        let model = try MLModel(contentsOf: compiled, configuration: cfg)
        let req = VNCoreMLRequest(model: try VNCoreMLModel(for: model))
        req.imageCropAndScaleOption = .scaleFill
        return (req, compiled, model)
    } catch { throw Camera.Failure(description: "cannot load model \(path): \(error)") }
}

func embedding(_ req: VNCoreMLRequest) -> [Float]? {
    guard let a = (req.results?.first as? VNCoreMLFeatureValueObservation)?.featureValue.multiArrayValue else { return nil }
    return (0..<a.count).map { a[$0].floatValue }
}
