/**
 * Gera os golden files do mapa/vizinhança (grid.json) e do motor da simulação
 * (simulation.json) a partir do código do Phaser. Ver tools/golden/README.md.
 *
 *   cd ..\TowerDefenserRL-reference
 *   npx --yes vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_grid_sim.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import mapData from '../../../TowerDefenserRL-reference/src/data/map.json';
import { hashSeed } from '../../../TowerDefenserRL-reference/src/sim/engine/rng';
import { Simulation, SimulationRunner, type System } from '../../../TowerDefenserRL-reference/src/sim/engine/simulation';
import { loadMap, type MapData } from '../../../TowerDefenserRL-reference/src/sim/grid/map';
import { neighbors } from '../../../TowerDefenserRL-reference/src/sim/grid/neighbors';

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../../tests/golden');
mkdirSync(outDir, { recursive: true });

function write(name: string, data: unknown): void {
  writeFileSync(resolve(outDir, name), JSON.stringify(data) + '\n');
  console.log(`gravado tests/golden/${name}`);
}

// ---------------------------------------------------------------- Grade

const small: MapData = {
  id: 'small',
  width: 5,
  height: 4,
  path: [
    { x: 0, y: 1 },
    { x: 3, y: 1 },
    { x: 3, y: 3 },
    { x: 1, y: 3 },
  ],
};

const maps = [small, mapData as MapData].map((data) => {
  const map = loadMap(data);
  let buildable = '';
  for (let y = 0; y < map.height; y++) {
    for (let x = 0; x < map.width; x++) buildable += map.canPlaceTower({ x, y }) ? '1' : '0';
  }
  return {
    data,
    pathCells: map.pathCells.map((c) => [c.x, c.y]),
    entrance: [map.entrance.x, map.entrance.y],
    nexus: [map.nexus.x, map.nexus.y],
    buildable,
  };
});

// Vizinhas de todas as casas do mapa do jogo, na ordem das casas (y externo, x interno).
const gameMap = loadMap(mapData as MapData);
const cellNeighbors = (mode: 4 | 8): number[][][] => {
  const all: number[][][] = [];
  for (let y = 0; y < gameMap.height; y++) {
    for (let x = 0; x < gameMap.width; x++) {
      all.push(neighbors(gameMap, { x, y }, mode).map((c) => [c.x, c.y]));
    }
  }
  return all;
};

write('grid.json', {
  maps,
  neighbors: { map: mapData, '4': cellNeighbors(4), '8': cellNeighbors(8) },
});

// ------------------------------------------------------- Motor da simulação
// Mesmo sistema de teste de tests/simulation.test.ts: consome o RNG, aloca ids
// e reage à ação `spawnEnemy`.
const testSystem: System = (ctx) => {
  for (const command of ctx.commands) {
    if (command.type === 'spawnEnemy') {
      ctx.emit({ type: 'enemySpawned', tick: ctx.state.tick, enemyId: ctx.allocateId(), enemyType: 'common' });
    }
  }
  if (ctx.rng.chance(0.3)) {
    ctx.emit({ type: 'enemySpawned', tick: ctx.state.tick, enemyId: ctx.allocateId(), enemyType: 'common' });
  }
};

// `Simulation.create` usa o RunState real, cujo `createRunState` já sorteia a primeira
// loja com o RNG. Para isolar só o motor, o estado volta ao ponto de partida do
// TestRunState do Godot: RNG = hash da semente, ids a partir de 1. O golden do
// estado completo (loja inclusa) vem com o porte do RunState.
function createEngineSim(seed: string, systems: System[]): Simulation {
  const sim = Simulation.create(seed, systems);
  const state = sim.state as { rngState: number; nextEntityId: number };
  state.rngState = hashSeed(seed);
  state.nextEntityId = 1;
  return sim;
}

function runWithActions(sim: Simulation, ticks: number): [number, number][] {
  const events: [number, number][] = [];
  for (let i = 0; i < ticks; i++) {
    if (sim.state.tick % 7 === 0) sim.enqueue({ type: 'spawnEnemy', enemyType: 'common' });
    sim.step();
    for (const e of sim.drainEvents()) {
      if (e.type === 'enemySpawned') events.push([e.tick, e.enemyId]);
    }
  }
  return events;
}

const runs = [
  { seed: 'seed-1', ticks: 500 },
  { seed: 'seed-2', ticks: 200 },
  { seed: 'Tower Defense', ticks: 1000 },
].map(({ seed, ticks }) => {
  const sim = createEngineSim(seed, [testSystem]);
  const events = runWithActions(sim, ticks);
  return {
    seed,
    ticks,
    events,
    tick: sim.state.tick,
    rngState: sim.state.rngState,
    nextEntityId: sim.state.nextEntityId,
  };
});

// Relógio + simulação: o delta de cada quadro é numerador/denominador (nada de
// float gravado). 300 quadros de 1000/60 a 1x e 50 de 2000/60 a 3x devem chegar ao mesmo estado.
const config = { ticksPerSecond: 30, speeds: [1, 2, 3], maxTicksPerFrame: 1000 };
const RUNNERS = [
  { name: 'slow_1x', seed: 'speed', speed: 1, frames: 300, deltaNumerator: 1000, deltaDenominator: 60 },
  { name: 'fast_3x', seed: 'speed', speed: 3, frames: 50, deltaNumerator: 2000, deltaDenominator: 60 },
];
const runners = RUNNERS.map((r) => {
  const runner = new SimulationRunner(createEngineSim(r.seed, [testSystem]), config);
  runner.clock.setSpeed(r.speed);
  for (let i = 0; i < r.frames; i++) runner.update(r.deltaNumerator / r.deltaDenominator);
  return {
    ...r,
    tick: runner.sim.state.tick,
    rngState: runner.sim.state.rngState,
    nextEntityId: runner.sim.state.nextEntityId,
  };
});

write('simulation.json', { runs, runners, config });
