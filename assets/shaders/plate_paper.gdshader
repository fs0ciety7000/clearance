// Grain de papier des planches de cinématique, posé **à l'exécution** (M14
// §3.6, D-195 : traitement B « lavis gravé » ; le papier n'est pas cuit dans
// les images pour tenir le budget disque). Matériau d'un `TextureRect` de
// couche (`BG`, `MID`, `FIG`, `LIT`) du `CinematicScreen` (lot D) :
// `PlatePaintStyle.paper_material(origin_px, size_px, Settings.fx_intensity)`.
// Même motif que `plate_paint.gdshader` (bruit de valeur à 3 px et 37 px de
// planche), calé sur les pixels de la planche : `origin_px` = coin haut-gauche
// de la couche dans la planche 2048×1152, `size_px` = sa taille.
// Statique (aucune source temporelle, rien ne bouge : DS §5, `reduce_motion`
// sans effet) ; `paper_alpha` = 0 → texture inchangée.
shader_type canvas_item;

uniform vec2 origin_px = vec2(0.0);
uniform vec2 size_px = vec2(2048.0, 1152.0);
uniform float paper_alpha : hint_range(0.0, 0.1) = 0.05;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec4 c = COLOR; // (déjà multipliée par TEXTURE dans un shader canvas_item)
	if (paper_alpha > 0.0) {
		vec2 frag = floor(origin_px + UV * size_px);
		float paper = value_noise(frag / 3.0) * 0.6 + value_noise(frag / 37.0) * 0.4 - 0.5;
		c.rgb = clamp(c.rgb + paper * paper_alpha, 0.0, 1.0);
	}
	COLOR = c;
}
