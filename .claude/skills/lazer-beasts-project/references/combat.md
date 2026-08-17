# Contrato de combate

## Catálogos

- Oito elementos: Luz, Escuridão, Fogo, Choque, Terra, Água, Natureza e Vento.
- Rivalidades mútuas: Luz ↔ Escuridão, Fogo ↔ Água, Terra ↔ Vento e Natureza ↔ Choque.
- Cada elemento possui exatamente duas forças e duas fraquezas; a tabela oficial vive em `CreatureDB.STRONG_AGAINST` e nunca deve ser duplicada em cenas.
- Dez golpes por elemento; índices 1–8 são rápidos/técnicos/controle e 9–10 são pesados.
- Cada Beast recebe quatro golpes do elemento primário e uma cobertura técnica contra fraqueza.
- Entre os cinco golpes há exatamente um pesado, sempre do elemento primário.
- Pesado tem teto de poder 50 e recarga alta; não pode encerrar luta sozinho.

## Classes de peso

| Classe | Multiplicador de recarga | Bônus de HP | Multiplicador de dano |
|---|---:|---:|---:|
| Ultra Leve | 0,70 | 0 | 1,08 |
| Leve | 0,82 | +8 | 1,05 |
| Médio | 1,00 | +16 | 1,00 |
| Pesado | 1,16 | +22 | 0,96 |
| Colossal | 1,30 | +24 | 0,92 |

HP máximo: `145 + resistência × 1,55 + bônus de peso`.

O peso concede sobrevivência, mas reduz dano e aumenta o tempo para reutilizar golpes. As classes leves fazem a troca inversa. Não aumentar simultaneamente HP e dano fora desses limites.

Executar `python tools/simulate_balance.py` depois de alterar atributos, afinidades, golpes ou classes. A referência atual usa 8.700 duelos: nenhuma Beast pode ficar abaixo de 24% ou acima de 76%, e a diferença total não pode exceder 50 pontos percentuais.

## Turnos e recarga

- Todos os cinco golpes começam prontos.
- Após usar, gravar `cooldown_base × multiplicador_de_peso`.
- Reduzir 1,0 apenas quando a vez daquele lutador voltar.
- Defender reduz o próximo dano para 48%.
- Trocar preserva HP e recargas do lutador que saiu.

## CPU

A CPU deve considerar apenas informações disponíveis ao jogador:

1. golpes prontos;
2. dano previsto e vantagem do elemento;
3. recarga efetiva;
4. possibilidade de nocaute;
5. vida baixa para troca/defesa.

Não dar dano, cooldown ou conhecimento oculto especial à CPU.
