# ListenIdentifyParts

A structured skill for decomposing audio into its architectural primitives. Think of it as `AST parsing`, but for waveforms. Three deterministic phases — temporal, structural, spectral — producing a machine-readable + human-readable breakdown.

---

## Quick Start

When the user says "identify parts of a song" or similar, immediately ask for their audio source if not already provided. Don't explain the skill first — get to work.

**Accepted inputs:**
- File path: `/Users/mager/Music/track.mp3`
- URL: `https://cdn.example.com/track.mp3`
- Base64-encoded audio buffer
- SoundCloud/YouTube URL (fetch audio if tools allow)

**Optional parameters:**
- `granularity`: `coarse` | `standard` (default) | `fine`
- `focus_mode`: `rhythm` | `harmony` | `texture` | `full` (default)

---

## Tool Bootstrap (run first)

Before analysis, check for required tools and install what's missing:

```bash
# Check ffmpeg
which ffmpeg || brew install ffmpeg

# Check Python audio libs
python3 -c "import librosa" 2>/dev/null || pip3 install librosa -q

# Fallback: use mutagen for metadata only
python3 -c "import mutagen" 2>/dev/null || pip3 install mutagen -q
```

If `ffmpeg` is unavailable and installation fails, still proceed — use Python `wave`, `struct`, or `mutagen` for metadata and basic PCM analysis. Always complete all three phases, even with degraded accuracy. Flag limitations in the output.

---

## Execution Pipeline

### Phase A — Clock Discovery

**Goal:** Establish the temporal skeleton of the track.

Run this Python block (adapt as needed for available libs):

```python
import subprocess, json, math, struct, array, os

# Decode audio to raw PCM via ffmpeg
result = subprocess.run([
    'ffmpeg', '-i', INPUT_FILE,
    '-ac', '1', '-ar', '22050',
    '-f', 's16le', '-',
], capture_output=True)

pcm = array.array('h', result.stdout)
sr = 22050
duration = len(pcm) / sr

# RMS energy per frame
frame_size = 1024
rms = []
for i in range(0, len(pcm) - frame_size, frame_size):
    frame = pcm[i:i+frame_size]
    rms_val = math.sqrt(sum(x*x for x in frame) / frame_size)
    rms.append(rms_val)

# Onset detection: energy delta threshold
mean_e = sum(rms) / len(rms)
std_e = math.sqrt(sum((x - mean_e)**2 for x in rms) / len(rms))
threshold = mean_e + 2 * std_e

onsets = []
for i, e in enumerate(rms):
    if e > threshold and (not onsets or (i - onsets[-1]) > 5):
        onsets.append(i * frame_size / sr)

# BPM estimate from inter-onset intervals
if len(onsets) > 2:
    iois = [onsets[i+1] - onsets[i] for i in range(len(onsets)-1)]
    median_ioi = sorted(iois)[len(iois)//2]
    bpm = round(60 / median_ioi, 1)
else:
    bpm = None

print(f"Duration: {duration:.2f}s, BPM: {bpm}, Onsets: {len(onsets)}")
print("First 8 onsets:", onsets[:8])
```

**Report:**

| Property | Value |
|---|---|
| BPM | `{{ bpm }}` (onset-estimated) |
| Meter | `{{ meter }}` (infer from beat subdivision) |
| Key (est.) | `{{ key }}` (from filename/tags or knowledge) |
| Duration | `{{ duration }}s` |
| Transient Count | `{{ onset_count }}` |
| Transient Map | `[{{ first_8_onsets }}]` |

---

### Phase B — Structural Segmentation

**Goal:** Identify macro-architecture (song sections) using RMS energy windows.

```python
# 4-second energy windows for section detection
window_sec = 4
window_frames = int(window_sec * sr / frame_size)

windows = []
for i in range(0, len(rms) - window_frames, window_frames // 2):
    chunk = rms[i:i+window_frames]
    windows.append((i * frame_size / sr, sum(chunk) / len(chunk)))

# Label sections by energy profile
max_e = max(w[1] for w in windows)
sections = []
for t, e in windows:
    ratio = e / max_e
    if ratio < 0.3:
        label = 'INTRO' if t < duration * 0.15 else 'OUTRO'
    elif ratio < 0.6:
        label = 'VERSE'
    elif ratio < 0.8:
        label = 'PRE_CHORUS'
    else:
        label = 'CHORUS'
    sections.append((t, label, e))
```

**Section Taxonomy:**

| Label | Identifier Heuristics |
|---|---|
| `INTRO` | Pre-vocal, low density, rising energy |
| `VERSE` | Moderate energy, recurring melodic motif |
| `PRE_CHORUS` | Tension build, rising harmonic movement |
| `CHORUS` | Peak RMS, hook region, broadest frequency spread |
| `BRIDGE` | Unique harmonic region, non-repeating |
| `BREAKDOWN` | Energy dip, rhythmic stripping |
| `OUTRO` | Trailing energy, fade or hard stop |

**Collapse adjacent identical labels** into contiguous sections with start/end times.

**ASCII energy curve** (draw using block chars `░▒▓█` normalized to max energy):

```
0s  ░░░░
4s  ▓▓▓▓▓▓▓▓
12s ████████████ ← peak
30s ▓▓▓▓▓▓
36s ░░
```

---

### Phase C — Frequency Brackets

