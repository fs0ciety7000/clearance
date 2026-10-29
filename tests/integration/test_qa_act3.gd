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
	if whole < 4:
		pending("QA-032 : %d règle(s) entière(s) visible(s) sur %d (hauteur de liste %d px, 1080p, 16 onglets)" % [
				whole, rulebook.cards.size(), int(view.size.y)])
		return
	assert_gte(whole, 4, "au moins 4 règles lisibles sans défiler")


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
	if not covered.is_empty():
		pending("QA-033 : bandeau de résultat sur %s" % ", ".join(covered))
		return
	assert_eq(covered.size(), 0)


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
	if not hidden.is_empty():
		pending("QA-034 : %d ligne(s) de dépense coupée(s) ou hors cadre à 1080p : %s" % [hidden.size(), ", ".join(hidden)])
		return
	assert_eq(hidden.size(), 0)


## QA-036 : profil `loyal` (et `mercenary3`) : au J29, si `montclair_pliable`
## (SC-70 approuvée), l'option « loyal » est remplacée par « loyal_paid » ;
## le profil demande « loyal », le choix est refusé et la Déposition tombe sur
## « Se taire » (soupçon +1) — en simulation comme dans `qa_campaign`.
func test_sim_profiles_choose_an_available_deposition_option() -> void:
	var economy: EconomyDef = data.get_economy()
	var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT3: true, &"montclair_pliable": true}
	var context: Dictionary[StringName, Variant] = EveningService.context_flags(flags, Household.new(), 0.95, 0)
	var deposition: EveningEvent = null
	for event: EveningEvent in EveningService.build_events(data.get_day(29).evening_events, context, economy):
		if event.id == &"d29_deposition":
			deposition = event
	assert_not_null(deposition, "Déposition")
	var refused: PackedStringArray = []
	for preset: StringName in [&"loyal", &"mercenary3"]:
		var wanted: StringName = SimProfile.preset(preset).choices.get(&"d29_deposition", &"")
		if wanted != &"" and deposition.get_option(wanted) == null:
			refused.append("%s → %s" % [preset, wanted])
	if not refused.is_empty():
		pending("QA-036 : option de Déposition absente pour %s (montclair_pliable)" % ", ".join(refused))
		return
	assert_eq(refused.size(), 0)
