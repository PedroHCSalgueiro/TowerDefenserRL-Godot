/**
 * Golden files de runs completas (paridade da simulação inteira): joga o bot do Phaser em runs
 * com semente fixa e grava o relatório de cada onda, o histograma de eventos e um resumo do
 * estado final. O Godot joga a mesma run com o porte do bot e deve chegar aos mesmos números.
 *
 *   cd ..\TowerDefenserRL-reference
 *   npx --yes vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_runs.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { Simulation } from '../../../TowerDefenserRL-reference/src/sim/engine/simulation';
import { goodBotBreak, goodBotReward } from '../../../TowerDefenserRL-reference/tests/support/goodBot';
import { botBreak, botSim, firstReward, playRun } from '../../../TowerDefenserRL-reference/tests/support/waveBot';

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../../tests/golden');
mkdirSync(outDir, { recursive: true });

interface Scenario {
  name: string;
  bot: 'wave' | 'good';
  seed: string;
  invulnerable: boolean;
}

const SCENARIOS: Scenario[] = [
  { name: 'wave_invulneravel', bot: 'wave', seed: 'paridade-1', invulnerable: true },
  { name: 'wave_normal', bot: 'wave', seed: 'paridade-2', invulnerable: false },
  { name: 'good_invulneravel', bot: 'good', seed: 'paridade-3', invulnerable: true },
  { name: 'good_normal', bot: 'good', seed: 'paridade-4', invulnerable: false },
];

function run(s: Scenario) {
  const sim: Simulation = botSim(s.seed, s.invulnerable);
  // Conta TODOS os eventos drenados pelo bot (o Godot conta nos mesmos pontos).
  const tally: Record<string, number> = {};
  const drain = sim.drainEvents.bind(sim);
  sim.drainEvents = () => {
    const events = drain();
    for (const e of events) tally[e.type] = (tally[e.type] ?? 0) + 1;
    return events;
  };
  const started = Date.now();
  const reports =
    s.bot === 'good'
      ? playRun(sim, goodBotBreak, goodBotReward)
      : playRun(sim, botBreak, firstReward);
  const st = sim.state;
  console.log(`${s.name}: ${reports.length} ondas, status ${st.status}, ${Date.now() - started} ms`);
  return {
    ...s,
    reports,
    tally,
    final: {
      tick: st.tick,
      rngState: st.rngState,
      nextEntityId: st.nextEntityId,
      status: st.status,
      cheated: st.cheated,
      gold: st.gold,
      wave: st.wave,
      nexus: st.nexus,
      stats: st.stats,
      towers: st.towers.map((t) => [t.id, t.type, t.star, t.x, t.y, t.invested]),
      rewardsTaken: st.rewards.taken.map((r) => [r.id, r.classId, r.wave]),
      droppedTotal: st.triggers.droppedTotal,
    },
  };
}

writeFileSync(resolve(outDir, 'runs.json'), JSON.stringify({ scenarios: SCENARIOS.map(run) }) + '\n');
console.log('gravado tests/golden/runs.json');
