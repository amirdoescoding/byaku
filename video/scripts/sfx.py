"""Synthesize the launch film's SFX into video/public/audio/sfx/ (48 kHz mono WAV, licence-clean).
Run: cd ml && uv run ../video/scripts/sfx.py"""
import wave
from pathlib import Path

import numpy as np

SR = 48_000
OUT = Path(__file__).resolve().parent.parent / "public/audio/sfx"
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def lowpass(x, cutoff):  # one-pole
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def fade(x, inn=0.002, out=0.01):
    n_in, n_out = int(SR * inn), int(SR * out)
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out)
    return x


def save(name, x, peak=0.9):
    x = fade(x / np.max(np.abs(x)) * peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1), w.setsampwidth(2), w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


def click():
    s = t(0.04)
    tick = rng.standard_normal(len(s)) * np.exp(-s / 0.0015)
    blip = np.sin(2 * np.pi * 2000 * s) * np.exp(-s / 0.008)
    return highpass(tick, 1500) + 0.5 * blip


def slam():
    s = t(0.6)
    f = 55 + 90 * np.exp(-s / 0.03)  # pitch drop into the low thump
    thump = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-s / 0.18)
    crack = lowpass(rng.standard_normal(len(s)), 2500) * np.exp(-s / 0.025)
    return np.tanh(2.5 * (thump + 0.8 * crack))


def rumble():
    s = t(2.0)
    brown = np.cumsum(rng.standard_normal(len(s)))
    brown = highpass(brown, 20)
    brown /= np.max(np.abs(brown))
    wobble = np.sin(2 * np.pi * 40 * s) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * s))
    env = np.minimum(1, s / 0.4) * np.minimum(1, (2.0 - s) / 0.6)
    return lowpass(brown + 0.7 * wobble, 300) * env


def crash():
    # wall breaking, all filtered noise (no pure tones, no clipping = no chiptune feel), then a room reverb
    s = t(1.8)
    boom = lowpass(lowpass(rng.standard_normal(len(s)), 140), 140) * np.exp(-s / 0.25) * (1 - np.exp(-s / 0.004))
    crack = lowpass(highpass(rng.standard_normal(len(s)), 150), 900) * np.exp(-s / 0.06) * (1 - np.exp(-s / 0.002))
    rubble = np.zeros_like(s)
    for at in rng.uniform(0, 1, 120) ** 2 * 1.4:  # chunks bunched after the hit, sparser as they settle
        i = int(at * SR)
        n = min(int(SR * rng.uniform(0.04, 0.15)), len(s) - i)
        k = np.arange(n) / SR
        env = (1 - np.exp(-k / 0.003)) * np.exp(-k / (n / SR / 4))  # soft attack: a thud, not a blip
        chunk = lowpass(rng.standard_normal(n), rng.uniform(120, 600)) * env  # each piece its own size/tone
        rubble[i : i + n] += chunk * rng.uniform(0.3, 1) * np.exp(-at / 0.6)
    return reverb(boom / np.abs(boom).max() + 0.6 * crack / np.abs(crack).max() + 0.9 * rubble / np.abs(rubble).max())


def reverb(x, decay=0.9, mix=0.18):  # convolve with a decaying, darkened noise tail (FFT)
    ir = lowpass(lowpass(rng.standard_normal(int(SR * decay * 2)), 1200), 1200) * np.exp(-t(decay * 2) / (decay / 3))
    n = len(x) + len(ir)
    wet = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)[: len(x)]
    return (1 - mix) * x + mix * wet / np.abs(wet).max() * np.abs(x).max()


def whoosh():
    # airy: broadband hiss through a smooth one-pole low-pass whose cutoff rises then falls, soft bell envelope
    d = 0.7
    s = t(d)
    noise = highpass(rng.standard_normal(len(s)), 150)
    cutoff = 300 + 2200 * np.sin(np.pi * s / d) ** 2  # peak ~2.5 kHz: air, not hiss
    noise = lowpass(noise, 2500)  # second pole tames the top further
    a = np.exp(-2 * np.pi * cutoff / SR)
    out = np.empty_like(noise)
    acc = 0.0
    for i, v in enumerate(noise):
        acc = (1 - a[i]) * v + a[i] * acc
        out[i] = acc
    return out * np.sin(np.pi * s / d) ** 1.5


def ting():
    s = t(0.7)
    return (np.sin(2 * np.pi * 2600 * s) + 0.4 * np.sin(2 * np.pi * 5200 * s)) * np.exp(-s / 0.18)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for fn in (click, slam, rumble, crash, whoosh, ting):
        save(fn.__name__, fn())
    print("wrote", sorted(p.name for p in OUT.glob("*.wav")))
