extends Node2D
## Visualizador das folhas em pixel dos heróis (Arte/ferramentas/render_pixel.py): parado e ataque.
##   godot --path . res://dev/prototipos/proto25d/animacoes_herois.tscn
## Modo ampliado: os heróis a ZOOM, uma fileira por região, e a direção gira a cada ataque. Modo grade:
## as 8 direções em tamanho real, GRID_PAGE heróis por página. Tab troca o modo e a página, setas giram a
## direção, Espaço pausa. Heróis sem folha em art_<id> ficam de fora.

const ART := "res://dev/prototipos/proto25d/"
## [nome, pasta, fileira no modo ampliado]
const HEROES := [
	["Sir Aldric", ART + "art_pixel/", 0],
	["Lyra", ART + "art_lyra/", 0],
	["Irmão Tomás", ART + "art_tomas/", 0],
	["Mestre Brom", ART + "art_brom/", 0],
	["Dama Selene", ART + "art_selene/", 0],
	["Wulf", ART + "art_wulf/", 0],
	["Eng. Mabel", ART + "art_mabel/", 0],
	["Rainha Isolde", ART + "art_isolde/", 0],
	["Bart", ART + "art_bart/", 1],
	["Ruby", ART + "art_ruby/", 1],
	["Imediato Âncora", ART + "art_ancora/", 1],
	["Morgana", ART + "art_morgana/", 1],
	["Kraus", ART + "art_kraus/", 1],
	["Mama Zuri", ART + "art_mama/", 1],
	["Nerea", ART + "art_nerea/", 1],
	["Polvo da Nerea", ART + "art_polvo/", 1],
	["Capitão Pena", ART + "art_pena/", 1],
	["Bolt", ART + "art_bolt/", 2],
	["Torreta do Bolt", ART + "art_torreta/", 2],
	["Vapora", ART + "art_vapora/", 2],
	["Golem Caldeira", ART + "art_golem/", 2],
	["Tic", ART + "art_tic/", 2],
	["Greta", ART + "art_greta/", 2],
]
const IDLE_FPS := 8.0
const ATTACK_FPS := 15.0
## Quadro em que sai o disparo (o mesmo de herois_ref.gd).
const FIRE_FRAME := 5
const ZOOM := 1.75
## Pés de cada fileira no modo ampliado.
const ROW_FEET := [215.0, 430.0, 645.0]
const GRID_PAGE := 4
const GRID_STEP := Vector2(116, 150)
const BG := Color("4c5a58")

var _heroes: Array[Dictionary] = []
var _sprites: Array[AnimatedSprite2D] = []
var _labels: Array[Label] = []
## -1 = ampliado; senão, a página da grade.
var _page := -1
var _dir := 1
var _phase := "idle"
var _phase_t := 0.0
var _paused := false
var _status: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for h in HEROES:
		var folder: String = h[1]
		if not FileAccess.file_exists(folder + "meta.json"):
			continue
		var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "meta.json"))
		var idle := _tex(folder + "Idle.png")
		var attack := _tex(folder + "Attack.png")
		var cols := int(meta["cols"])
		var dirs: Array[SpriteFrames] = []
		for row in meta["angles"].size():
			var frames := SpriteFrames.new()
			frames.remove_animation("default")
			frames.add_animation("idle")
			frames.set_animation_speed("idle", IDLE_FPS)
			frames.add_animation("attack")
			frames.set_animation_speed("attack", ATTACK_FPS)
			frames.set_animation_loop("attack", false)
			for f in cols:
				frames.add_frame("idle", _cell(idle, f, row))
				frames.add_frame("attack", _cell(attack, f, row))
			dirs.append(frames)
		_heroes.append({"name": h[0], "row": h[2], "dirs": dirs, "anchor": Vector2(meta["anchor"][0], meta["anchor"][1]), "cols": cols})
	_status = _label("", 18)
	_status.position = Vector2(16, 692)
	_layout()


func _tex(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))


func _cell(sheet: Texture2D, col: int, row: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(col * 128, row * 128, 128, 128)
	return a


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _sprite(hero: Dictionary, dir: int, pos: Vector2, scale_k: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = hero["dirs"][dir]
	s.centered = false
	s.offset = -hero["anchor"]
	s.scale = Vector2.ONE * scale_k
	s.position = pos
	s.set_meta("hero", hero)
	s.set_meta("dir", dir)
	add_child(s)
	_sprites.append(s)
	return s


## Monta os sprites do modo atual; os pés de cada sprite ficam em `position`.
func _layout() -> void:
	for s in _sprites:
		s.queue_free()
	for l in _labels:
		l.queue_free()
	_sprites.clear()
	_labels.clear()
	if _page >= 0:
		var first := _page * GRID_PAGE
		for i in range(first, mini(first + GRID_PAGE, _heroes.size())):
			var y := 150.0 + (i - first) * GRID_STEP.y
			var name_label := _label(_heroes[i]["name"], 20)
			name_label.position = Vector2(16, y - 40)
			_labels.append(name_label)
			for d in 8:
				_sprite(_heroes[i], d, Vector2(230 + d * GRID_STEP.x, y), 1.0)
	else:
		for row in ROW_FEET.size():
			var group := _heroes.filter(func(h: Dictionary) -> bool: return h["row"] == row)
			var step := 1280.0 / maxf(group.size(), 1)
			for i in group.size():
				var x := step * (i + 0.5)
				_sprite(group[i], _dir, Vector2(x, ROW_FEET[row]), ZOOM)
				var name_label := _label(group[i]["name"], 18)
				name_label.size = Vector2(step, 30)
				name_label.position = Vector2(x - step * 0.5, ROW_FEET[row] + 12)
				name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_labels.append(name_label)
	_set_phase(_phase)


func _set_phase(phase: String) -> void:
	_phase = phase
	_phase_t = 0.0
	for s in _sprites:
		s.play(phase)
	_update_status()


func _update_status() -> void:
	var pages := ceili(_heroes.size() / float(GRID_PAGE))
	var mode := "grade, tamanho real, página %d/%d" % [_page + 1, pages] if _page >= 0 else "ampliado %sx, direção %d/8" % [ZOOM, _dir + 1]
	var phase := "Parado" if _phase == "idle" else "Ataque (disparo no quadro %d)" % FIRE_FRAME
	_status.text = "%s  |  %s  |  Tab: modo   Setas: direção   Espaço: pausa" % [phase, mode]


func _process(delta: float) -> void:
	if _paused or _heroes.is_empty():
		return
	_phase_t += delta
	var cols: int = _heroes[0]["cols"]
	if _phase == "idle" and _phase_t >= cols / IDLE_FPS:
		_set_phase("attack")
	elif _phase == "attack" and _phase_t >= cols / ATTACK_FPS + 0.25:
		if _page < 0:
			_turn(1)
		_set_phase("idle")


func _turn(step: int) -> void:
	_dir = posmod(_dir + step, 8)
	for s in _sprites:
		var hero: Dictionary = s.get_meta("hero")
		s.sprite_frames = hero["dirs"][_dir]
	_update_status()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_TAB:
			_page += 1
			if _page >= ceili(_heroes.size() / float(GRID_PAGE)):
				_page = -1
			_layout()
		KEY_RIGHT:
			_turn(1)
			_set_phase(_phase)
		KEY_LEFT:
			_turn(-1)
			_set_phase(_phase)
		KEY_SPACE:
			_paused = not _paused
			for s in _sprites:
				if _paused:
					s.pause()
				else:
					s.play()
