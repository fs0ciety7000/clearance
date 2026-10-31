## M12 lot C — écrans et interfaces (UI_FLOW §8.6, §9.4 ; M12 §7.1 I28 → I34) :
## titre (Garde de nuit, Dossier), accueil de la Garde (graine du jour, code
## libre validé), Garde complète au guichet sur une graine (HUD, directive,
## Rulebook, fin de garde, records), épilogue J31 (carte, briefing,
## conclusion), Dossier (anti-spoiler D-131), bandeau d'événement, listes
## nommées, comparateur en panne, écran de fin (UN AN PLUS TARD), Charger
## (puce ÉPILOGUE). Focus initial et retour Ⓑ de chaque nouvel écran.
## Profil et sauvegardes dans le dossier de test (`SaveService.use_root`,
## `gut_pre_run.gd`), jamais dans `user://saves`.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const GARDE_CODE: String = "K2Q-9TX"

var _saved_state: Dictionary = {}


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	_saved_state = GameState.to_save_dict()
	_clear_profile()
	DayScene.pending_garde_run = null
	DayScene.force_null_booth = true
	GardeScreen.open_on_title = false


func after_each() -> void:
	DayScene.force_null_booth = false
	_clear_profile()
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	DayScene.pending_garde_run = null
	GardeScreen.open_on_title = false
	get_tree().paused = false
	GameState.end_session()
	GameState.apply_save_dict(_saved_state)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	Settings.clear_session_value(Settings.KEY_TEXT_SCALE)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


func _clear_profile() -> void:
	SaveService.remove_with_fallbacks(ProfileService.profile_path())


func _focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventAction = InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)


## Choix émis par `finished` (l'écran se libère en fermant : pas de `watch_signals`).
func _capture_finished(screen: ScreenBase) -> Array[StringName]:
	var choices: Array[StringName] = []
	screen.finished.connect(func(choice: StringName) -> void: choices.append(choice))
	return choices


func _main() -> Control:
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	return main


## Profil d'une partie terminée (fin `ending` à l'acte `act`) et de quelques
## personnages croisés ; épilogue débloqué si `act` = 3.
func _profile(ending: String = "", act: int = 1, met: Array = []) -> Dictionary:
	var profile: Dictionary = ProfileService.empty_profile()
	profile["max_day_reached"] = 30 if act == 3 else (12 if act == 2 else 5)
	if not ending.is_empty():
		profile["endings_seen"] = [{"id": ending, "variant": "", "act": act, "day": 30 if act == 3 else 6,
				"date": "2026-10-28T20:00:00", "count": 2, "last_date": "2026-10-28T20:00:00", "first_line_key": ""}]
	profile["characters_met"] = met
	if act == 3 and not ending.is_empty():
		var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
		var epi: Dictionary = EpilogueService.make_seed(StringName(ending), flags, Household.new(), {}, 77, 30)
		if not epi.is_empty():
			profile["epilogues"] = {EpilogueService.profile_key(epi): {"world": epi["world"], "key": epi["ending_key"], "seed": epi,
					"first_date": "", "count": 0, "last_date": "", "last_lines": []}}
			profile["epilogue_unlocked"] = true
	ProfileService.save_profile(profile)
	return ProfileService.load_profile()


## Verdict juste et documenté (discordances épinglées, question posée).
func _judge(scene: DayScene, correct: bool = true) -> void:
	EventBus.next_case_requested.emit()
	var dc: DayController = scene.day_controller
	var c: Case = dc.current_case
	assert_not_null(c, "passager construit")
	if c == null:
		return
	EventBus.passenger_arrived.emit(c.case_id)
	var expected: VerdictKind.Kind = dc.current_key.expected_verdict
	var kind: VerdictKind.Kind = expected
	if not correct:
		kind = VerdictKind.Kind.DENY if expected == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE
	var verdict: Verdict = Verdict.new(c.case_id, kind)
	for violation: Violation in dc.current_key.expected_violations:
		if not violation.refs.is_empty():
			var d: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[violation.refs.size() - 1])
			d.confirmed = true
			verdict.flagged.append(d)
	verdict.questions_asked = [&"purpose"]
	EventBus.verdict_stamped.emit(verdict)
	EventBus.passenger_departed.emit(c.case_id)


