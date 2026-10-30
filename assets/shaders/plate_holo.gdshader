// Couche holographique des planches de cinématique (M14 §3.3 « HOLO », D-184,
// D-186). Appliquée à l'exécution par `CinematicScreen` (lot D) sur un
// `ColorRect` ou un `TextureRect` posé sur la planche : lueur additive d'une
// vitre, d'un écran ou d'un hologramme. **Jamais sous la légende ni sur un
// `Label` lu** : les textes (numéros, Charte, Main courante) sont des `Label`
// posés au-dessus, nets, en police DS (DS §5, règles 1–2).
//
// Forme : rectangle aux bords doux (`edge_soft`) + halo (`halo`) ; avec une
// texture (TextureRect), la forme est multipliée par l'alpha de la texture.
// Plafonds DS §5 respectés par construction : scanlines α ≤ 0,08 à ≤ 20 px/s,
// scintillement ≤ 0,06 à ≤ 2 Hz (jamais > 3 Hz). Aucun glitch ici (≤ 2/min,
// déclenché par l'écran s'il en faut un).
// `power` (0..1) : allumage — c'est lui que l'écran anime (ex. PL-F9-1 : une
// vitre s'éteint toutes les 0,5 s ; `reduce_motion` : 0 d'emblée).
// `flicker` (réglage « Scintillement holographique », D-109) : 0 = ni
// scintillement ni défilement, lueurs gardées. `fx_intensity` (« Effets
// visuels ») : 0 = tout fixe, sans halo.
// `plate_time` ≥ 0 : temps figé (outil de planches, captures, pause) ; < 0 : TIME.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 tint : source_color = vec4(0.75, 0.88, 0.92, 1.0);
uniform float energy = 1.0;
uniform float power : hint_range(0.0, 1.0) = 1.0;
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.18;
uniform float halo : hint_range(0.0, 0.5) = 0.18;
uniform float edge_soft : hint_range(0.001, 0.5) = 0.06;
uniform float scan_alpha : hint_range(0.0, 0.08) = 0.05;
uniform float scan_period_px = 3.0;
uniform float scan_speed_px : hint_range(0.0, 20.0) = 12.0;
uniform float flicker_amp : hint_range(0.0, 0.06) = 0.03;
uniform float flicker_hz : hint_range(0.0, 2.0) = 0.5;
uniform float flicker = 1.0;
uniform float fx_intensity : hint_range(0.0, 1.0) = 1.0;
uniform float plate_time = -1.0;
uniform bool use_texture_alpha = false;

float rect_mask(vec2 uv, float soft) {
	vec2 d = min(uv, 1.0 - uv);
	return smoothstep(0.0, soft, d.x) * smoothstep(0.0, soft, d.y);
}

void fragment() {
	float t = plate_time >= 0.0 ? plate_time : TIME;
	float motion = clamp(flicker, 0.0, 1.0) * fx_intensity;
	// Le rectangle utile occupe le centre ; la marge `halo` reçoit la lueur.
	vec2 inner = (UV - halo) / max(1.0 - 2.0 * halo, 1e-3);
	float core = rect_mask(inner, edge_soft);
	vec2 d = max(max(-inner, inner - 1.0), vec2(0.0));
	float glow = exp(-length(d) * 9.0) * (1.0 - core) * fx_intensity;
	float shape = core * fill_alpha + glow * 0.5;
	if (use_texture_alpha) {
		shape *= texture(TEXTURE, UV).a;
	}
	// Scanlines : défilement ≤ 20 px/s, figées si `flicker` = 0.
	float y = FRAGCOORD.y + t * scan_speed_px * motion;
	float scan = 1.0 - scan_alpha * fx_intensity * step(0.5, fract(y / scan_period_px));
	// Scintillement doux ≤ 2 Hz (sinus : pas de créneau).
	float flick = 1.0 - flicker_amp * motion * (0.5 + 0.5 * sin(t * 6.2831853 * flicker_hz));
	float a = shape * scan * flick * power;
	COLOR = vec4(tint.rgb * energy * a, a);
}
