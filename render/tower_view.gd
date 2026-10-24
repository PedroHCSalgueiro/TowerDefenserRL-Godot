class_name TowerView
extends Node3D
## Desenha as torres (porte de `TowerView.ts`): um bloco na cor da classe principal com uma
## "tampa" na cor da segunda classe, as estrelas acima, o alcance da torre selecionada, o flash dos
## gatilhos, o brilho da fusão e o tremor de "travada". Um nó por torre, criado e removido conforme
## o estado.
##
## Papagaio (`towers.parrots`, o Capitão Pena): uma bolinha que pousa no ombro e voa até os alvos.
##
## Heróis com modelo 3D (`towers.models` em `render.json`, ex.: o Sir Aldric): o modelo troca o bloco
## colorido. Quando a torre atira, o modelo vira para o alvo e toca a animação de ataque; se o modelo
## emite `raio_disparado(ponta)`, um raio de luz sai da ponta até o alvo. Sem o arquivo do modelo (a
## exportação Web o deixa de fora por causa do tamanho), continua o bloco.

const BODY_SIZE := Vector3(0.42, 0.56, 0.42)
const FLASH_MS := 280.0
const BEAM_MS := 220.0

class TowerNode:
	extends Node3D
	var body: MeshInstance3D
	var cap: MeshInstance3D
	var stars: Node3D
	var star_count := 0
	var body_material: StandardMaterial3D
	## Brilho do gatilho (0..1) e pulso da fusão (0..1).
	var flash := 0.0
	var merge := 0.0
	## Tremor de "travada": tempo que falta, em ms.
	var shake_ms := 0.0
	var home := Vector3.ZERO
	## Modelo 3D (null = bloco colorido) e o que a animação de ataque precisa.
	var model: Node3D = null
	var star_height := BODY_SIZE.y + 0.5
	var attack_pending := false
	var attack_target_id := -1
	var beam_target := Vector3.ZERO
	var beam_color := Color.WHITE
	## Papagaio do Capitão Pena (null = sem papagaio): voa até o alvo do último tiro e pousa no ombro.
	var parrot: MeshInstance3D = null
	var parrot_target_id := -1
	var parrot_phase := 0.0
	var parrot_speed := 4.0

var _data: TowerData
var _nodes: Dictionary = {}  # id -> TowerNode
var _range_disc: MeshInstance3D
var _range_ring: MeshInstance3D
var _star_mesh: SphereMesh
var _star_material: StandardMaterial3D
var _cfg: Dictionary
## Raios de luz vivos: {"mesh": MeshInstance3D, "material": StandardMaterial3D, "left": ms}.
var _beams: Array = []


func setup(data: TowerData) -> void:
	_data = data
	_cfg = RenderConfig.data()["towers"]
	var range_cfg: Dictionary = _cfg["range"]
	_range_disc = MeshUtil.instance(MeshUtil.disc_mesh(), MeshUtil.flat_material(
			RenderConfig.color(range_cfg["fillColor"], range_cfg["fillAlpha"])), self)
	_range_ring = MeshUtil.instance(MeshUtil.ring_mesh(0.02), MeshUtil.flat_material(
			RenderConfig.color(range_cfg["lineColor"], range_cfg["lineAlpha"])), self)
	_range_disc.visible = false
	_range_ring.visible = false
	_star_mesh = SphereMesh.new()
	_star_mesh.radius = 0.07
	_star_mesh.height = 0.14
	_star_mesh.radial_segments = 8
	_star_mesh.rings = 4
	_star_material = MeshUtil.flat_material(RenderConfig.color(_cfg["stars"]["color"]))


## Sincroniza os nós com as torres do estado. `selected_cell`: Vector2i ou null.
func draw(state: Object, selected_cell: Variant, delta_ms: float) -> void:
	var seen := {}
	var selected: Tower = null
	for tower: Tower in state.towers:
		seen[tower.id] = true
		var node: TowerNode = _nodes.get(tower.id)
		if node == null:
			node = _create_node(tower)
			_nodes[tower.id] = node
		_update_node(node, tower, delta_ms)
		if node.attack_pending and node.model != null:
			_start_attack(node, tower, state)
		if node.parrot != null:
			_update_parrot(node, state, delta_ms)
		if selected_cell != null and tower.x == selected_cell.x and tower.y == selected_cell.y:
			selected = tower
	for id: int in _nodes.keys():
		if not seen.has(id):
			var gone: TowerNode = _nodes[id]
			if gone.parrot != null:
				gone.parrot.queue_free()
			gone.queue_free()
			_nodes.erase(id)
	show_range(selected)
	_update_beams(delta_ms)


## Mostra o alcance da torre (ou esconde com null).
func show_range(tower: Tower) -> void:
	var visible_range := tower != null
	_range_disc.visible = visible_range
	_range_ring.visible = visible_range
	if not visible_range:
		return
	var radius := _data.get_type(tower.type).range
	var pos := Vector3(tower.x, 0.02, tower.y)
	_range_disc.position = pos
	_range_ring.position = pos + Vector3(0, 0.005, 0)
	_range_disc.scale = Vector3(radius, 1.0, radius)
	_range_ring.scale = Vector3(radius, 1.0, radius)