# ---------------------------------------------------------------------------
# Titre (I28)
# ---------------------------------------------------------------------------

func test_title_locks_garde_and_dossier_on_a_blank_profile() -> void:
	var main: Control = await _main()
	var garde: Button = main.get(&"garde_button")
	var dossier: Button = main.get(&"dossier_button")
	assert_true(garde.disabled, "Garde grisée avant le J1 (D-128)")
	assert_eq(garde.focus_mode, Control.FOCUS_NONE, "jamais focalisée")
	assert_true((main.get(&"garde_locked_label") as Label).visible, "mention « Terminez votre premier jour »")
	assert_true(dossier.disabled, "Dossier grisé sans fin ni personnage")
	assert_true((main.get(&"dossier_locked_label") as Label).visible, "« Aucun dossier. »")


func test_title_opens_garde_and_dossier_once_unlocked_and_back_returns() -> void:
	_profile("f3_family_lost", 1, ["sc_01"])
	var main: Control = await _main()
	var garde: Button = main.get(&"garde_button")
	var dossier: Button = main.get(&"dossier_button")
	assert_false(garde.disabled, "Garde ouverte (max_day_reached ≥ 2)")
	assert_false(dossier.disabled, "Dossier ouvert (une fin vue)")
	assert_false((main.get(&"garde_locked_label") as Label).visible)
	var screen: GardeScreen = main.call(&"open_garde")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), screen.daily_button, "focus initial : JOUER LA GRAINE DU JOUR")
	_press(&"ui_cancel")
	await wait_process_frames(3)
	assert_null(main.get(&"screen"), "Ⓑ : retour au titre")
	assert_eq(_focus_owner(), garde, "focus rendu à GARDE DE NUIT")
	var ds: DossierScreen = main.call(&"open_dossier")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), ds.tab_buttons[DossierScreen.TAB_ENDINGS], "focus initial : onglet FINS")
	_press(&"ui_cancel")
	await wait_process_frames(3)
	assert_eq(_focus_owner(), dossier, "Ⓑ : focus rendu au DOSSIER")


# ---------------------------------------------------------------------------
# Accueil de la Garde (I31)
# ---------------------------------------------------------------------------

func test_garde_screen_validates_free_codes() -> void:
	var screen: GardeScreen = GardeScreen.new()
	screen.daily_code = "NUIT-2026-10-29"
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_true(screen.play_code_button.disabled, "rien de saisi : JOUER CE CODE inactif")
	screen.set_code_text("k2q9tx")
	assert_eq(screen.free_code, "K2Q-9TX", "casse et tiret indifférents")
	assert_false(screen.play_code_button.disabled)
	screen.set_code_text("K2O-9TX")
	assert_eq(screen.free_code, "", "O refusé")
	assert_eq(screen.status_text(), UiText.t("garde_seed_invalid", ""), "message : ni O, ni I, ni 0, ni 1")
	assert_true(screen.play_code_button.disabled)
	screen.set_code_text("K2Q9")
	assert_true(screen.status_text().contains("6"), "longueur : %s" % screen.status_text())
	var drawn: String = screen.fill_random(12345)
	assert_eq(screen.free_code, drawn, "tirage au hasard valide")
	watch_signals(screen)
	screen.play_free()
	assert_signal_emitted_with_parameters(screen, "start_requested", [drawn])
	assert_eq(screen.daily_summary({}, "NUIT-2026-10-29"), UiText.t("garde_daily_none", ""), "graine du jour jamais jouée")


