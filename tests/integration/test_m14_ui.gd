## M14 lot D — interfaces (I42 → I48 ; M14 §3, §5, §7.3 ; ARCHITECTURE
## §12 ter.3) : enchaînement fin → cinématique → écran de fin (et J31 →
## cinématique → conclusion), aucune séquence quand la sélection n'en rend pas,
## appui / maintien 0,8 s / avance manuelle (horloge simulée, clavier et
## manette), carte de titre, figures en silhouette, effets (glass_off,
## holographie, `reduce_motion`, `holo_flicker`), pause du rendu 3D, thème
## lancé par l'`AudioDirector`, profil (`cinematics_seen`), REVOIR et
## portraits du Dossier, options, sous-titre des annonces d'ambiance, aucun
## texte brut. Sauvegardes et profil dans le dossier de test (`gut_pre_run`).
extends GutTest

## D-203 : la bibliothèque avant les `PlateDef`.
const _CINEMATIC_LIBRARY := preload("res://scripts/core/cinematic_library_def.gd")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const SEED: int = 20_871_315

var _saved_state: Dictionary = {}


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, false)
	_saved_state = GameState.to_save_dict()
	SaveService.remove_with_fallbacks(ProfileService.profile_path())
	DayScene.force_null_booth = true


func after_each() -> void:
	DayScene.force_null_booth = false
	SaveService.remove_with_fallbacks(ProfileService.profile_path())
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	get_tree().paused = false
	GameState.end_session()
	GameState.apply_save_dict(_saved_state)
	for key: StringName in [Settings.KEY_REDUCE_MOTION, Settings.KEY_CINEMATIC_ADVANCE, Settings.KEY_HOLO_FLICKER,
			Settings.KEY_SUBTITLES, Settings.KEY_CLOCK_SLOW_ACCESSIBILITY, Settings.KEY_MUSIC_DYNAMICS,
			Settings.KEY_MUSIC_INSPECTION_REDUCE, Settings.KEY_TEXT_SCALE]:
		Settings.clear_session_value(key)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


func _scene(day: int, act: int = 3) -> DayScene:
	GameState.new_campaign(SEED)
	GameState.current_day = day
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	GameState.set_flag(EndingService.FLAG_ACT2, act >= 2)
	GameState.set_flag(EndingService.FLAG_ACT3, act >= 3)
	return scene


