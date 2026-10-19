class_name EnemyView
extends Node3D
## Desenha os inimigos (porte de `EnemyView.ts`): uma esfera por inimigo ativo, numa única
## MultiMesh (centenas de inimigos), interpolada entre o tick anterior e o atual; cor por tipo;
## chefões e elites maiores; voadores no ar; barra de vida (billboard) só de quem tem dano; aura
## roxa nos elites.

const FLOATS := 16  # 12 da transformação 3D + 4 (cor ou dado custom)
const STUN_TINT := Color("#ffe066")
const SLOW_TINT := Color("#8fd3ff")
const BLEED_TINT := Color("#ff2d2d")

const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
varying float frac;
void vertex() {
	frac = INSTANCE_CUSTOM.x;
	mat4 mv = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	mv = mv * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = mv;
}
void fragment() {
	ALBEDO = UV.x < frac ? vec3(0.35, 0.82, 0.35) : vec3(0.23, 0.05, 0.05);
}
"""

var _data: EnemyData
var _cfg: Dictionary
var _body: MultiMeshInstance3D
var _bars: MultiMeshInstance3D
var _auras: MultiMeshInstance3D
var _capacity := 0
var _body_buf := PackedFloat32Array()
var _bar_buf := PackedFloat32Array()
var _aura_buf := PackedFloat32Array()
var _colors: Dictionary = {}  # tipo -> Color
var _scales: Dictionary = {}  # tipo -> escala


func setup(data: EnemyData) -> void:
	_data = data
	_cfg = RenderConfig.data()["enemies"]
	for id: String in data.types:
		_colors[id] = RenderConfig.enemy_color(id)
		_scales[id] = float(_cfg["scales"].get(id, 1.0))
	var radius: float = float(_cfg["radius"]) * RenderConfig.PX_TO_UNIT
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var body_mat := MeshUtil.lit_material(Color.WHITE)
	body_mat.vertex_color_use_as_albedo = true
	_body = _new_multimesh(sphere, body_mat, true, false)
	var bar_quad := QuadMesh.new()
	bar_quad.size = Vector2(float(_cfg["healthBar"]["width"]) * RenderConfig.PX_TO_UNIT * 1.4,
			float(_cfg["healthBar"]["height"]) * RenderConfig.PX_TO_UNIT * 1.4)
	var bar_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = BAR_SHADER
	bar_mat.shader = shader
	_bars = _new_multimesh(bar_quad, bar_mat, false, true)
	var aura_mat := MeshUtil.flat_material(Color.WHITE)
	aura_mat.vertex_color_use_as_albedo = true
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_auras = _new_multimesh(MeshUtil.ring_mesh(0.25), aura_mat, true, false)


func _new_multimesh(mesh: Mesh, material: Material, colors: bool, custom: bool) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = 0
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _grow(needed: int) -> void:
	if needed <= _capacity:
		return
	_capacity = maxi(needed, maxi(256, _capacity * 2))
	for mmi in [_body, _bars, _auras]:
		mmi.multimesh.instance_count = _capacity
		mmi.multimesh.visible_instance_count = 0
	_body_buf.resize(_capacity * FLOATS)
	_bar_buf.resize(_capacity * FLOATS)
	_aura_buf.resize(_capacity * FLOATS)


## Desenha o estado. `alpha` = fração do próximo tick já decorrida (interpolação).
func draw(state: Object, alpha: float) -> void:
	var slots: Array[Enemy] = state.enemies.slots
	_grow(slots.size())
	var radius: float = float(_cfg["radius"]) * RenderConfig.PX_TO_UNIT
	var flying: float = float(_cfg["flyingHeight"]) * RenderConfig.PX_TO_UNIT
	var elite_scale: float = _cfg["eliteScale"]
	var bar_offset: float = float(_cfg["healthBar"]["offsetY"]) * RenderConfig.PX_TO_UNIT + 0.1
	var aura_size: float = float(_cfg["eliteAura"]["radius"]) * RenderConfig.PX_TO_UNIT * 1.2
	var aura_color: Color = RenderConfig.color(_cfg["eliteAura"]["color"], _cfg["eliteAura"]["alpha"])
	var body := _body_buf
	var bars := _bar_buf
	var auras := _aura_buf
	var n := 0
	var nb := 0
	var na := 0
	for enemy in slots:
		if not enemy.active:
			continue
		var scale: float = _scales.get(enemy.type, 1.0)
		if enemy.elite:
			scale *= elite_scale
		var x := lerpf(enemy.prev_x, enemy.x, alpha)
		var z := lerpf(enemy.prev_y, enemy.y, alpha)
		var y := radius * scale
		if _data.types[enemy.type].movement == "air":
			y += flying
		var c: Color = _colors.get(enemy.type, Color.MAGENTA)
		# Efeitos de estado tingem o inimigo: atordoado amarelo, lento azul-gelo, sangrando vermelho.
		if enemy.stun_ticks > 0:
			c = c.lerp(STUN_TINT, 0.65)
		elif enemy.slow_ticks > 0:
			c = c.lerp(SLOW_TINT, 0.6)
		if enemy.bleed_ticks > 0:
			c = c.lerp(BLEED_TINT, 0.45)
		var o := n * FLOATS
		body[o] = scale
		body[o + 1] = 0.0
		body[o + 2] = 0.0
		body[o + 3] = x
		body[o + 4] = 0.0
		body[o + 5] = scale
		body[o + 6] = 0.0
		body[o + 7] = y
		body[o + 8] = 0.0
		body[o + 9] = 0.0
		body[o + 10] = scale
		body[o + 11] = z
		body[o + 12] = c.r
		body[o + 13] = c.g
		body[o + 14] = c.b
		body[o + 15] = 1.0
		n += 1
		if enemy.hp < enemy.max_hp:
			var ob := nb * FLOATS
			bars[ob] = 1.0
			bars[ob + 1] = 0.0
			bars[ob + 2] = 0.0
			bars[ob + 3] = x
			bars[ob + 4] = 0.0
			bars[ob + 5] = 1.0
			bars[ob + 6] = 0.0
			bars[ob + 7] = y + bar_offset * maxf(1.0, scale * 0.8)
			bars[ob + 8] = 0.0
			bars[ob + 9] = 0.0
			bars[ob + 10] = 1.0
			bars[ob + 11] = z
			bars[ob + 12] = clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
			bars[ob + 13] = 0.0
			bars[ob + 14] = 0.0
			bars[ob + 15] = 0.0
			nb += 1
		if enemy.elite:
			var oa := na * FLOATS
			auras[oa] = aura_size
			auras[oa + 1] = 0.0
			auras[oa + 2] = 0.0
			auras[oa + 3] = x
			auras[oa + 4] = 0.0
			auras[oa + 5] = aura_size
			auras[oa + 6] = 0.0
			auras[oa + 7] = 0.03
			auras[oa + 8] = 0.0
			auras[oa + 9] = 0.0
			auras[oa + 10] = aura_size
			auras[oa + 11] = z
			auras[oa + 12] = aura_color.r
			auras[oa + 13] = aura_color.g
			auras[oa + 14] = aura_color.b
			auras[oa + 15] = aura_color.a
			na += 1
	_publish(_body.multimesh, body, n)
	_publish(_bars.multimesh, bars, nb)
	_publish(_auras.multimesh, auras, na)


static func _publish(mm: MultiMesh, buffer: PackedFloat32Array, count: int) -> void:
	mm.visible_instance_count = count
	if count > 0:
		mm.buffer = buffer
