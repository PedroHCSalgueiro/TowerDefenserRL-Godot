class_name GroundProjection
extends RefCounted
## Ponte entre a grade da simulação e o mundo 3D / a vista da câmera (substitui o `iso.ts` do
## Phaser). A grade vive no plano do chão: a casa (x, y) da simulação é o ponto (x, 0, y) do mundo
## 3D, com o centro da casa em coordenadas inteiras e a casa ocupando ±0,5.
##
## A câmera é ortográfica, olhando de (+x, +z) para (−x, −z) com elevação e azimute de 45° (como o
## laboratório do Sir Aldric). Assim a casa (0,0) fica no topo do losango do mapa, `x` cresce para
## baixo e à direita e `y` (z) para baixo e à esquerda — o mesmo desenho do Phaser.
##
## A "vista" da `CameraModel` é o plano da câmera em pixels: `view_px(x, z)`.

## Elevação da câmera acima do chão e azimute, em graus.
const ELEVATION_DEG := 45.0
const AZIMUTH_DEG := 45.0
## Pixels do plano da vista por unidade do mundo (uma casa = 1 unidade). 32·√2 dá o mesmo tamanho
## horizontal por casa do tile 64×32 do Phaser no zoom 1.
const PX_PER_UNIT := 45.254834


static func elevation() -> float:
	return deg_to_rad(ELEVATION_DEG)


static func azimuth() -> float:
	return deg_to_rad(AZIMUTH_DEG)


## Ponto do chão (x, z; em casas) → ponto do plano da vista, em pixels (direita, baixo).
static func view_px(gx: float, gz: float) -> Vector2:
	var u := (gx * cos(azimuth()) - gz * sin(azimuth()))
	var v := (gx * sin(azimuth()) + gz * cos(azimuth())) * sin(elevation())
	return Vector2(u, v) * PX_PER_UNIT


## Plano da vista (pixels) → ponto do chão (x, z), inverso de `view_px`.
static func ground_from_view(px: Vector2) -> Vector2:
	var u := px.x / PX_PER_UNIT
	var v := px.y / (PX_PER_UNIT * sin(elevation()))
	# u = gx·cos(a) − gz·sin(a);  v = gx·sin(a) + gz·cos(a)  →  rotação inversa.
	return Vector2(u * cos(azimuth()) + v * sin(azimuth()), -u * sin(azimuth()) + v * cos(azimuth()))


## Retângulo do mapa na vista (pixels): a caixa dos quatro cantos do chão do mapa.
static func map_view_bounds(width: int, height: int) -> Rect2:
	return cells_view_bounds(Rect2i(0, 0, width, height))


## Retângulo de um bloco de casas na vista (pixels): a área aberta do mapa que cresce.
static func cells_view_bounds(cells: Rect2i) -> Rect2:
	var x0 := float(cells.position.x) - 0.5
	var y0 := float(cells.position.y) - 0.5
	var x1 := float(cells.end.x) - 0.5
	var y1 := float(cells.end.y) - 0.5
	var corners := [view_px(x0, y0), view_px(x1, y0), view_px(x1, y1), view_px(x0, y1)]
	var min_p: Vector2 = corners[0]
	var max_p: Vector2 = corners[0]
	for c: Vector2 in corners:
		min_p = Vector2(minf(min_p.x, c.x), minf(min_p.y, c.y))
		max_p = Vector2(maxf(max_p.x, c.x), maxf(max_p.y, c.y))
	return Rect2(min_p, max_p - min_p)


## Posição 3D (chão) de um ponto da grade, com altura opcional.
static func to_world(gx: float, gz: float, height: float = 0.0) -> Vector3:
	return Vector3(gx, height, gz)


## Aplica a vista da `CameraModel` à Camera3D ortográfica: o centro da vista vira o ponto do chão
## sob o centro da tela, e o zoom define o tamanho vertical da projeção.
static func apply_view(camera: Camera3D, view: CameraModel.View, viewport_height_px: float) -> void:
	var ground := ground_from_view(view.center)
	var target := Vector3(ground.x, 0.0, ground.y)
	var dir_horizontal := Vector3(sin(azimuth()), 0.0, cos(azimuth()))
	var distance := 60.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = viewport_height_px / view.zoom / PX_PER_UNIT
	camera.near = 0.05
	camera.far = 200.0
	camera.position = target + dir_horizontal * (cos(elevation()) * distance) + Vector3.UP * (sin(elevation()) * distance)
	camera.look_at(target, Vector3.UP)


## Casa (Vector2i) sob um ponto da tela, ou null fora do mapa (ou sem câmera). Usa o raio da câmera
## contra o plano do chão.
static func cell_at_screen(camera: Camera3D, screen_pos: Vector2, map: SimMap) -> Variant:
	var ground: Variant = ground_at_screen(camera, screen_pos)
	if ground == null:
		return null
	var cell := Vector2i(floori(ground.x + 0.5), floori(ground.y + 0.5))
	return cell if map.is_inside(cell) else null


## Ponto do chão (x, z) sob um ponto da tela, ou null se o raio não cruza o chão.
static func ground_at_screen(camera: Camera3D, screen_pos: Vector2) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var normal := camera.project_ray_normal(screen_pos)
	if absf(normal.y) < 0.0001:
		return null
	var t := -origin.y / normal.y
	if t < 0.0:
		return null
	var hit := origin + normal * t
	return Vector2(hit.x, hit.z)
