# Lazer Beasts: Elemental Arena

Versão 4.0.0 — arcade original de batalha elemental em formato retrato para Godot 4.6. O pacote funciona offline e contém 30 Beasts originais, oito elementos, 80 golpes e combates 5×5 contra outro jogador ou CPU.

## Conteúdo funcional

- cutscene da Lazer & Sport, abertura, seleção de modo, montagem de equipe, combate e resultado;
- viewport vertical `720×1280`, arte 2.5D, cenários em perspectiva, parallax, sombras, aura e partículas;
- 30 retratos mestres HD e 30 spritesheets 4×4, sem fallback de baixa definição;
- animações próprias de idle/respiração, ataque, dano, celebração e derrota;
- oito elementos: Luz, Escuridão, Fogo, Choque, Terra, Água, Natureza e Vento;
- 10 golpes por elemento, totalizando 80 ícones e 80 efeitos animados;
- cinco golpes por Beast: quatro primários e uma cobertura contra fraqueza, com exatamente um pesado;
- vida, dano e recarga equilibrados por classe de peso;
- CPU que usa as mesmas regras, vida e cooldowns do jogador;
- guia interno de poderes, filtros modernos por elemento e suporte a mouse/toque;
- 30 cartas imprimíveis com QR e código estável, prontas para futura leitura física;
- teclado, dois controles USB, sistema de fichas e modo livre;
- músicas e efeitos locais, sem downloads ou tráfego durante a partida.

## Instalação

O destino esperado no gabinete é:

```text
C:\Users\LAZER GAMES\Documents\beta-13
```

Extraia o ZIP e execute `INSTALAR_BETA13.ps1`. O instalador cria um backup recuperável da pasta existente, copia a versão nova e confere 30 artes HD, 30 spritesheets, 80 efeitos de golpes, 30 cartas, 7 cenas e 19 scripts.

No Godot 4.6:

1. clique em **Importar**;
2. selecione `C:\Users\LAZER GAMES\Documents\beta-13\project.godot`;
3. aguarde a primeira importação das imagens;
4. pressione **F6** ou **F5**.

O renderer é **GL Compatibility** e a resolução-base é `720×1280`.

## Controles

| Ação | Jogador 1 | Jogador 2 |
|---|---|---|
| Mover | W A S D | Setas |
| Confirmar/golpe | Espaço | Enter |
| Cancelar/remover | Q | N |
| Confirmar equipe | E | M |
| Próximo filtro | TAB/ombro | TAB/ombro |
| Iniciar | 1/Start | 1/Start |
| Inserir ficha | 5 | 5 |

Teclas do operador: `F10` alterna modo livre/fichas, `F11` controla o som e `F12` alterna tela cheia. As preferências ficam em `user://lazer_beasts_settings.json`.

## Sistema de combate

Cada equipe possui cinco Beasts. Em seu turno, escolha um dos cinco golpes, defenda ou troque. Cada golpe tem poder, papel e recarga individual. A recarga diminui quando a vez daquela Beast retorna; por isso uma Beast leve reutiliza técnicas antes, enquanto as pesadas sobrevivem mais.

As classes são Ultra Leve, Leve, Médio, Pesado e Colossal. Vida e defesa crescem de maneira controlada com o peso; dano e cooldown compensam essa vantagem. O arquivo `tools/simulate_balance.py` executa 8.700 duelos de referência e bloqueia curvas com dominância excessiva.

Cada Beast recebe quatro golpes de seu elemento e um golpe técnico de cobertura. Isso mantém fraquezas relevantes sem transformar uma afinidade ruim em derrota automática.

| Elemento | Forte contra |
|---|---|
| Luz | Escuridão, Natureza |
| Escuridão | Vento, Água |
| Fogo | Luz, Natureza |
| Choque | Água, Vento |
| Terra | Choque, Fogo |
| Água | Fogo, Terra |
| Natureza | Terra, Água |
| Vento | Natureza, Luz |

## Sprites, golpes e cartas

- retratos mestres: `assets/creatures_hd/<id>.png`;
- animações: `assets/sprites/beasts/<id>.png`;
- ícones dos golpes: `assets/move_icons/<move_id>.png`;
- efeitos animados: `assets/moves_fx/<move_id>.png`;
- ícones de elemento: `assets/type_icons/<slug>.png`;
- cartas: `assets/cards/<id>.png`;
- catálogo: `data/creatures.json` e `data/moves.json`.

Não existe fallback SVG para Beasts. Se um spritesheet HD faltar, o jogo registra um erro explícito para impedir que uma arte provisória chegue ao gabinete.

O QR das cartas usa `LAZERBEASTS:<card_code>:<creature_id>`. O autoload `CardRegistry` já valida esse conteúdo e a seleção aceita a futura entrada do leitor sem misturar protocolo serial com a interface.

## Validação e regeneração

Após qualquer mudança de catálogo ou arte:

```powershell
python tools\generate_combat_catalog.py
python tools\generate_portrait_assets.py
python tools\validate_project.py
python tools\simulate_balance.py
```

O jogo não precisa de Python para rodar; essas ferramentas servem apenas para desenvolvimento.

## Exportação e gabinete

Em **Projeto → Exportar**, use o preset **Windows Desktop**. O destino padrão é `build/LazerBeasts.exe` e o PCK já está embutido.

Não é necessário alterar o Arduino se o encoder já aparece como teclado ou joystick USB. O projeto não grava firmware; um leitor de cartas futuro só precisa enviar o código lido para `CardRegistry.submit_scan()` por uma ponte apropriada.

## Estrutura

```text
beta-13/
├── .claude/skills/    contrato persistente para futuros agentes
├── assets/            Beasts HD, sprites, golpes, cartas, cenários e áudio
├── data/              30 Beasts e 80 golpes
├── scenes/            7 telas verticais
├── scripts/           autoloads, componentes, cenas e UI
├── tools/             geração, validação e simulação de equilíbrio
├── AGENTS.md
├── export_presets.cfg
└── project.godot
```

`Lazer Beasts`, suas criaturas, nomes, artes, interface, cartas e áudio são material original deste projeto. Não são usados personagens, sprites, marcas ou músicas oficiais de Pokémon/MEZASTAR; a referência é apenas o princípio genérico de clareza de um arcade colecionável.
