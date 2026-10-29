## M9 — Acte III sans UI : migration v4 → v5 sur de vraies sauvegardes v0.9.0
## (soir du J19), reprise J20 → J30 (pivot, soirées, Déposition, bilan final) ;
## signaux du contrat UI M9 (`ledger_changed`, `summons_published`) dans un
## vrai shift ; déterminisme des campagnes simulées J1–J30.
extends GutTest

const SaveChecks := preload("res://tests/helpers/save_checks.gd")
const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DIR: String = "user://test_act3_campaign_saves"
const MAX_WAIT_SEC: float = 2.0
const VK := VerdictKind.Kind
## Sauvegardes v4 réelles (v0.9.0, soir du J19) : graines 11, 5, 3 ; profils
## `solidaire`, `luciole`, `loyal` à 95 %.
const V4_FIXTURES: Dictionary[String, StringName] = {
	"res://tests/fixtures/qa_save_v4_j20_solidaire.json": &"solidaire",
	"res://tests/fixtures/qa_save_v4_j20_luciole.json": &"luciole",
	"res://tests/fixtures/qa_save_v4_j20_loyal.json": &"loyal",
}

var data: DataCatalog = null
var h: DayHarness = null
var _saved_state: Dictionary = {}
var _ledger: Array[Array] = []
var _summons: Array[SummonsEntry] = []


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	SaveService.delete_slot(1, DIR)
	_ledger.clear()
	_summons.clear()
	EventBus.ledger_changed.connect(_on_ledger)
	EventBus.summons_published.connect(_on_summons)


func after_each() -> void:
	EventBus.ledger_changed.disconnect(_on_ledger)
	EventBus.summons_published.disconnect(_on_summons)
	if h != null:
		h.dispose()
		h = null
	SaveService.delete_slot(1, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _on_ledger(entries: Array[LedgerEntry]) -> void:
	_ledger.append(entries.duplicate())


func _on_summons(entries: Array[SummonsEntry]) -> void:
	_summons = entries.duplicate()


## Joue le jour courant (simulateur, profil) et sa soirée ; renvoie la fin.
func _play_simulated_day(profile: SimProfile) -> StringName:
	var day_number: int = GameState.current_day
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags.duplicate()
	var memory: Dictionary = Campaign.memory_for_day(data)
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(GameState.get_day_seed(), "act3_test"))
	var summary: DaySummary = DaySimulator.play_day(data, day_number, GameState.get_day_seed(), profile, flags, memory, rng)
	GameState.add_credits(summary.get_total_income())
	for flag: StringName in flags:
		GameState.set_flag(flag, flags[flag])
	for key: Variant in memory:
		GameState.case_memory[key] = memory[key]
	if not Campaign.has_evening(data):
		return Campaign.close_final_day(data, summary, 1, DIR)
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var choices: Dictionary[StringName, StringName] = Campaign.default_choices(events, lines)
	var wanted: Dictionary[StringName, StringName] = profile.choices_for(events)
	for event_id: StringName in wanted:
		choices[event_id] = wanted[event_id]
	var report: EveningReport = Campaign.preview_evening(data, lines, events, choices)
	return Campaign.close_evening(data, summary, report, 1, DIR)


