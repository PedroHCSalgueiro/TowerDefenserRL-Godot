/**
 * Gera os golden files do RNG e do relógio a partir do código do Phaser.
 *
 * NÃO faz parte do jogo: é só o gerador da "prova de paridade". Importa a
 * simulação do clone de referência (somente leitura) e grava JSON em
 * tests/golden/. O Godot reproduz as mesmas entradas e compara com estas saídas.
 *
 * Rodar (veja tools/golden/README.md):
 *   cd ..\TowerDefenserRL-reference
 *   npx vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_engine.ts
 *
 * Os números do RNG são gravados como inteiros de 32 bits (a saída bruta,
 * float * 2^32 exato), para a comparação ser exata e não depender do
 * parser de JSON para floats.
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import engineConfig from '../../../TowerDefenserRL-reference/src/data/engine.json';
import { FixedStepClock } from '../../../TowerDefenserRL-reference/src/sim/engine/clock';
import { Rng, hashSeed } from '../../../TowerDefenserRL-reference/src/sim/engine/rng';

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../../tests/golden');
mkdirSync(outDir, { recursive: true });

function write(name: string, data: unknown): void {
  writeFileSync(resolve(outDir, name), JSON.stringify(data, null, 1) + '\n');
  console.log(`gravado tests/golden/${name}`);
}

const raw = (value: number): number => value * 4294967296;

// ---------------------------------------------------------------- RNG

const SEEDS = ['', 'a', 'abc', 'Tower Defense', 'ação', '😀x', 'seed-42'];
const DRAWS = 200;

const floats = SEEDS.map((seed) => {
  const holder = { rngState: hashSeed(seed) };
  const rng = new Rng(holder);
  const values = Array.from({ length: DRAWS }, () => raw(rng.nextFloat()));
  return { seed, hash: hashSeed(seed), values, finalState: holder.rngState };
});

const INT_RANGES: [number, number][] = [
  [3, 7],
  [0, 0],
  [-5, 12],
  [1, 100],
];
const ints = INT_RANGES.map(([min, max]) => {
  const holder = { rngState: hashSeed('ints') };
  const rng = new Rng(holder);
  const values = Array.from({ length: DRAWS }, () => rng.nextInt(min, max));
  return { min, max, values, finalState: holder.rngState };
});

const chanceHolder = { rngState: hashSeed('chance') };
const chanceRng = new Rng(chanceHolder);
const chance = {
  p: 0.3,
  values: Array.from({ length: DRAWS }, () => (chanceRng.chance(0.3) ? 1 : 0)),
  finalState: chanceHolder.rngState,
};

const pickHolder = { rngState: hashSeed('pick') };
const pickRng = new Rng(pickHolder);
const pickItems = [10, 20, 30, 40, 50];
const pick = {
  items: pickItems,
  values: Array.from({ length: 100 }, () => pickRng.pick(pickItems)),
  finalState: pickHolder.rngState,
};

const shuffleHolder = { rngState: hashSeed('shuffle') };
const shuffleRng = new Rng(shuffleHolder);
const shuffleArray = Array.from({ length: 20 }, (_, i) => i);
const shuffle = {
  start: [...shuffleArray],
  results: Array.from({ length: 5 }, () => [...shuffleRng.shuffle(shuffleArray)]),
  finalState: shuffleHolder.rngState,
};

write('rng.json', { floats, ints, chance, pick, shuffle });

// -------------------------------------------------------------- Relógio
// Os deltas são recalculados dos dois lados pela mesma fórmula (nada de
// floats gravados): "const" = 1000/60; "irregular" = 7 + (i % 13);
// "spike" = 1000/60, e a cada 17º quadro 500 ms (estoura o teto por quadro).

type Pattern = 'const' | 'irregular' | 'spike';
function delta(pattern: Pattern, i: number): number {
  if (pattern === 'irregular') return 7 + (i % 13);
  if (pattern === 'spike') return i % 17 === 16 ? 500 : 1000 / 60;
  return 1000 / 60;
}

const SCENARIOS: { name: string; pattern: Pattern; frames: number; speed: number }[] = [
  { name: 'const_1x', pattern: 'const', frames: 600, speed: 1 },
  { name: 'irregular_1x', pattern: 'irregular', frames: 500, speed: 1 },
  { name: 'spike_3x', pattern: 'spike', frames: 200, speed: 3 },
  { name: 'const_debug_10x', pattern: 'const', frames: 120, speed: 10 },
];

const scenarios = SCENARIOS.map((s) => {
  const clock = new FixedStepClock(engineConfig);
  clock.setSpeed(s.speed);
  const ticks: number[] = [];
  const alphas: number[] = [];
  for (let i = 0; i < s.frames; i++) {
    ticks.push(clock.advance(delta(s.pattern, i)));
    alphas.push(clock.alpha);
  }
  return { ...s, ticks, alphas, dropped: clock.droppedTicks };
});

const cycleClock = new FixedStepClock(engineConfig);
const cycle = [cycleClock.cycleSpeed(), cycleClock.cycleSpeed(), cycleClock.cycleSpeed(), cycleClock.cycleSpeed()];
cycleClock.setSpeed(5);
cycle.push(cycleClock.cycleSpeed());

write('clock.json', {
  config: engineConfig,
  tickDurationMs: new FixedStepClock(engineConfig).tickDurationMs,
  scenarios,
  cycle,
});
