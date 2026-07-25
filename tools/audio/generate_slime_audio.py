from __future__ import annotations

import hashlib
import math
import os
import random
import struct
import tempfile
import wave
from pathlib import Path
from typing import Sequence


SAMPLE_RATE = 48_000
MAX_PCM_PEAK = 29_195  # floor(32767 * 10 ** (-1 / 20))
DEFAULT_SEED = 73_421

ASSET_DURATIONS = {
    "slime_charge_loop.wav": 1.00,
    "slime_charge_full.wav": 0.18,
    "slime_fizzle.wav": 0.28,
    "slime_launch_01.wav": 0.24,
    "slime_launch_02.wav": 0.26,
    "slime_dash.wav": 0.30,
    "slime_impact_01.wav": 0.34,
    "slime_impact_02.wav": 0.38,
    "slime_recover_01.wav": 0.22,
    "slime_recover_02.wav": 0.25,
    "slime_idle.wav": 1.60,
}


def envelope(position: float, attack: float, release: float) -> float:
    """Return an attack/sustain/release envelope for a normalized position."""
    if not 0.0 <= position <= 1.0:
        return 0.0
    if attack > 0.0 and position < attack:
        return position / attack
    release_start = 1.0 - release
    if release > 0.0 and position > release_start:
        return max(0.0, (1.0 - position) / release)
    return 1.0


def sine_sample(phase: float) -> float:
    """Return a sine wave sample for a phase expressed in cycles."""
    return math.sin(math.tau * phase)


def low_pass(samples: list[float], coefficient: float) -> list[float]:
    """Apply a simple one-pole low-pass filter."""
    if not samples:
        return []
    filtered: list[float] = []
    previous = 0.0
    for sample in samples:
        previous += coefficient * (sample - previous)
        filtered.append(previous)
    return filtered


def normalize(samples: list[float], peak: float = 10 ** (-1 / 20)) -> list[float]:
    """Scale a buffer to the requested linear peak without altering its shape."""
    maximum = max((abs(sample) for sample in samples), default=0.0)
    if maximum == 0.0:
        return samples.copy()
    scale = peak / maximum
    return [sample * scale for sample in samples]


