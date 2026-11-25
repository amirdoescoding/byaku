"""Score `byaku match` output (Swift align -> SFace) with the same bar v2 as sface_live.py. Reads stdin.

Usage: .build/debug/byaku match ml/models/sface.mlpackage owner:lightA-yaw0 ... stranger:photo1 ... | (cd ml && uv run score_segments.py)

Swift counting rule, pre-registered 2026-11-25 before any Swift data:
  counted frame = phase active (10 s after Enter), exactly one Vision face, rect confidence >= 0.9, and
  landmarks + alignment + embedding all succeeded on it; camera at 5 fps
  enrollment = 5 s, same rule, mean of unit embeddings (owner alone)
  segments with < 20 frames are ignored; bar v2 unchanged (sface_live.summary): p5 of EVERY owner segment > p95(all strangers),
  >= 2 distinct strangers; threshold = midpoint of p5(owner) and p95(stranger). This run gates PR3.
"""
import sys

from sface_live import summary

segs = {}
for line in sys.stdin:
    p = line.split()
    if len(p) == 4 and p[0] == "seg":
        segs.setdefault(int(p[1]), (p[2], []))[1].append(float(p[3]))
summary([segs[k] for k in sorted(segs)])