func test_real_v4_saves_migrate_and_play_to_j30() -> void:
	for path: String in V4_FIXTURES:
		var text: String = FileAccess.get_file_as_string(path)
		var raw: Dictionary = JSON.parse_string(text)
		assert_eq(SaveService.as_int(raw["version"]), 4, "%s : sauvegarde v4 d'origine" % path.get_file())
		var migrated: Dictionary = SaveService.parse(text, path)
		assert_false(migrated.is_empty(), "%s acceptée" % path.get_file())
		assert_eq(SaveService.as_int(migrated["version"]), SaveService.VERSION)
		assert_eq(SaveService.VERSION, 6)
		assert_eq(SaveService.as_int(migrated["current_day"]), 20, "soir du J19 → J20")
		GameState.apply_save_dict(migrated)
		assert_true(Campaign.is_act2(), "%s : Acte II en cours" % path.get_file())
		var profile: SimProfile = SimProfile.preset(V4_FIXTURES[path], 0.95)
		var ending: StringName = EveningReport.ENDING_NONE
		while ending == EveningReport.ENDING_NONE and GameState.current_day <= 30:
			var day_number: int = GameState.current_day
			ending = _play_simulated_day(profile)
			if day_number == 20 and ending == EveningReport.ENDING_NONE:
				assert_true(Campaign.is_act3(), "%s : pivot du J20 franchi" % path.get_file())
				assert_ne(EndingService.climate_of(GameState.narrative_flags), &"", "climat posé")
			if ending == EveningReport.ENDING_NONE and day_number in [20, 25, 29]:
				var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
				assert_true(GameState.load_from_slot(1, DIR), "J%d : sauvegarde v6 relue" % day_number)
				assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected, "J%d : état identique" % day_number)
				var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.slot_path(1, DIR)))
				assert_eq(SaveService.as_int(saved["version"]), 6)
		assert_true(EndingService.ALL_ENDINGS.has(ending), "%s : fin %s" % [path.get_file(), ending])
		SaveChecks.assert_archived(self, 1, DIR, ending, path.get_file())
		var epilogue: Dictionary = Campaign.epilogue(ending)
		var lines: PackedStringArray = epilogue.get("lines", PackedStringArray())
		assert_gt(lines.size(), 1, String(ending))
		for line: String in lines:
			assert_true(UiText.has(line), "%s : %s" % [ending, line])


func _play_real_day(day_number: int, flags: Dictionary) -> DaySummary:
	Campaign.new_game(data, 20_871_315)
	GameState.current_day = day_number
	for flag: Variant in flags:
		GameState.set_flag(StringName(str(flag)), flags[flag])
	h = DayHarness.new()
	h.setup(self, NullBooth.new(), GameState.current_day, 0, GameState.get_day_seed(), GameState.get_true_flags(),
			Campaign.memory_for_day(data))
	var dc: DayController = h.controller
	dc.close_intro()
	var guard: int = 0
	while dc.phase != DayPhase.Kind.SUMMARY and guard < 40:
		guard += 1
		EventBus.next_case_requested.emit()
		if dc.phase == DayPhase.Kind.SUMMARY:
			break
		var case_id: StringName = dc.current_case_id()
		await wait_until(func() -> bool: return h.events_for(case_id).has(&"documents_presented"), MAX_WAIT_SEC)
		h.investigate_current()
		EventBus.interrogation_requested.emit(InspectionSession.TOPIC_PURPOSE)
		h.stamp(dc.current_key.expected_verdict)
		await wait_until(func() -> bool: return dc.phase != DayPhase.Kind.DEPARTING, MAX_WAIT_SEC)
	return h.summaries[0] if not h.summaries.is_empty() else null


func test_ledger_and_summons_signals_in_a_real_shift() -> void:
	var summary: DaySummary = await _play_real_day(26, {"act2_started": true, "act3_started": true, "sc16_family_split": true})
	assert_not_null(summary)
	assert_gt(_ledger.size(), 1, "Main courante publiée au début puis à chaque admission")
	assert_eq(_ledger[0].size(), 0, "vide au début du shift")
	var last: Array = _ledger[_ledger.size() - 1]
	assert_gt(last.size(), 0, "répondants admis")
	for entry: LedgerEntry in last:
		assert_true(SponsorRule.is_eligible(entry.faction_id, entry.citizen_class), "C-1 à C-3, Né·e-Halcyon")
	assert_gt(_summons.size(), 0, "onglet Convocations publié")
	for i: int in range(1, _summons.size()):
		assert_true(_summons[i - 1].number <= _summons[i].number, "trié par N°")
	for result: CaseResult in summary.results:
		assert_true(result.correct, "%s : verdict attendu correct (%s)" % [result.case_id, result.citation_reason_key])


func test_full_act_three_simulation_is_deterministic() -> void:
	for preset: StringName in [&"passeur", &"temoin"]:
		var a: Array[Dictionary] = BalanceSimulator.run_campaign(data, 41, 0.9, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.9))
		var b: Array[Dictionary] = BalanceSimulator.run_campaign(data, 41, 0.9, BalanceSimulator.Spending.REASONED, -1,
				SimProfile.preset(preset, 0.9))
		assert_eq(a.size(), b.size(), String(preset))
		assert_eq(JSON.stringify(a), JSON.stringify(b), "%s : même graine, même campagne" % preset)
