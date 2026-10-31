## M14 lots E et F — intégrité des **vraies** données (`tools/build_data_m14.gd`) :
## 18 séquences et 66 planches (63 places de M14 §3.4 + 3 variantes de fond),
## 46 fonds, 71 légendes `cin_*` présentes dans `fr.csv` et ≤ 70 caractères,
## 3–5 planches et 25–45 s (épilogue 18–30 s) pour chaque fin et variante,
## rien de l'Acte III dans une fin anticipée, figures nommées résolubles sur une
## vraie mémoire ; 52 annonces d'ambiance sans information de jeu ; tension
## musicale par jour, poids des événements, effets des annonces, portraits ;
## déterminisme du générateur et données à jour.
extends GutTest

const M14 := preload("res://tools/build_data_m14.gd")
const GF := preload("res://tests/helpers/generation_fixtures.gd")
const CSV_PATH: String = "res://data/i18n/fr.csv"
const PLATES_DIR: String = "res://data/cinematics/plates"
const TITLE_SEC: float = 3.5

var _texts: Dictionary[String, String] = {}
var _lib: CinematicLibraryDef = null


func before_all() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 2:
			_texts[row[0]] = row[1]
	_lib = CinematicLibraryDef.load_default()


func _all_plates() -> Array[PlateDef]:
	var result: Array[PlateDef] = []
	for name: String in DirAccess.get_files_at(PLATES_DIR):
		if name.ends_with(".tres"):
			result.append(load(PLATES_DIR.path_join(name)) as PlateDef)
	return result


# --- Séquences et planches --------------------------------------------------

func test_library_has_the_18_sequences_and_every_plate_exists() -> void:
	assert_not_null(_lib, "cinematics.tres présent")
	assert_eq(_lib.cinematics.size(), 18)
	var ids: Dictionary[StringName, bool] = {}
	var used: Dictionary[String, bool] = {}
	var epilogues: int = 0
	for c: CinematicDef in _lib.cinematics:
		assert_false(ids.has(c.id), "id unique %s" % c.id)
		ids[c.id] = true
		if c.is_epilogue():
			epilogues += 1
		assert_between(c.plates.size(), 3, 5, "%s : 3 à 5 planches candidates" % c.id)
		for p: PlateDef in c.plates:
			assert_not_null(p, "%s : planche référencée chargée" % c.id)
			if p == null:
				continue
			assert_true(p.resource_path.begins_with(PLATES_DIR), "%s : planche externe partagée" % p.id)
			assert_eq(p.resource_path.get_file().get_basename(), String(p.id), "nom de fichier = id")
			used[p.resource_path] = true
	assert_eq(epilogues, 4, "CIN-EA → CIN-ED")
	var plates: Array[PlateDef] = _all_plates()
	assert_eq(plates.size(), 66, "63 places + 3 variantes de fond")
	for p: PlateDef in plates:
		assert_true(used.has(p.resource_path), "%s utilisée par une séquence" % p.id)


