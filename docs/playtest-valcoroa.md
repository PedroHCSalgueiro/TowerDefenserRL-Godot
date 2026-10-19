# Playtest do Reino de Valcoroa (bots)

200 runs completas, 100 "sequential" e 100 "stack". Gerado por `tools/playtest/report.js`.

- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.
- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)
- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.

## Política: sequential

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 34,7 · mediana 35 · p10 32 · p90 37 (de 40).
**Duração da run:** média 23min42s · mediana 23min56s · mais curta 18min00s · mais longa 28min47s.

**Em que onda a run acaba (derrotas):** onda 35: 26 · onda 37: 24 · onda 36: 17 · onda 38: 13 · onda 34: 8 · onda 33: 5 · onda 32: 4 · onda 30: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 23 s | 4 | 7 | 1,9 | 17,8 |
| 6–10 | 27 s | 9 | 19 | 4,4 | 27,0 |
| 11–15 | 28 s | 15 | 46 | 7,3 | 40,1 |
| 16–20 | 33 s | 41 | 99 | 10,0 | 52,9 |
| 21–25 | 42 s | 86 | 181 | 12,4 | 66,5 |
| 26–30 | 51 s | 187 | 392 | 14,4 | 76,1 |
| 31–35 | 70 s | 339 | 662 | 16,2 | 69,0 |
| 36–40 | 82 s | 339 | 793 | 17,7 | 40,4 |

### Ouro

Ouro ganho por run: média 4.542 (mediana 4.595). Sobra no fim: média 557; maior pico guardado: média 904, máximo 1.268.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 2.755 | 60,6% |
| Bônus de fim de onda | 1.546 | 34,0% |
| Juros | 241 | 5,3% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 13,4 em média; compras: 29,5 torres, 41,8 fusões e 43,1 rerolls por run.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 15,0% | 26,4% | 998 | 0,70× | 19,3 | 2,63 | 3,8 | 99% das runs |
| Lyra | 19,9% | 30,2% | 1.375 | 0,96× | 16,7 | 2,61 | 3,6 | 100% das runs |
| Irmão Tomás | 1,8% | 3,4% | 126 | 0,09× | 3,4 | 2,62 | 3,7 | 100% das runs |
| Mestre Brom | 26,1% | 13,6% | 4.180 | 2,91× | 58,1 | 2,44 | 3,5 | 98% das runs |
| Dama Selene | 8,9% | 10,8% | 719 | 0,50× | 10,8 | 2,62 | 4,4 | 100% das runs |
| Wulf | 16,5% | 5,4% | 1.393 | 0,97× | 21,9 | 2,63 | 4,5 | 100% das runs |
| Engenheira Mabel | 7,0% | 5,8% | 1.143 | 0,80× | 0,0 | 2,45 | 3,6 | 98% das runs |
| Rainha Isolde | 4,7% | 4,4% | 1.543 | 1,08× | 17,2 | 2,30 | 2,6 | 87% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

**Raridades compradas:** Comum: 11,0 por run, primeira compra na onda 1,0 em média (a mais cedo: 1) · Incomum: 8,9 por run, primeira compra na onda 9,4 em média (a mais cedo: 7) · Raro: 7,0 por run, primeira compra na onda 18,1 em média (a mais cedo: 10) · Lendário: 2,6 por run, primeira compra na onda 26,9 em média (a mais cedo: 18).

Abates por tipo de inimigo (por run): armored 125 · boss 1 · common 465 · fast 201 · flying 139. Pico de inimigos no mapa: média 71, máximo 99.

## Política: stack

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 24,9 · mediana 26 · p10 24 · p90 27 (de 40).
**Duração da run:** média 9min50s · mediana 10min02s · mais curta 1min42s · mais longa 11min37s.

