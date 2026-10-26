class_name ClassPanel
extends VBoxContainer
## Painel lateral das classes, sobre o jogo: cada classe com a contagem atual e o próximo nível
## (ex.: "Arcana 3/4"), o nível ativo em destaque e, ao passar o mouse, o texto dos níveis e as
## torres que contam (porte de `classPanel.ts`). A dica aparece como tooltip nativo do nó.
## Linhas compactas: com todas as regiões são 13 (8 classes + 5 regiões), e o painel do núcleo, logo
## abaixo, não pode ficar atrás das cartas da loja.

const FONT_SIZE := 11
const ROW_PADDING := Vector2(8, 2)

var _key := ""


func _init() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size = Vector2(170, 0)


## Chame a cada quadro: só refaz os nós quando contagem ou nível mudaram. `wildcards`: coringas das
## recompensas por classe (T24).
func update(class_state: Dictionary, wildcards: Dictionary = {}) -> void:
	var rows := ClassPanelModel.build_rows(class_state, ClassData.game_data(), TowerData.game_data(), wildcards)
	var key := ClassPanelModel.rows_key(rows)
	if key == _key:
		return
	_key = key
	UiKit.clear(self)
	for row in rows:
		add_child(_render_row(row))


func _render_row(row: ClassPanelModel.Row) -> Control:
	var active := row.level > 0
	var node := PanelContainer.new()
	var bg := Color(0.2275, 0.1882, 0.0784, 0.92) if active else UiKit.BG
	var border := Color("#e0b84a") if active else UiKit.BORDER
	node.add_theme_stylebox_override("panel", UiKit.style(bg, border, 5, 1, ROW_PADDING))
	node.add_child(UiKit.label(row.label, FONT_SIZE, Color("#ffe9a8") if active else UiKit.TEXT, active))
	var lines: Array[String] = []
	for level: Dictionary in row.levels:
		lines.append("%sNível %d: %s" % ["▶ " if level["active"] else "", level["count"], level["text"]])
	lines.append("Contando: %s" % ", ".join(row.members) if not row.members.is_empty() else "Nenhuma torre contando")
	node.tooltip_text = "\n".join(lines)
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	return node