func _press(action: StringName, pressed: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _pad(button: JoyButton, pressed: bool) -> void:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


# ---------------------------------------------------------------------------
# Enchaînements (I43)
# ---------------------------------------------------------------------------

func test_end_flow_plays_the_cinematic_then_the_unchanged_end_screen() -> void:
	var scene: DayScene = _scene(30)
	await wait_process_frames(2)
	scene.show_end(EndingService.F10_PONT)
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	assert_not_null(sequence, "cinématique avant l'écran de fin")
	assert_eq(scene.screen_history.back(), &"cinematic")
	assert_eq(sequence.def.id, &"cin_f10")
	assert_eq(sequence.ending, EndingService.F10_PONT, "fin lue par l'AudioDirector")
	assert_between(sequence.plates.size(), CinematicService.MIN_PLATES, CinematicService.MAX_PLATES)
	assert_true(sequence.has_title_card(), "carte de titre")
	var title_key: String = str(Campaign.epilogue(EndingService.F10_PONT)["title_key"])
	assert_eq((sequence.title_card.find_child("Title", true, false) as Label).text, UiText.t(title_key, ""), "titre de la fin")
	var finished: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	var total: float = sequence.total_duration()
	assert_between(total, 25.0, 45.0, "M-14 : 25 à 45 s aux durées par défaut")
	assert_eq(sequence.phase, CinematicScreen.Phase.TITLE)
	sequence.tick(DS.PLATE_TITLE_SEC + 0.01)
	assert_eq(sequence.index, 0, "première planche après 3,5 s")
	var guard: int = 0
	while is_instance_valid(sequence) and sequence.phase != CinematicScreen.Phase.DONE and guard < 400:
		sequence.tick(0.25)
		guard += 1
	assert_eq(finished, [false], "finished(false) : vue en entier")
	var end: EndScreen = scene.screen as EndScreen
	assert_not_null(end, "écran de fin ensuite")
	assert_eq(scene.screen_history.slice(-2), [&"cinematic", &"end"] as Array[StringName])
	assert_true(ProfileService.has_seen_cinematic(ProfileService.load_profile(), "cin_f10"), "cinematics_seen")


func test_no_cinematic_when_selection_returns_none() -> void:
	var scene: DayScene = _scene(4, 1)
	await wait_process_frames(2)
	scene.show_end(EndingService.F4_GLORY) # F4 des actes I–II : aucune séquence (simulation)
	assert_true(scene.screen is EndScreen, "écran de fin direct")
	assert_false(scene.screen_history.has(&"cinematic"))
	scene.show_end(Campaign.ENDING_DEMO_COMPLETE)
	assert_true(scene.screen is EndScreen, "fin de démo : pas de cinématique")


func test_early_ending_shows_nothing_of_act_three() -> void:
	var scene: DayScene = _scene(9, 1)
	GameState.set_flag(EndingService.FLAG_AUDIT_ARRESTED, true)
	scene.show_end(EndingService.F1_ARRESTED)
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	assert_not_null(sequence)
	for plate: PlateDef in sequence.plates:
		assert_lt(plate.min_act, 3, "%s : rien de l'Acte III" % plate.id)
	assert_eq(CinematicScreen.caption_text(sequence.plates[0], sequence.ctx), UiText.t("cin_f1_1_audit", ""), "légende de l'audit")
	sequence.skip_all()


func test_epilogue_world_cinematic_before_the_conclusion() -> void:
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F10_PONT, flags, Household.new(), {}, 1234, 30)
	assert_not_null(Campaign.start_epilogue(epi))
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	scene.show_epilogue_ending({})
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	assert_not_null(sequence, "CIN-EC avant la carte de conclusion")
	assert_eq(sequence.def.id, &"cin_ec")
	assert_false(sequence.has_title_card(), "J31 : pas de carte de titre (D-201)")
	assert_eq(sequence.index, 0, "première planche tout de suite")
	assert_between(sequence.total_duration(), 18.0, 30.0, "épilogue : 18 à 30 s")
	var shown: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: shown.append(skipped))
	sequence.skip_all()
	assert_eq(shown, [true])
	await wait_process_frames(2)
	assert_eq(scene.screen_history.back(), &"epilogue_conclusion", "puis la conclusion (inchangée)")


# ---------------------------------------------------------------------------
# Commandes : appui, maintien, avance manuelle (I42)
# ---------------------------------------------------------------------------

func _open(ending: StringName = EndingService.F9_STRIKE) -> CinematicScreen:
	var scene: DayScene = _scene(30)
	await wait_process_frames(2)
	scene.show_end(ending)
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	sequence.set_process(false) # horloge simulée
	return sequence


func test_press_advances_after_lock_and_caption_first() -> void:
	var sequence: CinematicScreen = await _open()
	assert_false(sequence.request_next(), "carte de titre : rien avant 0,6 s")
	sequence.tick(DS.PLATE_ADVANCE_LOCK + 0.01)
	assert_true(sequence.request_next(), "appui : carte de titre passée")
	assert_eq(sequence.index, 0)
	assert_false(sequence.request_next(), "verrou de 0,6 s sur chaque planche")
	sequence.tick(DS.PLATE_ADVANCE_LOCK + 0.01)
	if sequence.is_caption_revealing():
		assert_true(sequence.request_next(), "la légende se révèle d'abord")
		assert_eq(sequence.index, 0, "même planche")
		assert_false(sequence.is_caption_revealing())
	assert_true(sequence.request_next())
	assert_eq(sequence.index, 1, "planche suivante")
	sequence.skip_all()


