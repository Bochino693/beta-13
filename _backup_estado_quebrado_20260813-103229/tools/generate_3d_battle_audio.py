#!/usr/bin/env python3
"""Gera rugidos individuais, ambiência de estádio e esquiva sem dependências."""

from __future__ import annotations

import json
import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RATE = 22_050


def write_wave(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(1.0, max(abs(value) for value in samples))
    pcm = bytearray()
    for value in samples:
        normalized = max(-1.0, min(1.0, value / peak * 0.92))
        pcm.extend(struct.pack("<h", round(normalized * 32_767)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


def envelope(time: float, duration: float, attack: float = 0.08) -> float:
    fade_in = min(1.0, time / max(attack, 0.001))
    fade_out = min(1.0, (duration - time) / max(duration * 0.28, 0.001))
    return max(0.0, fade_in * fade_out)


def beast_roar(creature: dict, family: str) -> list[float]:
    seed = int(creature["seed"]) * 7919
    rng = random.Random(seed)
    class_duration = {
        "Ultra Leve": 0.62,
        "Leve": 0.72,
        "Médio": 0.86,
        "Pesado": 1.02,
        "Colossal": 1.16,
    }
    duration = class_duration.get(creature["weight_class"], 0.86)
    family_base = {
        "bird": 205.0,
        "insect": 250.0,
        "specter": 155.0,
        "aquatic": 112.0,
        "serpent": 96.0,
        "dragon": 78.0,
        "mineral": 64.0,
        "plant": 72.0,
        "quadruped": 88.0,
        "biped": 105.0,
    }
    base = family_base.get(family, 100.0) * rng.uniform(0.90, 1.12)
    total = round(duration * RATE)
    output: list[float] = []
    phase = 0.0
    noise_memory = 0.0
    for index in range(total):
        time = index / RATE
        progress = time / duration
        pitch = base * (1.18 - progress * 0.42 + math.sin(progress * math.pi) * 0.12)
        phase += math.tau * pitch / RATE
        noise_memory = noise_memory * 0.80 + rng.uniform(-1.0, 1.0) * 0.20
        harmonic = (
            math.sin(phase)
            + math.sin(phase * 0.5 + 0.7) * 0.54
            + math.sin(phase * 2.03 + 1.2) * 0.24
        )
        growl = harmonic * (0.76 + math.sin(time * 31.0) * 0.12)
        texture = noise_memory * (0.58 if family in {"dragon", "mineral"} else 0.34)
        if family in {"bird", "insect"}:
            growl += math.sin(phase * 3.7) * 0.22
        elif family == "specter":
            growl *= 0.72 + math.sin(time * 17.0) * 0.26
            growl += math.sin(phase * 0.24) * 0.30
        elif family in {"aquatic", "serpent"}:
            growl += math.sin(phase * 0.33 + math.sin(time * 5.0)) * 0.34
        output.append((growl * 0.62 + texture) * envelope(time, duration))
    return output


def stadium_ambience(duration: float = 6.0) -> list[float]:
    rng = random.Random(20260813)
    total = round(duration * RATE)
    output: list[float] = []
    noise_memory = 0.0
    for index in range(total):
        time = index / RATE
        noise_memory = noise_memory * 0.985 + rng.uniform(-1.0, 1.0) * 0.015
        crowd = noise_memory * 0.58
        crowd += math.sin(math.tau * 73.0 * time) * 0.025
        crowd += math.sin(math.tau * 109.0 * time + 0.8) * 0.018
        cheer = max(0.0, math.sin(math.tau * time / 3.0 - 0.9)) ** 5 * 0.18
        crowd += cheer * math.sin(math.tau * 181.0 * time)
        output.append(crowd)
    crossfade = round(0.45 * RATE)
    start = output[:crossfade]
    for offset in range(crossfade):
        mix = offset / max(1, crossfade - 1)
        output[-crossfade + offset] = (
            output[-crossfade + offset] * (1.0 - mix) + start[offset] * mix
        )
    return output


def dodge_whoosh(duration: float = 0.34) -> list[float]:
    rng = random.Random(317)
    total = round(duration * RATE)
    output: list[float] = []
    smooth = 0.0
    for index in range(total):
        time = index / RATE
        progress = time / duration
        smooth = smooth * 0.56 + rng.uniform(-1.0, 1.0) * 0.44
        sweep = math.sin(math.tau * (220.0 + progress * 620.0) * time) * 0.18
        output.append((smooth * 0.74 + sweep) * math.sin(math.pi * progress))
    return output


def main() -> None:
    creatures = json.loads(
        (ROOT / "data/creatures.json").read_text(encoding="utf-8")
    )["creatures"]
    manifest = json.loads(
        (ROOT / "data/beast_3d_manifest.json").read_text(encoding="utf-8")
    )["beasts"]
    family_by_id = {item["id"]: item["family"] for item in manifest}
    beast_audio = ROOT / "assets/audio/beasts"
    for creature in creatures:
        output = beast_audio / f"{creature['id']}_roar.wav"
        write_wave(output, beast_roar(creature, family_by_id[creature["id"]]))
    write_wave(ROOT / "assets/audio/stadium_ambience.wav", stadium_ambience())
    write_wave(ROOT / "assets/audio/dodge.wav", dodge_whoosh())
    print(f"Rugidos: {len(creatures)}")
    print("Ambiência e esquiva: OK")


if __name__ == "__main__":
    main()
