## QA (docs/QA.md §13, passe Acte III) — non-régressions J20–J30 : sauvegardes
## v4 réelles du J20 migrées en v5 et relues à chaque soir J20–J29, textes de
## l'Acte III sans clé brute (briefings, soirées, options, épilogues F1–F10),
## sous-titres ≤ 90 caractères et Tessar entre ‹…›, VALIDER spammé pendant la
## Déposition. Les bugs ouverts de la passe sont détectés ici et marqués
## `pending("QA-xxx …")` tant qu'ils existent : la suite reste verte, le
## rapport GUT les liste, et le test redevient une vraie assertion une fois
## le bug corrigé.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DIR: String = "user://test_qa_act3"
const V4_J20: PackedStringArray = ["res://tests/fixtures/qa_save_v4_j20_loyal.json",
		"res://tests/fixtures/qa_save_v4_j20_luciole.json", "res://tests/fixtures/qa_save_v4_j20_solidaire.json"]
## Climats d'entrée de l'Acte III (D-086) et variantes de foyer fréquentes.
const CLIMATES: Array[StringName] = [&"climate_statu_quo", &"climate_vanne", &"climate_vitres", &"climate_registre",
		&"climate_promu"]

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	SaveService.delete(0, DIR)


func after_each() -> void:
	SaveService.delete(0, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _expected(_c: Case, key: CaseKey, i: int) -> VerdictKind.Kind:
	return key.expected_verdict if i % 6 != 5 else VerdictKind.Kind.DENY


# ---------------------------------------------------------------------------
# Sauvegardes (passent : non-régressions)
# ---------------------------------------------------------------------------

## Sauvegardes v4 réelles du J20 → v5 ; soirée pivot jouée, puis chaque soir
## J20–J29 : la sauvegarde relue redonne exactement l'état en mémoire.
func test_real_v4_j20_saves_roundtrip_every_act_three_evening() -> void:
	for path: String in V4_J20:
		var migrated: Dictionary = SaveService.parse(FileAccess.get_file_as_string(path), path)
		assert_false(migrated.is_empty(), "%s acceptée" % path.get_file())
		assert_eq(SaveService.as_int(migrated["version"]), SaveService.VERSION, "v4 → v%d" % SaveService.VERSION)
		assert_eq(SaveService.as_int(migrated["current_day"]), 20)
		GameState.apply_save_dict(migrated)
		var evenings: int = 0
		while GameState.current_day <= 29:
			var n: int = GameState.current_day
			var summary: DaySummary = DaySimulator.simulate(data, n, GameState.get_day_seed(), _expected)
			GameState.add_credits(summary.get_net())
			var events: Array[EveningEvent] = Campaign.prepare_events(data)
			var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
			var report: EveningReport = Campaign.preview_evening(data, lines, events)
			var ending: StringName = Campaign.close_evening(data, summary, report, 0, DIR)
			if ending != EveningReport.ENDING_NONE:
				assert_true(EndingService.ALL_ENDINGS.has(ending), "%s J%d : fin %s connue" % [path.get_file(), n, ending])
				break
			evenings += 1
			if n == 20:
				assert_true(Campaign.is_act3(), "%s : soirée pivot → Acte III" % path.get_file())
			var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
			assert_true(GameState.load_from_slot(0, DIR), "%s J%d relu" % [path.get_file(), n])
			assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected, "%s J%d : état identique" % [path.get_file(), n])
		assert_gt(evenings, 3, "%s : soirées de l'Acte III jouées" % path.get_file())


# ---------------------------------------------------------------------------
# i18n (passent : non-régressions)
# ---------------------------------------------------------------------------