func _create_node(tower: Tower) -> TowerNode:
	var node := TowerNode.new()
	var type := _data.get_type(tower.type)
	var main := RenderConfig.tower_color(_data, tower.type)
	var box := BoxMesh.new()
	box.size = BODY_SIZE
	node.body_material = MeshUtil.lit_material(main)
	node.body = MeshUtil.instance(box, node.body_material, node)
	node.body.position = Vector3(0, BODY_SIZE.y / 2.0, 0)
	node.body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if type.classes.size() > 1:
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.17
		cap_mesh.height = 0.34
		cap_mesh.radial_segments = 12
		cap_mesh.rings = 6
		# A tampa: cor de efeito do campeão (heróis sem modelo da Costa Rubra) ou a da segunda classe.
		var second := RenderConfig.color(_cfg["classColors"].get(type.classes[1], _cfg["fallbackColor"]))
		if _cfg.get("effectColors", {}).has(tower.type):
			second = RenderConfig.effect_color(_data, tower.type)
		node.cap = MeshUtil.instance(cap_mesh, MeshUtil.lit_material(second), node)
		node.cap.position = Vector3(0, BODY_SIZE.y + 0.1, 0)
	var model_cfg: Dictionary = _cfg.get("models", {}).get(tower.type, {})
	if not model_cfg.is_empty():
		_attach_model(node, model_cfg)
	var parrot_cfg: Dictionary = _cfg.get("parrots", {}).get(tower.type, {})
	if not parrot_cfg.is_empty():
		var parrot_mesh := SphereMesh.new()
		parrot_mesh.radius = 0.09
		parrot_mesh.height = 0.14
		parrot_mesh.radial_segments = 8
		parrot_mesh.rings = 4
		node.parrot = MeshUtil.instance(parrot_mesh, MeshUtil.lit_material(RenderConfig.color(parrot_cfg["color"])), self)
		node.parrot.position = Vector3(tower.x, 0.0, tower.y) + _shoulder()
		node.parrot_speed = float(parrot_cfg.get("speed", 4.0))
	node.stars = Node3D.new()
	node.stars.position = Vector3(0, node.star_height, 0)
	node.add_child(node.stars)
	node.position = Vector3(tower.x, 0.0, tower.y)
	node.home = node.position
	add_child(node)
	return node


## Troca o bloco pelo modelo 3D da torre, se o arquivo existir (senão fica o bloco).
func _attach_model(node: TowerNode, cfg: Dictionary) -> void:
	var path: String = cfg["scene"]
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	var model := scene.instantiate() as Node3D
	if model == null:
		return
	model.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	model.rotation.y = deg_to_rad(float(cfg.get("restYawDegrees", 0.0)))
	node.add_child(model)
	node.model = model
	node.star_height = float(cfg.get("starHeight", node.star_height))
	node.beam_color = RenderConfig.color(cfg.get("beamColor", "#ffe066"))
	node.body.visible = false
	if node.cap != null:
		node.cap.visible = false
	if model.has_signal("raio_disparado"):
		model.connect("raio_disparado", func(tip: Vector3) -> void: _spawn_beam(tip, node.beam_target, node.beam_color))


## O modelo vira para o alvo do tiro e toca o ataque (a duração acompanha o intervalo entre tiros).
func _start_attack(node: TowerNode, tower: Tower, state: Object) -> void:
	node.attack_pending = false
	var target: Enemy = null
	for enemy: Enemy in state.enemies.slots:
		if enemy.active and enemy.id == node.attack_target_id:
			target = enemy
			break
	if target == null:
		return
	var dx := target.x - float(tower.x)
	var dz := target.y - float(tower.y)
	if dx != 0.0 or dz != 0.0:
		node.model.rotation.y = atan2(dx, dz)
	node.beam_target = Vector3(target.x, 0.35, target.y)
	if node.model.has_method("atacar"):
		node.model.call("atacar", 1.0 / maxf(0.1, _data.get_type(tower.type).shots_per_second))


## Raio de luz da ponta (`from`) até o alvo; some em ~220 ms.
func _spawn_beam(from: Vector3, to: Vector3, color: Color) -> void:
	var delta := to - from
	if delta.length() < 0.01:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	mesh.height = delta.length()
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := MeshUtil.flat_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var beam := MeshUtil.instance(mesh, material, self)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = (from + to) / 2.0
	beam.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
	_beams.append({"mesh": beam, "material": material, "left": BEAM_MS, "color": color})


func _update_beams(delta_ms: float) -> void:
	for i in range(_beams.size() - 1, -1, -1):
		var beam: Dictionary = _beams[i]
		beam["left"] -= delta_ms
		if beam["left"] <= 0.0:
			(beam["mesh"] as MeshInstance3D).queue_free()
			_beams.remove_at(i)
		else:
			var color: Color = beam["color"]
			color.a = beam["left"] / BEAM_MS
			(beam["material"] as StandardMaterial3D).albedo_color = color


