class_name FontSetup
extends RefCounted
## A fonte padrão do Godot não tem símbolos como ★ ● ◆ ↑ −. No Windows o sistema completa, mas na
## exportação Web não há fontes do sistema (aparecem quadradinhos). A DejaVu Sans (livre; ver
## assets/fonts/DejaVu-LICENSE.txt) entra como fonte reserva da fonte padrão, para todos os textos.

const FONT_PATH := "res://assets/fonts/DejaVuSans.ttf"
static var _installed := false


static func install() -> void:
	if _installed:
		return
	_installed = true
	var symbols := load(FONT_PATH) as Font
	if symbols == null:
		push_warning("fonte de símbolos ausente: %s" % FONT_PATH)
		return
	var default_font := ThemeDB.fallback_font
	var theme_font := ThemeDB.get_default_theme().default_font
	for font: Font in [default_font, theme_font]:
		if font != null and not font.fallbacks.has(symbols):
			var list := font.fallbacks.duplicate()
			list.append(symbols)
			font.fallbacks = list