func test_garde_screen_text_scale_150_fits_the_deck() -> void:
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	_profile("f3_family_lost", 1)
	var screen: GardeScreen = GardeScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(3)
	for b: Button in [screen.daily_button, screen.play_code_button, screen.random_button, screen.back_button]:
		assert_gte(b.size.y, float(DS.HIT_TARGET_MIN), "%s ≥ 40 px" % b.name)
	assert_lte(screen.get_combined_minimum_size().x, 1920.0 + 1.0, "aucun débordement horizontal au texte 1,5")


# ---------------------------------------------------------------------------
# Garde complète au guichet (I31)
# ---------------------------------------------------------------------------

func test_garde_full_flow_hud_directive_rulebook_end_and_records() -> void:
	if GardeService.load_def() == null:
		pending("données de Garde absentes")
		return
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	var ui: ComparisonUI = scene.ui as ComparisonUI
	assert_eq(scene.session, GameState.SESSION_GARDE)
	assert_not_null(scene.garde_hud, "HUD de Garde")
	assert_true(ui.top_bar.garde_mode)
	assert_eq(ui.top_bar.get_errors_text(), "0/3")
	assert_eq(ui.top_bar.get_clock_text(), "22:00", "horloge cosmétique")
	assert_true(ui.top_bar.close_button.visible, "TERMINER LA GARDE proposé")
	assert_eq(ui.top_bar.close_button.text, UiText.t("garde_end_button", ""))
	var run: GardeRun = scene.garde_run
	var directives: Array = []
	var on_directive: Callable = func(n: int, unit: StringName, action: StringName) -> void: directives.append([n, unit, action])
	EventBus.garde_directive.connect(on_directive)
	for i: int in run.def.directive_every:
		_judge(scene)
		await wait_process_frames(1)
	EventBus.garde_directive.disconnect(on_directive)
	assert_eq(directives.size(), 1, "une directive après %d passagers" % run.def.directive_every)
	assert_eq(ui.top_bar.get_score_text(), str(run.score))
	assert_eq(ui.top_bar.get_clock_text(), UiText.clock(posmod(run.clock_minute(), 1440)), "horloge modulo 24 h")
	var card: GardeDirectiveCard = scene.garde_hud.card
	assert_not_null(card, "carte DIRECTIVE DE GARDE N° 1")
	await wait_process_frames(2)
	assert_eq(_focus_owner(), card.ok_button, "focus sur COMPRIS (Ⓐ ferme la carte)")
	var unit: GardeUnitDef = run.def.get_unit(StringName(directives[0][1]))
	var rule_id: StringName = unit.rule_ids()[0]
	# Le passager suivant applique la directive : règle NOUVEAU au Rulebook, surlignée.
	_judge(scene)
	await wait_process_frames(2)
	assert_true(not is_instance_valid(card) or card.is_dismissed(), "carte retirée au passager suivant")
	var rule_card: RuleCardView = ui.rulebook.get_rule_card(rule_id)
	assert_not_null(rule_card, "règle de la directive au Rulebook")
	if rule_card != null:
		assert_true(rule_card.entry.is_new, "badge NOUVEAU")
		assert_gt(rule_card.glow, 0.0, "règle surlignée")
	# Trois erreurs : fin de garde, records, écran FIN DE GARDE.
	for i: int in 3:
		if scene.day_controller.phase == DayPhase.Kind.SUMMARY:
			break
		_judge(scene, false)
		await wait_process_frames(1)
	assert_eq(scene.day_controller.phase, DayPhase.Kind.SUMMARY, "3ᵉ erreur → fin")
	await wait_seconds(DayScene.SIREN_DELAY_SEC + 0.3)
	var end: GardeEndScreen = scene.screen as GardeEndScreen
	assert_not_null(end, "écran FIN DE GARDE")
	if end == null:
		return
	await wait_process_frames(2)
	assert_eq(_focus_owner(), end.replay_button, "focus : REJOUER CETTE GARDE")
	assert_eq(end.code(), GARDE_CODE)
	assert_eq((end.record.get("errors", []) as Array).size(), 3, "les trois erreurs")
	assert_true(end.badges.get("new_record", false), "premier score = nouveau record")
	var profile: Dictionary = ProfileService.load_profile()
	assert_eq((profile["best_runs"] as Array).size(), 1, "record inscrit au profil")
	assert_eq(str((profile["best_runs"] as Array)[0]["seed_code"]), GARDE_CODE)
	var choices: Array[StringName] = _capture_finished(end)
	_press(&"ui_cancel")
	await wait_process_frames(2)
	assert_eq(choices, [&"title"] as Array[StringName], "Ⓑ : retour au titre")


