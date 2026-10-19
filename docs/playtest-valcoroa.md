# Playtest do Reino de Valcoroa (bots)

200 runs completas, 100 "sequential" e 100 "stack". Gerado por `tools/playtest/report.js`.

- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.
- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)
- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.

## Política: sequential

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 33,3 · mediana 34 · p10 32 · p90 36 (de 40).
**Duração da run:** média 25min40s · mediana 25min59s · mais curta 3min28s · mais longa 35min14s.

**Em que onda a run acaba (derrotas):** onda 35: 27 · onda 36: 22 · onda 33: 15 · onda 34: 14 · onda 37: 8 · onda 32: 4 · onda 38: 4 · onda 5: 2.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 25 s | 4 | 9 | 2,2 | 18,4 |
| 6–10 | 28 s | 9 | 19 | 5,1 | 30,4 |
| 11–15 | 30 s | 17 | 51 | 8,2 | 42,9 |
| 16–20 | 37 s | 54 | 133 | 11,1 | 56,7 |
| 21–25 | 48 s | 178 | 345 | 13,7 | 72,7 |
| 26–30 | 63 s | 328 | 746 | 16,1 | 83,9 |
| 31–35 | 86 s | 541 | 1.095 | 18,1 | 71,0 |
| 36–40 | 102 s | 977 | 1.501 | 19,5 | 45,6 |

### Ouro

Ouro ganho por run: média 6.699 (mediana 6.789). Sobra no fim: média 945; maior pico guardado: média 1.450, máximo 2.260.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 20.349 | 303,8% |
| Bônus de fim de onda | 2.010 | 30,0% |
| Juros | 256 | 3,8% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 14,7 em média; compras: 32,0 torres, 45,4 fusões e 43,5 rerolls por run.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 5,8% | 11,5% | 629 | 0,64× | 11,0 | 2,40 | 1,8 | 86% das runs |
| Lyra | 13,1% | 21,5% | 1.527 | 1,56× | 16,4 | 2,35 | 1,6 | 82% das runs |
| Irmão Tomás | 1,3% | 2,6% | 155 | 0,16× | 3,5 | 2,32 | 1,6 | 84% das runs |
| Mestre Brom | 34,8% | 22,2% | 2.849 | 2,91× | 51,1 | 2,53 | 3,5 | 95% das runs |
| Dama Selene | 4,5% | 6,5% | 357 | 0,37× | 5,3 | 2,50 | 3,6 | 99% das runs |
| Wulf | 13,8% | 6,0% | 983 | 1,01× | 16,2 | 2,52 | 3,9 | 95% das runs |
| Engenheira Mabel | 13,3% | 12,0% | 656 | 0,67× | 0,0 | 2,65 | 8,2 | 98% das runs |
| Rainha Isolde | 13,2% | 17,4% | 664 | 0,68× | 9,7 | 2,67 | 7,9 | 98% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 114 · boss 1 · common 423 · fast 185 · flying 126. Pico de inimigos no mapa: média 71, máximo 102.

## Política: stack

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 25,0 · mediana 26 · p10 19 · p90 28 (de 40).
**Duração da run:** média 9min56s · mediana 10min25s · mais curta 1min49s · mais longa 11min58s.

**Em que onda a run acaba (derrotas):** onda 28: 28 · onda 27: 26 · onda 29: 14 · onda 20: 7 · onda 25: 7 · onda 26: 7 · onda 5: 5 · onda 30: 4.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 27 s | 4 | 9 | 1,7 | 17,8 |
| 6–10 | 29 s | 14 | 29 | 4,7 | 31,9 |
| 11–15 | 34 s | 31 | 71 | 8,0 | 46,2 |
| 16–20 | 44 s | 83 | 171 | 10,9 | 61,1 |
| 21–25 | 62 s | 167 | 308 | 13,3 | 68,3 |
| 26–30 | 80 s | 296 | 529 | 15,4 | 43,1 |
| 31–35 | 82 s | 375 | 716 | 16,7 | 57,0 |
| 36–40 | — | — | — | — | — |

### Ouro

Ouro ganho por run: média 3.249 (mediana 3.449). Sobra no fim: média 308; maior pico guardado: média 619, máximo 981.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 8.590 | 264,3% |
| Bônus de fim de onda | 1.205 | 37,1% |
| Juros | 129 | 4,0% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 12,1 em média; compras: 25,5 torres, 34,4 fusões e 5,7 rerolls por run.
Chamadas antecipadas por run: 25,3 · ondas ativas ao chamar: 2,58 em média, máximo 7.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 9,9% | 18,3% | 266 | 0,64× | 10,5 | 2,39 | 3,2 | 97% das runs |
| Lyra | 24,7% | 33,1% | 697 | 1,67× | 17,1 | 2,40 | 3,0 | 92% das runs |
| Irmão Tomás | 2,6% | 4,3% | 73 | 0,17× | 3,4 | 2,39 | 3,2 | 97% das runs |
| Mestre Brom | 30,2% | 17,5% | 1.138 | 2,73× | 42,3 | 2,33 | 2,9 | 94% das runs |
| Dama Selene | 5,1% | 6,1% | 194 | 0,46× | 5,4 | 2,32 | 2,7 | 91% das runs |
| Wulf | 12,2% | 3,4% | 450 | 1,08× | 16,2 | 2,30 | 3,1 | 95% das runs |
| Engenheira Mabel | 7,3% | 6,6% | 248 | 0,59× | 0,0 | 2,34 | 3,7 | 95% das runs |
| Rainha Isolde | 7,7% | 10,3% | 274 | 0,66× | 9,5 | 2,38 | 3,8 | 95% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 53 · boss 1 · common 246 · fast 95 · flying 72. Pico de inimigos no mapa: média 86, máximo 144.

