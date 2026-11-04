class_name RenderConfig
extends RefCounted
## Números e cores da renderização (data/render.json), com os tamanhos convertidos de "pixels do
## Phaser" para unidades do mundo 3D (uma casa = 1 unidade). Os tamanhos em px valem na tela, no zoom 1: com a
## casa de 96 px de largura, 1 px ≈ 1/48 de casa (era 1/32 com a casa de 64; heróis, inimigos e barras ficaram do
## mesmo tamanho na tela e só a casa cresceu).

## Pixels do Phaser por unidade do mundo (para converter raios, alturas etc.).
const PX_TO_UNIT := 1.0 / 48.0

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


## Cor de efeito da torre (`towers.effectColors` em render.json, por campeão: pulsos dos gatilhos e a tampa
## do bloco); sem ela, a cor da classe principal.
static func effect_color(towers: TowerData, type: String) -> Color:
	var colors: Dictionary = data()["towers"].get("effectColors", {})
	if colors.has(type):
		return color(colors[type])
	return tower_color(towers, type)


## Cor do inimigo pelo tipo.
static func enemy_color(type: String) -> Color:
	var cfg: Dictionary = data()["enemies"]
	return color(cfg["colors"].get(type, cfg["fallbackColor"]))
