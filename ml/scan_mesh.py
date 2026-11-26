# /// script
# requires-python = "==3.12.*"
# dependencies = ["numpy", "scipy", "mediapipe"]
# ///
"""Face-scan mask mesh: MediaPipe's canonical face (Apache-2.0) decimated to a low-poly mask with eye and mouth holes,
plus the map from Vision's 76 landmarks to its vertices. Dev tooling only; the app ships the generated table.

  uv run ml/scan_mesh.py [N]          → design/scan/mesh.json (+ Sources/Byaku/ScanMesh.swift with --swift)
  uv run ml/scan_mesh.py --remap      → re-derive VISION_TO_MP from vision.json (swift ml/vision_dump.swift <faces> > vision.json)
"""
import collections, hashlib, json, pathlib, sys, urllib.request
import numpy as np
from scipy.spatial import Delaunay

ML = pathlib.Path(__file__).parent
MODELS, ROOT = ML / "models", ML.parent
URLS = {  # pinned: the mediapipe master branch is mutable
    "canonical_face_model.obj": ("https://raw.githubusercontent.com/google-ai-edge/mediapipe/master/mediapipe/modules/face_geometry/data/canonical_face_model.obj",
                                 "8bac80443397e113f41a8b565ea72c59390bc031d9defab289dba7bc0c54e618"),
    "face_landmarker.task": ("https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task",
                             "64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"),
}
# Vision region point i → canonical vertex. Derived by --remap on the 8 parity faces (×4): nearest MediaPipe landmark per Vision
# point, majority vote; 7 faces matched, median error 0.037 IOD, max 0.103 (chin). Pupils have no vertex; 158/386 are the lids above.
VISION_TO_MP = {
    "faceContour": [356, 447, 366, 435, 367, 365, 378, 400, 152, 148, 149, 136, 172, 215, 93, 234, 127],
    "leftEye": [246, 160, 157, 133, 153, 144], "rightEye": [263, 387, 384, 414, 380, 373],
    "leftEyebrow": [70, 105, 107, 55, 223, 46], "rightEyebrow": [300, 334, 336, 285, 443, 300],
    "nose": [6, 126, 98, 60, 2, 250, 327, 420], "noseCrest": [168, 6, 195, 4, 115, 440],
    "medianLine": [168, 6, 195, 4, 2, 0, 12, 14, 16, 152],
    "outerLips": [40, 39, 37, 0, 267, 269, 270, 410, 375, 404, 16, 85, 89, 61], "innerLips": [81, 12, 271, 402, 14, 178],
    "leftPupil": [158], "rightPupil": [386],
}
# Holes (MediaPipe's own loops): the mask has open eyes and a mouth slit.
HOLES = [
    [33, 7, 163, 144, 145, 153, 154, 155, 133, 173, 157, 158, 159, 160, 161, 246],
    [263, 249, 390, 373, 374, 380, 381, 382, 362, 398, 384, 385, 386, 387, 388, 466],
    [78, 95, 88, 178, 87, 14, 317, 402, 318, 324, 308, 415, 310, 311, 312, 13, 82, 81, 80, 191],
]


def fetch(name):
    url, sha = URLS[name]
    p = MODELS / name
    if not p.exists():
        MODELS.mkdir(exist_ok=True); print(f"downloading {name}", file=sys.stderr); urllib.request.urlretrieve(url, p)
    d = hashlib.sha256(p.read_bytes()).hexdigest()
    assert d == sha, f"{name} sha256 {d} != pinned {sha}; delete it and re-fetch, or re-pin after review"
    return p


def load_obj(p):
    V, F = [], []
    for line in p.read_text().splitlines():
        t = line.split()
        if t and t[0] == "v": V.append([float(x) for x in t[1:4]])
        if t and t[0] == "f": F.append([int(x.split("/")[0]) - 1 for x in t[1:4]])
    return np.array(V), F


def outer_loop(F):
    """The mesh's only boundary: the face oval, in order."""
    E = collections.Counter(tuple(sorted((f[i], f[(i + 1) % 3]))) for f in F for i in range(3))
    adj = collections.defaultdict(list)
    for (a, b), c in E.items():
        if c == 1: adj[a].append(b); adj[b].append(a)
    loop = [next(iter(adj))]
    while True:
        nx = [n for n in adj[loop[-1]] if n not in loop]
        if not nx: return loop
        loop.append(nx[0])


def inside(pts, poly):
    """Even-odd point-in-polygon, vectorised over pts (n×2)."""
    x, y, r = pts[:, 0], pts[:, 1], np.zeros(len(pts), bool)
    for (x1, y1), (x2, y2) in zip(poly, np.roll(poly, -1, 0)):
        c = ((y1 > y) != (y2 > y)) & (x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-12) + x1)
        r ^= c
    return r


