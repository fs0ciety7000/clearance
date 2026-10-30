## Planches de cinématique (M14 §3.3, §3.6, D-184, D-186) : garde-fous des
## shaders et de l'outil de rendu.
## - `plate_holo` : plafonds DS §5 tenus par les bornes des uniformes
##   (scanlines ≤ 0,08 à ≤ 20 px/s, scintillement ≤ 0,06 à ≤ 2 Hz) ;
## - `plate_paint` : grain ≤ DS.FX_NOISE_ALPHA_MAX, aucune source temporelle
##   (rendu déterministe) ;
## - `build_plates.gd` : aucun texte cuit (ni `TextMesh` ni `Label3D`).
extends GutTest

const HOLO: String = "res://assets/shaders/plate_holo.gdshader"
const PAINT: String = "res://assets/shaders/plate_paint.gdshader"
const TOOL: String = "res://tools/build_plates.gd"


## Borne haute (`hint_range`) d'un uniforme, ou NAN s'il n'en a pas.
func _max_of(shader: Shader, uniform: String) -> float:
	for u: Dictionary in shader.get_shader_uniform_list():
		if u["name"] == uniform and int(u["hint"]) == PROPERTY_HINT_RANGE:
			return String(u["hint_string"]).split(",")[1].to_float()
	return NAN


func _code_without_comments(path: String) -> String:
	var lines: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		lines.append(line.get_slice("//", 0))
	return "\n".join(lines)


func test_holo_caps_follow_design_system() -> void:
	var shader: Shader = load(HOLO) as Shader
	assert_not_null(shader)
	assert_lte(_max_of(shader, "scan_alpha"), DS.FX_SCANLINE_ALPHA_MAX)
	assert_lte(_max_of(shader, "scan_speed_px"), 20.0)
	assert_lte(_max_of(shader, "flicker_amp"), DS.FX_FLICKER_AMPLITUDE_MAX)
	assert_lte(_max_of(shader, "flicker_hz"), DS.FX_FLICKER_HZ_MAX)


func test_holo_has_accessibility_switches() -> void:
	var names: Array[String] = []
	for u: Dictionary in (load(HOLO) as Shader).get_shader_uniform_list():
		names.append(u["name"])
	for needed: String in ["power", "flicker", "fx_intensity", "plate_time"]:
		assert_has(names, needed, "uniforme %s (D-109, D-186, temps figé)" % needed)


func test_paint_grain_capped_and_timeless() -> void:
	var shader: Shader = load(PAINT) as Shader
	assert_not_null(shader)
	assert_lte(_max_of(shader, "grain_alpha"), DS.FX_NOISE_ALPHA_MAX)
	assert_false(_code_without_comments(PAINT).contains("TIME"), "plate_paint ne dépend pas du temps")


func test_plate_tool_bakes_no_text() -> void:
	var code: String = FileAccess.get_file_as_string(TOOL)
	assert_false(code.contains("TextMesh"), "aucun texte cuit dans les planches (D-184)")
	assert_false(code.contains("Label3D"), "aucun texte cuit dans les planches (D-184)")