func test_keyboard_hold_skips_everything_short_press_does_not() -> void:
	var sequence: CinematicScreen = await _open()
	var finished: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	sequence.tick(DS.PLATE_TITLE_SEC + 0.1)
	sequence.tick(DS.PLATE_ADVANCE_LOCK)
	_press(&"cancel", true)
	await wait_process_frames(2)
	assert_eq(sequence.hold_source, CinematicScreen.HOLD_CANCEL, "Échap : maintien commencé")
	sequence.tick(DS.CIN_SKIP_HOLD * 0.5)
	assert_almost_eq(sequence.hold_ring.progress, 0.5, 0.05, "anneau de progression")
	_press(&"cancel", false)
	await wait_process_frames(2)
	assert_true(finished.is_empty(), "relâché avant 0,8 s : rien n'est passé")
	assert_true(sequence.skip_prompt_visible, "l'invite « Maintenir pour passer » s'affiche")
	assert_false(get_tree().paused, "Échap n'ouvre pas la pause pendant la séquence")
	_press(&"cancel", true)
	await wait_process_frames(2)
	sequence.tick(DS.CIN_SKIP_HOLD + 0.01)
	assert_eq(finished, [true], "maintien 0,8 s : toute la séquence")
	await wait_process_frames(1)
	_press(&"cancel", false)


func test_pad_a_press_next_and_hold_skip() -> void:
	var sequence: CinematicScreen = await _open(EndingService.F10_PONT)
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	sequence.tick(DS.PLATE_TITLE_SEC + 0.01)
	sequence.tick(DS.PLATE_ADVANCE_LOCK + DS.DUR_SLOW + DS.DUR_PLATE_XFADE)
	if sequence.is_caption_revealing():
		sequence.request_next()
	var before: int = sequence.index
	_pad(JOY_BUTTON_A, true)
	await wait_process_frames(2)
	_pad(JOY_BUTTON_A, false)
	await wait_process_frames(2)
	assert_eq(sequence.index, before + 1, "Ⓐ : planche suivante")
	var finished: Array = []
	sequence.finished.connect(func(skipped: bool) -> void: finished.append(skipped))
	_pad(JOY_BUTTON_B, true)
	await wait_process_frames(2)
	sequence.tick(DS.CIN_SKIP_HOLD + 0.01)
	assert_eq(finished, [true], "Ⓑ maintenu : tout passer")
	_pad(JOY_BUTTON_B, false)


func test_skip_prompt_after_first_plate_unless_already_seen() -> void:
	var sequence: CinematicScreen = await _open()
	assert_false(sequence.skip_prompt_visible, "séquence nouvelle : pas d'invite d'emblée")
	sequence.tick(DS.PLATE_TITLE_SEC + 0.01)
	sequence.tick(DS.PLATE_ADVANCE_LOCK)
	sequence.advance()
	assert_true(sequence.skip_prompt_visible, "après la première planche")
	sequence.skip_all()
	var again: CinematicScreen = await _open()
	assert_true(again.already_seen, "profil : déjà vue")
	assert_true(again.skip_prompt_visible, "déjà vue : invite dès la première image")
	again.skip_all()


func test_manual_advance_waits_for_a_press() -> void:
	Settings.set_session_value(Settings.KEY_CINEMATIC_ADVANCE, Settings.CINEMATIC_MANUAL)
	var sequence: CinematicScreen = await _open()
	sequence.tick(DS.PLATE_TITLE_SEC + 0.01)
	assert_eq(sequence.index, 0)
	sequence.tick(60.0)
	assert_eq(sequence.index, 0, "manuelle : aucune avance automatique")
	assert_true(sequence.next_mark.visible, "« ▶ » sur la légende")
	assert_eq(sequence.next_mark.text, UiText.t("cin_next", ""))
	sequence.request_next()
	if sequence.index == 0:
		sequence.request_next() # la légende se révélait encore
	assert_eq(sequence.index, 1)
	sequence.skip_all()


