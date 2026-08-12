#!/usr/bin/env python3
"""Gera spritesheets 2.5D, ícones, golpes animados e cartas físicas."""

from __future__ import annotations

import colorsys
import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CREATURES = json.loads((ROOT / "data" / "creatures.json").read_text(encoding="utf-8"))["creatures"]
MOVES = json.loads((ROOT / "data" / "moves.json").read_text(encoding="utf-8"))["moves"]
SPRITES = ROOT / "assets" / "sprites" / "beasts"
TYPE_ICONS = ROOT / "assets" / "type_icons"
MOVE_ICONS = ROOT / "assets" / "move_icons"
MOVE_FX = ROOT / "assets" / "moves_fx"
CARDS = ROOT / "assets" / "cards"

FRAME = 320
TYPE_SLUG = {
    "Luz": "luz", "Escuridão": "escuridao", "Fogo": "fogo", "Choque": "choque",
    "Terra": "terra", "Água": "agua", "Natureza": "natureza", "Vento": "vento",
}
TYPE_COLOR = {
    "Luz": "#FFE477", "Escuridão": "#A856FF", "Fogo": "#FF5733", "Choque": "#FFDB32",
    "Terra": "#C58B52", "Água": "#27BCFF", "Natureza": "#50D35A", "Vento": "#9CF4E8",
}


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) for index in (0, 2, 4))


def fit_creature(source: Image.Image, max_size: int = 254) -> Image.Image:
    alpha = source.getchannel("A")
    box = alpha.getbbox()
    if box:
        source = source.crop(box)
    source.thumbnail((max_size, max_size), Image.Resampling.LANCZOS)
    return source


