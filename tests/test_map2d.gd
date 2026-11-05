extends GutTest
## Mapa 2D de teste (`Map2DBuilders`): as peças e a decoração nunca ficam no caminho nem fora do mapa, todo tile pedido
## existe no atlas, e a montagem é a mesma em toda execução (sem sorteio solto).

var cfg: Dictionary
var map: SimMap
var assets: Map2DAssets


func before_all() -> void:
	cfg = DataLoader.load_json("scenery2d.json")
	map = SimMap.load_map(cfg["testMap"])
	assets = Map2DAssets.load_from(String(cfg["assets"]))


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x + 0.5), floori(at.y + 0.5))


func test_tiles_pedidos_existem() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	for name: String in Map2DBuilders.wall_tiles(map, cells, portals).values():
		assert_true(assets.has_tile("muralha", name), name)
	for name: String in Map2DBuilders.edge_tiles(map, cells).values():
		assert_true(assets.has_tile("borda", name), name)


func test_pecas_fora_do_caminho() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	var props := Map2DBuilders.place_props(map, cells, portals, cfg)
	var decor := Map2DBuilders.scatter_decor(map, Map2DBuilders.terrain_kinds(map, cfg["terrain"]), props, cfg)
	assert_gt(props.size(), 5)
	for p: Dictionary in props + decor:
		var c := _cell(p["at"])
		if p["name"] in ["portal", "torre"]:
			continue
		assert_false(map.is_inside(c) and map.is_path(c) and not (p["name"] in ["tocha", "braseiro", "cristal_nucleo"]),
				"%s em cima do caminho (%s)" % [p["name"], c])
		assert_true(assets.meta["pecas"].has(p["name"]), "peça existe: %s" % p["name"])


func test_montagem_e_sempre_igual() -> void:
	var cells := FortressWalls.wall_cells(map)
	var portals := SceneryProps.portal_cells_of(map)
	var a := Map2DBuilders.place_props(map, cells, portals, cfg)
	var b := Map2DBuilders.place_props(map, cells, portals, cfg)
	assert_eq(str(a), str(b))



func test_posicao_das_pecas_bate_com_as_casas_do_tilemap() -> void:
	var l := TileMapLayer.new()
	l.tile_set = assets.tile_set
	add_child_autofree(l)
	# casa inteira: exatamente o centro que o TileMap usa para desenhar o losango
	for c: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(3, 5), Vector2i(-1, 0), Vector2i(10, 11)]:
		assert_eq(Map2DBuilders.cell_point(l, c.x, c.y), l.map_to_local(c), "centro da casa %s" % c)
	# fração: a mesma direção e escala do losango (meia casa em x anda 12 px para a direita e 6 para baixo)
	assert_eq(Map2DBuilders.cell_point(l, 2.5, 3.0) - l.map_to_local(Vector2i(2, 3)), Vector2(12, 6))
	assert_almost_eq(Map2DBuilders.cell_point(l, 4.0, 1.7) - l.map_to_local(Vector2i(4, 2)), Map2DBuilders.iso(0.0, -0.3), Vector2(0.001, 0.001))
	# a casa vizinha está a uma casa de distância (o iso é só o vetor, não a posição)
	assert_eq(l.map_to_local(Vector2i(1, 0)) - l.map_to_local(Vector2i(0, 0)), Map2DBuilders.iso(1, 0))


func test_ancoras_seguem_o_modo_de_cada_peca() -> void:
	for name: String in assets.meta["pecas"]:
		var info: Dictionary = assets.meta["pecas"][name]
		var pe: Array = info["pe"]
		var h := int(info["tamanho"][1])
		if info["modo"] == "portal":
			continue  # conferido em test_portal_*
		if info["modo"] == "base":
			assert_eq(int(pe[1]), h, "%s (base): o pé é a linha mais baixa" % name)
		else:
			# pegada: o centro do losango da base, largura/4 acima da ponta de baixo
			assert_eq(int(pe[1]), _round_half_even(h - float(info["base"]) / 4.0), "%s (pegada): pé no centro da base" % name)
			assert_lt(int(pe[1]), h, "%s: pé acima da linha mais baixa" % name)
		assert_true(int(pe[0]) >= 0 and int(pe[0]) <= int(info["tamanho"][0]), "%s: pé dentro da imagem" % name)