func test_backgrounds_layers_and_ds_ceilings() -> void:
	var backgrounds: Dictionary[String, bool] = {}
	for p: PlateDef in _all_plates():
		assert_eq(p.layers[0].kind, PlateLayerDef.KIND_BG, "%s : fond en premier" % p.id)
		var bg_count: int = 0
		for layer: PlateLayerDef in p.layers:
			match layer.kind:
				PlateLayerDef.KIND_BG:
					bg_count += 1
					backgrounds[layer.texture_path] = true
					assert_string_starts_with(layer.texture_path, "res://assets/cinematics/bg/bg_")
				PlateLayerDef.KIND_MID, PlateLayerDef.KIND_FIG:
					assert_string_starts_with(layer.texture_path, "res://assets/cinematics/%s/%s_" % [layer.kind, p.id])
				PlateLayerDef.KIND_FX:
					assert_true(layer.texture_path.is_empty())
					assert_has([PlateLayerDef.FX_RAIN, PlateLayerDef.FX_SMOKE, PlateLayerDef.FX_DUST, PlateLayerDef.FX_AIR,
							PlateLayerDef.FX_FOG], layer.fx_kind, "%s : effet connu" % p.id)
				PlateLayerDef.KIND_LIT:
					assert_eq(p.holo_effect, PlateDef.HOLO_GLASS_OFF_SEQUENCE, "%s : couche d'état" % p.id)
					assert_between(layer.state_index, 0, 11)
				_:
					fail_test("%s : couche inconnue %s" % [p.id, layer.kind])
		assert_eq(bg_count, 1, "%s : un seul fond" % p.id)
		assert_true(p.parallax_px <= PlateDef.PARALLAX_MAX_PX and p.zoom_to <= PlateDef.ZOOM_MAX, "%s : plafonds DS" % p.id)
		assert_false(String(p.dominant).is_empty() or String(p.dominant).begins_with("#"), "%s : dominante = jeton" % p.id)
		assert_eq(p.paint_radius_px, M14.PAINT_RADIUS_PX, "D-195 : lavis gravé")
		assert_has([&"s1", &"s2", &"s3", &"s4", &"s5", &"s6", &"s7", &"s8"], p.set_id, "%s : décor S1 → S8" % p.id)
	assert_eq(backgrounds.size(), 46, "46 fonds (M14 §3.6)")
	var f9: PlateDef = load(PLATES_DIR.path_join("pl_f9_1.tres"))
	var order: Array[int] = []
	for layer: PlateLayerDef in f9.layers:
		if layer.kind == PlateLayerDef.KIND_LIT:
			order.append(layer.state_index)
	assert_eq(order, [3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1, 2], "« Le 04 s'éteint. Puis le 05. Puis toutes. »")


func test_captions_and_labels_are_in_fr_csv_and_short() -> void:
	var keys: Dictionary[String, bool] = {}
	for p: PlateDef in _all_plates():
		for key: String in p.all_caption_keys():
			keys[key] = true
			assert_true(_texts.has(key), "légende %s dans fr.csv" % key)
			assert_true(_texts.get(key, "").length() <= PlateDef.CAPTION_MAX_CHARS, "%s ≤ 70 caractères" % key)
			assert_string_starts_with(key, "cin_")
		for label: PlateLabelDef in p.labels:
			if label.literal:
				assert_false(label.text_key.is_empty())
				assert_false(_texts.has(label.text_key), "littéral, pas une clé : %s" % label.text_key)
			else:
				assert_true(_texts.has(label.text_key), "étiquette %s dans fr.csv" % label.text_key)
			assert_has([&"holo_display", &"holo_small", &"clock"], label.style)
	assert_eq(keys.size(), 71, "71 légendes (M14 §3.4)")


## `[fin, variante, acte, jour, drapeaux vrais, séquence attendue ou &""]`.
func _scenarios() -> Array[Array]:
	var a2: Array[StringName] = [&"act2_started"]
	var a3: Array[StringName] = [&"act2_started", &"act3_started"]
	var none: Array[StringName] = []
	return [
		[EndingService.F1_ARRESTED, &"audit", 1, 9, none, &"cin_f1"],
		[EndingService.F1_ARRESTED, &"review", 2, 17, a2, &"cin_f1"],
		[EndingService.F1_ARRESTED, &"deposition", 3, 29, a3, &"cin_f1"],
		[EndingService.F1_ARRESTED, &"double", 3, 30, _with(a3, &"okonkwo_warned"), &"cin_f1"],
		[EndingService.F1_ARRESTED, &"double", 1, 10, none, &"cin_f1"],
		[EndingService.F2_REASSIGNED, &"", 1, 6, none, &"cin_f2"],
		[EndingService.F2_REASSIGNED, &"", 3, 30, a3, &"cin_f2"],
		[EndingService.F3_FAMILY_LOST, &"", 2, 14, a2, &"cin_f3"],
		[EndingService.F3_FAMILY_LOST, &"", 3, 30, _with(a3, &"lumika_learned"), &"cin_f3"],
		[EndingService.F4_GLORY, &"", 3, 30, a3, &"cin_f4"],
		[EndingService.F4_GLORY, &"", 3, 30, _with(a3, &"final3_dora"), &"cin_f4"],
		[EndingService.F4_GLORY, &"", 2, 20, a2, &""],
		[EndingService.F5_AIR, &"c", 3, 30, a3, &"cin_f5c"],
		[EndingService.F5_AIR, &"s", 3, 30, _with(a3, &"final3_dora"), &"cin_f5s"],
		[EndingService.F5_AIR, &"b", 3, 30, a3, &"cin_f5b"],
		[EndingService.F5_AIR, &"b", 2, 20, a2, &""],
		[EndingService.F5_AIR, &"", 1, 10, none, &""],
		[EndingService.F6_DRIFT, &"j10", 1, 10, none, &"cin_f6e"],
		[EndingService.F6_DRIFT, &"j20", 2, 20, a2, &"cin_f6e"],
		[EndingService.F6_DRIFT, &"t", 3, 30, a3, &"cin_f6t"],
		[EndingService.F6_DRIFT, &"d", 3, 30, _with(a3, &"exit3_drift"), &"cin_f6d"],
		[EndingService.F7_REOPENS, &"", 3, 30, a3, &"cin_f7"],
		[EndingService.F7_REOPENS, &"", 1, 10, none, &""],
		[EndingService.F8_REGISTRE, &"", 3, 30, a3, &"cin_f8"],
		[EndingService.F8_REGISTRE, &"", 2, 20, a2, &""],
		[EndingService.F9_STRIKE, &"", 3, 30, a3, &"cin_f9"],
		[EndingService.F9_STRIKE, &"", 2, 20, a2, &""],
		[EndingService.F10_PONT, &"", 3, 30, a3, &"cin_f10"],
	]


