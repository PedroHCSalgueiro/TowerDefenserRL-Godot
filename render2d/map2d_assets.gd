class_name Map2DAssets
extends RefCounted
## Assets do mapa 2D (gerados por `Arte/ferramentas/gerar_tiles_2d.py` a partir das artes existentes): o TileSet
## isométrico de 48x24 com três atlas (chão, saia da borda, muralha) e as peças com o ponto do pé.

const SRC_CHAO := 0
const SRC_BORDA := 1
const SRC_MURALHA := 2

var tile_set: TileSet
var meta: Dictionary
var folder := ""
var _textures := {}


static func load_from(folder_path: String) -> Map2DAssets:
	var a := Map2DAssets.new()
	a.folder = folder_path
	a.meta = JSON.parse_string(FileAccess.get_file_as_string(folder_path + "mapa2d.json"))
	a._build_tile_set()
	return a


func _build_tile_set() -> void:
	tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = Vector2i(int(meta["tile"][0]), int(meta["tile"][1]))
	for pair: Array in [["chao", SRC_CHAO], ["borda", SRC_BORDA], ["muralha", SRC_MURALHA]]:
		var info: Dictionary = meta[pair[0]]
		var src := TileSetAtlasSource.new()
		src.texture = load(folder + String(pair[0]) + ".png")
		var size := Vector2i(int(info["tamanho"][0]), int(info["tamanho"][1]))
		src.texture_region_size = size
		tile_set.add_source(src, pair[1])
		# o centro da casa dentro da imagem fica no centro da casa do mapa
		var origin := Vector2i(int(info["centro"][0]) - size.x / 2, int(info["centro"][1]) - size.y / 2)
		for key: String in info["tiles"]:
			var c: Array = info["tiles"][key]
			var coords := Vector2i(int(c[0]), int(c[1]))
			src.create_tile(coords)
			var td := src.get_tile_data(coords, 0)
			td.texture_origin = origin
			# a muralha se ordena meia casa para trás: o que está nas casas da frente dela é sempre desenhado depois
			if pair[1] == SRC_MURALHA:
				td.y_sort_origin = -int(meta["tile"][1]) / 2 - 1


## Posição no atlas da peça `name` do grupo ("chao", "borda" ou "muralha").
func tile(group: String, name: String) -> Vector2i:
	var c: Array = meta[group]["tiles"][name]
	return Vector2i(int(c[0]), int(c[1]))


func has_tile(group: String, name: String) -> bool:
	return meta[group]["tiles"].has(name)


## Sprite da peça com o pé no ponto (0, 0) do nó.
func prop(name: String) -> Sprite2D:
	if not meta["pecas"].has(name):
		push_warning("mapa 2D: peça desconhecida %s" % name)
		return null
	if not _textures.has(name):
		_textures[name] = load(folder + "pecas/" + name + ".png")
	var s := Sprite2D.new()
	s.texture = _textures[name]
	s.centered = false
	var foot: Array = meta["pecas"][name]["pe"]
	s.offset = -Vector2(float(foot[0]), float(foot[1]))
	return s
