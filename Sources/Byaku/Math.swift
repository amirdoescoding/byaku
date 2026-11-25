import CoreGraphics

/// Requested camera rate, clamped to what the spike measures. nil = not a number.
func parseFPS(_ s: String) -> Double? {
    guard let v = Double(s), v.isFinite else { return nil }
    return min(max(v, 1), 30)
}

/// Cosine similarity; 0 when either vector is all zeros (never NaN).
func cosine(_ a: [Float], _ b: [Float]) -> Float {
    precondition(a.count == b.count)
    var dot: Float = 0, na: Float = 0, nb: Float = 0
    for i in a.indices { dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i] }
    return na == 0 || nb == 0 ? 0 : dot / (na.squareRoot() * nb.squareRoot())
}

/// ArcFace 112×112 template (OpenCV alignCrop): eyes, nose tip, mouth corners; image-left first, top-left origin.
let arcfaceTemplate: [CGPoint] = [
    CGPoint(x: 38.2946, y: 51.6963), CGPoint(x: 73.5318, y: 51.5014), CGPoint(x: 56.0252, y: 71.7366),
    CGPoint(x: 41.5493, y: 92.3655), CGPoint(x: 70.7299, y: 92.2041),
]

/// Least-squares 2D similarity (rotation + uniform scale + translation, no reflection) mapping src onto dst.
/// Closed form in complex numbers: w = a·z + t, a = Σ conj(z̄ᵢ)·w̄ᵢ / Σ|z̄ᵢ|² on centred points (= Umeyama in 2D).
func similarity(src: [CGPoint], dst: [CGPoint]) -> CGAffineTransform {
    precondition(src.count == dst.count && src.count >= 2)
    let n = CGFloat(src.count)
    let ms = CGPoint(x: src.map(\.x).reduce(0, +) / n, y: src.map(\.y).reduce(0, +) / n)
    let md = CGPoint(x: dst.map(\.x).reduce(0, +) / n, y: dst.map(\.y).reduce(0, +) / n)
    var p: CGFloat = 0, q: CGFloat = 0, norm: CGFloat = 0
    for (s, d) in zip(src, dst) {
        let (zx, zy, wx, wy) = (s.x - ms.x, s.y - ms.y, d.x - md.x, d.y - md.y)
        p += zx * wx + zy * wy   // Re(conj(z)·w)
        q += zx * wy - zy * wx   // Im(conj(z)·w)
        norm += zx * zx + zy * zy
    }
    p /= norm; q /= norm
    // x' = p·x − q·y + tx, y' = q·x + p·y + ty
    return CGAffineTransform(a: p, b: q, c: -q, d: p, tx: md.x - (p * ms.x - q * ms.y), ty: md.y - (q * ms.x + p * ms.y))
}