func test_durations_follow_ds_and_slow_clock() -> void:
	var plate: PlateDef = PlateDef.new()
	assert_almost_eq(CinematicScreen.plate_duration(plate, "Court."), DS.PLATE_MIN_SEC, 0.001, "plancher de 6 s")
	var long_text: String = "x".repeat(70)
	assert_almost_eq(CinematicScreen.plate_duration(plate, long_text), DS.PLATE_BASE_SEC + 0.06 * 70, 0.001)
	plate.duration_sec = 8.0
	assert_almost_eq(CinematicScreen.plate_duration(plate, ""), 8.0, 0.001, "durée imposée par les données")
	Settings.set_session_value(Settings.KEY_CLOCK_SLOW_ACCESSIBILITY, true)
	assert_almost_eq(CinematicScreen.plate_duration(plate, ""), 12.0, 0.001, "horloge ralentie ×1,5")


# ---------------------------------------------------------------------------
# Planches, effets, accessibilité
# ---------------------------------------------------------------------------

func test_layers_paper_labels_and_glass_off_sequence() -> void:
	var sequence: CinematicScreen = await _open()
	sequence.jump_to(0, 0.0)
	var stage: CinematicScreen.PlateStage = sequence.stage
	assert_eq(stage.plate.id, &"pl_f9_1")
	assert_eq(stage.lit_layers.size(), 12, "douze vitres allumées")
	assert_eq(stage.lit_count(), 12, "toutes allumées au départ")
	for entry: Array in stage.layers:
		var node: CanvasItem = entry[0]
		if node is TextureRect:
			var mat: ShaderMaterial = node.material as ShaderMaterial
			assert_not_null(mat, "papier sur %s" % node.name)
			assert_eq(mat.shader.resource_path, PlatePaintStyle.PAPER_SHADER)
	var labels: Array[Node] = stage.find_children("Label_*", "Label", false, false)
	assert_eq(labels.size(), 12, "plaques 01 → 12 posées à l'exécution")
	assert_eq((labels[0] as Label).text, "01", "littéral")
	assert_eq(stage.holo_veils.size(), 12, "voiles holographiques sur les vitres")
	sequence.tick(DS.CIN_GLASS_OFF_DELAY + DS.CIN_GLASS_OFF_STEP * 2.0 + 0.01)
	assert_eq(stage.lit_count(), 9, "le 04, le 05, le 06 s'éteignent une à une")
	sequence.tick(8.0)
	sequence.skip_all()


func test_reduce_motion_freezes_parallax_zoom_and_switches_off_glass() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	Settings.set_session_value(Settings.KEY_HOLO_FLICKER, false)
	var sequence: CinematicScreen = await _open()
	sequence.jump_to(0, 0.0)
	var stage: CinematicScreen.PlateStage = sequence.stage
	assert_eq(stage.lit_count(), 0, "PL-F9-1 affichée directement éteinte")
	var scale0: Vector2 = stage.scale
	var pos0: Array[Vector2] = []
	for entry: Array in stage.layers:
		pos0.append((entry[0] as Control).position)
	sequence.tick(4.0)
	assert_eq(stage.scale, scale0, "aucun zoom")
	assert_almost_eq(stage.scale.x, stage.base_scale, 0.0001)
	for i: int in stage.layers.size():
		assert_eq((stage.layers[i][0] as Control).position, pos0[i], "aucune parallaxe")
	for veil: ColorRect in stage.holo_veils:
		var mat: ShaderMaterial = veil.material as ShaderMaterial
		assert_eq(float(mat.get_shader_parameter(&"flicker")), 0.0, "scintillement coupé (D-109)")
		assert_eq(float(mat.get_shader_parameter(&"plate_time")), CinematicScreen.FROZEN_TIME, "holographie figée")
	sequence.skip_all()


func test_motion_stays_within_ds_limits() -> void:
	var sequence: CinematicScreen = await _open()
	sequence.jump_to(1, 0.0)
	var stage: CinematicScreen.PlateStage = sequence.stage
	var start: Array[Vector2] = []
	for entry: Array in stage.layers:
		start.append((entry[0] as Control).position)
	sequence.tick(sequence.current_duration())
	assert_lte(stage.scale.x / stage.base_scale, DS.KEN_BURNS_MAX + 0.0001, "zoom ≤ 1,04")
	assert_gt(stage.scale.x / stage.base_scale, 1.0, "zoom lent")
	for i: int in stage.layers.size():
		var moved: float = ((stage.layers[i][0] as Control).position - start[i]).length() * (CinematicScreen.VIEW_LINES / CinematicScreen.PLATE_SIZE.y)
		assert_lte(moved, DS.PARALLAX_MAX_PX + 0.01, "parallaxe ≤ 12 px à 1080p")
	sequence.skip_all()


