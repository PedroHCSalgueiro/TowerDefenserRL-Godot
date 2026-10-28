class_name CoinIcon
extends Control
## Moeda de ouro desenhada por código (círculo, aro e brilho). Se existir `assets/ui/coin.png`, a
## imagem toma o lugar do desenho: é o gancho para a arte final, sem mexer em mais nada.

const TEXTURE_PATH := "res://assets/ui/coin.png"

static var _texture: Texture2D = null
static var _texture_checked := false


func _init(diameter: float = 24.0) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_coin(self, size * 0.5, minf(size.x, size.y) * 0.5)


## Desenha a moeda em qualquer `CanvasItem` (a carta e o HUD usam o mesmo desenho).
static func draw_coin(item: CanvasItem, center: Vector2, radius: float) -> void:
	var texture := _coin_texture()
	if texture != null:
		item.draw_texture_rect(texture, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
		return
	item.draw_circle(center + Vector2(0.0, radius * 0.08), radius, Color(0.0, 0.0, 0.0, 0.35))
	item.draw_circle(center, radius, Color("#a8741a"))
	item.draw_circle(center, radius * 0.86, Color("#f2c744"))
	item.draw_arc(center, radius * 0.62, 0.0, TAU, 24, Color("#b98a22"), maxf(1.0, radius * 0.12), true)
	item.draw_arc(center, radius * 0.7, PI * 1.1, PI * 1.7, 12, Color("#fff1b0"), maxf(1.0, radius * 0.14), true)


static func _coin_texture() -> Texture2D:
	if not _texture_checked:
		_texture_checked = true
		if ResourceLoader.exists(TEXTURE_PATH):
			_texture = load(TEXTURE_PATH) as Texture2D
	return _texture