func _update_node(node: TowerNode, tower: Tower, delta_ms: float) -> void:
	node.home = Vector3(tower.x, 0.0, tower.y)
	var offset := Vector3.ZERO
	if node.shake_ms > 0.0:
		node.shake_ms = maxf(0.0, node.shake_ms - delta_ms)
		var cfg: Dictionary = _cfg["locked"]
		var phase := node.shake_ms / float(cfg["shakeMs"])
		offset.x = sin(phase * PI) * float(cfg["shakePx"]) * RenderConfig.PX_TO_UNIT
	node.position = node.home + offset
	if node.star_count != tower.star:
		node.star_count = tower.star
		for child in node.stars.get_children():
			child.queue_free()
		var right := Vector3(cos(GroundProjection.azimuth()), 0.0, -sin(GroundProjection.azimuth()))
		for i in tower.star:
			var s := MeshUtil.instance(_star_mesh, _star_material, node.stars)
			s.position = right * ((float(i) - float(tower.star - 1) / 2.0) * 0.17)
	# Flash do gatilho e brilho da fusão.
	node.flash = maxf(0.0, node.flash - delta_ms / FLASH_MS)
	node.merge = maxf(0.0, node.merge - delta_ms / FLASH_MS)
	var glow := maxf(node.flash, node.merge)
	node.body_material.emission_enabled = glow > 0.0
	node.body_material.emission = Color.WHITE
	node.body_material.emission_energy_multiplier = glow * 1.5
	var pulse := 1.0 + node.merge * (float(_cfg["fusion"]["flashScale"]) - 1.0)
	node.body.scale = Vector3.ONE * pulse
	node.body.position.y = BODY_SIZE.y / 2.0 * pulse


## Ombro do Capitão (onde o papagaio pousa), relativo à casa da torre.
static func _shoulder() -> Vector3:
	return Vector3(0.16, BODY_SIZE.y + 0.12, 0.0)


## Papagaio do Capitão Pena: pousado no ombro sem inimigos e sem onda em andamento; senão voa até o alvo
## do último tiro e, entre um alvo e outro (ou sem alvo), circula sobre a torre. Só visual.
func _update_parrot(node: TowerNode, state: Object, delta_ms: float) -> void:
	var speed := node.parrot_speed
	var flying: bool = state.enemies.active_count > 0 or not state.waves.active.is_empty()
	var goal: Vector3 = node.home + _shoulder()
	node.parrot_phase += delta_ms / 1000.0
	if flying:
		var target: Enemy = null
		if node.parrot_target_id >= 0:
			for enemy: Enemy in state.enemies.slots:
				if enemy.active and enemy.id == node.parrot_target_id:
					target = enemy
					break
		if target != null:
			goal = Vector3(target.x, 0.55, target.y)
		else:
			goal = node.home + Vector3(cos(node.parrot_phase * 2.0) * 0.45, 0.9, sin(node.parrot_phase * 2.0) * 0.45)
	var step := speed * delta_ms / 1000.0
	var delta := goal - node.parrot.position
	node.parrot.position = goal if delta.length() <= step else node.parrot.position + delta.normalized() * step


## A torre disparou um gatilho visível: pisca.
func flash(tower_id: int) -> void:
	var node: TowerNode = _nodes.get(tower_id)
	if node != null:
		node.flash = 1.0


## Eventos do quadro: fusão (brilho) e torres travadas.
func handle_events(events: Array) -> void:
	for event: Dictionary in events:
		if event["type"] == "towersMerged":
			var node: TowerNode = _nodes.get(event["towerId"])
			if node != null:
				node.merge = 1.0
		elif event["type"] == "towerFired" and event["shot"] == "normal":
			var shooter: TowerNode = _nodes.get(event["towerId"])
			if shooter != null and shooter.model != null:
				shooter.attack_pending = true
				shooter.attack_target_id = event["targetId"]
			if shooter != null and shooter.parrot != null:
				shooter.parrot_target_id = event["targetId"]


## Treme a torre (tentou mover com onda ativa).
func show_locked(tower_id: int) -> void:
	var node: TowerNode = _nodes.get(tower_id)
	if node != null:
		var cfg: Dictionary = _cfg["locked"]
		node.shake_ms = float(cfg["shakeMs"]) * float(cfg["shakeRepeats"]) * 2.0


## Posição de uma torre no mundo (para efeitos), ou null.
func tower_position(tower_id: int) -> Variant:
	var node: TowerNode = _nodes.get(tower_id)
	return node.home if node != null else null


## Id da torre atingida por um raio (a mais próxima da câmera), ou -1.
func tower_at_ray(origin: Vector3, direction: Vector3) -> int:
	var best := -1
	var best_dist := INF
	for id: int in _nodes:
		var node: TowerNode = _nodes[id]
		var box := AABB(node.home + Vector3(-BODY_SIZE.x / 2.0, 0.0, -BODY_SIZE.z / 2.0),
				Vector3(BODY_SIZE.x, BODY_SIZE.y + 0.45, BODY_SIZE.z))
		var hit: Variant = box.intersects_ray(origin, direction)
		if hit != null:
			var d := origin.distance_to(hit)
			if d < best_dist:
				best_dist = d
				best = id
	return best
