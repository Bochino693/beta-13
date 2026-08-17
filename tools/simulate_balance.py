#!/usr/bin/env python3
"""Simula duelos 1x1 com as mesmas curvas usadas pelo runtime do Godot."""

from __future__ import annotations

import json
import random
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CREATURES = json.loads((ROOT / "data" / "creatures.json").read_text(encoding="utf-8"))["creatures"]
MOVES = {move["id"]: move for move in json.loads((ROOT / "data" / "moves.json").read_text(encoding="utf-8"))["moves"]}

# A hierarquia vem de data/elements.json — o MESMO arquivo que o runtime lê
# em scripts/autoload/creature_db.gd. Antes esta tabela era escrita à mão
# aqui e divergia da do jogo: esta dava um alvo por elemento, a do runtime
# dava dois. O simulador aprovava um equilíbrio que não era o do jogo
# instalado.
ELEMENTS = json.loads((ROOT / "data" / "elements.json").read_text(encoding="utf-8"))
STRONG = {
    element["name"]: list(element["strong_against"]) for element in ELEMENTS["elements"]
}
MULT = ELEMENTS["multipliers"]

WEIGHT = {
    "Ultra Leve": {"cooldown": .70, "hp": 0, "damage": 1.08},
    "Leve": {"cooldown": .82, "hp": 8, "damage": 1.05},
    "Médio": {"cooldown": 1.00, "hp": 16, "damage": 1.00},
    "Pesado": {"cooldown": 1.16, "hp": 22, "damage": .96},
    "Colossal": {"cooldown": 1.30, "hp": 24, "damage": .92},
}


def type_multiplier(attack_type: str, defense_type: str) -> float:
    # Mesma ordem de decisão do runtime: a vantagem é conferida ANTES da
    # resistência, então num par recíproco (Luz/Escuridão) os dois lados
    # atacam com vantagem.
    if attack_type == defense_type:
        return MULT["same_type"]
    if defense_type in STRONG[attack_type]:
        return MULT["advantage"]
    if attack_type in STRONG[defense_type]:
        return MULT["resistance"]
    return MULT["neutral"]


def max_hp(creature: dict) -> int:
    return round(145 + creature["resistance"] * 1.55 + WEIGHT[creature["weight_class"]]["hp"])


def cooldown(move: dict, creature: dict) -> float:
    return max(.35, round(move["cooldown"] * WEIGHT[creature["weight_class"]]["cooldown"] / .05) * .05)


def damage(attacker: dict, defender: dict, move: dict) -> int:
    attack_ratio = (attacker["attack"] / max(42, defender["defense"])) ** .62
    resistance_factor = 1 - min(.17, max(.06, defender["resistance"] / 590))
    return max(6, round(move["power"] * attack_ratio * resistance_factor * type_multiplier(move["element"], defender["type"]) * WEIGHT[attacker["weight_class"]]["damage"]))


def choose_move(attacker: dict, defender: dict, cooldowns: dict[str, float], rng: random.Random) -> dict | None:
    ready = [MOVES[move_id] for move_id in attacker["moves"] if cooldowns.get(move_id, 0) <= .001]
    if not ready:
        return None
    return max(ready, key=lambda move: damage(attacker, defender, move) - cooldown(move, attacker) * 1.7 + rng.uniform(-1.8, 1.8))


def duel(first: dict, second: dict, seed: int) -> str:
    rng = random.Random(seed)
    fighters = [first, second]
    hp = [max_hp(first), max_hp(second)]
    cooldowns: list[dict[str, float]] = [{}, {}]
    turn = 0 if first["speed"] >= second["speed"] else 1
    for _ in range(120):
        actor, target = fighters[turn], fighters[1-turn]
        for move_id in list(cooldowns[turn]):
            cooldowns[turn][move_id] = max(0, cooldowns[turn][move_id] - 1)
        move = choose_move(actor, target, cooldowns[turn], rng)
        if move is None:
            turn = 1 - turn
            continue
        cooldowns[turn][move["id"]] = cooldown(move, actor)
        hp[1-turn] -= max(5, damage(actor, target, move) + rng.randint(-2, 2))
        if hp[1-turn] <= 0:
            return actor["id"]
        turn = 1 - turn
    return fighters[0 if hp[0] >= hp[1] else 1]["id"]


def main() -> None:
    wins = defaultdict(int)
    matches = defaultdict(int)
    class_wins = defaultdict(int)
    class_matches = defaultdict(int)
    rounds_per_pair = 20
    for left_index, left in enumerate(CREATURES):
        for right_index in range(left_index + 1, len(CREATURES)):
            right = CREATURES[right_index]
            for repeat in range(rounds_per_pair):
                first, second = (left, right) if repeat % 2 == 0 else (right, left)
                winner = duel(first, second, left_index * 100000 + right_index * 1000 + repeat)
                for creature in (left, right):
                    matches[creature["id"]] += 1
                    class_matches[creature["weight_class"]] += 1
                wins[winner] += 1
                winner_class = left["weight_class"] if winner == left["id"] else right["weight_class"]
                class_wins[winner_class] += 1

    rates = [(wins[c["id"]] / matches[c["id"]], c) for c in CREATURES]
    rates.sort(key=lambda item: item[0])
    print(f"Duelos simulados: {sum(wins.values())} | repetições por confronto: {rounds_per_pair}")
    print("Menores:", ", ".join(f"{c['name']} {rate:.1%}" for rate, c in rates[:5]))
    print("Maiores:", ", ".join(f"{c['name']} {rate:.1%}" for rate, c in rates[-5:]))
    print("Classes:")
    for weight_class in WEIGHT:
        print(f"  {weight_class:11s} {class_wins[weight_class] / class_matches[weight_class]:.1%}")
    spread = rates[-1][0] - rates[0][0]
    if rates[0][0] < .24 or rates[-1][0] > .76 or spread > .50:
        raise SystemExit("ERRO: curva fora do limite competitivo definido.")
    print("Equilíbrio competitivo: OK")


if __name__ == "__main__":
    main()
