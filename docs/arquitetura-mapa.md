# Montagem do mapa: diagnóstico e arquitetura proposta

Feito em 05/11/2026, a pedido do Pedro, antes de mexer na montagem. Esta é uma proposta: nada foi implementado ainda.

## 1. Assets (verificados no disco)

**Chão (`assets/cenario/grama/`):** 13 losangos de 48×24 (`lisa_01..05`, `escura_01`, `flores_01..02`, `pedrinhas_01`, `terra_01`, `caminho_01..03`).
O losango ocupa as colunas 1 a 46, e o ponto de apoio fica no centro (23,5; 12).

**Texturas vistas de frente (`assets/cenario/valcoroa/`):**

| Arquivo | Tamanho | Uso hoje |
|---|---|---|
| `muralha_face.png` | 64×48 | — |
| `parede_a.png` | 66×120 | — |
| `parede_b.png` | 98×98 | — |
| `parede_c.png` | 96×96 | lados da muralha |

**Peças (`assets/cenario/valcoroa/pecas/`, 23 arquivos):** cópias reduzidas dos recortes do Gemini (`Arte/cenario/valcoroa/recortes/`). Alguns tamanhos no jogo:

| Peça | Tamanho | Peça | Tamanho |
|---|---|---|---|
| torre | 51×86 | pilar | 23×52 |
| árvore | 85×80 | obelisco | 23×50 |
| seca | 47×62 | cristal | 22×30 |
| portal | 44×60 | tocha | 12×30 |
| arco | 42×58 | barril | 13×18 |
| cristal_nucleo | 29×40 | crânio | 13×11 |

**Escala de referência:** herói com cerca de 34 px de altura, numa célula de 64 (`assets/personagens/*/pixel/meta.json`).

## 2. Como o mapa é montado hoje

O mundo é **3D**, com câmera ortográfica a 30°/45°, e o 3D é desenhado com um pixel por pixel da arte.

- **Chão:** `SceneryGround` + `scenery_ground.gdshader`. É procedural, com lajes, grama e terra em manchas, caminho de calçamento e brilho na entrada.
- **Muralha:** `FortressWalls`. São caixas 3D por código com o shader `fortress_wall.gdshader`. A geometria sai de `wall_boxes()`.
- **Peças:** `SceneryProps`. São `Sprite3D` em billboard, com sorteio fixo por casa: no pé da muralha (`wallChance`, peso por tipo), nas casas livres (`groundChance`), no portal, na torre do canto e no cristal do núcleo.
- **Luz:** `SceneLight`, uma camada 2D que multiplica a imagem do 3D.

## 3. Problemas encontrados

1. **Cada peça tem um tamanho de pixel diferente.** Elas foram reduzidas para uma altura de tabela, com fatores entre **0,26 e 0,92**. Então um pixel da arte do crânio não tem o mesmo tamanho que um da torre. É o principal motivo de o cenário parecer "colado". Peças da mesma imagem do Gemini têm o mesmo pixel nativo (cerca de 11,5 px por pixel da arte) e deveriam ser reduzidas **pelo mesmo fator inteiro** (1/3 ou 1/2). Assim mantêm a grade e o tamanho relativo.
2. **O ponto de apoio está errado.** Todo sprite é apoiado no centro da largura, mas o pé fica fora do centro em várias peças:
   - árvore: tronco em x ≈ 29 de 85;
   - arco: 33,5 de 42;
   - portal: 34,5 de 44;
   - toco: 7,5 de 24;
   - tábua: 3 de 14.

   Por isso as árvores e o arco parecem flutuar ou ficam fora do lugar.
3. **Distribuição sem critério.** O sorteio por casa escolhe o tipo pelo peso, sem olhar o vizinho. Saem barril ao lado de árvore e cristal ao lado de caixa, sem formar "cantinhos". Também não há regra de espaço entre as peças.
4. **Ordem de desenho.** O billboard em 3D com um deslocamento para a frente (`forwardUnits`) resolve o chão cortando os pés, mas peças altas encostadas na parede podem passar na frente de um herói que está atrás delas.
5. **A parede é procedural**, feita com caixas texturizadas, e não peças desenhadas. O encaixe é correto, mas falta o acabamento que um tile desenhado teria. E não dá para o Pedro montar à mão no editor.
6. **O chão procedural tem borda de mancha suave**, enquanto a referência tem transições com capim e pedras por cima.

## 4. Arquitetura proposta: mundo em 2D com os recursos da Godot

Hoje só a **apresentação** é 3D. A simulação (`sim/`) não sabe nada de render. Por isso dá para trocar o mundo para 2D sem mexer nas regras.

