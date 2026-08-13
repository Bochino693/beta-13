#!/usr/bin/env python3
"""Validação estrutural completa da versão vertical 2.5D."""

from __future__ import annotations

import json
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ELEMENTS = {"Luz", "Escuridão", "Fogo", "Choque", "Terra", "Água", "Natureza", "Vento"}


def main() -> None:
    creatures = json.loads((ROOT / "data" / "creatures.json").read_text(encoding="utf-8"))["creatures"]
    moves = json.loads((ROOT / "data" / "moves.json").read_text(encoding="utf-8"))["moves"]
    moves_by_id = {move["id"]: move for move in moves}
    errors: list[str] = []

    if len(creatures) != 30:
        errors.append(f"Catálogo tem {len(creatures)} Beasts; esperado: 30.")
    if len({item["id"] for item in creatures}) != 30:
        errors.append("Há IDs repetidos entre as Beasts.")
    if len(moves) != 80 or len(moves_by_id) != 80:
        errors.append(f"Catálogo de golpes inválido: {len(moves)} entradas, {len(moves_by_id)} IDs.")
    if (ROOT / "assets" / "creatures").exists():
        errors.append("A pasta de criaturas SVG/baixa definição ainda existe no projeto.")

    project_text = (ROOT / "project.godot").read_text(encoding="utf-8")
    if "window/size/viewport_width=720" not in project_text or "window/size/viewport_height=1280" not in project_text:
        errors.append("O viewport-base precisa permanecer em 720×1280.")
    if 'renderer/rendering_method="gl_compatibility"' not in project_text:
        errors.append("O renderer GL Compatibility não está configurado.")
    if "theme/default_font_multichannel_signed_distance_field=true" in project_text:
        errors.append("MSDF global precisa ficar desativado para preservar acentos em texto pequeno.")

    for creature in creatures:
        creature_id = creature["id"]
        element = creature["type"]
        if element not in ELEMENTS:
            errors.append(f"{creature_id}: elemento inválido {element}.")
        if float(creature.get("weight_kg", 0)) <= 0 or not creature.get("weight_class"):
            errors.append(f"{creature_id}: peso/classe ausente.")
        creature_moves = creature.get("moves", [])
        if len(creature_moves) != 5 or len(set(creature_moves)) != 5:
            errors.append(f"{creature_id}: precisa ter cinco golpes diferentes.")
        heavy = 0
        primary_count = 0
        coverage_count = 0
        for move_id in creature_moves:
            move = moves_by_id.get(move_id)
            if not move:
                errors.append(f"{creature_id}: golpe inexistente {move_id}.")
                continue
            if move["element"] == element:
                primary_count += 1
            else:
                coverage_count += 1
            heavy += move["role"] == "pesado"
        if heavy != 1:
            errors.append(f"{creature_id}: deve possuir exatamente um golpe pesado; possui {heavy}.")
        if primary_count != 4 or coverage_count != 1:
            errors.append(f"{creature_id}: esperado 4 golpes primários + 1 cobertura; encontrado {primary_count}+{coverage_count}.")
        for stat in ("attack", "defense", "resistance", "speed"):
            value = int(creature[stat])
            if not 1 <= value <= 100:
                errors.append(f"{creature_id}: {stat} fora de 1..100 ({value}).")
        resources = (
            f"assets/creatures_hd/{creature_id}.png",
            f"assets/sprites/beasts/{creature_id}.png",
            f"assets/sprites_combat/{creature_id}.png",
            f"assets/materials/creatures/{creature_id}.tres",
            f"assets/cards/{creature_id}.png",
        )
        for relative in resources:
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"{creature_id}: recurso ausente ou vazio: {relative}.")
        sheet_path = ROOT / "assets" / "sprites" / "beasts" / f"{creature_id}.png"
        if sheet_path.is_file():
            try:
                with Image.open(sheet_path) as sheet:
                    if sheet.size != (1280, 1280):
                        errors.append(f"{creature_id}: spritesheet deve ser 1280×1280; encontrado {sheet.size}.")
                    sheet.verify()
            except Exception as exc:
                errors.append(f"{creature_id}: spritesheet corrompido: {exc}.")
        combat_sheet = ROOT / "assets" / "sprites_combat" / f"{creature_id}.png"
        if combat_sheet.is_file():
            try:
                with Image.open(combat_sheet) as sheet:
                    if sheet.mode != "RGBA":
                        errors.append(f"{creature_id}: atlas de combate precisa ser RGBA.")
                    if sheet.width % 4 or sheet.height % 4:
                        errors.append(f"{creature_id}: atlas de combate nao forma grade 4x4.")
                    if sheet.getchannel("A").getextrema()[0] != 0:
                        errors.append(f"{creature_id}: atlas de combate nao tem alfa transparente.")
                with Image.open(combat_sheet) as sheet:
                    sheet.verify()
            except Exception as exc:
                errors.append(f"{creature_id}: atlas de combate corrompido: {exc}.")

    for move in moves:
        if move["element"] not in ELEMENTS:
            errors.append(f"{move['id']}: elemento inválido.")
        if move["role"] == "pesado" and int(move["power"]) > 50:
            errors.append(f"{move['id']}: golpe pesado excede o teto competitivo.")
        for relative in (f"assets/move_icons/{move['id']}.png", f"assets/moves_fx/{move['id']}.png"):
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"Golpe {move['id']}: recurso ausente {relative}.")
    for element in ELEMENTS:
        element_count = sum(move["element"] == element for move in moves)
        if element_count != 10:
            errors.append(f"{element}: deveria possuir 10 golpes; possui {element_count}.")

    # Confere todos os PNGs por leitura integral, não apenas pelo cabeçalho.
    for png_path in (ROOT / "assets").rglob("*.png"):
        try:
            with Image.open(png_path) as image:
                image.verify()
        except Exception as exc:
            errors.append(f"PNG corrompido: {png_path.relative_to(ROOT)}: {exc}.")

    # Confere referências literais usadas por cenas, scripts e configuração.
    source_files = [ROOT / "project.godot", *list((ROOT / "scenes").glob("*.tscn")), *list((ROOT / "scripts").rglob("*.gd"))]
    for source_path in source_files:
        source = source_path.read_text(encoding="utf-8")
        for relative in re.findall(r'res://([^"\']+\.(?:gd|tscn|png|svg|wav|tres|json))', source):
            if "%" in relative or "{" in relative:
                continue
            if not (ROOT / relative).is_file():
                errors.append(f"Referência ausente em {source_path.relative_to(ROOT)}: res://{relative}.")

    counts = {
        "scripts": len(list((ROOT / "scripts").rglob("*.gd"))),
        "scenes": len(list((ROOT / "scenes").glob("*.tscn"))),
        "cards": len(list((ROOT / "assets" / "cards").glob("*.png"))),
        "backgrounds": len(list((ROOT / "assets" / "backgrounds").glob("*.png"))),
        "type_icons": len(list((ROOT / "assets" / "type_icons").glob("*.png"))),
    }
    expected = {"scenes": 7, "cards": 30, "backgrounds": 4, "type_icons": 8}
    for key, expected_value in expected.items():
        if counts[key] != expected_value:
            errors.append(f"Contagem de {key}: {counts[key]}; esperado {expected_value}.")
    required_scripts = {
        "scripts/scenes/battle.gd",
        "scripts/components/cinematic_beast_sprite_3d.gd",
        "scripts/components/battle_stadium_3d.gd",
        "scripts/components/battle_shield_dome_3d.gd",
    }
    for relative in required_scripts:
        if not (ROOT / relative).is_file():
            errors.append(f"Script de batalha ausente: {relative}.")

    print(f"Beasts: {len(creatures)} | Golpes: {len(moves)} | Elementos: {len({c['type'] for c in creatures})}")
    print(" | ".join(f"{key}: {value}" for key, value in counts.items()))
    if errors:
        for error in errors:
            print(f"ERRO: {error}")
        raise SystemExit(1)
    print("Catálogos, balanceamento, sprites HD, golpes, cartas e estrutura: OK")


if __name__ == "__main__":
    main()
