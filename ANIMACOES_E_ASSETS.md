# Animações e assets

## Beasts HD

Cada Beast possui um retrato mestre em `assets/creatures_hd/<id>.png` e um spritesheet em `assets/sprites/beasts/<id>.png`. O spritesheet mede 1280×1280, dividido em 16 quadros de 320×320.

| Quadros | Estado | Leitura visual |
|---|---|---|
| 0–3 | Idle | respiração, apoio e flutuação contínua |
| 4–7 | Ataque | antecipação, avanço, soltura e retorno |
| 8–11 | Dano | flash, impacto, recuo e recuperação |
| 12–14 | Celebração | salto, aura e pose de vitória |
| 15 | Derrota | queda, dessaturação e repouso |

`creature_avatar.gd` reproduz esses quadros e acrescenta sombra, aura, deslocamento em profundidade e squash/stretch. O runtime não cria desenho substituto: spritesheet ausente é erro de conteúdo.

## Golpes

Os 80 golpes têm dois arquivos independentes:

- `assets/move_icons/<move_id>.png`: ícone para menus, guia e botões;
- `assets/moves_fx/<move_id>.png`: oito quadros de 192×192 para o efeito em combate.

`element_skill_fx.gd` usa o caminho registrado em `data/moves.json`, anima o efeito, o rastro e o impacto. O atacante executa sua linha de ataque antes do projétil e o alvo executa a linha de dano no contato.

## Arte 2.5D vertical

- `assets/backgrounds/`: quatro cenários 720×1280 sem texto;
- `assets/type_icons/`: oito placas elementais HD;
- `assets/materials/creatures/`: material individual de aura;
- `assets/materials/creature_fx.gdshader`: recorte, brilho e flash;
- `assets/cards/`: 30 cartas 600×900 com QR e código legível;
- `assets/audio/`: músicas e efeitos locais.

## Regeneração

```powershell
python tools\generate_combat_catalog.py
python tools\generate_portrait_assets.py
python tools\generate_audio_assets.py
python tools\validate_project.py
python tools\simulate_balance.py
```

Os geradores são ferramentas de desenvolvimento. Todos os arquivos necessários já acompanham o projeto.
