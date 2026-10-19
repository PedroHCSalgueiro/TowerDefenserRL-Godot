# Plano: portar o Tower Defense Roguelite (Phaser/TS) para o Godot

## Context

O jogo (Protótipo 1, ~T01–T25) está no GitHub (`PedroHCSalgueiro/TowerDefenserRL`, 30 commits, Phaser 4 + TypeScript + Vite + Vitest). Pedro decidiu migrar para o Godot: o teste de 3–5 dias (Notion, "Teste Godot") e o teste local do personagem Sir Aldric (`C:\Users\pedro\Documents\godot-tower-defense`) já funcionaram. Alvos: **PC (Steam) + Web**, então a linguagem é **GDScript** (o export web do Godot 4 não suporta C#; GodotSteam funciona com GDScript). Escopo: **tudo do Protótipo 1**. Projeto vai para um **novo repositório**; o Phaser fica intacto como referência.

**O que torna o porte viável:** o repositório já separa a regra do jogo da tela.
- `src/sim/` (~60 arquivos, TypeScript puro, sem Phaser, determinístico com RNG com semente, estado serializável) → vira GDScript quase 1:1, sem redesenhar nada.
- `src/data/*.json` (towers, classes, waves, economy, enemies, rewards, ui, render...) → o Godot lê JSON direto. Copiar, não reescrever. (`waves.json` tem 89 KB.)
- `tests/` (~60 arquivos) → fonte de verdade para provar que o porte se comporta igual.
- Só `src/render/` (Phaser, ~15 arquivos) e `src/ui/` (HTML/CSS, ~27 arquivos) precisam ser refeitos de verdade, em nós 3D/Control do Godot.

**Estado atual do Godot local:** um protótipo descartável (`scripts/game.gd`, 35 KB monolítico, 3 torres, grade 18×10, 300 inimigos, Sir Aldric com `.glb` + animação). Não é git, não tem a sim real. Serve como **laboratório de câmera/arte** — reaproveitar: câmera ortográfica 45°/45°, `assets/archer.glb`, `sir-aldric.glb`, `scenes/sir_aldric.tscn`, `sir_aldric_ataque.res`. O resto é jogado fora.

## Decisões de arquitetura (a regra mais importante)

1. **Mesma separação do Phaser:** `sim/` em GDScript puro (`RefCounted`, sem nós, sem `Node`/cena), `render/` e `ui/` só leem estado e eventos. Isso mantém a sim testável e deixa o port mecânico.
2. **Dados em JSON, números fora do código** (regra do CLAUDE.md atual continua valendo). `data/*.json` copiados byte a byte do repo antigo.
3. **Determinismo preservado:** reimplementar o RNG com semente (`rng.ts`) exatamente igual (mesmo algoritmo, não `RandomNumberGenerator` do Godot), senão os testes de comparação não batem.
4. **Tick fixo** a 30/s, render interpolado; velocidade 1x/2x/3x = mais ticks por quadro (`engine/clock.ts`).
5. **Performance:** MultiMeshInstance3D para inimigos/projéteis (centenas de inimigos), hash espacial portado de `spatialIndex.ts`, pools portados de `enemies/pool.ts` e `projectiles/pool.ts`.
6. **Testes:** GUT ou gdUnit4 (escolher um no passo 1) rodando headless: `godot --headless -s addons/gut/gut_cmdln.gd`.
7. **Render 3D, não 2D iso:** o Godot já usa câmera ortográfica 45° — o `iso.ts` (projeção isométrica manual) deixa de existir; a grade passa a ser coordenadas (x, 0, z).

## Fases

### Fase 0 — Preparação (meio dia)
- Instalar `gh` (GitHub CLI) ou configurar git/credenciais — hoje `gh` não existe na máquina.
- Criar repositório novo (ex.: `TowerDefenserRL-Godot`), `.gitignore` do Godot, `.gitattributes` com **Git LFS** para `.glb`/`.png`/`.jpg` (`sir-aldric.glb` tem 42 MB; texturas de 22 MB não devem entrar cruas no git).
- Clonar `TowerDefenserRL` ao lado como `reference/` (não copiado no novo repo) para consulta e para rodar os testes antigos.
- Escrever o novo `CLAUDE.md` (adaptar o do Notion: Godot 4.7, GDScript, `sim/` sem nós, números só em `data/`, RNG com semente, comandos de teste/export, regras do Notion/Diário/commit-por-tarefa).
- Criar o projeto Godot limpo (Godot 4.7, GL Compatibility — necessário para web) e trazer do laboratório só os assets de arte.

### Fase 1 — Núcleo da simulação (maior parte do trabalho, ~35% do total)
Portar em ordem de dependência, sempre **arquivo + teste correspondente juntos**:
1. `sim/engine/` — `rng`, `clock`, `events` (barramento → sinais ou lista de eventos), `simulation`.
2. `sim/grid/` — `map`, `neighbors` + `data/map.json`.
3. `sim/enemies/` — `enemyData`, `route`, `pool`, `order`, `armor`, `damage`, `systems`.
4. `sim/spatial/spatialIndex`, `sim/projectiles/`.
5. `sim/towers/` — `towerData`, `stars`, `fusion`, `placement`, `move`, `limit`, `targeting`, `systems`.
6. `sim/triggers/` — `triggerData`, `triggerState`, `neighborhood`, `links`, `effects`, `engine` (**o coração e o maior: ~22 KB + 16 KB**; proteção de 1×/s por torre e profundidade máxima da cadeia).
7. `sim/classes/` (bônus por contagem), `sim/economy/`, `sim/shop/`, `sim/nexus/`, `sim/waves/` (pulsos, empilhamento, fila invisível), `sim/rewards/` (T24), `sim/commands.ts`, `sim/state.ts`, `sim/systems.ts`.
- Tradução TS→GDScript: interfaces viram `class_name` + `RefCounted` ou `Dictionary` tipado (decidir uma convenção e manter); números "inteiros" do TS continuam `int`/`float` explícitos (cuidado: divisão inteira e arredondamento diferem — revisar `Math.floor/round`).
- **Teste de paridade (rede de segurança):** gerar no repo antigo "golden files" — rodar o simulador TS com sementes fixas + uma sequência de comandos (`tests/support/goodBot.ts`, `waveBot.ts`) e salvar o estado por tick/onda em JSON; o Godot roda a mesma semente/comandos e compara. Se bater onda a onda, o porte está correto.

### Fase 2 — Render 3D + câmera (~20%)
- Cena `Game.tscn`: grade (`GridView`), caminho, núcleo (`NexusView`), torres (`TowerView`), inimigos via MultiMesh (`EnemyView`), projéteis (`ProjectileView`), efeitos de gatilho (`triggerFx` + `TriggerFxView`: linhas de cadeia, "Cadeia xN", flash de fusão), preview de ligação e hover.
- `CameraController`/`camera.ts` (zoom na roda ×1,2, botão direito arrasta, setas 800 px/s, botão do meio reseta, limites, borda da tela com torre na mão) → `Camera3D` ortográfica reaproveitando a configuração 45°/45° do laboratório. Números em `data/render.json`.
- Torres e inimigos começam com **formas simples (greybox, como no Phaser)**; modelos de verdade vêm depois (Fase 6).

### Fase 3 — UI (~25%)
Refazer o `src/ui/` (HTML/CSS) com nós `Control` + `Theme` (um tema central substitui `ui.css`). Manter a separação "model" (lógica pura, já testada — `shopModel`, `waveHudModel`, `towerDragModel`, `tutorialModel`...) e "panel/controller" (nós):
- Loja (5 slots, reroll, venda, teclas 1–5), drag-and-drop de torres + teclas, tooltip de torre, painel de classes, painel do núcleo, HUD de ondas/ouro/juros/multiplicador "x3!", anúncio de onda, tela de recompensa (T24), tela de ajuda (H), tutorial contextual, tela de fim + relatório da run, rótulo de versão.
- Mapeamento de input (`mouseButtons.ts`, atalhos) para `InputMap`.
- Painel de debug/perf (`src/debug/`): FPS, tick, inimigos ativos, semente, trapaças — usar o Monitor do Godot + um `CanvasLayer` com o mesmo conteúdo.

### Fase 4 — Save e fluxo do jogo (~5%)
- Save da run (estado já é serializável → `JSON` em `user://`), versão de save para migrações. Laboratório e menus são pós-protótipo (fora de escopo, conforme o Mini-GDD).

### Fase 5 — Exports e CI (~5%)
- Presets de export: **Windows (.exe)** e **Web**. Web com GL Compatibility; checar threads/`SharedArrayBuffer` (o headers COOP/COEP necessários para build com threads — usar build sem threads para GitHub Pages/itch).
- Reproduzir o que o Phaser tinha: `.github/workflows/ci.yml` (testes) e `deploy.yml` (URL de teste) usando a imagem `barichello/godot-ci`.
- Medir os critérios do plano de teste do Notion: 1.000 inimigos + 30 torres com cadeia real a 60 FPS no PC; ≥ 30 FPS no web; tamanho do web < 50 MB.

### Fase 6 — Personagens e arte (depois do porte, não bloqueia)
- Integrar Sir Aldric (`.glb` + `AnimationPlayer` + shader cel shading/contorno) como a primeira torre com arte, seguindo o Guia de Estilo e as Fichas Visuais do Notion. **Reduzir o `.glb`/texturas antes** (42 MB / PNG de 22 MB não servem para web).
- Passar as 8 torres do protótipo de formas simples para personagens, uma por vez.
- Steam: GodotSteam (extensão em GDScript) só depois do jogo fechado — conquistas, cloud save, build de depot. Fora deste plano.

## Ordem de entrega sugerida (cada item roda e é jogável)
1. Repo + projeto vazio + CI de testes verde (Fase 0).
2. Sim portada + paridade com TS verde, **jogando só por testes/bot** (Fase 1).
3. Tela greybox rodando uma run completa de 10 ondas sem UI polida (Fase 2 + mínimo da 3).
4. UI completa + câmera = paridade com o que o Phaser faz hoje (Fase 3).
5. Save + exports Windows e Web + deploy (Fases 4–5).
6. Sir Aldric e as outras torres com arte (Fase 6).

## Riscos
- **Gatilhos em cadeia (`triggers/engine.ts`)**: maior chance de divergência sutil → resolvido pelos golden files; não pular.
- **Diferenças numéricas TS vs GDScript** (float64 vs int/float, `Math.round`, divisão): ver Fase 1.
- **Performance de GDScript** com muitas entidades: manter dados em `Array`/`PackedFloat32Array`, evitar `Dictionary` por inimigo no caminho quente; se faltar, o ponto crítico (hash espacial + movimento) pode virar GDExtension depois.
- **Web export**: sem C#, threads/headers, tamanho de assets.
- **Texto do Phaser 4**: nenhum — saímos dele.

## Arquivos críticos
- Origem (reference): `src/sim/**`, `src/data/*.json`, `tests/**`, `tests/support/{goodBot,waveBot}.ts`, `CLAUDE.md`, `.github/workflows/*.yml`.
- Destino (novo repo): `sim/`, `render/`, `ui/`, `data/`, `tests/`, `addons/gut` (ou gdUnit4), `CLAUDE.md`, `export_presets.cfg`.
- Reaproveitar do laboratório: `C:\Users\pedro\Documents\godot-tower-defense\{assets,scenes\sir_aldric.tscn,blender}`; câmera e shader de `scripts\game.gd` como referência.

## Verificação
- `godot --headless` roda toda a suíte portada (`tests/`) com 0 falhas; teste de paridade (golden files) bate nas sementes escolhidas.
- Rodar uma run de 10 ondas com chefão pelo bot e pelo jogo manualmente (`mcp__godot__run_project`) e comparar com a mesma semente no Phaser.
- Benchmark: 1.000 inimigos + 30 torres com cadeias reais ≥ 60 FPS (PC), ≥ 30 FPS (web).
- Exportar Windows e Web e abrir ambos; carregar em < 5 s no web, < 50 MB.

## Perguntas em aberto para você (não bloqueiam o plano)
- Registro de progresso: continuar atualizando o Diário de Desenvolvimento do Notion por tarefa, com T-IDs novos para o porte? (sugestão: sim, banco "Tarefas do Porte Godot".)
- Quando migrar de verdade: congelar o Phaser (`main`) assim que a Fase 3 estiver igual, ou manter os dois por um tempo?
