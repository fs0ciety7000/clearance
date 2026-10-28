// Vitre blindée du guichet (BOOTH_SCENE §4.2, M9) : teinte presque invisible,
// faux reflet de l'intérieur du guichet (lampe, bandes), Fresnel, gouttes
// statiques, filets de condensation qui glissent, buée du tiers bas, crasse
// des bords et rayures, scanlines très faibles. Sans texture d'écran (pas de
// copie du framebuffer : coût minimal).
// Zone dégagée autour du visage : `clear_point` (UV de la vitre) atténue tous
// les effets à 20 % (règle absolue de lisibilité, BOOTH_SCENE §4.2).
// `fx_intensity` : 1 complets (filets animés), 0,5 réduits (filets figés),
// 0 désactivés (teinte + reflet faible).
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.541, 0.592, 0.659, 0.04);
uniform vec4 reflect_color : source_color = vec4(0.62, 0.70, 0.78, 1.0);
uniform vec4 grime_color : source_color = vec4(0.16, 0.15, 0.13, 1.0);
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
	float fx = fx_intensity;
	// Reflet : deux larges bandes diagonales douces + une fine (lampe du guichet).
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

	// Filets de condensation : une colonne sur ~6 porte une goutte qui glisse
	// (2 cm/s), suivie d'une traînée fine ; figés à fx 0,5.
	float lanes = iso.x * 46.0;
	float lh = hash(vec2(floor(lanes), 5.3));
	float lane = smoothstep(0.5, 0.2, abs(fract(lanes) - 0.5));
	float anim = step(0.75, fx);
	float y = fract(uv.y * 0.7 - TIME * anim * (0.012 + 0.02 * lh) + lh * 9.0);
	float head = smoothstep(0.02, 0.0, abs(y - 0.5));
	float trail = smoothstep(0.5, 0.2, y) * step(y, 0.5) * 0.35;
	float runnel = lane * step(0.83, lh) * (head + trail);

	// Buée du tiers bas, crasse des bords (doigts autour de l'hygiaphone), rayures.
	float cond = smoothstep(0.62, 1.0, uv.y) * (0.6 + 0.4 * hash(floor(iso * 90.0)));
	float edge = max(smoothstep(0.07, 0.0, min(uv.x, 1.0 - uv.x)), smoothstep(0.88, 1.0, uv.y));
	float smudge = smoothstep(0.16, 0.0, length(vec2((uv.x - 0.333) * aspect, uv.y - 0.77))) * 0.6;
	float grime = clamp(edge + smudge, 0.0, 1.0) * (0.55 + 0.45 * hash(floor(iso * 24.0)));
	float s = iso.x * 0.35 + iso.y;
	float scratch = smoothstep(0.004, 0.0, abs(fract(s * 3.0) - 0.5) - 0.0) * step(0.93, hash(vec2(floor(s * 3.0), 1.0)))
			* step(0.6, hash(floor(iso * 6.0)));
	float scan = step(0.5, fract(FRAGCOORD.y / 3.0)) * 0.02;

	vec2 dc = vec2((uv.x - clear_point.x) * aspect, uv.y - clear_point.y);
	float m = mix(0.2, 1.0, smoothstep(clear_radius, clear_radius * 1.9, length(dc)));

	float a = tint.a
			+ reflect_alpha * band * mix(0.5, 1.0, fx) * m
			+ (drop * 0.10 + runnel * 0.12 + cond * 0.12 + grime * 0.10 + scratch * 0.08 + scan) * fx * m
			+ fresnel * 0.05;
	vec3 col = mix(tint.rgb, reflect_color.rgb, clamp(band + drop + runnel + scratch, 0.0, 1.0));
	col = mix(col, grime_color.rgb, grime * 0.7 * fx);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 0.35);
}
