# Teste da batalha 3D

## Início rápido

1. Abra `project.godot` no Godot 4.6.
2. Aguarde a importação inicial dos WAVs, imagens e futuros GLBs.
3. Pressione **F6** na cena de batalha ou **F5** para percorrer o jogo.
4. No modo CPU, use `A` e `D`; com dois jogadores, o segundo usa as setas.

## O que deve acontecer

- a Beast do jogador mostra as costas reais do corpo volumétrico e encara o oponente;
- a oponente mostra a frente e ocupa o outro lado do estádio;
- `A/D`, setas, direcional ou analógico movem apenas entre esquerda, centro e direita;
- durante o aviso vermelho de um golpe é permitida somente uma mudança de posição;
- sair da posição visada mostra `ESQUIVA` e reduz, sem zerar, o dano;
- o poder nasce em `FX_Origin`, atravessa o mundo 3D e atinge a faixa travada;
- cada golpe usa o arquivo indicado por `sprite_sheet` em `data/moves.json`;
- entrada e troca de Beast reproduzem um rugido individual;
- público, luzes, placar, piso e ambiência permanecem ativos.

## Diagnóstico honesto dos modelos

O sistema já é 3D, mas um corpo procedural não é a arte final da criatura. Abra
`data/beast_3d_manifest.json`: `proxy` significa que o motor está usando uma
anatomia volumétrica temporária; `ready` só pode ser usado quando o GLB final
existir. Execute:

```powershell
python tools\validate_3d_pipeline.py
```

Para impedir uma entrega incompleta, a checagem de lançamento é:

```powershell
python tools\validate_3d_pipeline.py --release
```

Ela falha enquanto qualquer um dos 30 modelos finais estiver ausente.
