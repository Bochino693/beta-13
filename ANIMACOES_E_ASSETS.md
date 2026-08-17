# Animações e assets

## Beast em combate — atlas de poses

A batalha desenha a Beast a partir de `assets/sprites_combat/<id>.png`, um
atlas RGBA de `3072×1536` em grade `8×4`, com células de `384×384` e margem
transparente de 22 px. O recorte de cada célula vem de
`assets/sprites_combat/<id>.poses.json`, gerado a partir da transparência real
da arte.

O manifesto é a fonte de verdade: linhas, colunas, tamanho de célula, nome e
retângulo de cada pose saem dele. `scripts/components/beast_pose_atlas.gd` é a
única porta de entrada; nada mais no projeto calcula recorte de célula.

### Vistas

| Índices | Vista | Quem usa |
|---|---|---|
| 0–15 | `back_*` | a Beast do jogador local, que luta **de costas**, em primeiro plano |
| 16–31 | `front_*` | a Beast adversária, que **encara** o jogador, ao fundo da arena |

As duas vistas são desenhos diferentes, não espelhamento. O rig antigo invertia
a UV da arte de frente, então a Beast do jogador continuava encarando o jogador
— só que ao contrário.

### Poses de cada vista

| Sufixo | Uso em combate |
|---|---|
| `idle_0` … `idle_5` | respiração em laço, na cadência da família da Beast |
| `light_charge` / `light_impact` | antecipação e contato do golpe leve |
| `heavy_charge` / `heavy_impact` | armação e contato do golpe pesado |
| `damage` | ao receber dano |
| `dodge_left` / `dodge_right` | troca de faixa |
| `victory` | vitória |
| `ko` | derrota (quadro preso: a Beast derrotada não volta a respirar) |
| `guard` | escudo erguido |

`beast_pose_atlas.gd` agrupa as poses por `(vista, estado)` lendo o sufixo
numérico do nome. Uma pose única e uma sequência de vários quadros são tratadas
da mesma maneira, então um atlas com mais quadros por estado — o contrato V4
descrito em `docs/CONTRATO_SPRITES_COMBATE_V4.md` — entra sem alterar código.

### Movimento

`scripts/components/beast_rig_3d.gd` combina duas camadas:

- **quadro a quadro**, num relógio fixo independente da taxa de renderização,
  para a animação não acelerar a 144 fps nem travar a 30;
- **coreografia no espaço 3D** por tween: avanço, salto do voador, ondulação do
  aquático, escavação, recuo do dano e queda do KO.

O rig **não usa billboard**. É isso que devolve a perspectiva: a Beast do
jogador está perto da câmera e ocupa mais tela, a adversária recua para o fundo
da arena. O material é um `StandardMaterial3D` explícito, não-sombreado, com
recorte por alfa — assim a Beast entra no buffer de profundidade e o poder pode
passar na frente ou atrás dela.

## Golpes

Os 80 golpes têm dois arquivos:

- `assets/move_icons/<move_id>.png`: ícone para menus, guia e botões;
- `assets/moves_fx/<move_id>.png`: tira horizontal de quadros quadrados.

`scripts/components/element_power_3d.gd` faz o poder nascer na Beast atacante e
atravessar a arena em 3D, com trajetória por `travel_style` e corpo geométrico
por `effect_family`. A tira entra em **mistura aditiva**: o escuro do desenho
não pinta o cenário, só a luz acende. Sobre ela vão um núcleo quente e um halo,
que dão borda definida ao poder. O dano só é aplicado no impacto.

## Arena

A arte de `data/arenas.json` **é** o cenário: um painel dimensionado para cobrir
todo o campo de visão da câmera. A geometria restante é só o que a Beast precisa
para existir num lugar — piso, costura do horizonte, luzes e anéis de reação ao
impacto. Não há mais arquibancada, público nem treliça procedurais competindo
com o desenho da arena.

## Telas e cartas

- `assets/creatures_hd/`: retrato mestre de cada Beast, usado nas telas de menu;
- `assets/sprites/beasts/`: folha 4×4 usada por `creature_avatar.gd` nos menus;
- `assets/backgrounds/`: cenários 720×1280 das telas de menu;
- `assets/battle/arena/`: arte das seis arenas de batalha;
- `assets/ui/loading/`: fundo de reserva do carregamento (a tela usa a arte da
  arena sorteada quando ela existe);
- `assets/type_icons/`: oito placas elementais;
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

Para conferir o visual em execução, com o Godot instalado:

```powershell
godot --headless --path . --script tools/validate_visual_runtime.gd
```

Ele monta as 30 Beasts nas **duas** vistas, confere que cada vista tem todas as
poses que o combate pede, dispara uma amostra de cada família de golpe e monta
as seis arenas.

Os geradores são ferramentas de desenvolvimento. Todos os arquivos necessários
já acompanham o projeto.
