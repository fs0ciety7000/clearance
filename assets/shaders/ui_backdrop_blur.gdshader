// Flou du décor 3D derrière les panneaux posés sur la vitre (DS §5 règle 5) :
// garantit la lisibilité du texte quel que soit le décor. Pas un effet holo
// (non soumis à fx_intensity) : c'est un support de lecture.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 6.0) = 3.0;

void fragment() {
	COLOR = vec4(textureLod(screen_tex, SCREEN_UV, lod).rgb, 1.0);
}
