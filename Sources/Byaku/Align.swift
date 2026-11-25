import CoreGraphics
import CoreVideo
import ImageIO
import Vision

/// BGRA source → 112×112 BGRA face crop on the CPU, matching OpenCV alignCrop (warpAffine, bilinear, black border).
/// `points` are the 5 face points in source pixels, top-left origin, image-left first.
/// Plain loop, not vImage: vImage's Lanczos kernel drifts to cos 0.977 vs alignCrop on small faces; 12.5k px is trivial.
func alignedFace(base: UnsafeMutableRawPointer, width: Int, height: Int, rowBytes: Int, points: [CGPoint]) -> CVPixelBuffer? {
    var out: CVPixelBuffer?
    guard CVPixelBufferCreate(nil, 112, 112, kCVPixelFormatType_32BGRA, nil, &out) == kCVReturnSuccess, let out else { return nil }
    CVPixelBufferLockBaseAddress(out, [])
    defer { CVPixelBufferUnlockBaseAddress(out, []) }
    guard let dst = CVPixelBufferGetBaseAddress(out)?.assumingMemoryBound(to: UInt8.self) else { return nil }
    let dstRow = CVPixelBufferGetBytesPerRow(out)
    let src = base.assumingMemoryBound(to: UInt8.self)
    let inv = similarity(src: points, dst: arcfaceTemplate).inverted()  // dst pixel -> src pixel, centres on integers
    for v in 0..<112 {
        for u in 0..<112 {
            let p = CGPoint(x: u, y: v).applying(inv)
            let x0 = Int(floor(p.x)), y0 = Int(floor(p.y))
            let fx = Float(p.x) - Float(x0), fy = Float(p.y) - Float(y0)
            var acc: (Float, Float, Float) = (0, 0, 0)
            for (dx, dy, w) in [(0, 0, (1 - fx) * (1 - fy)), (1, 0, fx * (1 - fy)), (0, 1, (1 - fx) * fy), (1, 1, fx * fy)] {
                let x = x0 + dx, y = y0 + dy
                guard x >= 0, y >= 0, x < width, y < height else { continue }  // outside taps are black
                let i = y * rowBytes + x * 4
                acc.0 += w * Float(src[i]); acc.1 += w * Float(src[i + 1]); acc.2 += w * Float(src[i + 2])
            }
            let o = v * dstRow + u * 4
            dst[o] = UInt8((acc.0).rounded()); dst[o + 1] = UInt8((acc.1).rounded()); dst[o + 2] = UInt8((acc.2).rounded()); dst[o + 3] = 255
        }
    }
    return out
}

/// Same, from a locked 32BGRA pixel buffer (the camera path).
func alignedFace(_ pb: CVPixelBuffer, points: [CGPoint]) -> CVPixelBuffer? {
    CVPixelBufferLockBaseAddress(pb, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(pb) else { return nil }
    return alignedFace(base: base, width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb),
                       rowBytes: CVPixelBufferGetBytesPerRow(pb), points: points)
}

/// Vision landmarks → the 5 alignCrop points in image pixels, top-left origin.
/// Mapping chosen by mean pixel error to YuNet over 7 sample faces (err/IOD), never by embedding cosine:
/// eyes = pupils 0.290 (contour centroid 0.299); nose = nose-region centroid 0.267 (crest lowest 0.321, region lowest 0.352);
/// mouth = outer-lip extremes along the eye axis 0.269 (inner lips 0.389).
func fivePoints(_ face: VNFaceObservation, width: Int, height: Int) -> [CGPoint]? {
    guard let lm = face.landmarks, let le = lm.leftPupil, let re = lm.rightPupil, let nose = lm.nose,
          let lips = lm.outerLips else { return nil }
    let size = CGSize(width: width, height: height)
    func pts(_ r: VNFaceLandmarkRegion2D) -> [CGPoint] {
        r.pointsInImage(imageSize: size).map { CGPoint(x: $0.x, y: CGFloat(height) - $0.y) }  // Vision is bottom-left
    }
    let eyes = (pts(le) + pts(re)).sorted { $0.x < $1.x }
    let np = pts(nose)
    guard eyes.count == 2, !np.isEmpty else { return nil }
    let tip = CGPoint(x: np.map(\.x).reduce(0, +) / CGFloat(np.count), y: np.map(\.y).reduce(0, +) / CGFloat(np.count))
    // Mouth corners: extremes of the outer lip along the eye axis (robust to roll).
    let ax = CGPoint(x: eyes[1].x - eyes[0].x, y: eyes[1].y - eyes[0].y)
    let lipPts = pts(lips)
    guard let l = lipPts.min(by: { $0.x * ax.x + $0.y * ax.y < $1.x * ax.x + $1.y * ax.y }),
          let r = lipPts.max(by: { $0.x * ax.x + $0.y * ax.y < $1.x * ax.x + $1.y * ax.y }) else { return nil }
    return [eyes[0], eyes[1], tip, l, r]
}

/// Rect → landmarks without re-detecting faces (reuses the rev-3 rects, so yaw/pitch stay from that request).
func landmarks(_ faces: [VNFaceObservation], perform: (VNRequest) throws -> Void) -> [VNFaceObservation] {
    let req = VNDetectFaceLandmarksRequest()
    req.inputFaceObservations = faces
    try? perform(req)
    return req.results ?? []
}

/// BGRA bitmap of an image file (top row first); opaque, so premultiplication is a no-op.
func bgra(_ url: URL) -> (CGImage, CGContext)? {
    guard let s = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(s, 0, nil),
          let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    return (img, ctx)
}
