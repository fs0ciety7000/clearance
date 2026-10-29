// Hologrammes et voiles additifs du guichet (M9) : logo du Consortium (jaune,
// marque), champs des barrières magnétiques de la file, halo de la ville de
// l'Anneau. Un seul matériau additif.
// Par sommet : COLOR.rgb = teinte, COLOR.a = opacité, UV = repère local
// (0..1), UV2.x = énergie, UV2.y = mode :
//   0 dégradé vertical · 1 hologramme (scanlines, scintillement léger)
//   · 2 champ magnétique (ondes horizontales) · 3 reflet (bandes diagonales,
//   réservé) · 4 halo (dégradé doux vers le haut).
// `fx_intensity` : 0 = figé, sans scanlines. `flicker` (M11, réglage
// « Scintillement holographique », D-109) : 0 = ni scintillement, ni
// scanlines, ni défilement des ondes — les lueurs restent (`fx_intensity`). Sans brouillard : un additif
// brouillé ajouterait la couleur du brouillard sur toute sa surface.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float fx_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 1.0;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	float mode = floor(UV2.y + 0.5);
	float a = COLOR.a;
	vec2 uv = UV;
	if (mode == 0.0) {
		a *= smoothstep(1.0, 0.2, uv.y);
	} else if (mode == 1.0) {
		float motion = fx_intensity * flicker;
		float scan = mix(1.0, 0.55 + 0.45 * step(0.5, fract(FRAGCOORD.y / 3.0)), motion);
		float flick = 1.0 - 0.15 * motion * step(0.9, hash11(floor(TIME * 1.5)));
		float pulse = 0.85 + 0.15 * sin(TIME * 1.1) * motion;
		a *= scan * flick * pulse;
	} else if (mode == 2.0) {
		float core = smoothstep(0.5, 0.0, abs(uv.y - 0.5));
		float wave = 0.65 + 0.35 * sin(uv.x * 40.0 - TIME * 3.0 * fx_intensity * flicker);
		a *= core * core * wave;
	} else if (mode == 3.0) {
		float d = uv.x * 0.8 - uv.y * 0.6;
		float band = smoothstep(0.08, 0.0, abs(fract(d * 1.7) - 0.5)) * 0.7 + 0.3;
		a *= band * smoothstep(0.0, 0.25, uv.y) * smoothstep(1.0, 0.6, uv.y);
	} else {
		a *= smoothstep(0.0, 0.35, uv.y) * smoothstep(1.0, 0.45, uv.y);
	}
	ALBEDO = COLOR.rgb * UV2.x;
	ALPHA = clamp(a, 0.0, 1.0);
}