func test_garde_end_requested_from_the_bar_is_confirmed_and_counts() -> void:
	if GardeService.load_def() == null:
		pending("données de Garde absentes")
		return
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	_judge(scene)
	await wait_process_frames(1)
	var dialog: ConfirmDialog = scene.request_end_garde()
	assert_not_null(dialog, "confirmation « Terminer la garde ? »")
	await wait_process_frames(2)
	dialog.accept()
	await wait_process_frames(1)
	assert_true(scene.garde_run.ended)
	assert_eq(scene.garde_run.end_reason, GardeRun.END_QUIT)
	await wait_seconds(DayScene.SIREN_DELAY_SEC + 0.3)
	var end: GardeEndScreen = scene.screen as GardeEndScreen
	assert_not_null(end)
	if end != null:
		assert_eq((end.get_node("%Reason") if end.has_node("%Reason") else end.find_child("Reason", true, false) as Label).text,
				UiText.t("garde_end_quit", ""), "raison : à votre demande")


func test_pause_offers_end_garde_in_two_steps() -> void:
	var pause: PauseMenu = PauseMenu.new()
	pause.garde_mode = true
	add_child_autofree(pause)
	await wait_process_frames(2)
	assert_true(pause.end_garde_button.visible)
	watch_signals(pause)
	pause.open()
	pause.end_garde_button.pressed.emit()
	assert_signal_not_emitted(pause, "end_garde_requested", "premier appui : confirmation")
	pause.end_garde_button.pressed.emit()
	assert_signal_emitted(pause, "end_garde_requested")
	assert_false(get_tree().paused)


# ---------------------------------------------------------------------------
# Épilogue J31 (I29, I30)
# ---------------------------------------------------------------------------