def make_loopable(samples: list[float], crossfade_seconds: float = 0.04) -> list[float]:
    """Smooth a loop boundary with equal-power blends at both edges."""
    if len(samples) < 2:
        return samples.copy()
    crossfade = min(round(crossfade_seconds * SAMPLE_RATE), len(samples) // 2)
    if crossfade < 2:
        return samples.copy()

    result = samples.copy()
    head = samples[:crossfade]
    tail = samples[-crossfade:]
    for index in range(crossfade):
        progress = index / (crossfade - 1)
        tail_angle = progress * math.pi / 4.0
        head_angle = math.pi / 4.0 + tail_angle
        result[-crossfade + index] = (
            tail[index] * math.cos(tail_angle)
            + head[crossfade - 1 - index] * math.sin(tail_angle)
        )
        result[index] = (
            tail[crossfade - 1 - index] * math.cos(head_angle)
            + head[index] * math.sin(head_angle)
        )
    return result


def write_pcm16(path: Path, samples: list[float]) -> None:
    """Atomically write mono, 48 kHz, signed little-endian PCM16 samples."""
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = b"".join(
        struct.pack("<h", max(-MAX_PCM_PEAK, min(MAX_PCM_PEAK, round(sample * 32767))))
        for sample in samples
    )
    with tempfile.NamedTemporaryFile(
        mode="wb", suffix=".tmp", prefix=f".{path.stem}-", dir=path.parent, delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
    try:
        with wave.open(str(temporary_path), "wb") as destination:
            destination.setnchannels(1)
            destination.setsampwidth(2)
            destination.setframerate(SAMPLE_RATE)
            destination.writeframes(pcm)
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def _linear_chirp(time: float, duration: float, start: float, end: float) -> float:
    return start * time + (end - start) * time * time / (2.0 * duration)


def _triple_chirp(time: float, duration: float, start: float, middle: float, end: float) -> float:
    half = duration / 2.0
    if time <= half:
        return _linear_chirp(time, half, start, middle)
    first_half_cycles = _linear_chirp(half, half, start, middle)
    return first_half_cycles + _linear_chirp(time - half, half, middle, end)


def _bubble(position: float, center: float, width: float) -> float:
    distance = (position - center) / width
    return math.exp(-(distance * distance) * 18.0)


def render_asset(name: str, duration: float, rng: random.Random) -> list[float]:
    """Synthesize one original slime sound from oscillators, noise, and envelopes."""
    frame_count = round(duration * SAMPLE_RATE)
    samples: list[float] = []
    for frame in range(frame_count):
        time = frame / SAMPLE_RATE
        position = frame / max(1, frame_count - 1)
        noise = rng.uniform(-1.0, 1.0)

        if name == "slime_charge_loop.wav":
            bubbles = max(0.0, sine_sample(5.0 * time)) ** 4
            sample = 0.60 * sine_sample(46.0 * time) + 0.34 * sine_sample(73.0 * time)
            sample += 0.22 * bubbles * sine_sample(146.0 * time)
        elif name == "slime_charge_full.wav":
            chirp = _linear_chirp(time, duration, 180.0, 310.0)
            sample = 0.54 * sine_sample(92.0 * time) + 0.56 * sine_sample(chirp)
            sample += 0.16 * noise
            sample *= envelope(position, 0.005 / duration, 0.150 / duration)
        elif name == "slime_fizzle.wav":
            chirp = _linear_chirp(time, duration, 170.0, 54.0)
            sample = 0.72 * sine_sample(chirp) + 0.31 * noise
            sample *= envelope(position, 0.003 / duration, 0.260 / duration)
        elif name.startswith("slime_launch_"):
            chirp = _linear_chirp(time, duration, 82.0, 235.0)
            sample = 0.70 * sine_sample(chirp) + 0.36 * sine_sample(41.0 * time)
            sample += 0.17 * noise
            sample *= envelope(position, 0.002 / duration, 1.0 - 0.002 / duration)
        elif name == "slime_dash.wav":
            chirp = _linear_chirp(time, duration, 64.0, 310.0)
            bubbles = _bubble(position, 0.27, 0.045) + _bubble(position, 0.62, 0.055)
            sample = 0.68 * sine_sample(chirp) + 0.32 * sine_sample(32.0 * time)
            sample += 0.24 * noise + 0.33 * bubbles * sine_sample(128.0 * time)
            sample *= envelope(position, 0.002 / duration, 1.0 - 0.002 / duration)
        elif name.startswith("slime_impact_"):
            chirp = _linear_chirp(time, duration, 105.0, 38.0)
            sample = 0.78 * sine_sample(chirp) + 0.58 * sine_sample(29.0 * time)
            sample += 0.29 * noise
            sample *= envelope(position, 0.001 / duration, 1.0 - 0.001 / duration)
        elif name.startswith("slime_recover_"):
            chirp = _triple_chirp(time, duration, 68.0, 145.0, 62.0)
            sample = 0.77 * sine_sample(chirp) + 0.16 * noise
            sample *= envelope(position, 0.004 / duration, 1.0 - 0.004 / duration)
        elif name == "slime_idle.wav":
            amplitude = 0.62 + 0.38 * sine_sample(0.9 * time)
            sample = amplitude * sine_sample(37.0 * time)
        else:
            raise ValueError(f"Unknown slime asset: {name}")

        samples.append(sample)

    coefficients = {
        "slime_charge_loop.wav": 0.055,
        "slime_charge_full.wav": 0.09,
        "slime_fizzle.wav": 0.07,
        "slime_launch_01.wav": 0.12,
        "slime_launch_02.wav": 0.12,
        "slime_dash.wav": 0.15,
        "slime_impact_01.wav": 0.18,
        "slime_impact_02.wav": 0.18,
        "slime_recover_01.wav": 0.08,
        "slime_recover_02.wav": 0.08,
        "slime_idle.wav": 0.035,
    }
    filtered = low_pass(samples, coefficients[name])
    if name == "slime_charge_loop.wav":
        filtered = make_loopable(filtered, 0.04)
    elif name == "slime_idle.wav":
        filtered = make_loopable(filtered, 0.08)
    return normalize(filtered)


def generate_assets(
    output_dirs: Sequence[Path],
    seed: int = DEFAULT_SEED,
) -> dict[str, list[float]]:
    """Render a deterministic pack and write identical copies to every directory."""
    rendered: dict[str, list[float]] = {}
    for name, duration in ASSET_DURATIONS.items():
        asset_seed = int.from_bytes(
            hashlib.sha256(f"{seed}:{name}".encode("utf-8")).digest()[:8],
            "little",
        )
        samples = render_asset(name, duration, random.Random(asset_seed))
        rendered[name] = samples
        for output_dir in output_dirs:
            write_pcm16(output_dir / name, samples)
    return rendered


if __name__ == "__main__":
    repository = Path(__file__).resolve().parents[2]
    generate_assets(
        [
            repository / "prototypes/slime_charge_movement/audio/slime",
            repository / "prueba_2/audio/slime",
        ]
    )
