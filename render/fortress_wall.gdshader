shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Bloco de muralha e saia da plataforma (`FortressWalls`). A textura da parede é vista de frente (`face`, um texel = um
// pixel da arte). Num lado do bloco, o texel anda 1 coluna a cada 2 pixels da tela na horizontal, e a linha sobe 1
// pixel a cada 2 (o 2:1 da câmera). Por isso a textura é presa ao mundo: `px_along` pixels da arte por unidade ao
// longo do lado e `px_up` por unidade na vertical. Assim ela emenda de um bloco para o outro.
//
// Luz por face (a luz vem da frente pela esquerda):
// - o lado que olha para +z (esquerda-baixo na tela) é o iluminado;
// - o topo é o meio-tom;
// - o lado que olha para +x (direita-baixo) fica na sombra azul-violeta;
// - a quina entre o topo e cada lado ganha uma linha clara de 1 pixel da arte.

uniform sampler2D face : filter_nearest, repeat_enable;
uniform float px_along = 24.0;
uniform float px_up = 29.4;
uniform vec3 left_tint = vec3(1.0, 0.98, 0.92);
uniform vec3 top_tint = vec3(0.78, 0.80, 0.88);
uniform vec3 right_tint = vec3(0.55, 0.56, 0.72);
uniform float edge_light = 1.35;

varying vec3 world;
varying vec3 wnormal;
varying float top_y;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	top_y = (MODEL_MATRIX * vec4(0.0, 0.5, 0.0, 1.0)).y;
}

vec3 texel(int u, int v) {
	ivec2 size = textureSize(face, 0);
	u = ((u % size.x) + size.x) % size.x;
	v = ((v % size.y) + size.y) % size.y;
	return texelFetch(face, ivec2(u, size.y - 1 - v), 0).rgb;
}

void fragment() {
	if (wnormal.y > 0.5) {
		// topo: a mesma pedra, deitada no losango (colunas e linhas em pixels da arte do topo)
		int u = int(floor((world.x - world.z) * px_along));
		int v = int(floor((world.x + world.z) * px_along * 0.5));
		ALBEDO = texel(u, v) * top_tint;
	} else {
		bool left = abs(wnormal.z) > abs(wnormal.x);
		float along = left ? world.x : -world.z;
		int u = int(floor(along * px_along));
		int v = int(floor(world.y * px_up));
		vec3 c = texel(u, v) * (left ? left_tint : right_tint);
		// quina: a linha de pixel da arte logo abaixo do topo
		if (top_y - world.y < 1.0 / px_up) {
			c *= edge_light;
		}
		ALBEDO = c;
	}
}
