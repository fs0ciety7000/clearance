## M14 lot A — formats de données (B81, B91 ; ARCHITECTURE §12 ter.2, §12 ter.3) :
## ensembles musicaux (calage à la mesure, couches par niveau, masques,
## groupes, hystérésis), thèmes et bibliothèque (sélection par fin, variante,
## monde), cinématiques (sélection, planches par acte et condition, figures
## vues à la vitre, légendes), champs M14 des définitions existantes.
extends GutTest

const GF = preload("res://tests/helpers/generation_fixtures.gd")


# --- Musique -------------------------------------------------------------------------

func _layer(id: StringName, enter: int, exit: int = -1, exposed: bool = false, melodic: bool = false,
		power: bool = false, group: StringName = &"") -> MusicLayerDef:
	var l: MusicLayerDef = MusicLayerDef.new()
	l.id = id
	l.enter_level = enter
	l.exit_level = exit
	l.exposed = exposed
	l.melodic = melodic
	l.keeps_on_power_down = power
	l.group = group
	return l


## Ensemble de jeu canonique (MS-02 → MS-05, §2.3).
func _game_set(bpm: float = 80.0) -> MusicSetDef:
	var s: MusicSetDef = MusicSetDef.new()
	s.id = MusicLibraryDef.SET_ACT1
	s.tempo_bpm = bpm
	s.layers = [_layer(&"l0", 0, -1, true, false, true), _layer(&"l1", 1), _layer(&"l2", 2),
			_layer(&"l3", 3, 4, true, true), _layer(&"l4", 4)]
	return s


func test_set_timing_is_sample_exact_for_every_tempo() -> void:
	# §2.2 : tempos de MS-01 → MS-07 et des thèmes (TH-F10 à 72 BPM : 48 kHz seulement).
	for bpm: float in [60.0, 64.0, 75.0, 80.0, 96.0]:
		var s: MusicSetDef = _game_set(bpm)
		assert_true(s.is_sample_exact(32000), "%d BPM exact à 32 kHz" % bpm)
		assert_true(s.is_sample_exact(48000), "%d BPM exact à 48 kHz" % bpm)
		assert_eq(s.loop_samples(), s.samples_per_bar() * 16)
	var ms02: MusicSetDef = _game_set(80.0)
	assert_almost_eq(ms02.seconds_per_bar(), 3.0, 1e-6)
	assert_almost_eq(ms02.loop_seconds(), 48.0, 1e-6)
	assert_eq(ms02.samples_per_bar(), 96000, "3 s à 32 kHz")
	assert_eq(_game_set(64.0).samples_per_bar(48000), 180000, "3,75 s à 48 kHz")
	assert_false(_game_set(72.0).is_sample_exact(32000), "72 BPM : thème à 48 kHz seulement")
	assert_eq(ms02.bar_at(0.0), 0)
	assert_eq(ms02.bar_at(5.99), 1)
	assert_eq(ms02.bar_at(48.5), 0, "la boucle repart")
	assert_almost_eq(ms02.next_bar_time(4.2), 6.0, 1e-6)
	assert_almost_eq(ms02.next_bar_time(6.0), 9.0, 1e-6, "pile sur une mesure : la suivante")


func test_active_layers_follow_the_level_table() -> void:
	var s: MusicSetDef = _game_set()
	# §2.5 : N0 L0 ; N1 L0 L1 ; N2 + L2 ; N3 + L3 ; N4 : L3 sort, L4 entre.
	var expected: Array[PackedInt32Array] = [PackedInt32Array([0]), PackedInt32Array([0, 1]), PackedInt32Array([0, 1, 2]),
			PackedInt32Array([0, 1, 2, 3]), PackedInt32Array([0, 1, 2, 4])]
	for level: int in 5:
		assert_eq(s.active_layers(level), expected[level], "N%d" % level)
	assert_eq(s.active_layers(9), expected[4], "borné à N4")
	assert_eq(s.active_layers(-3), expected[0])
	assert_eq(s.active_layers(0, MusicSetDef.MASK_EXPOSED), PackedInt32Array([0, 3]), "briefing exposé : L0 + L3")
	assert_eq(s.active_layers(3, MusicSetDef.MASK_NO_MELODY), PackedInt32Array([0, 1, 2]), "inspection : sans L3")
	assert_eq(s.active_layers(0, MusicSetDef.MASK_EXPOSED | MusicSetDef.MASK_NO_MELODY), PackedInt32Array([0]))
	assert_eq(s.active_layers(4, MusicSetDef.MASK_POWER_DOWN), PackedInt32Array([0]), "coupure : L0 seule")
	s.max_level = 2
	assert_eq(s.active_layers(4), expected[2], "plafond de l'ensemble")