func test_epilogue_intro_briefing_shift_and_conclusion() -> void:
	var def: EpilogueDef = EpilogueService.load_def()
	if def == null or def.worlds.size() < 4:
		pending("données d'épilogue absentes")
		return
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F10_PONT, flags, Household.new(), {}, 1234, 30)
	assert_not_null(Campaign.start_epilogue(epi))
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	var intro: EpilogueScreen = scene.screen as EpilogueScreen
	assert_not_null(intro, "carte UN AN PLUS TARD")
	assert_eq(_focus_owner(), intro.continue_button, "focus : CONTINUER")
	intro.continue_button.pressed.emit()
	await wait_process_frames(3)
	assert_not_null(scene.briefing, "briefing du J31")
	assert_eq(scene.briefing.epilogue_world, "c", "monde C (F10)")
	assert_eq((scene.briefing.find_child("DayTitle", true, false) as Label).text, UiText.t("epi_title", ""))
	assert_not_null(scene.briefing.find_child("EpilogueTiles", true, false), "tuiles sans chrono ni économie")
	var ui: ComparisonUI = scene.ui as ComparisonUI
	assert_true(ui.top_bar.untimed, "horloge sans alerte")
	assert_eq(ui.top_bar.get_location_text(), UiText.t("epi_eyebrow_c", ""))
	scene.briefing.close()
	await wait_process_frames(2)
	for i: int in scene.day_controller.day.passenger_count:
		_judge(scene)
		await wait_process_frames(1)
	assert_eq(scene.day_controller.phase, DayPhase.Kind.SUMMARY, "fin à la file vide")
	await wait_seconds(DayScene.SIREN_DELAY_SEC + 0.3)
	# M14 : la cinématique du monde (CIN-EC) d'abord, passée ici (test_m14_ui).
	var sequence: CinematicScreen = scene.screen as CinematicScreen
	assert_not_null(sequence, "cinématique du monde avant la conclusion")
	if sequence != null:
		sequence.skip_all()
	await wait_process_frames(2)
	var conclusion: EpilogueScreen = scene.screen as EpilogueScreen
	assert_not_null(conclusion, "carte de conclusion")
	if conclusion == null:
		return
	assert_eq(conclusion.mode, EpilogueScreen.Mode.CONCLUSION)
	assert_gt(conclusion.line_labels.size(), 0, "lignes de conclusion")
	assert_true(conclusion.is_reveal_done(), "animations réduites : tout est affiché")
	await wait_process_frames(2)
	assert_eq(_focus_owner(), conclusion.continue_button, "focus : RETOUR AU TITRE")
	var profile: Dictionary = ProfileService.load_profile()
	var entry: Dictionary = (profile["epilogues"] as Dictionary).get(EpilogueService.profile_key(epi), {})
	assert_eq(SaveService.as_int(entry.get("count", 0)), 1, "épilogue joué au profil : %s / %s" % [(profile["epilogues"] as Dictionary).keys(), scene.epilogue_card.get("profile_key", "?")])
	var choices: Array[StringName] = _capture_finished(conclusion)
	_press(&"ui_cancel")
	await wait_process_frames(2)
	assert_eq(choices, [&"title"] as Array[StringName], "Ⓑ : retour au titre")


func test_conclusion_card_reveals_lines_and_farewell() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, false)
	var screen: EpilogueScreen = EpilogueScreen.new()
	screen.setup_conclusion({"title_key": "epi_title", "eyebrow_key": "epi_eyebrow_b", "name_key": "dos_world_b", "tally_key": "epi_tally",
			"tally_args": [2], "lines": PackedStringArray(["epi_f9_open", "epi_b_yara_passed", "epi_f9_close"]), "args": {},
			"farewell_key": "epi_farewell_mira", "world": "b"})
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(screen.line_labels.size(), 3)
	assert_false(screen.is_reveal_done(), "révélation lente")
	assert_eq(_focus_owner(), screen.skip_button, "focus : TOUT AFFICHER")
	_press(&"ui_cancel")
	await wait_process_frames(2)
	assert_true(screen.is_reveal_done(), "Ⓑ : tout afficher d'abord")
	assert_eq((screen.find_child("Tally", true, false) as Label).text, UiText.tf("epi_tally", [2], ""))
	assert_not_null(screen.find_child("Farewell", true, false), "réplique Tessar de la figure")


func test_end_screen_offers_the_epilogue_only_after_act_three() -> void:
	var end: EndScreen = EndScreen.new()
	end.setup(EndingService.F10_PONT, [], Household.new(), 0, {&"act2_started": true, &"act3_started": true}, 0.9)
	add_child_autofree(end)
	await wait_process_frames(2)
	assert_true(end.has_epilogue())
	assert_not_null(end.epilogue_button)
	assert_null(end.locked_hint)
	end.offer_epilogue()
	await wait_process_frames(2)
	assert_true(end.epilogue_button.visible, "UN AN PLUS TARD affiché")
	assert_eq(_focus_owner(), end.epilogue_button, "bouton principal, focus")
	var early: EndScreen = EndScreen.new()
	early.setup(EndingService.F3_FAMILY_LOST, [], Household.new(), 0, {}, 0.5)
	add_child_autofree(early)
	await wait_process_frames(2)
	assert_null(early.epilogue_button, "pas d'épilogue avant l'Acte III")
	assert_not_null(early.locked_hint, "ligne epi_locked_hint")


