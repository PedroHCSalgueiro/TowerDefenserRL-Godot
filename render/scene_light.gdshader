shader_type canvas_item;
render_mode blend_mul, unshaded;

// Luz por cima do 3D (`SceneLight`): a cena inteira é multiplicada por uma luz ambiente fria, com os cantos mais
// escuros, e cada fonte (tocha, entrada, núcleo) devolve a cor dela em volta. Fica abaixo da interface.

const int MAX_LIGHTS = 48;
uniform vec3 ambient = vec3(0.7, 0.74, 0.86);
uniform float vignette = 0.45;
uniform int count = 0;
// tamanho da tela em pixels (o UV do retângulo começa no canto de cima à esquerda, como a projeção da câmera)
uniform vec2 view_size = vec2(1.0, 1.0);
// x, y (pixels da tela), raio x, raio y
uniform vec4 lights[MAX_LIGHTS];
// r, g, b, força
uniform vec4 colors[MAX_LIGHTS];

void fragment() {
	vec2 p = UV * view_size;
	vec2 c = (UV - 0.5) * 2.0;
	vec3 l = ambient * (1.0 - vignette * dot(c, c) * 0.5);
	for (int i = 0; i < MAX_LIGHTS; i++) {
		if (i >= count) {
			break;
		}
		vec2 d = (p - lights[i].xy) / lights[i].zw;
		l += colors[i].rgb * colors[i].a * exp(-dot(d, d));
	}
	COLOR = vec4(min(l, vec3(1.0)), 1.0);
}