func _with(base: Array[StringName], flag: StringName) -> Array[StringName]:
	var result: Array[StringName] = base.duplicate()
	result.append(flag)
	return result


func _duration(plates: Array[PlateDef], flags: Dictionary[StringName, Variant], title: bool) -> float:
	var total: float = TITLE_SEC if title else 0.0
	for p: PlateDef in plates:
		var caption: String = _texts.get(CinematicService.caption_key(p, flags), "")
		total += p.duration_sec if p.duration_sec > 0.0 else maxf(6.0, 2.5 + 0.06 * caption.length())
	return total


func test_every_ending_and_variant_selects_3_to_5_plates_within_25_to_45_seconds() -> void:
	for s: Array in _scenarios():
		var flags: Dictionary[StringName, Variant] = FlagCondition.from_true_flags(s[4])
		var label: String = "%s/%s acte %d" % [s[0], s[1], s[2]]
		assert_eq(EpilogueService.act_of(flags), s[2], "%s : drapeaux d'acte" % label)
		var def: CinematicDef = CinematicService.select(s[0], s[1], flags, s[2], s[3], _lib)
		if s[5] == &"":
			assert_null(def, "%s : écran de fin direct (M14 §8 n° 13)" % label)
			continue
		assert_not_null(def, label)
		if def == null:
			continue
		assert_eq(def.id, s[5], label)
		var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(flags, s[2], s[1], s[3])
		var plates: Array[PlateDef] = CinematicService.plates_for(def, ctx, s[2])
		assert_between(plates.size(), CinematicService.MIN_PLATES, CinematicService.MAX_PLATES, label)
		for p: PlateDef in plates:
			assert_true(p.min_act <= s[2], "%s : rien d'un acte plus tardif (%s)" % [label, p.id])
			if s[2] < 3:
				assert_true(p.min_act < 3, "%s : rien de l'Acte III (%s)" % [label, p.id])
		var seconds: float = _duration(plates, ctx, def.title_card)
		assert_between(seconds, 25.0, 45.0, "%s : %.1f s" % [label, seconds])


