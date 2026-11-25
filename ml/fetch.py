"""Download SFace + YuNet + a public multi-face sample into ml/models/ (git-ignored). Dev tooling only."""
import pathlib, urllib.request
import onnx

MODELS = pathlib.Path(__file__).parent / "models"
ZOO = "https://github.com/opencv/opencv_zoo/raw/main/models/"
FILES = {
    "sface.onnx": ZOO + "face_recognition_sface/face_recognition_sface_2021dec.onnx",
    "yunet.onnx": ZOO + "face_detection_yunet/face_detection_yunet_2023mar.onnx",
    # Public group selfie from opencv_zoo examples (YuNet boxes drawn on it; fine for parity).
    "sample.jpg": ZOO + "face_detection_yunet/example_outputs/largest_selfie.jpg",
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
        if p.suffix == ".onnx":
            onnx.checker.check_model(onnx.load(p))
    return MODELS


if __name__ == "__main__":
    print(fetch())
