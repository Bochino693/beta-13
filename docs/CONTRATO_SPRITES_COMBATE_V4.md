# Contrato dos sprites de combate V4

Cada Beast possui um atlas RGBA de `3072×3072`, em grade `8×8`. Cada célula
mede `384×384` e mantém 28 px transparentes em todas as bordas. O runtime
também ativa `filter_clip`, impedindo que o filtro da GPU revele parte do
quadro vizinho.

| Índices | Vista |
|---|---|
| 0–31 | Costas, jogador local |
| 32–63 | Frente, adversário |

Dentro de cada vista:

| Índice local | Sequência |
|---:|---|
| 0–7 | Idle/respiração, oito quadros em loop |
| 8–11 | Ataque leve: antecipação, contato e recuperação |
| 12–14 | Carregamento do ataque pesado |
| 15–17 | Soltura, impacto e recuperação pesada |
| 18–20 | Dano, recuo e retorno à guarda |
| 21–23 | Esquiva para a esquerda, sempre ereta |
| 24–26 | Esquiva para a direita, sempre ereta |
| 27–28 | Vitória |
| 29–30 | Derrota/KO |
| 31 | Pose exclusiva de escudo |

O atlas não contém a redoma: ela é um efeito 3D separado e permanece visível
durante as rodadas de proteção. Sombras, rastros e luz de presença também são
renderizados separadamente para manter as bordas da arte nítidas.
