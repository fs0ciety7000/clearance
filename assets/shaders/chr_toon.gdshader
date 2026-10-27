// Corps du passager (ASSETS §7.1, BOOTH_SCENE §5) : modèle Kenney recoloré par
// zones (carte `tex_chr_zones_*.png` produite par tools/build_passenger_skins.gd).
// R = zone (0 peau · 1 haut · 2 bas · 3 accent · 4 chaussures · 5 cheveux, ×40/255),
// G = détail (luminance relative, 0,5 = neutre : plis, usure, salissures).
// Éclairage toon (paliers), accent « chrome usé » légèrement métallique, rim de
// Fresnel bicolore désaturé (world.teal.dim à gauche, world.rose.dim à droite),
// émissif optionnel de l'accent (liseré lumineux de tenue). Le studio portrait
// met `rim_strength` à 0 (éclairage plat, pas de néon, BOOTH_SCENE §12.6).
shader_type spatial;
render_mode cull_back, depth_draw_opaque, diffuse_toon, specular_toon;

uniform sampler2D zones : filter_nearest, repeat_disable;
uniform vec4 skin_color : source_color = vec4(0.77, 0.58, 0.44, 1.0);
uniform vec4 top_color : source_color = vec4(0.23, 0.26, 0.32, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.14, 0.15, 0.18, 1.0);
uniform vec4 accent_color : source_color = vec4(0.55, 0.48, 0.37, 1.0);
uniform vec4 shoes_color : source_color = vec4(0.10, 0.10, 0.11, 1.0);
uniform vec4 hair_color : source_color = vec4(0.09, 0.08, 0.08, 1.0);
// Amplitude du détail de la skin d'origine (0 = aplats).
uniform float detail_strength : hint_range(0.0, 1.5) = 0.8;
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.7;
// Liseré émissif de l'accent (≤ 1,5, BOOTH_SCENE §5.2 : pas de glow sur le visage).
uniform vec4 accent_emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec4 z = texture(zones, UV);
	int zone = int(round(z.r * 255.0 / 40.0));
	vec3 base = skin_color.rgb;
	float metal = 0.0;
	float rough = 0.85;
	if (zone == 1) { base = top_color.rgb; }
	else if (zone == 2) { base = bottom_color.rgb; }
	else if (zone == 3) { base = accent_color.rgb; metal = 0.15; rough = 0.5; }
	else if (zone == 4) { base = shoes_color.rgb; rough = 0.6; }
	else if (zone == 5) { base = hair_color.rgb; rough = 0.7; }
	float detail = mix(1.0, clamp(z.g * 2.0, 0.3, 1.7), detail_strength);
	ALBEDO = base * detail;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 world_n = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, world_n.x));
	EMISSION = rim * fresnel * rim_strength + (zone == 3 ? accent_emission.rgb * detail : vec3(0.0));
}
