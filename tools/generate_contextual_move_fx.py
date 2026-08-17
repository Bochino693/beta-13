#!/usr/bin/env python3
"""Gera 80 tiras de FX transparentes e coerentes com cada golpe.

Cada arquivo mantém o contrato do jogo: oito quadros horizontais de 192x192.
O desenho é determinístico, possui margem de segurança e muda de silhueta em
todos os quadros. A geometria 3D continua sendo criada no runtime; estas tiras
entram como núcleo luminoso e detalhe do impacto, nunca como fundo opaco.
"""

from __future__ import annotations

import colorsys
import hashlib
import json
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
FRAME = 192
# 2x preserva antialias e brilho, mantendo a geração rápida o bastante para
# ser repetida pelo desenvolvedor sem deixar arquivos parcialmente gravados.
SCALE = 2
FRAMES = 8
SAFE = 12 * SCALE

PALETTES = {
    "Luz": ("#fff4a8", "#55eaff", "#ffffff"),
    "Escuridão": ("#9b58ff", "#25114e", "#f0c9ff"),
    "Fogo": ("#ff632e", "#ffcf45", "#fff6cf"),
    "Choque": ("#38dfff", "#fff36c", "#ffffff"),
    "Terra": ("#b87943", "#f0c878", "#6d3f2c"),
    "Água": ("#32cfff", "#9ff7ff", "#176ed4"),
    "Natureza": ("#42e778", "#d4ff69", "#177b49"),
    "Vento": ("#bafaff", "#ffffff", "#6bcfe9"),
}


def rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def seeded(move_id: str, frame: int) -> random.Random:
    digest = hashlib.sha256(f"{move_id}:{frame}".encode()).digest()
    return random.Random(int.from_bytes(digest[:8], "big"))


def layer() -> Image.Image:
    return Image.new("RGBA", (FRAME * SCALE, FRAME * SCALE), (0, 0, 0, 0))


def composite_glow(base: Image.Image, shape: Image.Image, radius: float = 8.0) -> None:
    glow = shape.filter(ImageFilter.GaussianBlur(radius * SCALE))
    base.alpha_composite(glow)
    base.alpha_composite(shape)


def glow_line(
    base: Image.Image,
    points: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    width: float,
    radius: float = 6.0,
) -> None:
    shape = layer()
    draw = ImageDraw.Draw(shape)
    scaled = [(round(x * SCALE), round(y * SCALE)) for x, y in points]
    draw.line(scaled, fill=color, width=max(1, round(width * SCALE)), joint="curve")
    composite_glow(base, shape, radius)


def glow_ellipse(
    base: Image.Image,
    box: tuple[float, float, float, float],
    color: tuple[int, int, int, int],
    width: float = 0.0,
    radius: float = 7.0,
) -> None:
    shape = layer()
    draw = ImageDraw.Draw(shape)
    scaled = tuple(round(value * SCALE) for value in box)
    if width > 0:
        draw.ellipse(scaled, outline=color, width=max(1, round(width * SCALE)))
    else:
        draw.ellipse(scaled, fill=color)
    composite_glow(base, shape, radius)


def glow_polygon(
    base: Image.Image,
    points: list[tuple[float, float]],
    color: tuple[int, int, int, int],
    radius: float = 6.0,
) -> None:
    shape = layer()
    draw = ImageDraw.Draw(shape)
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=color)
    composite_glow(base, shape, radius)


def arc_points(
    center: tuple[float, float], radius: float, start: float, finish: float, count: int = 28
) -> list[tuple[float, float]]:
    return [
        (
            center[0] + math.cos(start + (finish - start) * i / (count - 1)) * radius,
            center[1] + math.sin(start + (finish - start) * i / (count - 1)) * radius,
        )
        for i in range(count)
    ]


def particles(
    base: Image.Image,
    rng: random.Random,
    color: tuple[int, int, int, int],
    count: int,
    center: tuple[float, float] = (96, 96),
    spread: tuple[float, float] = (55, 42),
    elongated: bool = False,
) -> None:
    for _ in range(count):
        x = center[0] + rng.uniform(-spread[0], spread[0])
        y = center[1] + rng.uniform(-spread[1], spread[1])
        size = rng.uniform(2.0, 6.0)
        if elongated:
            glow_line(base, [(x - size, y + size), (x + size, y - size)], color, 1.5, 2.2)
        else:
            glow_ellipse(base, (x - size, y - size, x + size, y + size), color, 0, 2.5)


