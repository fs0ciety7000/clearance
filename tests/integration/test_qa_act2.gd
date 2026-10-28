## QA (docs/QA.md §12, passe Acte II) — non-régressions J10–J20 : sauvegardes
## réelles v3 (v0.8.1) migrées en v4 et rejouées depuis le J10, sauvegarde
## relue à chaque soir J10–J19 avec les prélèvements J11/J17, briefings de
## l'Acte II sans clé brute, plan de travail à 4 documents, boîte « QUITTER
## HALCYON ? » modale, noms des personnages de l'Acte II. Les bugs ouverts sont
## marqués `pending("QA-xxx …")` : la suite reste verte, le rapport GUT les liste.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")
const DIR: String = "user://test_qa_act2"
## Sauvegardes v3 produites par le code v0.8.1 (commit 3dd6ead), soir du J9 :
## `loyal` (Ilan dénoncé·e : `lost` + `detained`), `drift` (laissez-passer
## achetés), `luciole` (Ilan soutenu·e, confiance 13).
const V3_FIXTURES: PackedStringArray = ["res://tests/fixtures/qa_save_v3_j9_loyal.json",
		"res://tests/fixtures/qa_save_v3_j9_drift.json", "res://tests/fixtures/qa_save_v3_j9_luciole.json"]

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


## Joue la soirée du jour courant avec les choix par défaut ; renvoie la fin.
func _play_day(policy: Callable) -> StringName:
	var day_number: int = GameState.current_day
	var summary: DaySummary = DaySimulator.simulate(data, day_number, GameState.get_day_seed(), policy)
	GameState.add_credits(summary.get_net())
	if not Campaign.has_evening(data):
		return Campaign.close_final_day(data, summary, 0, DIR)
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var report: EveningReport = Campaign.preview_evening(data, lines, events)
	return Campaign.close_evening(data, summary, report, 0, DIR)


func _expected(_c: Case, key: CaseKey, _i: int) -> VerdictKind.Kind:
	return key.expected_verdict


# ---------------------------------------------------------------------------
# Sauvegardes (passent : non-régressions)
# ---------------------------------------------------------------------------

## Migration v3 → v4 sur de vraies sauvegardes v0.8.1 : version, foyer (Ilan
## dénoncé·e → vivant·e, mis·e en attente), drapeaux conservés ; la partie
## reprend au J10, passe la soirée pivot et sauvegarde en v4 (Acte II).
func test_real_v3_saves_migrate_and_continue_into_act_two() -> void:
	for path: String in V3_FIXTURES:
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_eq(SaveService.as_int(raw["version"]), 3, "%s : sauvegarde v3 d'origine" % path.get_file())
		var migrated: Dictionary = SaveService.parse(FileAccess.get_file_as_string(path), path)
		assert_false(migrated.is_empty(), "%s acceptée" % path.get_file())
		assert_eq(SaveService.as_int(migrated["version"]), SaveService.VERSION)
		assert_eq(SaveService.as_int(migrated["current_day"]), 10, "soir du J9 → J10")
		GameState.apply_save_dict(migrated)
		var ilan: Household.Member = GameState.household.get_member(Household.ILAN)
		if path.contains("loyal"):
			assert_true(ilan.detained, "Ilan dénoncé·e : mis·e en attente")
			assert_eq(ilan.state_key(), "hh_state_detained")
			assert_eq(GameState.household.alive_count(), 3, "« mis·e en attente » compte comme vivant·e")
			assert_eq(GameState.household.present_count(), 2)
		else:
			assert_eq(ilan.state_key(), "hh_state_well")
		if path.contains("drift"):
			assert_true(GameState.has_flag(&"drift_passes_bought"), "laissez-passer du J9 conservés")
		var ending: StringName = _play_day(_expected)
		assert_ne(ending, EndingService.F6_DRIFT, "%s : « Embarquer » jamais choisi par défaut" % path.get_file())
		if ending == EveningReport.ENDING_NONE:
			assert_true(Campaign.is_act2(), "%s : Acte II commencé" % path.get_file())
			assert_eq(GameState.current_day, 11)
			var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
			assert_true(GameState.load_from_slot(0, DIR), "sauvegarde v4 du soir du J10 relue")
			assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected)


