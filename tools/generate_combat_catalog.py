#!/usr/bin/env python3
"""Gera o catálogo atômico de 80 golpes e vincula cinco a cada Beast."""

from __future__ import annotations

import json
import hashlib
import re
import unicodedata
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CREATURES_PATH = ROOT / "data" / "creatures.json"
MOVES_PATH = ROOT / "data" / "moves.json"

ELEMENT_MOVES = {
    "Luz": [
        "Faísca da Aurora", "Lança Solar", "Prisma Cortante", "Halo Pulsante",
        "Reflexo Radiante", "Chuva de Fótons", "Selo do Zênite", "Caminho de Lux",
        "Explosão Helíaca", "Julgamento Prismático",
    ],
    "Escuridão": [
        "Garra Sombria", "Névoa Voraz", "Orbe do Véu", "Passo Umbral",
        "Eclipse Breve", "Correntes Abissais", "Marca do Medo", "Vácuo Silencioso",
        "Boca do Abismo", "Noite Terminal",
    ],
    "Fogo": [
        "Brasa Veloz", "Chicote de Fagulha", "Mordida Ígnea", "Rastro de Lava",
        "Arco de Cinza", "Círculo Vulcânico", "Fôlego Rubro", "Erupção Guiada",
        "Queda Meteórica", "Coroa da Caldeira",
    ],
    "Choque": [
        "Pulso Estático", "Salto Voltaico", "Arco Azul", "Agulha de Plasma",
        "Campo de Indução", "Rede Trovejante", "Bobina Reversa", "Surto Magnético",
        "Impacto Tesla", "Tempestade de Arco",
    ],
    "Terra": [
        "Estilhaço Raso", "Garra de Arenito", "Pilar Súbito", "Onda Sísmica",
        "Casulo Mineral", "Órbita Rochosa", "Prisão de Geodo", "Fenda Ancestral",
        "Colisão Monolítica", "Despertar Fóssil",
    ],
    "Água": [
        "Gota Bala", "Chicote de Maré", "Bolha de Pressão", "Corte Corrente",
        "Espuma Vital", "Rajada de Coral", "Espiral Oceânica", "Prisão de Maré",
        "Torpedo Abissal", "Trono das Águas",
    ],
    "Natureza": [
        "Espinho Ágil", "Pólen Vivo", "Cipó Chicote", "Foice de Folha",
        "Esporos Pulsantes", "Casca Guardiã", "Enxame Verde", "Raiz Caçadora",
        "Floresta Ascendente", "Colapso Micélio",
    ],
    "Vento": [
        "Sopro Rápido", "Pena Lâmina", "Salto de Brisa", "Arco Ciclônico",
        "Passo Nuvem", "Turbina Ascendente", "Muralha de Ar", "Rasante Supersônico",
        "Olho do Furacão", "Quatro Ventos",
    ],
}

ELEMENT_META = {
    "Luz": ("luz", "#ffe477", "clarão"),
    "Escuridão": ("escuridao", "#a856ff", "vórtice"),
    "Fogo": ("fogo", "#ff5733", "chama"),
    "Choque": ("choque", "#ffdb32", "raio"),
    "Terra": ("terra", "#c58b52", "fragmento"),
    "Água": ("agua", "#27bcff", "onda"),
    "Natureza": ("natureza", "#50d35a", "folha"),
    "Vento": ("vento", "#9cf4e8", "espiral"),
}

# Papel, poder, recarga-base em turnos, custo de energia, prioridade e descrição curta.
MOVE_CURVE = [
    ("rápido", 23, 0.55, 7, 10, "Resposta imediata para manter pressão."),
    ("rápido", 26, 0.80, 9, 9, "Golpe curto com recuperação veloz."),
    ("rápido", 29, 1.05, 11, 8, "Ataque seguro para abrir combinações."),
    ("técnico", 31, 1.25, 13, 7, "Movimento preciso de risco controlado."),
    ("técnico", 33, 1.55, 15, 6, "Pressão equilibrada de alcance médio."),
    ("técnico", 35, 1.80, 17, 5, "Técnica estável para punir uma abertura."),
    ("controle", 37, 2.05, 19, 4, "Ocupa espaço e força reação do rival."),
    ("controle", 39, 2.35, 21, 3, "Golpe de controle com recarga moderada."),
    ("pesado", 45, 3.40, 27, 2, "Impacto forte, legível e com recuperação longa."),
    ("pesado", 48, 3.85, 30, 1, "Maior impacto do elemento, sem decidir a luta sozinho."),
]

WEIGHTS_KG = {
    "lumari": 8.4, "helionce": 168.0, "prismara": 32.0,
    "impavor": 22.0, "nocturna": 14.0, "abissarca": 620.0,
    "brasalam": 72.0, "vulcora": 510.0, "cinzibora": 46.0, "pyrocondor": 88.0,
    "voltalho": 18.0, "raiarraia": 34.0, "teslouro": 390.0, "arcdrake": 240.0,
    "pedrilho": 95.0, "geodrilo": 460.0, "monolito": 720.0, "fossatroz": 280.0,
    "medulux": 6.0, "crustarka": 82.0, "torpescama": 54.0, "marevante": 210.0,
    "floraphex": 12.0, "brotoxi": 31.0, "musgurso": 260.0, "arborion": 680.0,
    "brispulo": 9.0, "nimbaleia": 190.0, "ciclorn": 48.0, "tempestral": 160.0,
}

