// Relatório do playtest em lote: lê os JSON de `dev/playtest.gd` e escreve um resumo em Markdown.
//   node tools/playtest/report.js <pasta-com-os-json> [saida.md]
const fs = require('fs');
const path = require('path');

const dir = process.argv[2];
const outPath = process.argv[3];
if (!dir) { console.error('uso: node report.js <pasta> [saida.md]'); process.exit(1); }

const runs = [];
for (const f of fs.readdirSync(dir)) {
  if (f.endsWith('.json')) runs.push(...JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8')));
}
const policies = [...new Set(runs.map((r) => r.policy))];

const sum = (a) => a.reduce((x, y) => x + y, 0);
const mean = (a) => (a.length ? sum(a) / a.length : 0);
const sorted = (a) => [...a].sort((x, y) => x - y);
const pct = (a, p) => { const s = sorted(a); return s.length ? s[Math.min(s.length - 1, Math.floor(p * s.length))] : 0; };
const fmt = (n, d = 0) => Number(n).toLocaleString('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d });
const mmss = (s) => { const t = Math.round(s); return `${Math.floor(t / 60)}min${String(t % 60).padStart(2, "0")}s`; };
const TOTAL_WAVES = 40;
const HEROES = ['aldric', 'lyra', 'tomas', 'brom', 'selene', 'wulf', 'mabel', 'isolde'];
const NAMES = { aldric: 'Sir Aldric', lyra: 'Lyra', tomas: 'Irmão Tomás', brom: 'Mestre Brom', selene: 'Dama Selene', wulf: 'Wulf', mabel: 'Engenheira Mabel', isolde: 'Rainha Isolde' };

function table(head, rows) {
  const line = (cells) => `| ${cells.join(' | ')} |`;
  return [line(head), line(head.map(() => '---')), ...rows.map(line)].join('\n');
}

const out = [];
const P = (s = '') => out.push(s);

P('# Playtest do Reino de Valcoroa (bots)');
P();
P(`${runs.length} runs completas, ${policies.map((p) => `${runs.filter((r) => r.policy === p).length} "${p}"`).join(' e ')}. Gerado por \`tools/playtest/report.js\`.`);
P();
P('- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.');
P('- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)');
P('- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.');
P();

for (const policy of policies) {
  const rs = runs.filter((r) => r.policy === policy);
  P(`## Política: ${policy}`);
  P();
  const won = rs.filter((r) => r.outcome === 'won').length;
  const lost = rs.filter((r) => r.outcome === 'lost').length;
  const timeout = rs.filter((r) => r.outcome === 'timeout').length;
  const waves = rs.map((r) => r.wave);
  P(`**Resultado:** ${won} vitórias, ${lost} derrotas, ${timeout} sem fim (${fmt((100 * won) / rs.length)}% de vitória).`);
  P(`**Onda alcançada:** média ${fmt(mean(waves), 1)} · mediana ${pct(waves, 0.5)} · p10 ${pct(waves, 0.1)} · p90 ${pct(waves, 0.9)} (de ${TOTAL_WAVES}).`);
  const secs = rs.map((r) => r.seconds);
  P(`**Duração da run:** média ${mmss(mean(secs))} · mediana ${mmss(pct(secs, 0.5))} · mais curta ${mmss(Math.min(...secs))} · mais longa ${mmss(Math.max(...secs))}.`);
  P();

  // Onde as runs terminam
  const endWave = {};
  for (const r of rs) if (r.outcome !== 'won') endWave[r.wave + 1] = (endWave[r.wave + 1] || 0) + 1;
  const hist = Object.entries(endWave).sort((a, b) => b[1] - a[1]).slice(0, 8);
  if (hist.length) {
    P('**Em que onda a run acaba (derrotas):** ' + hist.map(([w, n]) => `onda ${w}: ${n}`).join(' · ') + '.');
    P();
  }

  // Duração por onda
  const durationByWave = {};
  for (const r of rs) {
    for (const w of Object.keys(r.waveStartTick)) {
      if (r.waveEndTick[w] !== undefined) (durationByWave[w] ||= []).push((r.waveEndTick[w] - r.waveStartTick[w]) / 30);
    }
  }
  const brackets = [[1, 5], [6, 10], [11, 15], [16, 20], [21, 25], [26, 30], [31, 35], [36, 40]];
  P('### Duração de cada onda, ouro guardado e torres, por faixa de ondas');
  P();
  const rows = brackets.map(([a, b]) => {
    const dur = []; const gold = []; const towers = []; const hp = [];
    for (let w = a; w <= b; w++) {
      dur.push(...(durationByWave[w] || []));
      for (const r of rs) {
        if (r.waveStartGold[w] !== undefined) { gold.push(r.waveStartGold[w]); towers.push(r.waveStartTowers[w]); }
        if (r.waveNexusHp[w] !== undefined) hp.push(r.waveNexusHp[w]);
      }
    }
    return [`${a}–${b}`, dur.length ? `${fmt(mean(dur))} s` : '—', gold.length ? fmt(mean(gold)) : '—',
      gold.length ? fmt(pct(gold, 0.9)) : '—', towers.length ? fmt(mean(towers), 1) : '—', hp.length ? fmt(mean(hp), 1) : '—'];
  });
  P(table(['Ondas', 'Duração média da onda', 'Ouro guardado (média)', 'Ouro guardado (p90)', 'Torres', 'Vida do núcleo ao fim'], rows));
  P();

  // Ouro
  P('### Ouro');
  P();
  const earned = mean(rs.map((r) => r.goldEarned));
  const comp = [['Abates', mean(rs.map((r) => r.killGold))], ['Bônus de fim de onda', mean(rs.map((r) => r.bonusGold))],
    ['Juros', mean(rs.map((r) => r.interestGold))], ['Chamada antecipada', mean(rs.map((r) => r.earlyGold))], ['Cadeia lucrativa', mean(rs.map((r) => r.chainGold))]];
  P(`Ouro ganho por run: média ${fmt(earned)} (mediana ${fmt(pct(rs.map((r) => r.goldEarned), 0.5))}). Sobra no fim: média ${fmt(mean(rs.map((r) => r.goldFinal)))}; maior pico guardado: média ${fmt(mean(rs.map((r) => r.maxGold)))}, máximo ${fmt(Math.max(...rs.map((r) => r.maxGold)))}.`);
  P();
  P(table(['De onde vem', 'Ouro por run', '% do total'], comp.map(([n, v]) => [n, fmt(v), `${fmt((100 * v) / earned, 1)}%`])));
  P();
  P(`Núcleo evoluído até o nível ${fmt(mean(rs.map((r) => r.nexusLevel)), 1)} em média; compras: ${fmt(mean(rs.map((r) => sum(Object.values(r.purchases)))), 1)} torres, ${fmt(mean(rs.map((r) => r.merges)), 1)} fusões e ${fmt(mean(rs.map((r) => r.rerolls)), 1)} rerolls por run.`);
  if (policy === 'stack') {
    P(`Chamadas antecipadas por run: ${fmt(mean(rs.map((r) => r.earlyCalls)), 1)} · ondas ativas ao chamar: ${fmt(mean(rs.flatMap((r) => r.activeWavesAtCall)), 2)} em média, máximo ${Math.max(...rs.flatMap((r) => r.activeWavesAtCall))}.`);
  }
  P();

  // Torres
  P('### Torres: dano, abates e uso');
  P();
  const trows = HEROES.map((h) => {
    const dmg = rs.map((r) => r.damageByType[h] || 0);
    const present = rs.filter((r) => (r.towerWaves[h] || 0) > 0);
    const totalTW = sum(rs.map((r) => r.towerWaves[h] || 0));
    const totalStar = sum(rs.map((r) => r.starWaves[h] || 0));
    const shots = sum(rs.map((r) => r.shotsByType[h] || 0));
    const kills = sum(rs.map((r) => r.killsByType[h] || 0));
    const totalDmg = sum(dmg);
    return { h, dmg: totalDmg, share: 0, perTW: totalTW ? totalDmg / totalTW : 0, kills, shots, presence: present.length / rs.length,
      starAvg: totalTW ? totalStar / totalTW : 0, perShot: shots ? totalDmg / shots : 0, buys: mean(rs.map((r) => r.purchases[h] || 0)), tw: totalTW };
  });
  const allDmg = sum(rs.map((r) => r.totalDamage));
  const allKills = sum(rs.map((r) => r.kills));
  for (const t of trows) t.share = t.dmg / allDmg;
  const avgPerTW = mean(trows.filter((t) => t.tw).map((t) => t.perTW));
  P(table(['Herói', '% do dano', '% dos abates', 'Dano por torre por onda', 'vs. média', 'Dano por tiro', 'Estrela média', 'Compras/run', 'Presente em'],
    trows.map((t) => [NAMES[t.h], `${fmt(100 * t.share, 1)}%`, `${fmt((100 * t.kills) / allKills, 1)}%`, fmt(t.perTW), `${fmt(t.perTW / avgPerTW, 2)}×`,
      fmt(t.perShot, 1), fmt(t.starAvg, 2), fmt(t.buys, 1), `${fmt(100 * t.presence)}% das runs`])));
  P();
  P('"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.');
  P();

  // Raridades: quando aparecem na prática
  const RAR = [['common', 'Comum'], ['uncommon', 'Incomum'], ['rare', 'Raro'], ['legendary', 'Lendário']];
  P('**Raridades compradas:** ' + RAR.map(([k, n]) => {
    const firsts = rs.map((r) => (r.firstBuyWave || {})[k]).filter((x) => x !== undefined);
    const buys = mean(rs.map((r) => (r.buysByRarity || {})[k] || 0));
    return firsts.length
      ? `${n}: ${fmt(buys, 1)} por run, primeira compra na onda ${fmt(mean(firsts), 1)} em média (a mais cedo: ${Math.min(...firsts)})`
      : `${n}: nenhuma`;
  }).join(' · ') + '.');
  P();

  // Inimigos
  const ke = {};
  for (const r of rs) for (const [t, n] of Object.entries(r.killsByEnemy)) ke[t] = (ke[t] || 0) + n;
  P('Abates por tipo de inimigo (por run): ' + Object.entries(ke).map(([t, n]) => `${t} ${fmt(n / rs.length)}`).join(' · ') + `. Pico de inimigos no mapa: média ${fmt(mean(rs.map((r) => r.peakEnemies)))}, máximo ${Math.max(...rs.map((r) => r.peakEnemies))}.`);
  P();
}

const text = out.join('\n') + '\n';
if (outPath) fs.writeFileSync(outPath, text);
console.log(text);
