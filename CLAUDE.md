# Tower Defense Roguelite (Godot)

Tower defense roguelite 2.5D para PC (Steam) e navegador (mouse e teclado).
O jogador compra torres numa loja com reroll, posiciona em grade e
monta composições de classes cujos gatilhos disparam em cadeia
contra hordas de centenas de inimigos.

Este repositório é o **porte para o Godot** do jogo feito em Phaser 4 + TypeScript
(`PedroHCSalgueiro/TowerDefenserRL`). O Phaser continua como **referência** e fonte
dos testes. Clone local de consulta: `C:\Users\pedro\Documents\TowerDefenserRL-reference`
(somente leitura; nunca copiar código do Phaser para cá).

Repositório (privado): https://github.com/PedroHCSalgueiro/TowerDefenserRL-Godot
Plano do porte: `docs/plano-porte-godot.md`.

## Links do Notion (use sempre estes, não precisa buscar)
- Mini-GDD (regras do jogo): https://app.notion.com/p/3e4c656560ae81f4b23dc4c4ece91da4
- Documento Técnico (do Phaser; arquitetura continua valendo): https://app.notion.com/p/3e5c656560ae81e991d3fc03b62227a4
- Diário de Desenvolvimento: https://app.notion.com/p/3e5c656560ae811f9631fdd9de2301f0
- Teste Godot: https://app.notion.com/p/3f9c656560ae81fb8a12ce9a4607b871
- Direção de Arte: https://app.notion.com/p/3ebc656560ae8102a571de5ca487830d
- Guia de Estilo Visual — Personagens: https://app.notion.com/p/3fac656560ae8150933de77457155594

Quando Pedro disser "execute a tarefa X", leia a tarefa e as seções do Mini-GDD
citadas, apresente um plano e só então implemente.

## Stack
- Godot 4.7, **GDScript** (C# não exporta para web), renderer GL Compatibility
- Alvos: Windows (Steam, GodotSteam depois) e Web
- Testes: GUT (a instalar em `addons/gut`), rodando headless

## Arquitetura (regra mais importante)
- `sim/`: lógica pura em GDScript (`RefCounted`, sem `Node`, sem cenas). PROIBIDO tocar em nós aqui.
- `render/`: nós 3D. Só lê estado e eventos da simulação.
- `ui/`: nós `Control` + `Theme` central. Lógica de tela em "model" puro, nós só desenham.
- `data/`: todos os números do jogo, em JSON (copiados do repo Phaser, mesma estrutura).
  Conjuntos da tela inicial em `data/sets/sets.json`: cada um lista camadas (`layers`) de `data/sets/`
  mescladas em ordem sobre `data/` — `heroes` (regras comuns dos heróis: 8 classes, economia, ondas),
  `valcoroa`, `costarubra` e `valcoroa_costarubra` (só o cenário de debug dos 16).
- `tests/`: testes da simulação.
- `assets/`, `scenes/`, `blender/` (com `.gdignore`): arte.

## Regras
- Nunca colocar números de jogo no código: sempre em `data/`.
- Toda regra da simulação vem com teste em `tests/`.
- Simulação determinística: RNG com semente portado de `rng.ts` do Phaser (mesmo algoritmo),
  nunca `randf()`/`RandomNumberGenerator` na sim.
- Tick fixo (30/s); render interpola; velocidade 1x/2x/3x = mais ticks por quadro.
- Porte arquivo a arquivo, **com o teste correspondente junto**. Paridade com o Phaser
  é provada por golden files (mesma semente + mesmos comandos = mesmo estado por onda).
- Cuidado com TS vs GDScript: divisão inteira, `Math.round`/`floor`, `int` vs `float`.
  O JSON do Godot traz todo número como `float`: converta com `int()` onde é inteiro e
  nunca divida dois `int` com `/` (no GDScript é divisão inteira). `Array.has(2.0)` não acha `2`.
- Convenções do porte: classes/métodos/propriedades em `snake_case`; **dados que cruzam a
  fronteira** (eventos, comandos, golden/save em JSON) mantêm as chaves do Phaser em
  `camelCase` (ex.: `{"type": "enemySpawned", "enemyId": 7}`). Célula da grade = `Vector2i`.
  Erros de entrada inválida: `push_error` + valor neutro (`null`), nunca exceção; teste com `assert_push_error`.
  Nomes que colidem com o Godot ganham outro nome (`GridMap` → `SimMap`).
- Não adicionar dependências/addons sem justificar.
- Tarefas pequenas: uma por vez, testes passando no fim.
- Arte pesada (`.glb`, `.png`, `.jpg`, `.blend`) vai pelo Git LFS (ver `.gitattributes`).
  Antes de exportar para web, reduzir modelos e texturas.

## Ao terminar cada tarefa (obrigatório)
1. Marcar o status da tarefa no Notion (banco de tarefas do porte, a criar).
2. Adicionar entrada no topo do "Diário de Desenvolvimento", seguindo o modelo da página.
3. Nunca decidir regra de jogo sozinho: registrar em "Perguntas de design" e perguntar ao Pedro.
4. Commit e push antes de marcar como Feito.

## Comandos
Godot 4.7.2 nesta máquina (a pasta se chama `.exe`; o executável está dentro dela):
`E:\Download\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` (use `$g` abaixo).
O MCP do Godot procura em `C:\Program Files\Godot\Godot.exe`; definir `GODOT_PATH` se for usá-lo.
- Importar assets (após clonar ou mudar arte): `$g --headless --path . --import`
- Abrir editor: `$g --editor --path .`
- Rodar jogo: `$g --path .`
- Testes (GUT 9.7.1): `$g --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Export: `$g --headless --export-release "Windows" build/windows/game.exe` e `"Web"` (presets a criar)

Texturas extraídas do `sir-aldric.glb` na importação ficam fora do git (ver `.gitignore`).
