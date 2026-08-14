#!/usr/bin/env python3
"""Gera atlas cinematograficos V4 com recorte seguro e 64 quadros.

Cada Beast recebe 32 quadros de costas e 32 de frente em celulas RGBA
fixas de 384 px. Os quadros intermediarios unem poses reais do material
fonte com deformacoes curtas de antecipacao/impacto; nenhuma celula consulta
pixels vizinhos. O contrato foi pensado para animacao temporal no Godot,
nao para trocar uma imagem estatica por outra.
"""

from __future__ import annotations

import io
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
from scipy import ndimage


ROOT = Path(__file__).resolve().parents[1]
BASE_REF = "04e80a2"
CELL = 384
COLS = 8
ROWS = 8
SAFE = 28

SEQUENCES = {
    "idle": (0, 8, 9.0, True),
    "light": (8, 12, 15.0, False),
    "heavy_charge": (12, 15, 9.0, False),
    "heavy_release": (15, 18, 13.0, False),
    "damage": (18, 21, 14.0, False),
    "dodge_left": (21, 24, 16.0, False),
    "dodge_right": (24, 27, 16.0, False),
    "victory": (27, 29, 6.0, True),
    "ko": (29, 31, 5.0, False),
    "guard": (31, 32, 1.0, True),
}

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

FAMILY_MOTION = {
    "wing": (1.55, 1.15, 1.18),
    "spectral": (1.45, 1.10, 1.12),
    "aquatic": (1.35, 1.05, 1.10),
    "dragon": (1.08, 1.02, 1.04),
    "fur": (1.00, 1.00, 1.00),
    "reptile": (0.86, 0.96, 0.94),
    "plant": (0.78, 0.92, 0.90),
    "mineral": (0.58, 0.82, 0.78),
}


def git_bytes(path: str) -> bytes:
    return subprocess.check_output(["git", "show", f"{BASE_REF}:{path}"], cwd=ROOT)


def source_atlas(creature_id: str) -> Image.Image:
    raw = git_bytes(f"assets/sprites_combat/{creature_id}.png")
    with Image.open(io.BytesIO(raw)) as image:
        return image.convert("RGBA")


def clean_components(image: Image.Image) -> Image.Image:
    """Mantem corpo e detalhes proximos, removendo vazamento da celula vizinha."""
    alpha = np.asarray(image.getchannel("A"), dtype=np.uint8)
    labels, count = ndimage.label(alpha > 4, structure=np.ones((3, 3), dtype=np.uint8))
    if count <= 1:
        return image
    areas = np.bincount(labels.ravel())
    areas[0] = 0
    main_label = int(areas.argmax())
    main_area = int(areas[main_label])
    main_mask = labels == main_label
    distance = ndimage.distance_transform_edt(~main_mask)
    keep = {main_label}
    proximity = max(10, round(min(image.size) * 0.048))
    minimum = max(10, round(main_area * 0.0011))
    for label_id in range(1, count + 1):
        if label_id == main_label or int(areas[label_id]) < minimum:
            continue
        component = labels == label_id
        if float(distance[component].min()) <= proximity:
            keep.add(label_id)
    result = image.copy()
    result.putalpha(Image.fromarray(np.where(np.isin(labels, tuple(keep)), alpha, 0).astype(np.uint8)))
    return result


