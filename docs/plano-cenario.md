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

## 2. Cada região é um lugar (direção do Pedro, 04/11)

O Pedro achou o "bosque" simples demais e definiu a ideia: **o cenário é a terra de cada região**.

- Valcoroa acontece **dentro de um reino de verdade**, num palácio.
- Costa Rubra acontece **numa costa com mar**.

As outras três regiões seguem a mesma ideia. Cada região tem **3 zonas**. O mapa base é uma delas, e cada pedaço novo pode ser outra zona da mesma região, para não cansar numa run longa.

### 👑 Valcoroa: o palácio real
Medieval clássico. Ouro, azul real e mármore claro.

- **Zonas:**
  - salão do trono: piso de mármore, tapete vermelho como caminho, colunas e vitrais;
  - pátio e jardim interno: lajes, canteiros podados, fonte e estátuas;
  - muralhas e ameias: pedra, estandartes, catapultas e ponte levadiça.
- **Caminho:** tapete ou passadeira de pedra clara, gasta nas bordas.
- **Chão em manchas:** mármore com desgaste, manchas de luz dos vitrais e poeira nos cantos.
- **Relevo em volta:** paredes do salão com janelas, galerias, sacadas e escadarias.
  O "derrubar parede" do mapa que cresce combina com isto: a parede cai e abre a sala nova.
- **Pontos de interesse:** trono, lareira grande, armaria, mesa de banquete e fonte do pátio.
- **Luz:** feixes dourados dos vitrais, castiçais e tochas.
- **Vida:** chama de tocha, estandartes balançando, poeira no feixe de luz e pétalas no jardim.

### 🏴‍☠️ Costa Rubra: a costa pirata
Piratas, ouro e saque. Vermelho-ferrugem, madeira molhada e turquesa do mar.

- **Zonas:**
  - praia e enseada: areia, rochas, palmeiras e barco encalhado;
  - porto e cais: tábuas, cordas, caixotes, barris e guindaste;
  - vila pirata nos rochedos: palafitas, pontes de corda e bandeiras.
- **Caminho:** areia batida na praia e tábuas no cais.
- **Chão em manchas:** areia seca e molhada, algas e conchas.
- **Relevo em volta:**
  - o mar: ondas, espuma batendo nas pedras e navios ancorados ao fundo;
  - os penhascos de rocha.

  O mapa fica numa faixa de terra entre o mar e o penhasco.
- **Pontos de interesse:** navio naufragado, baú meio enterrado, farol, fogueira e forca do porto.
- **Luz:** sol forte com reflexo da água balançando no chão perto do mar. No fim de tarde fica laranja, e à noite vêm as lanternas.
- **Vida:** ondas, gaivotas, espuma, bandeiras e água pingando.

### ⚙️ Forjaferro: a cidade-fábrica
Steampunk. Cobre, latão, ferro escuro e vapor branco.

- **Zonas:**
  - fundição: piso de ferro rebitado, canais de metal derretido e caldeirões;
  - pátio dos trilhos: dormentes, carrinhos de minério, carvão e engrenagens gigantes;
  - telhados e passarelas: chapas, chaminés, canos e grades.
- **Caminho:** trilho, esteira ou piso de grade de metal.
- **Chão em manchas:** chapas com ferrugem, fuligem, óleo e marcas de rodas.
- **Relevo em volta:** prédios de tijolo, chaminés enormes soltando fumaça e poços com brilho de metal derretido lá embaixo.
- **Pontos de interesse:** fornalha, relógio de torre (combina com o Tic), oficina, guindaste a vapor e tanque de pressão.
- **Luz:** laranja vindo de baixo (metal derretido), lâmpadas elétricas azuladas (combina com a Volta) e fumaça.
- **Vida:** vapor saindo dos canos, faíscas, engrenagens girando e luz piscando.

### 💀 Cripta Cinzenta: a necrópole
Fantasia sombria. Cinza, roxo apagado e verde-espectral.
A referência da fogueira e da ponte já é quase este clima.

- **Zonas:**
  - cemitério: lápides, túmulos, árvores secas e cerca de ferro torta;
  - pântano dos mortos: água parada escura, névoa rente ao chão, raízes e juncos;
  - catacumbas: corredores de pedra, nichos com ossos, velas e sarcófagos.
- **Caminho:** terra pisada entre os túmulos, lajes rachadas e passarela de tábuas no pântano.
- **Chão em manchas:** terra escura, folhas mortas, musgo cinza e ossinhos.
- **Relevo em volta:** muros do cemitério, mausoléus altos, igreja em ruína ao fundo e névoa densa na borda.
- **Pontos de interesse:** mausoléu, altar, poço de almas, carroça fúnebre e fogueira de vigia.
- **Luz:** escura e fria, com pontos quentes de lanterna e o brilho verde das almas. É o bioma em que a luz por cima mais trabalha.
- **Vida:** névoa andando, almas flutuando (combina com a mecânica de almas da Cripta), corvos e vaga-lumes frios.

