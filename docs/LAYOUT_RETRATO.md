# Layout retrato 720×1280 — grade de faixas

## O bug corrigido

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

A causa não era apenas um valor errado. Era o método: posição absoluta em `Control` solto,
sem container e sem âncora. Qualquer troca de fonte ou de texto reabre o
problema.

## Regra

Toda tela é dividida em **faixas verticais exclusivas**. Um elemento vive dentro
de uma faixa e não pode cruzar a fronteira. Faixas são declaradas como constante
no topo do script, nunca digitadas soltas no meio do código.

```gdscript
const Y_TOPO          := 12.0
const Y_HUD_INIMIGO   := 58.0
const Y_ARENA         := 140.0
const Y_HUD_ALIADO    := 888.0
const Y_MENSAGEM      := 970.0
const Y_ACOES         := 1018.0
```

## Faixas da batalha

| Faixa | Y inicial | Y final | Altura | Conteúdo |
|---|---|---|---|---|
| Topo | 12 | 48 | 36 | Turno + placar |
| Oponente | 58 | 130 | 72 | Nome, elemento, vida e reservas |
| Arena | 140 | 878 | 738 | Estádio 3D, lutadores e impacto |
| Aliado | 888 | 960 | 72 | Nome, elemento, vida e reservas |
| Mensagem | 970 | 1008 | 38 | Texto do turno |
| Ações | 1018 | 1256 | 238 | Detalhe + 5 golpes + escudo/troca |

Todas as fronteiras têm 10 px de respiro. A arena cresceu sem invadir o HUD;
os dois lutadores ocupam diagonais diferentes para nunca se esconderem.

## Regras que não se negociam

1. **Nada de `position` absoluto em nó filho de painel.** Use
   `MarginContainer` + `VBoxContainer`/`GridContainer`. O container calcula.
2. **O painel é `PanelContainer`, não `Panel` com `size` manual.** Assim ele
   cresce com o conteúdo em vez de cortar texto.
3. **Margem interna de 18 px em todo painel**, via
   `add_theme_constant_override("margin_left", 18)` nos quatro lados.
4. **Hierarquia tipográfica explícita.** Nome, vida, dano, poder e recarga
   permanecem legíveis mesmo com os painéis compactos.
5. **Botão de golpe: altura mínima 50 px.** O grid de três colunas e a faixa
   de detalhe preservam dano, poder e recarga sem esconder a arena.
6. **Área da arena fica livre de UI.** Se precisar mostrar dano ou nome flutuante
   sobre a Beast, use `Label3D` no espaço 3D, não `Control` por cima.
7. **Zero `size` fixo em Label.** `custom_minimum_size` sim, `size` não.

## Verificação automática

Adicionar a `tools/validate_project.py` uma checagem que lê as constantes de
faixa de cada script de cena e falha se duas faixas se sobrepuserem. É barato e
elimina a classe inteira de bug.

```python
FAIXAS = [("topo",12,48),("oponente",58,130),("arena",140,878),
          ("aliado",888,960),("mensagem",970,1008),("acoes",1018,1256)]

for i in range(len(FAIXAS) - 1):
    nome_a, _, fim_a = FAIXAS[i]
    nome_b, ini_b, _ = FAIXAS[i + 1]
    assert fim_a <= ini_b, f"Faixas {nome_a} e {nome_b} se sobrepõem"
assert FAIXAS[-1][2] <= 1280, "A última faixa passa do fim da tela"
```
