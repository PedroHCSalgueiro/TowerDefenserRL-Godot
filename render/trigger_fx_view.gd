class_name TriggerFxView
extends Node3D
## Feedback visual dos gatilhos (T16), desenhado a partir dos eventos do quadro e dos modelos de
## `trigger_fx.gd` (porte de `TriggerFxView.ts`):
##
## - pulso (linha que some em `pulse.durationMs`) da torre que disparou até o destino, na cor da
##   classe principal dela; no máximo `pulse.maxActive`;
## - flash curto (a torre pisca) na torre que disparou um gatilho visível;
## - "Cadeia xN!" sobre a torre que começou a cadeia, com um anel enquanto a cadeia dura (e
##   `lingerMs` depois); a cadeia do núcleo mostra o rótulo sobre o núcleo, sem anel;
## - números de dano agregados por efeito (liga e desliga com N).
##
## Uma malha de faixas redesenhada por quadro e textos 3D reaproveitados (um pool do tamanho do
## limite), para o caos do empilhamento não derrubar o FPS. Os textos têm tamanho fixo na tela.

## Escala dos textos de tamanho fixo (ajustada visualmente).
const LABEL_PIXEL_SIZE := 0.0009

var _cfg: Dictionary
var _towers: TowerData
var _tower_view: TowerView
var _nexus_pos: Vector3
var _pulses: TriggerFx.PulseModel
var _numbers: TriggerFx.DamageNumberModel
var _chains: TriggerFx.ChainModel
var _pulse_mesh: MeshInstance3D
var _pulse_material: StandardMaterial3D
var _ring_pool: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _label_pool: Array[Label3D] = []
var _label_shown: Array[Dictionary] = []
var _number_pool: Array[Label3D] = []
var _number_owner: Array[int] = []
var _tower_info := {}  # id -> {"x","y","color"}
var _time_ms := 0.0
var _ring_cfg: Dictionary


func setup(map: SimMap, towers: TowerData, tower_view: TowerView) -> void:
	_cfg = RenderConfig.data()["triggerFx"]
	_towers = towers
	_tower_view = tower_view
	_nexus_pos = Vector3(map.nexus.x, 0.0, map.nexus.y)
	_pulses = TriggerFx.PulseModel.new(_cfg["pulse"])
	_numbers = TriggerFx.DamageNumberModel.new(_cfg["numbers"])
	_chains = TriggerFx.ChainModel.new(_cfg["chain"])
	_ring_cfg = _cfg["chain"]["ring"]
	_pulse_material = StandardMaterial3D.new()
	_pulse_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pulse_material.vertex_color_use_as_albedo = true
	_pulse_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pulse_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pulse_mesh = MeshInstance3D.new()
	_pulse_mesh.mesh = ImmediateMesh.new()
	_pulse_mesh.material_override = _pulse_material
	_pulse_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pulse_mesh)
	var chain: Dictionary = _cfg["chain"]
	for i in int(chain["maxLabels"]):
		_label_pool.append(_make_label(chain, 2))
		_label_shown.append({"chain_id": 0, "length": 0, "at_ms": 0.0})
		var mat := MeshUtil.flat_material(RenderConfig.color(_ring_cfg["color"], _ring_cfg["alpha"]))
		_ring_materials.append(mat)
		var ring := MeshUtil.instance(MeshUtil.ring_mesh(0.08), mat, self)
		ring.visible = false
		_ring_pool.append(ring)
	var numbers: Dictionary = _cfg["numbers"]
	for i in int(numbers["maxActive"]):
		_number_pool.append(_make_label(numbers, 1))
		_number_owner.append(0)


func _make_label(style: Dictionary, priority: int) -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = LABEL_PIXEL_SIZE
	label.no_depth_test = true
	label.render_priority = priority
	label.font_size = int(style["fontSize"]) * 3
	label.modulate = RenderConfig.color(style["color"])
	label.outline_modulate = RenderConfig.color(style["strokeColor"])
	label.outline_size = int(style["strokeWidth"]) * 3
	label.visible = false
	add_child(label)
	return label


## Liga ou desliga os números de dano (tecla N); devolve o estado novo.
func toggle_numbers() -> bool:
	return _numbers.toggle()


func _lookup(tower_id: int) -> Dictionary:
	return _tower_info.get(tower_id, {})


func handle_events(state: Object, events: Array) -> void:
	_sync_towers(state)
	if events.is_empty():
		return
	_pulses.add(events, _lookup)
	_numbers.add(events)
	_chains.add(events)
	for id in TriggerFx.flashed_towers(events):
		_tower_view.flash(id)


