#!/usr/bin/env python3
"""Gera atlas de combate V3 padronizados, sem vazamento entre celulas.

O material de entrada e lido do commit-base 04e80a2 para que o gerador possa
ser executado novamente mesmo depois de os atlas finais substituirem os V2.
Cada Beast recebe 32 celulas RGBA de 384 px: 16 de costas e 16 de frente.
"""

from __future__ import annotations

import io
import json
import math
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
BASE_REF = "04e80a2"
CELL = 384
COLS = 8
ROWS = 4
SAFE = 22

POSE_NAMES = (
    "idle_0", "idle_1", "idle_2", "idle_3", "idle_4", "idle_5",
    "light_charge", "light_impact", "heavy_charge", "heavy_impact",
    "damage", "dodge_left", "dodge_right", "victory", "ko", "guard",
)

FAMILY_BY_ID = {
    "lumari": "spectral", "helionce": "fur", "prismara": "wing",
    "impavor": "spectral", "nocturna": "spectral", "abissarca": "dragon",
    "brasalam": "reptile", "vulcora": "mineral", "cinzibora": "spectral",
    "pyrocondor": "wing", "voltalho": "fur", "raiarraia": "aquatic",
    "teslouro": "mineral", "arcdrake": "dragon", "pedrilho": "fur",
    "geodrilo": "reptile", "monolito": "mineral", "fossatroz": "reptile",
    "medulux": "aquatic", "crustarka": "aquatic", "torpescama": "aquatic",
    "marevante": "dragon", "floraphex": "wing", "brotoxi": "plant",
    "musgurso": "fur", "arborion": "plant", "brispulo": "fur",
    "nimbaleia": "aquatic", "ciclorn": "wing", "tempestral": "dragon",
}

ELEMENT_COLORS = {
    "Luz": (255, 230, 92), "Escuridão": (165, 83, 255),
    "Fogo": (255, 86, 48), "Choque": (68, 226, 255),
    "Terra": (211, 146, 72), "Água": (70, 146, 255),
    "Natureza": (73, 224, 126), "Vento": (139, 246, 230),
}


def git_bytes(path: str) -> bytes:
    return subprocess.check_output(
        ["git", "show", f"{BASE_REF}:{path}"], cwd=ROOT
    )


def source_atlas(creature_id: str) -> Image.Image:
    raw = git_bytes(f"assets/sprites_combat/{creature_id}.png")
    with Image.open(io.BytesIO(raw)) as image:
        return image.convert("RGBA")


