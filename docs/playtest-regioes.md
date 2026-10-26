# Relatório do agente testador

Gerado por `tools/playtest/agent_report.js` a partir de `final`. Os bots não jogam como uma pessoa: servem para comparar regiões e heróis entre si. A referência é o Reino de Valcoroa (já balanceado com o Pedro).

## Conjuntos

| Conjunto | Runs por política | Onda mediana (sequential) | Vitórias (sequential) | Onda mediana (stack) | Vitórias (stack) | Marcação |
| --- | --- | --- | --- | --- | --- | --- |
| costarubra | 20 | 23,0 | 0% | 19,0 | 0% | — |
| cripta | 20 | 24,0 | 0% | 21,0 | 0% | — |
| forjaferro | 20 | 22,5 | 0% | 19,0 | 0% | — |
| panteao | 20 | 24,0 | 0% | 17,5 | 0% | — |
| todas | 12 | 24,0 | 0% | 19,0 | 0% | — |
| valcoroa | 20 | 25,0 | 0% | 19,0 | 0% | — |

## Heróis

Bancada: cada herói sozinho, 4 cópias em ★2 nas mesmas casas, ondas uma a uma até perder. "vs. raridade" = diferença para a mediana dos heróis da mesma raridade (todas as regiões). "Dano/torre/onda" = dano do herói ÷ (cópias no mapa somadas em cada onda), relativo à média do conjunto da região, nas runs sequential. "Impacto" = onda média das runs em que o herói ficou ao menos 5 ondas no mapa, menos a das outras (ruidoso com poucas runs).

### costarubra

| Herói | Classe | Raridade | Bancada (onda) | vs. raridade | Dano | Abates | Dano/torre/onda | Impacto | Marcação |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bart Canhoneiro | Artilheiro | Comum | 14,0 | +0,0 | 18.776 | 147 | 1,35× | — | — |
| Ruby Duas-Pistolas | Atirador | Comum | 14,0 | +0,0 | 18.531 | 147 | 0,97× | — | — |
| Imediato Âncora | Guardião | Comum | 15,0 | +1,0 | 23.729 | 159 | 0,76× | — | — |
| Morgana do Mar | Controlador | Incomum | 14,0 | +0,0 | 18.177 | 146 | 1,20× | -0,6 | — |
| Capitão Pena | Suporte | Incomum | 9,0 | -5,0 | 4.684 | 74 | 0,29× | -0,6 | depende de vizinhas |
| Kraus Arpoador | Caçador | Incomum | 14,0 | +0,0 | 18.367 | 140 | 0,96× | — | — |
| Mama Zuri | Mago | Raro | 14,0 | +0,0 | 18.047 | 146 | 1,19× | +2,2 | — |
| Nerea, Domadora Abissal | Invocador | Raro | 14,0 | +0,0 | 17.694 | 147 | 1,28× | +2,4 | — |

### cripta

| Herói | Classe | Raridade | Bancada (onda) | vs. raridade | Dano | Abates | Dano/torre/onda | Impacto | Marcação |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Morn, o Ceifador | Guardião | Comum | 14,5 | +0,5 | 18.324 | 145 | 0,90× | — | — |
| Nyx Espectral | Atirador | Comum | 14,0 | +0,0 | 18.338 | 145 | 0,97× | — | — |
| Acólito Sombrio | Suporte | Comum | 8,0 | -6,0 | 3.269 | 62 | 0,12× | — | depende de vizinhas |
| Golem de Ossos | Artilheiro | Incomum | 14,0 | +0,0 | 17.600 | 146 | 1,22× | +1,3 | — |
| Vex, o Necromante | Invocador | Incomum | 15,0 | +1,0 | 19.897 | 149 | 0,72× | -1,3 | — |
| Agatha da Peste | Controlador | Incomum | 14,5 | +0,5 | 16.783 | 136 | 0,96× | +5,1 | — |
| Grim, o Carrasco | Caçador | Raro | 14,0 | +0,0 | 15.125 | 137 | 1,41× | +1,8 | — |
| Lich Morvath | Mago | Raro | 14,0 | +0,0 | 18.395 | 146 | 1,70× | +1,4 | — |

### forjaferro