## Chaque soir J10–J20 : la sauvegarde relue redonne l'état exact ; les
## prélèvements (D-079) ne tombent qu'au J11 et au J17, à 30 % au-delà de 40 ₵.
## M9 : la soirée pivot du J20 ouvre l'Acte III (l'Acte III a son propre test).
func test_every_act_two_evening_save_roundtrips_with_levies() -> void:
	Campaign.new_game(data, 4242)
	var economy: EconomyDef = data.get_economy()
	var policy: Callable = func(_c: Case, key: CaseKey, i: int) -> VerdictKind.Kind:
		return key.expected_verdict if i % 7 != 6 else VerdictKind.Kind.DENY
	for day_number: int in range(1, 21):
		assert_eq(GameState.current_day, day_number)
		var summary: DaySummary = DaySimulator.simulate(data, day_number, GameState.get_day_seed(), policy)
		GameState.add_credits(summary.get_net())
		if not Campaign.has_evening(data):
			var final: StringName = Campaign.close_final_day(data, summary, 0, DIR)
			assert_true(EndingService.ALL_ENDINGS.has(final), "fin du J20 : %s" % final)
			assert_false(SaveService.has_save(0, DIR), "sauvegarde effacée à la fin")
			return
		var events: Array[EveningEvent] = Campaign.prepare_events(data)
		var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
		var levy: int = 0
		for line: ExpenseLine in lines:
			if line.id == EveningService.LINE_LEVY:
				levy = line.cost
		var expected_levy: int = economy.levy_for(day_number, GameState.credits)
		assert_eq(levy, expected_levy, "J%d : prélèvement" % day_number)
		if day_number in [11, 17] and GameState.credits > economy.levy_floor + 10:
			assert_gt(levy, 0, "J%d : prélèvement dû" % day_number)
		elif not day_number in [11, 17]:
			assert_eq(levy, 0, "J%d : pas de prélèvement" % day_number)
		var report: EveningReport = Campaign.preview_evening(data, lines, events)
		var ending: StringName = Campaign.close_evening(data, summary, report, 0, DIR)
		if ending != EveningReport.ENDING_NONE:
			fail_test("fin anticipée %s au J%d (politique ~86 %%)" % [ending, day_number])
			return
		if day_number >= 10:
			var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
			assert_true(GameState.load_from_slot(0, DIR), "J%d relu" % day_number)
			assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected, "J%d : état identique" % day_number)
	assert_true(Campaign.is_act3(), "soirée pivot du J20 : Acte III commencé")
	assert_eq(GameState.current_day, 21)


# ---------------------------------------------------------------------------
# Bugs ouverts (pending tant qu'ils existent)
# ---------------------------------------------------------------------------

## Foyers représentatifs de l'Acte II pour les briefings.
func _households() -> Array[Household]:
	var plain: Household = Household.new()
	var soute: Household = Household.new()
	soute.send_away(Household.ILAN, Household.AWAY_SOUTE)
	var held: Household = Household.new()
	held.get_member(Household.ILAN).detained = true
	return [plain, soute, held]


## QA-019 : briefing du J11, vannes ouvertes (cas le plus fréquent des campagnes
## réelles) : la clé `msg_cons_day11_albedo` manquait dans `fr.csv` et le
## bulletin Albédo évinçait l'annonce du prélèvement (même groupe `levy`).
## Aucune clé brute aux briefings J10–J20 ; le prélèvement est toujours annoncé.
func test_act_two_briefings_have_no_raw_key() -> void:
	var raw: PackedStringArray = []
	var variants: Array[Array] = [[], [&"vannes_opened"], [&"vannes_failed"], [&"vannes_aborted"],
			[&"vannes_opened", &"ilan_in_hiding"], [&"vannes_failed", &"ilan_arrested_vannes"], [&"strike_joined"],
			[&"registre_sent"], [&"ilan_joined_soute"], [&"promotion_offered"], [&"okonkwo_warned"]]
	for n: int in range(10, data.get_last_day_number() + 1):
		for flag_set: Array in variants:
			for home: Household in _households():
				var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT2: true}
				for flag: StringName in flag_set:
					flags[flag] = true
				var content: BriefingContent = BriefingContent.build(data.get_day(n), flags, home, 0)
				for message: Dictionary in content.messages:
					for key: String in [message["text"], message["speaker"]]:
						if not UiText.has(key) and not raw.has("J%d %s" % [n, key]):
							raw.append("J%d %s" % [n, key])
				for key: String in [content.directive_key, content.directive_title_key, content.slogan_key]:
					if not UiText.has(key) and not raw.has("J%d %s" % [n, key]):
						raw.append("J%d %s" % [n, key])
	assert_eq(raw, PackedStringArray(), "QA-019 : clés absentes de fr.csv au briefing")
	# Le bulletin du J11 annonce toujours le prélèvement, Albédo ou non.
	for flag_set: Array in variants:
		for home: Household in _households():
			var flags: Dictionary[StringName, Variant] = {EndingService.FLAG_ACT2: true, &"lucioles_trust": 3}
			for flag: StringName in flag_set:
				flags[flag] = true
			var content: BriefingContent = BriefingContent.build(data.get_day(11), flags, home, 0)
			var levy_announced: bool = false
			for message: Dictionary in content.messages:
				levy_announced = levy_announced or UiText.t(str(message["text"])).contains("Prélèvement de Rééquilibrage")
			assert_true(levy_announced, "J11 %s : prélèvement annoncé" % [flag_set])


