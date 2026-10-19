# Playtest do Reino de Valcoroa (bots)

200 runs completas, 100 "sequential" e 100 "stack". Gerado por `tools/playtest/report.js`.

- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.
- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)
- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.

## Política: sequential

**Resultado:** 2 vitórias, 98 derrotas, 0 sem fim (2% de vitória).
**Onda alcançada:** média 37,4 · mediana 38 · p10 36 · p90 39 (de 40).
**Duração da run:** média 27min34s · mediana 27min38s · mais curta 21min40s · mais longa 33min05s.

**Em que onda a run acaba (derrotas):** onda 39: 30 · onda 38: 25 · onda 40: 19 · onda 37: 17 · onda 36: 6 · onda 35: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 22 s | 4 | 9 | 2,2 | 18,8 |
| 6–10 | 25 s | 9 | 19 | 5,8 | 33,2 |
| 11–15 | 26 s | 25 | 74 | 9,7 | 49,2 |
| 16–20 | 30 s | 114 | 256 | 13,0 | 66,5 |
| 21–25 | 41 s | 290 | 598 | 15,9 | 83,5 |
| 26–30 | 53 s | 668 | 1.190 | 18,3 | 96,6 |
| 31–35 | 74 s | 1.315 | 2.243 | 20,5 | 102,8 |
| 36–40 | 94 s | 2.098 | 3.439 | 22,3 | 70,6 |

### Ouro

Ouro ganho por run: média 18.601 (mediana 18.926). Sobra no fim: média 3.119; maior pico guardado: média 4.419, máximo 6.677.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 15.798 | 84,9% |
| Bônus de fim de onda | 2.457 | 13,2% |
| Juros | 347 | 1,9% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 18,6 em média; compras: 40,3 torres, 58,1 fusões e 53,9 rerolls por run.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 5,3% | 10,4% | 967 | 0,76× | 18,2 | 2,40 | 1,7 | 86% das runs |
| Lyra | 7,7% | 12,9% | 1.486 | 1,17× | 17,9 | 2,42 | 1,7 | 81% das runs |
| Irmão Tomás | 0,8% | 1,7% | 153 | 0,12× | 3,7 | 2,34 | 1,6 | 85% das runs |
| Mestre Brom | 34,9% | 20,6% | 3.696 | 2,92× | 70,0 | 2,60 | 4,6 | 100% das runs |
| Dama Selene | 6,2% | 9,3% | 647 | 0,51× | 9,8 | 2,60 | 4,6 | 100% das runs |
| Wulf | 11,3% | 4,8% | 1.148 | 0,91× | 19,6 | 2,59 | 4,8 | 99% das runs |
| Engenheira Mabel | 16,7% | 15,4% | 1.026 | 0,81× | 0,0 | 2,74 | 10,7 | 100% das runs |
| Rainha Isolde | 17,1% | 24,8% | 1.019 | 0,80× | 15,3 | 2,74 | 10,8 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 157 · boss 1 · common 564 · fast 253 · flying 176 · bossFinal 0. Pico de inimigos no mapa: média 96, máximo 115.

## Política: stack

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 30,0 · mediana 30 · p10 28 · p90 32 (de 40).
**Duração da run:** média 11min36s · mediana 11min39s · mais curta 10min27s · mais longa 12min45s.

**Em que onda a run acaba (derrotas):** onda 31: 26 · onda 32: 22 · onda 30: 19 · onda 33: 13 · onda 29: 11 · onda 28: 4 · onda 34: 4 · onda 27: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 24 s | 4 | 9 | 1,9 | 18,5 |
| 6–10 | 24 s | 19 | 40 | 5,6 | 35,0 |
| 11–15 | 25 s | 56 | 118 | 9,7 | 53,2 |
| 16–20 | 32 s | 158 | 315 | 12,9 | 70,6 |
| 21–25 | 49 s | 378 | 672 | 15,6 | 85,8 |
| 26–30 | 71 s | 677 | 1.244 | 17,9 | 81,9 |
| 31–35 | 86 s | 924 | 1.771 | 19,7 | 48,4 |
| 36–40 | — | 1.457 | 2.341 | 21,1 | — |

### Ouro

Ouro ganho por run: média 9.385 (mediana 9.490). Sobra no fim: média 1.105; maior pico guardado: média 1.949, máximo 3.189.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 7.539 | 80,3% |
| Bônus de fim de onda | 1.635 | 17,4% |
| Juros | 211 | 2,2% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 16,4 em média; compras: 34,8 torres, 48,6 fusões e 9,5 rerolls por run.
Chamadas antecipadas por run: 28,6 · ondas ativas ao chamar: 2,46 em média, máximo 8.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 9,8% | 18,6% | 410 | 0,74× | 17,7 | 2,51 | 3,6 | 100% das runs |
| Lyra | 16,6% | 25,2% | 750 | 1,35× | 18,8 | 2,50 | 3,3 | 100% das runs |
| Irmão Tomás | 1,6% | 2,8% | 66 | 0,12× | 3,6 | 2,45 | 3,4 | 99% das runs |
| Mestre Brom | 35,1% | 19,4% | 1.558 | 2,80× | 59,6 | 2,48 | 4,4 | 99% das runs |
| Dama Selene | 6,6% | 8,5% | 305 | 0,55× | 9,8 | 2,46 | 4,3 | 99% das runs |
| Wulf | 11,0% | 3,2% | 547 | 0,98× | 20,5 | 2,44 | 4,0 | 100% das runs |
| Engenheira Mabel | 9,6% | 8,4% | 397 | 0,71× | 0,0 | 2,50 | 6,2 | 100% das runs |
| Rainha Isolde | 9,6% | 13,7% | 413 | 0,74× | 15,1 | 2,47 | 5,8 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 81 · boss 1 · common 350 · fast 141 · flying 109. Pico de inimigos no mapa: média 126, máximo 171.

