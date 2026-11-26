"""Download SFace + YuNet + a public multi-face sample into ml/models/ (git-ignored). Dev tooling only."""
import hashlib, pathlib, urllib.request
import onnx

MODELS = pathlib.Path(__file__).parent / "models"
ZOO = "https://github.com/opencv/opencv_zoo/raw/main/models/"
FILES = {
    "sface.onnx": ZOO + "face_recognition_sface/face_recognition_sface_2021dec.onnx",
    "yunet.onnx": ZOO + "face_detection_yunet/face_detection_yunet_2023mar.onnx",
    # Public group selfie from opencv_zoo examples (YuNet boxes drawn on it; fine for parity).
    "sample.jpg": ZOO + "face_detection_yunet/example_outputs/largest_selfie.jpg",
}
# Pinned bytes: ZOO is the mutable main branch, and a release ships whatever CI downloads here.
SHA256 = {
    "sface.onnx": "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79",
    "yunet.onnx": "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
    "sample.jpg": "ab8413ad9bb4f53068f4fb63c6747e5989991dd02241c923d5595b614ecf2bf6",
}


def fetch() -> pathlib.Path:
    MODELS.mkdir(exist_ok=True)
    for name, url in FILES.items():
        p = MODELS / name
        if not p.exists():
            print(f"downloading {name}")
            urllib.request.urlretrieve(url, p)
        # LFS guard: a pointer file is ~130 bytes and not a valid ONNX.
        assert p.stat().st_size > 50_000, f"{name} is {p.stat().st_size} bytes (LFS pointer?)"
        digest = hashlib.sha256(p.read_bytes()).hexdigest()
        assert digest == SHA256[name], f"{name} sha256 {digest} != pinned {SHA256[name]}; delete it and re-fetch, or re-pin after review"
        if p.suffix == ".onnx":
            onnx.checker.check_model(onnx.load(p))
    return MODELS


if __name__ == "__main__":
    print(fetch())
