/**
 * Golden files dos inimigos (enemies.json): rota do mapa do jogo, armadura e
 * dados. Ver tools/golden/README.md.
 *
 *   cd ..\TowerDefenserRL-reference
 *   npx --yes vite-node ..\TowerDefenserRL-Godot\tools\golden\gen_enemies.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import mapData from '../../../TowerDefenserRL-reference/src/data/map.json';
import { applyArmor } from '../../../TowerDefenserRL-reference/src/sim/enemies/armor';
import { enemyData } from '../../../TowerDefenserRL-reference/src/sim/enemies/enemyData';
import { buildRoutes } from '../../../TowerDefenserRL-reference/src/sim/enemies/route';
import { loadMap, type MapData } from '../../../TowerDefenserRL-reference/src/sim/grid/map';

const outDir = resolve(dirname(fileURLToPath(import.meta.url)), '../../tests/golden');
mkdirSync(outDir, { recursive: true });

const map = loadMap(mapData as MapData);
const routes = buildRoutes(map);

// Floats do JS vão como TEXTO com o padrão de bits IEEE-754 (int64 em decimal):
// o parser de JSON do Godot não garante o último bit de um float.
const view = new DataView(new ArrayBuffer(8));
const exact = (v: number): string => {
  view.setFloat64(0, v);
  return BigInt.asIntN(64, view.getBigUint64(0)).toString();
};

function sampleRoute(kind: 'ground' | 'air'): { length: string; samples: [string, string, string][] } {
  const route = routes[kind];
  const samples: [string, string, string][] = [];
  const out = { x: 0, y: 0 };
  // Distâncias de 0,137 em 0,137 (não alinhadas às casas) até além do fim.
  for (let d = -0.5; d <= route.length + 1; d += 0.137) {
    route.sampleInto(d, out);
    samples.push([exact(d), exact(out.x), exact(out.y)]);
  }
  return { length: exact(route.length), samples };
}

const armorCases = [
  [30, 50, 100],
  [10, 100, 100],
  [10, 100, 50],
  [1, 10000, 100],
  [7.3, 30, 100],
  [12, 0, 100],
].map(([raw, armor, scale]) => ({ raw, armor, scale, result: exact(applyArmor(raw!, armor!, { scale: scale! })) }));

writeFileSync(
  resolve(outDir, 'enemies.json'),
  JSON.stringify({ routes: { ground: sampleRoute('ground'), air: sampleRoute('air') }, armorCases }) + '\n',
);
console.log('gravado tests/golden/enemies.json');
console.log('tipos:', Object.keys(enemyData.types).join(', '));
