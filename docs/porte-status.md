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
Câmera ortográfica 45°/45° (`GroundProjection`, `CameraModel` = porte de camera.ts), grade, torres, núcleo, inimigos e
projéteis em MultiMesh, barras de vida em shader billboard, efeitos de gatilho, hover e preview de ligação (`render/`).

## Fase 3 — UI ✅
Loja, HUD de ondas, painéis do núcleo e das classes, tooltip, drag de torres, tutorial, tela de recompensa, ajuda (H),
fim de run + relatório, rótulo de versão e painel de debug/perf (F2). Lógica em modelos puros (`ui/*_model.gd`), nós em
Controls montados no código (`UiKit`). `scenes/game.tscn` é a cena principal.
Fonte de símbolos: a DejaVu Sans entra como reserva (`FontSetup`) porque o export Web não tem fontes do sistema.

## Fase 4 — Save ✅
`Simulation.serialize()` / `Simulation.restore(text, systems, map)` (`RunStateIO`, versão de save = `RunState.VERSION`).
O parser de JSON do Godot não devolve o mesmo double em ~17% dos números de 17 dígitos, então todo float vai como texto
com os bits IEEE-754 (`SaveCodec`). `tests/test_save.gd`: restaurar no meio da run e continuar dá os mesmos eventos e o
mesmo estado final que não ter parado. Ainda falta: gravar/ler em `user://` pelo jogo (autosave) e migração entre versões.

## Fase 5 — Exports e CI ✅ (parcial)
Presets Windows e Web (sem threads), `ci.yml` (testes) e `build.yml` (exporta e guarda os artefatos). Falta o deploy
(Pages) e medir os critérios do plano no web.

## Fase 6 — Arte e personagens
Fora do escopo atual (Sir Aldric, redução de glb/texturas, GodotSteam).

## Desempenho (GDScript)
~16 s para 40 ondas de bot sem renderização (Phaser: ~0,7 s). Estresse (`--open=stress`): ~4,6 ms/tick em média,
picos de 40–60 ms; o Web é mais lento. Perfil por sistema em `dev/profile_systems.gd`.

## Conjuntos de torres e Reino de Valcoroa (novo, além do porte)
- **Tela inicial** (`scenes/menu.tscn`, cena principal): escolhe o conjunto da run (Padrão ou Reino de Valcoroa) e a
  semente. `--set=valcoroa` e `--play` pulam a tela (capturas e testes).
- **Conjuntos** (`GameSets`): `data/sets/<id>/` complementa `data/` (mescla em profundidade; `"$replace": true` troca o
  arquivo inteiro). O Padrão não muda nada e continua provado pelos golden files.
- **Valcoroa**: 8 heróis do Notion (Sir Aldric, Lyra, Irmão Tomás, Mestre Brom, Dama Selene, Wulf, Engenheira Mabel,
  Rainha Isolde), as 8 classes novas (ainda sem bônus de classe, só a contagem) e o bônus do Reino (3/5/8).
- **Mecânicas novas**: efeitos de estado (Lento que empilha até 50%, Atordoado, Sangramento), aura de velocidade,
  armadilhas no caminho, gatilho por tempo (`everyNSeconds`), mira `strongest`, `onHit`, perfurante com teto de alvos.
- **Números de Valcoroa são provisórios**: o Notion só dá exemplos; ★2 e ★3 de cada herói foram inventados como ponto
  de partida e estão em `data/sets/valcoroa/towers.json` (ver "Perguntas de design" no Notion).
