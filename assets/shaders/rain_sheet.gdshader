// Pluie de condensation du hall (BOOTH_SCENE §6, LORE §3 : elle ruisselle des
// conduites de recyclage). M9 : toutes les nappes dans UN maillage
// (`booth_rain.res`), paramètres par sommet : UV2.x = vitesse, UV2.y = graine,
// COLOR.a = intensité, COLOR.b × 512 = colonnes, COLOR.r × 8 = rang de la
// nappe. Additif, couleur `world.rain`.
// Qualité (BoothQuality) : `layers` = nombre de nappes dessinées (les autres
// sont repliées en un point dans le vertex shader : aucun pixel calculé).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.306, 0.345, 0.408, 1.0);
uniform int layers = 3;
uniform float motion : hint_range(0.0, 1.0) = 1.0;

varying float v_speed;
varying float v_seed;
varying float v_columns;

float hash(float n, float seed) {
	return fract(sin(n * 91.3458 + seed * 17.13) * 47453.5453);
}

void vertex() {
	v_speed = UV2.x;
	v_seed = UV2.y;
	v_columns = COLOR.b * 512.0;
	if (floor(COLOR.r * 8.0 + 0.5) >= float(layers)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float col = floor(UV.x * v_columns);
	float h = hash(col, v_seed);
	float lane = fract(UV.x * v_columns);
	float width = smoothstep(0.5, 0.15, abs(lane - 0.5));
	float y = fract(UV.y * 2.0 - TIME * motion * v_speed * (0.7 + 0.6 * h) + h * 13.0);
	float streak = smoothstep(0.0, 0.03, y) * (1.0 - smoothstep(0.03, 0.22, y));
	float on = step(0.45, h);
	float edge = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.8, UV.y);
	ALBEDO = color.rgb;
	ALPHA = streak * width * on * COLOR.a * edge;
}
