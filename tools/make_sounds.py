"""Makes the sound effects for Count Vlad's visit (the loan cutscene) and
the gang war.

    python3 tools/make_sounds.py

Writes WAV files into assets/sounds/. They're all made from scratch here
(sine waves and filtered noise), so swap in your own recordings whenever
you like: keep the same file names.

  vlad_sting.wav   a pipe organ chord, when the lights go out and he appears
  vlad_bats.wav    a swarm of bats flapping
  vlad_rip.wav     the head coming off (a wet tear and a pop)
  vlad_thud.wav    the body hitting the floor
  vlad_laugh.wav   a low "ha... ha... ha" as he walks off

  war_sting.wav    the gang war starts: a hit on a low drum and a brass stab
  war_punch.wav    a fist (or a skeleton's) landing
  war_nunchucks.wav  nunchucks whooshing round and cracking a skull
  war_shot.wav     the Glock
  war_reload.wav   a fresh magazine clicking in
  war_crack.wav    a skeleton falling apart into a heap of bones
  war_smash.wav    a shelf (or the register) getting smashed

  zomtok_beat_0.wav  ZomTok's dance tracks: two bars that loop. 0 is a
  zomtok_beat_1.wav  spooky shuffle (100 BPM), 1 a four-on-the-floor "brain
  zomtok_beat_2.wav  drop" (120 BPM), 2 a bone xylophone banger (128 BPM)
  zomtok_like.wav    a little pop when you like a video
  snake_eat.wav      the snake chomping something
  snake_over.wav     the snake crashing: wah wah wahhh
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


def war_sting():
    tt = t(2.6)
    drum = np.sin(2 * np.pi * (55 - 20 * tt) * tt) * np.exp(-tt * 3.5)
    hit = lowpass(rng.uniform(-1, 1, len(tt)), 900) * np.exp(-tt * 10)
    brass = np.zeros_like(tt)
    for f in [73.42, 87.31, 110.0, 146.83]:  # a dark D minor stab, with a growl
        saw = 2 * ((f * tt) % 1.0) - 1
        brass += saw
    brass = lowpass(brass, 1100) * envelope(len(tt), 0.03, 1.6) * (1 + 0.08 * np.sin(2 * np.pi * 6 * tt))
    return drum * 1.4 + hit * 0.8 + brass * 0.35


def punch():
    tt = t(0.22)
    body = np.sin(2 * np.pi * (110 - 60 * tt / 0.22) * tt) * np.exp(-tt * 22)
    slap = lowpass(rng.uniform(-1, 1, len(tt)), 2400) * np.exp(-tt * 60)
    return body * 1.2 + slap * 0.9


def nunchucks():
    tt = t(0.42)
    # A whoosh (a band of noise sweeping up), then the crack of wood on bone.
    noise = rng.uniform(-1, 1, len(tt))
    sweep = np.clip(tt / 0.22, 0, 1)
    whoosh = (lowpass(noise, 700) - lowpass(noise, 250)) * np.sin(np.pi * sweep) * (tt < 0.22)
    hit_t = tt - 0.2
    crack = np.where(hit_t > 0, rng.uniform(-1, 1, len(tt)) * np.exp(-hit_t * 70), 0)
    knock = np.where(hit_t > 0, sum(np.sin(2 * np.pi * f * hit_t) * np.exp(-hit_t * d) for f, d in [(620, 35), (930, 45)]), 0)
    return whoosh * 2.2 + crack * 0.8 + knock * 0.6


def shot():
    tt = t(0.5)
    blast = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 28)
    boom = np.sin(2 * np.pi * (140 - 80 * np.clip(tt * 6, 0, 1)) * tt) * np.exp(-tt * 12)
    tail = lowpass(rng.uniform(-1, 1, len(tt)), 700) * np.exp(-tt * 7) * 0.5
    return blast + boom * 0.9 + tail


def reload():
    out = []
    for f, length in [(2600, 0.03), (0, 0.12), (1800, 0.05)]:
        tt = t(length)
        if f == 0:
            out.append(np.zeros(len(tt)))
        else:
            click = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 120) + 0.5 * np.sin(2 * np.pi * f * tt) * np.exp(-tt * 90)
            out.append(click)
    return np.concatenate(out)


def bone_crack():
    tt = t(0.7)
    out = np.zeros_like(tt)
    for start in [0.0, 0.07, 0.16, 0.24, 0.35, 0.47]:  # bones clattering down
        tk = tt - start - rng.uniform(0, 0.02)
        f = rng.uniform(900, 1800)
        clack = np.where(tk > 0, np.sin(2 * np.pi * f * tk) * np.exp(-tk * 45), 0)
        out += clack * rng.uniform(0.5, 1.0)
    snap = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 80)
    return out + snap


def smash():
    tt = t(0.9)
    crash = rng.uniform(-1, 1, len(tt)) * np.exp(-tt * 6)
    glass = np.zeros_like(tt)
    for i in range(14):  # bits of glass and tins bouncing
        start = rng.uniform(0.02, 0.6)
        tk = tt - start
        glass += np.where(tk > 0, np.sin(2 * np.pi * rng.uniform(2500, 6000) * tk) * np.exp(-tk * 35), 0) * rng.uniform(0.2, 0.6)
    thump = np.sin(2 * np.pi * 80 * tt) * np.exp(-tt * 10)
    return lowpass(crash, 3500) * 0.9 + glass * 0.6 + thump


# ---------------------------------------------------------------- the PC's apps (0.17)

BEAT_BPM = [100, 120, 128]  # ZomTok's tracks (the game reads these too: ZomTok.BPM)


def _place(buf, x, at):
    """Adds `x` into the loop `buf` starting at sample `at`, wrapping round
    the end (so the loop is seamless)."""
    n = len(buf)
    for i in range(0, len(x), n):
        part = x[i:i + n]
        start = (at + i) % n
        end = start + len(part)
        if end <= n:
            buf[start:end] += part
        else:
            k = n - start
            buf[start:] += part[:k]
            buf[:end - n] += part[k:]


def _kick(r):
    tt = t(0.32)
    return np.sin(2 * np.pi * (48 + 80 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 9) * 1.3


def _snare(r):
    tt = t(0.2)
    noise = r.uniform(-1, 1, len(tt))
    band = lowpass(noise, 5000) - lowpass(noise, 700)
    return (band * 1.2 + 0.5 * np.sin(2 * np.pi * 190 * tt)) * np.exp(-tt * 18)


def _hat(r, open_=False):
    tt = t(0.2 if open_ else 0.05)
    noise = r.uniform(-1, 1, len(tt))
    return (noise - lowpass(noise, 6000)) * np.exp(-tt * (14 if open_ else 70)) * 0.7


def _bass(freq, seconds, square=True):
    tt = t(seconds)
    wave_ = np.sign(np.sin(2 * np.pi * freq * tt)) if square else 2 * ((freq * tt) % 1.0) - 1
    return lowpass(wave_, 420) * envelope(len(tt), 0.005, seconds * 0.5) * 0.9


def _bone(freq, seconds=0.35):
    """A xylophone made of bones: a knock and a bright, quick ring."""
    tt = t(seconds)
    ring = np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(2 * np.pi * freq * 3.9 * tt) * np.exp(-tt * 30)
    return ring * np.exp(-tt * 11)


def _theremin(freqs, seconds):
    """A wobbly, gliding ghost of a lead line through `freqs`."""
    tt = t(seconds)
    steps = np.repeat(freqs, int(np.ceil(len(tt) / len(freqs))))[:len(tt)]
    glide = lowpass(steps.astype(float), 12)
    vib = 1 + 0.012 * np.sin(2 * np.pi * 6 * tt)
    phase = np.cumsum(glide * vib) / RATE
    return np.sin(2 * np.pi * phase) * envelope(len(tt), 0.08, 0.3) * 0.5


def zomtok_beat(which):
    r = np.random.default_rng(300 + which)
    bpm = BEAT_BPM[which]
    beat = int(RATE * 60 / bpm)
    buf = np.zeros(beat * 8)  # two bars
    eighth = beat // 2
    if which == 0:  # a spooky shuffle in E minor
        for b in range(8):
            if b % 2 == 0:
                _place(buf, _kick(r), b * beat)
            else:
                _place(buf, _snare(r) * 0.8, b * beat)
            _place(buf, _hat(r) * 0.6, b * beat + int(eighth * 1.33))  # (swung)
        _place(buf, _kick(r) * 0.7, 5 * beat + int(eighth * 1.33))
        for b, f in enumerate([82.41, 98.0, 110.0, 123.47, 82.41, 98.0, 110.0, 92.5]):
            _place(buf, _bass(f, 60 / bpm * 0.9, square=False), b * beat)
        for b in (0, 4):
            tt = t(60 / bpm * 1.6)
            chord = sum(organ_note(f, tt) for f in [164.81, 196.0, 246.94]) * envelope(len(tt), 0.02, 0.8) * 0.12
            _place(buf, chord, b * beat)
    elif which == 1:  # four on the floor, a square bass and a ghost on lead
        for b in range(8):
            _place(buf, _kick(r), b * beat)
            if b % 2:
                _place(buf, _snare(r), b * beat)
            _place(buf, _hat(r, open_=True) * 0.5, b * beat + eighth)
            _place(buf, _hat(r) * 0.35, b * beat)
        for i, f in enumerate([55.0, 55.0, 110.0, 55.0, 65.41, 65.41, 130.81, 49.0] * 2):
            _place(buf, _bass(f, 60 / bpm * 0.45), i * eighth)
        _place(buf, _theremin([440.0, 523.25, 493.88, 392.0], 60 / bpm * 8), 0)
    else:  # bones
        for b in range(8):
            _place(buf, _kick(r), b * beat)
            if b % 2:
                _place(buf, _snare(r) * 0.9, b * beat)
                _place(buf, _snare(r) * 0.35, b * beat + eighth + eighth // 2)
            _place(buf, _hat(r) * 0.4, b * beat + eighth)
        tune = [392.0, 440.0, 523.25, 440.0, 587.33, 523.25, 440.0, 392.0, 329.63, 392.0, 440.0, 523.25, 659.25, 587.33, 523.25, 440.0]
        for i, f in enumerate(tune):
            _place(buf, _bone(f) * 0.55, i * eighth)
        for b, f in enumerate([98.0, 98.0, 110.0, 130.81, 98.0, 98.0, 146.83, 130.81]):
            tt = t(60 / bpm * 0.95)
            _place(buf, np.sin(2 * np.pi * f / 2 * tt) * envelope(len(tt), 0.01, 0.2) * 0.9, b * beat)
    return buf


def zomtok_like():
    tt = t(0.12)
    pop = np.sin(2 * np.pi * (700 + 900 * tt / 0.12) * tt) * np.exp(-tt * 40)
    return pop


def snake_eat():
    r = np.random.default_rng(310)
    tt = t(0.13)
    blip = np.sign(np.sin(2 * np.pi * (520 + 1400 * tt) * tt)) * np.exp(-tt * 25) * 0.5
    crunch = lowpass(r.uniform(-1, 1, len(tt)), 2200) * np.exp(-tt * 45)
    return blip + crunch


def snake_over():
    out = []
    for f, sec in [(392.0, 0.22), (369.99, 0.22), (349.23, 0.22), (329.63, 0.7)]:  # wah wah wah wahhh
        tt = t(sec)
        wobble = 1 + (0.02 * np.sin(2 * np.pi * 7 * tt) if sec > 0.5 else 0)
        saw = 2 * ((f / 2 * wobble * tt) % 1.0) - 1
        out.append(lowpass(saw, 900) * envelope(len(tt), 0.02, sec * 0.4))
    return np.concatenate(out)


def main():
    save("vlad_sting", sting(), 0.85)
    save("vlad_bats", bats(), 0.7)
    save("vlad_rip", rip(), 0.9)
    save("vlad_thud", thud(), 0.9)
    save("vlad_laugh", laugh(), 0.8)
    save("war_sting", war_sting(), 0.85)
    save("war_punch", punch(), 0.8)
    save("war_nunchucks", nunchucks(), 0.85)
    save("war_shot", shot(), 0.9)
    save("war_reload", reload(), 0.6)
    save("war_crack", bone_crack(), 0.8)
    save("war_smash", smash(), 0.85)
    pc_apps_sounds()


def pc_apps_sounds():
    for i in range(len(BEAT_BPM)):
        save(f"zomtok_beat_{i}", zomtok_beat(i), 0.55)
    save("zomtok_like", zomtok_like(), 0.5)
    save("snake_eat", snake_eat(), 0.55)
    save("snake_over", snake_over(), 0.6)


if __name__ == "__main__":
    main()