## QA-020 : J12+, quatre documents (carte, permis, bio-scan, contrat) en
## 1920×1080 : la mise en page par défaut les fait se chevaucher de ~40 % ; la
## date d'expiration du permis et du bio-scan (et le N° ID de la carte) sont
## sous le document suivant — y compris le champ visé par un lien du scanner.
func test_four_documents_keep_their_expiry_dates_visible() -> void:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	# Écran 1920×1080 (la fenêtre de GUT est plus haute).
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1920, 1080)
	ui.workbench.reduce_motion = true
	var day: DayDef = data.get_day(12)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	var case: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT, CaseFactory.BIOSCAN])
	case.documents.append(CaseFactory.document(&"work_contract", case.passenger_presented))
	case.index = 0
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	await wait_seconds(1.0)
	var views: Array[DocumentView] = ui.workbench.views
	assert_eq(views.size(), 4, "quatre documents posés")
	var hidden: PackedStringArray = []
	for i: int in views.size():
		var item: InspectableItem = views[i].find_item(FieldRef.new(views[i].get_document_id(), &"expiry_date"))
		if item == null:
			continue
		var rect: Rect2 = item.get_global_rect()
		for j: int in range(i + 1, views.size()):
			var cover: Rect2 = views[j].get_global_rect()
			if cover.intersects(rect) and cover.intersection(rect).get_area() > rect.get_area() * 0.25:
				hidden.append("%s (sous %s)" % [views[i].get_document_id(), views[j].get_document_id()])
				break
	assert_eq(hidden.size(), 0, "QA-020 : expiration visible au placement initial (1080p, 4 documents) : %s" % ", ".join(hidden))
	assert_false(ui.workbench.is_stacked(), "1080p, 4 documents : tous côte à côte (les piles n'y grossiraient pas le texte)")
	assert_gte(ui.workbench.fit_scale, ui.workbench.min_fit_scale(), "échelle lisible")


## Critère de bascule (QA-020 / QA-004) : ≥ 12 px physiques pour les valeurs
## des champs, échelle de la fenêtre comprise.
func test_document_scale_targets_twelve_physical_pixels() -> void:
	assert_almost_eq(Workbench.readable_scale_for(16.0, 1.0, 0.72), 0.75, 0.001, "1080p : valeurs 16 px")
	assert_almost_eq(Workbench.readable_scale_for(18.0, 1280.0 / 1920.0, 0.72), 1.0, 0.001, "Deck : plancher 18 px × 0,67")
	assert_almost_eq(Workbench.readable_scale_for(24.0, 1.0, 0.48), 0.5, 0.001, "texte 1,5 en 1080p")
	assert_almost_eq(Workbench.readable_scale_for(40.0, 1.0, 0.72), 0.72, 0.001, "jamais sous l'échelle minimale")