**Em que onda a run acaba (derrotas):** onda 27: 30 · onda 28: 19 · onda 25: 18 · onda 26: 18 · onda 20: 5 · onda 29: 3 · onda 30: 3 · onda 24: 2.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 26 s | 3 | 7 | 1,7 | 16,8 |
| 6–10 | 30 s | 10 | 23 | 4,1 | 26,8 |
| 11–15 | 36 s | 23 | 55 | 6,7 | 39,5 |
| 16–20 | 43 s | 48 | 95 | 9,8 | 53,2 |
| 21–25 | 59 s | 99 | 192 | 11,8 | 58,1 |
| 26–30 | 72 s | 175 | 329 | 13,7 | 35,4 |
| 31–35 | — | 275 | 460 | 15,0 | — |
| 36–40 | — | — | — | — | — |

### Ouro

Ouro ganho por run: média 1.981 (mediana 2.032). Sobra no fim: média 193; maior pico guardado: média 356, máximo 537.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 1.016 | 51,3% |
| Bônus de fim de onda | 870 | 43,9% |
| Juros | 95 | 4,8% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 10,5 em média; compras: 23,1 torres, 31,5 fusões e 4,2 rerolls por run.
Chamadas antecipadas por run: 24,1 · ondas ativas ao chamar: 2,47 em média, máximo 6.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 23,8% | 36,6% | 438 | 0,81× | 17,2 | 2,59 | 4,6 | 98% das runs |
| Lyra | 30,5% | 38,1% | 574 | 1,07× | 15,3 | 2,57 | 4,5 | 98% das runs |
| Irmão Tomás | 3,7% | 5,2% | 66 | 0,12× | 3,2 | 2,57 | 4,8 | 100% das runs |
| Mestre Brom | 12,0% | 4,8% | 1.258 | 2,34× | 41,0 | 2,01 | 1,4 | 74% das runs |
| Dama Selene | 9,6% | 8,4% | 328 | 0,61× | 10,3 | 2,35 | 3,2 | 96% das runs |
| Wulf | 14,9% | 2,8% | 574 | 1,07× | 20,9 | 2,33 | 2,9 | 97% das runs |
| Engenheira Mabel | 3,9% | 2,7% | 466 | 0,87× | 0,0 | 1,90 | 1,1 | 73% das runs |
| Rainha Isolde | 1,4% | 1,1% | 599 | 1,11× | 16,8 | 1,64 | 0,5 | 33% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

**Raridades compradas:** Comum: 14,0 por run, primeira compra na onda 1,0 em média (a mais cedo: 1) · Incomum: 6,1 por run, primeira compra na onda 9,7 em média (a mais cedo: 7) · Raro: 2,5 por run, primeira compra na onda 17,6 em média (a mais cedo: 9) · Lendário: 0,5 por run, primeira compra na onda 23,0 em média (a mais cedo: 17).

Abates por tipo de inimigo (por run): armored 52 · boss 1 · common 238 · fast 90 · flying 68. Pico de inimigos no mapa: média 77, máximo 105.


## Leitura (raridade por onda, 4 raridades, ouro mais curto)

Comparado com a rodada anterior (`playtest-valcoroa-rodada3.md`): vitória clássica 10% → 0%, onda média 38,2 → 34,7, ouro ganho por run 20.364 → 4.542, ouro guardado nas ondas 36–40 2.327 → 339, núcleo nível 18,9 → 13,4, duração 27,5 → 23,7 min.

- **Raridade por onda funciona:** a primeira compra de incomum fica na onda ~9, a de raro na ~18 e a de lendário na ~27. As compras mais cedo (incomum na 7, raro na 10, lendário na 18) vêm da carta de recompensa "Loja melhor", que empurra uma faixa.
- **O acúmulo de ouro acabou** (pico máximo 1.268), mas a renda ficou curta para os bots: eles chegam a 14 torres na onda 26–30 (antes 18). Bots são mais fracos que uma pessoa; use a sensação de jogo para decidir se a curva está dura demais.
- **Brom** ainda é ~2,9× a média por cópia, mas a parte dele no dano total caiu para 26% (os comuns carregam mais no começo). **Isolde** (lendária) rende 1,1× por cópia e aparece em 87% das runs.
- Se ficar duro demais, os botões estão em `data/sets/valcoroa/economy.json`: `waveBonus` (8 + 2 por onda) e `killGold.waveStep` (10; com 5 o ouro por abate sobe duas vezes mais rápido).
