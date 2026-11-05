# Direção visual do cenário

Esta é a pegada que o Pedro aprovou em 04/11/2026, depois dos testes da floresta (cenas v1 a v5).
Os testes estão em `Arte/cenario/gemini/`: `NOTAS-testes.md`, `PLANO-floresta.md` e os scripts `cena_v*.py`.
A proposta de biomas, relevo e transições está em `docs/plano-cenario.md`.
**Para gerar arte com IA:** a página do Notion "Regras de estilo — instruções para o agente de imagem" (https://app.notion.com/p/40fc656560ae81e9b794ce92ae48269d) tem o bloco pronto para colar nas instruções do agente, com câmera, tamanho de pixel, escala, fundo e o que evitar.

**Referência de clima:** jogos de ação em pixel com cenário denso e iluminado, como o Hero Siege.
A referência é só de ideia. **Nunca copiar arte de outro jogo**, nem colocar no jogo uma imagem que o Gemini copiou de uma captura.

## A ideia em uma frase

Um cenário **que faz sentido**: cada lugar tem um motivo (uma fogueira, uma ponte, uma ruína) e tudo em volta se arruma a partir dele.
O chão é rico em manchas, mas calmo. A luz costura tudo. E nada atrapalha a leitura do tower defense.

## Regras

### 1. Escala e câmera
- Pixel 2x, câmera 2:1 a 30°, casa de 48×24 pixels da arte (ver `render/ground_projection.gd`).
- Tamanhos de referência, em pixels da arte:

| Peça | Tamanho |
|---|---|
| Herói | cerca de 34 de altura |
| Capim | 8 a 14 |
| Detalhes do chão | 10 a 24 |
| Arbustos | 20 a 40 |
| Árvores | 60 a 110 (2 a 3 heróis) |
| Pontos de interesse | 24 a 60 de largura |

### 2. Chão: manchas grandes, vizinhos parecidos
- O tom varia **bastante entre manchas** e **pouco entre pixels vizinhos**.
  - Na referência, o contraste entre vizinhos é cerca de 2. O chão do Gemini ficou em cerca de 7 e mostra os quadradinhos.
  - Um chão liso, com desvio de tom 4, fica chapado.
- As manchas são esticadas na horizontal (chão isométrico), com borda recortada e marquinhas de 2 a 3 pixels.
- **O chão é feito pelo nosso gerador** (`chao_manchas.py`, que depois vai para `gerar_biomas.py`), não pelo Gemini: ele repete sem emenda, as cores ficam sob controle e serve para qualquer bioma.

### 3. Caminho orgânico
- A borda entre a terra e o chão é irregular (ruído pela posição), dentro de ±0,2 casa.
  As casas de construir e o caminho dos inimigos não mudam: só o desenho muda.
- A borda da terra é mais escura e a beirada do chão mais clara.
- Folhas, pedrinhas e capim por cima da borda escondem a linha.
- A terra tem manchas suaves, não pedrinhas em padrão.

### 4. Peças do Gemini: na paleta da região
- O Gemini faz **objetos soltos sobre fundo magenta**, um por imagem ou em folha com as peças separadas.
  Não usar o Gemini para chão nem para "tile" com lados.
- Toda peça passa por `recortar.py`: tira o magenta e reduz para a altura certa.
- Depois passa por `harmonizar.py`, que leva a peça para a **paleta da região**, partindo das cores do chão:
  - satura e escurece um pouco;
  - puxa os verdes para o tom do chão;
  - troca cada cor pela mais próxima dentro do mesmo grupo (verde, marrom ou cinza).
- As cores de destaque (flor, cogumelo, fogo) passam com pouca mudança: são os pontos de cor da cena.
- A pegada recursiva: primeiro uma prancha de estilo aprovada, e depois toda peça é gerada com ela anexada, na mesma conversa (`PROMPTS-v2.md`).

### 5. Composição em faixas
A partir do caminho e de cada ponto de interesse, a cena segue esta ordem:

1. chão limpo;
2. capim baixo e raro;
3. capim denso;
4. capim alto, pedras e arbustos em grupinhos;
5. árvores em grupos de 2 ou 3, com arbusto e pedra no pé.

Também valem estas regras:
- A borda de cada faixa é irregular.
- Nada fica solto ao acaso: as peças andam em grupos e cada grupo tem um motivo.
- **Uma árvore não cobre o caminho nem a área de jogo.** Se precisar ficar na frente, fica transparente quando tem alguém atrás.

### 6. Luz por cima
- Manchas grandes de luz e sombra, cantos mais escuros e um tom da região (quente, frio, esverdeado).
- As fontes de luz (fogueira, lanterna, braseiro, cristal) têm brilho que pisca.
- Os personagens recebem **menos** dessa luz e sempre ficam mais claros que o cenário.
- A ordem de contraste continua: cenário < inimigos < torres < efeitos.

### 7. Vida
- Vento em pixel inteiro: o capim balança 1 pixel e a copa 2, com a base parada e uma onda que atravessa o mapa.
- Partículas leves: fumaça, vaga-lumes, folhas caindo, poeira. Poucas, para não competir com o combate.

### 8. Leitura do tower defense vem antes de tudo
- Casas de construir: faixa limpa ou de capim baixo. A grade só aparece em volta do mouse.
- Tudo o que é denso (capim alto, árvores, relevo) fica nas casas fechadas e fora do mapa, emoldurando a área de jogo.
- O caminho dos inimigos sempre lê na hora, com contraste de valor maior que o da referência.
