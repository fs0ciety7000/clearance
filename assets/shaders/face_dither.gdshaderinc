// Plaque visage du passager (BOOTH_SCENE §10.3, ARCHITECTURE §8 bis.5) — code
// commun à `face_dither.gdshader` (plaque seule) et `chr_parts.gdshader`
// (pièces fusionnées de l'acteur, M10).
// Atlas 4×4 (cellules 128 px) : lignes 0–1 = yeux + sourcils, 2–3 = bouches.
// Canaux : R = encre (sourcils, paupières, bouche), G = iris, B = pupille, A = couverture
// (couverture sans canal = blanc de l'œil / dents → `sclera_color`).
// La moitié haute du quad lit une cellule « yeux », la moitié basse une cellule « bouche ».
// Transition entre expressions et bords : dithering ordonné Bayer 4×4 en espace UV,
// quantifié à 64×64 par cellule (stable quand la tête bouge, pas de scintillement écran).

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform vec4 ink_color : source_color = vec4(0.06, 0.05, 0.06, 1.0);
uniform vec4 iris_color_left : source_color = vec4(0.29, 0.18, 0.11, 1.0);
uniform vec4 iris_color_right : source_color = vec4(0.29, 0.18, 0.11, 1.0);
uniform vec4 sclera_color : source_color = vec4(0.80, 0.79, 0.76, 1.0);
uniform int eyes_from = 0;
uniform int eyes_to = 0;
uniform int mouth_from = 8;
uniform int mouth_to = 8;
// 0 = cellule « from », 1 = cellule « to » (fondu par seuil de dither).
uniform float blend : hint_range(0.0, 1.0) = 1.0;
// Décalage des pupilles (unités de cellule, ±0,04 max) : finit le regard.
uniform vec2 pupil_offset = vec2(0.0);
// Épaisseur des lèvres (1 = fines, >1 = pleines).
uniform float lip_scale = 1.0;

const float BAYER[16] = float[16](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);
const float GRID = 64.0;

vec4 face_sample_cell(int cell, vec2 cuv) {
	vec2 origin = vec2(float(cell % 4), float(cell / 4)) * 0.25;
	vec2 q = (floor(clamp(cuv, 0.0, 0.999) * GRID) + 0.5) / GRID;
	return texture(atlas, origin + q * 0.25);
}

// Couleur (rgb) et couverture tramée (a = 0 ou 1) de la plaque en `uv`.
vec4 face_shade(vec2 uv) {
	bool top = uv.y < 0.5;
	vec2 cuv = vec2(uv.x, top ? uv.y * 2.0 : (uv.y - 0.5) * 2.0);
	if (!top) {
		cuv.y = 0.44 + (cuv.y - 0.44) / lip_scale;
	}
	vec2 q = floor(clamp(cuv, 0.0, 0.999) * GRID);
	float threshold = (BAYER[int(mod(q.y, 4.0)) * 4 + int(mod(q.x, 4.0))] + 0.5) / 16.0;
	bool use_to = threshold < blend;
	int cell = top ? (use_to ? eyes_to : eyes_from) : (use_to ? mouth_to : mouth_from);

	vec4 base = face_sample_cell(cell, cuv);
	vec4 shifted = top ? face_sample_cell(cell, cuv - pupil_offset) : base;
	float coverage = base.a;
	float ink = base.r;
	// Iris et pupille suivent le regard mais restent dans l'œil (masque `base.a`).
	float iris = shifted.g * coverage * (1.0 - ink);
	float pupil = shifted.b * coverage * (1.0 - ink);

	vec3 iris_col = uv.x < 0.5 ? iris_color_left.rgb : iris_color_right.rgb;
	vec3 col = mix(sclera_color.rgb, iris_col, iris);
	col = mix(col, ink_color.rgb, max(ink, pupil));
	// Bords tramés : la couverture est seuillée par la matrice de Bayer.
	return vec4(col, coverage > threshold * 0.8 + 0.1 ? 1.0 : 0.0);
}
