// Silhouettes du Hall (BOOTH_SCENE §11, §20) : file d'attente et Gardes.
// Remplissage sombre teinté par la couleur d'instance (MultiMesh `use_colors`),
// rim teal/rose, léger balancement de vertex (±1 cm à 0,2 Hz) à phase propre.
// M14 (VH-1, VH-4, D-187, D-188) — données d'instance (`use_custom_data`) :
//   x = marche (0 à l'arrêt → 1 en mouvement : pas de ±2 cm à 2 Hz),
//   y = phase propre (s), z = mode (0 passager · 1 Garde · 2 Arbitre ·
//   3 civil posté, monde D du J31 : ni brassard ni teinte d'Arbitre),
//   w = assombrissement (coupure EV-05, grève : 0 → 1).
// `motion` = 0 (`reduce_motion`, DS §5) : ni balancement au repos ni pas ; la
// translation reste (c'est une information). Marque émissive (`UV.x` = 1 :
// brassard jaune de la Garde) ; l'Arbitre n'en porte pas.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 fill : source_color = vec4(0.063, 0.075, 0.106, 1.0);
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.9;
uniform float motion : hint_range(0.0, 1.0) = 1.0;
uniform vec4 mark_color : source_color = vec4(1.0, 0.902, 0.0, 1.0);
uniform float mark_energy = 0.55;
uniform vec4 arbiter_tint : source_color = vec4(0.72, 0.73, 0.76, 1.0);

varying vec3 tint;
varying float mark;
varying float dim;
varying float arbiter;

void vertex() {
	float phase = INSTANCE_CUSTOM.y + float(INSTANCE_ID) * 1.618;
	float h = clamp(VERTEX.y, 0.0, 2.0);
	float sway = sin(TIME * 1.2566 + phase) * 0.01 * h;
	VERTEX.x += sway * motion;
	// Pas : rebond vertical à 2 Hz pendant le déplacement seulement.
	VERTEX.y += abs(sin(TIME * 6.2832 + phase)) * 0.02 * INSTANCE_CUSTOM.x * motion;
	tint = COLOR.rgb;
	float mode = floor(INSTANCE_CUSTOM.z + 0.5);
	arbiter = step(1.5, mode) * step(mode, 2.5);
	mark = UV.x * step(0.5, mode) * step(mode, 1.5);
	dim = clamp(INSTANCE_CUSTOM.w, 0.0, 1.0);
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
	vec3 base = mix(fill.rgb, tint, mix(0.35, 0.6, arbiter));
	base = mix(base, base * arbiter_tint.rgb + arbiter_tint.rgb * 0.18, arbiter);
	vec3 col = base + rim * fresnel * rim_strength * (1.0 - 0.75 * dim);
	col = mix(col * (1.0 - 0.6 * dim), mark_color.rgb * mark_energy * (1.0 - 0.7 * dim), mark);
	ALBEDO = col;
}
