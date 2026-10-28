class_name GridView
extends Node3D
## O chão do mapa: uma laje por casa aberta (livre, caminho, entradas e núcleo), a casa sob o mouse e a
## casa selecionada (porte de `GridView.ts`). A casa sob o mouse vem do raio da câmera contra o chão.
##
## Mapa que cresce: casas fechadas não têm laje (ficam no escuro do fundo). Quando uma sala abre
## (`SimMap.revision` muda), as lajes novas sobem do escuro, uma depois da outra. Durante a escolha da
## parede, as salas oferecidas aparecem como chão fantasma na cor da opção (`show_candidates`), pulsando,
## e a entrada nova em vermelho.

var map: SimMap
var hovered_cell: Variant = null
var selected_cell: Variant = null
var _hover: MeshInstance3D
var _hover_material: StandardMaterial3D
var _selection: MeshInstance3D
var _tiles: Node3D
var _ghosts: Node3D
var _slab: BoxMesh
var _ghost_slab: BoxMesh
var _free_mat: Material
var _path_mat: Material
var _entrance_mat: Material
var _nexus_mat: Material
var _drawn_revision := -1
## Casas que já têm laje (índice -> true): só as novas sobem animadas.
var _drawn := {}
var _ghost_key := ""
## Materiais do chão fantasma e a opacidade base de cada um (para o pulso).
var _ghost_materials: Array = []
var _elapsed := 0.0


func setup(p_map: SimMap) -> void:
	map = p_map
	var cfg: Dictionary = RenderConfig.data()["grid"]
	_free_mat = MeshUtil.lit_material(RenderConfig.color(cfg["freeColor"]))
	_path_mat = MeshUtil.lit_material(RenderConfig.color(cfg["pathColor"]))
	_entrance_mat = MeshUtil.lit_material(RenderConfig.color(cfg["entranceColor"]))
	_nexus_mat = MeshUtil.lit_material(RenderConfig.color(cfg["nexusColor"]))
	_slab = BoxMesh.new()
	_slab.size = Vector3(0.96, 0.12, 0.96)
	_ghost_slab = BoxMesh.new()
	_ghost_slab.size = Vector3(0.92, 0.04, 0.92)
	_tiles = Node3D.new()
	add_child(_tiles)
	_ghosts = Node3D.new()
	add_child(_ghosts)
	_build_tiles(false)
	var hover_cfg: Dictionary = RenderConfig.data()["hover"]
	_hover_material = MeshUtil.flat_material(RenderConfig.color(hover_cfg["buildableColor"], hover_cfg["alpha"]))
	var hover_plane := PlaneMesh.new()
	hover_plane.size = Vector2(0.96, 0.96)
	_hover = MeshUtil.instance(hover_plane, _hover_material, self)
	_hover.visible = false
	var sel_cfg: Dictionary = RenderConfig.data()["selection"]
	_selection = MeshUtil.instance(MeshUtil.frame_mesh(1.0, 0.1), MeshUtil.flat_material(RenderConfig.color(sel_cfg["color"])), self)
	_selection.visible = false


## Chame a cada quadro: refaz o chão se o mapa mudou (sala aberta) e pulsa o chão fantasma.
## Devolve true no quadro em que o chão mudou.
func refresh(delta: float) -> bool:
	_elapsed += delta
	if not _ghost_materials.is_empty():
		var cfg: Dictionary = RenderConfig.data()["expansion"]
		var pulse := 0.75 + 0.25 * sin(_elapsed * TAU / float(cfg["pulseSeconds"]))
		for pair: Array in _ghost_materials:
			(pair[0] as StandardMaterial3D).albedo_color.a = float(pair[1]) * pulse
	if map.revision == _drawn_revision:
		return false
	_build_tiles(true)
	return true


func _material_for(cell: Vector2i, entrances: Dictionary) -> Material:
	if entrances.has(cell):
		return _entrance_mat
	if cell == map.nexus:
		return _nexus_mat
	if map.is_path(cell):
		return _path_mat
	return _free_mat


