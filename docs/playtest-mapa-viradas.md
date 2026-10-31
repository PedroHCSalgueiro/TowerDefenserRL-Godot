# Dificuldade e tempo no mapa com viradas (`viradas-01`)

Medição de 31/10/2026 no commit `13530c1`. Compara três mapas nas mesmas seeds: `greybox-01` (fixo, onde o Valcoroa foi balanceado), `moldes-01` (o mapa que cresce anterior, `afa7740`) e `viradas-01` (o novo). **Nenhum número de jogo foi alterado:** as sugestões abaixo são propostas para o Pedro aprovar.

## Conclusão

- **O mapa novo não deixou o jogo mais difícil.** O bot sequential perde na onda 28 e o good na 30, contra 26 e 26,5 no mapa fixo. Comparado ao `moldes-01`, muda pouco. Nenhum bot venceu as 40 ondas em nenhum dos três mapas.
- **O problema é o tempo.** A run típica foi de cerca de 15 min para 47–59 min, sem contar as pausas de loja. A partir da onda 11, cada onda leva cerca de 3× o tempo do mapa fixo no sequential e até 5× no good, e quase todo esse tempo é caminhada.
- **Há um caso grave na Forjaferro.** Com a Dra. Engrena, ondas chegam a passar de 1 hora e uma run bateu no limite de 8 horas de jogo. O motivo provável é o pulso magnético, que manda inimigos comuns de volta sem limite de distância.
- **As regiões seguem equilibradas.** Todas ficam a até 1 onda do Valcoroa, dentro da margem de 3. Nenhum ajuste de região é necessário por causa do mapa.

## Em que onda a run passa a ser perdida

"Núcleo < 50%" é a mediana da primeira onda que fecha com menos da metade da vida do núcleo. Ela vem cerca de 2 ondas antes da derrota nos bots sequential e good, e é o melhor sinal de que a run já está perdida. No stack, as duas coincidem; no lazy, a distância varia de 1 a 4 ondas.

| Bot | Mapa | Runs | Derrotas (da 1ª à última) | p10 | Mediana | p90 | Núcleo < 50% | Duração da run |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sequential | fixo | 24 | 24–28 | 25 | 26 | 27 | 25 | 15:26 |
| sequential | moldes | 24 | 25–28 | 25 | 26 | 28 | 25 | 35:14 |
| sequential | **viradas** | 24 | 25–31 | 27 | **28** | 30 | 26 | **47:29** |
| good | fixo | 32 | 20–29 | 24 | 26,5 | 28 | 25 | 13:34 |
| good | moldes | 32 | 26–33 | 27 | 30 | 32 | 28,5 | 52:18 |
| good | **viradas** | 32 | 26–32 | 28 | **30** | 31 | 27,5 | **59:28** |
| stack | fixo | 17 | 20–23 | 20 | 20 | 23 | 20 | 8:28 |
| stack | moldes | 17 | 20 | 20 | 20 | 20 | 20 | 9:48 |
| stack | **viradas** | 17 | 20 | 20 | **20** | 20 | 20 | **10:37** |
| lazy | fixo | 31 | 15–20 | 15 | 16 | 19 | 15 | 8:03 |
| lazy | moldes | 31 | 15–24 | 15 | 19 | 22 | 15 | 19:58 |
| lazy | **viradas** | 31 | 15–23 | 15 | **17** | 22 | 15 | **19:45** |

**Diferença na mesma seed (viradas menos o outro mapa, em ondas):**

| Bot | Contra o fixo | Contra o moldes |
| --- | --- | --- |
| sequential | +2,0 ± 0,7 | +1,6 ± 0,6 |
| good | +3,5 ± 0,4 | −0,4 ± 0,4 |
| stack | −0,9 ± 0,6 | 0,0 |
| lazy | +1,9 ± 0,6 | −0,3 ± 0,6 |

**Pontos de quebra nos bots:**

- **Onda 15** (primeiros voadores): 16% das runs do lazy morrem aqui no viradas, contra 45% no fixo.
- **Onda 20** (primeiro chefão): todas as runs do stack que passam da abertura morrem aqui no viradas e no moldes, e 12 de 17 no fixo. A mediana do stack é 20 em todas as regiões, então isso não é efeito do mapa. Não investiguei a causa.
- **Ondas 27–30:** é onde os bots sequential e good caem no viradas. Fecham a onda 27 63% e 91% das runs; fecham a onda 29, 17% e 59%.

As runs que morrem até a onda 3 estão fora dessas contas: 8 de 32 no sequential, 15 no stack, 1 no lazy, 0 no good. São as mesmas seeds nos três mapas. Nas seeds examinadas, o bot só comprou o Irmão Tomás, que não causa dano, então isso vem do bot, não do mapa.