## QA-020 : cinq documents (J20, figure finale + ticket de file) : la largeur ne
## suffit plus côte à côte, le plan range des piles à onglets. Chaque document
## de devant est entier, chaque document du fond montre son onglet (titre), et
## la touche n (`focus_document`) l'amène devant sans rien couvrir.
func test_five_documents_stack_with_readable_tabs() -> void:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	# Écran 1920×1080 (la fenêtre de GUT est plus haute).
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1920, 1080)
	ui.workbench.reduce_motion = true
	var day: DayDef = data.get_day(20)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	var case: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT, CaseFactory.BIOSCAN])
	case.documents.append(CaseFactory.document(&"work_contract", case.passenger_presented))
	case.documents.append(CaseFactory.document(&"queue_ticket", case.passenger_presented))
	case.index = 0
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	await wait_seconds(1.0)
	var bench: Workbench = ui.workbench
	assert_eq(bench.views.size(), 5, "cinq documents posés")
	assert_gte(bench.fit_scale, bench.min_fit_scale(), "échelle lisible")
	for view: DocumentView in bench.views:
		var covered: float = _covered_ratio(bench, view, Rect2(Vector2.ZERO, Vector2(view.size.x, view.tab_height())))
		assert_lt(covered, 0.25, "%s : onglet visible" % view.get_document_id())
		if bench.is_front(view):
			assert_lt(_covered_ratio(bench, view, Rect2(Vector2.ZERO, view.size)), 0.02, "%s : document de devant entier" % view.get_document_id())
	for i: int in bench.views.size():
		assert_true(bench.focus_document(i), "touche %d" % (i + 1))
		var view: DocumentView = bench.views[i]
		assert_true(bench.is_front(view))
		assert_lt(_covered_ratio(bench, view, Rect2(Vector2.ZERO, view.size)), 0.02, "%s devant : entier" % view.get_document_id())


## QA-023 : paire concordante comparée puis documents rendus avant la fin du
## surlignage (1,5 s) : aucun rappel sur un champ libéré (journal propre),
## le surlignage s'efface sinon normalement.
func test_concordant_mark_survives_documents_leaving_early() -> void:
	var ui: ComparisonUI = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	# Écran 1920×1080 (la fenêtre de GUT est plus haute).
	ui.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	ui.size = Vector2(1920, 1080)
	ui.workbench.reduce_motion = true
	var day: DayDef = data.get_day(12)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	var case: Case = CaseFactory.valid_case([CaseFactory.ID_CARD, CaseFactory.PERMIT])
	case.index = 0
	EventBus.case_presented.emit(case)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, case.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, case.case_id)
	EventBus.documents_presented.emit(case.case_id)
	await wait_process_frames(3)
	var context: RuleContext = CaseFactory.context(day.rule_set, day.game_date)
	var fields: Array[StringName] = [&"family_name", &"given_name"]
	for pass_index: int in 2:
		var a: FieldRef = FieldRef.new(CaseFactory.ID_CARD, fields[pass_index])
		var b: FieldRef = FieldRef.new(CaseFactory.PERMIT, fields[pass_index])
		ui.set_inspection_active(true)
		ui.pick(a)
		ui.pick(b)
		var result: Discrepancy = DiscrepancyChecker.check(case, a, b, context)
		assert_eq(result.result, Discrepancy.Result.CONCORDANT)
		EventBus.discrepancy_checked.emit(result)
		var item: InspectableItem = ui.workbench.find_item(a)
		assert_true(item.concordant, "paire surlignée")
		if pass_index == 0:
			await wait_seconds(DS.CONCORDANT_HOLD + DS.DUR_BASE + 0.2)
			assert_false(item.concordant, "surlignage effacé après %.1f s" % DS.CONCORDANT_HOLD)
		else:
			ui.workbench.clear(false)
			await wait_seconds(DS.CONCORDANT_HOLD + DS.DUR_BASE + 0.2)
			assert_eq(ui.workbench.views.size(), 0, "documents rendus avant la fin du surlignage, sans erreur")


## Part de `local` (repère du document) couverte par les documents affichés
## au-dessus de lui.
func _covered_ratio(bench: Workbench, view: DocumentView, local: Rect2) -> float:
	var rect: Rect2 = Rect2(view.get_global_transform() * local.position, local.size * view.get_global_transform().get_scale())
	var worst: float = 0.0
	for other: DocumentView in bench.views:
		if other == view or other.get_index() < view.get_index():
			continue
		var cover: Rect2 = other.get_global_rect().intersection(rect)
		if cover.has_area():
			worst = maxf(worst, cover.get_area() / rect.get_area())
	return worst


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
	screen.setup(day, balance, 20, lines, home, false)
	screen.set_events(events)
	return screen


