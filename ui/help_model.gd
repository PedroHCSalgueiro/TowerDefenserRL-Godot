class_name HelpModel
extends RefCounted
## Linhas da tela de ajuda (T17), dos textos em `ui.json`.


## Os controles do jogo; F2 e Ctrl+Shift+D só com o debug liberado. [{"keys", "action", "debug"}]
static func help_lines(debug_unlocked: bool) -> Array:
	var help: Dictionary = DataLoader.load_json("ui.json")["help"]
	var lines: Array = []
	for c: Dictionary in help["controls"]:
		lines.append({"keys": c["keys"], "action": c["action"], "debug": false})
	if debug_unlocked:
		for c: Dictionary in help["debugControls"]:
			lines.append({"keys": c["keys"], "action": c["action"], "debug": true})
	return lines