func test_captions_follow_variants_and_flags() -> void:
	var a3: Dictionary[StringName, Variant] = FlagCondition.from_true_flags([&"act2_started", &"act3_started"])
	var f1: CinematicDef = _lib.get_cinematic(&"cin_f1")
	var audit: Dictionary[StringName, Variant] = CinematicService.context_flags({}, 1, &"audit", 9)
	var plates: Array[PlateDef] = CinematicService.plates_for(f1, audit, 1)
	assert_eq(CinematicService.caption_key(plates[0], audit), "cin_f1_1_audit")
	assert_eq(plates[2].id, &"pl_f1_3", "Acte I : pas de borne")
	var warned: Dictionary[StringName, Variant] = a3.duplicate()
	warned[&"okonkwo_warned"] = true
	var late: Dictionary[StringName, Variant] = CinematicService.context_flags(warned, 3, &"double", 30)
	plates = CinematicService.plates_for(f1, late, 3)
	assert_eq(CinematicService.caption_key(plates[0], late), "cin_f1_1_double")
	assert_eq(plates[2].id, &"pl_f1_3_borne")
	assert_eq(CinematicService.caption_key(plates[3], late), "cin_f1_4_okonkwo")
	var early_double: Dictionary[StringName, Variant] = CinematicService.context_flags({}, 1, &"double", 10)
	for p: PlateDef in CinematicService.plates_for(f1, early_double, 1):
		assert_ne(p.id, &"pl_f1_1", "double jeu simulé des actes I–II : pas de « trente jours »")
	var dora: Dictionary[StringName, Variant] = a3.duplicate()
	dora[&"final3_dora"] = true
	var f4: CinematicDef = _lib.get_cinematic(&"cin_f4")
	var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags(dora, 3, &"", 30)
	assert_eq(CinematicService.caption_key(CinematicService.plates_for(f4, ctx, 3)[0], ctx), "cin_f4_1_dora")
	var f3: CinematicDef = _lib.get_cinematic(&"cin_f3")
	var lumika: Dictionary[StringName, Variant] = CinematicService.context_flags({&"lumika_learned": true}, 1, &"", 5)
	assert_eq(CinematicService.plates_for(f3, lumika, 1)[1].id, &"pl_f3_2_lumika")
	var plain: Dictionary[StringName, Variant] = CinematicService.context_flags({}, 1, &"", 5)
	assert_eq(CinematicService.plates_for(f3, plain, 1)[1].id, &"pl_f3_2")


## Mémoire réelle : SC-04 (Mira, J3) joué puis mémorisé sous `key`.
func _real_memory(key: String) -> Dictionary:
	var data: DataCatalog = GF.data()
	var day: DayDef = data.get_day(3)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(4242, 3))
	var scripted: ScriptedCaseDef = null
	for s: ScriptedCaseDef in day.scripted_cases:
		if s.id == &"sc_04":
			scripted = s
	var g: GeneratedCase = builder.build(scripted.at_index)
	return {key: CaseMemory.snapshot(3, g.case, VerdictKind.Kind.APPROVE)}


func _scripted_ids() -> Dictionary[String, bool]:
	var ids: Dictionary[String, bool] = {}
	var days: Array[DayDef] = []
	for d: DayDef in GF.data().days.values():
		days.append(d)
	for world: String in ["a", "b", "c", "d"]:
		days.append(load("res://data/epilogue/day_31_%s.tres" % world) as DayDef)
	for d: DayDef in days:
		for s: ScriptedCaseDef in d.scripted_cases:
			ids[String(s.id)] = true
	return ids


