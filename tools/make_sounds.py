"""Makes the sound effects for Count Vlad's visit (the loan cutscene).

    python3 tools/make_sounds.py

Writes WAV files into assets/sounds/. They're all made from scratch here
(sine waves and filtered noise), so swap in your own recordings whenever
you like: keep the same file names.

  vlad_sting.wav   a pipe organ chord, when the lights go out and he appears
  vlad_bats.wav    a swarm of bats flapping
  vlad_rip.wav     the head coming off (a wet tear and a pop)
  vlad_thud.wav    the body hitting the floor
  vlad_laugh.wav   a low "ha... ha... ha" as he walks off
"""
import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"
rng = np.random.default_rng(7)


def t(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n, attack, release):
    """0 -> 1 over `attack` seconds, then down to 0 over the last `release` seconds."""
    env = np.ones(n)
    a = max(1, int(RATE * attack))
    r = max(1, int(RATE * release))
    env[:a] = np.linspace(0, 1, a)
    env[-r:] *= np.linspace(1, 0, r) ** 2
    return env


def lowpass(x, cutoff):
    """A simple one-pole low-pass filter."""
    a = np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def save(name, x, volume=0.8):
    x = x / max(1e-9, np.max(np.abs(x))) * volume
    data = (x * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def organ_note(freq, tt):
    # A pipe organ: the note plus octaves and a fifth, with a slow wobble.
    wob = 1 + 0.003 * np.sin(2 * np.pi * 5.5 * tt)
    out = np.zeros_like(tt)
    for mult, amp in [(0.5, 0.5), (1, 1.0), (2, 0.6), (3, 0.3), (4, 0.25), (6, 0.1)]:
        out += amp * np.sin(2 * np.pi * freq * mult * wob * tt)
    return out


def sting():
    # D minor, low and loud: D2 A2 D3 F3 A3, held, then fading out.
    tt = t(3.2)
    x = sum(organ_note(f, tt) for f in [73.42, 110.0, 146.83, 174.61, 220.0])
    x *= envelope(len(tt), 0.04, 2.2)
    return x


def bats():
    tt = t(1.6)
    noise = rng.uniform(-1, 1, len(tt))
    flaps = np.zeros_like(tt)
    for rate in [11.0, 13.5, 16.0, 9.5]:  # several bats, flapping out of step
        phase = rng.uniform(0, 1)
        flaps += np.clip(np.sin(2 * np.pi * (rate * tt + phase)), 0, 1) ** 3
    x = lowpass(noise, 1800) * flaps
    squeaks = np.zeros_like(tt)
    for start in [0.15, 0.6, 1.05]:
        s = (tt > start) & (tt < start + 0.06)
        squeaks[s] = 0.25 * np.sin(2 * np.pi * (5200 + 2000 * (tt[s] - start) / 0.06) * tt[s])
    return (x + squeaks) * envelope(len(tt), 0.05, 0.5)


def rip():
    tt = t(0.9)
    noise = rng.uniform(-1, 1, len(tt))
    # A ragged tear: noise that crackles on and off, getting brighter...
    crackle = (rng.uniform(0, 1, len(tt)) > 0.55).astype(float)
    crackle = lowpass(crackle, 60)
    tear = lowpass(noise, 2500) * crackle * np.clip(tt / 0.5, 0, 1)
    tear[tt > 0.55] *= np.exp(-(tt[tt > 0.55] - 0.55) * 18)
    # ...then a wet pop.
    pop_t = tt - 0.55
    pop = np.where(pop_t > 0, np.sin(2 * np.pi * (160 - 90 * np.clip(pop_t * 4, 0, 1)) * pop_t) * np.exp(-pop_t * 14), 0)
    squelch = np.where(pop_t > 0, lowpass(rng.uniform(-1, 1, len(tt)), 500) * np.exp(-pop_t * 6), 0)
    return tear * 0.8 + pop * 1.2 + squelch * 0.9


def thud():
    tt = t(0.6)
    body = np.sin(2 * np.pi * (70 - 30 * tt) * tt) * np.exp(-tt * 9)
    dust = lowpass(rng.uniform(-1, 1, len(tt)), 400) * np.exp(-tt * 14)
    return body + 0.6 * dust


def laugh():
    out = []
    for i, pitch in enumerate([118, 112, 104, 96]):
        tt = t(0.32)
        f = pitch * (1 + 0.15 * np.exp(-tt * 12))
        voice = sum(a * np.sin(2 * np.pi * f * k * tt) for k, a in [(1, 1.0), (2, 0.5), (3, 0.35), (4, 0.2), (5, 0.15)])
        breath = lowpass(rng.uniform(-1, 1, len(tt)), 1200) * 0.35
        syllable = (voice + breath) * envelope(len(tt), 0.02, 0.22)
        out.append(syllable)
        out.append(np.zeros(int(RATE * (0.08 + 0.03 * i))))
    x = np.concatenate(out)
    return lowpass(x, 1600)


def main():
    save("vlad_sting", sting(), 0.85)
    save("vlad_bats", bats(), 0.7)
    save("vlad_rip", rip(), 0.9)
    save("vlad_thud", thud(), 0.9)
    save("vlad_laugh", laugh(), 0.8)


if __name__ == "__main__":
    main()
