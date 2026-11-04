# Plano do cenário: biomas, transições e relevo

**Situação:** proposta de 04/11/2026. Nada aqui está aprovado. As decisões que são do Pedro estão em "Perguntas de design" no Notion e no fim deste arquivo.
A pegada visual (como cada coisa deve parecer) está em `docs/direcao-visual-cenario.md`.

## 1. De onde partimos

- **Regiões dos heróis:** são 5 (Valcoroa, Costa Rubra, Forjaferro, Cripta Cinzenta e Panteão).
  - Valcoroa e Costa Rubra estão no lançamento. As outras ficam para depois.
  - A run pode misturar regiões. A pergunta aberta no Mini-GDD é: qual tema o mapa usa?
- **Mapa que cresce:** começa num mapa base e, nas ondas 5, 10, 15, 20, 25 e 30, ganha um pedaço novo de 11 casas (`data/expansion.json`).
  Cada pedaço novo é o lugar natural de uma **transição**.
- **Chão já gerado:** os 7 biomas do `gerar_biomas.py` (grama, floresta, areia, neve, outono, pântano e vulcânico).

## 2. Proposta: biomas separados das regiões dos heróis

O bioma é o **lugar** do mapa, e a região é a **facção** dos heróis. Como a run mistura facções, o lugar não pode depender delas.
Ainda assim, cada bioma lembra uma região, para dar identidade:

| Bioma | Lembra | Chão | Peças marcantes | Luz |
|---|---|---|---|---|
| **Floresta do reino** | Valcoroa | grama em manchas, terra | carvalhos retorcidos, fogueira, ruína, cerca, riacho e ponte | quente, de fim de tarde |
| **Costa** | Costa Rubra | areia clara, pedra molhada | palmeiras, rochas, destroços de barco, cais, água rasa | clara, levemente azulada |
| **Deserto dos templos** | Panteão | areia dourada, laje de arenito | cactos, colunas quebradas, estátua enterrada, obelisco, oásis | forte, branca e quente |
| **Forja** | Forjaferro | rocha escura, cinza | rochas vulcânicas, trilhos, carrinhos de minério, chaminés, lava | laranja de baixo, fumaça |
| **Bosque morto / cemitério** | Cripta Cinzenta | outono escuro, folhagem | árvores secas, lápides, cripta, lanternas, névoa | fria, com pontos quentes de lanterna |

Neve e pântano ficam de reserva, como variações (montanha do Panteão, brejo da Cripta).

**Primeiro corte:** Floresta do reino, porque já está no meio. Depois, a Costa, que fecha as duas regiões do lançamento.

## 3. Transições entre biomas

**Regra:** só existe transição entre **vizinhos**. Nunca, por exemplo, de neve direto para deserto.

```
Bosque morto ── Floresta do reino ── Costa ── Deserto dos templos ── Forja
```

**Como fica no mapa:**
- O mapa base tem um bioma.
- Cada pedaço novo pode trocar para um bioma vizinho.
- A emenda entre dois pedaços usa a mesma técnica do caminho orgânico:
  - uma máscara de ruído decide qual chão aparece em cada pixel, numa faixa de 1 a 2 casas;
  - nessa faixa as peças se misturam (capim seco entre a grama e a areia, um cacto perto de um arbusto).
- **Nunca uma linha reta.**

**O que cada par precisa:** cerca de 4 peças de transição. Por exemplo, capim seco, pedras de duas cores e uma árvore "de fronteira", como uma palmeira na floresta.

## 4. Relevo: montanhas, penhascos e desfiladeiros

A área de jogo continua **plana**, para a leitura e para as regras.
O relevo fica **em volta**, nas casas fechadas e fora do mapa. É ele que dá profundidade.

- **Planalto e penhasco:** as casas fora da área de jogo sobem um ou dois níveis, com uma parede de rocha desenhada (o `GridView` já desenha lajes com lado).
  Em cima, árvores e mato. Se o caminho passar entre dois planaltos, vira um **desfiladeiro**.
- **Montanha ao fundo:** silhuetas grandes na borda de cima do mapa, mais escuras e azuladas com a distância.
- **Água:** riacho e lago nas casas fechadas, com ponte onde o caminho cruza.
- **Quando um pedaço novo abre:** o penhasco daquele lado desce ou se abre (animação de terra), e a área nova aparece.

**Peças de relevo por bioma (cerca de 6):**
- face de penhasco (reta, canto de dentro, canto de fora);
- topo do penhasco com beirada;
- pedras grandes de pé de penhasco;
- silhueta de montanha.

## 5. Kit de cada bioma (o molde)

Todo bioma tem as mesmas vagas, cerca de 35 peças, o que facilita planejar e conferir.

| Grupo | Peças | Quem faz |
|---|---|---|
| Chão (base, variação, caminho, mata fechada) | 4 | nosso gerador |
| Capim e cobertura (baixo, alto, beiradas, folhas ou areia solta) | 4 folhas | Gemini |
| Detalhes pequenos (pedras, flores, galhos ou equivalentes) | 2 folhas | Gemini |
| Arbustos | 1 folha | Gemini |
| Peças grandes (árvores ou equivalentes) | 5 | Gemini |
| Pontos de interesse | 5 a 6 | Gemini |
| Relevo | 6 | Gemini mais o código |
| Água (se tiver) | 2 | nosso gerador mais shader |
| Transição para cada vizinho | cerca de 4 | Gemini |
| Clima (paleta, luz, névoa, partículas) | 1 arquivo de dados | eu |

## 6. Ordem de trabalho

1. **Floresta completa no jogo:** chão, faixas, vento, luz, peças e relevo. Este é o corte vertical.
2. **Transição de teste:** um pedaço de Bosque morto abrindo ao lado da floresta, para provar a técnica.
3. **Costa.**
4. Depois, um bioma por vez, sempre com o kit completo antes do próximo.

## 7. Decisões do Pedro (pendentes)

1. Os biomas propostos (seção 2) e a ordem de trabalho.
2. Como o bioma muda numa run:
   - (a) um bioma por run;
   - (b) o mapa vai mudando a cada pedaço novo, para um vizinho;
   - (c) o bioma depende das regiões dos heróis escolhidos.
3. O cenário mexe nas regras? Por exemplo: árvore ou pedra ocupa casa e impede construir; o relevo dá bônus de alcance.
   Sugestão: **não**, só visual.
4. Uma árvore pode ficar na frente da área de jogo, ficando transparente quando tem alguém atrás?
5. O núcleo (a torre do reino): é feito no Gemini, como peça, ou modelado no Blender, como os heróis, para ter animação?