## Briefings, soirées (titres, textes, options, résultats) J20–J30 dans les
## cinq climats × trois foyers, et épilogues F1–F10 : aucune clé absente.
func test_act_three_texts_have_no_raw_key() -> void:
	var raw: PackedStringArray = []
	var economy: EconomyDef = data.get_economy()
	var homes: Array[Household] = [Household.new(), Household.new(), Household.new()]
	homes[1].send_away(Household.ILAN, Household.AWAY_SOUTE)
	homes[2].get_member(Household.ILAN).detained = true
	for n: int in range(20, data.get_last_day_number() + 1):
		var day: DayDef = data.get_day(n)
		for climate: StringName in CLIMATES:
			for home: Household in homes:
				var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT2: true, EndingService.FLAG_ACT3: n > 20,
						climate: true, &"montclair_pliable": n % 2 == 0, &"dora_departed": n % 3 == 0}
				var content: BriefingContent = BriefingContent.build(day, flags, home, 0)
				var keys: PackedStringArray = [content.directive_key, content.directive_title_key, content.slogan_key]
				for message: Dictionary in content.messages:
					keys.append_array([str(message["text"]), str(message["speaker"])])
				var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, home, 0.9,
						economy.levy_for(n, 120))
				for event: EveningEvent in EveningService.build_events(day.evening_events, context, economy):
					keys.append_array([event.title_key, event.text_key])
					keys.append_array(event.extra_keys)
					for option: EveningOptionDef in event.options:
						keys.append_array([option.label_key, option.result_key])
				for key: String in keys:
					if not key.is_empty() and not UiText.has(key) and not raw.has("J%d %s" % [n, key]):
						raw.append("J%d %s" % [n, key])
	for ending: StringName in EndingService.ALL_ENDINGS:
		for climate: StringName in CLIMATES:
			var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT3: true, climate: true, &"pont": 6,
					&"final3_dora": climate == &"climate_vitres"}
			var epilogue: Dictionary = EndingService.epilogue_act3(ending, flags, Household.new())
			var keys: PackedStringArray = PackedStringArray(epilogue.get("lines", PackedStringArray()))
			keys.append(str(epilogue.get("title_key", "")))
			for key: String in keys:
				if not key.is_empty() and not UiText.has(key) and not raw.has("%s %s" % [ending, key]):
					raw.append("%s %s" % [ending, key])
	assert_eq(raw, PackedStringArray(), "clés absentes de fr.csv (Acte III)")


## Répliques des cas SC-51 → SC-82 : ≤ 90 caractères ; Tessar entre ‹…›
## équilibrés dans tous les textes de l'Acte III.
func test_act_three_subtitles_fit_and_tessar_is_bracketed() -> void:
	var too_long: PackedStringArray = []
	var unbalanced: PackedStringArray = []
	var line_key: RegEx = RegEx.create_from_string("^sc(5[1-9]|[67][0-9]|8[0-2])_[a-z0-9_]+$")
	var non_line: RegEx = RegEx.create_from_string("(note|label|desc|title|_doc|_item)")
	var act3_key: RegEx = RegEx.create_from_string("^(sc(5[1-9]|[67][0-9]|8[0-2])_|end3_|chapter3_|evt_d2[0-9]_|msg_.*day(2[0-9]|30))")
	var csv: FileAccess = FileAccess.open("res://data/i18n/fr.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row: PackedStringArray = csv.get_csv_line()
		if row.size() < 2:
			continue
		var key: String = row[0]
		var text: String = row[1]
		if line_key.search(key) != null and non_line.search(key) == null and text.length() > 90:
			too_long.append("%s (%d)" % [key, text.length()])
		if act3_key.search(key) != null and text.count("‹") != text.count("›"):
			unbalanced.append(key)
	assert_eq(too_long, PackedStringArray(), "sous-titres > 90 caractères")
	assert_eq(unbalanced, PackedStringArray(), "chevrons Tessar déséquilibrés")


# ---------------------------------------------------------------------------
# Robustesse (passe : non-régression)
# ---------------------------------------------------------------------------

func _evening(day_number: int, flags: Dictionary[StringName, Variant], balance: int = 60) -> EveningScreen:
	var day: DayDef = data.get_day(day_number)
	var economy: EconomyDef = data.get_economy()
	var home: Household = GameState.household
	var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, home, 0.9,
			economy.levy_for(day_number, balance))
	var events: Array[EveningEvent] = EveningService.build_events(day.evening_events, context, economy)
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, home, flags, balance)
	EveningService.default_selection(lines, balance)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(day, balance, 15, lines, home, false)
	screen.set_events(events)
	return screen


