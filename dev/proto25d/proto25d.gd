extends Node3D
## Protótipo 2.5D: mundo 3D de verdade (chão, luz, sombras, câmera em perspectiva que gira) com
## personagens, torres e árvores como sprites 2D "billboard". Reaproveita a arte do protótipo 2D
## (dev/proto2d/art). Descartável: não toca na simulação; os números são de demonstração.
##   godot --path . res://dev/proto25d/proto25d.tscn [-- --shot=a.png --shot-at=6 --follow --yaw=45
##                                                      --pitch=48 --dist=20 --ortho]

const ART := "res://dev/proto2d/art/"
const MAP_FILE := "res://data/map.json"
## Tamanho de um pixel de sprite em unidades do mundo (uma casa = 1 unidade).
const PIXEL := 0.022
## Pixels de textura do chão por casa.
const GROUND_PX := 48
const TOWER_ANCHOR := Vector2(24, 80)
const TREE_ANCHOR := Vector2(22, 54)
const GOBLIN_ANCHOR := Vector2(12, 26)
const KNIGHT_ANCHOR := Vector2(28, 52)
const ENEMY_SPEED := 1.6
const SPAWN_EVERY := 0.9
const TOWER_RANGE := 4.0
const SHOT_EVERY := 0.9
const ENEMY_HITS := 4
const HERO_HOME := Vector2(6, 4)
const HERO_SPEED := 2.2
const HERO_SIGHT := 5.0
const HERO_REACH := 1.2
const HERO_COOLDOWN := 0.5
const HERO_HIT_FRAME := 2
const TOWERS := [[4, 3, 0], [8, 4, 1], [7, 7, 0], [5, 8, 1], [9, 9, 0], [1, 4, 1]]

var _w := 0
var _h := 0
var _cam: Camera3D
var _yaw := 45.0
var _pitch := 48.0
var _dist := 20.0
var _ortho := false
var _follow := false
var _panning := false
var _shot_path := ""
var _shot_at := 6.0
var _elapsed := 0.0
var _path: Array[Vector2i] = []
var _blocked := {}
var _path_set := {}
var _enemies: Array[Dictionary] = []
var _towers: Array[Dictionary] = []
var _hero := {}
var _goblin_frames: SpriteFrames
var _spawn_cd := 0.0
var _label: Label


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--shot-at="):
			_shot_at = float(arg.substr(10))
		elif arg.begins_with("--yaw="):
			_yaw = float(arg.substr(6))
		elif arg.begins_with("--pitch="):
			_pitch = float(arg.substr(8))
		elif arg.begins_with("--dist="):
			_dist = float(arg.substr(7))
		elif arg == "--follow":
			_follow = true
		elif arg == "--ortho":
			_ortho = true
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	_w = int(map["width"])
	_h = int(map["height"])
	_build_path(map["path"])
	_build_environment()
	_build_ground()
	_build_goblin_frames()
	for t: Array in TOWERS:
		_blocked[Vector2i(t[0], t[1])] = true
	for t: Array in TOWERS:
		_add_tower(Vector2i(t[0], t[1]), t[2])
	_add_trees()
	_add_boulders()
	_add_hero()
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.5
	_cam.far = 200.0
	add_child(_cam)
	_update_camera()
	var hud := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12, 8)
	hud.add_child(_label)
	add_child(hud)
	_update_label()


# ---------------------------------------------------------------- montagem

func _build_path(points: Array) -> void:
	var prev := Vector2i(int(points[0]["x"]), int(points[0]["y"]))
	_path.append(prev)
	for i in range(1, points.size()):
		var next := Vector2i(int(points[i]["x"]), int(points[i]["y"]))
		var step := Vector2i(signi(next.x - prev.x), signi(next.y - prev.y))
		while prev != next:
			prev += step
			_path.append(prev)
	for c in _path:
		_blocked[c] = true
		_path_set[c] = true


## Casa (fracionária) da grade → ponto do chão no mundo 3D (mapa centrado na origem).
func _world(cell: Vector2) -> Vector3:
	return Vector3(cell.x - (_w - 1) * 0.5, 0.0, cell.y - (_h - 1) * 0.5)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("16231a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b8c8d8")
	env.ambient_light_energy = 0.45
	env.fog_enabled = true
	env.fog_light_color = Color("16231a")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -40, 0)
	sun.light_color = Color("fff0d0")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _ground_texture()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	var top := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(_w, _h)
	top.mesh = plane
	top.material_override = mat
	add_child(top)
	# bloco de terra sob o mapa: dá espessura ao tabuleiro quando a câmera gira/inclina
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(_w, 0.8, _h)
	base.mesh = box
	base.position = Vector3(0, -0.402, 0)
	var dirt := StandardMaterial3D.new()
	dirt.albedo_color = Color("4a3a28")
	dirt.roughness = 1.0
	base.material_override = dirt
	add_child(base)