func test_groups_select_variant_layers() -> void:
	var s: MusicSetDef = MusicSetDef.new()
	s.id = MusicLibraryDef.SET_EVENING
	s.tempo_bpm = 60.0
	s.bars = 12
	s.layers = [_layer(&"bed", 0, -1, true, false, true), _layer(&"warm", 0, -1, true, false, false, MusicLibraryDef.GROUP_WARM),
			_layer(&"crisis", 0, -1, true, false, false, MusicLibraryDef.GROUP_CRISIS)]
	assert_eq(s.active_layers(0), PackedInt32Array([0]), "aucun groupe : lit commun seul")
	assert_eq(s.active_layers(0, 0, [MusicLibraryDef.GROUP_WARM]), PackedInt32Array([0, 1]))
	assert_eq(s.active_layers(0, 0, [MusicLibraryDef.GROUP_CRISIS]), PackedInt32Array([0, 2]))
	assert_eq(s.layer_index(&"crisis"), 2)
	assert_eq(s.layer_index(&"absent"), -1)
	assert_eq(MusicLibraryDef.world_group(&"d"), &"world_d")


func test_level_quantization_has_hysteresis() -> void:
	var s: MusicSetDef = _game_set()
	assert_eq(s.level_for(0.0, 0), 0)
	assert_eq(s.level_for(0.17, 0), 0, "0,15 + 0,05 non atteint")
	assert_eq(s.level_for(0.21, 0), 1)
	assert_eq(s.level_for(0.12, 1), 1, "redescend sous 0,10 seulement")
	assert_eq(s.level_for(0.09, 1), 0)
	assert_eq(s.level_for(0.95, 0), 4, "la quantification seule ne limite pas la vitesse")
	assert_eq(s.level_for(1.0, 4), 4)
	assert_eq(s.level_for(0.0, 4), 0)
	var previous: int = 0
	for i: int in 101:
		var lvl: int = s.level_for(i / 100.0, previous)
		assert_true(lvl >= previous, "monotone à la montée (%d)" % i)
		previous = lvl


