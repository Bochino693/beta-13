# Contrato dos sprites de combate V3

Cada Beast possui um atlas RGBA de `3072×1536`, dividido em uma grade `8×4`.
Cada célula mede `384×384` e é isolada das células vizinhas.

| Índices | Vista |
|---|---|
| 0–15 | Costas, jogador local |
| 16–31 | Frente, adversário |

Dentro de cada vista:

| Índice local | Estado |
|---:|---|
| 0–5 | Sequência idle/respiração |
| 6 | Preparação do ataque leve |
| 7 | Impacto do ataque leve |
| 8 | Carregamento do ataque pesado |
| 9 | Impacto do ataque pesado |
| 10 | Recebendo dano |
| 11 | Esquiva para a esquerda |
| 12 | Esquiva para a direita |
| 13 | Vitória |
| 14 | KO |
| 15 | Escudo |

O recorte usa o canal alfa, portanto partes brancas da criatura não podem ser
confundidas com fundo nem removidas. A sombra é renderizada separadamente no
mundo 3D e reage à flutuação da Beast.