def decimate(V, F, n):
    oval = outer_loop(F)
    keep = list(dict.fromkeys(oval + [i for h in HOLES for i in h] + [i for v in VISION_TO_MP.values() for i in v]))
    rest = [i for i in range(len(V)) if i not in keep]
    d = np.min(np.linalg.norm(V[rest][:, None, :2] - V[keep][None, :, :2], axis=2), axis=1)
    while len(keep) < n:  # farthest-point fill over the frontal plane: even triangles, not MediaPipe's dense eyes
        j = int(d.argmax()); keep.append(rest[j])
        d = np.minimum(d, np.linalg.norm(V[rest][:, :2] - V[rest[j], :2], axis=1)); d[j] = -1
    P = V[keep][:, :2]
    tri = Delaunay(P).simplices
    c = P[tri].mean(1)
    ok = inside(c, V[oval][:, :2])
    for h in HOLES: ok &= ~inside(c, V[h][:, :2])
    tri = tri[ok]
    # Outward winding (+z faces the camera in canonical space), so backface culling is a sign test.
    a, b, cc = (V[keep][tri[:, k]] for k in range(3))
    flip = np.cross(b - a, cc - a)[:, 2] < 0
    tri[flip] = tri[flip][:, ::-1]
    return keep, tri


def remap():
    import mediapipe as mp
    from mediapipe.tasks.python import vision, BaseOptions
    V = json.load(open("vision.json"))
    det = vision.FaceLandmarker.create_from_options(vision.FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=str(fetch("face_landmarker.task"))), num_faces=10))
    votes = collections.defaultdict(list)
    for name, faces in V.items():
        img = mp.Image.create_from_file(name)
        M = [np.array([[p.x * img.width, p.y * img.height] for p in f])[:468] for f in det.detect(img).face_landmarks]
        for f in faces:
            iod = np.linalg.norm(np.subtract(f["leftPupil"][0], f["rightPupil"][0])); c = np.mean(f["faceContour"], 0)
            m = min(M, key=lambda m: np.linalg.norm(m.mean(0) - c), default=None)
            if m is None or np.linalg.norm(m.mean(0) - c) > iod: continue
            for r, pts in f.items():
                for i, p in enumerate(pts):
                    dd = np.linalg.norm(m - p, axis=1); votes[(r, i)].append((int(dd.argmin()), dd.min() / iod))
    out, errs = {}, []
    for (r, i), v in sorted(votes.items()):
        j = collections.Counter(x for x, _ in v).most_common(1)[0][0]
        errs.append(np.median([e for x, e in v if x == j])); out.setdefault(r, []).append(j)
    print(json.dumps(out)); print(f"median err/iod {np.median(errs):.3f}, max {max(errs):.3f}", file=sys.stderr)


def swift(mesh):
    v = ", ".join(f"{c:.3f}" for xyz in mesh["vertices"] for c in xyz)
    t = ", ".join(str(i) for tri in mesh["triangles"] for i in tri)
    m = "\n".join(f'        "{k}": {v},' for k, v in mesh["vision"].items())
    return f"""// Generated by ml/scan_mesh.py. Do not edit. Mesh: MediaPipe canonical face model (Apache-2.0, THIRD_PARTY_NOTICES), decimated.
/// The face-scan mask: canonical-space vertices (cm, +y up, +z toward the camera; flat x, y, z), outward-wound triangles
/// (flat a, b, c), and for each Vision landmark region the vertex index of each of its points.
enum ScanMesh {{
    static let xyz: [Float] = [{v}]
    static let tri: [Int] = [{t}]
    static let vision: [String: [Int]] = [
{m}
    ]
}}
"""


if __name__ == "__main__":
    if "--remap" in sys.argv: remap(); sys.exit()
    n = next((int(a) for a in sys.argv[1:] if a.isdigit()), 160)
    V, F = load_obj(fetch("canonical_face_model.obj"))
    keep, tri = decimate(V, F, n)
    idx = {old: new for new, old in enumerate(keep)}
    mesh = {"vertices": V[keep].round(3).tolist(), "triangles": tri.tolist(),
            "vision": {k: [idx[i] for i in v] for k, v in VISION_TO_MP.items()}, "mp": VISION_TO_MP}
    out = ROOT / "design/scan/mesh.json"; out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(mesh, separators=(",", ":")))
    print(f"{len(keep)} vertices, {len(tri)} triangles → {out.relative_to(ROOT)}", file=sys.stderr)
    if "--swift" in sys.argv:
        (ROOT / "Sources/Byaku/ScanMesh.swift").write_text(swift(mesh)); print("→ Sources/Byaku/ScanMesh.swift", file=sys.stderr)
