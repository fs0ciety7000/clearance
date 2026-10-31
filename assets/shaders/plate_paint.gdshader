// Peinture stylisée des planches de cinématique (M14 §3.6, D-184, B89).
// Passe plein écran (CanvasItem) appliquée hors ligne par `tools/build_plates.gd`
// au rendu figé du décor 3D ; réutilisable en espace écran pour les figures
// rendues à l'exécution (M14 §3.5, `PlateFigureService`, phase 2).
//
// Entrées : `source` = couleur (sRGB 8 bits, alpha pour les couches MID/FIG) ;
// `gbuffer` = normale de vue en octaédrique (rg) + profondeur logarithmique (b),
// rendue par la même caméra (optionnelle : `use_gbuffer`).
// Étapes : 1) filtre de Kuwahara (4 quadrants, rayon `radius` px) ;
// 2) quantification de la luminance sur une rampe de 8 tons (`ramp`, palette
// monde + dominante de la fin), la chroma d'origine étant gardée à
// `chroma_keep` (les émissifs de marque restent lisibles) ; `band_soft` adoucit
// les marches (0 = aplats francs) ; 3) encre `ink_color` par contours de
// profondeur, de normales et (faiblement) de luminance, épaisseur `ink_width`
// px ; 4) hachures dans les deux tons les plus sombres (`hatch_alpha`, variante
// B) ; 5) grain ordonné 4×4 (`grain_alpha` ≤ 0,04) + papier (`paper_alpha`).
// Aucune source temporelle : déterministe (même entrée, même sortie).
// Les couches transparentes sont lues non prémultipliées et écrites telles
// quelles (`blend_disabled`) ; l'encre déborde d'un pixel hors de la silhouette.
shader_type canvas_item;
render_mode blend_disabled, unshaded;

