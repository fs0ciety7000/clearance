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
// M14 (VH-7, VH-8, D-190) — états du Hall par acte, sans draw de plus : les
// variantes sont cuites dans le maillage (graine `COLOR.a`, hors vitrages) et
// celles qui ne servent pas sont repliées en un point dans `vertex()` :
//   `graffiti_state` : 0 luciole (graine 9) · 1 recouverte de peinture grise
//   (200) · 2 réapparue en grand (201) · 3 en grand + deux traits (202) ·
//   4 sous verre, « mémoire » (9 + cadre 203) ;
//   `departures_status` (écran des départs : graines 220–226 ; statut de la
//   ligne TRANSIT·7, 220 et 210–212) : 0 À L'HEURE
//   · 1 RETARD · 2 DERNIÈRE ROTATION (ligne en ambre) · 3 écran éteint.
// `flicker` (M11, QA-047, réglage « Scintillement holographique » /
// `Settings.holo_flicker`, D-109) : 0 = néons instables sans chute (lueur
// pleine et fixe) et écrans holo sans scanlines ni balayage ; les lueurs et la
// respiration très lente des vitrages (mode 3, < 0,05 Hz) restent.
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform float fx_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float flicker : hint_range(0.0, 1.0) = 1.0;
uniform float energy_scale = 1.0;
uniform int graffiti_state : hint_range(0, 4) = 0;
uniform int departures_status : hint_range(0, 3) = 0;
uniform vec4 departures_amber : source_color = vec4(1.0, 0.72, 0.25, 1.0);

varying vec3 world_pos;
varying float state_gain;
varying vec3 state_tint;

bool is_seed(float seed, float value) {
	return abs(seed - value) < 0.5;
}

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
	state_gain = 1.0;
	state_tint = vec3(1.0);
	float mode = floor(UV2.y + 0.5);
	if (mode != 3.0) {
		float seed = floor(COLOR.a * 255.0 + 0.5);
		bool show = true;
		if (is_seed(seed, 9.0)) {
			show = graffiti_state == 0 || graffiti_state == 4;
		} else if (is_seed(seed, 200.0)) {
			show = graffiti_state == 1;
		} else if (is_seed(seed, 201.0)) {
			show = graffiti_state == 2 || graffiti_state == 3;
		} else if (is_seed(seed, 202.0)) {
			show = graffiti_state == 3;
		} else if (is_seed(seed, 203.0)) {
			show = graffiti_state == 4;
		} else if (is_seed(seed, 210.0)) {
			show = departures_status == 0;
		} else if (is_seed(seed, 211.0)) {
			show = departures_status == 1;
		} else if (is_seed(seed, 212.0)) {
			show = departures_status == 2;
			state_tint = departures_amber.rgb;
		} else if (is_seed(seed, 220.0) && departures_status == 2) {
			state_tint = departures_amber.rgb;
		}
		if (departures_status == 3 && seed >= 210.0 && seed <= 226.0) {
			// Écran éteint : textes repliés, fonds (225, 226) presque noirs.
			show = show && seed >= 225.0;
			state_gain = 0.06;
		}
		if (!show) {
			VERTEX = vec3(0.0);
		}
	}
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
	ALBEDO = COLOR.rgb * state_tint * e * state_gain;
}
