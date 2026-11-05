shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Bloco de muralha, ameia e rebordo da saia (`FortressWalls`).
//
// - Faces verticais: a textura de tijolos vista de frente (`face`, um texel = um pixel da arte) é presa ao mundo no
//   2:1. Ao longo do lado ela tem `px_along` pixels da arte por unidade, e na vertical `px_up`. O UV é contínuo entre
//   blocos, sem corte a cada casa, e os tijolos ficam no tamanho original.
// - Topo: nunca a textura. É cor lisa (`top_color`) com contorno escuro de 1 pixel da arte na borda do bloco.
// - Luz da frente pela esquerda: a face que olha para +z (esquerda-baixo na tela) usa `left_tint`, e a que olha para +x
//   (direita-baixo) usa `right_tint`. A quina entre o topo e cada face ganha uma linha clara de 1 pixel da arte.

uniform sampler2D face : filter_nearest, repeat_enable;
uniform float px_along = 24.0;
uniform float px_up = 29.4;
uniform vec3 left_tint = vec3(0.92, 0.94, 1.0);
uniform vec3 right_tint = vec3(0.65, 0.68, 0.82);
uniform vec3 top_color = vec3(0.50, 0.55, 0.65);
uniform float outline_dark = 0.45;
uniform float edge_light = 1.3;

varying vec3 world;
varying vec3 wnormal;
varying vec3 lpos;
varying vec3 bscale;
varying float top_y;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	lpos = VERTEX;
	bscale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
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
		// distância até a borda do topo, em unidades do mundo (o losango de 1 casa tem 24 px da arte por lado)
		float dx = (0.5 - abs(lpos.x)) * bscale.x;
		float dz = (0.5 - abs(lpos.z)) * bscale.z;
		float px = 1.0 / px_along;
		ALBEDO = min(dx, dz) < px ? top_color * outline_dark : top_color;
	} else {
		bool left = abs(wnormal.z) > abs(wnormal.x);
		float along = left ? world.x : -world.z;
		int u = int(floor(along * px_along));
		int v = int(floor(world.y * px_up));
		vec3 c = texel(u, v) * (left ? left_tint : right_tint);
		if (top_y - world.y < 1.0 / px_up) {
			c *= edge_light;
		}
		ALBEDO = c;
	}
}