def tint_alpha(alpha: Image.Image, color: tuple[int, int, int], opacity: int = 255) -> Image.Image:
    layer = Image.new("RGBA", alpha.size, (*color, opacity))
    layer.putalpha(alpha.point(lambda value: value * opacity // 255))
    return layer


def state_frame(source: Image.Image, frame_index: int, accent: tuple[int, int, int]) -> Image.Image:
    canvas = Image.new("RGBA", (FRAME, FRAME), (0, 0, 0, 0))
    state = frame_index // 4
    phase = frame_index % 4
    rotations = [[-1.2, 0.0, 1.2, 0.0], [-5.0, -9.0, 7.0, 2.0], [-7.0, 5.0, -3.0, 0.0], [-4.0, 4.0, -2.0, 16.0]]
    scales = [[(1.00, .98), (1.01, 1.00), (1.00, 1.02), (.99, 1.00)],
              [(.94, 1.03), (.90, 1.08), (1.10, .94), (1.03, .98)],
              [(1.08, .91), (.94, 1.08), (1.05, .94), (1.00, 1.00)],
              [(.96, 1.04), (1.04, .96), (.98, 1.02), (.90, .84)]]
    offsets = [[(0, 7), (0, 2), (0, -3), (0, 2)],
               [(-10, 5), (-18, 6), (30, -2), (13, 2)],
               [(-25, 8), (18, 4), (-12, 10), (0, 5)],
               [(0, -20), (0, -36), (0, -14), (18, 30)]]
    sx, sy = scales[state][phase]
    resized = source.resize((max(1, round(source.width * sx)), max(1, round(source.height * sy))), Image.Resampling.LANCZOS)
    resized = resized.rotate(rotations[state][phase], Image.Resampling.BICUBIC, expand=True)
    if state == 2 and phase in (0, 2):
        white = Image.new("RGBA", resized.size, (255, 255, 255, 0))
        white.putalpha(resized.getchannel("A"))
        resized = Image.blend(resized, white, 0.55)
    if state == 3 and phase == 3:
        resized = ImageEnhance.Color(resized).enhance(0.25)
        resized = ImageEnhance.Brightness(resized).enhance(0.55)
    alpha = resized.getchannel("A")
    if state in (1, 3) and phase in (1, 2):
        glow_alpha = alpha.filter(ImageFilter.GaussianBlur(12))
        glow = tint_alpha(glow_alpha, accent, 155)
        gx = (FRAME - glow.width) // 2 + offsets[state][phase][0]
        gy = FRAME - glow.height - 17 + offsets[state][phase][1]
        canvas.alpha_composite(glow, (gx, gy))
    x = (FRAME - resized.width) // 2 + offsets[state][phase][0]
    y = FRAME - resized.height - 17 + offsets[state][phase][1]
    canvas.alpha_composite(resized, (x, y))
    return canvas


def generate_beast_sheets() -> None:
    SPRITES.mkdir(parents=True, exist_ok=True)
    for creature in CREATURES:
        source = Image.open(ROOT / "assets" / "creatures_hd" / f"{creature['id']}.png").convert("RGBA")
        source = fit_creature(source)
        accent = hex_rgb(creature["accent"])
        sheet = Image.new("RGBA", (FRAME * 4, FRAME * 4), (0, 0, 0, 0))
        for index in range(16):
            sheet.alpha_composite(state_frame(source, index, accent), ((index % 4) * FRAME, (index // 4) * FRAME))
        sheet.save(SPRITES / f"{creature['id']}.png", compress_level=6)


def star_points(center: tuple[float, float], outer: float, inner: float, count: int = 8) -> list[tuple[float, float]]:
    points = []
    for index in range(count * 2):
        radius = outer if index % 2 == 0 else inner
        angle = -math.pi / 2 + math.pi * index / count
        points.append((center[0] + math.cos(angle) * radius, center[1] + math.sin(angle) * radius))
    return points


def draw_element_symbol(draw: ImageDraw.ImageDraw, element: str, center: tuple[int, int], radius: int, color=(255, 255, 255, 255), width: int = 10) -> None:
    x, y = center
    if element == "Luz":
        draw.polygon(star_points(center, radius, radius * .42), fill=color)
    elif element == "Escuridão":
        draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
        draw.ellipse((x-radius*.25, y-radius*1.05, x+radius*1.10, y+radius*.72), fill=(24, 21, 54, 255))
    elif element == "Fogo":
        flame = [(x, y-radius), (x+radius*.42, y-radius*.15), (x+radius*.18, y+radius), (x, y+radius*.55), (x-radius*.25, y+radius), (x-radius*.55, y+radius*.05)]
        draw.polygon(flame, fill=color)
        draw.ellipse((x-radius*.20, y, x+radius*.22, y+radius*.70), fill=(255, 211, 72, 255))
    elif element == "Choque":
        bolt = [(x+radius*.18, y-radius), (x-radius*.58, y+radius*.12), (x-radius*.05, y+radius*.08), (x-radius*.30, y+radius), (x+radius*.66, y-radius*.22), (x+radius*.12, y-radius*.18)]
        draw.polygon(bolt, fill=color)
    elif element == "Terra":
        draw.polygon([(x-radius, y+radius*.65), (x-radius*.25, y-radius*.75), (x+radius*.12, y-radius*.20), (x+radius*.45, y-radius*.58), (x+radius, y+radius*.65)], fill=color)
        draw.line((x-radius*.72, y+radius*.18, x+radius*.75, y+radius*.18), fill=(90, 57, 34, 255), width=max(3, width//2))
    elif element == "Água":
        draw.polygon([(x, y-radius), (x+radius*.72, y+radius*.28), (x+radius*.45, y+radius*.78), (x, y+radius), (x-radius*.52, y+radius*.70), (x-radius*.68, y+radius*.20)], fill=color)
        draw.arc((x-radius*.38, y, x+radius*.35, y+radius*.68), 20, 145, fill=(172, 247, 255, 255), width=max(3, width//2))
    elif element == "Natureza":
        draw.ellipse((x-radius*.95, y-radius*.62, x+radius*.86, y+radius*.66), fill=color)
        draw.line((x-radius*.65, y+radius*.55, x+radius*.68, y-radius*.48), fill=(25, 101, 57, 255), width=width)
        draw.line((x-radius*.10, y+radius*.12, x-radius*.38, y-radius*.25), fill=(25, 101, 57, 255), width=max(3, width//2))
    else:
        for offset in (-radius*.45, 0, radius*.45):
            draw.arc((x-radius, y-radius*.72+offset, x+radius, y+radius*.35+offset), 205, 345, fill=color, width=width)


def gradient_tile(size: int, color: tuple[int, int, int]) -> Image.Image:
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = image.load()
    for y in range(size):
        for x in range(size):
            radial = max(0.0, 1.0 - math.dist((x, y), (size*.35, size*.25)) / (size*.9))
            factor = .52 + radial * .55 - y / size * .15
            px[x, y] = tuple(min(255, int(channel * factor)) for channel in color) + (255,)
    return image


def generate_type_icons() -> None:
    TYPE_ICONS.mkdir(parents=True, exist_ok=True)
    for element, value in TYPE_COLOR.items():
        rgb = hex_rgb(value)
        icon = gradient_tile(256, rgb)
        draw = ImageDraw.Draw(icon)
        draw.rounded_rectangle((7, 7, 249, 249), 46, outline=(255, 255, 255, 225), width=10)
        draw.rounded_rectangle((22, 22, 234, 234), 35, outline=(*rgb, 255), width=5)
        draw.ellipse((47, 43, 209, 205), fill=(7, 13, 35, 135), outline=(255, 255, 255, 90), width=4)
        draw_element_symbol(draw, element, (128, 124), 58, width=12)
        draw.text((128, 222), element.upper(), font=font(19, True), anchor="mm", fill=(255, 255, 255, 255), stroke_width=3, stroke_fill=(0, 0, 0, 160))
        icon.save(TYPE_ICONS / f"{TYPE_SLUG[element]}.png", compress_level=6)


def move_icon(move: dict) -> Image.Image:
    element = move["element"]
    rgb = hex_rgb(TYPE_COLOR[element])
    image = gradient_tile(160, rgb)
    draw = ImageDraw.Draw(image)
    role_color = {"rápido": (94, 247, 255), "técnico": (255, 238, 106), "controle": (113, 255, 151), "pesado": (255, 103, 92)}[move["role"]]
    draw.rounded_rectangle((5, 5, 155, 155), 30, outline=(*role_color, 255), width=7)
    draw.ellipse((30, 23, 130, 123), fill=(5, 10, 30, 145))
    draw_element_symbol(draw, element, (80, 73), 36, width=8)
    draw.rounded_rectangle((18, 121, 142, 151), 12, fill=(4, 8, 24, 220), outline=(*role_color, 255), width=2)
    draw.text((80, 136), f"{move['power']}  •  {move['slot']:02d}", font=font(17, True), anchor="mm", fill=(255, 255, 255, 255))
    return image


def generate_move_assets() -> None:
    MOVE_ICONS.mkdir(parents=True, exist_ok=True)
    MOVE_FX.mkdir(parents=True, exist_ok=True)
    for move in MOVES:
        icon = move_icon(move)
        icon.save(MOVE_ICONS / f"{move['id']}.png", compress_level=6)
        rgb = hex_rgb(TYPE_COLOR[move["element"]])
        rng = random.Random(int(hashlib.sha256(move["id"].encode()).hexdigest()[:8], 16))
        sheet = Image.new("RGBA", (192 * 8, 192), (0, 0, 0, 0))
        for frame_index in range(8):
            frame = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
            draw = ImageDraw.Draw(frame)
            progress = (frame_index + 1) / 8
            center = (96, 96)
            for particle in range(12):
                angle = particle / 12 * math.tau + frame_index * .25 + rng.random() * .25
                distance = 18 + progress * (30 + particle % 4 * 11)
                px = center[0] + math.cos(angle) * distance
                py = center[1] + math.sin(angle) * distance
                radius = max(2, int(8 - progress * 4 + particle % 3))
                draw.ellipse((px-radius, py-radius, px+radius, py+radius), fill=(*rgb, max(20, int(220 * (1-progress*.55)))))
            ring_radius = int(24 + progress * 47)
            draw.ellipse((96-ring_radius, 96-ring_radius, 96+ring_radius, 96+ring_radius), outline=(*rgb, 210), width=max(2, 8-frame_index//2))
            draw_element_symbol(draw, move["element"], center, int(34 + math.sin(progress*math.pi)*8), width=7)
            if move["role"] == "pesado":
                draw.ellipse((15, 15, 177, 177), outline=(255, 255, 255, 130), width=5)
            sheet.alpha_composite(frame, (frame_index * 192, 0))
        sheet.save(MOVE_FX / f"{move['id']}.png", compress_level=6)


def card_background(size: tuple[int, int], color: tuple[int, int, int]) -> Image.Image:
    width, height = size
    image = Image.new("RGB", size)
    pixels = image.load()
    hue, saturation, value = colorsys.rgb_to_hsv(*(channel / 255 for channel in color))
    for y in range(height):
        for x in range(width):
            light = .16 + .40 * (1-y/height) + .14 * max(0, 1-math.dist((x, y), (width*.22, height*.18))/(width*.9))
            r, g, b = colorsys.hsv_to_rgb(hue, min(1, saturation*.9), min(1, value*light*1.7))
            pixels[x, y] = (int(r*255), int(g*255), int(b*255))
    return image.convert("RGBA")


def generate_cards() -> None:
    CARDS.mkdir(parents=True, exist_ok=True)
    moves_by_id = {move["id"]: move for move in MOVES}
    try:
        import qrcode
    except ImportError:
        qrcode = None
    for number, creature in enumerate(CREATURES, start=1):
        rgb = hex_rgb(TYPE_COLOR[creature["type"]])
        card = card_background((600, 900), rgb)
        draw = ImageDraw.Draw(card)
        draw.rounded_rectangle((14, 14, 586, 886), 38, outline=(255, 255, 255, 230), width=9)
        draw.rounded_rectangle((28, 28, 572, 872), 30, outline=(*rgb, 255), width=5)
        draw.text((55, 55), f"BEAST #{number:03d}", font=font(22, True), fill=(226, 243, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        draw.text((55, 92), creature["name"], font=font(44, True), fill=(255, 255, 255), stroke_width=4, stroke_fill=(0, 0, 0))
        draw.rounded_rectangle((440, 45, 550, 155), 24, fill=(8, 14, 35, 215), outline=(255, 255, 255, 170), width=3)
        icon = Image.open(TYPE_ICONS / f"{TYPE_SLUG[creature['type']]}.png").resize((96, 96), Image.Resampling.LANCZOS)
        card.alpha_composite(icon, (447, 52))
        art = Image.open(ROOT / "assets" / "creatures_hd" / f"{creature['id']}.png").convert("RGBA")
        art = fit_creature(art, 420)
        glow = tint_alpha(art.getchannel("A").filter(ImageFilter.GaussianBlur(20)), rgb, 130)
        ax = (600-art.width)//2
        ay = 150 + (420-art.height)//2
        card.alpha_composite(glow, (ax, ay))
        card.alpha_composite(art, (ax, ay))
        draw = ImageDraw.Draw(card)
        draw.rounded_rectangle((42, 565, 558, 828), 28, fill=(5, 11, 30, 225), outline=(*rgb, 230), width=4)
        draw.text((65, 585), f"{creature['type'].upper()}  •  {creature['weight_class'].upper()}  •  {creature['weight_kg']:g} kg", font=font(19, True), fill=(*rgb, 255))
        stats = [("ATQ", creature["attack"]), ("DEF", creature["defense"]), ("RES", creature["resistance"]), ("VEL", creature["speed"])]
        for stat_index, (label, value) in enumerate(stats):
            x = 65 + (stat_index % 2) * 245
            y = 625 + (stat_index // 2) * 48
            draw.text((x, y), f"{label} {value:03d}", font=font(22, True), fill=(237, 247, 255))
        strongest = max((moves_by_id[move_id] for move_id in creature["moves"]), key=lambda item: item["power"])
        draw.text((65, 728), f"ÁPICE: {strongest['name'].upper()}  •  {strongest['power']} PODER", font=font(17, True), fill=(255, 226, 104))
        draw.text((65, 766), creature["card_code"], font=font(19, True), fill=(177, 203, 231))
        if qrcode:
            qr = qrcode.make(f"LAZERBEASTS:{creature['card_code']}:{creature['id']}").convert("RGB").resize((92, 92), Image.Resampling.NEAREST).convert("RGBA")
            card.alpha_composite(qr, (450, 750))
        draw.text((300, 855), "LAZER BEASTS • ELEMENTAL ARENA", font=font(18, True), anchor="mm", fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        card.save(CARDS / f"{creature['id']}.png", compress_level=6)


def main() -> None:
    generate_type_icons()
    generate_move_assets()
    generate_beast_sheets()
    generate_cards()
    print(f"Gerados: {len(CREATURES)} spritesheets, {len(MOVES)} ícones/FX, 8 tipos e {len(CREATURES)} cartas.")


if __name__ == "__main__":
    main()
