class_name HeroSprite
extends Node3D
## Herói em pixel (folhas de `Arte/ferramentas/render_pixel.py`): `Idle.png` e `Attack.png` com uma linha
## por direção e `meta.json` com o tamanho da casa, as colunas, o ponto dos pés e o ângulo de cada linha.
## Substitui o modelo 3D da torre (`towers.models.<id>.sprites` em `render.json`): o `TowerView` gira este
## nó para o alvo e chama `atacar(intervalo)`; a linha da folha é escolhida pelo ângulo entre essa direção
## e a câmera, então girar a câmera também troca a direção. Números em `towers.heroSprites`.
##
## Pixel exato (pixel 2x, folhas `estilo-novo/x64`): um pixel da folha é um pixel da arte do mundo
## (`camera.pixelArt`), e a cada quadro o sprite cai inteiro na grade de pixels da tela.

## Emitido no quadro do disparo quando `raio` é verdadeiro (o Sir Aldric), com o ponto de onde o raio sai.
signal raio_disparado(ponta: Vector3)

var raio := false

var _sprite: AnimatedSprite3D
var _rows: Array[SpriteFrames] = []
var _angles: Array[float] = []
var _row := -1
var _cols := 1
var _cfg: Dictionary
var _height := 1.0


## Monta o herói a partir da pasta das folhas; null se faltar algum arquivo.
static func create(folder: String, cfg: Dictionary) -> HeroSprite:
	var meta_path := folder + "meta.json"
	if not FileAccess.file_exists(meta_path) or not ResourceLoader.exists(folder + "Idle.png") or not ResourceLoader.exists(folder + "Attack.png"):
		return null
	var hero := HeroSprite.new()
	hero._build(JSON.parse_string(FileAccess.get_file_as_string(meta_path)), load(folder + "Idle.png"), load(folder + "Attack.png"), cfg)
	return hero


func _build(meta: Dictionary, idle: Texture2D, attack: Texture2D, cfg: Dictionary) -> void:
	_cfg = cfg
	_height = float(cfg["heightUnits"])
	var cell := float(meta["cell"])
	_cols = int(meta["cols"])
	for row in meta["angles"].size():
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		frames.add_animation("idle")
		frames.set_animation_speed("idle", float(cfg["idleFps"]))
		frames.add_animation("attack")
		frames.set_animation_loop("attack", false)
		for f in _cols:
			frames.add_frame("idle", _cell(idle, f, row, cell))
			frames.add_frame("attack", _cell(attack, f, row, cell))
		_rows.append(frames)
		_angles.append(float(meta["angles"][row]))
	_sprite = AnimatedSprite3D.new()
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# a sombra vem desenhada na folha, semitransparente: corte de alfa a deixaria preta
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.pixel_size = float(RenderConfig.data()["camera"]["pixelArt"]["viewPxPerArtPx"]) / GroundProjection.PX_PER_UNIT
	# o pé fica num canto de pixel (o meta.json traz o ponto com sobra de arredondamento)
	_sprite.offset = Vector2(roundf(cell * 0.5 - float(meta["anchor"][0])), roundf(float(meta["anchor"][1]) - cell * 0.5))
	_sprite.sprite_frames = _rows[0]
	_sprite.frame_changed.connect(_on_frame)
	_sprite.animation_finished.connect(_sprite.play.bind("idle"))
	add_child(_sprite)
	_sprite.play("idle")


static func _cell(sheet: Texture2D, col: int, row: int, cell: float) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2(col * cell, row * cell, cell, cell)
	return a


## Toca o ataque inteiro dentro do intervalo entre os tiros, nunca mais devagar que `attackFps`.
func atacar(intervalo: float) -> void:
	var fps := maxf(float(_cfg["attackFps"]), _cols / maxf(0.05, intervalo * float(_cfg["attackShare"])))
	_sprite.sprite_frames.set_animation_speed("attack", fps)
	_sprite.stop()
	_sprite.play("attack")


## O ponto levado para a borda de pixel mais perto na tela (anda menos de meio pixel da arte): com os pés num canto
## de pixel, cada pixel da folha cai inteiro num pixel da tela, sem coluna dobrada nem sumida.
func _on_pixel_grid(cam: Camera3D, point: Vector3) -> Vector3:
	var art := 1.0 / _sprite.pixel_size
	var screen := get_viewport().get_visible_rect().size
	var local := cam.global_transform.affine_inverse() * point
	var half := Vector2(cam.size * screen.x / screen.y, cam.size) * art * 0.5
	var px := Vector2(local.x * art + half.x, -local.y * art + half.y)
	var d := px.round() - px
	var basis := cam.global_transform.basis
	return point + basis.x * (d.x / art) - basis.y * (d.y / art)


func atacando() -> bool:
	return _sprite.animation == "attack" and _sprite.is_playing()


func _on_frame() -> void:
	if raio and _sprite.animation == "attack" and _sprite.frame == int(_cfg["fireFrame"]):
		raio_disparado.emit(global_position + Vector3.UP * _height * float(_cfg["beamHeight"]))


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var view := cam.global_transform.basis
	# um pouco para a frente, na direção da câmera, para o chão não cortar os pés
	_sprite.global_position = _on_pixel_grid(cam, global_position + view.z * float(_cfg["forwardUnits"]))
	var look := global_transform.basis.z
	var right := Vector3(view.x.x, 0, view.x.z).normalized()
	var to_cam := Vector3(view.z.x, 0, view.z.z).normalized()
	var angle := rad_to_deg(atan2(look.dot(right), look.dot(to_cam)))
	var best := 0
	for i in _angles.size():
		if absf(wrapf(angle - _angles[i], -180.0, 180.0)) < absf(wrapf(angle - _angles[best], -180.0, 180.0)):
			best = i
	if best == _row:
		return
	_row = best
	var anim := _sprite.animation
	var frame := _sprite.frame
	var progress := _sprite.frame_progress
	var fps := _sprite.sprite_frames.get_animation_speed("attack")
	_sprite.sprite_frames = _rows[best]
	_sprite.sprite_frames.set_animation_speed("attack", fps)
	_sprite.play(anim)
	_sprite.set_frame_and_progress(frame, progress)