## QA-021 : la boîte « QUITTER HALCYON ? » (J10, « Embarquer ») n'est pas
## modale au clavier / à la manette : Tab depuis CONFIRMER LE DÉPART sort de la
## boîte vers les postes de dépense derrière le voile (et jusqu'à VALIDER ET
## DORMIR) ; `confirm()` est accepté boîte ouverte (la nuit passe avec le choix
## par défaut « Rester », la boîte reste sous le rapport de nuit).
func test_quit_halcyon_confirmation_is_modal() -> void:
	GameState.household = Household.new()
	var screen: EveningScreen = _evening(10, {&"drift_passes_bought": true, &"final_passed": true})
	add_child_autofree(screen)
	await wait_process_frames(2)
	var drift: EveningEvent = screen.get_event(&"d10_drift")
	assert_not_null(drift)
	screen.show_step(screen.events.find(drift))
	await wait_process_frames(1)
	screen.request_choice(&"d10_drift", &"board")
	await wait_process_frames(2)
	assert_not_null(screen.confirm_layer, "boîte ouverte")
	var accept: Control = screen.confirm_layer.find_child("Accept", true, false) as Control
	var next: Control = accept.find_next_valid_focus()
	var escapes: bool = next != null and not screen.confirm_layer.is_ancestor_of(next)
	var previous: Control = accept.find_prev_valid_focus()
	screen.confirm()
	var validated_behind: bool = screen.confirm_layer != null and screen.choices.has(&"d10_drift")
	assert_false(escapes, "QA-021 : Tab reste dans la boîte (%s)" % [String(next.name) if next != null else "—"])
	assert_true(previous != null and screen.confirm_layer.is_ancestor_of(previous), "Maj+Tab reste dans la boîte")
	assert_false(validated_behind, "VALIDER ignoré boîte ouverte")
	assert_not_null(screen.confirm_layer, "boîte toujours ouverte")
	# Échap = annuler (« Rester »), le choix reste en suspens.
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"cancel"
	escape.pressed = true
	screen._input(escape)
	assert_null(screen.confirm_layer, "Échap ferme la boîte")
	var chosen: StringName = screen.choices.get(&"d10_drift", &"")
	assert_ne(chosen, &"board", "« Embarquer » non choisi")


## QA-022 : noms de famille des personnages tirés pour des passagers générés
## (« Tomás Navarro » le jour d'Elena Navarro, « Soren Sato » le jour de la
## révocation de Sato, un Kerr au J13). Depuis le correctif, le nom de famille
## de **chaque** personnage scénarisé des deux actes est réservé : aucun
## passager généré ne le porte, quel que soit le jour.
func test_act_two_character_surnames_are_not_drawn_for_generated_passengers() -> void:
	var families: Dictionary[String, bool] = {}
	for day: DayDef in data.days.values():
		for scripted: ScriptedCaseDef in day.scripted_cases:
			for value: Variant in [scripted.passenger_overrides.get(&"family_name", ""),
					scripted.truth_overrides.get(&"family_name", "")]:
				if not str(value).is_empty():
					families[str(value)] = true
	for family: String in ["Navarro", "Kerr", "Sato", "Lindgren", "Beaumont", "Okonkwo"]:
		assert_true(families.has(family), "personnage %s" % family)
	var hits: PackedStringArray = []
	var generated: int = 0
	for campaign: int in range(1, 7):
		for n: int in range(1, data.get_last_day_number() + 1):
			var day: DayDef = data.get_day(n)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [])
			for i: int in day.passenger_count:
				if builder.get_scripted_case(i) != null:
					continue
				var p: Passenger = builder.build(i).case.passenger_presented
				generated += 1
				if families.has(p.family_name):
					hits.append("graine %d J%d #%d %s %s" % [campaign, n, i, p.given_name, p.family_name])
	assert_gt(generated, 1000, "passagers générés")
	assert_eq(hits, PackedStringArray(), "QA-022 : passagers générés homonymes d'un personnage")


# ---------------------------------------------------------------------------
# Robustesse de la vraie scène (passent : non-régressions)
# ---------------------------------------------------------------------------

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")


func _day_scene(day_number: int, flags: Array[StringName] = []) -> DayScene:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	GameState.new_campaign(20_871_315)
	GameState.current_day = day_number
	GameState.set_flag(EndingService.FLAG_ACT2, true)
	for flag: StringName in flags:
		GameState.set_flag(flag, true)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	return scene