## Déposition (J29) : choix changé plusieurs fois puis VALIDER ET DORMIR spammé
## — le dernier choix compte, la nuit n'est validée qu'une fois.
func test_deposition_spam_validates_once_with_last_choice() -> void:
	GameState.new_campaign(4242)
	GameState.current_day = 29
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(EndingService.FLAG_ACT3, true)
	var screen: EveningScreen = _evening(29, {EndingService.FLAG_ACT3: true})
	add_child_autofree(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1920, 1080)
	await wait_process_frames(2)
	assert_not_null(screen.get_event(&"d29_deposition"), "Déposition au J29")
	for option: StringName in [&"truth", &"silent", &"truth", &"silent"]:
		screen.choose(&"d29_deposition", option)
	var validations: Array[int] = [0]
	screen.confirmed.connect(func(confirmed_lines: Array[ExpenseLine]) -> void:
		validations[0] += 1
		# Comme `DayScene` : rapport calculé puis affiché dans le même appel.
		var report: EveningReport = Campaign.preview_evening(data, confirmed_lines, screen.events, screen.get_choices())
		screen.show_report(report, &""))
	for i: int in 4:
		screen.confirm()
	assert_eq(validations[0], 1, "une seule validation")
	assert_eq(screen.get_choices().get(&"d29_deposition", &""), &"silent", "dernier choix retenu")


# ---------------------------------------------------------------------------
# Vraie scène : scénarios non joués par la passe (§13.4, §13.2)
# ---------------------------------------------------------------------------

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")


## Sauvegarde du joueur (`user://saves`) : la vraie scène y écrit en
## validant une soirée ; rendue telle quelle après le test.
func _backup_default_slot() -> String:
	var path: String = SaveService.slot_path()
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _restore_default_slot(text: String) -> void:
	SaveService.delete()
	if text.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(SaveService.DEFAULT_DIR)
	var file: FileAccess = FileAccess.open(SaveService.slot_path(), FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func _act_three_morning(day_number: int, credits: int) -> void:
	GameState.new_campaign(4242)
	GameState.current_day = day_number
	GameState.credits = credits
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	GameState.set_flag(EndingService.FLAG_ACT3, true)


func _scene_evening(scene: DayScene, day_number: int) -> EveningScreen:
	var summary: DaySummary = DaySimulator.simulate(data, day_number, GameState.get_day_seed(), _expected)
	scene.show_evening(summary)
	return scene.screen as EveningScreen


## Pause puis « QUITTER VERS LE TITRE » (confirmé) en pleine Enquête (soirée du
## J22, question Q1 déjà répondue) : la nuit n'est pas validée, aucune
## sauvegarde écrite ; « Continuer » relit la sauvegarde du matin et rejoue le
## J22, dont la soirée repose la même question.
func test_pause_quit_during_the_inquiry_replays_the_day() -> void:
	var player_save: String = _backup_default_slot()
	_act_three_morning(22, 200)
	assert_eq(GameState.save_to_slot(0, DIR), OK)
	var morning: String = JSON.stringify(GameState.to_save_dict(), "", true)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	var evening: EveningScreen = _scene_evening(scene, 22)
	await wait_process_frames(2)
	assert_not_null(evening, "soirée du J22")
	if evening == null:
		_restore_default_slot(player_save)
		return
	assert_not_null(evening.get_event(&"d22_q1"), "Enquête : question Q1")
	assert_true(evening.choose(&"d22_q1", &"tell"), "Q1 : Dire")
	var confirmed: Array[int] = [0]
	evening.confirmed.connect(func(_lines: Array[ExpenseLine]) -> void: confirmed[0] += 1)
	var quits: Array[int] = [0]
	scene.pause_menu.quit_to_title_requested.disconnect(scene.go_to_title)
	scene.pause_menu.quit_to_title_requested.connect(func() -> void: quits[0] += 1)
	scene.pause_menu.open()
	assert_true(get_tree().paused, "pause ouverte pendant l'Enquête")
	scene.pause_menu.call(&"_on_quit_pressed")
	assert_eq(quits[0], 0, "premier appui : confirmation demandée")
	scene.pause_menu.call(&"_on_quit_pressed")
	assert_eq(quits[0], 1, "second appui : retour au titre")
	assert_false(get_tree().paused, "arbre relâché au retour au titre")
	assert_eq(confirmed[0], 0, "nuit non validée")
	assert_eq(_backup_default_slot(), player_save, "aucune sauvegarde écrite par la soirée quittée")
	# « Continuer » : la sauvegarde du matin, puis le même jour.
	assert_true(GameState.load_from_slot(0, DIR), "Continuer")
	assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), morning, "état du matin du J22")
	scene.queue_free()
	await wait_process_frames(2)
	var again: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(again)
	await wait_process_frames(2)
	assert_eq(again.day_controller.day.day_number, 22, "le J22 est rejoué")
	var replay: EveningScreen = _scene_evening(again, 22)
	await wait_process_frames(2)
	assert_not_null(replay.get_event(&"d22_q1") if replay != null else null, "Q1 reposée")
	_restore_default_slot(player_save)


