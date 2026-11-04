shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

// Bloco de muralha (`FortressWalls`): os lados recebem a textura da muralha vista de frente (`face`, um texel = um
// pixel da arte), presa ao mundo para emendar de um bloco ao outro; o topo é pedra lisa. Luz da frente pela esquerda:
// o lado esquerdo na tela (normal +z) é mais claro que o direito (normal +x).

uniform sampler2D face : filter_nearest, repeat_enable;
// pixels da arte por unidade do mundo: na horizontal de um lado (casa de 48 = 24 por lado) e na vertical
uniform float px_along = 24.0;
uniform float px_up = 29.4;
uniform float left_light = 0.95;
uniform float right_light = 0.68;
uniform vec3 top_color = vec3(0.24, 0.25, 0.26);

varying vec3 world;
varying vec3 wnormal;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ivec2 size = textureSize(face, 0);
	if (wnormal.y > 0.5) {
		ALBEDO = top_color;
	} else {
		bool left = abs(wnormal.z) > abs(wnormal.x);
		float along = left ? world.x : -world.z;
		int u = int(floor(along * px_along));
		int v = int(floor(world.y * px_up));
		u = ((u % size.x) + size.x) % size.x;
		v = size.y - 1 - (((v % size.y) + size.y) % size.y);
		vec3 c = texelFetch(face, ivec2(u, v), 0).rgb;
		ALBEDO = c * (left ? left_light : right_light);
	}
}
