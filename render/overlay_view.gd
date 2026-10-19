class_name OverlayView
extends Node3D
## Camadas de feedback por cima do mapa (porte de `HoverView.ts`, `CarryView.ts` e
## `LinkPreviewView.ts`):
##
## - torre fantasma na casa sob o mouse enquanto uma torre está na mão (verde se serve, vermelho
##   se não) com o alcance dela;
## - alcance e vizinhas afetadas da torre sob o mouse (janela de informações);
## - setas das ligações que a torre na mão vai ter naquela casa e o contorno das casas vizinhas.

const GHOST_SIZE := Vector3(0.42, 0.56, 0.42)

var _towers: TowerData
var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _ghost_range_disc: MeshInstance3D
var _ghost_range_ring: MeshInstance3D
var _hover_disc: MeshInstance3D
var _hover_ring: MeshInstance3D
var _frames: MeshInstance3D  # contornos de casas e setas (ImmediateMesh redesenhada)
var _frames_material: StandardMaterial3D
var _verts := PackedVector3Array()
var _cols := PackedColorArray()


func setup(towers: TowerData) -> void:
	_towers = towers
	var cfg: Dictionary = RenderConfig.data()
	var box := BoxMesh.new()
	box.size = GHOST_SIZE
	_ghost_material = MeshUtil.lit_material(Color(1, 1, 1, float(cfg["carry"]["alpha"])))
	_ghost = MeshUtil.instance(box, _ghost_material, self)
	_ghost.visible = false
	var range_cfg: Dictionary = cfg["towers"]["range"]
	var fill := RenderConfig.color(range_cfg["fillColor"], range_cfg["fillAlpha"])
	var line := RenderConfig.color(range_cfg["lineColor"], range_cfg["lineAlpha"])
	_ghost_range_disc = MeshUtil.instance(MeshUtil.disc_mesh(), MeshUtil.flat_material(fill), self)
	_ghost_range_ring = MeshUtil.instance(MeshUtil.ring_mesh(0.02), MeshUtil.flat_material(line), self)
	_hover_disc = MeshUtil.instance(MeshUtil.disc_mesh(), MeshUtil.flat_material(fill), self)
	_hover_ring = MeshUtil.instance(MeshUtil.ring_mesh(0.02), MeshUtil.flat_material(line), self)
	for n in [_ghost_range_disc, _ghost_range_ring, _hover_disc, _hover_ring]:
		n.visible = false
	_frames_material = StandardMaterial3D.new()
	_frames_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_frames_material.vertex_color_use_as_albedo = true
	_frames_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_frames_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frames = MeshInstance3D.new()
	_frames.mesh = ImmediateMesh.new()
	_frames.material_override = _frames_material
	_frames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_frames)


## Torre fantasma (tipo, casa, serve?); tipo "" ou casa null esconde.
func draw_ghost(tower_type: String, cell: Variant, valid: bool) -> void:
	var show := tower_type != "" and cell != null
	_ghost.visible = show
	_ghost_range_disc.visible = show
	_ghost_range_ring.visible = show
	if not show:
		return
	var color := RenderConfig.tower_color(_towers, tower_type)
	var tint := RenderConfig.color(RenderConfig.data()["hover"]["buildableColor" if valid else "blockedColor"])
	var c := color.lerp(tint, 0.35)
	c.a = float(RenderConfig.data()["carry"]["alpha"])
	_ghost_material.albedo_color = c
	_ghost.position = Vector3(cell.x, GHOST_SIZE.y / 2.0, cell.y)
	var radius := _towers.get_type(tower_type).range
	for n in [_ghost_range_disc, _ghost_range_ring]:
		n.position = Vector3(cell.x, 0.02, cell.y)
		n.scale = Vector3(radius, 1.0, radius)