## Scanner (J14, ACV-2) : un lien suggéré survit à une pause ouverte / fermée,
## se confirme ensuite ; la fin du temps pendant l'inspection n'interrompt ni
## la confirmation ni le tampon ; le bilan arrive après le départ.
func test_scanner_suggestion_survives_pause_and_time_out() -> void:
	var scene: DayScene = _day_scene(14, [PartialScanner.FLAG_CONSORTIUM])
	var ui: ComparisonUI = scene.ui as ComparisonUI
	scene.briefing.close()
	ui.request_next_case()
	assert_true(await wait_until(func() -> bool: return ui.documents_shown, 8.0), "documents posés")
	var dc: DayController = scene.day_controller
	var case: Case = dc.current_case
	# Vraie discordance (le scanner ne suggère que des dates dépassées) : une
	# paire concordante déclencherait QA-023 au départ du passager.
	case.documents[0].expiry_date = dc.day.game_date - 3
	var link: Discrepancy = Discrepancy.new(FieldRef.new(case.documents[0].type_def.id, &"expiry_date"), FieldRef.today())
	EventBus.scanner_suggested.emit(case.case_id, [link] as Array[Discrepancy], PartialScanner.SOURCE_ACV)
	assert_eq(ui.pending_suggestion_count(), 1, "lien suggéré")
	scene.pause_menu.open()
	await wait_process_frames(3)
	scene.pause_menu.close()
	await wait_process_frames(2)
	assert_eq(ui.pending_suggestion_count(), 1, "suggestion conservée après la pause")
	dc._on_day_time_expired()
	assert_eq(dc.phase, DayPhase.Kind.INSPECTING, "fin du temps : le cas en cours continue")
	assert_true(ui.confirm_suggestion(), "confirmation après la fin du temps")
	EventBus.verdict_stamped.emit(Verdict.new(case.case_id, VerdictKind.Kind.DENY))
	assert_eq(dc.summary.get_processed_count(), 1, "tampon accepté")
	assert_true(await wait_until(func() -> bool: return scene.screen is ShiftSummaryScreen, 20.0), "bilan après le départ")
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


## Grève du J20 : spam de « Suivant » et de tampons pendant les lumières
## coupées : aucun passager de plus, le bilan arrive une seule fois.
func test_strike_lights_out_ignores_spam() -> void:
	var scene: DayScene = _day_scene(20, [&"strike_joined"])
	var ui: ComparisonUI = scene.ui as ComparisonUI
	scene.briefing.close()
	var dc: DayController = scene.day_controller
	ui.request_next_case()
	assert_true(await wait_until(func() -> bool: return ui.documents_shown, 8.0))
	var case_id: StringName = dc.current_case_id()
	EventBus.hall_announced.emit("hall_j20_strike")
	dc.shift_ended_early = true
	EventBus.verdict_stamped.emit(Verdict.new(case_id, VerdictKind.Kind.APPROVE))
	for i: int in 10:
		ui.request_next_case()
		EventBus.next_case_requested.emit()
		EventBus.verdict_stamped.emit(Verdict.new(case_id, VerdictKind.Kind.DENY))
		await wait_process_frames(1)
	assert_eq(dc.summary.get_processed_count(), 1, "un seul verdict")
	assert_true(await wait_until(func() -> bool: return scene.screen is ShiftSummaryScreen, 20.0), "bilan après le noir")
	assert_eq(dc.next_index, 1, "aucun passager appelé pendant la grève")
	assert_eq(scene.screen_history.count(&"summary"), 1)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


## QA-024 : note des postes du soir lue en clé par défaut `ev_note_<id>`
## (`ExpenseLine`) : « ev_note_levy » sous le Prélèvement de Rééquilibrage
## (J11, J17 : toute épargne > 40 ₵) et « ev_note_lease » sous la location de
## l'ACV-2 (J14–J19) s'affichaient en clair. Tous les jours, foyers malades ou
## absents, drapeaux de l'Acte II.
func test_evening_line_notes_are_translated() -> void:
	var economy: EconomyDef = data.get_economy()
	var raw: PackedStringArray = []
	for n: int in range(1, data.get_last_day_number() + 1):
		for variant: int in 2:
			var flags: Dictionary[StringName, Variant] = {}
			if variant == 1:
				flags = {PartialScanner.FLAG_CONSORTIUM: true, EveningService.FLAG_ILAN_JOB: true, &"meter_refused": true,
						EndingService.FLAG_ACT2: true}
			for home: Household in _evening_households():
				var lines: Array[ExpenseLine] = EveningService.build_lines(economy, n, home, flags, 200)
				lines.append_array(EveningService.income_lines(economy, n, home, flags))
				for line: ExpenseLine in lines:
					for key: String in [line.label_key, line.note_key]:
						if not key.is_empty() and not UiText.has(key) and not raw.has(key):
							raw.append(key)
	assert_eq(raw, PackedStringArray(), "notes de postes non traduites")