func test_holo_effects_are_recognised() -> void:
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	var seen: Dictionary = {}
	for def: CinematicDef in lib.cinematics:
		for plate: PlateDef in def.plates:
			if plate.holo_effect != &"":
				seen[plate.holo_effect] = true
	for effect: StringName in seen:
		assert_true(effect in [PlateDef.HOLO_GLASS_OFF_SEQUENCE, CinematicScreen.HOLO_WAVEFORM, CinematicScreen.HOLO_EYE,
				CinematicScreen.HOLO_RINGS], "effet %s reconnu" % effect)
	var sequence: CinematicScreen = await _open(EndingService.F8_REGISTRE)
	sequence.jump_to(0, 1.0)
	assert_not_null(sequence.stage.glyph, "PL-F8-1 : forme d'onde")
	assert_eq(sequence.stage.glyph.effect, CinematicScreen.HOLO_WAVEFORM)
	sequence.skip_all()


func test_figures_are_silhouettes_without_memory_and_requested_on_title_card() -> void:
	var scene: DayScene = _scene(30)
	GameState.set_flag(&"final3_dora", true)
	await wait_process_frames(2)
	scene.show_end(EndingService.F4_GLORY)
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	assert_not_null(sequence)
	assert_eq(sequence.phase, CinematicScreen.Phase.TITLE)
	assert_false(sequence.figure_textures.is_empty(), "figure demandée pendant la carte de titre")
	var slot: FigureSlotDef = sequence.plates[0].figures[0]
	var tex: Texture2D = sequence.figure_textures["%s/%s" % [sequence.plates[0].id, slot.id]]
	assert_eq(tex, PlateFigureService.silhouette_texture(slot), "headless / sans visage : silhouette de repli")
	sequence.jump_to(0)
	assert_not_null(sequence.stage.find_child("Figure_%s" % slot.id, false, false), "figure posée à son rect")
	sequence.skip_all()


func test_caption_style_contrast_and_deck_floor() -> void:
	var sequence: CinematicScreen = await _open()
	sequence.jump_to(0)
	var box: StyleBoxFlat = sequence.caption_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(box.bg_color, DS.SCRIM, "voile bg.void 72 %")
	# Pire cas : blanc sous le voile → contraste du texte primaire ≥ 7:1.
	var under: Color = Color.WHITE.lerp(Color(DS.SCRIM, 1.0), DS.SCRIM.a)
	assert_gte(_contrast(DS.TEXT_PRIMARY, under), 7.0, "≥ 7:1 sur toute image")
	assert_eq(sequence.caption_label.theme_type_variation, &"SubtitleText")
	assert_gte(sequence.caption_font_px(), roundi(DS.FS_SUBTITLE * DS.CIN_CAPTION_SCALE), "≥ 1,25 × sous-titre")
	await wait_process_frames(3)
	var safe: Rect2 = sequence.safe_rect()
	var r: Rect2 = sequence.caption_panel.get_rect()
	assert_true(safe.grow(1.0).encloses(r), "légende dans la zone sûre 16:10 %s ⊄ %s" % [r, safe])
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	await wait_process_frames(2)
	assert_gte(sequence.caption_font_px(), roundi(DS.FS_SUBTITLE * DS.CIN_CAPTION_SCALE * 1.5), "suit text_scale")
	sequence.skip_all()


static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