## Tempo de cada onda (Valcoroa)

Mediana em segundos, só com a onda rodando. Os bots chamam a próxima na hora e as telas de recompensa e de parede congelam o tempo, então uma pessoa joga mais do que isto. O "caminho" é a mediana de casas do mapa viradas.

| Onda | Caminho (seq.) | Seq. fixo | Seq. moldes | **Seq. viradas** | Caminho (good) | Good fixo | Good moldes | **Good viradas** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 31 | 23 | 16 | **18** | 31 | 23 | 16 | **18** |
| 2 | 31 | 24 | 12 | **17** | 31 | 20 | 14 | **19** |
| 3 | 31 | 21 | 11 | **17** | 31 | 18 | 13 | **18** |
| 4 | 31 | 19 | 11 | **17** | 31 | 18 | 12 | **17** |
| 5 | 31 | 19 | 11 | **17** | 31 | 20 | 13 | **19** |
| 6 | 50 | 16 | 31 | **35** | 50 | 14 | 30 | **34** |
| 7 | 50 | 18 | 31 | **36** | 50 | 15 | 31 | **35** |
| 8 | 50 | 21 | 37 | **47** | 50 | 16 | 40 | **46** |
| 9 | 50 | 24 | 40 | **47** | 50 | 18 | 40 | **47** |
| 10 | 50 | 40 | 53 | **68** | 50 | 26 | 58 | **64** |
| 11 | 73 | 22 | 57 | **70** | 71 | 22 | 77 | **80** |
| 12 | 73 | 22 | 55 | **69** | 71 | 22 | 76 | **79** |
| 13 | 73 | 23 | 58 | **70** | 71 | 22 | 74 | **79** |
| 14 | 73 | 24 | 57 | **70** | 71 | 22 | 74 | **80** |
| 15 | 73 | 51 | 98 | **114** | 71 | 36 | 102 | **105** |
| 16 | 106 | 29 | 89 | **107** | 99 | 24 | 114 | **123** |
| 17 | 106 | 32 | 90 | **109** | 99 | 25 | 114 | **124** |
| 18 | 106 | 37 | 91 | **107** | 99 | 26 | 115 | **124** |
| 19 | 106 | 41 | 98 | **116** | 99 | 29 | 117 | **127** |
| 20 | 106 | 49 | 122 | **145** | 99 | 36 | 154 | **165** |
| 21 | 129 | 45 | 139 | **152** | 124 | 33 | 151 | **164** |
| 22 | 129 | 52 | 139 | **161** | 124 | 38 | 152 | **166** |
| 23 | 129 | 61 | 157 | **177** | 124 | 44 | 155 | **169** |
| 24 | 129 | 64 | 161 | **179** | 124 | 52 | 157 | **171** |
| 25 | 129 | 76 | 230 | **275** | 124 | 83 | 220 | **243** |
| 26 | 160 | 73 | 210 | **240** | 151 | 68 | 201 | **226** |
| 27 | 160 | 79 | 230 | **244** | 153 | 69 | 208 | **241** |
| 28 | 154 | — | — | **258** | 152 | 72 | 213 | **244** |
| 29 | 162 | — | — | **268** | 154 | — | 220 | **247** |
| 30 | 156 | — | — | **418** | 154 | — | 302 | **327** |
| 31 | — | — | — | — | 171 | — | 277 | **277** |

No fim da tabela, as amostras do viradas são pequenas: 8, 4 e 1 runs do sequential nas ondas 28, 29 e 30; 11 e 1 runs do good nas ondas 30 e 31.

- **Salto a cada parede:** o tempo sobe de degrau logo depois das ondas 5, 10, 15, 20 e 25, junto com o caminho. Dentro de um mesmo degrau, sobe pouco.
- **É caminhada:** comuns andam 1 casa/s e blindados 0,7. Na onda 26 do good, 151 casas dão de 151 a 216 s de caminhada, para 226 s medidos.
- **Ondas múltiplas de 5:** a partir da 10, levam de 25% a 63% mais que a onda anterior nos bots sequential e good.
- **Tempo até o primeiro tiro:** no good, a mediana sobe de 2–4 s no início para 20 s a partir da onda 11, 30–35 s entre as ondas 16 e 24, e 40 s ou mais a partir da 26. No sequential, fica entre 0 e 13 s. No good, esse trecho inicial da onda é tempo morto.
- **Até a vitória (estimativa):** nenhum bot chegou lá. Somando as ondas 31–40 a uns 300 s cada, uma run vitoriosa ficaria perto de 2 horas sem contar a loja.