## Textura do chão inteiro (grama, terra do caminho, bordas irregulares), 1 casa = GROUND_PX pixels.
func _ground_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var size := Vector2i(_w * GROUND_PX, _h * GROUND_PX)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var grass: Array[Color] = [Color("3f6b35"), Color("477a3a"), Color("39602f")]
	var dirt: Array[Color] = [Color("a58b5c"), Color("b29a69"), Color("957c50")]
	var block := 2
	var noise := PackedInt32Array()
	noise.resize((size.x / block + 1) * (size.y / block + 1))
	for i in noise.size():
		noise[i] = rng.randi() % 3
	var nw := size.x / block + 1
	for y in size.y:
		for x in size.x:
			var cx := x / GROUND_PX
			var cy := y / GROUND_PX
			var lx := x % GROUND_PX
			var ly := y % GROUND_PX
			var is_path := _blocked_path(Vector2i(cx, cy))
			# borda irregular: perto da divisa com o tipo vizinho, às vezes pega o tipo dele
			var edge := 3
			var other := is_path
			if lx < edge and _blocked_path(Vector2i(cx - 1, cy)) != is_path and rng.randf() < 0.45:
				other = not is_path
			elif lx >= GROUND_PX - edge and _blocked_path(Vector2i(cx + 1, cy)) != is_path and rng.randf() < 0.45:
				other = not is_path
			elif ly < edge and _blocked_path(Vector2i(cx, cy - 1)) != is_path and rng.randf() < 0.45:
				other = not is_path
			elif ly >= GROUND_PX - edge and _blocked_path(Vector2i(cx, cy + 1)) != is_path and rng.randf() < 0.45:
				other = not is_path
			var shades := dirt if other else grass
			img.set_pixel(x, y, shades[noise[(y / block) * nw + x / block]])
	for i in _w * _h * 14:
		var p := Vector2i(rng.randi_range(0, size.x - 3), rng.randi_range(0, size.y - 3))
		var c := _blocked_path(Vector2i(p.x / GROUND_PX, p.y / GROUND_PX))
		var speck := Color("d2bc88") if c else Color("62a04b")
		img.set_pixel(p.x, p.y, speck)
		img.set_pixel(p.x + 1, p.y, speck)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _blocked_path(cell: Vector2i) -> bool:
	return _path_set.has(cell)


func _setup_sprite(s: SpriteBase3D, size: Vector2, anchor: Vector2) -> void:
	s.pixel_size = PIXEL
	# o sprite acompanha a inclinação da câmera (sem isso a arte fica achatada vista de cima)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.shaded = false
	s.double_sided = true
	s.centered = true
	s.offset = Vector2(size.x * 0.5 - anchor.x, anchor.y - size.y * 0.5)


func _sprite(file: String, anchor: Vector2) -> Sprite3D:
	var s := Sprite3D.new()
	var tex: Texture2D = load(ART + file)
	s.texture = tex
	_setup_sprite(s, tex.get_size(), anchor)
	return s


