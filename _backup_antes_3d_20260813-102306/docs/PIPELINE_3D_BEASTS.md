# Pipeline real: ilustração 2D para Beast 3D

Uma imagem frontal não contém a geometria escondida das costas. Nenhum botão
consegue recuperar essa informação com fidelidade absoluta. O processo correto
usa a arte atual como **design**, reconstrói volume e depois cria esqueleto e
animação.

## 1. Folha multivista

Para cada Beast, produzir frente, perfil, costas e 3/4 com proporções iguais.
O arquivo `assets/model_references/pyrocondor_turnaround_v1.png` demonstra o
formato. A vista traseira precisa decidir penas, cauda, asas e pontos de união
que não aparecem na ilustração original.

## 2. Malha-base

Há dois caminhos válidos:

1. modelagem no Blender sobre as vistas ortográficas, com melhor controle; ou
2. reconstrução image-to-3D para obter uma base, seguida obrigatoriamente de
   correção no Blender.

Ferramentas image-to-3D podem acelerar o bloco inicial, mas não substituem
retopologia, correção das costas, UV, materiais ou rig. Para testar localmente,
os projetos oficiais [Hunyuan3D-2](https://github.com/Tencent-Hunyuan/Hunyuan3D-2)
e [TripoSR](https://github.com/VAST-AI-Research/TripoSR) são referências abertas.

## 3. Retopologia e materiais

- silhueta precisa ser reconhecível de frente, perfil e costas;
- 25 mil a 60 mil triângulos por Beast é uma faixa inicial razoável para o
  gabinete; criar LOD se o estádio tiver público mais pesado;
- separar partes que deformam: mandíbula, cauda, asas, orelhas e placas;
- manter uma textura base, normal e emissão; o núcleo elemental usa emissão;
- preservar transparência apenas onde for indispensável.

## 4. Esqueleto e animações

Rig mínimo: raiz, pelve/centro, coluna, cabeça, mandíbula, membros, cauda e
cadeias de asa quando existirem. Criaturas sem pernas usam uma raiz flutuante.

Clipes obrigatórios:

| Clipe | Função |
|---|---|
| `Idle` | respiração, asas, cauda ou flutuação |
| `AttackLight` | golpe rápido/técnico |
| `AttackHeavy` | carga e liberação pesada |
| `Hit` | impacto e recuperação |
| `DodgeLeft` / `DodgeRight` | troca de posição |
| `Win` | comemoração |
| `KO` | derrota |

As animações devem ficar em loop apenas no `Idle`. Não animar o deslocamento
global de esquiva dentro do clipe: o jogo move a raiz entre as três posições.

## 5. Exportação e importação

Exportar glTF binário (`.glb`), aplicar escala e rotação e incluir malha,
materiais, esqueleto e animações. O Godot recomenda glTF 2.0 para cenas 3D;
consulte a [documentação oficial de importação 3D](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html).

Salvar em `assets/models/beasts/<id>/<id>.glb`. O jogo detecta o arquivo sem
alterar a batalha. A frente do modelo aponta para `-Z`; assim a câmera vê as
costas reais da Beast do jogador e a frente da adversária.

## 6. Validação

```text
python tools/validate_3d_pipeline.py
python tools/validate_3d_pipeline.py --release
python tools/validate_project.py
python tools/simulate_balance.py
```

O primeiro comando aceita proxies de desenvolvimento. `--release` falha até
que as 30 GLBs finais existam e o manifesto esteja marcado como `ready`.
