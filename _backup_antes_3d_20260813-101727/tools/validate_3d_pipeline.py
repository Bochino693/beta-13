#!/usr/bin/env python3
"""Valida o contrato 3D, as três posições e os 80 poderes animados."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def load_json(relative: str) -> dict:
    return json.loads((ROOT / relative).read_text(encoding="utf-8"))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--release",
        action="store_true",
        help="Exige os 30 modelos GLB finais e status ready.",
    )
    args = parser.parse_args()

    creatures = load_json("data/creatures.json")["creatures"]
    moves = load_json("data/moves.json")["moves"]
    manifest = load_json("data/beast_3d_manifest.json")
    battle = (ROOT / "scripts/scenes/battle.gd").read_text(encoding="utf-8")
    combatant = (ROOT / "scripts/components/beast_combatant_3d.gd").read_text(
        encoding="utf-8"
    )
    arena_source = (ROOT / "scripts/components/battle_arena_3d.gd").read_text(
        encoding="utf-8"
    )
    projectile_source = (ROOT / "scripts/components/move_projectile_3d.gd").read_text(
        encoding="utf-8"
    )
    runtime_3d = "\n".join((battle, combatant, arena_source, projectile_source))
    errors: list[str] = []
    warnings: list[str] = []

    creature_ids = {item["id"] for item in creatures}
    manifest_items = {item["id"]: item for item in manifest.get("beasts", [])}
    if set(manifest_items) != creature_ids:
        missing = sorted(creature_ids - set(manifest_items))
        extra = sorted(set(manifest_items) - creature_ids)
        errors.append(f"Manifesto 3D divergente. Faltando={missing}; extras={extra}")

    expected_animations = {
        "Idle", "AttackLight", "AttackHeavy", "Hit", "Win", "KO",
        "DodgeLeft", "DodgeRight",
    }
    configured_animations = set(manifest.get("model_contract", {}).get("animations", []))
    if configured_animations != expected_animations:
        errors.append("Contrato de animações 3D incompleto ou divergente.")
    if manifest.get("model_contract", {}).get("markers") != [
        "FX_Origin", "Hit_Target"
    ]:
        errors.append("Contrato dos marcadores FX_Origin/Hit_Target divergente.")

    final_models = 0
    for creature_id, item in manifest_items.items():
        expected = f"res://assets/models/beasts/{creature_id}/{creature_id}.glb"
        if item.get("model") != expected:
            errors.append(f"{creature_id}: caminho deve ser {expected}.")
        model_path = ROOT / expected.removeprefix("res://")
        ready = item.get("status") == "ready"
        if model_path.is_file() and model_path.stat().st_size > 0:
            final_models += 1
        elif ready:
            errors.append(f"{creature_id}: marcado ready, mas GLB não existe.")
        elif args.release:
            errors.append(f"{creature_id}: modelo final ausente.")

    forbidden_in_battle = (
        "CreatureAvatar", "ElementSkillFX", "BeastRig3D",
        "assets/creatures_hd", "assets/sprites/beasts",
    )
    for forbidden in forbidden_in_battle:
        if forbidden in battle:
            errors.append(f"Batalha 3D ainda referencia solução plana: {forbidden}")

    required_in_battle = (
        "BeastCombatant3D", "MoveProjectile3D", "BattleArena3D",
        "_dodge_locked_lane", "DODGE_DAMAGE", "for lane in 3",
    )
    for required in required_in_battle:
        if required not in runtime_3d:
            errors.append(f"Contrato de batalha ausente: {required}")

    if "MODEL_ROOT" not in combatant or "PackedScene" not in combatant:
        errors.append("O combatente não carrega modelos GLB como PackedScene.")
    if "assets/creatures_hd" in combatant or "Sprite3D" in combatant:
        errors.append("O corpo da Beast 3D não pode usar retrato/billboard.")

    for move in moves:
        expected_sheet = ROOT / move["sprite_sheet"].removeprefix("res://")
        if not expected_sheet.is_file():
            errors.append(f"{move['id']}: spritesheet ausente.")
            continue
        with Image.open(expected_sheet) as image:
            if image.height <= 0 or image.width % image.height:
                errors.append(f"{move['id']}: tira não possui quadros quadrados.")
                continue
            frames = image.width // image.height
            if frames < 4:
                errors.append(f"{move['id']}: somente {frames} quadros de poder.")

    if final_models < len(creature_ids):
        warnings.append(
            f"MODELOS FINAIS: {final_models}/{len(creature_ids)}. "
            "Proxies volumétricos ficam ativos durante a produção artística."
        )

    audio_paths = [
        ROOT / "assets/audio/stadium_ambience.wav",
        ROOT / "assets/audio/dodge.wav",
    ]
    audio_paths.extend(
        ROOT / f"assets/audio/beasts/{creature_id}_roar.wav"
        for creature_id in creature_ids
    )
    for audio_path in audio_paths:
        if not audio_path.is_file() or audio_path.stat().st_size < 1024:
            errors.append(f"Áudio 3D ausente ou vazio: {audio_path.relative_to(ROOT)}")

    print(f"Beasts no manifesto: {len(manifest_items)}")
    print(f"Poderes com spritesheet: {len(moves)}")
    print("Posições laterais: 3")
    print(f"Rugidos individuais: {len(creature_ids)}")
    for warning in warnings:
        print(f"AVISO: {warning}")
    if errors:
        for error in errors:
            print(f"ERRO: {error}")
        raise SystemExit(1)
    print("Arena, esquiva, projéteis e contrato 3D: OK")


if __name__ == "__main__":
    main()
