"""SFace ONNX -> CoreML .mlpackage with a three-way parity assert (D12).

cv2.FaceRecognizerSF.feature vs onnxruntime pins the input contract (channel order, raw 0-255);
onnxruntime vs CoreML checks the ImageType + FP16 conversion. Public sample faces only, never camera captures.
"""
import json, sys
import coremltools as ct
import cv2
import numpy as np
import onnxruntime as ort
import torch
from onnx2torch import convert
from PIL import Image

from fetch import fetch

BAR = 0.99


def cos(a, b):
    a, b = np.ravel(a), np.ravel(b)
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b)))


def parity_faces(models, n=8):
    """YuNet + alignCrop on the public sample -> n aligned 112x112 BGR crops (largest faces first)."""
    img = cv2.imread(str(models / "sample.jpg"))
    det = cv2.FaceDetectorYN.create(str(models / "yunet.onnx"), "", (img.shape[1], img.shape[0]), 0.9)
    _, faces = det.detect(img)
    assert faces is not None and len(faces) >= 5, f"need >=5 public faces, got {0 if faces is None else len(faces)}"
    rec = cv2.FaceRecognizerSF.create(str(models / "sface.onnx"), "")
    faces = sorted(faces, key=lambda f: -f[2] * f[3])[:n]
    return rec, [rec.alignCrop(img, f) for f in faces]


def main():
    models = fetch()
    rec, crops = parity_faces(models)
    out = models / "parity"
    out.mkdir(exist_ok=True)

    sess = ort.InferenceSession(str(models / "sface.onnx"))
    def ort_feat(bgr, rgb):
        x = (bgr[:, :, ::-1] if rgb else bgr).transpose(2, 0, 1)[None].astype(np.float32)
        return sess.run(None, {"data": x})[0]

    # 1) cv2 <-> ORT: which channel order does OpenCV feed the model?
    rgb = None
    for order in (True, False):
        if all(cos(rec.feature(c), ort_feat(c, order)) > 0.999 for c in crops):
            rgb = order
            break
    if rgb is None:
        sys.exit("parity FAIL: cv2 and onnxruntime disagree in both channel orders")
    print(f"cv2 <-> onnxruntime: match with {'RGB' if rgb else 'BGR'} raw 0-255 input")

    # 2) ONNX -> torch -> trace -> CoreML
    try:
        net = convert(str(models / "sface.onnx")).eval()
    except Exception as e:
        sys.exit(f"conversion blocked: onnx2torch failed: {e}")
    traced = torch.jit.trace(net, torch.rand(1, 3, 112, 112) * 255)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS14,
        inputs=[ct.ImageType(name="image", shape=(1, 3, 112, 112),
                             color_layout=ct.colorlayout.RGB if rgb else ct.colorlayout.BGR, scale=1.0, bias=[0, 0, 0])],
        outputs=[ct.TensorType(name="embedding")],
    )
    mlmodel.short_description = "SFace 2021dec (opencv_zoo), 112x112 aligned face -> 128-d embedding"
    mlmodel.save(str(models / "sface.mlpackage"))

    # 3) ORT <-> CoreML on the same crops; write exact 112x112 PNGs + reference embeddings for Swift.
    ref, worst = {}, 1.0
    for i, c in enumerate(crops):
        assert c.shape == (112, 112, 3)
        name = f"face{i}.png"
        cv2.imwrite(str(out / name), c)
        o = ort_feat(c, rgb)
        m = mlmodel.predict({"image": Image.fromarray(c[:, :, ::-1])})["embedding"]
        c_cv, c_ml = cos(rec.feature(c), o), cos(o, m)
        worst = min(worst, c_cv, c_ml)
        print(f"{name}: cv2~ort={c_cv:.5f} ort~coreml={c_ml:.5f}")
        ref[name] = [float(v) for v in np.ravel(o)]
    (out / "parity.json").write_text(json.dumps(ref))
    print(f"worst cosine {worst:.5f} (bar {BAR}) -> {'PASS' if worst > BAR else 'FAIL'}")
    sys.exit(0 if worst > BAR else 1)


if __name__ == "__main__":
    main()
