extends Node3D
# Sir Aldric (torre do raio). O modelo vem de assets/sir-aldric.glb.
# - Parado: fica na pose do primeiro quadro da animação "ataque" (ainda não há idle).
# - atacar(intervalo): toca "ataque" acelerada para caber no intervalo entre ataques.
# - A animação tem uma faixa Call Method no quadro em que a espada está mais alta (t = 0,70 s)
#   que chama disparar_raio(); ela emite raio_disparado com a posição da ponta da espada.

signal raio_disparado(ponta: Vector3)

const ANIM := "ataque"
const PONTA_LOCAL := Vector3(0, 0.876, 0)   # ponta da lâmina no espaço local da malha "Espada"
const FOLGA := 0.9                          # a animação usa no máximo 90% do intervalo entre ataques

var ap: AnimationPlayer
var espada: Node3D


func _ready() -> void:
	ap = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	espada = find_child("Espada", true, false) as Node3D
	ap.animation_finished.connect(_ao_terminar)
	_pose_parado()


func _pose_parado() -> void:
	ap.speed_scale = 1.0
	ap.play(ANIM)
	ap.seek(0.0, true)
	ap.pause()


func atacar(intervalo: float) -> void:
	var dur := ap.get_animation(ANIM).length
	ap.speed_scale = maxf(1.0, dur / (intervalo * FOLGA))
	ap.stop()
	ap.play(ANIM)


func atacando() -> bool:
	return ap.is_playing()


# chamado pela faixa Call Method da animação
func disparar_raio() -> void:
	raio_disparado.emit(ponta_espada())


func ponta_espada() -> Vector3:
	return espada.global_transform * PONTA_LOCAL


func _ao_terminar(nome: StringName) -> void:
	if nome == ANIM:
		_pose_parado()