## Escolha da parede

Forçando a parede de menos ou de mais caminho (Valcoroa, 16 seeds):

| Bot | Parede | Caminho final (mediana) | Onda da derrota | Duração |
| --- | --- | --- | --- | --- |
| sequential | menos caminho | 138 | 29 | 47:06 |
| sequential | mais caminho | 176 | 28 | 54:24 |
| good | menos caminho | 138 | 29 | 50:09 |
| good | mais caminho | 179 | 30 | 59:08 |

A escolha muda 38–41 casas e de 7 a 9 minutos, mas no máximo 1 onda. Para estes bots, ela quase não pesa na dificuldade. Os caminhos finais vão de 114 a 212 casas, dentro do esperado nos protótipos (150–210) ou um pouco abaixo.

## Regiões

Mediana da onda da derrota no sequential, 12 seeds. A margem é de até 3 ondas do Valcoroa.

| Conjunto | Fixo | Viradas | Diferença para o Valcoroa | Run fixo | Run viradas |
| --- | --- | --- | --- | --- | --- |
| valcoroa | 26 | 28 | — | 15:26 | 47:29 |
| costarubra | 24 | 27 | −1 | 14:34 | 47:24 |
| forjaferro | 26 | 29 | +1 | 18:26 | **101:06** |
| cripta | 24 | 27 | −1 | 13:59 | 44:18 |
| panteao | 25,5 | 28 | 0 | 15:43 | 48:02 |
| todas (9 seeds) | 26 | 27 | −1 | 16:42 | 47:05 |

### Forjaferro e a Dra. Engrena

Das 12 runs da Forjaferro no viradas, 6 duraram de 2 a 8 horas de jogo. Na mediana, as ondas 26 e 28 levam 819 s e 1.271 s; na run que bateu no limite de 8 h, a onda 28 sozinha levou 5.778 s.

- **Quem está nas runs lentas:** as 7 runs mais longas (80 min ou mais) têm a Dra. Engrena. Das 5 mais curtas (40–46 min), 3 terminam sem ela e 2 com dano baixo dela. Na run de 8 h, ela causou 72% do dano.
- **Mecanismo provável:** o pulso (`_magnet_pull`, `sim/triggers/trigger_effects.gd:744`) leva cada inimigo terrestre no alcance ao ponto do caminho mais perto da torre. Elites têm teto de 1 casa (`eliteMaxCells`) e chefões não se movem, mas o inimigo comum não tem limite (`sim/status/status.gd:70`). Com corredores vizinhos, esse ponto pode estar muito atrás do inimigo, e a Engrena repete isso a cada 6 s em ★3.

Essa explicação vem do código e da correlação nas runs. Não fiz um teste isolando o pulso. O mesmo efeito existe de leve no mapa fixo, onde a bancada da Engrena já era a mais longa (1.065 s).

## Bancada dos heróis

Aqui a coluna conta **ondas fechadas**: 14 significa morrer na 15, a primeira com voadores. Cada herói joga sozinho, com 4 cópias ★2 nas melhores casas da base, e 2 seeds.

| Raridade | Heróis | Mediana fixo | Mediana viradas | Fora de ±4 no viradas |
| --- | --- | --- | --- | --- |
| Comum | 15 | 14 | 17,5 | Tomás (2), Acólito (4), Amunet (4), todos Suporte |
| Incomum | 14 | 14 | 14,5 | Capitão Pena (5) e Tic (9), ambos Suporte |
| Raro | 10 | 14 | 16,75 | nenhum |
| Lendário | 1 | 15 | 18 | nenhum |

- **Os suportes são fracos sozinhos por natureza,** então nenhum herói de dano fica fora da margem.
- **Quem mais ganha:** Ferro Balisteiro (+7), Ruby e Vapora (+6), Nyx (+5,5), Wulf, Bart e Kallia (+5).
- **Quem não ganha nada:** Golem Caldeira, Greta, Golem de Ossos, Hoplita Dorian e Ciclope ficam nas mesmas ondas do mapa fixo (14).
- **A raridade inverte:** comuns (17,5) rendem mais que raros (16,75) e incomuns (14,5). No mapa fixo, quase todos empatavam em 14, então isso não aparecia.

## Sugestões de ajuste em `data/` (não aplicadas)

Nenhuma destas foi testada: os ganhos são estimados pela proporção do caminho. A ordem é a que eu tentaria. Medir uma de cada vez leva pouco tempo se for só o Valcoroa.