func test_load_screen_shows_the_epilogue_chip_and_action() -> void:
	var data: Dictionary = {"campaign_seed": 9, "credits": 3, "score_total": 0, "citations": 0, "narrative_flags": {},
		"day_history": [], "household": Household.new().to_dict(), "case_memory": {}, "difficulty": "hard", "play_time_sec": 60,
		"current_day": 30}
	SaveService.save_slot(data, 2)
	SaveService.mark_ended(2, "f10_pont")
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
	SaveService.write_epilogue(2, EpilogueService.make_seed(EndingService.F10_PONT, flags, Household.new(), {}, 9, 30))
	var screen: LoadScreen = LoadScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_true(screen.epilogue_buttons.has(2), "action JOUER « UN AN PLUS TARD »")
	assert_not_null(screen.cards[1].find_child("EpilogueChip", true, false), "puce ÉPILOGUE")
	assert_eq(_focus_owner(), screen.epilogue_buttons[2], "focus sur l'épilogue (aucune partie active)")
	watch_signals(screen)
	screen.epilogue_buttons[2].pressed.emit()
	assert_signal_emitted_with_parameters(screen, "epilogue_requested", [2])


# ---------------------------------------------------------------------------
# Dossier (I33, D-131)
# ---------------------------------------------------------------------------

func test_dossier_hides_totals_and_level_two_hints_before_the_epilogue() -> void:
	var profile: Dictionary = _profile("f3_family_lost", 1, ["sc_01", "sc_20"])
	assert_eq(DossierData.endings_total_text(profile), "", "aucun total avant epilogue_unlocked")
	var cards: Array[Dictionary] = DossierData.ending_cards(profile)
	assert_eq(cards.size(), 10)
	for card: Dictionary in cards:
		if not card["seen"]:
			assert_eq(str(card["hint2"]), "", "aucun indice de niveau 2 : %s" % card["id"])
			assert_false(card.has("title"), "jamais le titre d'une fin non vue")
	var table: CharacterTableDef = CharacterTableDef.load_default()
	if table != null:
		assert_eq(DossierData.people_total_text(profile, table), "")
		var people: Array[Dictionary] = DossierData.people(profile, table)
		var ids: Array = people.map(func(p: Dictionary) -> String: return str(p["id"]))
		assert_eq(people.size(), 2, "seulement les personnages croisés : %s" % [ids])
		for person: Dictionary in people:
			if person["id"] == "chr_arkady":
				assert_true(str(person["name"]).contains("Bastien"), "faux nom tant que le vrai n'est pas appris")
	var screen: DossierScreen = DossierScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_false(screen.tabs.has(DossierScreen.TAB_EPILOGUES), "onglet ÉPILOGUES masqué")
	assert_null(screen.find_child("Hint2", true, false), "aucun indice de niveau 2 affiché")


func test_dossier_after_an_act_three_ending_shows_totals_worlds_and_replay() -> void:
	var profile: Dictionary = _profile("f10_pont", 3, ["sc_01", "sc_04"])
	assert_ne(DossierData.endings_total_text(profile), "", "totaux après la fin de l'Acte III")
	var worlds: Array[Dictionary] = DossierData.epilogue_worlds(profile)
	assert_eq(worlds.size(), 4)
	var seen: int = 0
	for world: Dictionary in worlds:
		if world["seen"]:
			seen += 1
		else:
			assert_eq(str(world["name"]), UiText.t("dos_world_unknown", ""), "monde non vu : silhouette")
	assert_eq(seen, 1, "un seul monde vu (C)")
	var screen: DossierScreen = DossierScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(3)
	assert_true(screen.tabs.has(DossierScreen.TAB_EPILOGUES))
	assert_not_null(screen.find_child("Hint2", true, false), "indices de niveau 2 visibles")
	screen.cycle_tab(1)
	await wait_process_frames(2)
	assert_eq(screen.current_tab, DossierScreen.TAB_PEOPLE, "RB : onglet suivant")
	assert_eq(_focus_owner(), screen.tab_buttons[DossierScreen.TAB_PEOPLE])
	screen.show_tab(DossierScreen.TAB_EPILOGUES)
	await wait_process_frames(2)
	assert_eq(screen.epilogue_buttons.size(), 1, "JOUER depuis la graine du profil")
	watch_signals(screen)
	screen.epilogue_buttons.values()[0].pressed.emit()
	assert_signal_emitted(screen, "epilogue_requested")
	assert_false(Campaign.epilogue_seed_from_profile(str(screen.epilogue_buttons.keys()[0])).is_empty(), "graine rejouable")