## Sombra redonda no chão (a sombra de verdade só existe para os objetos 3D reais).
func _blob(scale_xz: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(ART + "shadow.png")
	s.pixel_size = PIXEL * scale_xz
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.shaded = false
	s.rotation_degrees = Vector3(-90, 0, 0)
	s.position = Vector3(0, 0.02, 0)
	return s


func _add_tower(cell: Vector2i, kind: int) -> void:
	var node := Node3D.new()
	node.position = _world(Vector2(cell))
	node.add_child(_blob(1.9))
	node.add_child(_sprite("tower_arcane.png" if kind == 1 else "tower_archer.png", TOWER_ANCHOR))
	add_child(node)
	_towers.append({"node": node, "cell": cell, "kind": kind, "cd": randf() * SHOT_EVERY})


func _add_trees() -> void:
	for y in _h:
		for x in _w:
			var cell := Vector2i(x, y)
			if _blocked.has(cell):
				continue
			var border := x == 0 or y == 0 or x == _w - 1 or y == _h - 1
			if (x * 5 + y * 11) % 6 == 0 or (border and (x + y) % 2 == 0):
				var node := Node3D.new()
				node.position = _world(Vector2(cell)) + Vector3(((x * 3 + y) % 5 - 2) * 0.1, 0, 0)
				node.add_child(_blob(1.5))
				node.add_child(_sprite("tree.png", TREE_ANCHOR))
				add_child(node)


## Pedras em 3D de verdade: recebem luz e projetam sombra no chão (mostra o que o 2.5D ganha).
func _add_boulders() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("7b8087")
	mat.roughness = 0.9
	for cell in [Vector2i(2, 12), Vector2i(11, 3), Vector2i(6, 12), Vector2i(12, 7), Vector2i(1, 9), Vector2i(8, 1), Vector2i(5, 3)]:
		if _blocked.has(cell):
			continue
		var m := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.42
		sphere.height = 0.7
		sphere.radial_segments = 7
		sphere.rings = 4
		m.mesh = sphere
		m.material_override = mat
		m.position = _world(Vector2(cell)) + Vector3(0, 0.22, 0)
		m.rotation_degrees = Vector3(0, (cell.x * 37 + cell.y * 17) % 180, 0)
		m.scale = Vector3(1.0 + (cell.x % 3) * 0.15, 0.8, 1.0)
		add_child(m)


func _build_goblin_frames() -> void:
	_goblin_frames = SpriteFrames.new()
	_goblin_frames.set_animation_speed("default", 8.0)
	for f in 4:
		_goblin_frames.add_frame("default", load(ART + "goblin_%d.png" % f))


# ---------------------------------------------------------------- herói

func _add_hero() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: Array in [["idle", 2, 2.5, true], ["walk", 6, 10.0, true], ["attack", 5, 10.0, false]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[2])
		frames.set_animation_loop(anim[0], anim[3])
		for f in int(anim[1]):
			frames.add_frame(anim[0], load(ART + "knight_%s_%d.png" % [anim[0], f]))
	var node := Node3D.new()
	node.position = _world(HERO_HOME)
	node.add_child(_blob(1.3))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	_setup_sprite(sprite, Vector2(64, 56), KNIGHT_ANCHOR)
	sprite.play("idle")
	sprite.frame_changed.connect(_on_hero_frame)
	sprite.animation_finished.connect(_on_hero_attack_done)
	node.add_child(sprite)
	add_child(node)
	_hero = {"node": node, "sprite": sprite, "cell": HERO_HOME, "state": "idle", "cd": 0.0, "target": {}}


## Vira o sprite conforme o lado da TELA para onde ele anda (depende de onde a câmera está).
func _face(sprite: SpriteBase3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	if d.length() > 0.001:
		(sprite as AnimatedSprite3D).flip_h = d.dot(_cam.global_transform.basis.x) < 0.0


func _update_hero(delta: float) -> void:
	_hero["cd"] = maxf(0.0, _hero["cd"] - delta)
	if _hero["state"] == "attack":
		return
	var cell: Vector2 = _hero["cell"]
	var target: Dictionary = {}
	var best := HERO_SIGHT
	for e in _enemies:
		var dist := (_cell_at(e["d"]) - cell).length()
		if dist <= best:
			best = dist
			target = e
	var goal := HERO_HOME
	var in_reach := false
	if not target.is_empty():
		goal = _cell_at(target["d"])
		in_reach = best <= HERO_REACH
		if in_reach and _hero["cd"] <= 0.0:
			_start_hero_attack(target)
			return
	var sprite: AnimatedSprite3D = _hero["sprite"]
	var to := goal - cell
	if in_reach or to.length() < 0.08:
		_play_hero(sprite, "idle")
		return
	var node: Node3D = _hero["node"]
	var old := node.position
	cell += to.normalized() * minf(HERO_SPEED * delta, to.length())
	_hero["cell"] = cell
	node.position = _world(cell)
	_face(sprite, old, node.position)
	_play_hero(sprite, "walk")


func _play_hero(sprite: AnimatedSprite3D, anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func _start_hero_attack(target: Dictionary) -> void:
	_hero["state"] = "attack"
	_hero["target"] = target
	var sprite: AnimatedSprite3D = _hero["sprite"]
	_face(sprite, (_hero["node"] as Node3D).position, (target["node"] as Node3D).position)
	sprite.play("attack")


func _on_hero_frame() -> void:
	var sprite: AnimatedSprite3D = _hero["sprite"]
	if sprite.animation != "attack" or sprite.frame != HERO_HIT_FRAME:
		return
	var target: Dictionary = _hero["target"]
	if _enemies.has(target):
		target["hits"] = ENEMY_HITS - 1
		_hit(target)


func _on_hero_attack_done() -> void:
	var sprite: AnimatedSprite3D = _hero["sprite"]
	if sprite.animation != "attack":
		return
	_hero["state"] = "idle"
	_hero["cd"] = HERO_COOLDOWN
	sprite.play("idle")


# ---------------------------------------------------------------- jogo de mentira

func _process(delta: float) -> void:
	_elapsed += delta
	_spawn_cd -= delta
	if _spawn_cd <= 0.0:
		_spawn_cd = SPAWN_EVERY
		_spawn_enemy()
	_move_enemies(delta)
	_fire_towers(delta)
	_update_hero(delta)
	_update_camera()
	if _shot_path != "" and _elapsed > _shot_at:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _spawn_enemy() -> void:
	var node := Node3D.new()
	node.add_child(_blob(0.9))
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = _goblin_frames
	_setup_sprite(sprite, Vector2(24, 28), GOBLIN_ANCHOR)
	sprite.speed_scale = randf_range(0.9, 1.15)
	sprite.play("default")
	sprite.frame = randi() % 4
	node.add_child(sprite)
	node.position = _world(Vector2(_path[0]))
	add_child(node)
	_enemies.append({"node": node, "sprite": sprite, "d": 0.0, "hits": 0})


func _cell_at(d: float) -> Vector2:
	var i := mini(floori(d), _path.size() - 2)
	return Vector2(_path[i]).lerp(Vector2(_path[i + 1]), d - i)


func _move_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		e["d"] += ENEMY_SPEED * delta
		var node: Node3D = e["node"]
		if e["d"] >= _path.size() - 1:
			_enemies.erase(e)
			node.queue_free()
			continue
		var old := node.position
		node.position = _world(_cell_at(e["d"]))
		_face(e["sprite"], old, node.position)


func _fire_towers(delta: float) -> void:
	for t in _towers:
		t["cd"] -= delta
		if t["cd"] > 0.0:
			continue
		var target: Dictionary = {}
		var best := TOWER_RANGE
		for e in _enemies:
			var dist := (_cell_at(e["d"]) - Vector2(t["cell"])).length()
			if dist <= best:
				best = dist
				target = e
		if target.is_empty():
			continue
		t["cd"] = SHOT_EVERY
		_shoot(t, target)


func _shoot(tower: Dictionary, enemy: Dictionary) -> void:
	var spark := Sprite3D.new()
	spark.texture = load(ART + "spark.png")
	spark.pixel_size = PIXEL * 1.4
	spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spark.shaded = false
	spark.modulate = Color("7fe3ff") if tower["kind"] == 1 else Color("ffd870")
	add_child(spark)
	var from: Vector3 = (tower["node"] as Node3D).position + Vector3(0, 1.45, 0)
	var target_node: Node3D = enemy["node"]
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(target_node):
			var to := target_node.position + Vector3(0, 0.35, 0)
			spark.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * 0.5, 0)
	, 0.0, 1.0, 0.25)
	tween.tween_callback(func() -> void:
		spark.queue_free()
		_hit(enemy))


func _hit(enemy: Dictionary) -> void:
	if not _enemies.has(enemy):
		return
	enemy["hits"] += 1
	var sprite: AnimatedSprite3D = enemy["sprite"]
	sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if enemy["hits"] >= ENEMY_HITS:
		_enemies.erase(enemy)
		var node: Node3D = enemy["node"]
		var fade := create_tween().set_parallel()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.3)
		fade.tween_property(node, "scale", Vector3(1.2, 0.2, 1.2), 0.3)
		fade.chain().tween_callback(node.queue_free)


# ---------------------------------------------------------------- câmera

func _update_camera() -> void:
	var target := Vector3(0, 0.6, 0)
	if _follow:
		target = (_hero["node"] as Node3D).position + Vector3(0, 0.8, 0)
	var yaw := deg_to_rad(_yaw)
	var pitch := deg_to_rad(_pitch)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * _dist
	_cam.position = target + offset
	_cam.look_at(target, Vector3.UP)
	if _ortho:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.size = _dist * 0.55
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE


func _update_label() -> void:
	_label.text = "Protótipo 2.5D — botão direito: girar/inclinar · roda: zoom · espaço: %s" % ("perspectiva" if _ortho else "ortográfica")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = clampf(_dist / 1.1, 6.0, 40.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = clampf(_dist * 1.1, 6.0, 40.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
	elif event is InputEventMouseMotion and _panning:
		var rel := (event as InputEventMouseMotion).relative
		_yaw -= rel.x * 0.3
		_pitch = clampf(_pitch + rel.y * 0.2, 15.0, 85.0)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		_ortho = not _ortho
		_update_label()
