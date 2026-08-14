# Atualização visual — arena cinematográfica

Esta atualização trabalha sobre a base recuperada do projeto. Nenhum catálogo,
regra de dano, recarga, peso, troca, KO ou pontuação foi removido.

## Batalha

- arena ampliada para 738 px dentro do retrato 720×1280;
- aliado embaixo à esquerda e oponente acima à direita, sem sobreposição;
- câmera estável com enquadramento diagonal e zoom exclusivo para golpes pesados;
- 30 atlas V4 8×8, com 1.920 quadros e vistas reais de frente e de costas;
- oito idles e sequências completas de ataque leve/pesado, dano, esquiva,
  vitória, KO e guarda por família;
- sombras, anéis de presença e luz elemental para os dois lutadores;
- três arenas originais, piso sem malha quadriculada, público, LEDs, totens,
  holofotes e resposta luminosa ao impacto;
- 80 spritesheets de golpes viajando em arco e explodindo sobre o alvo;
- escudo holográfico com indicação de um impacto;
- HUD compacto e legível, com 10 px entre todas as faixas.

## Interface

- MSDF global desativado para evitar deformação de acentos em texto pequeno;
- fonte de exibição e fonte de corpo separadas;
- painéis e botões arredondados, com bordas, sombra e hierarquia tipográfica;
- seleções em duas colunas, com retratos vindos da pose frontal de combate;
- fundo estável: somente partículas e iluminação se movem;
- instruções de teclas retiradas das telas públicas;
- abertura em engine com duas Beasts animadas, sem depender de vídeo externo.

## Verificação

Execute na raiz do projeto:

```text
python tools/validar_layout.py
python tools/verificar_batalha.py
python tools/validate_project.py
python tools/simulate_balance.py
```

O teste visual final precisa ser feito no Godot 4.6, executando o projeto em
720×1280.