# ---------------------------------------------------------------------------
# Guichet : événements, listes nommées, règles mutables, comparateur (I32)
# ---------------------------------------------------------------------------

func _ui() -> ComparisonUI:
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate()
	add_child_autofree(ui)
	await wait_process_frames(2)
	return ui


func test_station_event_banner_and_rulebook_line() -> void:
	var events: StationEventsDef = StationEventService.load_def()
	if events == null:
		pending("données d'événements absentes")
		return
	var ui: ComparisonUI = await _ui()
	var event: StationEventDef = null
	for candidate: StationEventDef in events.events:
		if candidate.key == &"comparator":
			event = candidate
	assert_not_null(event)
	var plan: StationEventPlan = StationEventService.garde_plan(event, 0)
	plan.state = StationEventPlan.State.ACTIVE
	EventBus.station_event_started.emit(plan)
	await wait_process_frames(2)
	assert_true(ui.event_banner.visible, "bandeau ÉVÉNEMENT")
	var text: String = ui.event_banner.get_text()
	assert_true(text.contains(UiText.t("sev_comparator_title", "")), "titre de l'événement : %s" % text)
	assert_true(text.contains(UiText.plural("sev_ui_remaining", plan.remaining(0), "", "")), "passagers restants")
	assert_not_null(ui.event_banner.find_child("Event_%s" % event.id, true, false).get_child(0) as UiIcon, "icône (jamais la couleur seule)")
	assert_eq(ui.rulebook.event_notes.size(), 1, "ligne ambre en tête du Rulebook")
	assert_false(ui.rulebook.event_notes[0].contains("%d"))
	EventBus.station_event_ended.emit(plan)
	await wait_process_frames(2)
	assert_false(ui.event_banner.visible, "fin d'événement : bandeau retiré")
	assert_eq(ui.rulebook.event_notes.size(), 0)


func test_stolen_cards_list_opens_its_rulebook_tab() -> void:
	var ui: ComparisonUI = await _ui()
	var entry: RevokedEntry = RevokedEntry.new()
	entry.id = &"stolen_1"
	entry.citizen_id = "TYC-4421-KX"
	var entries: Array[RevokedEntry] = [entry]
	EventBus.rule_list_published.emit(&"stolen", entries)
	await wait_process_frames(2)
	assert_true(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_STOLEN), "onglet « Cartes volées »")
	assert_true(ui.rulebook.show_reference_tab(RulebookReference.TAB_STOLEN))
	assert_not_null(ui.rulebook.get_revoked_card(&"stolen_1"), "carte sélectionnable")
	assert_eq(ui.find_revocation(&"stolen_1"), entry, "comparateur : entrée retrouvée")
	var empty: Array[RevokedEntry] = []
	EventBus.rule_list_published.emit(&"stolen", empty)
	await wait_process_frames(2)
	assert_false(ui.rulebook.visible_reference_tabs().has(RulebookReference.TAB_STOLEN), "liste vide : onglet fermé")


