// Relatório do agente testador: lê a pasta de `tools/playtest/agent.ps1` (uma subpasta por conjunto, com os
// JSON do playtest em lote e o `bench.json` da bancada) e escreve o resumo de balanço em Markdown, com as
// marcações de "forte demais" e "fraco demais".
//   node tools/playtest/agent_report.js <pasta> [saida.md]
//
// Regras das marcações (ajustáveis aqui embaixo, em LIMITS):
// - Região: a onda mediana (sequential) longe da do Reino de Valcoroa, a referência já balanceada.
// - Herói na bancada (sozinho, mesmas casas): onda alcançada longe da mediana dos heróis da mesma raridade.
//   Suporte e quem depende de vizinhas (aura, "vizinha abate", "ao ser ativado") não são marcados como fracos.
// - Herói nas runs: dano por torre por onda muito acima ou abaixo da média do conjunto.
const fs = require('fs');
const path = require('path');

const LIMITS = {
  regionWaves: 3, // onda mediana do conjunto vs. Valcoroa (sequential)
  benchWaves: 4, // onda da bancada vs. mediana da mesma raridade
  dominantShare: 2.0, // dano por torre por onda vs. média do conjunto
  weakShare: 0.4,
};
const REFERENCE = 'valcoroa';

const dir = process.argv[2];
const outPath = process.argv[3];
if (!dir) { console.error('uso: node agent_report.js <pasta> [saida.md]'); process.exit(1); }

const sum = (a) => a.reduce((x, y) => x + y, 0);
const mean = (a) => (a.length ? sum(a) / a.length : 0);
const median = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? (s.length % 2 ? s[(s.length - 1) / 2] : (s[s.length / 2 - 1] + s[s.length / 2]) / 2) : 0; };
const fmt = (n, d = 0) => Number(n).toLocaleString('pt-BR', { minimumFractionDigits: d, maximumFractionDigits: d });
const table = (head, rows) => [head, head.map(() => '---'), ...rows].map((c) => `| ${c.join(' | ')} |`).join('\n');
const RARITY = { common: 'Comum', uncommon: 'Incomum', rare: 'Raro', legendary: 'Lendário' };

const sets = fs.readdirSync(dir).filter((d) => fs.statSync(path.join(dir, d)).isDirectory());
const data = {};
const names = {};
const errors = [];
for (const set of sets) {
  const d = path.join(dir, set);
  const runs = [];
  let bench = [];
  for (const f of fs.readdirSync(d)) {
    const full = path.join(d, f);
    if (f === 'bench.json') bench = JSON.parse(fs.readFileSync(full, 'utf8'));
    else if (f.endsWith('.json')) runs.push(...JSON.parse(fs.readFileSync(full, 'utf8')));
    else if (f.endsWith('.log') || f.endsWith('.err')) {
      const lines = fs.readFileSync(full, 'utf8').split(/\r?\n/).filter((l) => /SCRIPT ERROR|^ERROR|Parse Error/.test(l));
      if (lines.length) errors.push(`${set}/${f}: ${lines.length} erro(s), o primeiro: \`${lines[0].trim().slice(0, 160)}\``);
    }
  }
  for (const b of bench) names[b.hero] = b.name;
  data[set] = { runs, bench };
}

const out = [];
const P = (s = '') => out.push(s);
P('# Relatório do agente testador');
P();
P(`Gerado por \`tools/playtest/agent_report.js\` a partir de \`${path.basename(dir)}\`. Os bots não jogam como uma pessoa: servem para comparar regiões e heróis entre si. A referência é o Reino de Valcoroa (já balanceado com o Pedro).`);
P();

// ---------------------------------------------------------------- regiões
const policyStats = (runs, policy) => {
  const rs = runs.filter((r) => r.policy === policy);
  return { n: rs.length, median: median(rs.map((r) => r.wave)), mean: mean(rs.map((r) => r.wave)),
    won: rs.filter((r) => r.outcome === 'won').length, timeouts: rs.filter((r) => r.outcome === 'timeout').length };
};
const ref = data[REFERENCE] ? policyStats(data[REFERENCE].runs, 'sequential') : null;
const flags = [];
P('## Conjuntos');
P();
const setRows = [];
for (const set of sets) {
  const { runs } = data[set];
  if (!runs.length) continue;
  const seq = policyStats(runs, 'sequential');
  const stk = policyStats(runs, 'stack');
  let flag = '';
  if (ref && set !== REFERENCE && seq.n) {
    const diff = seq.median - ref.median;
    if (diff <= -LIMITS.regionWaves) flag = `fraco (${fmt(diff, 1)} ondas)`;
    if (diff >= LIMITS.regionWaves) flag = `forte (+${fmt(diff, 1)} ondas)`;
    if (flag) flags.push(`**Conjunto ${set}:** ${flag} em relação ao Valcoroa (mediana ${fmt(seq.median, 1)} contra ${fmt(ref.median, 1)}).`);
  }
  if (seq.timeouts + stk.timeouts > 0) errors.push(`${set}: ${seq.timeouts + stk.timeouts} run(s) sem fim (o teto de 1 hora de jogo).`);
  const dropped = sum(runs.map((r) => r.droppedTriggers || 0));
  if (dropped) errors.push(`${set}: ${dropped} gatilho(s) descartado(s) nas runs.`);
  setRows.push([set, `${seq.n}`, fmt(seq.median, 1), `${fmt((100 * seq.won) / Math.max(1, seq.n))}%`, fmt(stk.median, 1),
    `${fmt((100 * stk.won) / Math.max(1, stk.n))}%`, flag || '—']);
}
P(table(['Conjunto', 'Runs por política', 'Onda mediana (sequential)', 'Vitórias (sequential)', 'Onda mediana (stack)', 'Vitórias (stack)', 'Marcação'], setRows));
P();

