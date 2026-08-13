#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verificar_batalha.py

Confere, sem abrir o Godot, se a batalha 2.5D esta consistente com o resto do
projeto: metodos de autoload que existem, assets que existem, as 30 Beasts com
retrato e familia de animacao, os 80 golpes com sprite de efeito.

Rodar de dentro da pasta do projeto:
    python tools/verificar_batalha.py
"""

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BATALHA = RAIZ / "scripts" / "scenes" / "battle.gd"
RIG = RAIZ / "scripts" / "components" / "beast_rig_3d.gd"

AUTOLOADS = {
    "CreatureDB": RAIZ / "scripts" / "autoload" / "creature_db.gd",
    "MoveDB": RAIZ / "scripts" / "autoload" / "move_db.gd",
    "GameState": RAIZ / "scripts" / "autoload" / "game_state.gd",
    "AudioSynth": RAIZ / "scripts" / "autoload" / "audio_synth.gd",
    "Transition": RAIZ / "scripts" / "autoload" / "transition.gd",
}

erros = []
avisos = []
ok = []


def secao(titulo):
    print()
    print(titulo)
    print("-" * len(titulo))


def checar_arquivos():
    for caminho in (BATALHA, RIG):
        if not caminho.exists():
            erros.append("arquivo ausente: %s" % caminho.relative_to(RAIZ))
        else:
            ok.append("%s presente (%d linhas)" % (
                caminho.relative_to(RAIZ),
                len(caminho.read_text(encoding="utf-8").splitlines()),
            ))


def checar_autoloads(texto):
    """Todo Autoload.metodo() chamado em battle.gd existe no autoload?"""
    for nome, arquivo in AUTOLOADS.items():
        if not arquivo.exists():
            avisos.append("autoload nao encontrado: %s" % nome)
            continue
        fonte = arquivo.read_text(encoding="utf-8")
        definidos = set(re.findall(r"^func\s+([a-zA-Z_0-9]+)", fonte, re.M))
        constantes = set(re.findall(r"^const\s+([A-Z_0-9]+)", fonte, re.M))
        variaveis = set(re.findall(r"^var\s+([a-z_0-9]+)", fonte, re.M))

        chamados = set(re.findall(nome + r"\.([a-zA-Z_0-9]+)", texto))
        for membro in sorted(chamados):
            if membro in definidos or membro in constantes or membro in variaveis:
                ok.append("%s.%s" % (nome, membro))
            else:
                erros.append("%s.%s nao existe em %s" % (
                    nome, membro, arquivo.relative_to(RAIZ)))


def checar_metodos_do_rig(texto):
    if not RIG.exists():
        return
    fonte = RIG.read_text(encoding="utf-8")
    definidos = set(re.findall(r"^(?:static\s+)?func\s+([a-zA-Z_0-9]+)", fonte, re.M))
    nativos = {"queue_free", "new", "add_child", "position", "global_position"}

    chamados = set(re.findall(r"rig[a-z_]*\.([a-z_0-9]+)\(", texto))
    chamados |= set(re.findall(r"_rigs\[[^\]]+\]\.([a-z_0-9]+)\(", texto))
    chamados |= set(re.findall(r"BeastRig3D\.([a-z_0-9]+)\(", texto))

    for membro in sorted(chamados):
        if membro in definidos or membro in nativos:
            ok.append("BeastRig3D.%s" % membro)
        else:
            erros.append("BeastRig3D.%s nao existe" % membro)


def checar_criaturas():
    caminho = RAIZ / "data" / "creatures.json"
    if not caminho.exists():
        erros.append("data/creatures.json ausente")
        return []

    criaturas = json.loads(caminho.read_text(encoding="utf-8"))["creatures"]
    print("  criaturas no catalogo: %d" % len(criaturas))

    fonte_rig = RIG.read_text(encoding="utf-8") if RIG.exists() else ""
    mapeadas = set(re.findall(r'^\t"([a-z_0-9]+)":\s*"', fonte_rig, re.M))
    familias = set(re.findall(r'^\t"([a-z]+)":\s*\{', fonte_rig, re.M))

    sem_retrato = []
    sem_familia = []

    for c in criaturas:
        cid = c["id"]
        if not (RAIZ / "assets" / "creatures_hd" / ("%s.png" % cid)).exists():
            sem_retrato.append(cid)
        if cid not in mapeadas:
            sem_familia.append(cid)

    if sem_retrato:
        erros.append("sem retrato HD: %s" % ", ".join(sem_retrato))
    else:
        ok.append("as %d Beasts tem retrato em assets/creatures_hd" % len(criaturas))

    if sem_familia:
        avisos.append("sem familia de animacao explicita (usarao deducao): %s"
                      % ", ".join(sem_familia))
    else:
        ok.append("as %d Beasts tem familia de animacao definida" % len(criaturas))

    perfis_usados = set(re.findall(r':\s*"([a-z]+)"', "\n".join(
        re.findall(r'^\t"[a-z_0-9]+":\s*("[a-z]+"),', fonte_rig, re.M))))
    invalidos = perfis_usados - familias
    if invalidos:
        erros.append("familias usadas que nao existem em PERFIS: %s"
                     % ", ".join(sorted(invalidos)))

    costas = RAIZ / "assets" / "creatures_back"
    n_costas = len(list(costas.glob("*.png"))) if costas.exists() else 0
    print("  artes de costas: %d de %d (opcional, o rig usa contraluz sem elas)"
          % (n_costas, len(criaturas)))

    return criaturas


def checar_golpes():
    caminho = RAIZ / "data" / "moves.json"
    if not caminho.exists():
        erros.append("data/moves.json ausente")
        return

    golpes = json.loads(caminho.read_text(encoding="utf-8"))["moves"]
    print("  golpes no catalogo: %d" % len(golpes))

    sem_fx = []
    sem_icone = []
    for g in golpes:
        fx = str(g.get("sprite_sheet", "")).replace("res://", "")
        icone = str(g.get("icon", "")).replace("res://", "")
        if not fx or not (RAIZ / fx).exists():
            sem_fx.append(g["id"])
        if not icone or not (RAIZ / icone).exists():
            sem_icone.append(g["id"])

    if sem_fx:
        erros.append("golpes sem sprite de efeito: %d (%s...)"
                     % (len(sem_fx), ", ".join(sem_fx[:3])))
    else:
        ok.append("os %d golpes tem sprite de efeito" % len(golpes))

    if sem_icone:
        avisos.append("golpes sem icone: %d" % len(sem_icone))
    else:
        ok.append("os %d golpes tem icone" % len(golpes))

    pesados = [g for g in golpes if str(g.get("role", "")) == "pesado"]
    print("  golpes marcados como pesado: %d" % len(pesados))


def checar_presenca_das_mudancas(texto):
    exigido = {
        "SubViewport": "arena 3D dentro do Control",
        "BeastRig3D": "rig de deformacao das Beasts",
        "_tocar_fx_do_golpe": "sprite de golpe tocando no impacto",
        "sprite_sheet": "leitura da tira de efeito do moves.json",
        "_sacudir_camera": "tremor de camera no impacto",
        "_empurrar_camera": "zoom no golpe pesado",
        "_numero_de_dano": "numero de dano flutuante",
        "Y_ARENA": "grade de faixas do retrato",
        "unproject_position": "projecao 3D->2D do numero de dano",
        "creatures_back": "suporte a arte de costas futura",
    }
    for marca, descricao in exigido.items():
        if marca in texto:
            ok.append("%s (%s)" % (marca, descricao))
        else:
            erros.append("FALTA em battle.gd: %s (%s)" % (marca, descricao))

    proibido = {
        "sprites/beasts": "spritesheet falso antigo",
        "CreatureAvatar": "avatar 2D antigo",
        "ElementSkillFX": "efeito generico antigo",
    }
    for marca, descricao in proibido.items():
        if marca in texto:
            erros.append("battle.gd ainda usa %s (%s)" % (marca, descricao))
        else:
            ok.append("nao usa mais %s" % descricao)


def main():
    print()
    print("VERIFICACAO DA BATALHA 2.5D")
    print("=" * 40)

    secao("1. Arquivos")
    checar_arquivos()
    if not BATALHA.exists():
        print("battle.gd nao existe. Abortando.")
        return 1
    texto = BATALHA.read_text(encoding="utf-8")

    secao("2. Mudancas presentes no battle.gd")
    checar_presenca_das_mudancas(texto)

    secao("3. Chamadas de autoload")
    checar_autoloads(texto)

    secao("4. Metodos do rig")
    checar_metodos_do_rig(texto)

    secao("5. Beasts")
    checar_criaturas()

    secao("6. Golpes")
    checar_golpes()

    print()
    print("=" * 40)
    print("OK:      %d verificacoes" % len(ok))
    print("AVISOS:  %d" % len(avisos))
    print("ERROS:   %d" % len(erros))

    for a in avisos:
        print("  AVISO: %s" % a)
    for e in erros:
        print("  ERRO:  %s" % e)

    print()
    if erros:
        print("RESULTADO: corrija os erros acima antes de abrir o Godot.")
        return 1
    print("RESULTADO: batalha consistente com o projeto.")
    print("Falta apenas o teste visual: abra o Godot 4.6 e rode com F5.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
