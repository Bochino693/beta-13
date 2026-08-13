#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
validar_layout.py — impede que as faixas do retrato voltem a se sobrepor.

Le as constantes de faixa direto de scripts/scenes/battle.gd e falha se
duas faixas se cruzarem ou se alguma passar do fim da tela.

Foi este tipo de conferencia que faltou: no battle.gd antigo o avatar do
jogador terminava em y=875 e o balao de mensagem comecava em y=865.

Rodar de dentro da pasta do projeto:
    python tools/validar_layout.py
"""

import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BATALHA = RAIZ / "scripts" / "scenes" / "battle.gd"


def ler_constantes(texto):
    achadas = {}
    padrao = re.compile(r"^const\s+([A-Z_0-9]+)\s*:=\s*([0-9]+(?:\.[0-9]+)?)\s*(?:#.*)?$", re.M)
    for nome, valor in padrao.findall(texto):
        achadas[nome] = float(valor)
    return achadas


def main():
    if not BATALHA.exists():
        print("ERRO: nao encontrei", BATALHA)
        return 1

    c = ler_constantes(BATALHA.read_text(encoding="utf-8"))

    faltando = [
        n for n in (
            "MARGEM", "ALTURA", "Y_TOPO", "H_TOPO", "Y_HUD_INIMIGO", "H_HUD",
            "Y_ARENA", "H_ARENA", "Y_HUD_ALIADO", "Y_MENSAGEM", "H_MENSAGEM",
            "Y_ACOES",
        )
        if n not in c
    ]
    if faltando:
        print("ERRO: constantes ausentes em battle.gd:", ", ".join(faltando))
        return 1

    faixas = [
        ("topo",         c["Y_TOPO"],         c["Y_TOPO"] + c["H_TOPO"]),
        ("hud inimigo",  c["Y_HUD_INIMIGO"],  c["Y_HUD_INIMIGO"] + c["H_HUD"]),
        ("arena 3D",     c["Y_ARENA"],        c["Y_ARENA"] + c["H_ARENA"]),
        ("hud aliado",   c["Y_HUD_ALIADO"],   c["Y_HUD_ALIADO"] + c["H_HUD"]),
        ("mensagem",     c["Y_MENSAGEM"],     c["Y_MENSAGEM"] + c["H_MENSAGEM"]),
        ("acoes",        c["Y_ACOES"],        c["ALTURA"] - c["MARGEM"]),
    ]

    erros = []

    for i in range(len(faixas) - 1):
        nome_a, _, fim_a = faixas[i]
        nome_b, ini_b, _ = faixas[i + 1]
        if fim_a > ini_b:
            erros.append(
                "'%s' termina em %.0f e '%s' comeca em %.0f "
                "(sobreposicao de %.0f px)" % (nome_a, fim_a, nome_b, ini_b, fim_a - ini_b)
            )

    if faixas[-1][2] > c["ALTURA"]:
        erros.append("a ultima faixa passa do fim da tela (%.0f > %.0f)"
                     % (faixas[-1][2], c["ALTURA"]))

    print()
    print("FAIXAS DO RETRATO %dx%d" % (720, int(c["ALTURA"])))
    for nome, ini, fim in faixas:
        print("  %-14s %6.0f -> %6.0f   (%3.0f px)" % (nome, ini, fim, fim - ini))

    respiros = []
    for i in range(len(faixas) - 1):
        respiros.append(faixas[i + 1][1] - faixas[i][2])
    print("  respiro entre faixas: %s" % ", ".join("%.0f" % r for r in respiros))

    print()
    if erros:
        for e in erros:
            print("ERRO:", e)
        return 1

    if min(respiros) < 6:
        print("AVISO: faixas muito coladas. O retrato fica sufocado no gabinete.")

    print("LAYOUT OK — nenhuma faixa se sobrepoe.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
