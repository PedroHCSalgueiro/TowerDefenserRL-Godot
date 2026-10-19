class_name GridView
extends Node3D
## O chão do mapa: uma laje por casa (livre, caminho, entrada e núcleo), a casa sob o mouse e a casa
## selecionada (porte de `GridView.ts`). A casa sob o mouse vem do raio da câmera contra o chão.

var map: SimMap
var hovered_cell: Variant = null
var selected_cell: Variant = null
var _hover: MeshInstance3D
var _hover_material: StandardMaterial3D
var _selection: MeshInstance3D


func setup(p_map: SimMap) -> void:
	map = p_map
	var cfg: Dictionary = RenderConfig.data()["grid"]
	var free_mat := MeshUtil.lit_material(RenderConfig.color(cfg["freeColor"]))
	var path_mat := MeshUtil.lit_material(RenderConfig.color(cfg["pathColor"]))
	var entrance_mat := MeshUtil.lit_material(RenderConfig.color(cfg["entranceColor"]))
	var nexus_mat := MeshUtil.lit_material(RenderConfig.color(cfg["nexusColor"]))
	var slab := BoxMesh.new()
	slab.size = Vector3(0.96, 0.12, 0.96)
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			var mat := free_mat
			if cell == map.entrance:
				mat = entrance_mat
			elif cell == map.nexus:
				mat = nexus_mat
			elif map.is_path(cell):
				mat = path_mat
			var mi := MeshUtil.instance(slab, mat, self)
			mi.position = Vector3(x, -0.06, y)
	var hover_cfg: Dictionary = RenderConfig.data()["hover"]
	_hover_material = MeshUtil.flat_material(RenderConfig.color(hover_cfg["buildableColor"], hover_cfg["alpha"]))
	var hover_plane := PlaneMesh.new()
	hover_plane.size = Vector2(0.96, 0.96)
	_hover = MeshUtil.instance(hover_plane, _hover_material, self)
	_hover.visible = false
	var sel_cfg: Dictionary = RenderConfig.data()["selection"]
	_selection = MeshUtil.instance(MeshUtil.frame_mesh(1.0, 0.1), MeshUtil.flat_material(RenderConfig.color(sel_cfg["color"])), self)
	_selection.visible = false


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