## Mesma regra do gerador (round() do Python): o meio vai para o par. O round() do GDScript sobe o meio (52,5 -> 53).
func _round_half_even(v: float) -> int:
	var f := floorf(v)
	if is_equal_approx(v - f, 0.5):
		return int(f) if int(f) % 2 == 0 else int(f) + 1
	return int(roundf(v))


func test_arredondamento_segue_o_gerador() -> void:
	assert_eq(_round_half_even(52.5), 52, "árvore: 58 - 22/4 = 52,5")
	assert_eq(_round_half_even(25.5), 26, "cristal: 31 - 22/4 = 25,5")
	assert_eq(_round_half_even(23.5), 24, "tocha: 26 - 10/4 = 23,5")
	assert_eq(_round_half_even(19.25), 19)


func test_ponto_de_contato_da_arvore_no_sprite() -> void:
	# o que o Sprite2D usa de verdade: pé 52 (centro da base) + ajuste [8, -3] -> o tronco toca o chão em (19, 49)
	var s := assets.prop("arvore")
	assert_eq(s.offset, Vector2(-19, -49))
	assert_false(s.centered)
	s.free()


func test_decoracao_achatada_preserva_a_ancora_antiga() -> void:
	# capim, crânio, pedras, raiz, cogumelo e tábua já tocavam o chão pela linha de baixo: continuam iguais
	var antes := {"capim": [8, 10], "cranio": [6, 10], "pedras": [8, 12], "raiz": [4, 11], "cogumelo": [8, 16], "tabua": [4, 9],
			"torre": [28, 94]}
	for name: String in antes:
		assert_eq(assets.foot_of(name), Vector2(antes[name][0], antes[name][1]), name)


func test_ajuste_manual_e_respeitado() -> void:
	var info: Dictionary = assets.meta["pecas"]["barril"]
	var guardado: Array = info.get("ajuste", [0, 0])
	info["ajuste"] = [3, -2]
	var s := assets.prop("barril")
	assert_eq(s.offset, -(Vector2(float(info["pe"][0]), float(info["pe"][1])) + Vector2(3, -2)))
	s.free()
	info["ajuste"] = guardado
	var arvore: Dictionary = assets.meta["pecas"]["arvore"]
	assert_eq(assets.foot_of("arvore"), Vector2(float(arvore["pe"][0]) + float(arvore["ajuste"][0]), float(arvore["pe"][1]) + float(arvore["ajuste"][1])))



func _portal() -> Array:
	var portals := SceneryProps.portal_cells_of(map)
	assert_eq(portals.size(), 1, "o mapa de teste tem uma entrada")
	var c: Vector2i = portals.keys()[0]
	return [c, portals[c]]


func test_portal_tamanho_e_pe() -> void:
	var info: Dictionary = assets.meta["pecas"]["portal"]
	assert_eq(info["modo"], "portal")
	assert_eq(int(info["fator"]), 2, "arco nativo 56x77 reduzido por fator inteiro 2")
	assert_eq(Vector2i(int(info["tamanho"][0]), int(info["tamanho"][1])), Vector2i(28, 38))
	var muralha_px: int = 40
	assert_lt(int(info["tamanho"][1]), muralha_px, "o portal cabe embaixo do topo da muralha (a parede faz a verga)")
	# o pé fica entre os dois pilares, na altura dos pés deles (não na ponta de um só)
	var pe: Array = info["pe"]
	assert_true(int(pe[0]) > 8 and int(pe[0]) < 20, "pé no meio da largura: %s" % [pe])
	assert_true(int(pe[1]) > 30 and int(pe[1]) <= 38, "pé na base: %s" % [pe])
	# a abertura deixa passar um inimigo (diâmetro 2 x enemies.radius, em pixels da arte)
	var ab: Array = info["abertura"]
	var inimigo := 2.0 * float(RenderConfig.data()["enemies"]["radius"])
	assert_gt(float(ab[3] - ab[1]), inimigo, "abertura mais alta que um inimigo")
	assert_gt(float(ab[2] - ab[0]), inimigo * 0.5, "abertura mais larga que meio inimigo")


