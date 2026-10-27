// Silhouettes de la file d'attente (BOOTH_SCENE §11) : remplissage sombre
// teinté par la couleur d'instance (MultiMesh `use_colors`), rim teal/rose,
// léger balancement de vertex (±1 cm à 0,2 Hz) à phase aléatoire par instance.
shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 fill : source_color = vec4(0.063, 0.075, 0.106, 1.0);
uniform vec4 rim_left : source_color = vec4(0.169, 0.431, 0.471, 1.0);
uniform vec4 rim_right : source_color = vec4(0.494, 0.227, 0.361, 1.0);
uniform float rim_strength = 0.9;

varying vec3 tint;

void vertex() {
	float phase = float(INSTANCE_ID) * 1.618;
	float sway = sin(TIME * 1.2566 + phase) * 0.01 * clamp(VERTEX.y, 0.0, 2.0);
	VERTEX.x += sway;
	tint = COLOR.rgb;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	vec3 rim = mix(rim_left.rgb, rim_right.rgb, smoothstep(-0.3, 0.3, NORMAL.x));
	ALBEDO = mix(fill.rgb, tint, 0.35) + rim * fresnel * rim_strength;
}
