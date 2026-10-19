class_name LinkHint
extends RefCounted
## Texto curto perto do mouse enquanto uma torre está na mão (T23): "sem ligações aqui", a fusão
## ("funde: ★2↑") ou as ligações ("ativa 2 · carga 1"), e a prévia de classes da loja (T16).
## Modelo puro (porte de `linkHint.ts`); o nó que desenha fica em `link_hint_label.gd`.

const KINDS := ["activates", "charges", "copies"]


## Linhas do texto; vazio = nada a mostrar.
static func lines(preview: TriggerLinks, purchase: ClassPreview) -> Array[String]:
	var texts: Dictionary = DataLoader.load_json("ui.json")["linkHint"]["texts"]
	var out: Array[String] = []
	if purchase != null and purchase.fusion != "":
		out.append("funde: %s" % purchase.fusion)
		return out
	if preview != null:
		if preview.links.is_empty():
			out.append(texts["none"])
		else:
			var parts: Array[String] = []
			for kind: String in KINDS:
				var n := 0
				for l in preview.links:
					if l.kind == kind:
						n += 1
				if n > 0:
					parts.append("%s %d" % [texts[kind], n])
			out.append(" · ".join(parts))
	if purchase != null:
		out.append_array(purchase.classes)
	return out