def crop_source(atlas: Image.Image, index: int) -> Image.Image:
    cell_w = atlas.width // 4
    cell_h = atlas.height // 4
    x = (index % 4) * cell_w
    y = (index // 4) * cell_h
    nominal = clean_disconnected_fragments(atlas.crop((x, y, x + cell_w, y + cell_h)))
    bbox = nominal.getchannel("A").point(lambda value: 255 if value > 3 else 0).getbbox()
    if bbox is None:
        return Image.new("RGBA", (1, 1))
    left, top, right, bottom = bbox
    pad = 4
    return nominal.crop((
        max(0, left - pad), max(0, top - pad),
        min(cell_w, right + pad), min(cell_h, bottom + pad),
    ))


def clean_disconnected_fragments(image: Image.Image) -> Image.Image:
    """Mantem o corpo e detalhes proximos; remove vazamento de outra celula."""
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    labels, count = ndimage.label(alpha > 4, structure=np.ones((3, 3), dtype=np.uint8))
    if count <= 1:
        return image
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    main_label = int(areas.argmax())
    main_area = int(areas[main_label])
    main_mask = labels == main_label
    distance_to_body = ndimage.distance_transform_edt(~main_mask)
    proximity = max(9, round(min(image.size) * 0.045))
    keep = {main_label}

    for label_id in range(1, count + 1):
        if label_id == main_label or int(areas[label_id]) < max(10, round(main_area * 0.0012)):
            continue
        component = labels == label_id
        nearest = float(distance_to_body[component].min())
        if nearest <= proximity:
            keep.add(label_id)

    keep_mask = np.isin(labels, tuple(keep))
    cleaned_alpha = np.where(keep_mask, alpha, 0).astype(np.uint8)
    result = image.copy()
    result.putalpha(Image.fromarray(cleaned_alpha, mode="L"))
    return result


def transform(
    source: Image.Image,
    *,
    scale_x: float = 1.0,
    scale_y: float = 1.0,
    angle: float = 0.0,
    shift_x: int = 0,
    shift_y: int = 0,
    tint: tuple[int, int, int] | None = None,
    brightness: float = 1.0,
) -> Image.Image:
    width = max(1, round(source.width * scale_x))
    height = max(1, round(source.height * scale_y))
    image = source.resize((width, height), Image.Resampling.LANCZOS)
    if abs(angle) > 0.01:
        image = image.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    if brightness != 1.0:
        rgb = ImageEnhance.Brightness(image.convert("RGB")).enhance(brightness)
        rgb.putalpha(image.getchannel("A"))
        image = rgb
    if tint is not None:
        overlay = Image.new("RGBA", image.size, (*tint, 0))
        overlay.putalpha(image.getchannel("A").point(lambda a: round(a * 0.22)))
        image = Image.alpha_composite(image, overlay)
    canvas = Image.new("RGBA", (CELL, CELL))
    max_w = CELL - SAFE * 2
    max_h = CELL - SAFE * 2
    ratio = min(max_w / image.width, max_h / image.height, 1.45)
    if ratio < 0.999 or ratio > 1.001:
        image = image.resize(
            (max(1, round(image.width * ratio)), max(1, round(image.height * ratio))),
            Image.Resampling.LANCZOS,
        )
    px = (CELL - image.width) // 2 + shift_x
    py = CELL - SAFE - image.height + shift_y
    px = min(max(SAFE, px), CELL - SAFE - image.width)
    py = min(max(SAFE, py), CELL - SAFE - image.height)
    canvas.alpha_composite(image, (px, py))
    return canvas


def add_energy(image: Image.Image, color: tuple[int, int, int], strength: float) -> Image.Image:
    result = image.copy()
    alpha = image.getchannel("A")
    blurred = np.asarray(alpha.filter(ImageFilter.GaussianBlur(8)), dtype=np.int16)
    solid = np.asarray(alpha, dtype=np.int16)
    outer = np.clip((blurred - solid * 0.78) * (0.72 + strength), 0, 46).astype(np.uint8)
    glow = Image.new("RGBA", image.size, (*color, 0))
    glow.putalpha(Image.fromarray(outer, mode="L"))
    result = Image.alpha_composite(glow, result)
    draw = ImageDraw.Draw(result, "RGBA")
    cx, cy = CELL // 2, CELL // 2 + 42
    for radius, width, opacity in ((142, 3, 105), (126, 2, 80)):
        draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), 198, 342,
                 fill=(*color, opacity), width=width)
    return result


