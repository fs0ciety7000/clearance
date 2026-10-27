// Nappe de pluie (BOOTH_SCENE §6) : quad à traînées défilantes, additif,
// couleur `world.rain`. 3 nappes à vitesses différentes, au-delà de l'auvent.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.306, 0.345, 0.408, 1.0);
uniform float speed = 1.6;
uniform float columns = 140.0;
uniform float intensity = 0.35;
uniform float seed = 0.0;

float hash(float n) {
	return fract(sin(n * 91.3458 + seed * 17.13) * 47453.5453);
}

void fragment() {
	float col = floor(UV.x * columns);
	float h = hash(col);
	float lane = fract(UV.x * columns);
	float width = smoothstep(0.5, 0.15, abs(lane - 0.5));
	float y = fract(UV.y * 2.0 - TIME * speed * (0.7 + 0.6 * h) + h * 13.0);
	float streak = smoothstep(0.0, 0.03, y) * (1.0 - smoothstep(0.03, 0.22, y));
	float on = step(0.45, h);
	float edge = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.8, UV.y);
	ALBEDO = color.rgb;
	ALPHA = streak * width * on * intensity * edge;
}