# Cada classe preserva uma identidade sem criar uma vitória automática. As
# pequenas variações determinísticas mantêm as 30 Beasts diferentes entre si.
COMBAT_PROFILES = {
    "Ultra Leve": (94, 70, 72, 100),
    "Leve": (92, 76, 77, 92),
    "Médio": (88, 82, 82, 82),
    "Pesado": (86, 88, 88, 68),
    "Colossal": (84, 92, 92, 48),
}

# Quatro golpes do elemento primário (incluindo exatamente um pesado). O
# quinto golpe é uma cobertura técnica contra um dos predadores do elemento.
PRIMARY_MOVE_INDICES = [
    [0, 3, 6, 8],
    [1, 2, 5, 9],
    [0, 4, 7, 8],
    [1, 3, 5, 9],
]

STRONG_AGAINST = {
    "Luz": ["Escuridão"],
    "Escuridão": ["Luz"],
    "Fogo": ["Natureza"],
    "Água": ["Fogo"],
    "Choque": ["Água"],
    "Vento": ["Choque"],
    "Terra": ["Vento"],
    "Natureza": ["Terra"],
}


def slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]+", "_", normalized.lower()).strip("_")


def weight_class(weight: float) -> str:
    if weight <= 15:
        return "Ultra Leve"
    if weight <= 55:
        return "Leve"
    if weight <= 160:
        return "Médio"
    if weight <= 350:
        return "Pesado"
    return "Colossal"


def balanced_stats(creature_id: str, class_name: str) -> dict[str, int]:
    base = COMBAT_PROFILES[class_name]
    digest = hashlib.sha256(creature_id.encode("utf-8")).digest()
    values = [min(100, base[index] + digest[index] % 5 - 2) for index in range(4)]
    return dict(zip(("attack", "defense", "resistance", "speed"), values))


def coverage_element(primary: str, position: int) -> str:
    predators = [element for element, targets in STRONG_AGAINST.items() if primary in targets]
    predator = predators[position % len(predators)]
    counters = [element for element, targets in STRONG_AGAINST.items() if predator in targets and element != primary]
    return counters[position % len(counters)] if counters else primary


def build_moves() -> list[dict]:
    result: list[dict] = []
    for element, names in ELEMENT_MOVES.items():
        element_slug, color, visual = ELEMENT_META[element]
        for index, name in enumerate(names):
            role, power, cooldown, energy, priority, objective = MOVE_CURVE[index]
            result.append({
                "id": f"{element_slug}_{index + 1:02d}_{slug(name)}",
                "name": name,
                "element": element,
                "slot": index + 1,
                "role": role,
                "power": power,
                "cooldown": cooldown,
                "energy_cost": energy,
                "priority": priority,
                "color": color,
                "visual": visual,
                "objective": objective,
                "icon": f"res://assets/move_icons/{element_slug}_{index + 1:02d}_{slug(name)}.png",
                "sprite_sheet": f"res://assets/moves_fx/{element_slug}_{index + 1:02d}_{slug(name)}.png",
            })
    return result


def main() -> None:
    creatures_data = json.loads(CREATURES_PATH.read_text(encoding="utf-8"))
    moves = build_moves()
    moves_by_element: dict[str, list[dict]] = {}
    for move in moves:
        moves_by_element.setdefault(move["element"], []).append(move)

    counters: dict[str, int] = {}
    for creature_number, creature in enumerate(creatures_data["creatures"], start=1):
        creature_id = creature["id"]
        weight = WEIGHTS_KG[creature_id]
        creature["weight_kg"] = weight
        creature["weight_class"] = weight_class(weight)
        creature.update(balanced_stats(creature_id, creature["weight_class"]))
        element = creature["type"]
        position = counters.get(element, 0)
        counters[element] = position + 1
        pool = moves_by_element[element]
        primary_moves = [pool[index]["id"] for index in PRIMARY_MOVE_INDICES[position % 4]]
        coverage_pool = moves_by_element[coverage_element(element, position)]
        creature["moves"] = primary_moves + [coverage_pool[4]["id"]]
        checksum = sum((position + 1) * ord(character) for position, character in enumerate(creature_id)) % 10000
        creature["card_code"] = f"LB3-{creature_number:03d}-{checksum:04d}"

    creatures_data["version"] = 4
    MOVES_PATH.write_text(json.dumps({"version": 1, "moves": moves}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    CREATURES_PATH.write_text(json.dumps(creatures_data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Gerados {len(moves)} golpes; {len(creatures_data['creatures'])} Beasts receberam peso e cinco golpes.")


if __name__ == "__main__":
    main()
