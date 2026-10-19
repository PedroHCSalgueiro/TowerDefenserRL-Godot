/**
 * Golden files de cenários de debug: torres de todos os tipos, em ★1, ★2 e ★3, contra hordas, com
 * comandos agendados por tick. Exercita todos os gatilhos (disparo múltiplo, explosão, ativar
 * vizinhas, raio em cadeia, perfurante, execução, copiar) e as pausas de recompensa. Os comandos
 * vão no próprio JSON, e o Godot os repete exatamente.
 *
 *   cd ..\TowerDefenserRL-reference
 *   npx --yes vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_scenarios.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import mapData from '../../../TowerDefenserRL-reference/src/data/map.json';
import { Simulation } from '../../../TowerDefenserRL-reference/src/sim/engine/simulation';
import { loadMap } from '../../../TowerDefenserRL-reference/src/sim/grid/map';
import type { SimCommand } from '../../../TowerDefenserRL-reference/src/sim/state';
import { createGameSystems } from '../../../TowerDefenserRL-reference/src/sim/systems';

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../../tests/golden');
mkdirSync(outDir, { recursive: true });
const map = loadMap(mapData);

const EIGHT = ['mortar', 'reaper', 'relay', 'obelisk', 'ballista', 'clock', 'executioner', 'mirror'];

interface Scenario {
  name: string;
  seed: string;
  ticks: number;
  /** [tick em que enfileirar, comando]. */
  commands: [number, SimCommand][];
}

function chain(star: number): Scenario {
  return {
    name: `cadeia_8_tipos_estrela_${star}`,
    seed: `cadeia-${star}`,
    ticks: 1800,
    commands: [
      [0, { type: 'debugSetNexusInvulnerable', value: true }],
      [0, { type: 'debugSpawnTowers', count: 16, towerTypes: EIGHT, layout: 'clustered', star }],
      [0, { type: 'debugSetStress', stress: { count: 400, layout: 'spread' } }],
      [600, { type: 'debugSpawnEnemies', count: 300, enemyType: null, layout: 'clustered' }],
    ],
  };
}

const SCENARIOS: Scenario[] = [
  chain(1),
  chain(2),
  chain(3),
  {
    name: 'ondas_tardias_estrela_3',
    seed: 'tardias',
    ticks: 3600,
    commands: [
      [0, { type: 'debugSetNexusInvulnerable', value: true }],
      [0, { type: 'debugAddGold', amount: 5000 }],
      [0, { type: 'debugSkipToWave', wave: 20 }],
      [1, { type: 'debugSpawnTowers', count: 20, towerTypes: EIGHT, layout: 'spread', star: 3 }],
      [2, { type: 'callWave' }],
      [900, { type: 'callWave' }],
      [1800, { type: 'callWave' }],
    ],
  },
  {
    name: 'loja_fusao_venda_mover_nucleo',
    seed: 'loja-1',
    ticks: 1200,
    commands: [
      [0, { type: 'debugAddGold', amount: 1000 }],
      [1, { type: 'buyTower', slot: 0, x: 3, y: 3 }],
      [2, { type: 'buyTower', slot: 1, x: 4, y: 3 }],
      [3, { type: 'rerollShop' }],
      [4, { type: 'buyTower', slot: 2, x: 5, y: 3 }],
      [5, { type: 'buyTower', slot: 0 }],
      [6, { type: 'buyTower', slot: 1 }],
      [7, { type: 'evolveNexus' }],
      [8, { type: 'evolveNexus' }],
      [9, { type: 'moveTower', towerId: 1, x: 6, y: 4 }],
      [10, { type: 'sellTower', towerId: 2 }],
      [11, { type: 'callWave' }],
      [30, { type: 'callWave' }],
      [60, { type: 'moveTower', towerId: 1, x: 7, y: 4 }],
      [600, { type: 'endWave' }],
    ],
  },
  {
    name: 'recompensas_debug',
    seed: 'recompensa-1',
    ticks: 1500,
    commands: [
      [0, { type: 'debugAddGold', amount: 500 }],
      [1, { type: 'debugOpenReward' }],
      [5, { type: 'rerollRewards' }],
      [10, { type: 'chooseReward', index: 1 }],
      [20, { type: 'debugOpenReward' }],
      [400, { type: 'debugOpenReward' }],
    ],
  },
];

function play(s: Scenario) {
  const sim = Simulation.create(s.seed, createGameSystems(map));
  const tally: Record<string, number> = {};
  const byTick = new Map<number, SimCommand[]>();
  for (const [tick, cmd] of s.commands) byTick.set(tick, [...(byTick.get(tick) ?? []), cmd]);
  for (let tick = 0; tick < s.ticks; tick++) {
    for (const cmd of byTick.get(tick) ?? []) sim.enqueue(cmd);
    sim.step();
    for (const e of sim.drainEvents()) tally[e.type] = (tally[e.type] ?? 0) + 1;
  }
  const st = sim.state;
  console.log(`${s.name}: tick ${st.tick}, status ${st.status}, ${Object.values(tally).reduce((a, b) => a + b, 0)} eventos`);
  return {
    name: s.name,
    seed: s.seed,
    ticks: s.ticks,
    commands: s.commands,
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
      towers: st.towers.map((t) => [t.id, t.type, t.star, t.x, t.y, t.invested, t.charges, t.triggerCounter, t.cooldownTicks]),
      triggers: { nextSeq: st.triggers.nextSeq, nextChainId: st.triggers.nextChainId, queued: st.triggers.queue.length, dropped: st.triggers.droppedTotal },
      enemies: st.enemies.activeCount,
      projectiles: st.projectiles.activeCount,
      shop: st.shop,
      rewards: { taken: st.rewards.taken, open: st.rewards.screen !== null, queue: st.rewards.queue, rngState: st.rewards.rngState },
      classes: Object.fromEntries(Object.entries(st.classes).map(([id, c]) => [id, [c.level, c.members]])),
    },
  };
}

writeFileSync(resolve(outDir, 'scenarios.json'), JSON.stringify({ scenarios: SCENARIOS.map(play) }) + '\n');
console.log('gravado tests/golden/scenarios.json');