def add_guard(image: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    result = image.copy()
    draw = ImageDraw.Draw(result, "RGBA")
    for radius, width, opacity in ((154, 5, 170), (142, 2, 110), (128, 2, 80)):
        box = (CELL // 2 - radius, CELL // 2 - radius + 18,
               CELL // 2 + radius, CELL // 2 + radius + 18)
        draw.arc(box, 192, 348, fill=(*color, opacity), width=width)
    for degree in range(205, 341, 27):
        radians = math.radians(degree)
        x = CELL // 2 + math.cos(radians) * 150
        y = CELL // 2 + 18 + math.sin(radians) * 150
        draw.ellipse((x - 4, y - 4, x + 4, y + 4), fill=(*color, 210))
    return result


def states(atlas: Image.Image, back: bool, family: str, color: tuple[int, int, int]) -> list[Image.Image]:
    offset = 8 if back else 0
    rest_a = crop_source(atlas, offset + 0)
    rest_b = crop_source(atlas, offset + 1)
    charge = crop_source(atlas, offset + 2)
    attack = crop_source(atlas, offset + 3)
    damage = crop_source(atlas, offset + 4)
    dodge = crop_source(atlas, offset + 5)
    victory = crop_source(atlas, offset + 6)
    ko = crop_source(atlas, offset + 7)

    amplitude = 1.0
    if family in {"wing", "spectral", "aquatic"}:
        amplitude = 1.45
    elif family == "mineral":
        amplitude = 0.72

    idle = [
        transform(rest_a),
        transform(rest_b, shift_y=-round(2 * amplitude)),
        transform(rest_a, scale_x=0.985, scale_y=1.025, angle=-1.15 * amplitude,
                  shift_y=-round(3 * amplitude)),
        transform(rest_b, scale_x=1.018, scale_y=0.99, angle=1.35 * amplitude,
                  shift_y=-round(5 * amplitude)),
        transform(rest_a, scale_x=1.025, scale_y=0.975, angle=0.65 * amplitude,
                  shift_x=round(3 * amplitude)),
        transform(rest_b, scale_x=0.99, scale_y=1.035, angle=-0.55 * amplitude,
                  shift_x=-round(3 * amplitude), shift_y=-round(4 * amplitude)),
    ]

    light_charge = transform(charge, scale_x=0.98, scale_y=1.02,
                             shift_x=-10 if back else 10)
    light_impact = transform(attack, scale_x=1.035, scale_y=0.985,
                             shift_x=12 if back else -12, brightness=1.06)
    heavy_charge = add_energy(
        transform(charge, scale_x=0.95, scale_y=1.04, tint=color, brightness=1.08),
        color, 0.44,
    )
    heavy_impact = add_energy(
        transform(attack, scale_x=1.07, scale_y=1.02,
                  shift_x=16 if back else -16, brightness=1.12),
        color, 0.62,
    )
    hurt = transform(damage, angle=-4.0 if back else 4.0, tint=(255, 72, 82),
                     brightness=1.08)
    dodge_left = transform(dodge, scale_x=0.96, scale_y=1.02, angle=5.0,
                           shift_x=-18)
    dodge_right = transform(dodge.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
                            scale_x=0.96, scale_y=1.02, angle=-5.0, shift_x=18)
    win = transform(victory, scale_x=1.02, scale_y=1.05, shift_y=-7, brightness=1.06)
    defeated = transform(ko, scale_x=1.04, scale_y=0.94, shift_y=8, brightness=0.77)
    guard = add_guard(transform(rest_a, scale_x=0.97, scale_y=1.01), (89, 215, 255))
    return idle + [light_charge, light_impact, heavy_charge, heavy_impact, hurt,
                   dodge_left, dodge_right, win, defeated, guard]


def save_atlas(creature: dict) -> None:
    creature_id = creature["id"]
    source = source_atlas(creature_id)
    family = FAMILY_BY_ID.get(creature_id, "standard")
    color = ELEMENT_COLORS[creature["type"]]
    # Nos atlas V2 a metade visual de costas ocupa 0..7, embora manifestos
    # antigos tenham gravado os sufixos ao contrario. O V3 corrige o contrato:
    # 0..15 costas (jogador), 16..31 frente (adversario).
    frames = states(source, False, family, color) + states(source, True, family, color)
    assert len(frames) == 32

    atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL))
    for index, frame in enumerate(frames):
        atlas.alpha_composite(frame, ((index % COLS) * CELL, (index // COLS) * CELL))

    target = ROOT / "assets" / "sprites_combat" / f"{creature_id}.png"
    temp = target.with_suffix(".png.tmp")
    atlas.save(temp, format="PNG", compress_level=6, optimize=False)
    with Image.open(temp) as check:
        check.load()
        if check.size != (3072, 1536) or check.mode != "RGBA":
            raise RuntimeError(f"atlas invalido: {creature_id}")
    temp.replace(target)

    poses = []
    for index in range(32):
        view = "back" if index < 16 else "front"
        state = POSE_NAMES[index % 16]
        poses.append({
            "name": f"{view}_{state}",
            "index": index,
            "rect": [(index % COLS) * CELL, (index // COLS) * CELL, CELL, CELL],
            "anchor": [0.5, 1.0],
        })
    manifest = {
        "version": 3,
        "id": creature_id,
        "atlas": f"res://assets/sprites_combat/{creature_id}.png",
        "size": [COLS * CELL, ROWS * CELL],
        "rows": ROWS,
        "columns": COLS,
        "cell": [CELL, CELL],
        "safe_margin": SAFE,
        "poses": poses,
    }
    (target.parent / f"{creature_id}.poses.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    catalog = json.loads((ROOT / "data" / "creatures.json").read_text(encoding="utf-8"))
    for number, creature in enumerate(catalog["creatures"], start=1):
        save_atlas(creature)
        print(f"[{number:02d}/30] {creature['id']}")
    print("Atlas V3: 30 Beasts, 960 quadros, grade 8x4.")


if __name__ == "__main__":
    main()
