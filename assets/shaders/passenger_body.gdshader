// Matériau des pièces du passager greybox (BOOTH_SCENE §5.2, ASSETS §7) :
// couleur unie + rim de Fresnel bicolore (teal à gauche, rose à droite, en
// espace vue) pour garantir la silhouette sur fond sombre. Le studio portrait
// met `rim_strength` à 0 (éclairage studio, pas de néon, §12.6).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform vec4 albedo : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.75;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.6;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
	EMISSION = rim * fresnel * rim_strength + emission_color.rgb;
}
