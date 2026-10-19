# Playtest do Reino de Valcoroa (bots)

200 runs completas, 100 "sequential" e 100 "stack". Gerado por `tools/playtest/report.js`.

- **sequential**: o jogador clássico: compra e evolui o núcleo entre as ondas e só chama a onda seguinte quando a anterior acaba.
- **stack**: o jogador apressado: chama uma onda nova a cada 20 s com as anteriores ainda no mapa, e compra durante as ondas. (Ondas de chefão só podem ser chamadas com o mapa vazio, então o empilhamento para nelas.)
- Os bots não são jogadores bons: comprar sempre a carta mais cara, escolher a primeira recompensa e posicionar na casa que vê mais caminho. Servem para comparar torres e políticas, não para prever o resultado de uma pessoa.

## Política: sequential

**Resultado:** 18 vitórias, 82 derrotas, 0 sem fim (18% de vitória).
**Onda alcançada:** média 38,2 · mediana 38 · p10 36 · p90 40 (de 40).
**Duração da run:** média 29min07s · mediana 29min19s · mais curta 22min00s · mais longa 36min37s.

**Em que onda a run acaba (derrotas):** onda 40: 31 · onda 39: 22 · onda 38: 14 · onda 37: 10 · onda 36: 4 · onda 35: 1.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 24 s | 4 | 11 | 2,4 | 19,7 |
| 6–10 | 24 s | 10 | 23 | 7,0 | 37,6 |
| 11–15 | 26 s | 49 | 132 | 11,4 | 57,5 |
| 16–20 | 31 s | 229 | 458 | 14,9 | 76,2 |
| 21–25 | 41 s | 457 | 908 | 18,1 | 93,7 |
| 26–30 | 52 s | 1.411 | 2.400 | 20,3 | 106,3 |
| 31–35 | 75 s | 2.334 | 4.620 | 22,7 | 113,7 |
| 36–40 | 99 s | 4.676 | 7.276 | 24,5 | 89,4 |

### Ouro

Ouro ganho por run: média 37.052 (mediana 37.870). Sobra no fim: média 6.088; maior pico guardado: média 9.690, máximo 12.023.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 34.114 | 92,1% |
| Bônus de fim de onda | 2.550 | 6,9% |
| Juros | 387 | 1,0% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 21,1 em média; compras: 45,1 torres, 65,1 fusões e 58,0 rerolls por run.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 3,3% | 6,9% | 628 | 0,47× | 11,6 | 2,43 | 1,9 | 88% das runs |
| Lyra | 7,9% | 14,2% | 1.538 | 1,16× | 17,4 | 2,36 | 1,8 | 88% das runs |
| Irmão Tomás | 0,8% | 1,8% | 150 | 0,11× | 3,6 | 2,40 | 1,9 | 86% das runs |
| Mestre Brom | 52,5% | 37,6% | 5.568 | 4,21× | 99,4 | 2,66 | 5,1 | 100% das runs |
| Dama Selene | 3,5% | 5,7% | 349 | 0,26× | 5,4 | 2,65 | 5,5 | 99% das runs |
| Wulf | 9,9% | 4,6% | 1.037 | 0,78× | 16,2 | 2,63 | 5,1 | 100% das runs |
| Engenheira Mabel | 11,0% | 11,1% | 646 | 0,49× | 0,0 | 2,76 | 12,3 | 100% das runs |
| Rainha Isolde | 11,1% | 18,2% | 672 | 0,51× | 9,8 | 2,76 | 11,7 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 167 · boss 1 · common 614 · fast 264 · flying 186 · bossFinal 0. Pico de inimigos no mapa: média 102, máximo 118.

## Política: stack

**Resultado:** 0 vitórias, 100 derrotas, 0 sem fim (0% de vitória).
**Onda alcançada:** média 31,7 · mediana 32 · p10 29 · p90 34 (de 40).
**Duração da run:** média 12min12s · mediana 12min11s · mais curta 10min28s · mais longa 13min47s.

**Em que onda a run acaba (derrotas):** onda 33: 21 · onda 34: 21 · onda 32: 20 · onda 31: 11 · onda 35: 11 · onda 30: 6 · onda 29: 4 · onda 36: 3.

### Duração de cada onda, ouro guardado e torres, por faixa de ondas

| Ondas | Duração média da onda | Ouro guardado (média) | Ouro guardado (p90) | Torres | Vida do núcleo ao fim |
| --- | --- | --- | --- | --- | --- |
| 1–5 | 25 s | 5 | 11 | 2,0 | 19,8 |
| 6–10 | 24 s | 31 | 71 | 6,7 | 40,3 |
| 11–15 | 25 s | 102 | 193 | 11,3 | 61,8 |
| 16–20 | 33 s | 288 | 507 | 14,8 | 80,2 |
| 21–25 | 49 s | 695 | 1.246 | 17,6 | 96,4 |
| 26–30 | 67 s | 1.261 | 2.581 | 19,9 | 99,2 |
| 31–35 | 86 s | 1.981 | 3.653 | 21,9 | 72,4 |
| 36–40 | 88 s | 2.748 | 4.928 | 23,3 | 41,0 |

### Ouro

Ouro ganho por run: média 20.310 (mediana 19.992). Sobra no fim: média 2.630; maior pico guardado: média 4.435, máximo 7.353.

