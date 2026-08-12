#!/usr/bin/env python3
"""Gera músicas e efeitos WAV originais para o arcade."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"
RATE = 22050


def oscillator(kind: str, phase: float) -> float:
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0 else -1.0
    if kind == "triangle":
        return 2.0 / math.pi * math.asin(math.sin(phase))
    if kind == "saw":
        return 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
    return math.sin(phase)


def add_tone(buffer: list[float], start: float, duration: float, frequency: float, volume: float, kind: str = "sine", glide: float = 0.0) -> None:
    start_frame = max(0, int(start * RATE))
    end_frame = min(len(buffer), int((start + duration) * RATE))
    phase = 0.0
    for frame in range(start_frame, end_frame):
        local = (frame - start_frame) / RATE
        attack = min(1.0, local / 0.012)
        release = min(1.0, (duration - local) / min(0.12, duration * 0.35))
        envelope = max(0.0, attack * release)
        current_frequency = frequency * (1.0 + glide * local / max(duration, 0.001))
        phase += 2.0 * math.pi * current_frequency / RATE
        buffer[frame] += oscillator(kind, phase) * volume * envelope


def add_drum(buffer: list[float], start: float, volume: float = 0.25) -> None:
    duration = 0.13
    start_frame = int(start * RATE)
    for offset in range(int(duration * RATE)):
        frame = start_frame + offset
        if frame >= len(buffer):
            break
        local = offset / RATE
        envelope = math.exp(-local * 30.0)
        kick = math.sin(2.0 * math.pi * (105.0 - local * 430.0) * local)
        noise = random.uniform(-1.0, 1.0) * 0.18
        buffer[frame] += (kick + noise) * volume * envelope


def save(filename: str, buffer: list[float]) -> None:
    peak = max(0.001, max(abs(sample) for sample in buffer))
    gain = min(0.92 / peak, 1.0)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, sample * gain)) * 32767)) for sample in buffer)
    with wave.open(str(OUTPUT / filename), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


def make_music(filename: str, bpm: float, notes: list[float], bars: int, mood: str) -> None:
    step = 60.0 / bpm / 2.0
    duration = len(notes) * bars * step
    buffer = [0.0] * int(duration * RATE)
    for repeat in range(bars):
        for index, frequency in enumerate(notes):
            at = (repeat * len(notes) + index) * step
            add_tone(buffer, at, step * 0.76, frequency, 0.11, "square" if mood == "battle" else "triangle")
            add_tone(buffer, at, step * 0.90, frequency * 2.0, 0.035, "sine")
            if index % 2 == 0:
                add_tone(buffer, at, step * 1.8, frequency * 0.5, 0.09, "saw")
            if index % 4 == 0:
                add_drum(buffer, at, 0.28 if mood == "battle" else 0.18)
            elif mood == "battle" and index % 2 == 1:
                add_drum(buffer, at, 0.11)
    save(filename, buffer)


def make_sfx(filename: str, tones: list[tuple[float, float, float, float, str, float]], duration: float, noise: bool = False) -> None:
    buffer = [0.0] * int(duration * RATE)
    for start, length, frequency, volume, kind, glide in tones:
        add_tone(buffer, start, length, frequency, volume, kind, glide)
    if noise:
        for frame in range(len(buffer)):
            local = frame / RATE
            buffer[frame] += random.uniform(-1.0, 1.0) * 0.18 * math.exp(-local * 19.0)
    save(filename, buffer)


def main() -> None:
    random.seed(1313)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    make_music("intro_theme.wav", 94.0, [110.0, 164.81, 220.0, 293.66, 220.0, 164.81, 246.94, 329.63], 2, "intro")
    make_music("menu_loop.wav", 116.0, [146.83, 220.0, 293.66, 246.94, 174.61, 261.63, 329.63, 293.66], 3, "menu")
    make_music("battle_loop.wav", 142.0, [110.0, 110.0, 164.81, 146.83, 110.0, 196.0, 174.61, 146.83], 4, "battle")
    make_music("victory_theme.wav", 122.0, [261.63, 329.63, 392.0, 523.25, 392.0, 523.25, 659.25, 783.99], 2, "victory")

    make_sfx("ui_move.wav", [(0, .06, 520, .25, "square", .15), (.035, .07, 690, .16, "sine", 0)], .13)
    make_sfx("confirm.wav", [(0, .09, 440, .28, "triangle", .2), (.06, .13, 660, .25, "square", 0)], .22)
    make_sfx("cancel.wav", [(0, .10, 310, .25, "saw", -.3), (.07, .12, 180, .20, "triangle", 0)], .22)
    make_sfx("coin.wav", [(0, .08, 988, .28, "square", 0), (.08, .17, 1319, .32, "square", .05)], .28)
    make_sfx("hit.wav", [(0, .15, 95, .42, "saw", -.45), (0, .06, 180, .24, "square", 0)], .20, True)
    make_sfx("special.wav", [(0, .20, 131, .30, "saw", .9), (.05, .18, 523, .24, "square", .3), (.12, .17, 784, .18, "sine", 0)], .34, True)
    make_sfx("guard.wav", [(0, .12, 220, .25, "triangle", .2), (.04, .22, 440, .20, "sine", -.1)], .29)
    make_sfx("knockout.wav", [(0, .18, 165, .32, "saw", -.4), (.12, .31, 110, .30, "triangle", -.2)], .48, True)
    make_sfx("victory.wav", [(0, .14, 523, .25, "square", 0), (.10, .14, 659, .25, "square", 0), (.20, .14, 784, .27, "square", 0), (.30, .28, 1047, .30, "triangle", 0)], .62)
    print("Gerados: 4 temas musicais e 9 efeitos WAV originais.")


if __name__ == "__main__":
    main()