func test_library_picks_set_and_theme() -> void:
	assert_eq(MusicLibraryDef.set_id_for_day(1), MusicLibraryDef.SET_ACT1)
	assert_eq(MusicLibraryDef.set_id_for_day(10), MusicLibraryDef.SET_ACT1)
	assert_eq(MusicLibraryDef.set_id_for_day(11), MusicLibraryDef.SET_ACT2)
	assert_eq(MusicLibraryDef.set_id_for_day(20), MusicLibraryDef.SET_ACT2)
	assert_eq(MusicLibraryDef.set_id_for_day(21), MusicLibraryDef.SET_ACT3)
	assert_eq(MusicLibraryDef.set_id_for_day(31, DayDef.MODE_EPILOGUE), MusicLibraryDef.SET_EPILOGUE)
	assert_eq(MusicLibraryDef.set_id_for_day(0, DayDef.MODE_GARDE), MusicLibraryDef.SET_GARDE)
	assert_eq(MusicLibraryDef.max_level_for(12, false), 4)
	assert_eq(MusicLibraryDef.max_level_for(12, true), 2, "Récit : N2")
	assert_eq(MusicLibraryDef.max_level_for(31, false), 2, "J31 : N2")
	var lib: MusicLibraryDef = MusicLibraryDef.new()
	lib.sets = [_game_set()]
	lib.themes = [_theme(&"th_f5c", [EndingService.F5_AIR], [&"c"]), _theme(&"th_f5b", [EndingService.F5_AIR], [&"b"]),
			_theme(&"th_f6", [EndingService.F6_DRIFT], []), _theme(&"th_f6t", [EndingService.F6_DRIFT], [&"t"]),
			_theme(&"th_f1", [EndingService.F1_ARRESTED], [])]
	var world: MusicThemeDef = _theme(&"th_ed", [], [])
	world.worlds = [&"d"]
	lib.themes.append(world)
	assert_eq(lib.get_set(MusicLibraryDef.SET_ACT1).id, MusicLibraryDef.SET_ACT1)
	assert_null(lib.get_set(MusicLibraryDef.SET_TITLE))
	assert_eq(lib.theme_for_ending(EndingService.F5_AIR, &"b").id, &"th_f5b")
	assert_eq(lib.theme_for_ending(EndingService.F6_DRIFT, &"t").id, &"th_f6t", "variante nommée d'abord")
	assert_eq(lib.theme_for_ending(EndingService.F6_DRIFT, &"j10").id, &"th_f6", "sinon thème générique")
	assert_eq(lib.theme_for_ending(EndingService.F1_ARRESTED, &"audit").id, &"th_f1")
	assert_null(lib.theme_for_ending(EndingService.F5_AIR, &""), "F5 d'un acte I–II simulé : aucun thème")
	assert_null(lib.theme_for_ending(&"demo_complete", &""))
	assert_eq(lib.theme_for_world(&"d").id, &"th_ed")
	assert_null(lib.theme_for_world(&"a"))
	assert_eq(lib.get_theme(&"th_f1").id, &"th_f1")


func _theme(id: StringName, endings: Array[StringName], variants: Array[StringName]) -> MusicThemeDef:
	var t: MusicThemeDef = MusicThemeDef.new()
	t.id = id
	t.endings = endings
	t.ending_variants = variants
	return t


func test_theme_sections_and_variants() -> void:
	var t: MusicThemeDef = _theme(&"th_f1", [EndingService.F1_ARRESTED], [])
	t.tempo_bpm = 60.0
	var main: AudioStreamWAV = AudioStreamWAV.new()
	var tail: AudioStreamWAV = AudioStreamWAV.new()
	var reduced: AudioStreamWAV = AudioStreamWAV.new()
	var okonkwo: AudioStreamWAV = AudioStreamWAV.new()
	t.stream = main
	t.tail_stream = tail
	t.reduced_fx_stream = reduced
	for row: Array in [[MusicSectionDef.OPENING, 0, 2], [MusicSectionDef.A, 2, 4], [MusicSectionDef.B, 6, 2]]:
		var sec: MusicSectionDef = MusicSectionDef.new()
		sec.id = row[0]
		sec.start_bar = row[1]
		sec.bars = row[2]
		t.sections.append(sec)
	var v: MusicThemeVariantDef = MusicThemeVariantDef.new()
	v.id = &"okonkwo"
	v.condition = FlagCondition.make([&"okonkwo_warned"])
	v.stream = okonkwo
	t.variants = [v]
	var none: Dictionary[StringName, Variant] = {}
	var warned: Dictionary[StringName, Variant] = {&"okonkwo_warned": true}
	assert_eq(t.main_bars(), 8, "ouverture + A + B")
	assert_almost_eq(t.seconds_per_bar(), 4.0, 1e-6)
	assert_eq(t.section(MusicSectionDef.A).start_bar, 2)
	assert_null(t.section(MusicSectionDef.TAIL))
	assert_eq(t.main_stream(none), main)
	assert_eq(t.main_stream(none, true), reduced, "effets visuels réduits (§2.11)")
	assert_eq(t.main_stream(warned), okonkwo, "variante okonkwo_warned")
	assert_eq(t.tail_for(warned), tail, "queue du thème si la variante n'en a pas")
	assert_eq(t.variant_for(warned).id, &"okonkwo")
	assert_null(t.variant_for(none))


# --- Cinématiques ---------------------------------------------------------------------

func _plate(id: StringName, caption: String, min_act: int = 1, max_act: int = 3) -> PlateDef:
	var p: PlateDef = PlateDef.new()
	p.id = id
	p.caption_key = caption
	p.min_act = min_act
	p.max_act = max_act
	return p