### 🏛️ Panteão: o monte dos deuses
Mitologia. Mármore branco, ouro e céu.
Os heróis misturam mitos (grego, egípcio e nórdico), então o lugar é **onde todos os deuses se encontram**.

- **Zonas:**
  - templo grego no alto: mármore, colunas, oliveiras e nuvens lá embaixo;
  - deserto dos templos, o que o Pedro queria: areia dourada, pirâmide, obelisco, esfinge meio enterrada, cactos e oásis;
  - salão nórdico na neve: madeira, pedra, runas, fogueira e pinheiros nevados.
- **Caminho:** escadarias e lajes de mármore, e areia batida no deserto.
- **Chão em manchas:** mármore com veios, dunas suaves e neve com pegadas.
- **Relevo em volta:** **ilhas flutuando no céu**, com a borda do mapa caindo em nuvens, e estátuas colossais ao fundo.
- **Pontos de interesse:** altar com chama sagrada, estátua de deus, oráculo (combina com a Pítia), ninho de grifo (combina com a Kallia) e portal de luz.
- **Luz:** a mais clara e saturada do jogo, com raios de sol entre as nuvens.
- **Vida:** nuvens passando por baixo, chama sagrada, areia soprando ou neve caindo, conforme a zona.

## 3. Transições entre regiões

Com cada região sendo um lugar, a passagem de uma para outra precisa de um motivo no mundo.
A proposta é **um continente só**, com fronteiras entre vizinhas:

```
Cripta Cinzenta ── Valcoroa ── Costa Rubra ── Forjaferro ── Panteão
 (catacumbas      (palácio)    (porto)        (fábrica na    (o monte
  sob o reino)                                 montanha)      acima de tudo)
```

| Par | Peça de passagem |
|---|---|
| Valcoroa → Cripta | escadaria do palácio descendo para as catacumbas, ou o cemitério real atrás das muralhas |
| Valcoroa → Costa Rubra | o portão do palácio sai para o porto: o cais de pedra do reino vira o cais de madeira dos piratas |
| Costa Rubra → Forjaferro | estaleiro e doca de ferro: a madeira vira metal e as rochas da costa sobem para a montanha |
| Forjaferro → Panteão | elevador ou trilho subindo a montanha: o último trecho vira escadaria de mármore até as nuvens |

**Como a passagem fica no mapa:**
- O pedaço novo traz a região vizinha.
- A emenda é uma faixa de 1 a 2 casas, onde os chãos e as peças dos dois lados se misturam de forma orgânica, junto com a peça de passagem.
- **Nunca uma linha reta.**
- Entre zonas da mesma região, vale a mesma técnica.

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

1. **Primeira região completa no jogo (Valcoroa, palácio):** chão, faixas, vento, luz, peças e relevo. Este é o corte vertical.
2. **Transição de teste:** um pedaço de Bosque morto abrindo ao lado da floresta, para provar a técnica.
3. **Costa.**
4. Depois, um bioma por vez, sempre com o kit completo antes do próximo.

## 7. Decisões do Pedro (pendentes)

1. Biomas: definido pelo Pedro (04/11) que cada região é um lugar. Falta aprovar as zonas, a geografia (seções 2 e 3) e a ordem de trabalho.
2. Como o bioma muda numa run:
   - (a) um bioma por run;
   - (b) o mapa vai mudando a cada pedaço novo, para um vizinho;
   - (c) o bioma depende das regiões dos heróis escolhidos.
3. O cenário mexe nas regras? Por exemplo: árvore ou pedra ocupa casa e impede construir; o relevo dá bônus de alcance.
   Sugestão: **não**, só visual.
4. Uma árvore pode ficar na frente da área de jogo, ficando transparente quando tem alguém atrás?
5. O núcleo (a torre do reino): é feito no Gemini, como peça, ou modelado no Blender, como os heróis, para ter animação?

## 8. Ideias de jogo ligadas ao cenário (04/11, em discussão)

O Pedro propôs três ideias. Elas são regras de jogo, então ficam em "Perguntas de design — Cenário e biomas" (itens 6 a 8) até ele decidir.

1. **Rota aleatória:** cada run passa por uma rota diferente do continente, e nenhuma run vê tudo.
   - Proposta: a geografia é fixa, a zona inicial é sorteada, e em cada expansão o jogador escolhe entre 2 ou 3 paredes que levam a zonas vizinhas sorteadas.
   - Um modo longo, a "Grande Travessia", passaria pelas 5 regiões.
2. **Sempre todos os campeões:** os 40 heróis na loja em toda run.
   - Antes de decidir, medir com os bots: a diluição da loja com 3 cópias por estrela e o bônus de região mais difícil de completar.
3. **Bônus e penalidade pelo lugar:** vale pela casa onde o herói está.
   - Rivalidades em ciclo: Valcoroa contra Cripta, Cripta contra Panteão, Panteão contra Forjaferro, Forjaferro contra Costa Rubra e Costa Rubra contra Valcoroa.
   - Números pequenos, com mais bônus do que penalidade.
