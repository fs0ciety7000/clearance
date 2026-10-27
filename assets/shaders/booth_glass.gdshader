// Vitre du guichet, version greybox (BOOTH_SCENE §4.2) : teinte presque
// invisible, faux reflet diagonal procédural, Fresnel, quelques gouttes
// statiques, condensation du tiers bas, scanlines très faibles.
// Zone dégagée autour du visage : `clear_point` (UV de la vitre) atténue tous
// les effets à 20 % (règle absolue de lisibilité).
// `fx_intensity` : 1 complets, 0,5 réduits, 0 désactivés (teinte + reflet faible).
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.541, 0.592, 0.659, 0.04);
uniform vec4 reflect_color : source_color = vec4(0.62, 0.70, 0.78, 1.0);
uniform float reflect_alpha = 0.10;
uniform vec2 clear_point = vec2(0.5, 0.45);
uniform float clear_radius = 0.10;
// Largeur / hauteur de la vitre (distances isotropes autour du visage).
uniform float aspect = 1.714;
uniform float fx_intensity : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 iso = vec2(uv.x * aspect, uv.y);
	// Reflet : deux larges bandes diagonales douces + une fine.
	float d = uv.x * 0.9 - uv.y * 0.55;
	float band = smoothstep(0.10, 0.0, abs(d - 0.18)) * 0.8
			+ smoothstep(0.035, 0.0, abs(d - 0.31)) * 0.6
			+ smoothstep(0.16, 0.0, abs(d + 0.42)) * 0.45;
	float fresnel = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);

	// Gouttes statiques (grille hachée).
	vec2 cell = floor(iso * 38.0);
	vec2 f = fract(iso * 38.0) - 0.5;
	float h = hash(cell);
	float drop = h > 0.86 ? smoothstep(0.22, 0.12, length(f + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.4)) : 0.0;

	// Condensation du tiers bas.
	float cond = smoothstep(0.62, 1.0, uv.y) * (0.6 + 0.4 * hash(floor(iso * 90.0)));
	float scan = step(0.5, fract(FRAGCOORD.y / 3.0)) * 0.02;

	vec2 dc = vec2((uv.x - clear_point.x) * aspect, uv.y - clear_point.y);
	float m = mix(0.2, 1.0, smoothstep(clear_radius, clear_radius * 1.9, length(dc)));

	float fx = fx_intensity;
	float a = tint.a
			+ reflect_alpha * band * mix(0.5, 1.0, fx) * m
			+ (drop * 0.10 + cond * 0.12 + scan) * fx * m
			+ fresnel * 0.05;
	ALBEDO = mix(tint.rgb, reflect_color.rgb, clamp(band + drop, 0.0, 1.0));
	ALPHA = clamp(a, 0.0, 0.35);
}