```
World2D (Node2D, y_sort_enabled)
├── TerrainLayer   (TileMapLayer, isométrico 48×24)   terreno: lajes, terra, grama, por "terrains" do TileSet
├── PathLayer      (TileMapLayer)                     caminho: tiles de calçamento com borda (autotile por terrain)
├── EdgeLayer      (TileMapLayer)                     saia da plataforma e rebordo (tiles de 48×36)
├── WallLayer      (TileMapLayer, y_sort)             muralha: tiles altos (48×76) com origem no pé
├── Props          (Node2D, y_sort)                   peças: Sprite2D com offset no pé, colocadas por regras
├── Units          (Node2D, y_sort)                   heróis e inimigos (AnimatedSprite2D) — mesma ordem do Props
└── Light          (CanvasModulate + PointLight2D)    luz fria geral, tochas, portal e cristal
```

| Peça do sistema | Responsabilidade |
|---|---|
| `TerrainBuilder` | pinta o `TerrainLayer` com ruído em manchas grandes e usa os terrains do TileSet para as transições |
| `PathBuilder` | pinta o caminho a partir de `SimMap.path_cells`; o autotile acerta as curvas e as pontas |
| `WallBuilder` | casas fechadas vizinhas da área aberta viram muralha (alta atrás) ou saia (frente); o autotile acerta os cantos e as pontas |
| `PropPlacer` | coloca as peças por **conjuntos com regra**: depósito (barril, caixa) na muralha, guarda (tocha, braseiro) na beira do caminho, jardim (árvore, moita, capim) nos cantos, ruína (coluna, pedra). Tem espaço mínimo entre peças, não ocupa casa livre com peça alta e os dados ficam em `data/` |
| `DecorScatter` | miudezas e transições (capim, pedras e folhas na borda entre terrenos e na beira do caminho) |

**O que se ganha:**
- **Y-Sort nativo:** o herói passa atrás da árvore do jeito certo.
- **Pixel exato** simples: zoom inteiro na `Camera2D`.
- **Montagem à mão:** o Pedro pode pintar ou corrigir um mapa no editor.
- **Autotile** de paredes e caminhos pelo TileSet.

**O que custa:** refazer a camada `render/` do mundo, ou seja, chão, torres, inimigos, projéteis, efeitos, sobreposições e câmera, em 2D. A interface e a simulação não mudam. São várias tarefas, uma por vez, com os testes passando em cada uma.

## 5. Plano

1. **Teste isolado:** uma cena nova (`scenes/teste_mapa_2d.tscn`) com um pedaço de 12×12 casas montado pelos builders, com os assets atuais, heróis parados e Y-Sort. O jogo não muda.
2. Comparar com a referência (`Arte/cenario/valcoroa/alvo_visual_v3.webp`) e ajustar.
3. Só depois, se aprovado, migrar o mundo do jogo para 2D, parte por parte.

## 6. Teste 2D: primeira versão (05/11)

**Como abrir:** `scenes/teste_mapa_2d.tscn`. O jogo não mudou.

**Arquivos:**

| Arquivo | O que faz |
|---|---|
| `render2d/map2d_assets.gd` | TileSet isométrico de 48×24 com 3 atlas e as peças com o ponto do pé |
| `render2d/map2d_builders.gd` | terreno, caminho, muralha e saia, peças por regra e decoração |
| `render2d/map2d_test.gd` | a cena: camadas, Y-Sort, luz 2D e câmera com zoom 2 |
| `data/scenery2d.json` | mapa de teste, regras, espaçamentos e luzes |
| `tests/test_map2d.gd` | testes da montagem |

**Assets:** saem de `Arte/ferramentas/gerar_tiles_2d.py`, que só reduz, recorta e projeta as artes existentes.
- As peças são reduzidas por um **fator inteiro**, e cada uma tem o seu **ponto do pé**.
- As lajes e o caminho são as texturas `parede_b` e `parede_a` projetadas no losango, em 4×4 variantes que continuam de uma casa para a outra.
- A grama e a terra são os losangos de `grama/`, escurecidos.
- A muralha (meia casa, 40 px, ameias, pontas e canto) e a saia (12 px com rebordo) são feitas com `parede_c`.

**Ordem de desenho:**
- chão → caminho → saia (z_index);
- muralha, peças e heróis num `Node2D` com Y-Sort;
- a muralha se ordena meia casa para trás (`y_sort_origin`), então o que está na casa da frente dela é desenhado depois.

**Ainda falta, comparando com a referência:**
- terreno mais orgânico: as manchas de grama ainda mostram o losango;
- mais variedade de parede (estandartes, tochas de parede);
- o redemoinho do portal mais visível;
- inimigos e torres.