def draw_family(move: dict, frame_index: int) -> Image.Image:
    family = str(move["effect_family"])
    reaction = str(move["scene_reaction"])
    element = str(move["element"])
    rng = seeded(str(move["id"]), frame_index)
    primary, secondary, highlight = [rgba(value) for value in PALETTES[element]]
    t = frame_index / float(FRAMES - 1)
    pulse = 0.78 + 0.22 * math.sin(t * math.pi)
    base = layer()

    if family in {"orb", "bubble", "burst", "eclipse", "vortex"}:
        radius = (22 + 9 * math.sin(t * math.pi)) * pulse
        if family == "eclipse":
            glow_ellipse(base, (96 - radius, 96 - radius, 96 + radius, 96 + radius), rgba("#150c31"), 0, 10)
            glow_ellipse(base, (96 - radius - 7, 96 - radius - 7, 96 + radius + 7, 96 + radius + 7), primary, 4, 8)
        elif family == "bubble":
            glow_ellipse(base, (96 - radius, 96 - radius, 96 + radius, 96 + radius), secondary, 4, 7)
            glow_ellipse(base, (82, 77, 91, 86), highlight, 0, 3)
        elif family == "vortex":
            for ring in range(3):
                rr = radius + ring * 11
                pts = arc_points((96, 96), rr, t * math.tau + ring, t * math.tau + ring + math.pi * 1.45)
                glow_line(base, pts, primary if ring != 1 else secondary, 3.5 - ring * 0.5, 6)
        else:
            glow_ellipse(base, (96 - radius, 96 - radius, 96 + radius, 96 + radius), primary, 0, 11)
            glow_ellipse(base, (88, 87, 104, 103), highlight, 0, 4)
            if family == "burst":
                for ray in range(10):
                    angle = ray * math.tau / 10 + t * 0.7
                    glow_line(base, [(96, 96), (96 + math.cos(angle) * 65, 96 + math.sin(angle) * 65)], secondary, 2.4, 5)

    elif family in {"spear", "beam", "breath", "gust", "shard", "torpedo"}:
        length = 122 if family in {"beam", "breath", "gust"} else 92
        wobble = math.sin(t * math.tau) * 5
        if family == "breath":
            glow_polygon(base, [(39, 88), (39, 104), (40 + length, 125 + wobble), (40 + length, 67 + wobble)], primary, 11)
            particles(base, rng, secondary, 16, (118, 96), (48, 34))
        elif family == "gust":
            for line in range(4):
                y = 74 + line * 15 + math.sin(t * math.tau + line) * 5
                pts = [(35, y), (70, y - 8), (110, y + 6), (35 + length, y - 3)]
                glow_line(base, pts, primary if line % 2 == 0 else secondary, 3, 5)
        elif family == "torpedo":
            glow_polygon(base, [(44, 96), (76, 75), (147, 86), (164, 96), (147, 106), (76, 117)], primary, 8)
            for ring in range(3):
                x = 45 - ring * 12 + (frame_index % 2) * 3
                glow_ellipse(base, (x - 7, 82, x + 7, 110), secondary, 2.5, 4)
        else:
            tip = 45 + length
            width = 6 if family == "beam" else 12
            glow_polygon(base, [(39, 96 - width), (tip - 17, 96 - width * 0.55), (tip, 96), (tip - 17, 96 + width * 0.55), (39, 96 + width)], primary, 8)
            glow_line(base, [(45, 96), (tip - 5, 96)], highlight, 2.5, 4)
            if family == "shard":
                for extra in range(3):
                    y = 68 + extra * 28
                    glow_polygon(base, [(74, y), (105, y - 5), (118, y), (105, y + 5)], secondary, 4)

    elif family == "lightning":
        points = [(34, 96)]
        for index in range(1, 8):
            points.append((34 + index * 18, 96 + rng.uniform(-25, 25)))
        points.append((160, 96))
        glow_line(base, points, primary, 7, 8)
        glow_line(base, points, highlight, 2, 4)
        particles(base, rng, secondary, 10, (96, 96), (58, 42), True)

    elif family in {"slash", "claw", "maw"}:
        count = 3 if family in {"claw", "maw"} else 2
        for index in range(count):
            rr = 48 + index * 10
            start = -2.2 + t * 0.25 + index * 0.12
            pts = arc_points((94, 106), rr, start, start + 1.72, 34)
            glow_line(base, pts, primary if index % 2 == 0 else secondary, 7 - index, 7)
            glow_line(base, pts, highlight, 1.5, 3)
        if family == "maw":
            glow_polygon(base, [(62, 82), (92, 96), (63, 110), (83, 96)], primary, 5)
            glow_polygon(base, [(130, 82), (100, 96), (129, 110), (109, 96)], primary, 5)

    elif family in {"ring", "field", "sigil", "wall", "shell", "prison", "net"}:
        rings = 3 if family in {"field", "prison", "net"} else 2
        for index in range(rings):
            rr = (28 + index * 15) * (0.82 + t * 0.25)
            glow_ellipse(base, (96 - rr, 96 - rr * 0.65, 96 + rr, 96 + rr * 0.65), primary if index != 1 else secondary, 4.5, 7)
        if family == "sigil":
            for spoke in range(6):
                angle = spoke * math.tau / 6 + t * 0.45
                glow_line(base, [(96 + math.cos(angle) * 18, 96 + math.sin(angle) * 18), (96 + math.cos(angle) * 57, 96 + math.sin(angle) * 37)], highlight, 2.5, 4)
        elif family in {"wall", "shell"}:
            glow_line(base, [(49, 124), (64, 61), (96, 43), (128, 61), (143, 124)], secondary, 5, 7)
        elif family == "net":
            for offset in range(-36, 49, 18):
                glow_line(base, [(58, 96 + offset), (134, 96 - offset)], secondary, 2, 4)

    elif family in {"whip", "chains", "coil", "root", "spiral", "tornado", "orbit"}:
        loops = 2.4 if family in {"tornado", "spiral", "coil"} else 1.25
        pts = []
        for index in range(55):
            p = index / 54
            x = 37 + p * 120
            amp = (13 + p * 25) if family == "tornado" else 24
            y = 96 + math.sin(p * math.tau * loops + t * math.tau) * amp * (0.45 + p * 0.55)
            pts.append((x, y))
        glow_line(base, pts, primary, 7 if family == "root" else 4.5, 8)
        glow_line(base, pts, highlight, 1.4, 3)
        if family == "chains":
            for x, y in pts[::7]:
                glow_ellipse(base, (x - 6, y - 4, x + 6, y + 4), secondary, 2, 3)
        particles(base, rng, secondary, 9, (100, 96), (55, 44))

    elif family in {"fog", "foam", "pollen", "spores", "swarm", "storm", "rain", "nightfall", "prism_storm"}:
        count = 28 if family in {"storm", "rain", "nightfall", "prism_storm"} else 20
        elongated = family in {"storm", "rain", "prism_storm"}
        particles(base, rng, primary, count, (96, 96), (58, 58), elongated)
        if family == "nightfall":
            glow_ellipse(base, (48, 48, 144, 144), rgba("#21103f", 190), 0, 12)
            glow_ellipse(base, (57, 57, 135, 135), secondary, 3, 8)
        if family == "foam":
            for bubble in range(8):
                x = 55 + bubble * 11 + rng.uniform(-4, 4)
                y = 106 + rng.uniform(-20, 18)
                glow_ellipse(base, (x - 6, y - 6, x + 6, y + 6), secondary, 2, 4)

    elif family in {"ground_wave", "fissure", "pillar", "eruption", "caldera", "forest", "fossil", "mycelium", "water_throne", "monolith", "meteor"}:
        ground_y = 139
        glow_line(base, [(34, ground_y), (158, ground_y)], primary, 4, 6)
        if family in {"ground_wave", "fissure", "caldera"}:
            pts = [(35, ground_y), (54, 128), (70, 142), (88, 119), (106, 138), (125, 112), (158, 132)]
            glow_line(base, pts, primary, 6, 8)
            glow_line(base, pts, highlight, 1.5, 3)
        elif family == "meteor":
            glow_ellipse(base, (70, 50 + t * 18, 122, 102 + t * 18), primary, 0, 12)
            for trail in range(4):
                glow_line(base, [(81 + trail * 10, 48 + t * 18), (56 + trail * 8, 24)], secondary, 4, 6)
        elif family == "monolith":
            glow_polygon(base, [(75, 137), (68, 64), (93, 42), (119, 66), (124, 137)], primary, 10)
            glow_line(base, [(93, 55), (94, 125)], highlight, 3, 5)
        else:
            pieces = 5 if family in {"forest", "fossil", "mycelium", "water_throne"} else 3
            for index in range(pieces):
                x = 52 + index * (88 / max(1, pieces - 1))
                height = 34 + ((index * 17 + frame_index * 9) % 42)
                top = ground_y - height * (0.75 + t * 0.25)
                if family in {"forest", "mycelium"}:
                    glow_line(base, [(x, ground_y), (x + math.sin(index) * 9, top)], primary, 7, 7)
                    glow_ellipse(base, (x - 15, top - 10, x + 15, top + 10), secondary, 0, 6)
                elif family == "water_throne":
                    glow_line(base, [(x, ground_y), (x + math.sin(index) * 7, top)], primary, 10, 9)
                else:
                    glow_polygon(base, [(x - 8, ground_y), (x - 5, top + 9), (x, top), (x + 6, top + 8), (x + 9, ground_y)], primary, 7)

    elif family in {"dash", "wave"}:
        for index in range(4):
            y = 65 + index * 20 + math.sin(t * math.tau + index) * 5
            glow_line(base, [(38, y), (74, y - 9), (118, y + 7), (157, y - 4)], primary if index % 2 == 0 else secondary, 4, 6)
        if reaction == "sonic_boom":
            glow_ellipse(base, (58, 49, 134, 143), highlight, 4, 8)

    else:
        glow_ellipse(base, (66, 66, 126, 126), primary, 0, 10)
        particles(base, rng, secondary, 12)

    # Uma assinatura secundária baseada no nome evita golpes visualmente iguais.
    signature = int(hashlib.md5(str(move["id"]).encode()).hexdigest()[:4], 16)
    for index in range(3 + signature % 4):
        angle = (signature % 360) * math.pi / 180 + index * math.tau / (3 + signature % 4) + t
        distance = 48 + (signature % 13)
        x = 96 + math.cos(angle) * distance
        y = 96 + math.sin(angle) * distance
        glow_ellipse(base, (x - 2.5, y - 2.5, x + 2.5, y + 2.5), highlight, 0, 2.5)

    # Antialias, margem transparente absoluta e tamanho contratual.
    base = base.resize((FRAME, FRAME), Image.Resampling.LANCZOS)
    base.paste((0, 0, 0, 0), (0, 0, FRAME, 4))
    base.paste((0, 0, 0, 0), (0, FRAME - 4, FRAME, FRAME))
    base.paste((0, 0, 0, 0), (0, 0, 4, FRAME))
    base.paste((0, 0, 0, 0), (FRAME - 4, 0, FRAME, FRAME))
    return base


