## Réglage « Qualité graphique » appliqué au guichet 3D (M9, BOOTH_SCENE §13).
##
## Lit `Settings.graphics_quality_level()` (Bas 0 / Moyen 1 / Élevé 2 ; « Auto »
## = Moyen sur Steam Deck, Élevé ailleurs) et `Settings.fx_intensity`, puis
## règle ce qui coûte : ombres de la `KeyLight`, glow, MSAA du `SubViewport`
## hôte, cartes de normales et ruissellement animé du décor, nombre de nappes
## de pluie. Le visage n'est jamais dégradé (pas de baisse de résolution 3D :
## la comparaison visage ↔ photo prime). Réappliqué sur `settings_changed`.
## M11 (D-109) : `Settings.holo_flicker` → paramètre `flicker` du matériau
## des hologrammes (`booth_holo.gdshader`) : scintillement, scanlines et
## défilement coupés, lueurs gardées.
## Références posées par `tools/build_booth.gd`.
class_name BoothQuality
extends Node

const RAIN_LAYERS: PackedInt32Array = [1, 2, 3]
const MSAA: Array[Viewport.MSAA] = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X]

@export var environment: Environment = null
@export var key_light: SpotLight3D = null
@export var decor_material: ShaderMaterial = null
@export var emissive_material: ShaderMaterial = null
@export var holo_material: ShaderMaterial = null
@export var rain_material: ShaderMaterial = null
@export var glass_material: ShaderMaterial = null

## Niveau appliqué en dernier (tests, debug).
var level: int = -1


func _ready() -> void:
	EventBus.settings_changed.connect(_on_settings_changed)
	apply()


func _on_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_GRAPHICS_QUALITY or key == Settings.KEY_FX_INTENSITY or key == Settings.KEY_HOLO_FLICKER:
		apply()


func apply() -> void:
	level = clampi(Settings.graphics_quality_level(), 0, 2)
	var fx: float = Settings.fx_intensity
	if key_light != null:
		key_light.shadow_enabled = level >= 1
	if environment != null:
		environment.glow_enabled = level >= 1
		environment.glow_bloom = 0.04 if level >= 2 else 0.02
	if decor_material != null:
		decor_material.set_shader_parameter(&"use_normal_maps", level >= 1)
		decor_material.set_shader_parameter(&"wet_motion", fx if level >= 1 else 0.0)
	if rain_material != null:
		rain_material.set_shader_parameter(&"layers", RAIN_LAYERS[level])
	for mat: ShaderMaterial in [emissive_material, holo_material]:
		if mat != null:
			mat.set_shader_parameter(&"fx_intensity", fx)
	if holo_material != null:
		holo_material.set_shader_parameter(&"flicker", 1.0 if Settings.holo_flicker else 0.0)
	var sub: SubViewport = get_viewport() as SubViewport
	if sub != null:
		sub.msaa_3d = MSAA[level]
