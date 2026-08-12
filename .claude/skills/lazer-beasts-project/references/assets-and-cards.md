# Contrato de assets e cartas

## Beasts

- Retrato mestre: `assets/creatures_hd/<id>.png`.
- Spritesheet em runtime: `assets/sprites/beasts/<id>.png`, 1280×1280, grade 4×4, quadros de 320×320.
- Material individual: `assets/materials/creatures/<id>.tres`.
- Nunca criar ou carregar `assets/creatures/<id>.svg`.

Mapa da folha:

| Quadros | Estado |
|---|---|
| 0–3 | idle/respiração |
| 4–7 | preparação, avanço e soltura do ataque |
| 8–11 | flash, recuo e recuperação de dano |
| 12–14 | comemoração |
| 15 | derrota |

## Golpes

- Ícone: `assets/move_icons/<move_id>.png`.
- Efeito animado: `assets/moves_fx/<move_id>.png`, oito quadros horizontais de 192×192.
- O caminho oficial fica no registro de `data/moves.json`; não montar caminhos diferentes em cenas.

## Elementos e cenários

- Ícones HD: `assets/type_icons/<slug>.png`.
- Backgrounds verticais: `assets/backgrounds/*.png`, 720×1280, sem texto/Beasts.

## Cartas físicas

- Arte: `assets/cards/<id>.png`, retrato, QR e `card_code` visível.
- Conteúdo QR: `LAZERBEASTS:<card_code>:<creature_id>`.
- Resolver código somente por `CardRegistry.submit_scan()`.
- O leitor futuro deve entregar o texto ao registro; seleção e batalha não conhecem protocolo serial/QR.
- Rejeitar código desconhecido e nunca criar Beast dinamicamente a partir do texto lido.