## Avance de l'Arbitre (`d21_loan`) dans la vraie scène : solde < 40 ₵ au soir
## du J21 → l'offre est présentée, « Accepter » crédite 30 ₵ et pose
## `arbitre_loan` ; le remboursement (35 ₵, obligatoire) tombe au soir du J27.
func test_arbitre_loan_is_offered_and_repaid_in_the_real_scene() -> void:
	var player_save: String = _backup_default_slot()
	var economy: EconomyDef = data.get_economy()
	_act_three_morning(21, 10)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	var evening: EveningScreen = _scene_evening(scene, 21)
	await wait_process_frames(2)
	assert_not_null(evening, "soirée du J21")
	if evening == null:
		_restore_default_slot(player_save)
		return
	assert_not_null(evening.get_event(&"d21_loan"), "avance proposée sous %d ₵" % economy.loan_balance_below)
	assert_true(evening.choose(&"d21_loan", &"take"), "avance acceptée")
	var before: int = GameState.credits
	evening.confirm()
	await wait_process_frames(2)
	assert_true(FlagCondition.is_flag_true(GameState.narrative_flags, EveningService.FLAG_LOAN), "avance enregistrée")
	assert_eq(GameState.current_day, 22, "nuit validée")
	var spent: int = 0
	for line: ExpenseLine in evening.lines:
		if line.paid:
			spent += line.cost
	assert_true(GameState.credits >= before + economy.loan_amount - spent, "avance créditée (+%d ₵)" % economy.loan_amount)
	assert_true(SaveService.has_save(), "sauvegarde du soir écrite")
	# Soir du J27 : remboursement imposé.
	GameState.current_day = economy.loan_day
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, Campaign.prepare_events(data))
	var repay: ExpenseLine = null
	for line: ExpenseLine in lines:
		if line.id == EveningService.LINE_LOAN:
			repay = line
	assert_not_null(repay, "remboursement au J%d" % economy.loan_day)
	if repay != null:
		assert_eq(repay.cost, economy.loan_repay)
		assert_true(repay.mandatory, "remboursement obligatoire")
	_restore_default_slot(player_save)


# ---------------------------------------------------------------------------
# Bugs ouverts (pending tant qu'ils existent)
# ---------------------------------------------------------------------------

func _booth_ui(day_number: int) -> ComparisonUI:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	# Écran 1920×1080 (la fenêtre de GUT est plus haute).
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1920, 1080)
	ui.workbench.reduce_motion = true
	var day: DayDef = data.get_day(day_number)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	return ui


## QA-032 : Rulebook à 15–16 onglets (J24+) en 1920×1080 : la rangée d'onglets
## mange la hauteur du panneau ; la liste « Règles » n'affiche que 2 règles
## entières (la Main courante et les Convocations : une seule carte).
func test_rulebook_shows_enough_rules_with_sixteen_tabs() -> void:
	var ui: ComparisonUI = _booth_ui(26)
	await wait_seconds(0.5)
	var rulebook: RulebookPanel = ui.rulebook
	var scroll: ScrollContainer = rulebook.get(&"_scroll") as ScrollContainer
	assert_not_null(scroll, "liste du Rulebook")
	var view: Rect2 = scroll.get_global_rect()
	var whole: int = 0
	for card: RuleCardView in rulebook.cards:
		if card.is_visible_in_tree() and view.encloses(card.get_global_rect()):
			whole += 1
	assert_gt(rulebook.cards.size(), 10, "règles du J26")
	assert_gte(whole, 4, "au moins 4 règles lisibles sans défiler (%d px de liste)" % int(view.size.y))
	# Navigation sur une rangée : la liste garde ≥ 60 % de la hauteur du panneau.
	assert_gte(view.size.y, rulebook.size.y * 0.6, "liste ≥ 60 %% du panneau (%d / %d px)" % [int(view.size.y), int(rulebook.size.y)])


