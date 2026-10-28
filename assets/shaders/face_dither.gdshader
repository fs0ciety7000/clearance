// Plaque visage seule (BOOTH_SCENE §10.3) : matériau de la pièce source `Face`
// du rig. En jeu, la plaque est fusionnée avec les autres pièces de l'acteur
// et rendue par `chr_parts.gdshader` (M10, BOOTH_SCENE §18) ; ce shader reste
// le rendu de référence (`PassengerRig.merge_parts = false`).
// Opaque + alpha scissor : le visage dessine seulement ses marques, la peau est la tête.
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#include "res://assets/shaders/face_dither.gdshaderinc"

// Courbure du quad pour épouser la tête (VERTEX.z -= k * r²).
uniform float curvature = 4.0;

void vertex() {
	VERTEX.z -= curvature * (VERTEX.x * VERTEX.x + VERTEX.y * VERTEX.y);
}

void fragment() {
	vec4 face = face_shade(UV);
	ALBEDO = face.rgb;
	ROUGHNESS = 0.6;
	ALPHA = face.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
