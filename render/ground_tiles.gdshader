shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// O chão em pixel (`GroundTiles`): cada casa aberta desenha um losango do bioma (`tile`, 48x24), pixel a pixel.
//
// Com a câmera 2:1 (azimute 45°, elevação 30°), o ponto do chão (x, z) cai a ((x - z)*W/2, (x + z)*H/2) pixels da
// arte na tela, e o centro da casa (cx, cz) fica no centro do losango dela. Aqui o caminho é o inverso: cada
// fragmento vira um pixel da arte (U, V), e o losango que é dono desse pixel diz qual imagem desenhar. Os
// losangos do gerador de biomas encaixam em escada (linhas de 2, 6, 10 ... W - 2 pixels), então o pixel da borda
// pode ser da casa vizinha: o teste da escada decide.
//
// `cells` guarda, por casa, o índice da imagem no atlas + 1 (0 = casa fechada, sem chão).

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform sampler2D cells : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(1.0, 1.0);
// Escurece a borda de cada losango (linha da grade, discreta).
uniform float grid_shade = 0.0;
// Tamanho da casa em pixels da arte (largura = 2 x altura).
uniform ivec2 tile = ivec2(48, 24);

varying vec3 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Dentro do losango da imagem (pixel local em 0..W-1, 0..H-1), como o `diamond_mask` do gerador de biomas.
bool inside(ivec2 p) {
	int hw = tile.x / 2;
	int k = p.y < tile.y / 2 ? p.y : tile.y - 1 - p.y;
	return p.y >= 0 && p.y < tile.y && p.x >= hw - 1 - 2 * k && p.x <= hw + 2 * k;
}

// A borda do losango (algum vizinho de 4 lados fica fora dele).
bool border(ivec2 p) {
	return !inside(p + ivec2(1, 0)) || !inside(p + ivec2(-1, 0)) || !inside(p + ivec2(0, 1)) || !inside(p + ivec2(0, -1));
}

void fragment() {
	float TILE_W = float(tile.x);
	float TILE_H = float(tile.y);
	// pixel da arte sob o fragmento (o chão parado fica em y = 0; ao subir, a imagem sobe junto)
	vec2 uv_px = vec2((ground.x - ground.z) * TILE_W * 0.5, (ground.x + ground.z) * TILE_H * 0.5);
	vec2 px = floor(uv_px) + 0.5;
	// casa mais próxima pelo centro do pixel e, se a escada disser, a vizinha
	ivec2 cell = ivec2(round(vec2(px.x / TILE_W + px.y / TILE_H, px.y / TILE_H - px.x / TILE_W)));
	ivec2 local = ivec2(floor(px - vec2(float(cell.x - cell.y) * TILE_W * 0.5, float(cell.x + cell.y) * TILE_H * 0.5)
			+ vec2(TILE_W * 0.5, TILE_H * 0.5)));
	if (!inside(local)) {
		bool left = local.x < tile.x / 2;
		bool top = local.y < tile.y / 2;
		// vizinha: em cima à esquerda é x - 1, em cima à direita é z - 1, embaixo à direita x + 1, embaixo à esquerda z + 1
		ivec2 nb = top ? (left ? ivec2(-1, 0) : ivec2(0, -1)) : (left ? ivec2(0, 1) : ivec2(1, 0));
		cell += nb;
		local -= ivec2((nb.x - nb.y) * (tile.x / 2), (nb.x + nb.y) * (tile.y / 2));
	}
	if (cell.x < 0 || cell.y < 0 || float(cell.x) >= map_size.x || float(cell.y) >= map_size.y) {
		discard;
	}
	int index = int(round(texelFetch(cells, cell, 0).r * 255.0)) - 1;
	if (index < 0) {
		discard;
	}
	vec4 color = texelFetch(atlas, ivec2(index * tile.x + local.x, local.y), 0);
	if (color.a < 0.5) {
		discard;
	}
	ALBEDO = border(local) ? color.rgb * (1.0 - grid_shade) : color.rgb;
}
