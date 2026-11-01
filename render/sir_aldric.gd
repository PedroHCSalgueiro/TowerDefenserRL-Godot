extends Node3D
# Sir Aldric (torre do raio). O modelo vem de assets/personagens/sir-aldric/sir-aldric.glb (V2: cabeça nova, capa, escudo e espada no esqueleto CC).
# - Parado: fica na pose do primeiro quadro da animação "ataque" (ainda não há idle).
# - atacar(intervalo): toca "ataque" acelerada para caber no intervalo entre ataques.
# - A animação tem uma faixa Call Method no quadro em que a espada está mais alta (t = 0,70 s)
#   que chama disparar_raio(); ela emite raio_disparado com a posição da ponta da espada.
#   O .glb não traz essa faixa: ela é acrescentada à animação importada ao carregar.

signal raio_disparado(ponta: Vector3)

const ANIM := "ataque"
const RAIO_T := 0.70                        # instante (s) em que a espada está mais alta e o raio sai
const PONTA_LOCAL := Vector3(0, 1.03, 0)    # ponta da lâmina no espaço local da malha "Espada"
const FOLGA := 0.9                          # a animação usa no máximo 90% do intervalo entre ataques

var ap: AnimationPlayer
var espada: Node3D


func _ready() -> void:
	ap = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	espada = find_child("Espada", true, false) as Node3D
	_acrescentar_faixa_do_raio()
	ap.animation_finished.connect(_ao_terminar)
	_pose_parado()


func _acrescentar_faixa_do_raio() -> void:
	var anim := ap.get_animation(ANIM)
	if anim == null:
		return
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_METHOD:
			return   # já tem: a animação importada é compartilhada entre as torres
	var faixa := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(faixa, ap.get_node(ap.root_node).get_path_to(self))
	anim.track_insert_key(faixa, RAIO_T, {"method": &"disparar_raio", "args": []})


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