func test_named_figures_resolve_to_real_cases_and_faces() -> void:
	var ids: Dictionary[String, bool] = _scripted_ids()
	var slots: Dictionary[StringName, int] = {}
	for p: PlateDef in _all_plates():
		for slot: FigureSlotDef in p.figures:
			slots[slot.id] = slots.get(slot.id, 0) + 1
			assert_has([&"fg_figure", &"fg_wren", &"fg_figure31"], slot.id)
			assert_string_starts_with(slot.silhouette_path, "res://assets/cinematics/fig/%s_" % slot.id)
			assert_eq(slot.omit_plate_if_missing, slot.id == &"fg_figure31", "%s : seule PL-E-FIG est omise" % p.id)
			for candidate: ConditionalKey in slot.memory_cases:
				assert_true(ids.has(candidate.key), "%s : cas %s réel" % [slot.id, candidate.key])
	assert_eq(slots, {&"fg_figure": 2, &"fg_wren": 1, &"fg_figure31": 2} as Dictionary[StringName, int])
	var none: Dictionary[StringName, Variant] = {}
	var dora: Dictionary[StringName, Variant] = {&"final3_dora": true}
	var f4: PlateDef = load(PLATES_DIR.path_join("pl_f4_1.tres"))
	var figure: FigureSlotDef = f4.figures[0]
	assert_not_null(CinematicService.figure_appearance(figure, _real_memory("sc_82b"), none), "Mira vue au J30")
	assert_null(CinematicService.figure_appearance(figure, _real_memory("sc_82b"), dora), "Dora attendue : pas Mira")
	assert_not_null(CinematicService.figure_appearance(figure, _real_memory("sc_82a"), dora), "Dora vue au J30")
	assert_null(CinematicService.figure_appearance(figure, {}, none), "REVOIR : silhouette")
	var wren: FigureSlotDef = (load(PLATES_DIR.path_join("pl_f6_2.tres")) as PlateDef).figures[0]
	assert_not_null(CinematicService.figure_appearance(wren, _real_memory("sc_19"), none), "Wren du J9 (fin du J10)")
	# PL-E-FIG : seulement une figure du J31 **approuvée** et vue.
	var ea: CinematicDef = CinematicService.select_epilogue(&"a", _lib)
	var memory: Dictionary = _real_memory("sc_93b")
	var refused: Dictionary[StringName, Variant] = CinematicService.context_flags({&"act3_started": true}, 3)
	assert_eq(CinematicService.plates_for(ea, refused, 3, memory).size(), 3, "figure refusée : PL-E-FIG omise")
	var passed: Dictionary[StringName, Variant] = CinematicService.context_flags({&"act3_started": true, &"sc93_mira_passed": true}, 3)
	var plates: Array[PlateDef] = CinematicService.plates_for(ea, passed, 3, memory)
	assert_eq(plates.size(), 4)
	assert_eq(plates[1].id, &"pl_e_fig", "PL-E-FIG en deuxième")
	var ed: CinematicDef = CinematicService.select_epilogue(&"d", _lib)
	var d_passed: Dictionary[StringName, Variant] = CinematicService.context_flags({&"act3_started": true, &"sc103_mira_passed": true}, 3)
	assert_eq(CinematicService.plates_for(ed, d_passed, 3, _real_memory("sc_103"))[1].id, &"pl_e_fig_d", "monde D : sas Castellanos")


func test_epilogue_sequences_last_18_to_30_seconds() -> void:
	for world: StringName in [&"a", &"b", &"c", &"d"]:
		var def: CinematicDef = CinematicService.select_epilogue(world, _lib)
		assert_not_null(def)
		assert_eq(def.id, StringName("cin_e" + String(world)))
		assert_false(def.title_card)
		var ctx: Dictionary[StringName, Variant] = CinematicService.context_flags({&"act3_started": true}, 3)
		var without: Array[PlateDef] = CinematicService.plates_for(def, ctx, 3)
		assert_eq(without.size(), 3)
		assert_between(_duration(without, ctx, def.title_card), 18.0, 30.0)
		assert_between(_duration(def.plates, ctx, def.title_card), 18.0, 30.0, "avec PL-E-FIG")


func test_tool_constants_match_the_services() -> void:
	# Le générateur recopie des préfixes ; ils doivent rester ceux du service.
	assert_eq(String(M14._act_flag(3)), CinematicService.FLAG_ACT_PREFIX + "3")
	assert_true(M14._variant(&"audit").all_of.has(StringName(CinematicService.FLAG_VARIANT_PREFIX + "audit")))


# --- Annonces d'ambiance ----------------------------------------------------

func test_pa_lines_are_52_texts_without_game_information() -> void:
	var table: PaLineTable = PaLineTable.load_default()
	assert_not_null(table, "pa_lines.tres présent")
	assert_eq(table.lines.size(), 52)
	assert_eq(table.weights.size(), 52)
	var titles: PackedStringArray = []
	for key: String in _texts:
		if key.begins_with("doc_") and key.ends_with("_title"):
			titles.append(_texts[key].to_lower())
	var rule_code: RegEx = RegEx.create_from_string("\\bR\\d+\\b")
	var keys: Dictionary[String, bool] = {}
	for line: HallAnnouncementDef in table.lines:
		var key: String = line.text_key
		assert_false(keys.has(key), "clé unique %s" % key)
		keys[key] = true
		assert_string_starts_with(key, PaLineTable.KEY_PREFIX)
		assert_true(_texts.has(key), "%s dans fr.csv" % key)
		var text: String = _texts.get(key, "")
		assert_true(text.length() <= PaLineTable.MAX_CHARS, "%s ≤ 90 caractères" % key)
		assert_null(rule_code.search(text), "%s : aucun code de règle" % key)
		for title: String in titles:
			assert_false(text.to_lower().contains(title), "%s : aucun nom de document (%s)" % [key, title])
		assert_true(line.music_action.is_empty() or HallAnnouncementDef.MUSIC_ACTIONS.has(line.music_action))
		assert_eq(line.after_case, -1)
		assert_eq(line.at_minute, -1)
		assert_false(line.ends_shift)


