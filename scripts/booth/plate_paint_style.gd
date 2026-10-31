## Style pictural des planches de cinématique (M14 §3.6, D-184, **D-195 :
## traitement B « lavis gravé »**) — source unique pour l'outil hors ligne
## (`tools/build_plates.gd`) et les figures rendues à l'exécution
## (`PlateFigureService`, M14 §3.5).
##
## - `PRESET` : réglages de `plate_paint.gdshader` du traitement B, **sans papier
##   cuit** (`paper_alpha` = 0) : le grain de papier est posé à l'exécution par
##   `plate_paper.gdshader` (budget disque D-195), avec le même motif.
## - `dominant_color(token)` : couleur d'un nom de jeton DS (`PlateDef.dominant`,
##   jamais une couleur codée en dur dans les données).
## - `ramp(dominant, mix, light, light_mix)` : rampe de 8 tons tirée des gris
##   du monde (DS + BOOTH §5) teintés par la dominante de la fin.
## - `paint_material(...)`, `paper_material(...)` : matériaux prêts à poser.
## Aucune dépendance au jeu (ni état, ni cas).
class_name PlatePaintStyle
extends RefCounted

const PAINT_SHADER: String = "res://assets/shaders/plate_paint.gdshader"
const PAPER_SHADER: String = "res://assets/shaders/plate_paper.gdshader"
## Format des planches (M14 §3.3) : fond 2048×1152.
const PLATE_SIZE: Vector2i = Vector2i(2048, 1152)

## Traitement B « lavis gravé » (D-195) : Kuwahara r6, marches adoucies, chroma
## plus présente, encre fine, hachures dans les ombres, grain ; papier à l'exécution.
const PRESET: Dictionary = {
	"label": "B — lavis gravé", "radius": 6, "tone_gamma": 0.8, "band_soft": 0.45, "chroma_keep": 0.5,
	"ink_alpha": 0.6, "ink_width": 1.0, "hatch_alpha": 0.32, "grain_alpha": 0.03, "paper_alpha": 0.0,
}
## Papier posé à l'exécution (même motif que la phase 1 : bruit de valeur à
## 3 px et 37 px de planche).
const PAPER_ALPHA: float = 0.05

## Part de la dominante dans chaque ton de la rampe (sombre → clair), par défaut.
## (valeurs de la planche témoin PL-F9-1 validée par le client, D-195).
const DEFAULT_MIX: Array[float] = [0.0, 0.2, 0.3, 0.35, 0.3, 0.2, 0.1, 0.0]

## Jetons DS admis pour `PlateDef.dominant` (M14 §3.3, « Couleur »).
const TOKENS: Dictionary[StringName, Color] = {
	&"accent.cyan": DS.ACCENT_CYAN,
	&"accent.yellow": DS.ACCENT_YELLOW,
	&"accent.magenta": DS.ACCENT_MAGENTA,
	&"state.red": DS.STATE_RED,
	&"state.amber": DS.STATE_AMBER,
	&"state.green": DS.STATE_GREEN,
	&"text.primary": DS.TEXT_PRIMARY,
	&"text.secondary": DS.TEXT_SECONDARY,
	&"text.muted": DS.TEXT_MUTED,
	&"world.steel": GreyboxStyle.WORLD_STEEL,
	&"world.key": GreyboxStyle.WORLD_KEY,
	&"world.teal": GreyboxStyle.WORLD_TEAL_DIM,
	&"world.rose": GreyboxStyle.WORLD_ROSE_DIM,
	&"world.spill": GreyboxStyle.WORLD_HALCYON_SPILL,
}


## Couleur d'un jeton (`world.steel` si inconnu ; `known` : vrai si reconnu).
static func dominant_color(token: StringName) -> Color:
	return TOKENS.get(token, GreyboxStyle.WORLD_STEEL)


static func is_known_token(token: StringName) -> bool:
	return TOKENS.has(token)


## Part de la dominante selon sa nature : les accents saturés (jaune, magenta,
## rouge, vert, cyan) teintent moins que les gris du monde (la dominante est
## décorative, DS §2 : jamais porteuse de sens).
static func default_mix(token: StringName) -> Array[float]:
	var scale: float = 1.0
	if String(token).begins_with("accent.") or String(token).begins_with("state."):
		scale = 0.38 # (PL-F10-3 validée : vert à ≈ 0,35)
	elif String(token).begins_with("text."):
		scale = 0.6
	var out: Array[float] = []
	for m: float in DEFAULT_MIX:
		out.append(m * scale)
	return out


## Rampe de 8 tons : gris du monde teintés par la dominante, tons clairs tirés
## vers `light` (`light_mix`, lumière d'ambiance de la planche).
static func ramp(dominant: Color, mix_amounts: Array, light: Color = Color.WHITE, light_mix: Array = []) -> PackedColorArray:
	var base: Array[Color] = [DS.BG_VOID, DS.BG_PANEL, DS.BG_ELEVATED, GreyboxStyle.WORLD_STEEL, DS.TEXT_MUTED, DS.TEXT_SECONDARY,
			GreyboxStyle.WORLD_KEY.lerp(DS.TEXT_SECONDARY, 0.4), DS.TEXT_PRIMARY]
	var out: PackedColorArray = []
	for i: int in 8:
		var c: Color = base[i].lerp(dominant, float(mix_amounts[i]) if i < mix_amounts.size() else 0.0)
		out.append(c.lerp(light, float(light_mix[i])) if i < light_mix.size() else c)
	return out


## Matériau de peinture (`plate_paint.gdshader`) pour une image source et son
## G-buffer (null : contours par alpha et luminance seulement).
static func paint_material(source: Texture2D, gbuffer: Texture2D, ramp_colors: PackedColorArray, transparent: bool,
		preset: Dictionary = PRESET) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(PAINT_SHADER) as Shader
	mat.set_shader_parameter(&"source", source)
	mat.set_shader_parameter(&"gbuffer", gbuffer)
	mat.set_shader_parameter(&"use_gbuffer", gbuffer != null)
	mat.set_shader_parameter(&"ramp", ramp_colors)
	mat.set_shader_parameter(&"ink_color", DS.BG_VOID)
	mat.set_shader_parameter(&"transparent_layer", transparent)
	if gbuffer == null:
		mat.set_shader_parameter(&"luma_edge", 0.08)
	for key: String in ["radius", "tone_gamma", "band_soft", "chroma_keep", "ink_alpha", "ink_width", "hatch_alpha",
			"grain_alpha", "paper_alpha"]:
		mat.set_shader_parameter(StringName(key), preset[key])
	return mat


## Papier à l'exécution (D-195) pour une couche dont le coin haut-gauche est à
## `origin_px` (pixels de planche) et de taille `size_px` ; `strength` suit
## « Effets visuels » (`Settings.fx_intensity`, 0 = sans papier).
static func paper_material(origin_px: Vector2, size_px: Vector2, strength: float = 1.0) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = load(PAPER_SHADER) as Shader
	mat.set_shader_parameter(&"origin_px", origin_px)
	mat.set_shader_parameter(&"size_px", size_px)
	mat.set_shader_parameter(&"paper_alpha", PAPER_ALPHA * clampf(strength, 0.0, 1.0))
	return mat