// Image à peindre : uniforme nommé (ni TEXTURE ni un sampler en argument de
// fonction ne sont acceptés dans les fonctions par le compilateur de Godot 4.7).
uniform sampler2D source : filter_nearest;
uniform sampler2D gbuffer : filter_nearest;
uniform bool use_gbuffer = true;
uniform int radius : hint_range(0, 8) = 4;
uniform vec4 ramp[8];
uniform float tone_gamma = 0.8;
uniform float tone_gain = 1.0;
uniform float band_soft : hint_range(0.0, 1.0) = 0.0;
uniform float chroma_keep : hint_range(0.0, 1.0) = 0.3;
uniform vec4 ink_color = vec4(0.027, 0.031, 0.047, 1.0);
uniform float ink_alpha : hint_range(0.0, 1.0) = 0.9;
uniform float ink_width = 1.0;
uniform float depth_edge = 0.012;
uniform float normal_edge = 0.35;
uniform float luma_edge = 0.0;
uniform float hatch_alpha : hint_range(0.0, 1.0) = 0.0;
uniform float hatch_period = 6.0;
uniform float grain_alpha : hint_range(0.0, 0.04) = 0.04;
uniform float paper_alpha : hint_range(0.0, 0.1) = 0.0;
uniform bool transparent_layer = false;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float luma(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec4 src(vec2 uv) {
	vec4 c = texture(source, uv);
	if (transparent_layer && c.a > 0.0) {
		c.rgb /= c.a; // rendu 3D sur fond transparent : bords prémultipliés
	}
	return c;
}

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

vec3 kuwahara(vec2 uv, vec2 px) {
	vec3 m0 = vec3(0.0); vec3 m1 = vec3(0.0); vec3 m2 = vec3(0.0); vec3 m3 = vec3(0.0);
	vec3 s0 = vec3(0.0); vec3 s1 = vec3(0.0); vec3 s2 = vec3(0.0); vec3 s3 = vec3(0.0);
	for (int j = -radius; j <= radius; j++) {
		for (int i = -radius; i <= radius; i++) {
			vec3 c = src(uv + vec2(float(i), float(j)) * px).rgb;
			vec3 c2 = c * c;
			if (i <= 0 && j <= 0) { m0 += c; s0 += c2; }
			if (i >= 0 && j <= 0) { m1 += c; s1 += c2; }
			if (i <= 0 && j >= 0) { m2 += c; s2 += c2; }
			if (i >= 0 && j >= 0) { m3 += c; s3 += c2; }
		}
	}
	float n = float((radius + 1) * (radius + 1));
	m0 /= n; m1 /= n; m2 /= n; m3 /= n;
	float v0 = dot(abs(s0 / n - m0 * m0), vec3(1.0));
	float v1 = dot(abs(s1 / n - m1 * m1), vec3(1.0));
	float v2 = dot(abs(s2 / n - m2 * m2), vec3(1.0));
	float v3 = dot(abs(s3 / n - m3 * m3), vec3(1.0));
	vec3 best = m0;
	float bv = v0;
	if (v1 < bv) { bv = v1; best = m1; }
	if (v2 < bv) { bv = v2; best = m2; }
	if (v3 < bv) { best = m3; }
	return best;
}

vec3 oct_decode(vec2 e) {
	e = e * 2.0 - 1.0;
	vec3 n = vec3(e, 1.0 - abs(e.x) - abs(e.y));
	if (n.z < 0.0) {
		n.xy = (1.0 - abs(n.yx)) * vec2(n.x >= 0.0 ? 1.0 : -1.0, n.y >= 0.0 ? 1.0 : -1.0);
	}
	return normalize(n);
}

// Intensité de contour (0..1) autour de `uv` : profondeur, normales, alpha, luminance.
float edge_at(vec2 uv, vec2 px) {
	float e = 0.0;
	vec2 o = px * ink_width;
	vec4 c = src(uv);
	vec4 cx = src(uv + vec2(o.x, 0.0));
	vec4 cy = src(uv + vec2(0.0, o.y));
	vec4 cxn = src(uv - vec2(o.x, 0.0));
	vec4 cyn = src(uv - vec2(0.0, o.y));
	if (transparent_layer) {
		e = max(e, smoothstep(0.2, 0.6, max(abs(cx.a - cxn.a), abs(cy.a - cyn.a))));
	}
	if (luma_edge > 0.0) {
		float lx = abs(luma(cx.rgb) - luma(cxn.rgb));
		float ly = abs(luma(cy.rgb) - luma(cyn.rgb));
		e = max(e, smoothstep(luma_edge, luma_edge * 2.5, max(lx, ly)));
	}
	if (use_gbuffer) {
		vec4 g = texture(gbuffer, uv);
		vec4 gx = texture(gbuffer, uv + vec2(o.x, 0.0));
		vec4 gy = texture(gbuffer, uv + vec2(0.0, o.y));
		vec4 gxn = texture(gbuffer, uv - vec2(o.x, 0.0));
		vec4 gyn = texture(gbuffer, uv - vec2(0.0, o.y));
		// Profondeur : différence seconde (ignore les pentes régulières du sol).
		float dd = max(abs(gx.b + gxn.b - 2.0 * g.b), abs(gy.b + gyn.b - 2.0 * g.b));
		e = max(e, smoothstep(depth_edge, depth_edge * 2.0, dd));
		vec3 n = oct_decode(g.rg);
		float nd = max(max(1.0 - dot(n, oct_decode(gx.rg)), 1.0 - dot(n, oct_decode(gxn.rg))),
				max(1.0 - dot(n, oct_decode(gy.rg)), 1.0 - dot(n, oct_decode(gyn.rg))));
		e = max(e, smoothstep(normal_edge, normal_edge * 1.6, nd));
		// Fond vide (pas de géométrie) : contour de silhouette.
		float empty = step(0.999, g.b);
		float empty_n = max(max(step(0.999, gx.b), step(0.999, gxn.b)), max(step(0.999, gy.b), step(0.999, gyn.b)));
		e = max(e, abs(empty_n - empty));
	}
	return clamp(e, 0.0, 1.0);
}

vec3 tone(vec3 c, vec2 frag, out float index) {
	float l = pow(clamp(luma(c) * tone_gain, 0.0, 1.0), tone_gamma);
	float bayer = (BAYER[int(mod(frag.y, 4.0)) * 4 + int(mod(frag.x, 4.0))] + 0.5) / 16.0 - 0.5;
	float x = clamp(l * 8.0 + bayer * band_soft, 0.0, 7.999);
	float i = floor(x);
	float f = fract(x);
	vec3 a = ramp[int(i)].rgb;
	vec3 b = ramp[int(min(i + 1.0, 7.0))].rgb;
	// band_soft : transition douce sur la largeur `band_soft` autour de chaque marche.
	float t = band_soft > 0.0 ? smoothstep(1.0 - band_soft, 1.0, f) : 0.0;
	vec3 r = mix(a, b, t);
	index = i;
	// Chroma gardée : teinte d'origine portée à la luminance du ton.
	float lc = max(luma(c), 1e-3);
	vec3 chroma = clamp(c / lc, 0.0, 4.0) * luma(r);
	float sat = clamp((max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b))) / max(max(c.r, max(c.g, c.b)), 1e-3), 0.0, 1.0);
	return mix(r, clamp(chroma, 0.0, 1.0), chroma_keep * sat);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(source, 0));
	vec2 frag = floor(UV / px);
	vec4 base = src(UV);
	vec3 col = radius > 0 ? kuwahara(UV, px) : base.rgb;
	float index = 0.0;
	col = tone(col, frag, index);
	// Hachures (variante B) : diagonales dans les deux tons les plus sombres, croisées dans le plus sombre.
	if (hatch_alpha > 0.0) {
		float d1 = step(fract((frag.x + frag.y) / hatch_period), 1.0 / hatch_period);
		float d2 = step(fract((frag.x - frag.y) / hatch_period), 1.0 / hatch_period);
		float h = index < 0.5 ? max(d1, d2) : (index < 1.5 ? d1 : 0.0);
		col = mix(col, ink_color.rgb, h * hatch_alpha);
	}
	float e = edge_at(UV, px);
	col = mix(col, ink_color.rgb, e * ink_alpha);
	float bayer = (BAYER[int(mod(frag.y, 4.0)) * 4 + int(mod(frag.x, 4.0))] + 0.5) / 16.0 - 0.5;
	col += bayer * grain_alpha;
	if (paper_alpha > 0.0) {
		float paper = value_noise(frag / 3.0) * 0.6 + value_noise(frag / 37.0) * 0.4 - 0.5;
		col += paper * paper_alpha;
	}
	float alpha = 1.0;
	if (transparent_layer) {
		// Alpha du calque + liseré d'encre qui déborde légèrement.
		alpha = max(base.a, e * ink_alpha * step(0.01, max(max(src(UV + vec2(px.x * ink_width, 0.0)).a,
				src(UV - vec2(px.x * ink_width, 0.0)).a), max(src(UV + vec2(0.0, px.y * ink_width)).a,
				src(UV - vec2(0.0, px.y * ink_width)).a))));
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), alpha);
}