## Casa e cor de cada torre (para os pulsos; as torres podem ter se movido).
func _sync_towers(state: Object) -> void:
	_tower_info.clear()
	for tower: Tower in state.towers:
		_tower_info[tower.id] = {"x": float(tower.x), "y": float(tower.y), "color": RenderConfig.tower_color(_towers, tower.type)}


func draw(state: Object, frame_delta_ms: float) -> void:
	_time_ms += frame_delta_ms
	var live := {}
	for chain: TriggerState.ChainRecord in state.triggers.chains:
		live[chain.id] = true
	_chains.advance(frame_delta_ms, live)
	_draw_pulses()
	_draw_chains()
	_draw_numbers()
	_pulses.advance(frame_delta_ms)
	_numbers.advance(frame_delta_ms)


func _draw_pulses() -> void:
	var im := _pulse_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	if _pulses.pulses.is_empty():
		return
	var pulse_cfg: Dictionary = _cfg["pulse"]
	var width := float(pulse_cfg["lineWidth"]) * RenderConfig.PX_TO_UNIT * 1.6
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for pulse in _pulses.pulses:
		var a := Vector3(pulse.from.x, 0.55, pulse.from.y)
		var b := Vector3(pulse.to.x, 0.35, pulse.to.y)
		var dir := (b - a)
		if dir.length() < 0.001:
			continue
		var side := dir.cross(Vector3.UP).normalized() * width * 0.5
		var c := pulse.color
		c.a = float(pulse_cfg["alpha"]) * maxf(0.0, pulse.ms_left / float(pulse_cfg["durationMs"]))
		for v in [a - side, a + side, b + side, a - side, b + side, b - side]:
			im.surface_set_color(c)
			im.surface_add_vertex(v)
	im.surface_end()


func _draw_chains() -> void:
	var chain_cfg: Dictionary = _cfg["chain"]
	var labels := _chains.labels()
	for i in _label_pool.size():
		var label3d := _label_pool[i]
		var ring := _ring_pool[i]
		var label: TriggerFx.ChainLabel = labels[i] if i < labels.size() else null
		var tower_pos: Variant = null
		if label != null and label.origin_tower_id != null:
			tower_pos = _tower_view.tower_position(label.origin_tower_id)
		if label == null or (label.origin_tower_id != null and tower_pos == null):
			label3d.visible = false
			ring.visible = false
			continue
		var anchor: Vector3
		if tower_pos != null:
			anchor = tower_pos + Vector3(0, 1.25, 0)
			# Anel no pé da torre: pulsa enquanto a cadeia está viva.
			var pulse := 1.0
			if label.alive:
				pulse = 1.0 + float(_ring_cfg["pulseScale"]) * sin(_time_ms / float(_ring_cfg["pulseMs"]) * TAU)
			var r := float(_ring_cfg["radius"]) * pulse
			ring.position = tower_pos + Vector3(0, 0.03, 0)
			ring.scale = Vector3(r, 1.0, r)
			ring.visible = true
		else:
			anchor = _nexus_pos + Vector3(0, 1.6, 0)
			ring.visible = false
		var shown: Dictionary = _label_shown[i]
		if shown["chain_id"] != label.chain_id or (shown["length"] != label.length \
				and _time_ms - shown["at_ms"] >= float(chain_cfg["labelRefreshMs"])):
			shown["chain_id"] = label.chain_id
			shown["length"] = label.length
			shown["at_ms"] = _time_ms
			label3d.text = String(chain_cfg["text"]).replace("{n}", str(label.length))
		label3d.position = anchor
		label3d.modulate.a = 1.0 if label.alive else 0.6
		label3d.visible = true


## Cada número fica preso a um texto do pool enquanto vive: o texto é feito uma vez só.
func _draw_numbers() -> void:
	var cfg: Dictionary = _cfg["numbers"]
	var rise := float(cfg["risePx"]) * RenderConfig.PX_TO_UNIT * 1.5
	var alive := {}
	for n in _numbers.numbers:
		alive[n.id] = true
	for i in _number_owner.size():
		if _number_owner[i] != 0 and not alive.has(_number_owner[i]):
			_number_owner[i] = 0
			_number_pool[i].visible = false
	for n in _numbers.numbers:
		var slot := _number_owner.find(n.id)
		if slot < 0:
			slot = _number_owner.find(0)
			if slot < 0:
				continue
			_number_owner[slot] = n.id
			_number_pool[slot].text = str(roundi(n.value))
			_number_pool[slot].visible = true
		var life := maxf(0.0, n.ms_left / float(cfg["durationMs"]))
		_number_pool[slot].position = Vector3(n.at.x, 0.6 + rise * (1.0 - life), n.at.y)
		_number_pool[slot].modulate.a = life
