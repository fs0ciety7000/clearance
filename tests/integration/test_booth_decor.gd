## Décor définitif du guichet (M9, BOOTH_SCENE §17) : budget de draw calls
## (décor fusionné), aucune ombre portée par le décor, réglage « Qualité
## graphique » appliqué par `BoothQuality`.
extends GutTest

const BOOTH_SCENE: PackedScene = preload("res://scenes/booth/booth.tscn")
## Budget du décor hors passagers et UI (BOOTH_SCENE §13) : 40 ; réel : 7.
const DECOR_DRAW_BUDGET: int = 8

var booth: BoothDirector = null


func before_each() -> void:
	booth = BOOTH_SCENE.instantiate()
	add_child_autofree(booth)


func after_each() -> void:
	Settings.clear_session_value(Settings.KEY_GRAPHICS_QUALITY)
	Settings.clear_session_value(Settings.KEY_FX_INTENSITY)


## Instances géométriques du décor (tout sauf les acteurs de `PassengerSlots`).
func _decor_geometry() -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	var slots: Node = booth.get_node(^"%PassengerSlots")
	for node: Node in booth.find_children("*", "GeometryInstance3D", true, false):
		if slots.is_ancestor_of(node):
			continue
		found.append(node as GeometryInstance3D)
	return found


func test_decor_fits_draw_budget() -> void:
	var geometry: Array[GeometryInstance3D] = _decor_geometry()
	var surfaces: int = 0
	for g: GeometryInstance3D in geometry:
		var mi: MeshInstance3D = g as MeshInstance3D
		surfaces += mi.mesh.get_surface_count() if mi != null and mi.mesh != null else 1
	assert_lte(surfaces, DECOR_DRAW_BUDGET, "surfaces du décor (1 draw call chacune)")
	assert_eq(booth.get_node(^"Decor").get_child_count(), 5, "5 maillages fusionnés")


func test_decor_casts_no_shadow() -> void:
	for g: GeometryInstance3D in _decor_geometry():
		assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, String(g.name))


func test_decor_meshes_share_one_lit_material() -> void:
	var near: MeshInstance3D = booth.get_node(^"Decor/StaticNear")
	var far: MeshInstance3D = booth.get_node(^"Decor/StaticFar")
	assert_same(near.material_override, far.material_override)


func test_quality_levels_apply() -> void:
	var quality: BoothQuality = booth.get_node(^"Quality")
	var key: SpotLight3D = booth.get_node(^"Lights/KeyLight")
	var rain: ShaderMaterial = (booth.get_node(^"Decor/Rain") as MeshInstance3D).material_override as ShaderMaterial
	var env: Environment = (booth.get_node(^"WorldEnvironment") as WorldEnvironment).environment
	Settings.set_session_value(Settings.KEY_GRAPHICS_QUALITY, 0.0)
	assert_eq(quality.level, 0)
	assert_false(key.shadow_enabled, "Bas : pas d'ombre")
	assert_false(env.glow_enabled, "Bas : pas de glow")
	var layers: int = rain.get_shader_parameter(&"layers")
	assert_eq(layers, 1)
	Settings.set_session_value(Settings.KEY_GRAPHICS_QUALITY, 2.0)
	assert_eq(quality.level, 2)
	assert_true(key.shadow_enabled, "Élevé : ombre de la lampe")
	assert_true(env.glow_enabled)
	layers = rain.get_shader_parameter(&"layers")
	assert_eq(layers, 3)


func test_auto_quality_resolves_by_platform() -> void:
	Settings.set_session_value(Settings.KEY_GRAPHICS_QUALITY, Settings.QUALITY_AUTO)
	var expected: int = 1 if OS.get_environment("SteamDeck") == "1" else 2
	assert_eq(Settings.graphics_quality_level(), expected)
	assert_eq((booth.get_node(^"Quality") as BoothQuality).level, expected)
