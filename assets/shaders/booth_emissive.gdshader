// Émissifs fusionnés du guichet (BOOTH_SCENE §5–§6, M9) : néons, lettres des
// enseignes (TextMesh cuits), écrans, fenêtres de la ville de l'Anneau, LED
// de l'hygiaphone, graffiti luciole. Un seul matériau, non éclairé.
// Par sommet : COLOR.rgb = teinte, COLOR.a = graine, UV2.x = énergie
// (> 1 : déclenche le glow), UV2.y = mode :
//   0 fixe · 1 néon instable (chute brève, ≤ 2 Hz, jamais dans la fenêtre
//   utile) · 2 écran holo (scanlines + balayage lent, UV = repère de l'écran)
//   · 3 vitrages de la ville (grille de fenêtres en repère monde, allumées
//   au hasard, moyennée au loin contre le moiré ; respiration très lente).
// `fx_intensity` (Settings, DS §5) : 0 = tout fixe.
// `flicker` (M11, QA-047, réglage « Scintillement holographique » /
// `Settings.holo_flicker`, D-109) : 0 = néons instables sans chute (lueur
// pleine et fixe) et écrans holo sans scanlines ni balayage ; les lueurs et la
// respiration très lente des vitrages (mode 3, < 0,05 Hz) restent.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float fx_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 1.0;
uniform float energy_scale = 1.0;

varying vec3 world_pos;

float hash11(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float e = UV2.x * energy_scale;
	float mode = floor(UV2.y + 0.5);
	float seed = COLOR.a * 255.0;
	if (mode == 1.0) {
		float h = hash11(floor(TIME * 2.0) + seed * 3.1);
		e *= 1.0 - fx_intensity * flicker * 0.6 * step(0.88, h);
	} else if (mode == 2.0) {
		float motion = fx_intensity * flicker;
		float scan = mix(1.0, 0.8 + 0.2 * step(0.5, fract(FRAGCOORD.y / 3.0)), motion);
		float sweep = smoothstep(0.08, 0.0, abs(fract(UV.y + TIME * 0.06 * motion + seed * 0.01) - 0.5));
		e *= scan * (1.0 + 0.35 * sweep * motion);
	} else if (mode == 3.0) {
		vec2 g = vec2((world_pos.x + world_pos.z) * 0.55, world_pos.y * 0.75);
		vec2 cell = floor(g);
		vec2 f = fract(g);
		float frame = step(0.2, f.x) * step(f.x, 0.8) * step(0.25, f.y) * step(f.y, 0.75);
		float h = hash21(cell + vec2(seed, 0.0));
		float lit = step(0.66, h) * frame * (0.55 + 0.9 * fract(h * 7.31));
		float aa = clamp(1.6 - 1.5 * max(fwidth(g).x, fwidth(g).y), 0.0, 1.0);
		e *= mix(0.22, 0.03 + lit, aa) * (1.0 - 0.15 * fx_intensity * (0.5 + 0.5 * sin(TIME * 0.3 + h * 20.0)));
	}
	ALBEDO = COLOR.rgb * e;
}