def crop_source(atlas: Image.Image, index: int) -> Image.Image:
    width = atlas.width // 4
    height = atlas.height // 4
    x = (index % 4) * width
    y = (index // 4) * height
    nominal = clean_components(atlas.crop((x, y, x + width, y + height)))
    bbox = nominal.getchannel("A").point(lambda value: 255 if value > 3 else 0).getbbox()
    if bbox is None:
        return Image.new("RGBA", (1, 1))
    left, top, right, bottom = bbox
    pad = 5
    return nominal.crop((max(0, left - pad), max(0, top - pad), min(width, right + pad), min(height, bottom + pad)))


def fit(
    source: Image.Image,
    *,
    scale_x: float = 1.0,
    scale_y: float = 1.0,
    angle: float = 0.0,
    shift_x: int = 0,
    shift_y: int = 0,
    brightness: float = 1.0,
    tint: tuple[int, int, int] | None = None,
) -> Image.Image:
    bbox = source.getchannel("A").getbbox()
    image = source.crop(bbox) if bbox is not None else source
    image = image.resize((max(1, round(image.width * scale_x)), max(1, round(image.height * scale_y))), Image.Resampling.LANCZOS)
    if abs(angle) > 0.01:
        image = image.rotate(angle, Image.Resampling.BICUBIC, expand=True)
    if brightness != 1.0:
        rgb = ImageEnhance.Brightness(image.convert("RGB")).enhance(brightness)
        rgb.putalpha(image.getchannel("A"))
        image = rgb
    if tint is not None:
        color = Image.new("RGBA", image.size, (*tint, 0))
        color.putalpha(image.getchannel("A").point(lambda value: round(value * 0.16)))
        image = Image.alpha_composite(image, color)
    limit = CELL - SAFE * 2
    ratio = min(limit / max(1, image.width), limit / max(1, image.height))
    image = image.resize((max(1, round(image.width * ratio)), max(1, round(image.height * ratio))), Image.Resampling.LANCZOS)
    x = (CELL - image.width) // 2 + shift_x
    y = CELL - SAFE - image.height + shift_y
    x = min(max(SAFE, x), CELL - SAFE - image.width)
    y = min(max(SAFE, y), CELL - SAFE - image.height)
    canvas = Image.new("RGBA", (CELL, CELL))
    canvas.alpha_composite(image, (x, y))
    return canvas


def morph(a: Image.Image, b: Image.Image, amount: float, *, blur: float = 0.0) -> Image.Image:
    """Mistura premultiplicada sem escurecer nem tornar o corpo transparente."""
    array_a = np.asarray(a, dtype=np.float32) / 255.0
    array_b = np.asarray(b, dtype=np.float32) / 255.0
    alpha_a = array_a[..., 3:4]
    alpha_b = array_b[..., 3:4]
    weight_a = alpha_a * (1.0 - amount)
    weight_b = alpha_b * amount
    weight = weight_a + weight_b
    rgb = (array_a[..., :3] * weight_a + array_b[..., :3] * weight_b) / np.maximum(weight, 1e-6)
    alpha = np.maximum(alpha_a, alpha_b)
    rgba = np.concatenate((rgb, alpha), axis=2)
    frame = Image.fromarray(np.clip(rgba * 255.0, 0, 255).astype(np.uint8), mode="RGBA")
    if blur > 0.0:
        softened = frame.filter(ImageFilter.GaussianBlur(blur))
        frame = Image.blend(frame, softened, min(0.28, blur * 0.11))
    return frame


def recolor_glow(image: Image.Image, color: tuple[int, int, int], amount: float) -> Image.Image:
    alpha = image.getchannel("A")
    outer = alpha.filter(ImageFilter.GaussianBlur(9))
    glow = Image.new("RGBA", image.size, (*color, 0))
    glow.putalpha(outer.point(lambda value: round(value * amount)))
    return Image.alpha_composite(glow, image)


def build_view(atlas: Image.Image, source_offset: int, family: str, color: tuple[int, int, int], back: bool) -> list[Image.Image]:
    rest_a_raw = crop_source(atlas, source_offset + 0)
    rest_b_raw = crop_source(atlas, source_offset + 1)
    charge_raw = crop_source(atlas, source_offset + 2)
    attack_raw = crop_source(atlas, source_offset + 3)
    damage_raw = crop_source(atlas, source_offset + 4)
    victory_raw = crop_source(atlas, source_offset + 6)
    ko_raw = crop_source(atlas, source_offset + 7)
    amplitude, attack_gain, dodge_gain = FAMILY_MOTION.get(family, (1.0, 1.0, 1.0))
    facing = 1 if back else -1

    rest_a = fit(rest_a_raw)
    rest_b = fit(rest_b_raw, shift_y=-round(3 * amplitude))
    breath_high = fit(rest_a_raw, scale_x=0.992, scale_y=1.018, angle=-0.55 * amplitude, shift_y=-round(4 * amplitude))
    breath_low = fit(rest_b_raw, scale_x=1.012, scale_y=0.988, angle=0.45 * amplitude)
    idle = [
        rest_a,
        morph(rest_a, rest_b, 0.34),
        rest_b,
        morph(rest_b, breath_high, 0.55),
        breath_high,
        morph(breath_high, breath_low, 0.48),
        breath_low,
        morph(breath_low, rest_a, 0.52),
    ]

    charge = fit(charge_raw, scale_x=0.97, scale_y=1.025, shift_x=-facing * round(8 * attack_gain))
    release = fit(attack_raw, scale_x=1.035, scale_y=0.985, shift_x=facing * round(12 * attack_gain), brightness=1.05)
    release_stretch = fit(attack_raw, scale_x=1.075, scale_y=0.965, shift_x=facing * round(20 * attack_gain), brightness=1.10)
    light = [
        morph(rest_a, charge, 0.64),
        charge,
        release_stretch,
        morph(release, rest_a, 0.58),
    ]

    heavy_a = recolor_glow(fit(charge_raw, scale_x=1.035, scale_y=0.945, tint=color), color, 0.12)
    heavy_b = recolor_glow(fit(charge_raw, scale_x=0.96, scale_y=1.055, shift_y=-6, brightness=1.08, tint=color), color, 0.20)
    heavy_c = recolor_glow(morph(heavy_a, heavy_b, 0.62), color, 0.26)
    heavy_release = recolor_glow(morph(heavy_b, release, 0.55, blur=0.6), color, 0.22)
    heavy_impact = recolor_glow(fit(attack_raw, scale_x=1.095, scale_y=1.015, shift_x=facing * round(22 * attack_gain), brightness=1.16), color, 0.30)
    heavy_recover = morph(release, rest_a, 0.62)
    heavy = [heavy_a, heavy_c, heavy_b, heavy_release, heavy_impact, heavy_recover]

    hurt_contact = fit(damage_raw, angle=-facing * 2.2, tint=(255, 76, 88), brightness=1.12)
    hurt_recoil = fit(damage_raw, scale_x=1.045, scale_y=0.94, angle=-facing * 5.5, shift_x=-facing * 14, tint=(255, 76, 88))
    hurt = [hurt_contact, hurt_recoil, morph(hurt_recoil, rest_a, 0.68)]

    # Esquiva nasce de pose ereta. Nunca reutiliza o quadro de KO/queda.
    dodge_ready_left = fit(rest_a_raw, angle=2.2 * dodge_gain, shift_x=10)
    dodge_far_left = fit(charge_raw, scale_x=0.94, scale_y=1.025, angle=7.0 * dodge_gain, shift_x=-round(34 * dodge_gain))
    dodge_left = [dodge_ready_left, dodge_far_left, morph(dodge_far_left, rest_a, 0.58)]
    dodge_ready_right = fit(rest_a_raw, angle=-2.2 * dodge_gain, shift_x=-10)
    dodge_far_right = fit(charge_raw, scale_x=0.94, scale_y=1.025, angle=-7.0 * dodge_gain, shift_x=round(34 * dodge_gain))
    dodge_right = [dodge_ready_right, dodge_far_right, morph(dodge_far_right, rest_a, 0.58)]

    victory_a = fit(victory_raw, scale_y=1.035, shift_y=-6, brightness=1.08)
    victory_b = fit(victory_raw, scale_x=1.035, scale_y=0.985, angle=1.2 * amplitude)
    ko_a = morph(hurt_recoil, fit(ko_raw, brightness=0.86), 0.58)
    ko_b = fit(ko_raw, scale_x=1.035, scale_y=0.96, shift_y=7, brightness=0.72)
    guard = fit(charge_raw, scale_x=1.025, scale_y=0.975, tint=(89, 215, 255), brightness=1.06)
    frames = idle + light + heavy + hurt + dodge_left + dodge_right + [victory_a, victory_b, ko_a, ko_b, guard]
    if len(frames) != 32:
        raise RuntimeError(f"sequencia invalida: {len(frames)}")
    return frames


def validate_cell(frame: Image.Image, creature_id: str, index: int) -> None:
    bbox = frame.getchannel("A").point(lambda value: 255 if value > 3 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"{creature_id}: quadro vazio {index}")
    left, top, right, bottom = bbox
    if left < SAFE or top < SAFE or right > CELL - SAFE or bottom > CELL - SAFE:
        raise RuntimeError(f"{creature_id}: quadro {index} fora da area segura: {bbox}")


def enforce_safe(frame: Image.Image) -> Image.Image:
    """Recorta inclusive o halo para impedir amostragem da celula vizinha."""
    alpha = np.asarray(frame.getchannel("A"), dtype=np.uint8).copy()
    alpha[:SAFE, :] = 0
    alpha[CELL - SAFE:, :] = 0
    alpha[:, :SAFE] = 0
    alpha[:, CELL - SAFE:] = 0
    result = frame.copy()
    result.putalpha(Image.fromarray(alpha, mode="L"))
    return result


def save_atlas(creature: dict) -> None:
    creature_id = creature["id"]
    source = source_atlas(creature_id)
    family = FAMILY_BY_ID.get(creature_id, "standard")
    color = ELEMENT_COLORS[creature["type"]]
    # Fonte 04e80a2: 0..7 costas, 8..15 frente.
    frames = build_view(source, 0, family, color, True) + build_view(source, 8, family, color, False)
    atlas = Image.new("RGBA", (COLS * CELL, ROWS * CELL))
    for index, original in enumerate(frames):
        frame = enforce_safe(original)
        validate_cell(frame, creature_id, index)
        atlas.alpha_composite(frame, ((index % COLS) * CELL, (index // COLS) * CELL))

    target = ROOT / "assets" / "sprites_combat" / f"{creature_id}.png"
    temp = target.with_suffix(".png.tmp")
    atlas.save(temp, format="PNG", compress_level=7, optimize=False)
    with Image.open(temp) as check:
        check.load()
        if check.size != (3072, 3072) or check.mode != "RGBA":
            raise RuntimeError(f"atlas invalido: {creature_id}")
    temp.replace(target)

    poses = []
    for index in range(64):
        poses.append({
            "name": ("back" if index < 32 else "front") + f"_frame_{index % 32:02d}",
            "index": index,
            "rect": [(index % COLS) * CELL, (index // COLS) * CELL, CELL, CELL],
            "anchor": [0.5, 1.0],
        })
    manifest = {
        "version": 4,
        "id": creature_id,
        "atlas": f"res://assets/sprites_combat/{creature_id}.png",
        "size": [COLS * CELL, ROWS * CELL],
        "rows": ROWS,
        "columns": COLS,
        "cell": [CELL, CELL],
        "safe_margin": SAFE,
        "views": {"back": [0, 32], "front": [32, 64]},
        "sequences": {
            name: {"start": start, "end": end, "fps": fps, "loop": loop}
            for name, (start, end, fps, loop) in SEQUENCES.items()
        },
        "poses": poses,
    }
    (target.parent / f"{creature_id}.poses.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    catalog = json.loads((ROOT / "data" / "creatures.json").read_text(encoding="utf-8"))
    for number, creature in enumerate(catalog["creatures"], start=1):
        save_atlas(creature)
        print(f"[{number:02d}/30] {creature['id']}")
    print("Atlas V4: 30 Beasts, 1.920 quadros, grade 8x8, margem segura 28 px.")


if __name__ == "__main__":
    main()