func _build_tiles(animate: bool) -> void:
	_drawn_revision = map.revision
	var entrances := {}
	for i in map.entrance_count():
		entrances[map.entrance_cell(i)] = true
	var fresh: Array[MeshInstance3D] = []
	var fresh_center := Vector2.ZERO
	for child in _tiles.get_children():
		_tiles.remove_child(child)
		child.queue_free()
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if not map.is_open(cell):
				continue
			var mi := MeshUtil.instance(_slab, _material_for(cell, entrances), _tiles)
			mi.position = Vector3(x, -0.06, y)
			var index := map.index_of(cell)
			if animate and not _drawn.has(index):
				fresh.append(mi)
				fresh_center += Vector2(x, y)
			_drawn[index] = true
	if fresh.is_empty():
		return
	# As lajes novas sobem do escuro, de dentro para fora da sala.
	var cfg: Dictionary = RenderConfig.data()["expansion"]
	fresh_center /= float(fresh.size())
	var rise := float(cfg["riseSeconds"])
	var tween := create_tween().set_parallel(true)
	for mi in fresh:
		var spread := Vector2(mi.position.x, mi.position.z).distance_to(fresh_center)
		mi.position.y = -0.06 - float(cfg["riseDepth"])
		tween.tween_property(mi, "position:y", -0.06, rise) \
				.set_delay(spread * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Salas oferecidas na escolha da parede: chão fantasma na cor de cada opção; `hovered` (índice da opção
## sob o mouse, -1 = nenhuma) fica mais forte e as outras mais fracas. Lista vazia apaga.
func show_candidates(rooms: Array, hovered: int) -> void:
	var ids: Array = rooms.map(func(r: ExpansionData.Room) -> String: return r.id)
	var key := "%s|%d" % [",".join(ids), hovered]
	if key == _ghost_key:
		return
	_ghost_key = key
	for child in _ghosts.get_children():
		_ghosts.remove_child(child)
		child.queue_free()
	_ghost_materials.clear()
	var cfg: Dictionary = RenderConfig.data()["expansion"]
	for i in rooms.size():
		var room: ExpansionData.Room = rooms[i]
		var alpha := float(cfg["alpha"])
		if hovered == i:
			alpha = float(cfg["hoverAlpha"])
		elif hovered >= 0:
			alpha *= 0.4
		var mat := MeshUtil.flat_material(Color(ExpansionScreenUi.option_color(i), alpha))
		_ghost_materials.append([mat, alpha])
		for cell in room.cells:
			MeshUtil.instance(_ghost_slab, mat, _ghosts).position = Vector3(cell.x, -0.1, cell.y)
		if room.has_entrance():
			var door := MeshUtil.flat_material(RenderConfig.color(cfg["entranceColor"], minf(1.0, alpha + 0.25)))
			_ghost_materials.append([door, minf(1.0, alpha + 0.25)])
			for cell in room.entrance_cells:
				MeshUtil.instance(_ghost_slab, door, _ghosts).position = Vector3(cell.x, -0.08, cell.y)


## Bloco de casas que a câmera deve mostrar: as abertas e, se houver, as `extra` (salas oferecidas).
func view_cells(extra: Array = []) -> Rect2i:
	var lo := Vector2i(map.width, map.height)
	var hi := Vector2i(-1, -1)
	for y in map.height:
		for x in map.width:
			if map.is_open(Vector2i(x, y)):
				lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
				hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
	for room: ExpansionData.Room in extra:
		var cells: Array[Vector2i] = []
		cells.append_array(room.cells)
		cells.append_array(room.entrance_cells)
		for cell in cells:
			lo = Vector2i(mini(lo.x, cell.x), mini(lo.y, cell.y))
			hi = Vector2i(maxi(hi.x, cell.x), maxi(hi.y, cell.y))
	return Rect2i(lo, hi - lo + Vector2i.ONE)


## Atualiza a casa sob o mouse. `screen_pos` null = mouse fora do jogo (sobre a interface).
func update_hover(camera: Camera3D, screen_pos: Variant) -> void:
	hovered_cell = GroundProjection.cell_at_screen(camera, screen_pos, map) if screen_pos != null else null


## Realça a casa sob o mouse: verde se dá para construir, vermelho se não (`valid` null = só
## contorno neutro).
func show_hover(cell: Variant, valid: bool) -> void:
	_hover.visible = cell != null
	if cell == null:
		return
	var cfg: Dictionary = RenderConfig.data()["hover"]
	_hover_material.albedo_color = RenderConfig.color(cfg["buildableColor"] if valid else cfg["blockedColor"], cfg["alpha"])
	_hover.position = Vector3(cell.x, 0.02, cell.y)


func select(cell: Variant) -> void:
	selected_cell = cell
	_selection.visible = cell != null
	if cell != null:
		_selection.position = Vector3(cell.x, 0.03, cell.y)