| # | Arquivo | Antes → depois | Efeito esperado | Risco |
| --- | --- | --- | --- | --- |
| 1 | `data/enemies.json` | velocidade: `common` 1 → 1,2; `armored` 0,7 → 0,85 (+20%) | Cerca de 15% menos tempo nas ondas de caminho longo, em todas as regiões | Menos tempo de tiro devolve parte das 2–3,5 ondas ganhas. Vale para o mapa fixo, então os golden files podem precisar de atualização. |
| 2 | `data/expansion.json`, `molds` | peso de `reto` 1 → 2; peso de `zigue` 2 → 1 | Peça média de 21,5 → 19,5 casas (−9%) | Baixo: a escolha da parede quase não mudou a dificuldade. Menos pedaços longos e sinuosos para ver. |
| 3 | `data/expansion.json`, `afterWaves` | `[5,10,15,20,25,30]` → `[5,10,15,20,30]` | Ondas 26–30 com cerca de 20% menos caminho, uns 4 min por run | Muda o ritmo de abertura que o Pedro definiu. |
| 4 | `data/waves.json` | Sem mudança por enquanto | — | Se a meta for morrer na mesma onda do mapa fixo, 2 ondas equivalem a cerca de +23% de vida (a vida cresce 11% por onda), mas isso alongaria as ondas ainda mais. Só depois de medir a 1. |

O caso da Engrena não se resolve só com números: espaçar o pulso reduz o problema, mas não limita a distância. Veja a pergunta 2.

## Perguntas de design para o Pedro

1. **Qual a duração desejada para a run?** Essa resposta decide tudo o mais. Hoje são cerca de 50–60 min até a derrota, e talvez 2 h até a vitória, sem contar a loja.
2. **O inimigo comum deve ter um teto no pulso da Engrena?** O teto já existe para elites. Estendê-lo exige uma mudança pequena em `sim/` mais uma chave nova no bloco `push` de `data/sets/heroes/towers.json`, e é a correção que eu recomendo.
3. **A escolha da parede deve pesar na dificuldade?** Hoje ela muda sobretudo o tempo. Uma pessoa pode tirar mais proveito das peças novas do que estes bots.
4. **A raridade invertida na bancada é aceitável?** No mapa longo, comuns de tiro único superam raros quando cada herói joga sozinho.

## Limites da medição

- **Bots não são pessoas:** servem para comparar mapas e regiões entre si. Os tempos não incluem as pausas de loja, e as somas das ondas são somas de medianas.
- **Interrompido a pedido, com 174 de 176 rodadas prontas:**
  - `viradas/todas/sequential-9` (3 seeds) ficou de fora, por isso "todas" tem 9 seeds. Ela já rodava há mais do dobro do tempo das parecidas; não sei o motivo.
  - `viradas/todas/bench` parou em 15 de 40 heróis. Esses 15 deram os mesmos valores das bancadas por região, então nada se perde.
- **Saúde:** 717 runs, 0 linhas de erro nos logs, 0 gatilhos descartados e 1 run sem fim (a da Forjaferro).
- **Amostras menores:** a escolha da parede usa 16 seeds (11 no sequential, sem as mortes de abertura), e a bancada, 2 seeds. Diferenças de 1 onda nessas tabelas não são conclusivas.
- **Isolamento:** a medição rodou em cópias limpas de `13530c1` e `afa7740`, só com os bots novos. Por isso, `assets/sir-aldric.glb`, `render/sir_aldric.gd`, os dois `.import` da Lyra e `dev/proto2d/` não afetam nada, e o `aacf630` não toca em `sim/`.
- **Testes:** 299 de 299 no GUT, com `aacf630` e as mudanças dos bots, incluindo `tests/test_bot_growing_map.gd`.

## O que mudou nas ferramentas

`dev/wave_bot.gd`, `dev/good_bot.gd`, `dev/playtest.gd` e `dev/hero_bench.gd` agora jogam no mapa que cresce. `dev/playtest.gd` e `dev/hero_bench.gd` aceitam `--map=growing|fixed` (padrão `growing`) e `--walls=first|longest|shortest|auto` (padrão `auto`, em que a simulação sorteia). O `WaveBot` sozinho continua no mapa fixo, porque os golden files dependem dele.

**Pendências:**

- `.claude/agents/testador.md` ainda não cita esses argumentos.
- `tools/playtest/agent.ps1` agora mede o mapa que cresce e leva bem mais tempo; este lote levou 1h52 com 10 Godots em paralelo.
- Os números de `docs/playtest-regioes.md` são do mapa fixo e não se comparam com os daqui.
- O `--demo` do `WaveBot` usa o mapa do bot, não o mapa que cresce do jogo. Vi isso lendo o código, mas não rodei.
- A abertura do bot, que às vezes só compra suporte, desperdiça até 15 de 32 seeds.
