extends Node2D
## Protótipo do visual 2D isométrico: TileMapLayer 2:1 + sprites com ordenação por Y.
## Descartável: usa só o traçado de data/map.json e NÃO toca na simulação (os números abaixo são
## de demonstração, não regras do jogo). Rodar:
##   godot --path . res://dev/proto2d/proto2d.tscn [-- --shot=arquivo.png]

const ART := "res://dev/proto2d/art/"
const MAP_FILE := "res://data/map.json"
const TILE := Vector2i(64, 32)
const TOWER_ANCHOR := Vector2(56, 164)
const TREE_ANCHOR := Vector2(22, 54)
const GOBLIN_ANCHOR := Vector2(12, 26)
const KNIGHT_ANCHOR := Vector2(28, 52)
const HERO_HOME := Vector2(6, 4)
const HERO_SPEED := 2.2
const HERO_SIGHT := 5.0
const HERO_REACH := 1.2
const HERO_COOLDOWN := 0.5
const HERO_HIT_FRAME := 2
const ENEMY_SPEED := 1.6
const SPAWN_EVERY := 0.9
const TOWER_RANGE := 4.0
const SHOT_EVERY := 0.9
const ENEMY_HITS := 4
## [coluna, linha, tipo (0 arqueira, 1 arcana)]
const TOWERS := [[4, 3, 0], [8, 4, 1], [7, 7, 0], [5, 8, 1], [11, 8, 0], [1, 5, 1]]

