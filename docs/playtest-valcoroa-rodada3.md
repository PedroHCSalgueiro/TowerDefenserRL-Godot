# Playtest do Reino de Valcoroa (bots)

200 runs completas, 100 "sequential" e 100 "stack". Gerado por `tools/playtest/report.js`.

- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.
- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)
- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.

## Política: sequential

**Resultado:** 10 vitórias, 90 derrotas, 0 sem fim (10% de vitória).
**Onda alcançada:** média 38,2 · mediana 38 · p10 37 · p90 40 (de 40).
**Duração da run:** média 27min37s · mediana 27min33s · mais curta 21min18s · mais longa 33min16s.

**Em que onda a run acaba (derrotas):** onda 40: 37 · onda 39: 28 · onda 38: 16 · onda 37: 8 · onda 36: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 22 s | 4 | 9 | 2,2 | 18,8 |
| 6–10 | 24 s | 9 | 19 | 5,8 | 33,2 |
| 11–15 | 25 s | 25 | 74 | 9,7 | 49,2 |
| 16–20 | 30 s | 114 | 256 | 13,0 | 66,5 |
| 21–25 | 39 s | 290 | 598 | 15,9 | 83,5 |
| 26–30 | 51 s | 668 | 1.190 | 18,3 | 96,6 |
| 31–35 | 69 s | 1.320 | 2.253 | 20,5 | 105,4 |
| 36–40 | 91 s | 2.327 | 3.828 | 22,4 | 80,4 |

### Ouro

Ouro ganho por run: média 20.364 (mediana 20.273). Sobra no fim: média 3.817; maior pico guardado: média 4.974, máximo 7.076.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 17.451 | 85,7% |
| Bônus de fim de onda | 2.556 | 12,6% |
| Juros | 357 | 1,8% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 18,9 em média; compras: 40,9 torres, 59,0 fusões e 55,4 rerolls por run.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 4,9% | 9,6% | 1.002 | 0,71× | 19,6 | 2,40 | 1,7 | 86% das runs |
| Lyra | 6,7% | 11,4% | 1.470 | 1,05× | 18,0 | 2,42 | 1,7 | 81% das runs |
| Irmão Tomás | 0,7% | 1,4% | 149 | 0,11× | 3,7 | 2,34 | 1,6 | 85% das runs |
| Mestre Brom | 37,7% | 22,6% | 4.464 | 3,18× | 87,2 | 2,61 | 4,6 | 100% das runs |
| Dama Selene | 5,9% | 9,1% | 700 | 0,50× | 10,8 | 2,61 | 4,6 | 100% das runs |
| Wulf | 10,9% | 4,8% | 1.226 | 0,87× | 21,3 | 2,59 | 4,8 | 100% das runs |
| Engenheira Mabel | 16,1% | 15,2% | 1.095 | 0,78× | 0,0 | 2,74 | 10,8 | 100% das runs |
| Rainha Isolde | 17,1% | 25,8% | 1.127 | 0,80× | 17,3 | 2,74 | 11,0 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 169 · boss 1 · common 610 · fast 270 · flying 188 · bossFinal 0. Pico de inimigos no mapa: média 101, máximo 115.

## Política: stack

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 31,2 · mediana 31 · p10 29 · p90 33 (de 40).
**Duração da run:** média 11min59s · mediana 11min59s · mais curta 10min59s · mais longa 13min15s.

**Em que onda a run acaba (derrotas):** onda 32: 28 · onda 33: 28 · onda 31: 16 · onda 34: 12 · onda 30: 9 · onda 29: 3 · onda 35: 3 · onda 36: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 24 s | 4 | 9 | 1,9 | 18,5 |
| 6–10 | 23 s | 19 | 41 | 5,6 | 34,9 |
| 11–15 | 25 s | 60 | 122 | 9,8 | 53,3 |
| 16–20 | 31 s | 158 | 311 | 13,0 | 70,6 |
| 21–25 | 46 s | 367 | 675 | 15,7 | 86,4 |
| 26–30 | 67 s | 707 | 1.313 | 17,9 | 89,8 |
| 31–35 | 84 s | 969 | 1.845 | 19,9 | 60,1 |
| 36–40 | — | 1.495 | 2.562 | 21,1 | — |