func _cinematic(id: StringName, endings: Array[StringName], variants: Array[StringName], plates: Array[PlateDef],
		acts: PackedInt32Array = PackedInt32Array()) -> CinematicDef:
	var c: CinematicDef = CinematicDef.new()
	c.id = id
	c.endings = endings
	c.ending_variants = variants
	c.acts = acts
	c.plates = plates
	return c


func _library() -> CinematicLibraryDef:
	var lib: CinematicLibraryDef = CinematicLibraryDef.new()
	var f1_3: PlateDef = _plate(&"pl_f1_3", "cin_f1_3", 1, 2)
	var f1_3b: PlateDef = _plate(&"pl_f1_3_borne", "cin_f1_3_borne", 3, 3)
	var f1_1: PlateDef = _plate(&"pl_f1_1", "cin_f1_1_double")
	f1_1.captions = [ConditionalKey.make("cin_f1_1_audit", FlagCondition.make([&"cin_variant_audit"]))]
	var f1_4: PlateDef = _plate(&"pl_f1_4", "cin_f1_4")
	f1_4.captions = [ConditionalKey.make("cin_f1_4_okonkwo", FlagCondition.make([&"okonkwo_warned"]))]
	lib.cinematics = [
		_cinematic(&"cin_f1", [EndingService.F1_ARRESTED], [], [f1_1, _plate(&"pl_f1_2", "cin_f1_2"), f1_3, f1_3b, f1_4]),
		_cinematic(&"cin_f4", [EndingService.F4_GLORY], [], [_plate(&"pl_f4_1", "cin_f4_1")], PackedInt32Array([3])),
		_cinematic(&"cin_f5b", [EndingService.F5_AIR], [&"b"], [_plate(&"pl_f5b_1", "cin_f5b_1")]),
		_cinematic(&"cin_f5c", [EndingService.F5_AIR], [&"c"], [_plate(&"pl_f5c_1", "cin_f5c_1")]),
		_cinematic(&"cin_f6e", [EndingService.F6_DRIFT], [], [_plate(&"pl_f6e_1", "cin_f6e_1")]),
		_cinematic(&"cin_f6t", [EndingService.F6_DRIFT], [&"t"], [_plate(&"pl_f6t_1", "cin_f6t_1")]),
	]
	var epi: CinematicDef = _cinematic(&"cin_ea", [], [], [_plate(&"pl_ea_1", "cin_ea_1"), _fig_plate(), _plate(&"pl_ea_3", "cin_ea_3")])
	epi.worlds = [&"a"]
	lib.cinematics.append(epi)
	return lib


func _slot() -> FigureSlotDef:
	var slot: FigureSlotDef = FigureSlotDef.new()
	slot.id = &"fg_figure31"
	slot.memory_cases = [ConditionalKey.make("sc_93b", FlagCondition.make([&"sc93_passed"])),
			ConditionalKey.make("sc_93a")]
	return slot


func _fig_plate() -> PlateDef:
	var p: PlateDef = _plate(&"pl_e_fig", "cin_e_fig")
	var slot: FigureSlotDef = _slot()
	slot.omit_plate_if_missing = true
	p.figures = [slot]
	return p


