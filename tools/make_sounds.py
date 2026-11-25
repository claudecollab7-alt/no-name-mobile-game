"""Generate the trial's three wooden board sounds as 16-bit mono WAV files.

Synthesised from scratch so there is no licence to track.
Run: python -I trial/tools/make_sounds.py trial/assets/sounds
"""

import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100


def tone(freq: float, decay: float, length: float, amp: float) -> list[float]:
    n = int(RATE * length)
    return [amp * math.sin(2 * math.pi * freq * i / RATE) * math.exp(-i / (RATE * decay)) for i in range(n)]


def noise(length: float, decay: float, amp: float, smooth: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    n = int(RATE * length)
    out, last = [], 0.0
    for i in range(n):
        last = last * smooth + rng.uniform(-1, 1) * (1 - smooth)
        out.append(amp * last * math.exp(-i / (RATE * decay)))
    return out


def mix(*layers: list[float], offset: list[int] | None = None) -> list[float]:
    offset = offset or [0] * len(layers)
    length = max(len(l) + o for l, o in zip(layers, offset))
    out = [0.0] * length
    for layer, o in zip(layers, offset):
        for i, v in enumerate(layer):
            out[i + o] += v
    return out


def fade(samples: list[float], ms: float = 4) -> list[float]:
    n = min(len(samples), int(RATE * ms / 1000))
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


def write(path: Path, samples: list[float]) -> None:
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.8 / peak
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale * 32767)) for s in samples))


def main() -> None:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    out.mkdir(parents=True, exist_ok=True)
    # Place: a short, bright wooden tok.
    place = mix(tone(820, 0.018, 0.12, 1.0), tone(1640, 0.010, 0.12, 0.45), noise(0.02, 0.004, 0.5, 0.3, 1))
    # Move: a soft slide ending in a lighter tok.
    slide = noise(0.11, 0.06, 0.35, 0.85, 2)
    move = mix(slide, tone(700, 0.015, 0.1, 0.8), tone(1400, 0.008, 0.1, 0.3), offset=[0, int(RATE * 0.09), int(RATE * 0.09)])
    # Capture: a heavier, lower knock with a short rattle.
    capture = mix(tone(190, 0.09, 0.35, 1.0), tone(380, 0.05, 0.35, 0.5), noise(0.06, 0.02, 0.6, 0.5, 3), tone(760, 0.012, 0.2, 0.4))
    for name, data in (("place", place), ("move", move), ("capture", capture)):
        write(out / f"{name}.wav", fade(data))
        print(f"{name}.wav  {len(data) / RATE * 1000:.0f} ms")


if __name__ == "__main__":
    main()
