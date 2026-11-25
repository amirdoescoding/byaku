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
