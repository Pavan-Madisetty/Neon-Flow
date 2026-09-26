#!/usr/bin/env python3
"""Synthesises the game's sound effects as 16-bit mono WAV files (no deps)."""
import math
import os
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")


def tone(freq, dur, vol=0.5, kind="sine", decay=6.0, slide=0.0):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq + slide * t
        phase += 2 * math.pi * f / RATE
        s = math.sin(phase)
        if kind == "soft":
            s = 0.75 * s + 0.25 * math.sin(2 * phase)
        env = math.exp(-decay * t / dur) * min(1.0, i / (RATE * 0.004))
        out.append(s * env * vol)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def offset(track, seconds):
    return [0.0] * int(RATE * seconds) + track


def save(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print("wrote", path)


def main():
    os.makedirs(OUT, exist_ok=True)
    save("tap", tone(660, 0.07, 0.5, "soft", 7))
    save("click", tone(440, 0.05, 0.45, "soft", 8))
    save("move", tone(520, 0.03, 0.25, "sine", 8))
    save("connect", mix(tone(523.25, 0.16, 0.45, "soft", 5),
                        offset(tone(783.99, 0.24, 0.45, "soft", 5), 0.09)))
    save("cut", tone(300, 0.14, 0.4, "soft", 6, slide=-700))
    save("hint", mix(tone(1046.5, 0.3, 0.35, "sine", 5),
                     offset(tone(1568.0, 0.3, 0.3, "sine", 5), 0.07),
                     offset(tone(2093.0, 0.35, 0.25, "sine", 5), 0.14)))
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
    win = []
    for i, f in enumerate(notes):
        win.append(offset(tone(f, 0.45, 0.4, "soft", 4), i * 0.11))
    win.append(offset(mix(tone(523.25, 0.9, 0.3, "soft", 3),
                          tone(659.25, 0.9, 0.3, "soft", 3),
                          tone(783.99, 0.9, 0.3, "soft", 3)), 0.55))
    save("win", mix(*win))
    save("undo", tone(600, 0.12, 0.4, "soft", 6, slide=-300))
    save("error", mix(tone(196, 0.18, 0.4, "soft", 5), offset(tone(165, 0.22, 0.4, "soft", 5), 0.1)))
    save("star", tone(1200, 0.25, 0.4, "sine", 5, slide=600))


if __name__ == "__main__":
    main()
