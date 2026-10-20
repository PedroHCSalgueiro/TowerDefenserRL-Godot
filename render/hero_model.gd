class_name HeroModel
extends Node3D
## Modelo 3D de um herói sem efeito especial no ataque (a Lyra): fica na pose do primeiro quadro da animação
## "ataque" e, a cada tiro, toca essa animação acelerada para caber no intervalo entre os tiros. O `TowerView`
## chama `atacar(intervalo)`. (O Sir Aldric tem script próprio porque a animação dele dispara um raio.)

## Nome preferido da animação de ataque; se o arquivo trouxer outro nome (a exportação do Blender chama de
## "Animation"), vale a primeira animação que não seja a RESET.
const ANIM_PREFERIDA := "ataque"
## A animação usa no máximo 90% do intervalo entre os tiros.
const FOLGA := 0.9

var ap: AnimationPlayer
var _anim := ""


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	ap = players[0] as AnimationPlayer
	_anim = _escolher_animacao()
	ap.animation_finished.connect(_ao_terminar)
	_pose_parado()


func _escolher_animacao() -> String:
	if ap.has_animation(ANIM_PREFERIDA):
		return ANIM_PREFERIDA
	for nome in ap.get_animation_list():
		if nome != "RESET":
			return nome
	return ""


func _pose_parado() -> void:
	if ap == null or _anim == "":
		return
	ap.speed_scale = 1.0
	ap.play(_anim)
	ap.seek(0.0, true)
	ap.pause()


func atacar(intervalo: float) -> void:
	if ap == null or _anim == "":
		return
	var dur := ap.get_animation(_anim).length
	ap.speed_scale = maxf(1.0, dur / (intervalo * FOLGA))
	ap.stop()
	ap.play(_anim)


func atacando() -> bool:
	return ap != null and ap.is_playing()


func _ao_terminar(nome: StringName) -> void:
	if nome == _anim:
		_pose_parado()
