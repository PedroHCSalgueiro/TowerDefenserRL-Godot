class_name MutablePoint
extends RefCounted
## Ponto com coordenadas de 64 bits (float do GDScript).
##
## A simulação NUNCA usa Vector2 para posições fracionárias: Vector2 é 32 bits
## nesta build do Godot e quebraria a paridade com o Phaser (float64).
## `Enemy` herda daqui, para a rota escrever a posição direto no inimigo.

var x: float = 0.0
var y: float = 0.0


func _init(p_x: float = 0.0, p_y: float = 0.0) -> void:
	x = p_x
	y = p_y