def main() -> None:
    catalog_path = ROOT / "data" / "moves.json"
    moves = json.loads(catalog_path.read_text(encoding="utf-8"))["moves"]
    requested = set(sys.argv[1:])
    if requested:
        known = {str(move["id"]) for move in moves}
        unknown = requested - known
        if unknown:
            raise SystemExit(f"Golpes inexistentes: {sorted(unknown)}")
        moves = [move for move in moves if str(move["id"]) in requested]
    output = ROOT / "assets" / "moves_fx"
    output.mkdir(parents=True, exist_ok=True)
    for move in moves:
        missing = {"effect_family", "travel_style", "scene_reaction"} - set(move)
        if missing:
            raise SystemExit(f"{move['id']}: perfil visual incompleto: {sorted(missing)}")
        strip = Image.new("RGBA", (FRAME * FRAMES, FRAME), (0, 0, 0, 0))
        for frame_index in range(FRAMES):
            strip.alpha_composite(draw_family(move, frame_index), (frame_index * FRAME, 0))
        final_path = output / f"{move['id']}.png"
        temporary_path = output / f".{move['id']}.tmp.png"
        strip.save(temporary_path, optimize=True)
        temporary_path.replace(final_path)
    print(f"Geradas {len(moves)} tiras contextuais RGBA em {output}")


if __name__ == "__main__":
    main()