### Ouro

Ouro ganho por run: média 10.645 (mediana 10.570). Sobra no fim: média 1.331; maior pico guardado: média 2.206, máximo 3.073.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 8.660 | 81,4% |
| Bônus de fim de onda | 1.757 | 16,5% |
| Juros | 227 | 2,1% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 16,9 em média; compras: 36,1 torres, 50,8 fusões e 9,5 rerolls por run.
Chamadas antecipadas por run: 29,5 · ondas ativas ao chamar: 2,45 em média, máximo 7.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 9,3% | 18,4% | 451 | 0,70× | 19,3 | 2,51 | 3,6 | 99% das runs |
| Lyra | 14,3% | 22,3% | 755 | 1,17× | 19,1 | 2,51 | 3,3 | 99% das runs |
| Irmão Tomás | 1,3% | 2,5% | 64 | 0,10× | 3,6 | 2,46 | 3,5 | 100% das runs |
| Mestre Brom | 40,1% | 21,7% | 2.090 | 3,24× | 82,3 | 2,51 | 4,6 | 100% das runs |
| Dama Selene | 6,1% | 8,3% | 338 | 0,52× | 11,0 | 2,47 | 4,3 | 99% das runs |
| Wulf | 10,2% | 3,4% | 572 | 0,89× | 21,8 | 2,46 | 4,3 | 100% das runs |
| Engenheira Mabel | 8,5% | 7,8% | 418 | 0,65× | 0,0 | 2,50 | 6,1 | 100% das runs |
| Rainha Isolde | 10,1% | 15,5% | 480 | 0,74× | 17,3 | 2,50 | 6,3 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 90 · boss 1 · common 385 · fast 156 · flying 120. Pico de inimigos no mapa: média 136, máximo 200.


## Leitura (depois do balanço)

Este relatório é o **depois**. O **antes** (regras da primeira versão) está em `playtest-valcoroa-antes.md`.

| | Antes | Depois |
|---|---|---|
| Vitória (jogador clássico) | 18% | 10% |
| Onda alcançada (clássico) | 38,2 | 38,2 |
| Vitória (jogador apressado) | 0% | 0% |
| Ouro ganho por run (clássico) | 37.052 | 20.364 |
| Ouro guardado nas ondas 36–40 | 4.676 | 2.327 |
| Maior pico guardado (máximo) | 12.023 | 7.076 |
| Mestre Brom no dano total | 52% | 38% |
| Brom por cópia (média = 1,0×) | 4,2× | 3,2× |
| Duração da run clássica | 29 min | 27,5 min |

**O que mudou nas regras:** ouro por abate a cada 2 ondas (1 nas ondas 1–2 até 20 nas 39–40, em vez do número da onda); Mestre Brom com dano 7 e bola carregada mais fraca; Aldric 14, Selene 10, Mabel 11, Isolde 12,5 e Wulf 13 de dano; aura do Irmão Tomás +15% (+30% para o Reino).

**Como se chegou aos números:** varredura de 30 runs por configuração (ver os commits "Balanço de Valcoroa"). O corte de ouro sozinho derrubava a vitória de ~23% para ~7%, e o nerf do Brom sozinho para ~3%; por isso o Brom ficou em meio-termo e os outros heróis ganharam dano.

**Ainda aberto:**
- O Brom continua o herói mais forte por cópia (3,2× a média) e o Irmão Tomás o mais fraco em dano (0,11×; ele é suporte e o ganho que dá às vizinhas não entra nessa conta).
- O ouro guardado no fim das runs ainda passa de 2.000 nas ondas 36–40 (antes 4.700), porque depois da onda ~25 não há em que gastar além da evolução do núcleo.
- O bot clássico perde quase sempre nas ondas 38–40; o apressado chega à onda ~31. A chamada antecipada nunca rendeu ouro, porque a janela do bônus quase nunca está aberta quando o bot chama.
- Cadeias em Valcoroa são curtas (média 3 a 4 disparos); só a Dama Selene ativa vizinhas.
- Bots não são pessoas: valem para comparar heróis e regras, não para prever o resultado de quem joga bem.
