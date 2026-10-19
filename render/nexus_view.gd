class_name NexusView
extends Node3D
## Desenha o núcleo (porte de `NexusView.ts`): um pilar vermelho no fim do caminho, a barra de vida
## acima e a linha do ataque fraco ao alvo.

var _map: SimMap
var _cfg: Dictionary
var _pillar: MeshInstance3D
var _bar_back: MeshInstance3D
var _bar_fill: MeshInstance3D
var _bar_pivot: Node3D
var _line: MeshInstance3D
var _line_ms := 0.0
var _line_from := Vector3.ZERO
var _line_to := Vector3.ZERO
var _fill_material: StandardMaterial3D


func setup(map: SimMap) -> void:
	_map = map
	_cfg = RenderConfig.data()["nexus"]
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.28
	cylinder.bottom_radius = 0.34
	cylinder.height = 0.8
	var color := RenderConfig.color(RenderConfig.data()["grid"]["nexusColor"])
	_pillar = MeshUtil.instance(cylinder, MeshUtil.lit_material(color.lightened(0.15)), self)
	_pillar.position = Vector3(map.nexus.x, 0.4, map.nexus.y)
	_pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Barra de vida: dois quads de frente para a câmera (billboard).
	var bar: Dictionary = _cfg["healthBar"]
	var width: float = float(bar["width"]) * RenderConfig.PX_TO_UNIT
	var height: float = float(bar["height"]) * RenderConfig.PX_TO_UNIT
	_bar_pivot = Node3D.new()
	_bar_pivot.position = Vector3(map.nexus.x, 1.15, map.nexus.y)
	add_child(_bar_pivot)
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	var back_mat := MeshUtil.flat_material(RenderConfig.color(bar["backColor"]))
	back_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	back_mat.no_depth_test = true
	_bar_back = MeshUtil.instance(quad, back_mat, _bar_pivot)
	_fill_material = MeshUtil.flat_material(RenderConfig.color(bar["fillColor"]))
	_fill_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fill_material.no_depth_test = true
	var fill_quad := QuadMesh.new()
	fill_quad.size = quad.size
	_bar_fill = MeshUtil.instance(fill_quad, _fill_material, _bar_pivot)
	_bar_fill.sorting_offset = 0.01
	_line = MeshUtil.line_strip(self, MeshUtil.flat_material(RenderConfig.color(_cfg["attackLine"]["color"])))


## `frame_delta_ms` = 0 com o jogo pausado (a linha do ataque congela).
func draw(state: Object, frame_delta_ms: float) -> void:
	var frac := clampf(state.nexus.hp / float(state.nexus.max_hp), 0.0, 1.0)
	var width: float = float(_cfg["healthBar"]["width"]) * RenderConfig.PX_TO_UNIT
	# O quad de fundo mantém a largura; o da frente encolhe pelo lado direito (a malha é
	# recortada e deslocada, o que funciona com billboard).
	var fill := _bar_fill.mesh as QuadMesh
	var w := maxf(width * frac, 0.001)
	fill.size = Vector2(w, float(_cfg["healthBar"]["height"]) * RenderConfig.PX_TO_UNIT)
	fill.center_offset = Vector3(-(width - w) / 2.0, 0.0, 0.0)
	_bar_fill.visible = frac > 0.0
	_line_ms = maxf(0.0, _line_ms - frame_delta_ms)
	_line.visible = _line_ms > 0.0
	if _line.visible:
		_draw_line(_line_from, _line_to)


## Eventos do quadro: o ataque do núcleo desenha a linha até o alvo.
func handle_events(events: Array) -> void:
	for event: Dictionary in events:
		if event["type"] == "nexusFired":
			_line_from = Vector3(_map.nexus.x, 0.6, _map.nexus.y)
			_line_to = Vector3(event["x"], 0.3, event["y"])
			_line_ms = float(_cfg["attackLine"]["durationMs"])


func _draw_line(a: Vector3, b: Vector3) -> void:
	var im := _line.mesh as ImmediateMesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(a)
	im.surface_add_vertex(b)
	im.surface_end()