## QA-033 : le bandeau de résultat (CONCORDANT 1,2 s ; DISCORDANCE sans délai)
## se pose sur le bas des documents : MRZ et code-barres de la carte, lignes
## Répondant / Convocation du permis (J24+, 2 documents à grande échelle).
func test_result_banner_does_not_cover_documents() -> void:
	var ui: ComparisonUI = _booth_ui(24)
	var case: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 0
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	await wait_seconds(1.0)
	ui.workbench.show_banner(Workbench.BannerKind.DISCORDANT, "DISCORDANCE 1", "Texte de résultat de comparaison.")
	await wait_process_frames(2)
	var banner: Control = ui.workbench.get(&"_banner") as Control
	var covered: PackedStringArray = []
	for view: DocumentView in ui.workbench.views:
		var cover: Rect2 = banner.get_global_rect().intersection(view.get_global_rect())
		if cover.has_area() and cover.get_area() > view.get_global_rect().get_area() * 0.02:
			covered.append("%s (%d %%)" % [view.get_document_id(), int(100.0 * cover.get_area() / view.get_global_rect().get_area())])
	assert_eq(covered.size(), 0, "bandeau de résultat sur %s" % ", ".join(covered))


## QA-034 : soirée en 1920×1080, foyer complet (vous + Ilan, Noa, Dora) : la
## liste des dépenses défile dans un cadre trop court ; la dernière ration
## (Dora) est coupée en bas sans indice de défilement (J22, J29).
func test_evening_rations_are_all_visible_at_1080p() -> void:
	GameState.household = Household.new()
	var screen: EveningScreen = _evening(29, {EndingService.FLAG_ACT3: true}, 35)
	add_child_autofree(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1920, 1080)
	await wait_process_frames(3)
	var hidden: PackedStringArray = []
	for row: Button in screen.get(&"_rows"):
		var scroll: ScrollContainer = null
		var parent: Node = row.get_parent()
		while parent != null and scroll == null:
			scroll = parent as ScrollContainer
			parent = parent.get_parent()
		if scroll != null and not scroll.get_global_rect().grow(1.0).encloses(row.get_global_rect()):
			hidden.append(row.name if row.name != &"" else row.text)
	assert_eq(hidden.size(), 0, "ligne(s) de dépense coupée(s) ou hors cadre à 1080p : %s" % ", ".join(hidden))


## QA-036 (corrigé) : profils `loyal` et `accusateur` : au J29, si
## `montclair_pliable` (SC-70 approuvée), l'option « loyal » est remplacée par
## « loyal_paid » (même libellé, +20 ₵) ; le profil choisit par intention et
## obtient la variante offerte au lieu de retomber sur « Se taire ».
func test_sim_profiles_choose_an_available_deposition_option() -> void:
	var economy: EconomyDef = data.get_economy()
	for pliable: bool in [true, false]:
		var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT3: true}
		if pliable:
			flags[&"montclair_pliable"] = true
		var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, Household.new(), 0.95, 0)
		var deposition: EveningEvent = null
		var events: Array[EveningEvent] = EveningService.build_events(data.get_day(29).evening_events, context, economy)
		for event: EveningEvent in events:
			if event.id == &"d29_deposition":
				deposition = event
		assert_not_null(deposition, "Déposition")
		if deposition == null:
			return
		for preset: StringName in [&"loyal", &"accusateur"]:
			var profile: SimProfile = SimProfile.preset(preset)
			var option: EveningOptionDef = profile.option_for(deposition)
			assert_not_null(option, "%s : option de Déposition offerte (pliable=%s)" % [preset, pliable])
			if option != null:
				assert_eq(option.id, &"loyal_paid" if pliable else &"loyal", "%s : variante attendue" % preset)
				var resolved: StringName = profile.choices_for(events).get(&"d29_deposition", &"")
				assert_eq(resolved, option.id)
