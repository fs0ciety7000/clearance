## QA (docs/QA.md §4) — sauvegarde : relecture à chaque soir J1–J9 (soirées
## par défaut, `Campaign.close_evening`), sauvegardes corrompues ou hors bornes,
## reprise de la scène de jour depuis une sauvegarde. Bugs ouverts : `pending`.
extends GutTest

const SaveChecks := preload("res://tests/helpers/save_checks.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const DIR: String = "user://test_qa_saves"
const SEED: int = 4242

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	SaveService.delete_slot(1, DIR)


func after_each() -> void:
	get_tree().paused = false
	SaveService.delete_slot(1, DIR)
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _write_raw(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(SaveService.slot_dir(1, DIR))
	var file: FileAccess = FileAccess.open(SaveService.slot_path(1, DIR), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _valid_dict(day: int = 3) -> Dictionary:
	Campaign.new_game(data, SEED)
	GameState.current_day = day
	var d: Dictionary = GameState.to_save_dict()
	d["version"] = SaveService.VERSION
	return d


## Chaque soir J1–J9 : la sauvegarde automatique relue redonne l'état exact.
func test_every_evening_save_roundtrips() -> void:
	Campaign.new_game(data, SEED)
	var policy: Callable = func(_c: Case, key: CaseKey, i: int) -> VerdictKind.Kind:
		return key.expected_verdict if i % 4 != 3 else VerdictKind.Kind.APPROVE
	for day_number: int in range(1, 10):
		assert_eq(GameState.current_day, day_number)
		var summary: DaySummary = DaySimulator.simulate(data, day_number, GameState.get_day_seed(), policy)
		GameState.add_credits(summary.get_net())
		var events: Array[EveningEvent] = Campaign.prepare_events(data)
		var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
		var report: EveningReport = Campaign.preview_evening(data, lines, events)
		var ending: StringName = Campaign.close_evening(data, summary, report, 1, DIR)
		if ending != EveningReport.ENDING_NONE:
			SaveChecks.assert_archived(self, 1, DIR, ending, "fin %s au J%d" % [ending, day_number])
			return
		var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
		assert_true(GameState.load_from_slot(1, DIR), "J%d relu" % day_number)
		assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected, "J%d : état identique après relecture" % day_number)


func test_garbage_files_are_refused_without_crash() -> void:
	for text: String in ["", "{", "null", "[]", "\u0000\u0001\u0002", "{\"version\": \"3\"}",
			JSON.stringify({"version": 3, "current_day": 2})]:
		_write_raw(text)
		assert_true(SaveService.load_current(1, DIR).is_empty(), "refusé : %s" % text.c_escape())


func test_wrong_inner_types_load_safely() -> void:
	var d: Dictionary = _valid_dict(4)
	d["household"] = {"members": "pas une liste", "cold_streak": "x"}
	d["day_history"] = ["texte", 3, {"day": "un"}]
	d["narrative_flags"] = {"loyalty": "beaucoup", "suspicion": {"a": 1}, "met_mira": "oui"}
	d["case_memory"] = {"sc_02": "rien"}
	_write_raw(JSON.stringify(d))
	assert_true(GameState.load_from_slot(1, DIR), "schéma de premier niveau conforme")
	assert_eq(GameState.household.members.size(), 3, "foyer par défaut")
	# Le jour se construit malgré des jauges illisibles.
	var content: BriefingContent = BriefingContent.build(data.get_day(GameState.current_day), GameState.narrative_flags,
			GameState.household)
	assert_not_null(content)
	assert_eq(Campaign.compliance(), 0.0, "historique illisible ignoré")


## QA-003 (corrigé) : une sauvegarde au-delà du dernier jour des données (J11,
## J99) est refusée ; le dernier jour lui-même reste valide.
func test_out_of_range_day_is_refused() -> void:
	var last: int = data.get_last_day_number()
	assert_eq(SaveService.last_day(), last, "borne lue dans data/days")
	for day: int in [last + 1, 99]:
		_write_raw(JSON.stringify(_valid_dict(day)))
		assert_true(SaveService.load_current(1, DIR).is_empty(), "J%d refusé" % day)
		assert_false(GameState.load_from_slot(1, DIR), "J%d : état inchangé" % day)
	_write_raw(JSON.stringify(_valid_dict(last)))
	assert_false(SaveService.load_current(1, DIR).is_empty(), "J%d accepté" % last)


## QA-018 (corrigé) : l'écriture renomme le `.tmp` par-dessus la sauvegarde
## (jamais de suppression préalable) ; un `.tmp` complet laissé par un arrêt
## avant le renommage est relu si la sauvegarde principale manque.
func test_interrupted_save_is_recovered_from_tmp() -> void:
	assert_eq(SaveService.save_slot(_valid_dict(4), 1, DIR), OK)
	assert_eq(SaveService.save_slot(_valid_dict(5), 1, DIR), OK, "écrase la précédente")
	var path: String = SaveService.slot_path(1, DIR)
	assert_false(FileAccess.file_exists(path + SaveService.TMP_SUFFIX), "pas de .tmp résiduel")
	assert_false(FileAccess.file_exists(path + SaveService.BACKUP_SUFFIX), "pas de .bak résiduel")
	assert_eq(SaveService.as_int(SaveService.load_current(1, DIR).get("current_day")), 5)
	# Arrêt simulé entre l'écriture du .tmp et le renommage, ancienne absente.
	DirAccess.rename_absolute(path, path + SaveService.TMP_SUFFIX)
	assert_true(SaveService.has_save(1, DIR), ".tmp vu comme sauvegarde")
	assert_eq(SaveService.as_int(SaveService.load_current(1, DIR).get("current_day")), 5, "relu depuis le .tmp")
	SaveService.delete_slot(1, DIR)
	assert_false(SaveService.has_save(1, DIR), "delete efface aussi le .tmp")


func test_scene_resumes_from_a_loaded_save() -> void:
	_write_raw(JSON.stringify(_valid_dict(6)))
	assert_true(GameState.load_from_slot(1, DIR))
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(2)
	assert_eq(scene.day_controller.day.day_number, 6, "reprise au J6")
	assert_not_null(scene.briefing, "briefing du J6 affiché")