func _eligible_keys(table: PaLineTable, ctx: Dictionary[StringName, Variant]) -> PackedStringArray:
	var keys: PackedStringArray = []
	for line: HallAnnouncementDef in table.eligible(ctx):
		keys.append(line.text_key)
	return keys


func test_pa_pools_by_act_day_event_world_and_night_shift() -> void:
	var table: PaLineTable = PaLineTable.load_default()
	var j5: PackedStringArray = _eligible_keys(table, PaLineTable.context(1, 5))
	assert_eq(j5.size(), 10, "Acte I hors J8–J10")
	for key: String in j5:
		assert_string_starts_with(key, "pa_a1_")
	assert_eq(_eligible_keys(table, PaLineTable.context(1, 9)).size(), 12, "J8–J10 : quai 2")
	assert_true(_eligible_keys(table, PaLineTable.context(2, 17)).has("pa_a2_08"), "couvre-feu J16–J20")
	assert_false(_eligible_keys(table, PaLineTable.context(2, 12)).has("pa_a2_08"))
	var j29: PackedStringArray = _eligible_keys(table, PaLineTable.context(3, 29))
	assert_true(j29.has("pa_a3_03") and j29.has("pa_a3_06") and j29.has("pa_a3_10"))
	assert_false(j29.has("pa_a3_05"), "démenti J21–J28 seulement")
	assert_false(_eligible_keys(table, PaLineTable.context(3, 22)).has("pa_a3_10"))
	var ev: Array[StringName] = [&"ev_06"]
	var crowd: PackedStringArray = _eligible_keys(table, PaLineTable.context(2, 12, ev))
	assert_true(crowd.has("pa_ev06"))
	assert_false(crowd.has("pa_ev02"))
	var world_d: PackedStringArray = _eligible_keys(table, PaLineTable.context(0, 31, [], &"d"))
	assert_eq(world_d, PackedStringArray(["pa_epi_d_01", "pa_epi_d_02"]), "J31 : lignes du monde seulement")
	var night: PackedStringArray = _eligible_keys(table, PaLineTable.context(0, 0, [], &"", true))
	assert_eq(night.size(), 4, "Garde : 4 lignes")
	for key: String in night:
		assert_string_starts_with(key, "pa_garde_")
	# Chaque événement de station a sa ligne, sauf EV-05 (coupure).
	for n: int in range(1, 10):
		var id: StringName = StringName("ev_%02d" % n)
		var only: Array[StringName] = [id]
		var got: bool = _eligible_keys(table, PaLineTable.context(0, 0, only)).has("pa_ev%02d" % n)
		assert_eq(got, n != 5, "%s : annonce d'ambiance" % id)


# --- Champs musicaux et portraits (D-194) ------------------------------------

func test_music_tension_floor_event_weights_and_announcement_actions() -> void:
	var expected_tension: Array[int] = [0, 0, 0, 1, 1, 1, 1, 2, 2, 3, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3]
	var data: DataCatalog = GF.data()
	for n: int in range(1, 31):
		var day: DayDef = data.get_day(n)
		assert_eq(day.music_tension, expected_tension[n - 1], "J%d : tension" % n)
		assert_eq(day.music_floor, {20: 1, 30: 2}.get(n, -1), "J%d : plancher" % n)
		for a: HallAnnouncementDef in day.announcements:
			assert_true(a.music_action.is_empty() or HallAnnouncementDef.MUSIC_ACTIONS.has(a.music_action))
			if a.ends_shift:
				assert_eq(a.music_action, HallAnnouncementDef.MUSIC_SILENCE, "J%d : les vitres s'éteignent" % n)
	for world: String in ["a", "b", "c", "d"]:
		var epi: DayDef = load("res://data/epilogue/day_31_%s.tres" % world)
		assert_eq(epi.music_tension, 0)
		assert_eq(epi.music_floor, -1)
	assert_eq(_announcement(data.get_day(27), "hall_j27_arbitre").music_action, HallAnnouncementDef.MUSIC_SWELL)
	assert_eq(_announcement(data.get_day(16), "hall_j16_curfew").music_action, HallAnnouncementDef.MUSIC_DROP)
	var weights: Dictionary[String, float] = {"ev_01": 0.1, "ev_02": 0.4, "ev_03": 0.5, "ev_04": 0.4, "ev_05": 0.0,
			"ev_06": 0.3, "ev_07": 0.4, "ev_08": 0.1, "ev_09": 0.5}
	for id: String in weights:
		var event: StationEventDef = load("res://data/events/%s.tres" % id)
		assert_almost_eq(event.music_weight, weights[id], 0.0001, id)