func test_no_raw_text_in_any_sequence() -> void:
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	for def: CinematicDef in lib.cinematics:
		for plate: PlateDef in def.plates:
			for key: String in plate.all_caption_keys():
				assert_true(UiText.has(key), "%s : légende %s traduite" % [plate.id, key])
			for lab: PlateLabelDef in plate.labels:
				var text: String = lab.display_text(func(k: String) -> String: return UiText.t(k, "") if UiText.has(k) else "")
				assert_false(text.is_empty(), "%s : étiquette %s" % [plate.id, lab.text_key])
				if not lab.literal:
					assert_ne(text, lab.text_key, "jamais la clé brute")
	for key: String in ["cin_skip_hold", "cin_skip_all", "cin_next", "cin_replay", "sub_pa_prefix", "opt_music_inspect",
			"opt_music_inspect_hint", "opt_music_reduced", "opt_music_normal", "opt_music_dynamics", "opt_music_dynamics_hint",
			"opt_music_dynamic", "opt_music_stable", "opt_cinematic_advance", "opt_cinematic_hint", "opt_cinematic_auto",
			"opt_cinematic_manual", "dos_portrait_hidden"]:
		assert_true(UiText.has(key), "clé d'interface %s" % key)
	var sequence: CinematicScreen = await _open()
	var hint: Label = sequence.skip_row.find_child("SkipHint", true, false) as Label
	assert_eq(hint.text, UiText.t("cin_skip_hold", ""))
	assert_eq(sequence.skip_button.text, UiText.t("cin_skip_all", ""))
	sequence.skip_all()


# ---------------------------------------------------------------------------
# Rendu 3D et musique
# ---------------------------------------------------------------------------

func test_booth_rendering_paused_during_the_sequence() -> void:
	DayScene.force_null_booth = false
	var scene: DayScene = _scene(30)
	await wait_process_frames(3)
	assert_not_null(scene.booth, "vraie bande 3D")
	assert_false(scene.booth.is_rendering_paused())
	scene.show_end(EndingService.F9_STRIKE)
	assert_true(scene.booth.is_rendering_paused(), "UPDATE_DISABLED pendant la cinématique")
	assert_eq(scene.booth_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED)
	(scene.screen as CinematicScreen).skip_all()
	assert_false(scene.booth.is_rendering_paused(), "rendu rétabli à la fin")
	assert_true(scene.screen is EndScreen)


func test_audio_director_starts_the_theme_and_keeps_it_under_the_end_screen() -> void:
	var scene: DayScene = _scene(30)
	await wait_process_frames(3)
	var audio: AudioDirector = scene.get_node(^"%AudioDirector") as AudioDirector
	scene.show_end(EndingService.F9_STRIKE)
	await wait_process_frames(3)
	var path: String = AudioDirector.theme_path_for_ending(EndingService.F9_STRIKE, &"")
	if path.is_empty() or not ResourceLoader.exists(path):
		pending("thèmes non rendus")
		(scene.screen as CinematicScreen).skip_all()
		return
	assert_eq(audio.music_state, &"cinematic", "le directeur audio reconnaît la cinématique")
	assert_eq(audio.theme_id, (load(path) as MusicThemeDef).id, "thème de F9")
	assert_true(audio.music.has_pending_theme() or audio.music.get_current_clip() == audio.theme_id, "thème après le fondu de 2 s")
	(scene.screen as CinematicScreen).skip_all()
	await wait_process_frames(3)
	assert_eq(audio.music_state, &"end", "le thème continue sous l'écran de fin")
	assert_true(audio.fade_out_music(DS.MUSIC_EXIT_FADE) >= 0.0)


func test_leaving_waits_for_the_music_fade_under_a_black_veil() -> void:
	var scene: DayScene = _scene(5, 1)
	await wait_process_frames(3)
	var audio: AudioDirector = scene.get_node(^"%AudioDirector") as AudioDirector
	var called: Array = []
	var playing: bool = audio.music != null and audio.music.is_playing()
	scene._leave_after_music_fade(func() -> void: called.append(true))
	if not playing:
		assert_eq(called, [true], "sans musique : tout de suite")
		return
	assert_true(called.is_empty(), "attend le fondu")
	assert_true(scene.leaving)
	assert_true(scene.blackout.visible, "voile noir")
	assert_true(get_tree().paused, "plus rien ne bouge pendant le fondu")
	scene._leave_after_music_fade(func() -> void: called.append(false))
	await wait_seconds(DS.MUSIC_EXIT_FADE + 0.3)
	assert_eq(called, [true], "une seule sortie, après 1,5 s")
	assert_false(get_tree().paused)


