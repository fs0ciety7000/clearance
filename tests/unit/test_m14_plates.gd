## M14 lot C — planches de cinématique (B89, B90, B92 ; D-184, D-185, D-195) :
## couverture du catalogue de décors sur les **vraies** données du lot E, style
## pictural unique (traitement B, papier à l'exécution, jetons DS), figures
## nommées (silhouette de repli sans mémoire, en headless), taille des
## portraits du Dossier, et cohérence données ↔ manifeste quand il existe.
extends GutTest

const SETS = preload("res://tools/plate_sets.gd")
const PLATES_DIR: String = "res://data/cinematics/plates"
const MANIFEST: String = "res://assets/cinematics/manifest.json"

var _plates: Array[PlateDef] = []


func before_all() -> void:
	CinematicLibraryDef.load_default() # avant les PlateDef (fuite à la sortie sinon)
	var files: PackedStringArray = DirAccess.get_files_at(PLATES_DIR)
	files.sort()
	for f: String in files:
		if f.ends_with(".tres"):
			_plates.append(load(PLATES_DIR.path_join(f)) as PlateDef)


func test_every_background_and_layer_has_a_builder() -> void:
	assert_gt(_plates.size(), 60, "planches du lot E")
	var sets: SETS = SETS.new(null, null, null)
	var bgs: Dictionary = {}
	for plate: PlateDef in _plates:
		for layer: PlateLayerDef in plate.layers:
			if layer == null or layer.texture_path.is_empty():
				continue
			var stem: String = layer.texture_path.get_file().get_basename()
			match layer.kind:
				PlateLayerDef.KIND_BG:
					bgs[stem] = true
					assert_true(sets.has_bg(stem), "fond %s construit (%s)" % [stem, plate.id])
				PlateLayerDef.KIND_MID, PlateLayerDef.KIND_FIG:
					assert_true(sets.has_layer(stem), "couche %s construite (%s)" % [stem, plate.id])
	assert_eq(bgs.size(), 46, "46 fonds distincts (M14 §3.6)")


func test_dominants_are_known_design_tokens() -> void:
	for plate: PlateDef in _plates:
		assert_true(PlatePaintStyle.is_known_token(plate.dominant), "%s : jeton %s" % [plate.id, plate.dominant])


func test_treatment_b_without_baked_paper() -> void:
	assert_eq(int(PlatePaintStyle.PRESET["radius"]), 6, "D-195 : Kuwahara rayon 6")
	assert_eq(float(PlatePaintStyle.PRESET["paper_alpha"]), 0.0, "papier jamais cuit")
	assert_gt(float(PlatePaintStyle.PRESET["hatch_alpha"]), 0.0, "hachures du lavis gravé")
	var ramp: PackedColorArray = PlatePaintStyle.ramp(DS.STATE_RED, PlatePaintStyle.default_mix(&"state.red"))
	assert_eq(ramp.size(), 8, "8 tons")
	for i: int in 7:
		assert_lt(ramp[i].get_luminance(), ramp[i + 1].get_luminance() + 0.001, "rampe croissante")
	var paper: ShaderMaterial = PlatePaintStyle.paper_material(Vector2(10, 20), Vector2(300, 400), 0.0)
	assert_eq(float(paper.get_shader_parameter(&"paper_alpha")), 0.0, "effets visuels à 0 : sans papier")
	assert_false((paper.shader as Shader).get_shader_uniform_list().is_empty(), "plate_paper compile")


func test_paint_shaders_have_no_time_source() -> void:
	for path: String in ["res://assets/shaders/plate_paint.gdshader", "res://assets/shaders/plate_paper.gdshader"]:
		var code: String = (load(path) as Shader).code
		assert_false(code.contains("TIME"), "%s déterministe (aucun TIME)" % path)


func test_figure_service_falls_back_to_silhouette_without_memory() -> void:
	var service: PlateFigureService = PlateFigureService.new()
	add_child_autofree(service)
	var slot: FigureSlotDef = null
	var flags: Dictionary[StringName, Variant] = {}
	for plate: PlateDef in _plates:
		if not plate.figures.is_empty():
			slot = plate.figures[0]
			break
	assert_not_null(slot, "emplacement de figure dans les données")
	# REVOIR depuis le Dossier / headless : mémoire vide → silhouette de repli.
	var tex: Texture2D = service.request_for(slot, {}, flags)
	assert_eq(tex, PlateFigureService.silhouette_texture(slot))
	assert_eq(service.pending(), 0, "aucun rendu demandé")
	# Headless : même avec un visage, aucun rendu GPU (repli).
	var app: PassengerAppearance = PlateFigureService.anonymous_appearance()
	assert_eq(service.request(slot, app), PlateFigureService.silhouette_texture(slot))


func test_agent_is_never_a_named_figure() -> void:
	for plate: PlateDef in _plates:
		for slot: FigureSlotDef in plate.figures:
			assert_true(slot.id in [&"fg_figure", &"fg_wren", &"fg_figure31"], "%s : figure nommée connue" % plate.id)


func test_portrait_service_size_for_dossier() -> void:
	var service: PortraitService = PortraitService.new()
	service.size = PortraitService.DOSSIER_SIZE
	add_child_autofree(service)
	var app: PassengerAppearance = PlateFigureService.anonymous_appearance()
	var tex: Texture2D = service.get_portrait(app)
	assert_eq(Vector2i(tex.get_size()), PortraitService.DOSSIER_SIZE, "vignette 128×160")
	var doc: PortraitService = PortraitService.new()
	add_child_autofree(doc)
	assert_eq(Vector2i(doc.get_portrait(app).get_size()), PortraitService.SIZE, "documents inchangés (256×320)")
	service.size = Vector2i(96, 120)
	assert_eq(service.cache_size(), 0, "changer la taille vide le cache")


func test_rendered_plates_match_data_when_manifest_exists() -> void:
	if not FileAccess.file_exists(MANIFEST):
		pending("planches pas encore rendues (tools/build_plates.gd)")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var files: Dictionary = manifest.get("files", {})
	assert_eq(String(manifest.get("treatment", "")), PlatePaintStyle.PRESET["label"])
	for plate: PlateDef in _plates:
		for layer: PlateLayerDef in plate.layers:
			if layer == null or layer.kind == PlateLayerDef.KIND_FX:
				continue
			assert_true(files.has(layer.texture_path), "%s rendu (%s)" % [layer.texture_path, plate.id])
			# Fond : rectangle libre (PL-F6E-4 agrandit BG-Q7 ×1,6) ; couches : relues du rendu.
			if files.has(layer.texture_path) and layer.kind != PlateLayerDef.KIND_BG:
				var rn: Array = (files[layer.texture_path] as Dictionary)["rect_norm"]
				assert_almost_eq(layer.rect.position.x, float(rn[0]), 0.002, "%s : x relu du manifeste" % layer.texture_path)
				assert_almost_eq(layer.rect.size.y, float(rn[3]), 0.002, "%s : hauteur relue du manifeste" % layer.texture_path)
				assert_true(FileAccess.file_exists(layer.texture_path), "%s présent" % layer.texture_path)
