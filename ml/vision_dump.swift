// Vision landmark regions per face → JSON (image pixels, top-left origin). Feeds ml/scan_mesh.py --remap.
// Run: swift ml/vision_dump.swift <images…> > vision.json
import Vision
import AppKit
var out: [String: [[String: [[Double]]]]] = [:]
for f in CommandLine.arguments.dropFirst() {
  let img = NSImage(contentsOfFile: f)!.cgImage(forProposedRect: nil, context: nil, hints: nil)!
  let h = VNImageRequestHandler(cgImage: img)
  let r = VNDetectFaceRectanglesRequest(); r.revision = VNDetectFaceRectanglesRequestRevision3
  try! h.perform([r])
  let l = VNDetectFaceLandmarksRequest(); l.inputFaceObservations = r.results
  try! h.perform([l])
  let size = CGSize(width: img.width, height: img.height)
  out[(f as NSString).lastPathComponent] = (l.results ?? []).compactMap { o in
    guard let m = o.landmarks else { return nil }
    let regs: [(String, VNFaceLandmarkRegion2D?)] = [("faceContour",m.faceContour),("leftEye",m.leftEye),("rightEye",m.rightEye),("leftEyebrow",m.leftEyebrow),("rightEyebrow",m.rightEyebrow),("nose",m.nose),("noseCrest",m.noseCrest),("medianLine",m.medianLine),("outerLips",m.outerLips),("innerLips",m.innerLips),("leftPupil",m.leftPupil),("rightPupil",m.rightPupil)]
    var d: [String: [[Double]]] = [:]
    for (n, reg) in regs { if let reg { d[n] = reg.pointsInImage(imageSize: size).map { [Double($0.x), Double(size.height - $0.y)] } } }
    return d
  }
}
print(String(data: try! JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]), encoding: .utf8)!)