func test_select_by_ending_variant_and_act() -> void:
	var lib: CinematicLibraryDef = _library()
	var none: Dictionary[StringName, Variant] = {}
	assert_eq(CinematicService.select(EndingService.F1_ARRESTED, &"audit", none, 1, 9, lib).id, &"cin_f1")
	assert_eq(CinematicService.select(EndingService.F5_AIR, &"b", none, 2, 20, lib).id, &"cin_f5b")
	assert_eq(CinematicService.select(EndingService.F5_AIR, &"c", none, 3, 30, lib).id, &"cin_f5c")
	assert_null(CinematicService.select(EndingService.F5_AIR, &"", none, 2, 20, lib), "F5 de l'Acte II simulé : aucune")
	assert_eq(CinematicService.select(EndingService.F6_DRIFT, &"t", none, 3, 30, lib).id, &"cin_f6t", "variante nommée d'abord")
	assert_eq(CinematicService.select(EndingService.F6_DRIFT, &"j10", none, 1, 10, lib).id, &"cin_f6e")
	assert_null(CinematicService.select(EndingService.F4_GLORY, &"", none, 2, 20, lib), "F4 des actes I–II : écran seul")
	assert_eq(CinematicService.select(EndingService.F4_GLORY, &"", none, 3, 30, lib).id, &"cin_f4")
	assert_null(CinematicService.select(&"demo_complete", &"", none, 1, 10, lib), "fin de démo : aucune")
	assert_null(CinematicService.select(EndingService.F7_REOPENS, &"", none, 3, 30, lib), "pas de données : aucune")
	assert_eq(CinematicService.select_epilogue(&"a", lib).id, &"cin_ea")
	assert_null(CinematicService.select_epilogue(&"b", lib))
	assert_eq(lib.get_cinematic(&"cin_f4").id, &"cin_f4")


func test_plates_follow_act_conditions_and_captions() -> void:
	var lib: CinematicLibraryDef = _library()
	var def: CinematicDef = lib.get_cinematic(&"cin_f1")
	var none: Dictionary[StringName, Variant] = {}
	var early: Dictionary[StringName, Variant] = CinematicService.context_flags(none, 1, &"audit", 9)
	var plates: Array[PlateDef] = CinematicService.plates_for(def, early, 1)
	var ids: Array[StringName] = []
	for p: PlateDef in plates:
		ids.append(p.id)
	assert_eq(ids, [&"pl_f1_1", &"pl_f1_2", &"pl_f1_3", &"pl_f1_4"] as Array[StringName], "fin anticipée : rien de l'Acte III")
	assert_eq(CinematicService.caption_key(plates[0], early), "cin_f1_1_audit", "légende de la variante")
	assert_eq(CinematicService.caption_key(plates[3], early), "cin_f1_4")
	var late_flags: Dictionary[StringName, Variant] = {&"okonkwo_warned": true}
	var late: Dictionary[StringName, Variant] = CinematicService.context_flags(late_flags, 3, &"double", 30)
	plates = CinematicService.plates_for(def, late, 3)
	assert_eq(plates[2].id, &"pl_f1_3_borne", "Acte III : la borne jaune")
	assert_eq(CinematicService.caption_key(plates[0], late), "cin_f1_1_double")
	assert_eq(CinematicService.caption_key(plates[3], late), "cin_f1_4_okonkwo")
	assert_true(late.has(&"cin_act_3") and late.has(&"cin_variant_double") and late.has(&"cin_day_30"))
	assert_false(late_flags.has(&"cin_act_3"), "les drapeaux de la partie ne sont pas modifiés")
	assert_eq(plates[0].all_caption_keys(), PackedStringArray(["cin_f1_1_double", "cin_f1_1_audit"]))


## Mémoire réelle : Mira au J3 (SC-04, visière baissée par `appearance_overrides`).
func _mira_memory(lift: bool) -> Dictionary:
	var data: DataCatalog = GF.data()
	var day: DayDef = data.get_day(3)
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(4242, 3))
	var scripted: ScriptedCaseDef = null
	for s: ScriptedCaseDef in day.scripted_cases:
		if s.id == &"sc_04":
			scripted = s
	var g: GeneratedCase = builder.build(scripted.at_index)
	if lift:
		assert_true(g.case.remove_visor(), "SC-04 arrive visière baissée")
	return {"sc_93a": CaseMemory.snapshot(3, g.case, VerdictKind.Kind.APPROVE)}