var _ground: TileMapLayer
var _world: Node2D
var _fx: Node2D
var _camera: Camera2D
var _origin := Vector2.ZERO
var _path: Array[Vector2i] = []
var _blocked := {}
var _enemies: Array[Dictionary] = []
var _towers: Array[Dictionary] = []
var _goblin_frames: SpriteFrames
var _glow_tex: GradientTexture2D
var _hero := {}
var _spawn_cd := 0.0
var _elapsed := 0.0
var _shot_path := ""
var _shot_at := 6.0
var _follow := false
var _zoom_arg := 0.0
var _panning := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("16231a"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg == "--follow":
			_follow = true
		elif arg.begins_with("--zoom="):
			_zoom_arg = float(arg.substr(7))
		elif arg.begins_with("--shot-at="):
			_shot_at = float(arg.substr(10))
	var map: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	var w := int(map["width"])
	var h := int(map["height"])
	_build_path(map["path"])
	_build_ground(w, h)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_fx = Node2D.new()
	add_child(_fx)
	_build_goblin_frames()
	for t: Array in TOWERS:
		_add_tower(Vector2i(t[0], t[1]), t[2])
		_blocked[Vector2i(t[0], t[1])] = true
	_add_trees(w, h)
	_add_hero()
	_camera = Camera2D.new()
	_camera.position = _local(Vector2((w - 1) * 0.5, (h - 1) * 0.5))
	_camera.zoom = Vector2(1.25, 1.25) if _zoom_arg <= 0.0 else Vector2(_zoom_arg, _zoom_arg)
	add_child(_camera)
	var hud := CanvasLayer.new()
	var label := Label.new()
	label.text = "Protótipo 2D isométrico — roda: zoom · botão direito: arrastar"
	label.position = Vector2(12, 8)
	hud.add_child(label)
	add_child(hud)


# ---------------------------------------------------------------- montagem

## Casas do traçado, uma a uma (os pontos do JSON são cantos de segmentos retos).
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


func _build_ground(w: int, h: int) -> void:
	var src := TileSetAtlasSource.new()
	src.texture = load(ART + "tiles.png")
	src.texture_region_size = TILE
	for i in 4:
		src.create_tile(Vector2i(i, 0))
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = TILE
	ts.add_source(src, 0)
	_ground = TileMapLayer.new()
	_ground.tile_set = ts
	add_child(_ground)
	_origin = _ground.map_to_local(Vector2i.ZERO)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var kind := 3 if _blocked.has(cell) else (x * 7 + y * 13) % 3
			_ground.set_cell(cell, 0, Vector2i(kind, 0))


## Casa (fracionária) → posição na tela do mundo; é a mesma conta do tile isométrico 2:1.
func _local(cell: Vector2) -> Vector2:
	return _origin + Vector2((cell.x - cell.y) * TILE.x * 0.5, (cell.x + cell.y) * TILE.y * 0.5)


func _sprite(file: String, anchor: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + file)
	s.centered = false
	s.offset = -anchor
	return s


func _shadow(width_scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(ART + "shadow.png")
	s.scale = Vector2(width_scale, width_scale)
	return s


func _add_tower(cell: Vector2i, kind: int) -> void:
	var node := Node2D.new()
	node.position = _local(Vector2(cell))
	node.add_child(_shadow(3.2))
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 7.0)
	for f in 4:
		frames.add_frame("default", load(ART + "tower_%s_%d.png" % ["arcane" if kind == 1 else "fine", f]))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -TOWER_ANCHOR
	sprite.play("default")
	sprite.frame = randi() % 4
	node.add_child(sprite)
	var tint := Color("7fe3ff") if kind == 1 else Color("ffb65c")
	var glows: Array[Sprite2D] = [_glow(Vector2(0, -136), 0.8, tint), _glow(Vector2(0, -78), 1.6, tint)]
	for g in glows:
		node.add_child(g)
	_world.add_child(node)
	_towers.append({"node": node, "cell": cell, "kind": kind, "cd": randf() * SHOT_EVERY, "glows": glows, "phase": randf() * TAU})


## Halo de luz somado à cena (chama e janelas).
func _glow(at: Vector2, size: float, tint: Color) -> Sprite2D:
	if _glow_tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = grad
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 64
		_glow_tex.height = 64
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var s := Sprite2D.new()
	s.texture = _glow_tex
	s.material = mat
	s.position = at
	s.scale = Vector2(size, size)
	s.modulate = tint
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s


func _add_trees(w: int, h: int) -> void:
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			if _blocked.has(cell):
				continue
			var border := x == 0 or y == 0 or x == w - 1 or y == h - 1
			if (x * 5 + y * 11) % 6 == 0 or (border and (x + y) % 2 == 0):
				var node := Node2D.new()
				node.position = _local(Vector2(cell)) + Vector2(((x * 3 + y) % 5 - 2) * 3.0, 0)
				node.add_child(_shadow(1.5))
				node.add_child(_sprite("tree.png", TREE_ANCHOR))
				_world.add_child(node)


func _build_goblin_frames() -> void:
	_goblin_frames = SpriteFrames.new()
	_goblin_frames.set_animation_speed("default", 8.0)
	for f in 4:
		_goblin_frames.add_frame("default", load(ART + "goblin_%d.png" % f))


# ---------------------------------------------------------------- herói (cavaleiro)

func _add_hero() -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim: Array in [["idle", 2, 2.5, true], ["walk", 6, 10.0, true], ["attack", 5, 10.0, false]]:
		frames.add_animation(anim[0])
		frames.set_animation_speed(anim[0], anim[2])
		frames.set_animation_loop(anim[0], anim[3])
		for f in int(anim[1]):
			frames.add_frame(anim[0], load(ART + "knight_%s_%d.png" % [anim[0], f]))
	var node := Node2D.new()
	node.position = _local(HERO_HOME)
	node.add_child(_shadow(1.3))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = -KNIGHT_ANCHOR
	sprite.play("idle")
	sprite.frame_changed.connect(_on_hero_frame)
	sprite.animation_finished.connect(_on_hero_attack_done)
	node.add_child(sprite)
	_world.add_child(node)
	_hero = {"node": node, "sprite": sprite, "cell": HERO_HOME, "state": "idle", "cd": 0.0, "target": {}}


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
	var sprite: AnimatedSprite2D = _hero["sprite"]
	var to := goal - cell
	if in_reach or to.length() < 0.08:
		_play_hero(sprite, "idle")
		return
	var node: Node2D = _hero["node"]
	var old_x := node.position.x
	cell += to.normalized() * minf(HERO_SPEED * delta, to.length())
	_hero["cell"] = cell
	node.position = _local(cell)
	if absf(node.position.x - old_x) > 0.01:
		sprite.flip_h = node.position.x < old_x
	_play_hero(sprite, "walk")


func _play_hero(sprite: AnimatedSprite2D, anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func _start_hero_attack(target: Dictionary) -> void:
	_hero["state"] = "attack"
	_hero["target"] = target
	var sprite: AnimatedSprite2D = _hero["sprite"]
	var hero_x := (_hero["node"] as Node2D).position.x
	var target_x := (target["node"] as Node2D).position.x
	if absf(target_x - hero_x) > 1.0:
		sprite.flip_h = target_x < hero_x
	sprite.play("attack")


## No quadro do golpe a espada acerta: o goblin morre de uma vez.
func _on_hero_frame() -> void:
	var sprite: AnimatedSprite2D = _hero["sprite"]
	if sprite.animation != "attack" or sprite.frame != HERO_HIT_FRAME:
		return
	var target: Dictionary = _hero["target"]
	if _enemies.has(target):
		target["hits"] = ENEMY_HITS - 1
		_hit(target)


func _on_hero_attack_done() -> void:
	var sprite: AnimatedSprite2D = _hero["sprite"]
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
	if _follow:
		_camera.position = (_hero["node"] as Node2D).position + Vector2(0, -20)
	if _shot_path != "" and _elapsed > _shot_at:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


func _spawn_enemy() -> void:
	var node := Node2D.new()
	node.add_child(_shadow(0.9))
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = _goblin_frames
	sprite.centered = false
	sprite.offset = -GOBLIN_ANCHOR
	sprite.speed_scale = randf_range(0.9, 1.15)
	sprite.play("default")
	sprite.frame = randi() % 4
	node.add_child(sprite)
	node.position = _local(Vector2(_path[0]))
	_world.add_child(node)
	_enemies.append({"node": node, "sprite": sprite, "d": 0.0, "hits": 0})


## Posição da casa ao longo do traçado: `d` é a distância em casas desde a entrada.
func _cell_at(d: float) -> Vector2:
	var i := mini(floori(d), _path.size() - 2)
	return Vector2(_path[i]).lerp(Vector2(_path[i + 1]), d - i)


func _move_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		e["d"] += ENEMY_SPEED * delta
		var node: Node2D = e["node"]
		if e["d"] >= _path.size() - 1:
			_enemies.erase(e)
			node.queue_free()
			continue
		var old_x := node.position.x
		node.position = _local(_cell_at(e["d"]))
		if absf(node.position.x - old_x) > 0.01:
			(e["sprite"] as AnimatedSprite2D).flip_h = node.position.x < old_x


func _fire_towers(delta: float) -> void:
	for t in _towers:
		var pulse := 1.0 + sin(_elapsed * 9.0 + t["phase"]) * 0.14 + sin(_elapsed * 23.0 + t["phase"]) * 0.07
		t["glows"][0].modulate.a = 0.28 * pulse
		t["glows"][1].modulate.a = 0.07 * pulse
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
	var spark := Sprite2D.new()
	spark.texture = load(ART + "spark.png")
	spark.modulate = Color("7fe3ff") if tower["kind"] == 1 else Color("ffd870")
	_fx.add_child(spark)
	var from: Vector2 = (tower["node"] as Node2D).position + Vector2(0, -100)
	var target_node: Node2D = enemy["node"]
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		if is_instance_valid(target_node):
			var to := target_node.position + Vector2(0, -12)
			spark.position = from.lerp(to, t) - Vector2(0, sin(t * PI) * 22.0)
	, 0.0, 1.0, 0.25)
	tween.tween_callback(func() -> void:
		spark.queue_free()
		_hit(enemy))


func _hit(enemy: Dictionary) -> void:
	if not _enemies.has(enemy):
		return
	enemy["hits"] += 1
	var sprite: AnimatedSprite2D = enemy["sprite"]
	sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.12)
	if enemy["hits"] >= ENEMY_HITS:
		_enemies.erase(enemy)
		var node: Node2D = enemy["node"]
		var fade := create_tween().set_parallel()
		fade.tween_property(node, "modulate:a", 0.0, 0.3)
		fade.tween_property(node, "scale", Vector2(1.2, 0.2), 0.3)
		fade.chain().tween_callback(node.queue_free)


# ---------------------------------------------------------------- câmera

func _unhandled_input(event: InputEvent) -> void:
	if _shot_path != "":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_camera.zoom = (_camera.zoom * 1.1).clamp(Vector2(0.6, 0.6), Vector2(4, 4))
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_camera.zoom = (_camera.zoom / 1.1).clamp(Vector2(0.6, 0.6), Vector2(4, 4))
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_panning = mb.pressed
	elif event is InputEventMouseMotion and _panning:
		_camera.position -= (event as InputEventMouseMotion).relative / _camera.zoom
