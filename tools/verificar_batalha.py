#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verificar_batalha.py

Confere se a batalha contínua 2.5D está consistente: arte mestre transparente,
rig deformável, três locomoções, projéteis 3D e 80 golpes contextuais.

Rodar de dentro da pasta do projeto:
    python tools/verificar_batalha.py
"""

import json
import re
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BATALHA = RAIZ / "scripts" / "scenes" / "battle.gd"
SPRITE = RAIZ / "scripts" / "components" / "stable_beast_rig_3d.gd"
PROJETIL = RAIZ / "scripts" / "components" / "physical_projectile.gd"
ESTADIO = RAIZ / "scripts" / "components" / "battle_stadium_3d.gd"
ESCUDO = RAIZ / "scripts" / "components" / "battle_shield_dome_3d.gd"
FUNDO_ARENA = RAIZ / "assets" / "battle" / "arena" / "lazer_coliseum_backplate.png"
FONTE_CORPO = RAIZ / "assets" / "battle" / "fonts" / "URWGothic-Book.otf"

AUTOLOADS = {
    "CreatureDB": RAIZ / "scripts" / "autoload" / "creature_db.gd",
    "ArenaDB": RAIZ / "scripts" / "autoload" / "arena_db.gd",
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
    for caminho in (BATALHA, SPRITE, PROJETIL, ESTADIO, ESCUDO, FUNDO_ARENA, FONTE_CORPO):
        if not caminho.exists():
            erros.append("arquivo ausente: %s" % caminho.relative_to(RAIZ))
        else:
            if caminho.suffix in {".gd", ".py", ".md"}:
                detalhe = "%d linhas" % len(caminho.read_text(encoding="utf-8").splitlines())
            else:
                detalhe = "%d bytes" % caminho.stat().st_size
            ok.append("%s presente (%s)" % (caminho.relative_to(RAIZ), detalhe))


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
    if not SPRITE.exists():
        return
    fonte = SPRITE.read_text(encoding="utf-8")
    definidos = set(re.findall(r"^(?:static\s+)?func\s+([a-zA-Z_0-9]+)", fonte, re.M))
    nativos = {"queue_free", "new", "add_child", "position", "global_position"}

    chamados = set(re.findall(r"rig[a-z_]*\.([a-z_0-9]+)\(", texto))
    chamados |= set(re.findall(r"_rigs\[[^\]]+\]\.([a-z_0-9]+)\(", texto))
    chamados |= set(re.findall(r"StableBeastRig3D\.([a-z_0-9]+)\(", texto))

    for membro in sorted(chamados):
        if membro in definidos or membro in nativos:
            ok.append("Rig contínuo.%s" % membro)
        else:
            erros.append("Rig contínuo.%s nao existe" % membro)


def checar_criaturas():
    caminho = RAIZ / "data" / "creatures.json"
    if not caminho.exists():
        erros.append("data/creatures.json ausente")
        return []

    criaturas = json.loads(caminho.read_text(encoding="utf-8"))["creatures"]
    print("  criaturas no catalogo: %d" % len(criaturas))

    fonte_rig = SPRITE.read_text(encoding="utf-8") if SPRITE.exists() else ""
    trecho_mapa = fonte_rig.split("const FAMILY_BY_ID", 1)[-1].split("}", 1)[0]
    mapeadas = set(re.findall(r'"([a-z_0-9]+)"\s*:', trecho_mapa))
    familias = set(re.findall(r'^\t"([a-z]+)":\s*\{', fonte_rig.split("const FAMILY_BY_ID", 1)[0], re.M))

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

    perfis_usados = set(re.findall(r':\s*"([a-z]+)"', trecho_mapa))
    invalidos = perfis_usados - familias
    if invalidos:
        erros.append("familias usadas que nao existem em PERFIS: %s"
                     % ", ".join(sorted(invalidos)))

    print("  artes mestre transparentes: %d de %d" % (len(criaturas) - len(sem_retrato), len(criaturas)))

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
    sem_perfil_visual = []
    for g in golpes:
        fx = str(g.get("sprite_sheet", "")).replace("res://", "")
        icone = str(g.get("icon", "")).replace("res://", "")
        if not fx or not (RAIZ / fx).exists():
            sem_fx.append(g["id"])
        if not icone or not (RAIZ / icone).exists():
            sem_icone.append(g["id"])
        if any(not str(g.get(key, "")) for key in ("effect_family", "travel_style", "scene_reaction")):
            sem_perfil_visual.append(g["id"])

    if sem_fx:
        erros.append("golpes sem sprite de efeito: %d (%s...)"
                     % (len(sem_fx), ", ".join(sem_fx[:3])))
    else:
        ok.append("os %d golpes tem sprite de efeito" % len(golpes))

    if sem_icone:
        avisos.append("golpes sem icone: %d" % len(sem_icone))
    else:
        ok.append("os %d golpes tem icone" % len(golpes))
    if sem_perfil_visual:
        erros.append("golpes sem perfil visual contextual: %s" % ", ".join(sem_perfil_visual))
    else:
        ok.append("os %d golpes têm família, viagem e reação de cenário" % len(golpes))

    pesados = [g for g in golpes if str(g.get("role", "")) == "pesado"]
    print("  golpes marcados como pesado: %d" % len(pesados))


def checar_audio(criaturas):
    audio = RAIZ / "assets" / "audio"
    ausentes = []
    for criatura in criaturas:
        caminho = audio / "beasts" / (criatura["id"] + "_roar.wav")
        if not caminho.is_file() or caminho.stat().st_size < 1000:
            ausentes.append(criatura["id"])
    for nome in ("dodge.wav", "stadium_ambience.wav"):
        caminho = audio / nome
        if not caminho.is_file() or caminho.stat().st_size < 1000:
            ausentes.append(nome)
    if ausentes:
        erros.append("audio da batalha ausente: %s" % ", ".join(ausentes))
    else:
        ok.append("30 rugidos + esquiva + ambiente presentes")


def checar_presenca_das_mudancas(texto):
    exigido = {
        "SubViewport": "arena 3D dentro do Control",
        "StableBeastRig3D": "malha contínua com arte mestre",
        "PhysicalProjectile": "geometria 3D viajando do atacante ao alvo",
        "BattleStadium3D": "estadio 3D estavel",
        "BattleShieldDome3D": "redoma de guarda",
        "_tocar_fx_do_golpe": "sprite de golpe tocando no impacto",
        "sprite_sheet": "leitura da tira de efeito do moves.json",
        "_sacudir_camera": "tremor de camera no impacto",
        "preparar_golpe": "movimento contextual da Beast",
        "_numero_de_dano": "numero de dano flutuante",
        "Y_ARENA": "grade de faixas do retrato",
        "unproject_position": "projecao 3D->2D do numero de dano",
        "_mover_faixa": "esquiva em tres posicoes",
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
        "CinematicBeastSprite3D": "atlas/crossfade que causava piscadas",
        "_empurrar_camera": "zoom de ataque rejeitado",
    }
    for marca, descricao in proibido.items():
        if marca in texto:
            erros.append("battle.gd ainda usa %s (%s)" % (marca, descricao))
        else:
            ok.append("nao usa mais %s" % descricao)


def main():
    print()
    print("VERIFICACAO DA BATALHA CONTINUA 2.5D")
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
    criaturas = checar_criaturas()

    secao("6. Golpes")
    checar_golpes()

    secao("7. Audio")
    checar_audio(criaturas)

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
