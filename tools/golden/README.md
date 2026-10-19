# Golden files (prova de paridade com o Phaser)

`tests/golden/*.json` guardam as **saídas reais do código do Phaser** para entradas fixas
(sementes, deltas de tempo, comandos). Os testes GUT em `tests/` reproduzem as mesmas
entradas em GDScript e exigem saídas idênticas. Se um golden falha, o porte divergiu.

Os JSON são gerados por scripts TypeScript desta pasta, que importam a simulação do clone
de referência (somente leitura). Nenhum código do Phaser é copiado para este repositório.

## Regenerar

Pré-requisito (uma vez): `npm ci` em `C:\Users\pedro\Documents\TowerDefenserRL-reference`.

```powershell
cd C:\Users\pedro\Documents\TowerDefenserRL-reference
npx --yes vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_engine.ts
```

Só regenerar se o **Phaser mudar de comportamento de propósito** (`git pull` no clone de
referência), e commitar o JSON novo junto com o ajuste do porte.

## Scripts

| Script | Gera | Cobre |
| --- | --- | --- |
| `gen_engine.ts` | `rng.json`, `clock.json` | `sim/engine/rng`, `sim/engine/clock` |
| `gen_grid_sim.ts` | `grid.json`, `simulation.json` | `sim/grid/*`, `sim/engine/simulation` + `simulation_runner` (com sistema de teste; RNG reiniciado em `hashSeed`, pois o `createRunState` real já sorteia a loja) |

## Convenções

- Saídas do RNG são gravadas como inteiros de 32 bits (float × 2³², exato), para a
  comparação não depender do parser de float do JSON.
- Deltas de tempo não são gravados: ambos os lados recalculam pela mesma fórmula.
- Valores reais comparados com tolerância (`1e-9`) só onde o JS expõe float derivado (ex.: `alpha`).