## Alcance e vizinhas afetadas da torre sob o mouse (`hover_tower`, null esconde) e/ou a prévia das
## ligações da torre na mão (`links`, null esconde): setas + contorno das casas vizinhas.
func draw_info(hover_tower: Tower, neighbors: Array, links: TriggerLinks) -> void:
	_hover_disc.visible = hover_tower != null
	_hover_ring.visible = hover_tower != null
	var im := _frames.mesh as ImmediateMesh
	im.clear_surfaces()
	if hover_tower == null and links == null:
		return
	_verts.clear()
	_cols.clear()
	if hover_tower != null:
		var radius := _towers.get_type(hover_tower.type).range
		for n in [_hover_disc, _hover_ring]:
			n.position = Vector3(hover_tower.x, 0.02, hover_tower.y)
			n.scale = Vector3(radius, 1.0, radius)
		var info_cfg: Dictionary = RenderConfig.data()["hoverInfo"]
		var neighbor_color := RenderConfig.color(info_cfg["neighborColor"], info_cfg["neighborAlpha"])
		for neighbor: Tower in neighbors:
			_add_frame(neighbor.x, neighbor.y, neighbor_color)
	if links != null:
		var cfg: Dictionary = RenderConfig.data()["linkPreview"]
		var cell_color := RenderConfig.color(cfg["cellColor"], cfg["cellAlpha"])
		for cell in links.neighbor_cells:
			_add_frame(cell.x, cell.y, cell_color)
		for link in links.links:
			var color := RenderConfig.color(cfg["colors"][link.kind], cfg["arrowAlpha"])
			_add_arrow(Vector3(link.from.x, 0.9, link.from.y), Vector3(link.to.x, 0.9, link.to.y), color)
	if _verts.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in _verts.size():
		im.surface_set_color(_cols[i])
		im.surface_add_vertex(_verts[i])
	im.surface_end()


func _add_frame(cx: float, cz: float, color: Color) -> void:
	var h := 0.47
	var t := 0.07
	var y := 0.05
	var quads := [
		[Vector3(cx - h, y, cz - h), Vector3(cx + h, y, cz - h), Vector3(cx + h, y, cz - h + t), Vector3(cx - h, y, cz - h + t)],
		[Vector3(cx - h, y, cz + h - t), Vector3(cx + h, y, cz + h - t), Vector3(cx + h, y, cz + h), Vector3(cx - h, y, cz + h)],
		[Vector3(cx - h, y, cz - h), Vector3(cx - h + t, y, cz - h), Vector3(cx - h + t, y, cz + h), Vector3(cx - h, y, cz + h)],
		[Vector3(cx + h - t, y, cz - h), Vector3(cx + h, y, cz - h), Vector3(cx + h, y, cz + h), Vector3(cx + h - t, y, cz + h)],
	]
	for q: Array in quads:
		for i in [0, 1, 2, 0, 2, 3]:
			_verts.append(q[i])
			_cols.append(color)


func _add_arrow(from: Vector3, to: Vector3, color: Color) -> void:
	var cfg: Dictionary = RenderConfig.data()["linkPreview"]
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	dir /= length
	var inset := float(cfg["arrowInset"]) * RenderConfig.PX_TO_UNIT * 1.4
	var a := from + dir * inset
	var b := to - dir * inset
	var side := dir.cross(Vector3.UP).normalized()
	var w := float(cfg["arrowLineWidth"]) * RenderConfig.PX_TO_UNIT * 0.9
	var head_len := float(cfg["arrowHeadLength"]) * RenderConfig.PX_TO_UNIT * 1.4
	var head_w := float(cfg["arrowHeadWidth"]) * RenderConfig.PX_TO_UNIT * 1.4
	var neck := b - dir * head_len
	for v in [a - side * w, a + side * w, neck + side * w, a - side * w, neck + side * w, neck - side * w]:
		_verts.append(v)
		_cols.append(color)
	for v in [neck + side * head_w, neck - side * head_w, b]:
		_verts.append(v)
		_cols.append(color)
