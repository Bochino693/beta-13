# Layout retrato 720×1280 — grade de faixas

## O bug atual

`scripts/scenes/battle.gd` posiciona tudo com números absolutos soltos:

```gdscript
avatar.position = Vector2(10, 505)
avatar.size     = Vector2(390, 370)   # borda inferior = 875
...
message_panel.position = Vector2(20, 865)   # começa em 865
```

O avatar do jogador termina em **875** e o balão de mensagem começa em **865**.
São **10 px de sobreposição**, e é por isso que "está tudo por cima de tudo".
Há mais casos: `versus` em y=475 cai dentro do avatar do inimigo (196–551).

A causa não é o valor errado. É o método: posição absoluta em `Control` solto,
sem container e sem âncora. Qualquer troca de fonte ou de texto reabre o
problema.

## Regra

Toda tela é dividida em **faixas verticais exclusivas**. Um elemento vive dentro
de uma faixa e não pode cruzar a fronteira. Faixas são declaradas como constante
no topo do script, nunca digitadas soltas no meio do código.

```gdscript
const LARGURA_BASE    := 720.0
const ALTURA_BASE     := 1280.0
const MARGEM_LATERAL  := 24.0

const FAIXA_TOPO      := 24.0    # HUD do oponente
const FAIXA_ARENA     := 300.0   # área 3D visível
const FAIXA_MENSAGEM  := 862.0   # balão de mensagem
const FAIXA_ACOES     := 962.0   # painel de golpes
```

## Faixas da batalha

| Faixa | Y inicial | Y final | Altura | Conteúdo |
|---|---|---|---|---|
| Topo | 24 | 120 | 96 | Nome + vida do oponente |
| Arena | 120 | 750 | 630 | Palco 3D. Zero UI aqui. |
| Aliado | 750 | 846 | 96 | Nome + vida do jogador |
| Mensagem | 862 | 938 | 76 | Texto do turno |
| Ações | 962 | 1256 | 294 | 5 golpes + defender/trocar |

Sobra 16 px entre Aliado e Mensagem e 24 px entre Mensagem e Ações. Esse
respiro é obrigatório: sem ele o retrato fica sufocado no gabinete.

## Regras que não se negociam

1. **Nada de `position` absoluto em nó filho de painel.** Use
   `MarginContainer` + `VBoxContainer`/`GridContainer`. O container calcula.
2. **O painel é `PanelContainer`, não `Panel` com `size` manual.** Assim ele
   cresce com o conteúdo em vez de cortar texto.
3. **Margem interna de 18 px em todo painel**, via
   `add_theme_constant_override("margin_left", 18)` nos quatro lados.
4. **Fonte mínima 22 px** para texto lido a um braço de distância no gabinete.
   Nome de Beast: 24. Mensagem de turno: 26. Botão de golpe: 22.
5. **Botão de golpe: altura mínima 62 px.** É toque de dedo em pé, não mouse.
6. **Área da arena fica livre de UI.** Se precisar mostrar dano ou nome flutuante
   sobre a Beast, use `Label3D` no espaço 3D, não `Control` por cima.
7. **Zero `size` fixo em Label.** `custom_minimum_size` sim, `size` não.

## Verificação automática

Adicionar a `tools/validate_project.py` uma checagem que lê as constantes de
faixa de cada script de cena e falha se duas faixas se sobrepuserem. É barato e
elimina a classe inteira de bug.

```python
FAIXAS = [("topo",24,120),("arena",120,750),("aliado",750,846),
          ("mensagem",862,938),("acoes",962,1256)]

for i in range(len(FAIXAS) - 1):
    nome_a, _, fim_a = FAIXAS[i]
    nome_b, ini_b, _ = FAIXAS[i + 1]
    assert fim_a <= ini_b, f"Faixas {nome_a} e {nome_b} se sobrepõem"
assert FAIXAS[-1][2] <= 1280, "A última faixa passa do fim da tela"
```
