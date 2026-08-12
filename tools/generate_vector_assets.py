#!/usr/bin/env python3
"""Gera os SVGs e materiais importados pelo Godot a partir do catálogo."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "data" / "creatures.json"
TYPES = ROOT / "assets" / "types"
ACTIONS = ROOT / "assets" / "actions"
MATERIALS = ROOT / "assets" / "materials" / "creatures"


TYPE_SLUGS = {
    "Luz": "luz",
    "Escuridão": "escuridao",
    "Fogo": "fogo",
    "Choque": "choque",
    "Terra": "terra",
    "Água": "agua",
    "Natureza": "natureza",
    "Vento": "vento",
}


def rgba(hex_color: str, alpha: float = 1.0) -> str:
    value = hex_color.lstrip("#")
    red, green, blue = (int(value[index:index + 2], 16) / 255 for index in (0, 2, 4))
    return f"Color({red:.6f}, {green:.6f}, {blue:.6f}, {alpha:.6f})"


def symbol(type_name: str, color: str = "#ffffff") -> str:
    common = f'fill="{color}" stroke="{color}" stroke-linecap="round" stroke-linejoin="round"'
    symbols = {
        "Luz": f'<path d="M0-31L8-10L30-8L13 6L19 29L0 16L-19 29L-13 6L-30-8L-8-10Z" {common}/><circle cx="0" cy="0" r="6" fill="#ffffff"/>',
        "Escuridão": f'<path d="M17-28C-2-21-8 2 4 16C12 25 24 25 31 21C21 34-1 35-16 19C-33 1-22-25 1-31C7-33 13-32 17-28Z" {common}/>',
        "Fogo": f'<path d="M0 29C-20 14-23-4-8-22C-8-8 1-7 5-26C23-9 27 12 10 28C7 14-1 11-3 1C-13 13-9 23 0 29Z" {common}/>',
        "Choque": f'<path d="M7-31L-21 7H-3L-10 31L23-12H5Z" {common}/>',
        "Terra": f'<path d="M-25 17L-20-15L-5-29L21-17L29 12L11 29L-14 27Z" {common}/>',
        "Água": f'<path d="M0-29C-4-16-22 0-22 13A22 22 0 0044 0C22 0 4-16 0-29Z" {common}/>',
        "Natureza": f'<path d="M-29 17C-25-17 2-30 29-25C25 7 7 29-24 25C-10 16 3 5 17-13C-3 2-16 14-29 17Z" {common}/>',
        "Vento": f'<g fill="none" stroke="{color}" stroke-width="7" stroke-linecap="round"><path d="M-28-12H10C28-12 27-29 13-29C5-29 1-25-1-20"/><path d="M-29 3H21C35 3 34 20 21 20C15 20 11 17 9 13"/><path d="M-25 18H-3"/></g>',
    }
    return symbols[type_name]


def body_shape(shape: int, body: str, accent: str, detail: str) -> str:
    if shape == 0:
        return f'<ellipse cx="160" cy="188" rx="70" ry="77" fill="url(#body)" stroke="{detail}" stroke-width="7"/>'
    if shape == 1:
        return f'<path d="M74 193C78 136 113 112 170 118C224 123 250 161 239 213C230 256 198 276 143 268C96 262 68 235 74 193Z" fill="url(#body)" stroke="{detail}" stroke-width="7"/>'
    if shape == 2:
        return f'<path d="M69 204C69 142 104 108 160 108C218 108 254 143 252 211C250 270 212 292 159 287C103 291 68 263 69 204Z" fill="url(#body)" stroke="{detail}" stroke-width="8"/>'
    return f'<path d="M91 128L222 125L255 188L226 273L100 278L65 210Z" fill="url(#body)" stroke="{detail}" stroke-width="8"/><path d="M113 147H202L220 204L197 252H116L94 202Z" fill="{accent}" opacity=".28"/>'


def creature_svg(creature: dict) -> str:
    body = creature["body"]
    accent = creature["accent"]
    detail = creature["detail"]
    seed = int(creature["seed"])
    horns = int(creature["horns"])
    tail = int(creature["tail"])
    wings = bool(creature["wings"])
    shape = int(creature["shape"])
    eye_offset = (seed % 7) - 3
    mark_x = 125 + seed % 54
    tail_side = -1 if seed % 2 else 1

    head_x = 221 if shape == 1 else 160
    head_y = 151 if shape == 1 else (101 if shape == 2 else 111)
    emblem_x = 150 if shape == 1 else 160
    emblem_y = 207 if shape != 3 else 212

    appendages = []
    if tail:
        start_x = 94 if shape == 1 else (111 if tail_side < 0 else 209)
        end_x = 35 if tail_side < 0 or shape == 1 else 285
        control_x = 15 if end_x < 160 else 305
        end_y = 128 - tail * 13
        appendages.append(f'<path d="M{start_x} 211C{70 if end_x < 160 else 250} 220 {control_x} 180 {end_x} {end_y}" fill="none" stroke="{detail}" stroke-width="{16 + tail * 3}" stroke-linecap="round"/>')
        if tail == 1:
            appendages.append(f'<circle cx="{end_x}" cy="{end_y}" r="14" fill="{accent}" stroke="{detail}" stroke-width="5"/>')
        elif tail == 2:
            appendages.append(f'<path d="M{end_x - 16} {end_y - 4}L{end_x} {end_y - 28}L{end_x + 17} {end_y + 5}Z" fill="{accent}" stroke="{detail}" stroke-width="5"/>')
        else:
            appendages.append(f'<path d="M{end_x - 20} {end_y}L{end_x - 8} {end_y - 22}L{end_x + 5} {end_y - 8}L{end_x + 23} {end_y - 27}L{end_x + 18} {end_y + 10}Z" fill="{accent}" stroke="{detail}" stroke-width="5"/>')
    if wings:
        wing_top = 57 if shape == 1 else 72
        appendages.append(
            f'<path d="M112 158L27 {wing_top}L42 189L102 224Z" fill="{accent}" opacity=".9" stroke="{detail}" stroke-width="7"/>'
            f'<path d="M205 155L293 {wing_top}L275 194L211 224Z" fill="{accent}" opacity=".9" stroke="{detail}" stroke-width="7"/>'
            f'<path d="M48 {wing_top + 25}L92 176M272 {wing_top + 25}L226 176" stroke="#ffffff" opacity=".48" stroke-width="5"/>'
        )

    horn_parts = []
    if horns >= 1:
        horn_parts.append(f'<path d="M{head_x - 17} {head_y - 17}L{head_x} {head_y - 72}L{head_x + 17} {head_y - 17}Z" fill="{accent}" stroke="{detail}" stroke-width="6"/>')
    if horns >= 2:
        horn_parts.append(f'<path d="M{head_x - 41} {head_y - 7}L{head_x - 77} {head_y - 52}L{head_x - 30} {head_y - 27}ZM{head_x + 41} {head_y - 7}L{head_x + 77} {head_y - 52}L{head_x + 30} {head_y - 27}Z" fill="{detail}" stroke="{accent}" stroke-width="5"/>')
    if horns >= 3:
        horn_parts.append(f'<path d="M{head_x - 52} {head_y - 38}Q{head_x} {head_y - 82} {head_x + 52} {head_y - 38}" fill="none" stroke="{accent}" stroke-width="10" stroke-linecap="round"/>')

    if shape == 1:
        legs = f'<path d="M103 230L91 285M139 238L137 288M193 237L202 287M225 224L244 284" stroke="{detail}" stroke-width="19" stroke-linecap="round"/><path d="M75 289H108M121 292H153M186 291H218M226 288H260" stroke="{accent}" stroke-width="13" stroke-linecap="round"/>'
    else:
        legs = f'<path d="M105 237L99 289M215 237L221 289" stroke="{detail}" stroke-width="28" stroke-linecap="round"/><ellipse cx="99" cy="291" rx="31" ry="12" fill="{accent}" stroke="{detail}" stroke-width="5"/><ellipse cx="221" cy="291" rx="31" ry="12" fill="{accent}" stroke="{detail}" stroke-width="5"/>'

    arms = ""
    if shape != 1:
        arm_y = 183 if shape == 2 else 193
        hands = 18 if shape == 2 else 14
        arms = (
            f'<path d="M103 {arm_y}Q60 {arm_y + 4} 48 {arm_y - 42}" fill="none" stroke="{body}" stroke-width="25"/>'
            f'<path d="M217 {arm_y}Q260 {arm_y + 4} 272 {arm_y - 42}" fill="none" stroke="{body}" stroke-width="25"/>'
            f'<circle cx="48" cy="{arm_y - 42}" r="{hands}" fill="{accent}" stroke="{detail}" stroke-width="5"/>'
            f'<circle cx="272" cy="{arm_y - 42}" r="{hands}" fill="{accent}" stroke="{detail}" stroke-width="5"/>'
        )

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="320" height="320" viewBox="0 0 320 320">
  <title>{creature['name']} — {creature['title']}</title>
  <defs>
    <linearGradient id="body" x1="0" y1="0" x2="1" y2="1"><stop stop-color="{accent}"/><stop offset=".38" stop-color="{body}"/><stop offset="1" stop-color="{detail}"/></linearGradient>
    <radialGradient id="shine"><stop stop-color="#ffffff" stop-opacity=".9"/><stop offset="1" stop-color="{accent}" stop-opacity="0"/></radialGradient>
  </defs>
  <g stroke-linecap="round" stroke-linejoin="round">
    {''.join(appendages)}
    {legs}
    {arms}
    {body_shape(shape, body, accent, detail)}
    <ellipse cx="{mark_x}" cy="205" rx="23" ry="34" fill="{accent}" opacity=".34" transform="rotate({seed % 47 - 23} {mark_x} 205)"/>
    <circle cx="{205 - seed % 36}" cy="229" r="{8 + seed % 9}" fill="{detail}" opacity=".68"/>
    <ellipse cx="{head_x}" cy="{head_y}" rx="{59 if shape == 1 else 64}" ry="{48 if shape == 1 else 56}" fill="{body}" stroke="{detail}" stroke-width="7"/>
    {''.join(horn_parts)}
    <ellipse cx="{head_x - 27}" cy="{head_y - 4}" rx="14" ry="18" fill="#f9ffff" stroke="{detail}" stroke-width="4"/>
    <ellipse cx="{head_x + 27}" cy="{head_y - 4}" rx="14" ry="18" fill="#f9ffff" stroke="{detail}" stroke-width="4"/>
    <circle cx="{head_x - 24 + eye_offset}" cy="{head_y}" r="7" fill="{detail}"/><circle cx="{head_x + 30 + eye_offset}" cy="{head_y}" r="7" fill="{detail}"/>
    <circle cx="{head_x - 22 + eye_offset}" cy="{head_y - 4}" r="2.5" fill="#ffffff"/><circle cx="{head_x + 32 + eye_offset}" cy="{head_y - 4}" r="2.5" fill="#ffffff"/>
    <path d="M{head_x - 17} {head_y + 28}Q{head_x} {head_y + 41 + seed % 8} {head_x + 18} {head_y + 27}" fill="none" stroke="{detail}" stroke-width="6"/>
    <g transform="translate({emblem_x} {emblem_y}) scale(.62)">{symbol(creature['type'], '#ffffff')}</g>
    <ellipse cx="{head_x - 38}" cy="{head_y - 30}" rx="38" ry="25" fill="url(#shine)" opacity=".34"/>
  </g>
</svg>
'''


def type_svg(type_name: str, color: str) -> str:
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs><radialGradient id="g"><stop stop-color="#ffffff"/><stop offset=".16" stop-color="{color}"/><stop offset="1" stop-color="#081128"/></radialGradient></defs>
  <circle cx="64" cy="64" r="58" fill="url(#g)" stroke="{color}" stroke-width="7"/>
  <g transform="translate(64 64) scale(1.45)">{symbol(type_name)}</g>
</svg>
'''


def action_svgs() -> dict[str, str]:
    wrapper = lambda color, content: f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><circle cx="64" cy="64" r="56" fill="#0a1431" stroke="{color}" stroke-width="7"/>{content}</svg>'''
    return {
        "attack.svg": wrapper("#ff744d", '<path d="M25 83L88 20L108 40L45 103L19 109Z" fill="#ff744d"/><path d="M70 29L99 58M29 78L50 99" stroke="#ffffff" stroke-width="8"/>'),
        "special.svg": wrapper("#bf6cff", '<path d="M64 14L75 48L111 48L82 69L93 104L64 83L35 104L46 69L17 48L53 48Z" fill="#bf6cff"/><circle cx="64" cy="63" r="13" fill="#ffffff"/>'),
        "guard.svg": wrapper("#59d7ff", '<path d="M64 18L105 34V62C105 87 88 105 64 113C40 105 23 87 23 62V34Z" fill="#59d7ff"/><path d="M64 33V96M40 57H88" stroke="#ffffff" stroke-width="8"/>'),
        "switch.svg": wrapper("#59e98b", '<path d="M22 46H91L76 29M106 82H37L52 99" fill="none" stroke="#59e98b" stroke-width="13" stroke-linecap="round" stroke-linejoin="round"/><circle cx="27" cy="46" r="7" fill="#ffffff"/><circle cx="101" cy="82" r="7" fill="#ffffff"/>'),
    }


def material_text(creature: dict) -> str:
    pulse_speed = 0.75 + (int(creature["seed"]) % 9) * 0.08
    return f'''[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n[ext_resource type="Shader" path="res://assets/materials/creature_fx.gdshader" id="1_fx"]\n\n[resource]\nshader = ExtResource("1_fx")\nshader_parameter/hit_flash = 0.0\nshader_parameter/aura_strength = 0.0\nshader_parameter/aura_color = {rgba(creature['accent'], .92)}\nshader_parameter/pulse_speed = {pulse_speed:.3f}\n'''


def main() -> None:
    for directory in (TYPES, ACTIONS, MATERIALS):
        directory.mkdir(parents=True, exist_ok=True)

    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))["creatures"]
    valid_ids = {creature["id"] for creature in catalog}
    for existing in MATERIALS.glob("*.tres"):
        if existing.stem not in valid_ids:
            existing.unlink()
    valid_type_slugs = set(TYPE_SLUGS.values())
    for existing in TYPES.glob("*.svg"):
        if existing.stem not in valid_type_slugs:
            existing.unlink()
    type_colors = {}
    for creature in catalog:
        type_colors.setdefault(creature["type"], creature["body"])
        (MATERIALS / f"{creature['id']}.tres").write_text(material_text(creature), encoding="utf-8")

    for type_name, slug in TYPE_SLUGS.items():
        (TYPES / f"{slug}.svg").write_text(type_svg(type_name, type_colors[type_name]), encoding="utf-8")

    for filename, contents in action_svgs().items():
        (ACTIONS / filename).write_text(contents, encoding="utf-8")

    print(f"Gerados: {len(TYPE_SLUGS)} tipos, 4 ações e {len(catalog)} materiais. Beasts usam somente PNG HD.")


if __name__ == "__main__":
    main()