func test_rulebook_shows_added_retired_and_restored_rules() -> void:
	var ui: ComparisonUI = await _ui()
	var data: DataCatalog = DataCatalog.load_from()
	var ids: Array[StringName] = [&"r_id_card_valid", &"r_mrz_valid"]
	var rules: Array[Rule] = []
	for id: StringName in ids:
		var rule: Rule = data.rules.get(id, null)
		assert_not_null(rule, String(id))
		if rule != null:
			rules.append(rule)
	if rules.size() < 2:
		return
	var added: RulebookEntry = rules[0].get_rulebook_entry()
	added.is_new = true
	var retired: RulebookEntry = rules[1].get_rulebook_entry()
	retired.retired = true
	retired.note_key = "rb_retired_quais"
	ui.rulebook.apply_rules([added] as Array[RulebookEntry], [retired] as Array[RulebookEntry])
	await wait_process_frames(2)
	assert_true(ui.rulebook.get_rule_card(ids[0]).entry.is_new, "règle ajoutée : NOUVEAU")
	assert_true(ui.rulebook.get_rule_card(ids[1]).is_retired(), "règle retirée : barrée")
	var restored: RulebookEntry = rules[1].get_rulebook_entry()
	ui.rulebook.apply_rules([rules[0].get_rulebook_entry(), restored] as Array[RulebookEntry], [] as Array[RulebookEntry], [ids[1]])
	await wait_process_frames(2)
	var card: RuleCardView = ui.rulebook.get_rule_card(ids[1])
	assert_false(card.is_retired())
	assert_eq(card.note_text, UiText.t("rb_restored", ""), "règle rétablie : puce RÉTABLIE")
	assert_true(ui.rulebook.focus_rule(ids[1]))
	assert_gt(card.glow, 0.0, "mise en évidence")


func test_comparator_down_shows_an_agent_finding_instead_of_a_result() -> void:
	var ui: ComparisonUI = await _ui()
	var rule_set: RuleSet = RuleSet.new().make_shift_copy()
	var ctx: RuleContext = RuleContext.new()
	ctx.rule_set = rule_set
	ctx.apply_changes([RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)] as Array[RuleChangeDef], &"test")
	ui.rule_context_provider = func() -> RuleContext: return ctx
	assert_true(ui.comparator_down(), "modificateur lu")
	var a: FieldRef = FieldRef.today()
	var b: FieldRef = FieldRef.rulebook_rule(&"r_id_card_valid")
	var result: Discrepancy = Discrepancy.new(a, b)
	result.result = Discrepancy.Result.DISCORDANT
	result.confirmed = true
	assert_true(ui.selection.request_pair(a, b))
	ui.discrepancies.clear()
	EventBus.discrepancy_checked.emit(result)
	await wait_process_frames(1)
	assert_eq(ui.discrepancies.size(), 0, "aucune DISCORDANCE numérotée pendant la panne")
	ui.rule_context_provider = Callable()
	assert_false(ui.comparator_down(), "sans contexte : comparateur normal")


func test_sponsor_card_document_renders_on_the_workbench() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var def: DocumentTypeDef = data.documents.get(&"sponsor_card", null)
	if def == null:
		pending("carte de répondant absente des données")
		return
	var doc: DocumentInstance = DocumentInstance.new(def)
	doc.serial = "RP-0042"
	doc.set_value(&"family_name", "OKAFOR")
	doc.set_value(&"given_name", "ADAEZE")
	doc.set_value(&"citizen_id", "HG-4521-KX8M")
	doc.set_value(&"sponsor", "HG-2233-PQ7R")
	var view: DocumentView = DocumentView.create(doc)
	add_child_autofree(view)
	await wait_process_frames(2)
	assert_gt(view.fields.size(), 3, "champs de la carte de répondant")
	var sponsor: DocFieldView = null
	for field: DocFieldView in view.fields:
		if field.ref != null and field.ref.field_id == &"sponsor":
			sponsor = field
	assert_not_null(sponsor, "ligne Répondant sélectionnable")
