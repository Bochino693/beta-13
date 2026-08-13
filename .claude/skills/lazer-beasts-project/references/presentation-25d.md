# Apresentação 2.5D — padrão obrigatório do Lazer Beasts

Ler este arquivo antes de mexer em batalha, câmera, animação de Beast, efeito de
golpe, enquadramento ou qualquer coisa que o jogador enxerga durante o duelo.

## 1. O erro que não pode se repetir

As versões até a v4.0.1 geraram "spritesheets de animação" que eram **a mesma
ilustração parada** com tinta, contorno e escala aplicados por script. Nenhum
pixel do corpo mudava de pose. O resultado parece um cartão, não um vídeo.

**Proibido**: gerar spritesheet por filtro de imagem (tint, outline, resize,
grayscale) e chamar aquilo de animação. Se os quadros não mudam a silhueta, o
arquivo não é animação.

**Padrão correto**: a ilustração HD única vira uma malha deformável em tempo
real. Ver `scripts/components/beast_rig_3d.gd`. A malha é um `PlaneMesh` com
`subdivide_width = subdivide_depth = 32` e um shader `spatial` que empurra os
vértices.

## 2. Movimento vivo obrigatório em toda Beast

Nenhuma Beast pode ficar parada em tela. Todas rodam permanentemente:

| Canal | O que faz | Onde atua |
|---|---|---|
| `respiro` | torso infla e desinfla, pés presos ao chão | máscara de altura 0.05–0.58 |
| `asa` | batida com atraso na ponta | extremidades laterais, `abs(u) > 0.24` |
| `pelo` | ondulação de pelo, franja, folhagem, chamas | silhueta e topo |
| `balanco` | peso do corpo deslocando devagar | corpo inteiro, proporcional à altura |
| `flutuacao` | subida e descida de quem não toca o chão | corpo inteiro |

Cada Beast declara `familia_anim` em `data/creatures.json`. Valores aceitos:
`ave`, `dragao`, `felpudo`, `reptil`, `planta`, `mineral`, `aquatico`,
`espectro`, `padrao`. O perfil define a intensidade de cada canal — um pássaro
bate asa forte e rápido, um mineral quase não respira.

Cada rig começa com `_tempo = randf() * 8.0`. Duas Beasts nunca podem respirar
em sincronia; sincronia denuncia que é efeito de programa.

## 3. Estados de combate

Chamados por `Arena25D`, nunca direto pela cena de regra:

- `entrar()` — dissolução de baixo para cima na entrada
- `atacar()` — recua, avança, emite `animacao_terminou("impacto")` no ponto
  exato em que o sprite do golpe deve aparecer, e volta
- `carregar()` — só para o golpe pesado, antes de `atacar()`
- `levar_dano(cor)` — flash na cor do elemento atacante + tremor
- `comemorar()` — vitória
- `tombar()` — rotação na base + dissolução

O sprite do golpe **nunca** aparece antes de `animacao_terminou("impacto")`.
Efeito antes do movimento é o que faz o combate parecer dessincronizado.

## 4. Enquadramento do duelo

- Aliado: `Vector3(-0.55, 0, 1.15)`, altura 2.95, `de_costas = true`
- Inimigo: `Vector3(0.35, 0, -5.40)`, altura 2.35, `de_costas = false`
- Os dois deslocados em X para lados opostos: nunca se sobrepõem na silhueta
- Câmera: `Camera3D`, `keep_aspect = KEEP_WIDTH`, `fov = 46`,
  posição `(0, 2.10, 4.60)`, rotação X `-9.5°`
- A câmera tem respiro lento permanente em `_process`. Câmera imóvel mata a
  sensação de 3D.
- Golpe pesado empurra o `fov` para 36 e volta. Golpe normal não mexe no `fov`.

### Vista de costas

O projeto não tem arte de costas das 30 Beasts. Enquanto não tiver, `de_costas`
usa espelhamento horizontal + `contraluz = 0.85`: o corpo escurece e só a borda
fica acesa pela luz da arena. Lê como silhueta em contraluz, não como erro.

Quando houver arte de costas real, ela entra em `assets/creatures_back/<id>.png`
e o rig passa a carregar essa textura com `contraluz = 0.25`. Não remover o modo
contraluz: ele continua sendo o fallback de qualquer Beast sem arte de costas.

## 5. Efeitos de golpe

- Tira horizontal em `assets/moves_fx/<elemento>_<n>_<nome>.png`
- Renderizados em `Sprite3D` com `billboard = BILLBOARD_ENABLED`,
  `no_depth_test = true`, `render_priority = 5`
- `modulate` sempre na cor do elemento do golpe, nunca branco
- O FX do aliado usa `pixel_size` maior que o do inimigo — perspectiva
- Cada tira declara `quadros` no `data/moves.json`. Sem esse campo, assume 8.

## 6. Câmera e impacto

- Dano normal: `_sacudir_camera(0.20)`
- Dano pesado: `_sacudir_camera(0.42)`
- O tremor é em `rotation_degrees:z`, nunca em `position`. Tremor de posição
  descola a Beast do chão e quebra a perspectiva.

## 7. Checagem antes de entregar qualquer mudança visual

1. As duas Beasts respiram com fases diferentes?
2. A Beast do jogador aparece de costas e maior que a do oponente?
3. O sprite do golpe nasce no `impacto`, não antes?
4. A câmera se move sozinha mesmo sem input?
5. Nenhum elemento de HUD invade a faixa de outro? (ver `docs/LAYOUT_RETRATO.md`)
6. Rodou em `gl_compatibility` sem erro de shader no console?

## 8. Onde a apresentação vive hoje

- `scripts/scenes/battle.gd` — batalha 2.5D completa. Raiz `Control`, arena
  dentro de um `SubViewport` 3D. Não converter para `Node3D`: o `battle.tscn`
  original continua válido.
- `scripts/components/beast_rig_3d.gd` — rig de deformação + `FAMILIA_POR_ID`
  com a família anatômica das 30 Beasts.
- `tools/validar_layout.py` — roda antes de qualquer entrega que mexa em faixa.

Regras que não podem ser revertidas:

- `assets/sprites/beasts/*.png` é lixo herdado (16 quadros idênticos). Não usar,
  não regenerar, não "corrigir". A fonte de arte da batalha é
  `assets/creatures_hd/<id>.png`.
- O número de quadros do FX de golpe é calculado como `largura / altura` da
  tira. Não adicionar campo `quadros` no `moves.json`.
- Toda regra de combate vive em `MoveDB` e `CreatureDB`. `battle.gd` só desenha.
  Nenhum número de dano, recarga ou peso pode ser escrito dentro de `battle.gd`.
