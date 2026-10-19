class_name RenderConfig
extends RefCounted
## Números e cores da renderização (data/render.json), com os tamanhos convertidos de "pixels do
## Phaser" para unidades do mundo 3D (uma casa = 1 unidade; no Phaser uma casa tem 32 px de
## largura no zoom 1, então 1 px ≈ 1/32 de casa).

## Pixels do Phaser por unidade do mundo (para converter raios, alturas etc.).
const PX_TO_UNIT := 1.0 / 32.0

static var _cfg: Dictionary = {}
## Conjunto de torres a que `_cfg` pertence (trocar de conjunto muda cores e modelos).
static var _cfg_set := ""


static func data() -> Dictionary:
	if _cfg.is_empty() or _cfg_set != DataLoader.set_id():
		_cfg = DataLoader.load_json("render.json")
		_cfg_set = DataLoader.set_id()
	return _cfg


## "#rrggbb" → Color.
static func color(hex: String, alpha: float = 1.0) -> Color:
	var c := Color.html(hex)
	c.a = alpha
	return c


## Cor da classe principal da torre (a primeira); `fallbackColor` se não tiver classe.
static func tower_color(towers: TowerData, type: String) -> Color:
	var cfg: Dictionary = data()["towers"]
	var t := towers.types.get(type) as TowerData.TowerType
	if t == null or t.classes.is_empty():
		return color(cfg["fallbackColor"])
	return color(cfg["classColors"].get(t.classes[0], cfg["fallbackColor"]))


## Cor do inimigo pelo tipo.
static func enemy_color(type: String) -> Color:
	var cfg: Dictionary = data()["enemies"]
	return color(cfg["colors"].get(type, cfg["fallbackColor"]))