func test_figures_are_the_faces_seen_or_silhouettes() -> void:
	var slot: FigureSlotDef = _slot()
	var none: Dictionary[StringName, Variant] = {}
	var down: Dictionary = _mira_memory(false)
	var app: PassengerAppearance = CinematicService.figure_appearance(slot, down, none)
	assert_not_null(app)
	assert_true(app.is_face_covered(), "visière jamais relevée : rendue baissée")
	var up: PassengerAppearance = CinematicService.figure_appearance(slot, _mira_memory(true), none)
	assert_false(up.is_face_covered(), "visière relevée à la vitre : visage")
	assert_eq(up.get_trait(PassengerAppearance.SLOT_HEADWEAR), PassengerAppearance.VISOR_UP)
	assert_null(CinematicService.figure_appearance(slot, {}, none), "REVOIR du Dossier : silhouette")
	var recalled: Dictionary = down.duplicate(true)
	(recalled["sc_93a"] as Dictionary)["recalled"] = true
	assert_null(CinematicService.figure_appearance(slot, recalled, none), "entrée recalculée : jamais vue")
	var passed: Dictionary[StringName, Variant] = {&"sc93_passed": true}
	assert_not_null(CinematicService.figure_appearance(slot, down, passed), "candidat suivant si le premier manque")
	# PL-E-FIG omise sans visage, gardée avec.
	var lib: CinematicLibraryDef = _library()
	var epi: CinematicDef = CinematicService.select_epilogue(&"a", lib)
	var flags: Dictionary[StringName, Variant] = CinematicService.context_flags(none, 3)
	assert_eq(CinematicService.plates_for(epi, flags, 3).size(), 2, "sans figure : PL-E-FIG omise")
	assert_eq(CinematicService.plates_for(epi, flags, 3, down)[1].id, &"pl_e_fig", "figure vue : PL-E-FIG en deuxième")


func test_plate_layer_and_label_defaults_respect_ds_ceilings() -> void:
	var p: PlateDef = PlateDef.new()
	assert_true(p.parallax_px <= PlateDef.PARALLAX_MAX_PX)
	assert_true(p.zoom_to <= PlateDef.ZOOM_MAX)
	assert_eq(PlateDef.CAPTION_MAX_CHARS, 70)
	var layer: PlateLayerDef = PlateLayerDef.new()
	assert_eq(layer.kind, PlateLayerDef.KIND_BG)
	assert_eq(layer.rect, Rect2(0.0, 0.0, 1.0, 1.0))
	assert_eq(PlateLayerDef.KINDS.size(), 4, "BG, MID, FIG, FX (HOLO et CAP : UI)")
	var slot: FigureSlotDef = FigureSlotDef.new()
	assert_eq(slot.render_size, Vector2i(512, 768), "studio en grand (§3.5)")
	assert_eq(PlateLabelDef.new().style, &"holo_small")
	assert_eq(CinematicLibraryDef.PATH, "res://data/cinematics/cinematics.tres")


# --- Champs M14 des définitions existantes (lot F : valeurs) ---------------------------

func test_m14_fields_default_to_neutral_on_real_data() -> void:
	var data: DataCatalog = GF.data()
	for day_number: int in data.days:
		var day: DayDef = data.days[day_number]
		assert_between(day.music_tension, 0, 3, "J%d music_tension" % day_number)
		assert_between(day.music_floor, -1, 4, "J%d music_floor" % day_number)
		for a: HallAnnouncementDef in day.announcements:
			assert_true(a.music_action == &"" or HallAnnouncementDef.MUSIC_ACTIONS.has(a.music_action),
					"J%d %s : music_action" % [day_number, a.text_key])
	var events: StationEventsDef = load(StationEventService.DEF_PATH) as StationEventsDef
	if events != null:
		for ev: StationEventDef in events.events:
			assert_between(ev.music_weight, 0.0, 1.0, "%s music_weight" % ev.id)
	var table: CharacterTableDef = CharacterTableDef.load_default()
	assert_not_null(table)
	for character: CharacterDef in table.characters:
		for case_id: StringName in character.portrait_cases:
			assert_true(character.case_ids.has(case_id), "%s : portrait_cases ⊂ case_ids" % character.id)
	var mira: CharacterDef = table.character_of(&"sc_04")
	assert_true(mira.allows_portrait(&"sc_04"), "liste vide : tous les cas")
	assert_false(mira.allows_portrait(&"sc_02"), "cas d'un autre personnage")
	mira = mira.duplicate() as CharacterDef
	mira.portrait_cases = [&"sc_22"]
	assert_false(mira.allows_portrait(&"sc_04"), "liste blanche")
	assert_true(mira.allows_portrait(&"sc_22"))