// ---------------------------------------------------------------- bancada
const benchAll = sets.filter((s) => s !== 'todas' && s !== 'valcoroa_costarubra').flatMap((s) => data[s].bench);
const byRarity = {};
for (const b of benchAll) (byRarity[b.rarity] ||= []).push(b.wave);
const rarityMedian = Object.fromEntries(Object.entries(byRarity).map(([r, w]) => [r, median(w)]));

// Dano por torre por onda nas runs (sequential) de cada conjunto de região.
const perTW = {};
const impact = {};
for (const set of sets) {
  const rs = data[set].runs.filter((r) => r.policy === 'sequential');
  if (!rs.length) continue;
  const heroes = new Set(rs.flatMap((r) => Object.keys(r.towerWaves || {})));
  const rows = [];
  for (const h of heroes) {
    const tw = sum(rs.map((r) => (r.towerWaves || {})[h] || 0));
    const dmg = sum(rs.map((r) => (r.damageByType || {})[h] || 0));
    rows.push({ h, value: tw ? dmg / tw : 0, tw });
    // Impacto: onda média das runs em que o herói ficou no mapa por pelo menos 5 ondas, contra as outras.
    const withH = rs.filter((r) => ((r.towerWaves || {})[h] || 0) >= 5).map((r) => r.wave);
    const without = rs.filter((r) => ((r.towerWaves || {})[h] || 0) < 5).map((r) => r.wave);
    if (withH.length && without.length) (impact[set] ||= {})[h] = mean(withH) - mean(without);
  }
  const avg = mean(rows.filter((r) => r.tw).map((r) => r.value));
  perTW[set] = Object.fromEntries(rows.map((r) => [r.h, avg ? r.value / avg : 0]));
}

P('## Heróis');
P();
P(`Bancada: cada herói sozinho, 4 cópias em ★2 nas mesmas casas, ondas uma a uma até perder. "vs. raridade" = diferença para a mediana dos heróis da mesma raridade (todas as regiões). "Dano/torre/onda" = dano do herói ÷ (cópias no mapa somadas em cada onda), relativo à média do conjunto da região, nas runs sequential. "Impacto" = onda média das runs em que o herói ficou ao menos 5 ondas no mapa, menos a das outras (ruidoso com poucas runs).`);
P();
for (const set of sets) {
  const bench = data[set].bench;
  if (!bench.length || set === 'todas' || set === 'valcoroa_costarubra') continue;
  P(`### ${set}`);
  P();
  const rows = bench.map((b) => {
    const diff = b.wave - (rarityMedian[b.rarity] || b.wave);
    const share = (perTW[set] || {})[b.hero];
    const imp = (impact[set] || {})[b.hero];
    const marks = [];
    const support = b.class === 'support' || b.needsNeighbors;
    if (diff >= LIMITS.benchWaves) marks.push('forte demais sozinho');
    if (diff <= -LIMITS.benchWaves && !support) marks.push('fraco sozinho');
    if (share !== undefined && share >= LIMITS.dominantShare) marks.push('domina o dano');
    if (share !== undefined && share > 0 && share <= LIMITS.weakShare && !support) marks.push('quase não causa dano');
    for (const m of marks) flags.push(`**${b.name}** (${set}, ${RARITY[b.rarity]}, ${b.className}): ${m} — bancada onda ${fmt(b.wave, 1)} (${diff >= 0 ? '+' : ''}${fmt(diff, 1)}), dano/torre/onda ${share !== undefined ? fmt(share, 2) + '×' : '—'}.`);
    return [b.name, b.className, RARITY[b.rarity], fmt(b.wave, 1), `${diff >= 0 ? '+' : ''}${fmt(diff, 1)}`, fmt(b.damage), fmt(b.kills),
      share !== undefined ? `${fmt(share, 2)}×` : '—', imp !== undefined ? `${imp >= 0 ? '+' : ''}${fmt(imp, 1)}` : '—',
      (b.dropped ? `descartou ${b.dropped} gatilhos; ` : '') + (marks.join(', ') || (support ? 'depende de vizinhas' : '—'))];
  });
  P(table(['Herói', 'Classe', 'Raridade', 'Bancada (onda)', 'vs. raridade', 'Dano', 'Abates', 'Dano/torre/onda', 'Impacto', 'Marcação'], rows));
  P();
}

// ---------------------------------------------------------------- resumo
P('## O que pede ajuste');
P();
if (flags.length) for (const f of flags) P(`- ${f}`); else P('Nada marcado: todos os conjuntos e heróis dentro dos limites.');
P();
P('## Erros e travamentos');
P();
if (errors.length) for (const e of errors) P(`- ${e}`); else P('Nenhum: nenhum erro nos logs, nenhuma run sem fim e nenhum gatilho descartado.');
P();
P(`Limites: região ±${LIMITS.regionWaves} ondas da mediana do Valcoroa; bancada ±${LIMITS.benchWaves} ondas da mediana da raridade; dano por torre por onda acima de ${LIMITS.dominantShare}× ou abaixo de ${LIMITS.weakShare}× a média do conjunto.`);

const text = out.join('\n') + '\n';
if (outPath) fs.writeFileSync(outPath, text);
console.log(text);
