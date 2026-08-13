# Modelos 3D das Beasts

Cada modelo final fica em:

```text
assets/models/beasts/<id>/<id>.glb
```

Exemplo:

```text
assets/models/beasts/pyrocondor/pyrocondor.glb
```

Contrato obrigatório:

- escala em metros, eixo vertical `+Y` e frente apontando para `-Z`;
- origem no centro do chão entre os pés ou sob o corpo flutuante;
- malha com UV, materiais PBR e esqueleto;
- animações `Idle`, `AttackLight`, `AttackHeavy`, `Hit`, `Win`, `KO`,
  `DodgeLeft` e `DodgeRight`;
- marcadores opcionais `FX_Origin` e `Hit_Target`;
- sem plano com retrato frontal, sem billboard e sem imagens de outras marcas.

Enquanto um arquivo não existe, o jogo constrói um proxy volumétrico real da
família anatômica. O proxy deixa arena, câmera, esquiva e golpes testáveis, mas
não deve ser confundido com a arte final.
