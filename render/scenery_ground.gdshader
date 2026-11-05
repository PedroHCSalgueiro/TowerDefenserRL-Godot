shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Chão do cenário (`SceneryGround`, `grid.scenery` em render.json): pátio de lajes escuras em manchas e caminho de
// pedra clara, desenhados pixel a pixel da arte (docs/direcao-visual-cenario.md).
//
// - Cada fragmento vira o centro de um pixel da arte; tudo é calculado nesse ponto, então o chão fica em pixel exato.
// - A borda do caminho é orgânica: a casa é procurada num ponto torto por um ruído (`warp`, em casas), e não no ponto
//   certo. As casas de construir e o caminho dos inimigos não mudam, só o desenho.
// - `cells`: tipo de cada casa (0 fechada, 1 livre, 2 caminho, 3 entrada, 4 núcleo) em R*255.
// - `glow`: brilho do caminho (1 na entrada, caindo pelo caminho), amostrado com filtro linear para ficar suave.

uniform sampler2D cells : filter_nearest, repeat_disable;
uniform sampler2D glow : filter_linear, repeat_disable;
uniform vec2 map_size = vec2(1.0, 1.0);
uniform ivec2 tile = ivec2(48, 24);
uniform vec3 floor_ramp[5];
uniform vec3 path_ramp[5];
uniform vec3 dirt_ramp[5];
uniform vec3 grass_ramp[5];
// quanto do pátio é laje, grama e terra (o resto); as manchas são grandes e de borda irregular
uniform float slab_share = 0.3;
uniform float grass_share = 0.35;
uniform vec3 glow_color = vec3(0.6, 0.3, 1.0);
uniform float glow_strength = 0.5;
uniform float warp = 0.16;
uniform float slab = 0.5;
uniform float joint_dark = 0.62;
uniform float moss_amount = 0.25;
uniform vec3 moss_color = vec3(0.16, 0.24, 0.14);
uniform float rim_dark = 0.75;
// grade só em volta do mouse (como no `GroundTiles`)
uniform float grid_shade = 0.0;
uniform vec2 cursor = vec2(-1000.0, -1000.0);
uniform float grid_radius = 2.5;

varying vec3 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.1 + 7.0) + 0.15 * vnoise(p * 4.3 + 13.0);
}

int kind(vec2 g) {
	ivec2 c = ivec2(floor(g + 0.5));
	if (c.x < 0 || c.y < 0 || float(c.x) >= map_size.x || float(c.y) >= map_size.y) {
		return 0;
	}
	return int(round(texelFetch(cells, c, 0).r * 255.0));
}

bool is_path(int k) {
	return k >= 2;
}

void fragment() {
	float W = float(tile.x);
	float H = float(tile.y);
	// centro do pixel da arte sob o fragmento, de volta para o chão
	vec2 uv_px = vec2((ground.x - ground.z) * W * 0.5, (ground.x + ground.z) * H * 0.5);
	vec2 px = floor(uv_px) + 0.5;
	vec2 g = vec2((px.x / (W * 0.5) + px.y / (H * 0.5)) * 0.5, (px.y / (H * 0.5) - px.x / (W * 0.5)) * 0.5);

	int base = kind(g);
	if (base == 0) {
		discard;
	}
	vec2 tw = vec2(fbm(g * 1.7), fbm(g * 1.7 + 17.3)) - 0.5;
	vec2 gw = g + tw * warp * 2.0;
	int k = kind(gw);
	if (k == 0) {
		k = base;  // a borda torta não pode abrir buraco para uma casa fechada
	}
	vec3 color;
	if (is_path(k)) {
		// calçamento: pedras arredondadas (células) no espaço dos pixels, achatadas como o chão isométrico
		vec2 q = vec2(px.x / 6.5, px.y / 3.4);
		vec2 qi = floor(q);
		float d1 = 9.0;
		float d2 = 9.0;
		vec2 best = vec2(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = qi + vec2(float(x), float(y));
				vec2 p = c + vec2(hash(c), hash(c + 5.1)) * 0.8 + 0.1;
				float d = length(q - p);
				if (d < d1) {
					d2 = d1;
					d1 = d;
					best = c;
				} else if (d < d2) {
					d2 = d;
				}
			}
		}
		int tone = int(floor(hash(best + 3.3) * 4.99));
		color = path_ramp[tone];
		if (d2 - d1 < 0.14) {
			color *= joint_dark;
		}
		// beirada: perto de uma casa que não é caminho, a pedra escurece
		float e = 0.09;
		bool rim = !is_path(max(kind(gw + vec2(e, 0.0)), 1)) || !is_path(max(kind(gw - vec2(e, 0.0)), 1))
				|| !is_path(max(kind(gw + vec2(0.0, e)), 1)) || !is_path(max(kind(gw - vec2(0.0, e)), 1));
		if (rim) {
			color *= rim_dark;
		}
		float gl = texture(glow, (g + 0.5) / map_size).r;
		color = mix(color, color * 0.6 + glow_color * 0.7, clamp(gl * glow_strength, 0.0, 1.0));
	} else {
		// pátio misturado: manchas grandes de lajes, grama e terra, cada uma com a sua textura
		float tone_n = fbm(vec2(g.x - g.y, (g.x + g.y) * 2.0) * 0.45);
		int tone = clamp(int(floor(tone_n * 6.0 - 0.6)), 0, 4);
		float zone = fbm(g * 0.55 + 21.0);
		float zone2 = fbm(g * 0.55 + 77.0);
		vec2 pf = vec2(px.x / 2.0, px.y);
		float grain = hash(floor(pf));
		if (zone > 1.0 - slab_share) {
			// lajes em fileiras desencontradas
			color = floor_ramp[tone];
			vec2 sl = g / slab;
			float row = floor(sl.y);
			float uu = sl.x + 0.5 * mod(row, 2.0);
			vec2 f = vec2(fract(uu), fract(sl.y));
			color *= 0.9 + 0.2 * hash(vec2(floor(uu), row));
			if (f.x < 0.07 || f.y < 0.1) {
				color *= joint_dark;
			}
		} else if (zone2 > 1.0 - grass_share) {
			// grama: tons em manchas e fiapos de 2 pixels em pé
			color = grass_ramp[tone];
			if (grain > 0.86) {
				color = grass_ramp[min(tone + 1, 4)];
			} else if (grain < 0.08) {
				color = grass_ramp[max(tone - 1, 0)];
			}
		} else {
			// terra com pedrinhas
			color = dirt_ramp[tone];
			if (grain > 0.95) {
				color = floor_ramp[min(tone + 2, 4)];
			} else if (grain < 0.1) {
				color *= 0.85;
			}
		}
		if (fbm(g * 0.8 + 40.0) > 1.0 - moss_amount) {
			color = mix(color, moss_color, 0.35);
		}
		float gl = texture(glow, (g + 0.5) / map_size).r;
		color += glow_color * gl * glow_strength * 0.25;
	}
	// grade só perto do mouse: borda da casa de verdade (sem o ruído)
	vec2 fc = fract(g + 0.5);
	float edge = min(min(fc.x, 1.0 - fc.x), min(fc.y, 1.0 - fc.y));
	ivec2 cell = ivec2(floor(g + 0.5));
	float near = 1.0 - smoothstep(grid_radius * 0.4, grid_radius, distance(vec2(cell), cursor));
	if (edge < 0.035) {
		color *= 1.0 - grid_shade * near;
	}
	ALBEDO = color;
}