| Herói | Classe | Raridade | Bancada (onda) | vs. raridade | Dano | Abates | Dano/torre/onda | Impacto | Marcação |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bolt, o Mecânico | Invocador | Comum | 15,0 | +1,0 | 24.669 | 164 | 0,95× | — | — |
| Vapora | Atirador | Comum | 15,0 | +1,0 | 24.031 | 164 | 1,45× | -1,5 | — |
| Golem Caldeira | Guardião | Comum | 14,0 | +0,0 | 15.560 | 135 | 1,12× | — | depende de vizinhas |
| Tic, o Relojoeiro | Suporte | Incomum | 10,0 | -4,0 | 6.380 | 87 | 0,33× | -2,5 | depende de vizinhas |
| Greta Morteirista | Artilheiro | Incomum | 14,0 | +0,0 | 17.688 | 146 | 1,86× | +3,8 | — |
| Volta, a Eletricista | Mago | Incomum | 13,0 | -1,0 | 12.276 | 124 | 0,53× | -3,2 | depende de vizinhas |
| Dra. Engrena | Controlador | Raro | 16,0 | +2,0 | 28.324 | 173 | 0,93× | +5,2 | — |
| Ferro Balisteiro | Caçador | Raro | 13,0 | -1,0 | 12.811 | 126 | 0,83× | +2,5 | depende de vizinhas |

### panteao

| Herói | Classe | Raridade | Bancada (onda) | vs. raridade | Dano | Abates | Dano/torre/onda | Impacto | Marcação |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Hoplita Dorian | Guardião | Comum | 14,0 | +0,0 | 16.449 | 139 | 1,06× | — | — |
| Ilíria, a Arqueira | Atirador | Comum | 14,5 | +0,5 | 18.464 | 146 | 0,80× | — | — |
| Sacerdotisa Amunet | Suporte | Comum | 8,0 | -6,0 | 3.095 | 61 | 0,12× | — | depende de vizinhas |
| Ciclope Forjador | Artilheiro | Incomum | 14,0 | +0,0 | 16.934 | 143 | 1,28× | +1,7 | — |
| Pítia, o Oráculo | Controlador | Incomum | 14,0 | +0,0 | 15.766 | 137 | 0,66× | -0,5 | — |
| Sigrun, a Valquíria | Caçador | Incomum | 14,0 | +0,0 | 19.163 | 139 | 1,23× | -0,1 | — |
| Tritão das Tempestades | Mago | Raro | 14,0 | +0,0 | 17.495 | 146 | 1,76× | +0,2 | — |
| Kallia, Domadora de Grifos | Invocador | Raro | 14,5 | +0,5 | 19.495 | 145 | 1,07× | -0,3 | — |

### valcoroa

| Herói | Classe | Raridade | Bancada (onda) | vs. raridade | Dano | Abates | Dano/torre/onda | Impacto | Marcação |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Sir Aldric | Guardião | Comum | 17,0 | +3,0 | 37.540 | 204 | 1,88× | — | — |
| Lyra, a Besteira | Atirador | Comum | 14,0 | +0,0 | 15.283 | 135 | 0,73× | — | — |
| Irmão Tomás | Suporte | Comum | 7,0 | -7,0 | 2.116 | 46 | 0,08× | — | depende de vizinhas |
| Mestre Brom | Artilheiro | Raro | 12,0 | -2,0 | 9.877 | 107 | 1,65× | -0,4 | — |
| Dama Selene | Mago | Incomum | 14,0 | +0,0 | 17.629 | 144 | 0,52× | +2,0 | — |
| Wulf, Caçador Real | Caçador | Incomum | 13,0 | -1,0 | 12.473 | 115 | 1,01× | — | — |
| Engenheira Mabel | Invocador | Raro | 15,0 | +1,0 | 22.054 | 154 | 0,98× | +0,6 | — |
| Rainha Isolde | Controlador | Lendário | 15,0 | +0,0 | 20.513 | 151 | 1,14× | +0,9 | — |

## O que pede ajuste

Nada marcado: todos os conjuntos e heróis dentro dos limites.

## Erros e travamentos

Nenhum: nenhum erro nos logs, nenhuma run sem fim e nenhum gatilho descartado.

Limites: região ±3 ondas da mediana do Valcoroa; bancada ±4 ondas da mediana da raridade; dano por torre por onda acima de 2× ou abaixo de 0.4× a média do conjunto.
