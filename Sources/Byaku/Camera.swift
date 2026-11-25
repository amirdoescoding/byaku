import AVFoundation
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
    private var dropTo: Double? = nil      // software throttle when the sensor can't go this slow
    private var lastProcessed = Date.distantPast
    private let handler = VNSequenceRequestHandler()
    private let request: VNDetectFaceRectanglesRequest = {
        let r = VNDetectFaceRectanglesRequest()
        r.revision = VNDetectFaceRectanglesRequestRevision3   // rev 3 fills yaw + pitch
        return r
    }()

    init(fps: Double) { self.fps = fps }

    func start() {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            let sem = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .video) { _ in sem.signal() }
            sem.wait()
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            fail("camera access denied for the host app (\(hostApp())). Allow it in System Settings → Privacy & Security → Camera.", code: 77)
        }
        // .builtInWideAngleCamera excludes Continuity (iPhone) and external webcams.
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified
        ).devices.first else { fail("no built-in camera found", code: 69) }

        // Smallest format ≥ 640 px wide; prefer one whose min rate reaches the requested fps.
        let formats = device.formats.filter { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width >= 640 }
        func width(_ f: AVCaptureDevice.Format) -> Int32 { CMVideoFormatDescriptionGetDimensions(f.formatDescription).width }
        func minRate(_ f: AVCaptureDevice.Format) -> Double { f.videoSupportedFrameRateRanges.map(\.minFrameRate).min() ?? 30 }
        guard let format = formats.min(by: { (minRate($0), width($0)) < (minRate($1), width($1)) }) else {
            fail("no usable camera format", code: 69)
        }
        let d = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        print("camera: \(device.localizedName) \(d.width)x\(d.height) ranges=\(format.videoSupportedFrameRateRanges.map { "\($0.minFrameRate)-\($0.maxFrameRate)" }) host=\(hostApp())")

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            fail("cannot open camera input", code: 69)
        }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
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
        } catch { fail("cannot configure camera: \(error)", code: 69) }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sb: CMSampleBuffer, from connection: AVCaptureConnection) {
        framesDelivered += 1
        if let dropTo, Date().timeIntervalSince(lastProcessed) < 1 / dropTo { return }
        lastProcessed = Date()
        guard let pb = CMSampleBufferGetImageBuffer(sb) else { return }
        framesProcessed += 1
        try? handler.perform([request], on: pb)
        onFaces(request.results ?? [])
    }
}

/// Camera permission (TCC) belongs to the app that launched us, not this binary.
func hostApp() -> String {
    ProcessInfo.processInfo.environment["__CFBundleIdentifier"]
        ?? ProcessInfo.processInfo.environment["TERM_PROGRAM"] ?? "unknown"
}
