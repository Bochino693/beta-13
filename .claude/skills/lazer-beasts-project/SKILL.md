---
name: lazer-beasts-project
description: Preservar e evoluir o projeto Godot Lazer Beasts. Usar ao alterar combate, criaturas, golpes, peso, recarga, CPU, interface vertical, animações 2.5D, assets HD, cartas físicas, leitor de cartas, catálogo JSON, cenas ou documentação do jogo.
---

# Lazer Beasts Project

Tratar o projeto como arcade colecionável original, vertical e offline. Não reintroduzir nomes, artes, músicas ou criaturas de Pokémon/MEZASTAR; aproveitar apenas princípios genéricos de clareza, coleção e batalha.

## Fluxo obrigatório

1. Ler `references/vision.md` antes de decidir interface, modo ou escopo.
2. Ler `references/combat.md` antes de alterar dano, HP, peso, recarga, CPU, elementos ou golpes.
3. Ler `references/assets-and-cards.md` antes de tocar em imagens, spritesheets, ícones, cartas ou scanner.
4. Manter cada sistema atômico: dados em JSON, regra em autoload/componente, tela apenas consumindo a API.
5. Rodar `python tools/validate_project.py`, `python tools/simulate_balance.py`,
   `godot --headless --path . --script tools/validate_visual_runtime.gd` e o
   analisador GDScript disponível antes de entregar.

## Invariantes

- Manter viewport base em `720×1280`, orientação retrato e renderer GL Compatibility.
- Usar somente PNG HD para Beasts; nunca usar SVG, desenho genérico ou fallback de baixa definição.
- Manter a leitura de câmera da arena: a Beast do jogador SEMPRE de costas em
  primeiro plano (poses `back_*`), a adversária SEMPRE de frente ao fundo
  (poses `front_*`). Nunca espelhar uma vista para fingir a outra.
- Não ligar `billboard` na Beast: é o que mata a perspectiva. Billboard só em
  efeito de luz (poder, partícula).
- Manter a arte da arena como cenário inteiro; não reintroduzir arquibancada,
  público ou estrutura procedural concorrendo com ela.
- Manter 30 Beasts, oito elementos e 80 golpes, salvo pedido explícito de expansão.
- Dar exatamente cinco golpes a cada Beast: quatro do elemento primário, uma cobertura técnica e exatamente um pesado.
- Aplicar peso à vida e à recarga sem criar vitória automática para Pesado/Colossal.
- Manter estados HD de idle, ataque, hit, celebração e derrota em todas as Beasts.
- Fazer a CPU consumir as mesmas regras e cooldowns do jogador.
- Preservar teclado, dois joysticks, mouse/toque, modo livre/fichas e futura leitura de cartas.
- Manter o jogo totalmente local durante a execução.

## Fontes de verdade

- Beasts e seus cinco golpes: `data/creatures.json`.
- Catálogo dos golpes: `data/moves.json`.
- Hierarquia elemental: `data/elements.json` (fonte ÚNICA; lida pelo runtime
  em `creature_db.gd` e por `tools/simulate_balance.py`). Luz e Escuridão são
  rivais recíprocos; todo elemento vence exatamente dois.
- Poses de combate da Beast: `assets/sprites_combat/<id>.poses.json`, lido só
  por `scripts/components/beast_pose_atlas.gd`.
- Peso, HP, recarga e previsão de dano: `scripts/autoload/move_db.gd`.
- Registro futuro de cartas: `scripts/autoload/card_registry.gd`.
- Validação de recursos/contratos: `tools/validate_project.py`.

Não duplicar essas regras em scripts de cena. Exibir valores obtidos dessas APIs.
