class_name EndScreen
extends Control
## Telas de fim de run (vitória e derrota), sobre o jogo, com as mesmas estatísticas: onda, tempo de
## jogo, abates e a maior cadeia. Semente, marcação de trapaça, "Copiar relatório" e "Jogar de novo"
## (porte de `endScreen.ts`).

signal restart_pressed


func show_report(report: RunReport) -> void:
	UiKit.clear(self)
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.05, 0.72)
	UiKit.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var accent := Color("#6ccf7c") if report.won else Color("#e25555")
	var panel := UiKit.panel(Color("#1d1f21"), Color("#4f9a5b") if report.won else Color("#b54848"), 8, Vector2(48, 32))
	center.add_child(panel)
	var box := UiKit.vbox(8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	var title := UiKit.label("Vitória!" if report.won else "O núcleo caiu", 32, accent, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var summary := UiKit.label("Onda %d/%d · Tempo: %s · Abates: %d · Maior cadeia: x%d" % [
			report.wave, report.total_waves, RunReport.format_time(report.seconds), report.kills, report.longest_chain],
			14, Color("#bbbbbb"))
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(summary)
	var seed_label := UiKit.label("Semente: %s · Versão: %s" % [report.seed_text, report.version], 12, Color("#888888"))
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(seed_label)
	if report.cheated:
		var cheated := UiKit.label("Run com trapaças", 14, Color("#ffb347"), true)
		cheated.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(cheated)
	var note := UiKit.label("", 12, Color("#9be37a"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var copy := UiKit.button("Copiar relatório", func() -> void:
		DisplayServer.clipboard_set(report.format())
		note.text = "Relatório copiado.")
	copy.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(copy)
	box.add_child(note)
	var restart := UiKit.button("Jogar de novo", func() -> void: restart_pressed.emit())
	restart.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(restart)
	visible = true


func hide_screen() -> void:
	visible = false
	UiKit.clear(self)