# ---------------------------------------------------------------------------
# Dossier : REVOIR, portraits (I46)
# ---------------------------------------------------------------------------

func _profile_with(ending: String, act: int, cinematic: String, met: Array = [], portraits: Dictionary = {}) -> void:
	var profile: Dictionary = ProfileService.empty_profile()
	profile["max_day_reached"] = 30
	profile["endings_seen"] = [{"id": ending, "variant": "", "act": act, "day": 30, "date": "2026-10-28T20:00:00", "count": 1,
			"last_date": "2026-10-28T20:00:00", "first_line_key": ""}]
	if not cinematic.is_empty():
		profile["cinematics_seen"] = [cinematic]
	profile["characters_met"] = met
	profile["portraits"] = portraits
	ProfileService.save_profile(profile)


func test_dossier_replay_only_seen_cinematics_with_silhouettes() -> void:
	_profile_with("f10_pont", 3, "")
	var dossier: DossierScreen = DossierScreen.new()
	add_child_autofree(dossier)
	await wait_process_frames(2)
	assert_true(dossier.replay_buttons.is_empty(), "séquence jamais vue : pas de REVOIR")
	dossier.queue_free()
	_profile_with("f10_pont", 3, "cin_f10")
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	var ds: DossierScreen = main.call(&"open_dossier") as DossierScreen
	await wait_process_frames(2)
	assert_not_null(ds.title_music, "musique du titre transmise")
	var b: Button = ds.replay_buttons.get("cin_f10", null)
	assert_not_null(b, "REVOIR sur la fin vue")
	assert_eq(b.text, UiText.t("cin_replay", ""))
	b.pressed.emit()
	var sequence: CinematicScreen = ds.replay
	assert_not_null(sequence, "cinématique par-dessus le Dossier")
	assert_false(sequence.record_seen, "rien d'inscrit")
	assert_true(sequence.memory.is_empty(), "aucune mémoire de partie : silhouettes")
	assert_true(sequence.skip_prompt_visible, "déjà vue : invite tout de suite")
	assert_eq(sequence.get_parent(), ds)
	_press(&"cancel", true)
	await wait_process_frames(2)
	assert_false(ds.is_closing(), "Ⓑ ne ferme pas le Dossier sous la séquence")
	sequence.tick(DS.CIN_SKIP_HOLD + 0.01)
	_press(&"cancel", false)
	await wait_process_frames(3)
	assert_null(ds.replay, "retour au Dossier")
	assert_eq(get_viewport().gui_get_focus_owner(), b, "focus rendu à REVOIR")


func test_dossier_portraits_and_initials_fallback() -> void:
	var table: CharacterTableDef = CharacterTableDef.load_default()
	var chr_seen: CharacterDef = table.character_of(&"sc_01")
	var chr_hidden: CharacterDef = table.character_of(&"sc_02")
	assert_not_null(chr_seen)
	var app: PassengerAppearance = PlateFigureService.anonymous_appearance()
	var portraits: Dictionary = {String(chr_seen.id): {"appearance": app.serialize(), "visor": "none", "case_id": "sc_01", "day": 1, "act": 1}}
	_profile_with("f3_family_lost", 1, "", ["sc_01", "sc_02"], portraits)
	var dossier: DossierScreen = DossierScreen.new()
	add_child_autofree(dossier)
	await wait_process_frames(2)
	dossier.show_tab(DossierScreen.TAB_PEOPLE)
	await wait_process_frames(2)
	assert_not_null(dossier.portrait_service, "PortraitService du Dossier")
	assert_eq(dossier.portrait_service.size, PortraitService.DOSSIER_SIZE, "vignettes 128×160")
	assert_eq(dossier.portrait_service.get_parent(), dossier, "libéré avec l'écran")
	var card_seen: Control = dossier.find_child("Person_%s" % chr_seen.id, true, false) as Control
	var frame: DossierScreen.PortraitFrame = card_seen.find_child("Portrait", true, false) as DossierScreen.PortraitFrame
	assert_not_null(frame, "portrait vu à la vitre")
	assert_not_null(frame.texture_rect.texture)
	assert_eq(frame.texture_rect.texture.get_size(), Vector2(PortraitService.DOSSIER_SIZE))
	assert_not_null(card_seen.find_child("Initials", true, false), "initiales gardées")
	assert_gte(frame.get_combined_minimum_size().x * 1280.0 / 1920.0, 72.0, "≥ 72 px au Deck")
	if chr_hidden != null and chr_hidden.id != chr_seen.id:
		var card_hidden: Control = dossier.find_child("Person_%s" % chr_hidden.id, true, false) as Control
		assert_null(card_hidden.find_child("Portrait", true, false), "jamais vu : pas de portrait")
		var badge: Control = card_hidden.find_child("Initials", true, false) as Control
		assert_not_null(badge, "repli : initiales")
		assert_eq(badge.tooltip_text, UiText.t("dos_portrait_hidden", ""))


