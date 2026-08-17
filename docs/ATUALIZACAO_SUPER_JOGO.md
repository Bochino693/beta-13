# Atualização visual — arena cinematográfica v8

Esta atualização trabalha sobre a base recuperada do projeto. Nenhum catálogo,
regra de dano, recarga, peso, troca, KO ou pontuação foi removido.

## Batalha

- arena enquadrada dinamicamente a partir da proporção da imagem, preservando
  horizonte, piso e profundidade dentro da faixa de batalha 720×710;
- Beast do jogador em primeiro plano, maior e com somente a vista traseira real
  recortada do atlas; oponente menor, ao fundo e sempre de frente;
- câmera `KEEP_WIDTH` com FOV 46, respiro cinematográfico e aproximação
  exclusiva para golpes pesados;
- malha contínua 32×32 para as 30 Beasts, com respiração, balanço, cabeça,
  cauda, passos, asas, flutuação e movimento aquático por família;
- ataques com gestos diferentes para avanço, voo, mergulho, varredura,
  deslocamento instantâneo e golpes que percorrem o chão;
- sombras, anéis de presença e luz elemental para os dois lutadores;
- arenas originais, piso sem malha quadriculada, público, LEDs, totens,
  holofotes e resposta luminosa ao impacto;
- 80 golpes combinando sprites transparentes com energia 3D fina, dois rastros,
  impacto persistente e geometria própria para cada elemento;
- escudo holográfico com indicação de um impacto;
- HUD compacto e legível, com 10 px entre todas as faixas.

## Interface

- MSDF global desativado para evitar deformação de acentos em texto pequeno;
- fonte de exibição e fonte de corpo separadas;
- painéis e botões arredondados, com bordas, sombra e hierarquia tipográfica;
- seleções em duas colunas, com retratos vindos da pose frontal de combate;
- fundo estável: somente partículas e iluminação se movem;
- carregamento com nova arte do portal elemental, prévia e nome da arena,
  instrução contextual, progresso real, recursos carregados, cronômetro e
  contagem 3–2–1 antes da entrada;
- instruções de teclas retiradas das telas públicas;
- abertura em engine com duas Beasts animadas, sem depender de vídeo externo.

## Hierarquia elemental

As rivalidades principais são mútuas: Luz ↔ Escuridão, Fogo ↔ Água,
Terra ↔ Vento e Natureza ↔ Choque. Cada elemento possui exatamente duas forças
e duas fraquezas; a fonte única da regra é `CreatureDB.STRONG_AGAINST`.

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
