# Instruções para agentes

Ao trabalhar neste projeto, usar a skill `.claude/skills/lazer-beasts-project/SKILL.md` e ler as referências indicadas por ela. Esses arquivos são o contrato de visão, combate, assets e cartas.

Antes de concluir qualquer alteração, executar:

```text
python tools/validate_project.py
python tools/simulate_balance.py
```

Não reintroduzir criaturas SVG, layout horizontal ou regras duplicadas dentro de scripts de cena.
