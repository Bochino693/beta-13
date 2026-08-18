#!/usr/bin/env python3
"""Validação estrutural completa da versão vertical 2.5D."""

from __future__ import annotations

import json
from collections import Counter
from statistics import mean
import re
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]

# A lista de elementos vem de data/elements.json — a mesma fonte que o
# runtime e o simulate_balance.py leem. Era mais uma cópia escrita à mão.
ELEMENTS = {
    entry["name"]
    for entry in json.loads(
        (ROOT / "data" / "elements.json").read_text(encoding="utf-8")
    )["elements"]
}


RARITIES = {
    entry["id"]: entry
    for entry in json.loads(
        (ROOT / "data" / "rarities.json").read_text(encoding="utf-8")
    )["rarities"]
}


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
        if creature.get("rarity") not in RARITIES:
            errors.append(f"{creature_id}: raridade inválida {creature.get('rarity')!r}.")
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
            f"assets/materials/creatures/{creature_id}.tres",
            f"assets/cards/{creature_id}.png",
        )
        for relative in resources:
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"{creature_id}: recurso ausente ou vazio: {relative}.")
        master_path = ROOT / "assets" / "creatures_hd" / f"{creature_id}.png"
        if master_path.is_file():
            try:
                with Image.open(master_path) as master:
                    master.load()
                    if master.mode != "RGBA":
                        errors.append(f"{creature_id}: arte mestre precisa ser RGBA.")
                    else:
                        alpha = master.getchannel("A")
                        if alpha.getextrema() != (0, 255):
                            errors.append(f"{creature_id}: arte mestre não possui transparência completa.")
                        bounds = alpha.getbbox()
                        if bounds is None:
                            errors.append(f"{creature_id}: arte mestre está vazia.")
                        elif bounds[0] < 2 or bounds[1] < 2 or bounds[2] > master.width - 2 or bounds[3] > master.height - 2:
                            errors.append(f"{creature_id}: arte mestre encosta na borda: {bounds}/{master.size}.")
            except Exception as exc:
                errors.append(f"{creature_id}: arte mestre corrompida: {exc}.")

    for move in moves:
        if move["element"] not in ELEMENTS:
            errors.append(f"{move['id']}: elemento inválido.")
        if move["role"] == "pesado" and int(move["power"]) > 50:
            errors.append(f"{move['id']}: golpe pesado excede o teto competitivo.")
        for relative in (f"assets/move_icons/{move['id']}.png", f"assets/moves_fx/{move['id']}.png"):
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size == 0:
                errors.append(f"Golpe {move['id']}: recurso ausente {relative}.")
        for visual_key in ("effect_family", "travel_style", "scene_reaction"):
            if not str(move.get(visual_key, "")):
                errors.append(f"Golpe {move['id']}: metadado visual ausente: {visual_key}.")
        fx_path = ROOT / "assets" / "moves_fx" / f"{move['id']}.png"
        if fx_path.is_file():
            try:
                with Image.open(fx_path) as effect:
                    effect.load()
                    if effect.mode != "RGBA" or effect.size != (1536, 192):
                        errors.append(f"{move['id']}: FX deve ser RGBA 1536×192; encontrado {effect.mode} {effect.size}.")
                    elif effect.getchannel("A").getextrema() != (0, 255):
                        errors.append(f"{move['id']}: FX sem transparência completa.")
            except Exception as exc:
                errors.append(f"{move['id']}: FX corrompido: {exc}.")
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
    # Não existe mais lista de exceção: os protótipos paralelos (battle_v2,
    # battle_ui_v2, battle_stadium_3d_v2, battle_encenacao, arena_3d_v2 e os
    # cinco shaders que só eles usavam) foram removidos. Todo script em
    # scripts/ é código vivo e tem de apontar para arquivos existentes.
    source_files = [
        ROOT / "project.godot",
        *list((ROOT / "scenes").glob("*.tscn")),
        *list((ROOT / "scripts").rglob("*.gd")),
    ]
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
        "scripts/components/beast_pose_atlas.gd",
        "scripts/components/beast_rig_3d.gd",
        "scripts/components/element_power_3d.gd",
        "scripts/components/battle_arena_3d.gd",
        "scripts/components/battle_shield_dome_3d.gd",
    }
    for relative in required_scripts:
        if not (ROOT / relative).is_file():
            errors.append(f"Script de batalha ausente: {relative}.")

    # A hierarquia elemental mora em data/elements.json e é lida tanto pelo
    # runtime quanto por simulate_balance.py. Aqui só se confere que ela está
    # bem formada: alvo inexistente quebraria a vantagem em silêncio.
    elements_file = json.loads((ROOT / "data" / "elements.json").read_text(encoding="utf-8"))
    element_names = ELEMENTS
    if len(element_names) != 8:
        errors.append(f"Hierarquia: {len(element_names)} elementos; esperado 8.")
    for entry in elements_file["elements"]:
        targets = entry["strong_against"]
        for target in targets:
            if target not in element_names:
                errors.append(
                    f"Hierarquia: {entry['name']} vence '{target}', que não é elemento."
                )
        if len(targets) != 2:
            errors.append(
                f"Hierarquia: {entry['name']} vence {len(targets)} elementos; "
                "todos devem vencer exatamente 2 para a roda fechar."
            )

    # O atlas de combate é o que põe a Beast do jogador de costas e a rival
    # de frente. Sem as duas vistas não existe leitura 3D.
    for creature in creatures:
        manifest_path = ROOT / "assets" / "sprites_combat" / f"{creature['id']}.poses.json"
        if not manifest_path.is_file():
            errors.append(f"Manifesto de poses ausente: {creature['id']}.")
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        pose_names = {pose["name"] for pose in manifest["poses"]}
        for view in ("back", "front"):
            if not any(name.startswith(f"{view}_idle") for name in pose_names):
                errors.append(f"{creature['id']}: sem poses de idle na vista {view}.")
            for state in ("damage", "guard", "ko", "victory"):
                if f"{view}_{state}" not in pose_names:
                    errors.append(f"{creature['id']}: falta {view}_{state}.")

    contagem = Counter(creature.get("rarity") for creature in creatures)
    for rarity_id, entry in RARITIES.items():
        esperado = int(entry.get("expected_count", 0))
        if contagem.get(rarity_id, 0) != esperado:
            errors.append(
                f"Raridade {rarity_id}: {contagem.get(rarity_id, 0)} Beasts; esperado {esperado}."
            )

    # Toda faixa competitiva precisa existir em algum elemento e nenhum
    # elemento pode ficar sem uma carta de topo — senao escolher elemento
    # viraria escolher raridade.
    topo = {rid for rid, e in RARITIES.items() if int(e.get("order", 0)) >= 2}
    por_elemento: dict[str, set[str]] = {}
    for creature in creatures:
        por_elemento.setdefault(creature["type"], set()).add(creature.get("rarity"))
    for element, faixas in sorted(por_elemento.items()):
        if not faixas & topo:
            errors.append(f"Elemento {element}: nenhuma Beast Épica ou Lendária.")

    # Raridade e colecao, nao poder: os totais de status nao podem subir
    # junto com a escassez, senao simulate_balance.py deixa de valer.
    def total(creature: dict) -> int:
        return sum(int(creature[k]) for k in ("attack", "defense", "resistance", "speed"))

    medias = {
        rarity_id: mean([total(c) for c in creatures if c.get("rarity") == rarity_id])
        for rarity_id in RARITIES
        if any(c.get("rarity") == rarity_id for c in creatures)
    }
    if medias and (max(medias.values()) - min(medias.values())) > 8.0:
        errors.append(
            "Raridade virou força: média de status por faixa varia "
            f"{max(medias.values()) - min(medias.values()):.1f} pontos "
            f"({ {k: round(v, 1) for k, v in medias.items()} })."
        )

    print(f"Beasts: {len(creatures)} | Golpes: {len(moves)} | Elementos: {len({c['type'] for c in creatures})}")
    print("Raridade: " + " | ".join(
        f"{rid} {contagem.get(rid, 0)} (média {medias.get(rid, 0):.0f})"
        for rid in sorted(RARITIES, key=lambda r: RARITIES[r].get("order", 0))
    ))
    print(" | ".join(f"{key}: {value}" for key, value in counts.items()))
    if errors:
        for error in errors:
            print(f"ERRO: {error}")
        raise SystemExit(1)
    print("Catálogos, balanceamento, sprites HD, golpes, cartas e estrutura: OK")


if __name__ == "__main__":
    main()