func _announcement(day: DayDef, key: String) -> HallAnnouncementDef:
	for a: HallAnnouncementDef in day.announcements:
		if a.text_key == key:
			return a
	return null


func test_portrait_whitelists_exclude_other_faces() -> void:
	var table: CharacterTableDef = CharacterTableDef.load_default()
	assert_not_null(table)
	var mazur: CharacterDef = table.character_of(&"sc_11")
	assert_false(mazur.allows_portrait(&"sc_29"), "Katya, la fille : pas le visage de Dariusz")
	assert_true(mazur.allows_portrait(&"sc_78"))
	var kerr: CharacterDef = table.character_of(&"sc_30")
	assert_false(kerr.allows_portrait(&"sc_31"), "homonyme")
	assert_true(kerr.allows_portrait(&"sc_69"))
	var lev: CharacterDef = table.character_of(&"sc_05")
	assert_true(lev.allows_portrait(&"sc_13"), "SC-13 : le visage de Lev (la photo est celle d'un autre)")
	for character: CharacterDef in table.characters:
		for case_id: StringName in character.portrait_cases:
			assert_true(character.case_ids.has(case_id), "%s ⊂ case_ids" % character.id)


# --- Déterminisme et données à jour -----------------------------------------

## Vue « données » d'une ressource : propriétés stockées, sous-ressources
## embarquées dépliées, ressources externes par chemin.
func _dump(value: Variant, top: bool = true) -> Variant:
	if value is Resource:
		var res: Resource = value
		if not top and not res.resource_path.is_empty() and not res.resource_path.contains("::"):
			return "ext:" + res.resource_path
		var out: Dictionary = {}
		for prop: Dictionary in res.get_property_list():
			var name: String = prop["name"]
			if not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE) or name.begins_with("resource_") or name == "script":
				continue
			out[name] = _dump(res.get(StringName(name)), false)
		return out
	if value is Array:
		var arr: Array = []
		for item: Variant in value:
			arr.append(_dump(item, false))
		return arr
	if value is Dictionary:
		var d: Dictionary = {}
		for k: Variant in value:
			d[k] = _dump(value[k], false)
		return d
	return value


func test_generator_is_deterministic_and_data_is_up_to_date() -> void:
	var first: Array[PlateDef] = M14.build_plates()
	var second: Array[PlateDef] = M14.build_plates()
	assert_eq(first.size(), 66)
	for i: int in first.size():
		var a: Variant = _dump(first[i])
		assert_eq(a, _dump(second[i]), "%s : deux constructions identiques" % first[i].id)
		var on_disk: PlateDef = load(PLATES_DIR.path_join("%s.tres" % first[i].id))
		assert_eq(a, _dump(on_disk), "%s : data/ à jour (relancer build_data)" % first[i].id)
	var pa: Variant = _dump(M14.build_pa_lines())
	assert_eq(pa, _dump(M14.build_pa_lines()))
	assert_eq(pa, _dump(PaLineTable.load_default()), "pa_lines.tres à jour")
	var built: CinematicLibraryDef = M14.build_cinematics(_all_plates())
	assert_eq(built.cinematics.size(), _lib.cinematics.size())
	for i: int in built.cinematics.size():
		var mine: Dictionary = _dump(built.cinematics[i])
		var disk: Dictionary = _dump(_lib.cinematics[i])
		assert_eq(mine, disk, "%s : cinematics.tres à jour" % built.cinematics[i].id)