func _evening_households() -> Array[Household]:
	var homes: Array[Household] = _households()
	var sick: Household = Household.new()
	var grave: Household = Household.new()
	for member: Household.Member in sick.members:
		member.health = Household.Health.SICK
	for member: Household.Member in grave.members:
		member.health = Household.Health.GRAVELY_SICK
	homes.append_array([sick, grave])
	return homes


## QA-024 / QA-028 : **toute clé référencée par les données** (`data/` :
## briefings, soirées et options, annonces, avis, révocations, cas scénarisés,
## objets glissés, documents, règles, factions) existe dans `fr.csv`. Parcours
## réflexif des propriétés stockées : `*_key`, `key` (`ConditionalKey`),
## `*_keys` ; ressources, tableaux et dictionnaires imbriqués.
func test_every_data_referenced_key_exists_in_fr_csv() -> void:
	var missing: PackedStringArray = []
	var seen: Dictionary[int, bool] = {}
	var roots: Array = []
	roots.append_array(data.factions.values())
	roots.append_array(data.documents.values())
	roots.append_array(data.rules.values())
	roots.append_array(data.rule_sets.values())
	roots.append_array(data.days.values())
	roots.append(data.get_economy())
	for root: Variant in roots:
		_collect_missing_keys(root, "", missing, seen)
	assert_gt(seen.size(), 100, "parcours des données")
	assert_eq(missing, PackedStringArray(), "clés des données absentes de fr.csv")


## QA-030 : la barrière de mixage (autoload) tourne à chaque image, pause
## comprise, avant `AudioServer.update()` ; elle rend la main aussitôt.
func test_audio_mix_barrier_is_always_processing() -> void:
	var barrier: Node = get_tree().root.get_node_or_null("AudioMixBarrier")
	assert_not_null(barrier, "autoload AudioMixBarrier")
	if barrier == null:
		return
	assert_eq(barrier.process_mode, Node.PROCESS_MODE_ALWAYS)
	assert_true(barrier.is_processing())
	var start: int = Time.get_ticks_msec()
	for i: int in 100:
		barrier.call(&"sync_with_mixer")
	assert_lt(Time.get_ticks_msec() - start, 1000, "100 barrières en moins d'une seconde")


## QA-028 (données) : chaque code employeur de R25 a son libellé `rb_emp_*`.
func test_employer_codes_have_label_keys() -> void:
	var found: int = 0
	for rule: Rule in data.rules.values():
		var consistent: ContractConsistentRule = rule as ContractConsistentRule
		if consistent == null:
			continue
		for employer: String in consistent.employer_codes:
			found += 1
			var key: String = ContractConsistentRule.label_key(consistent.employer_codes[employer])
			assert_true(UiText.has(key), "%s → %s" % [employer, key])
			assert_true(UiText.t(key).ends_with(employer), "%s : libellé « %s »" % [key, UiText.t(key)])
	assert_eq(found, 14, "13 codes employeurs + AR (Acte III)")


func _collect_missing_keys(value: Variant, prop: String, missing: PackedStringArray, seen: Dictionary[int, bool]) -> void:
	match typeof(value):
		TYPE_OBJECT:
			if not value is Resource:
				return
			var res: Resource = value
			if seen.has(res.get_instance_id()):
				return
			seen[res.get_instance_id()] = true
			for info: Dictionary in res.get_property_list():
				var name: String = info["name"]
				var usage: int = info["usage"]
				if (usage & PROPERTY_USAGE_STORAGE) == 0 or name == "script" or name.begins_with("resource_"):
					continue
				_collect_missing_keys(res.get(name), name, missing, seen)
		TYPE_ARRAY:
			for item: Variant in value:
				_collect_missing_keys(item, prop, missing, seen)
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			for item: Variant in dict.values():
				_collect_missing_keys(item, prop, missing, seen)
		TYPE_PACKED_STRING_ARRAY:
			if prop.ends_with("_keys"):
				for key: String in value:
					if not UiText.has(key) and not missing.has(key):
						missing.append(key)
		TYPE_STRING, TYPE_STRING_NAME:
			var key: String = str(value)
			if (prop == "key" or prop.ends_with("_key")) and not key.is_empty() and not UiText.has(key) \
					and not missing.has(key):
				missing.append(key)