func test_portal_na_face_de_dentro_da_muralha() -> void:
	var p := _portal()
	var c: Vector2i = p[0]
	var out: Vector2i = p[1]
	var props := Map2DBuilders.place_props(map, FortressWalls.wall_cells(map), SceneryProps.portal_cells_of(map), cfg)
	var portal: Dictionary = props.filter(func(x: Dictionary) -> bool: return x["name"] == "portal")[0]
	assert_eq(portal["at"], Vector2(c) - Vector2(out) * 0.5, "na face de dentro, centrado na casa")
	assert_eq(portal["flip"], out.x != 0, "espelhado na parede que corre ao longo de z")


func test_portal_chao_e_muralha_em_volta() -> void:
	var p := _portal()
	var c: Vector2i = p[0]
	var out: Vector2i = p[1]
	var cells := FortressWalls.wall_cells(map)
	# soleira: o chão do caminho na casa do portal, existente no atlas
	var sol := Map2DBuilders.threshold_tiles(SceneryProps.portal_cells_of(map))
	assert_true(sol.has(c))
	assert_true(assets.has_tile("chao", sol[c]), sol[c])
	assert_true(String(sol[c]).begins_with("soleira_z_" if out.x != 0 else "soleira_x_"))
	# a muralha continua na casa do portal (verga e batentes) e nas duas vizinhas ao longo da parede
	var wt := Map2DBuilders.wall_tiles(map, cells, SceneryProps.portal_cells_of(map))
	var along := Vector2i(0, 1) if out.x != 0 else Vector2i(1, 0)
	for k in [-1, 0, 1]:
		var w: Vector2i = c + along * int(k)
		assert_true(wt.has(w), "muralha em %s" % w)
		assert_true(assets.has_tile("muralha", wt[w]), wt[w])
	# a casa de dentro, na frente do portal, é o começo do caminho
	assert_true(map.is_path(c - out), "o caminho começa na frente do portal")
	# a saia não passa pela casa do portal (ela é só da borda da frente)
	assert_false(Map2DBuilders.edge_tiles(map, cells).has(c))


func test_quem_passa_pelo_portal_fica_na_frente_dele() -> void:
	var l := TileMapLayer.new()
	l.tile_set = assets.tile_set
	add_child_autofree(l)
	var p := _portal()
	var c: Vector2i = p[0]
	var out: Vector2i = p[1]
	var portal_y := Map2DBuilders.cell_point(l, Map2DBuilders.portal_point(c, out).x, Map2DBuilders.portal_point(c, out).y).y
	# Y-Sort: um herói ou inimigo na casa de entrada (logo depois do vão) é desenhado depois do portal
	var entrada_y := Map2DBuilders.cell_point(l, (c - out).x, (c - out).y).y
	assert_gt(entrada_y, portal_y)
	# e a muralha vizinha (ordenada meia casa para trás) é desenhada antes do portal: não atravessa os pilares
	var along := Vector2i(0, 1) if out.x != 0 else Vector2i(1, 0)
	var y_origin := -int(assets.meta["tile"][1]) / 2 - 1
	for k in [-1, 0, 1]:
		var w: Vector2i = c + along * int(k)
		assert_lt(l.map_to_local(w).y + y_origin, portal_y, "muralha %s antes do portal" % w)
