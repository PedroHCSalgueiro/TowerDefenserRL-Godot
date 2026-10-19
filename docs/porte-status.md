# Status do porte (Phaser/TS → Godot/GDScript)

Atualizado em 2026-10-18. Plano geral: `plano-porte-godot.md`.

## Fase 0 — Preparação ✅
Repo, Git LFS, CLAUDE.md, projeto Godot 4.7.2, GUT 9.7.1, CI.

## Fase 1 — Simulação ✅ (paridade total com o Phaser)

Todo `src/sim/` do Phaser está portado para `sim/` (GDScript, sem nós). A prova de paridade são os
**golden files** (`tests/golden/*.json`, gerados por `tools/golden/*.ts` a partir do código do Phaser):

| Golden | O que prova |
| --- | --- |
| `rng.json`, `clock.json` | RNG (mulberry32/FNV-1a) e relógio de passo fixo, bit a bit |
| `grid.json`, `enemies.json` | mapa, vizinhança, rotas (inclui o `Math.hypot` do V8), armadura |
| `simulation.json` | motor (Simulation/Runner) |
| `runs.json` | 4 runs completas de 40 ondas (2 bots × com/sem derrota): relatório de cada onda, histograma de eventos, estado final (RNG, ids, torres, recompensas) idênticos |
| `scenarios.json` | cenários de debug: 16 torres de 8 tipos em ★1/★2/★3 contra hordas (até ~34 mil eventos), ondas tardias, loja/fusão/venda/mover/núcleo, recompensas |

Mapa dos módulos (TS → GDScript): `engine/*` → `sim/engine/*`; `grid/*` → `sim/grid/{sim_map,neighbors}`;
`enemies/*` → `sim/enemies/*`; `spatial` → `sim/spatial/spatial_index`; `projectiles/*` → `sim/projectiles/*`;
`towers/*` → `sim/towers/*`; `triggers/*` → `sim/triggers/*`; `classes/*` → `sim/classes/*`;
`economy/*`, `shop/*`, `nexus/*`, `waves/*`, `rewards/*` → pastas de mesmo nome; `state/commands/systems` →
`sim/{run_state,commands,game_systems}`; `debug/*` → `sim/debug/*`.

### Cuidados numéricos descobertos
- Posições são `float` (64 bits), nunca `Vector2` (32 bits).
- `Math.hypot` do V8 usa soma compensada: `SimMath.hypot`.
- `Math.round` arredonda o meio para cima: `SimMath.js_round`.
- `sort` do JS é estável; `sort_custom` do Godot não: desempate explícito quando há empate possível.
- JSON do Godot traz números como `float`; `Array.has(2.0)` não acha `2`.

### Ainda não portado da Fase 1
- Testes unitários finos do Phaser para triggers/fusion/shop/economy/waves/rewards/classes (a paridade das runs
  e dos cenários cobre o comportamento; portar os unitários melhora a localização de falhas).

## Fase 2 — Render 3D + câmera ✅
Câmera ortográfica 45°/45° (,  = porte de camera.ts), grade, torres, núcleo, inimigos e
projéteis em MultiMesh, barras de vida em shader billboard, efeitos de gatilho, hover e preview de ligação ().

## Fase 3 — UI ✅
Loja, HUD de ondas, painéis do núcleo e das classes, tooltip, drag de torres, tutorial, tela de recompensa, ajuda (H),
fim de run + relatório, rótulo de versão e painel de debug/perf (F2). Lógica em modelos puros (), nós em
Controls montados no código ().  é a cena principal.
Fonte de símbolos: a DejaVu Sans entra como reserva () porque o export Web não tem fontes do sistema.

## Fase 4 — Save ✅
 /  (, versão de save = ).
O parser de JSON do Godot não devolve o mesmo double em ~17% dos números de 17 dígitos, então todo float vai como texto
com os bits IEEE-754 (). : restaurar no meio da run e continuar dá os mesmos eventos e o
mesmo estado final que não ter parado. Ainda falta: gravar/ler em  pelo jogo (autosave) e migração entre versões.

## Fase 5 — Exports e CI ✅ (parcial)
Presets Windows e Web (sem threads),  (testes) e  (exporta e guarda os artefatos). Falta o deploy
(Pages) e medir os critérios do plano no web.

## Fase 6 — Arte e personagens
Fora do escopo atual (Sir Aldric, redução de glb/texturas, GodotSteam).

## Desempenho (GDScript)
~16 s para 40 ondas de bot sem renderização (Phaser: ~0,7 s). Estresse (cenário ): ~4,6 ms/tick em média,
picos de 40–60 ms; o Web é mais lento. Perfil por sistema em .