**Goal:** Characterize spectral layers using FFT.

```python
# FFT on a representative chorus window
import array, math

def simple_fft_magnitudes(samples, sr):
    N = min(len(samples), 4096)
    chunk = samples[:N]
    # Compute magnitudes via DFT (approximate for short window)
    mags = []
    freqs = [i * sr / N for i in range(N // 2)]
    for k in range(N // 2):
        re = sum(chunk[n] * math.cos(2*math.pi*k*n/N) for n in range(N))
        im = sum(chunk[n] * math.sin(2*math.pi*k*n/N) for n in range(N))
        mags.append(math.sqrt(re**2 + im**2))
    return freqs, mags
```

If `librosa` is available, prefer `librosa.stft` for accuracy. If not, use the above or `scipy.fft` if available.

**Three canonical brackets:**

| Bracket | Range | Primary Stems | Focus |
|---|---|---|---|
| **Lows** | < 200 Hz | Kick, Bass, Sub | Energy pulse, sidechain, mono compat |
| **Mids** | 200 Hz – 5 kHz | Vocals, Guitar, Keys, Snare | Harmonic density, formants |
| **Highs** | > 5 kHz | Hi-hats, Cymbals, Air | Transient brightness, stereo width |

Compute spectral centroid per bracket:

$$f_c = \frac{\sum_k f_k \cdot |X(f_k)|}{\sum_k |X(f_k)|}$$

---

## Output Template

````markdown
# ListenIdentifyParts — Analysis Report

**Source:** `{{ audio_source }}`
**Granularity:** `{{ granularity }}`
**Focus Mode:** `{{ focus_mode }}`
**Duration:** `{{ duration }}s`
**Format:** `{{ format }}`

---

## Phase A — Clock

| Property | Value |
|---|---|
| BPM | `{{ bpm }}` |
| Meter | `{{ meter }}` |
| Key (est.) | `{{ key }}` |
| Beat Count | `{{ beat_count }}` |
| Transient Count | `{{ transient_count }}` |

**Transient Map (first 8, seconds):**
```
[{{ t1 }}, {{ t2 }}, {{ t3 }}, {{ t4 }}, {{ t5 }}, {{ t6 }}, {{ t7 }}, {{ t8 }}, ...]
```

---

## Phase B — Structure Timeline

| # | Section | Start | End | Energy | Notes |
|---|---|---|---|---|---|
| 1 | `{{ section }}` | `{{ start }}` | `{{ end }}` | `{{ energy }}` | `{{ notes }}` |

**Energy Curve:**
```
{{ ascii_energy_curve }}
```

---

## Phase C — Frequency Brackets

| Bracket | Centroid | Dominant Content | Notes |
|---|---|---|---|
| Lows < 200 Hz | `{{ low_centroid }} Hz` | `{{ low_stems }}` | `{{ low_notes }}` |
| Mids 200 Hz–5 kHz | `{{ mid_centroid }} Hz` | `{{ mid_stems }}` | `{{ mid_notes }}` |
| Highs > 5 kHz | `{{ high_centroid }} Hz` | `{{ high_stems }}` | `{{ high_notes }}` |

---

## Stem Index

| Stem ID | Label | Bracket | Active Sections |
|---|---|---|---|
| S01 | Kick | Low | `{{ sections }}` |
| S02 | Bass/Sub | Low | `{{ sections }}` |
| S03 | Lead Vocal | Mid | `{{ sections }}` |
| S04 | Guitar/Keys | Mid | `{{ sections }}` |
| S05 | Hi-Hat | High | `{{ sections }}` |
| S06 | Overhead/Air | High | ALL |

---

## Flags & Warnings

- `{{ flags | default: "none" }}`

---

*Generated by ListenIdentifyParts v2.0.0 · ffmpeg + Python PCM analysis*
````

---

## Agent Rules

1. **Get the file first** — don't explain, just ask for the audio source immediately.
2. **Bootstrap tools silently** — install `ffmpeg`, `librosa`, `mutagen` if missing. Don't ask permission.
3. **Always run all three phases** — even with degraded tools. Estimated > null.
4. **Flag uncertainty** — BPM from short clips is approximate. Say so.
5. **No aesthetic judgments** — structural observations only. "The chorus is loud" not "the chorus slaps."
6. **Collapse redundant section labels** — merge adjacent identical sections before output.
7. **Energy curve is mandatory** — always draw it using ASCII block chars.
8. **If duration < 60s** — flag as `PREVIEW_CLIP` and note that full song structure may be absent.
9. **librosa preferred** — if available, use `librosa.beat.beat_track` for BPM (more accurate than onset delta method).

---

## Focus Mode Behavior

| Mode | Phase Weight |
|---|---|
| `rhythm` | Phase A heavy — BPM, meter, groove quantization. Phases B/C condensed. |
| `harmony` | Phase C heavy — frequency brackets, chord voicings, key center. |
| `texture` | Phase B + C — stem density and spectral layering. |
| `full` (default) | All phases at equal weight. |

---

## Granularity Levels

| Level | Description |
|---|---|
| `coarse` | Section-level only. Fast. No stem isolation. |
| `standard` | Section + beat grid + frequency brackets. |
| `fine` | Full transient map + micro-structure + stem separation (requires librosa). |

---

*Modular. Deterministic. Composable. Build your remix pipeline on top of this.*