# ---------------------------------------------------------------------------
# Options (I44) et annonces d'ambiance (I45)
# ---------------------------------------------------------------------------

func test_options_have_the_three_m14_settings() -> void:
	var options: OptionsPanel = OptionsPanel.new()
	add_child_autofree(options)
	await wait_process_frames(1)
	for key: StringName in [Settings.KEY_MUSIC_INSPECTION_REDUCE, Settings.KEY_MUSIC_DYNAMICS, Settings.KEY_CINEMATIC_ADVANCE]:
		assert_true(options.controls.has(key), "réglage %s" % key)
		assert_eq(options.controls[key].focus_mode, Control.FOCUS_ALL, "manette")
	var reduce: Button = options.controls[Settings.KEY_MUSIC_INSPECTION_REDUCE] as Button
	assert_eq(reduce.text, UiText.t("opt_music_reduced", ""))
	assert_eq(reduce.button_pressed, Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE), "réduite par défaut")
	var group: ButtonGroup = reduce.button_group
	(group.get_buttons()[1] as Button).button_pressed = true
	assert_false(Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE), "NORMALE")
	var dyn: Button = options.controls[Settings.KEY_MUSIC_DYNAMICS] as Button
	(dyn.button_group.get_buttons()[1] as Button).button_pressed = true
	assert_true(Settings.is_music_stable(), "STABLE")
	var cin: Button = options.controls[Settings.KEY_CINEMATIC_ADVANCE] as Button
	(cin.button_group.get_buttons()[1] as Button).button_pressed = true
	assert_true(Settings.is_cinematic_manual(), "MANUELLE")
	(cin.button_group.get_buttons()[0] as Button).button_pressed = true
	assert_false(Settings.is_cinematic_manual(), "AUTOMATIQUE")
	(dyn.button_group.get_buttons()[0] as Button).button_pressed = true
	(group.get_buttons()[0] as Button).button_pressed = true
	Settings.save_settings()


func test_ambient_announcement_subtitle_respects_the_setting() -> void:
	var scene: DayScene = _scene(3, 1)
	await wait_process_frames(3)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	var key: String = "pa_a1_01"
	assert_true(UiText.has(key), "ligne d'ambiance du lot E")
	EventBus.ambient_announced.emit(key, 4.0)
	assert_true(ui.subtitles.visible, "sous-titre affiché")
	assert_eq(ui.subtitles.get_tag(), UiText.t("sub_pa_prefix", ""), "« [Haut-parleur] »")
	assert_eq(ui.subtitles.get_text(), "« %s »" % UiText.t(key, ""))
	assert_false(ui.pa_strip.visible, "jamais sur le bandeau HAUT-PARLEUR · HALL")
	ui.subtitles.visible = false
	EventBus.ambient_announced.emit("pa_inconnue_xyz", 4.0)
	assert_false(ui.subtitles.visible, "clé non traduite : rien")
	Settings.set_session_value(Settings.KEY_SUBTITLES, false)
	await wait_process_frames(1)
	EventBus.ambient_announced.emit(key, 4.0)
	assert_false(ui.subtitles.visible, "sous-titres coupés : rien (ni toast)")