| De onde vem | Ouro por run | % do total |
| --- | --- | --- |
| Abates | 18.236 | 89,8% |
| Bônus de fim de onda | 1.810 | 8,9% |
| Juros | 264 | 1,3% |
| Chamada antecipada | 0 | 0,0% |
| Cadeia lucrativa | 0 | 0,0% |

Núcleo evoluído até o nível 19,1 em média; compras: 40,3 torres, 56,7 fusões e 9,1 rerolls por run.
Chamadas antecipadas por run: 30,7 · ondas ativas ao chamar: 2,57 em média, máximo 9.

### Torres: dano, abates e uso

| Herói | % do dano | % dos abates | Dano por torre por onda | vs. média | Dano por tiro | Estrela média | Compras/run | Presente em |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | 4,4% | 10,6% | 250 | 0,40× | 11,3 | 2,52 | 3,3 | 100% das runs |
| Lyra | 12,5% | 23,6% | 691 | 1,12× | 19,1 | 2,50 | 3,4 | 100% das runs |
| Irmão Tomás | 1,3% | 2,7% | 66 | 0,11× | 3,7 | 2,51 | 3,6 | 100% das runs |
| Mestre Brom | 56,9% | 36,0% | 2.755 | 4,45× | 104,9 | 2,55 | 5,2 | 99% das runs |
| Dama Selene | 3,6% | 5,7% | 182 | 0,30× | 5,6 | 2,53 | 4,9 | 100% das runs |
| Wulf | 8,7% | 3,4% | 459 | 0,74× | 16,8 | 2,51 | 5,1 | 99% das runs |
| Engenheira Mabel | 5,9% | 6,2% | 258 | 0,42× | 0,0 | 2,54 | 7,2 | 100% das runs |
| Rainha Isolde | 6,7% | 11,4% | 285 | 0,46× | 10,2 | 2,56 | 7,7 | 100% das runs |

"Dano por torre por onda" = dano total do herói ÷ (torres do herói no mapa somadas em cada onda): mostra quanto cada cópia rende, independente de quantas foram compradas. Dano de Sangramento e de armadilha conta para o herói que o causou.

Abates por tipo de inimigo (por run): armored 94 · boss 1 · common 407 · fast 163 · flying 124. Pico de inimigos no mapa: média 145, máximo 202.


## Leitura

**Ouro.** 92% do ouro vem dos abates (cada inimigo vale o número da onda dele). Como as ondas têm cada vez mais inimigos, o ganho cresce rápido: só a onda 40 paga ~5.000. Depois da onda 15 não há mais em que gastar: o jogador compra cerca de 45 torres e 58 rerolls na run inteira, e os juros têm teto de 10. Resultado: ouro guardado médio de 457 nas ondas 21–25, 1.411 nas 26–30 e 4.676 nas 36–40, com sobra de ~6.000 no fim e picos de 12.000. O bônus de fim de onda (7%) e os juros (1%) quase não pesam. Para comparação, o total de abates da run (1.481 inimigos) renderia: 43.672 com a regra atual; 9.308 com 1 de ouro a cada 5 ondas; 5.137 com 1 + onda/10; 1.481 com 1 fixo.

**Ritmo.** A run clássica dura ~29 min (as ondas 1–10 levam ~24 s cada; as 36–40 levam ~99 s). Empilhar ondas encurta a run para ~12 min, mas nenhuma das 100 runs apressadas ganhou (chegam à onda ~32) e o núcleo chega ao fim com pouca vida. Os bots clássicos ganham 18% das vezes e quase todos chegam às ondas 36–40: o fim do jogo está apertado, o começo está folgado (vida do núcleo cresce até a onda 30).

**Heróis (dano por cópia por onda; média = 1,0×).**
- **Mestre Brom: 4,2–4,5× a média e ~52–57% de todo o dano.** É o ponto que mais foge. Parte vem de ser dano em área (soma cada inimigo atingido) e de a bola carregada sair a cada 4 tiros além do tiro normal. Candidato nº 1 a ajuste.
- **Lyra 1,1×**, **Wulf 0,75×**: dentro do esperado.
- **Mabel 0,4–0,5×**, **Isolde 0,5×**, **Aldric 0,4–0,47×**: baixo em dano, mas eles têm utilidade que o dano não mede (armadilhas, lentidão e atordoamento). A Isolde ainda é a 2ª em abates (18%).
- **Dama Selene 0,26–0,3×** e **Irmão Tomás 0,11×**: são suporte; o dano que fazem acontecer (tiros ativados, velocidade das vizinhas) é creditado a outras torres, então o número deles aqui subestima o valor real. Mesmo assim o Tomás está muito abaixo.
- O bot compra a carta mais cara, então Mabel e Isolde (raras) aparecem 7–12 vezes por run e as comuns 2–3: a contagem de compras mostra o bot, não a força.

**Cadeias.** A maior cadeia média é pequena (poucos disparos em sequência): em Valcoroa só a Dama Selene ativa vizinhas, então o coração do jogo (combos em cadeia) quase não aparece. Também por isso nenhuma recompensa de "cadeia lucrativa" chegou a render ouro.

**Cuidados.** Bots, não pessoas: a política de compra é simples e o posicionamento é fixo. Os números de ★2/★3 dos heróis são provisórios (ver Perguntas de design no Notion). A chamada antecipada não rendeu ouro nenhuma vez, mesmo com ~31 chamadas por run: a janela do bônus (75% dos inimigos da onda mais recente ainda não nasceram) quase nunca estava aberta quando o bot chamou.
