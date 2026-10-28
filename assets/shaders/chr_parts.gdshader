// Pièces d'apparence fusionnées d'un passager (M10, BOOTH_SCENE §18,
// ARCHITECTURE §8 bis.2) : un seul maillage skinné par acteur réunit plaque
// visage, nez, oreilles, cheveux, coiffe, visière, détails de tenue,
// accessoires, implants, fil magenta, brassard et liasse de papiers
// (`PassengerRig.rebuild_parts`). Chaque pièce garde son rendu d'origine,
// porté par sommet :
//   CUSTOM0 = albédo linéaire (rgb) + mode (a) ;
//   CUSTOM1 = émission linéaire (rgb) ; UV2 = (rugosité, métal).
// Modes : 0 pièce unie (= passenger_body.gdshader : rim de Fresnel bicolore),
// 1 plaque visage (= face_dither.gdshader, n'ombre pas), 2 non éclairé
// (tatouage holo), 3 papiers (pièce unie visible si `papers_visible`).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://assets/shaders/face_dither.gdshaderinc"

uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.7;
uniform bool papers_visible = false;

varying vec3 v_albedo;
varying vec3 v_emission;
varying vec2 v_rough_metal;
varying flat int v_mode;

void vertex() {
	v_albedo = CUSTOM0.rgb;
	v_emission = CUSTOM1.rgb;
	v_rough_metal = UV2;
	v_mode = int(round(CUSTOM0.a));
	// Pièce masquée : triangles dégénérés (aucun fragment, aucune ombre).
	if ((v_mode == 3 && !papers_visible) || (v_mode == 1 && IN_SHADOW_PASS)) {
		VERTEX = vec3(0.0);
	}
}

void fragment() {
	float alpha = 1.0;
	if (v_mode == 1) {
		vec4 face = face_shade(UV);
		ALBEDO = face.rgb;
		ROUGHNESS = 0.6;
		alpha = face.a;
	} else if (v_mode == 2) {
		// Équivalent d'un matériau non éclairé : ni diffus ni spéculaire.
		ALBEDO = vec3(0.0);
		SPECULAR = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = v_albedo;
	} else {
		ALBEDO = v_albedo;
		ROUGHNESS = v_rough_metal.x;
		METALLIC = v_rough_metal.y;
		float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
		EMISSION = rim * fresnel * rim_strength + v_emission;
	}
	ALPHA = alpha;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
