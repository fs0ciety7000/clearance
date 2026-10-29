## M11 — migration v5 → v6 (D-101) sur de vraies sauvegardes 0.10.0
## (`qa_save_v5_j25_*.json` : soir du J24, Acte III, écrites par la 0.10.0
## en reprenant les sauvegardes 0.9.0 `qa_save_v4_j20_*`) : `slot_0.json`
## devient l'emplacement 1 sans perte, l'ancien fichier `slot_0.v5.bak` ;
## la partie reprend au J25 et va jusqu'à sa fin, archivée et inscrite au
## profil ; reprise d'un jour passé après migration.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SaveChecks := preload("res://tests/helpers/save_checks.gd")
const DIR: String = "user://test_save_migration_v6"
## Sauvegardes v5 réelles (0.10.0, soir du J24) et le profil qui les a jouées.
const V5_FIXTURES: Dictionary[String, StringName] = {
	"res://tests/fixtures/qa_save_v5_j25_luciole.json": &"luciole",
	"res://tests/fixtures/qa_save_v5_j25_solidaire.json": &"solidaire",
}
const V4_FIXTURE: String = "res://tests/fixtures/qa_save_v4_j20_loyal.json"

var data: DataCatalog = null
var _saved_state: Dictionary = {}


func before_all() -> void:
	data = Gen.data()


func before_each() -> void:
	_saved_state = GameState.to_save_dict()
	_clear()


func after_each() -> void:
	_clear()
	if SaveService.as_int(_saved_state.get("current_day", 0)) >= 1:
		GameState.apply_save_dict(_saved_state)
	else:
		GameState.new_campaign(1)
		GameState.current_day = 0


func _clear() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot, DIR)
	for name: String in [ProfileService.FILE_NAME, SaveService.LEGACY_FILE, SaveService.LEGACY_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


## Dépose une ancienne sauvegarde comme le ferait un build 0.10.0.
func _install_legacy(fixture: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var text: String = FileAccess.get_file_as_string(fixture)
	var file: FileAccess = FileAccess.open(DIR.path_join(SaveService.LEGACY_FILE), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return text


## Joue le jour courant (simulateur, profil) et sa soirée ; renvoie la fin.
func _play_simulated_day(profile: SimProfile) -> StringName:
	var flags: Dictionary[StringName, Variant] = GameState.narrative_flags.duplicate()
	var memory: Dictionary = Campaign.memory_for_day(data)
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(GameState.get_day_seed(), "v6_test"))
	var summary: DaySummary = DaySimulator.play_day(data, GameState.current_day, GameState.get_day_seed(), profile, flags,
			memory, rng)
	GameState.add_credits(summary.get_total_income())
	for flag: StringName in flags:
		GameState.set_flag(flag, flags[flag])
	for key: Variant in memory:
		GameState.case_memory[key] = memory[key]
	if not Campaign.has_evening(data):
		return Campaign.close_final_day(data, summary, SaveService.NO_SLOT, DIR)
	var events: Array[EveningEvent] = Campaign.prepare_events(data)
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data, events)
	var choices: Dictionary[StringName, StringName] = Campaign.default_choices(events, lines)
	var wanted: Dictionary[StringName, StringName] = profile.choices_for(events)
	for event_id: StringName in wanted:
		choices[event_id] = wanted[event_id]
	var report: EveningReport = Campaign.preview_evening(data, lines, events, choices)
	return Campaign.close_evening(data, summary, report, SaveService.NO_SLOT, DIR)


func test_real_v5_saves_migrate_without_loss_and_play_to_the_end() -> void:
	for fixture: String in V5_FIXTURES:
		_clear()
		var text: String = _install_legacy(fixture)
		var raw: Dictionary = JSON.parse_string(text)
		assert_eq(SaveService.as_int(raw["version"]), 5, "%s : sauvegarde v5 d'origine" % fixture.get_file())
		assert_eq(str(raw["game_version"]), "0.10.0")
		# Référence : l'état tel que la 0.10.0 l'aurait rechargé.
		GameState.apply_save_dict(SaveService.parse(text, fixture))
		var expected: String = JSON.stringify(GameState.to_save_dict(), "", true)
		GameState.new_campaign(1)
		# « Continuer » à l'écran titre : migration à la première lecture.
		assert_eq(SaveService.latest_slot(DIR), 1, "%s → emplacement 1" % fixture.get_file())
		assert_false(FileAccess.file_exists(DIR.path_join(SaveService.LEGACY_FILE)), "slot_0.json déplacé")
		var backup: String = DIR.path_join(SaveService.LEGACY_BACKUP_FILE)
		assert_true(FileAccess.file_exists(backup), "ancien fichier gardé en .v5.bak")
		assert_eq(FileAccess.get_file_as_string(backup), text, "jamais modifié")
		assert_eq(SaveService.migrate_legacy(DIR), SaveService.NO_SLOT, "idempotent")
		assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([25]), "instantané du jour courant seulement")
		var meta: Dictionary = SaveService.load_meta(1, DIR)
		assert_eq(SaveService.as_int(meta["current_day"]), 25)
		assert_eq(SaveService.as_int(meta["act"]), 3, "Acte III")
		assert_eq(SaveService.as_int(meta["credits"]), SaveService.as_int(raw["credits"]))
		assert_eq(str(meta["saved_at"]), str(raw["saved_at"]), "date d'origine conservée")
		assert_eq(str(meta["difficulty"]), "hard")
		assert_eq(str(meta["status"]), "active")
		var current: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveService.slot_path(1, DIR)))
		assert_eq(SaveService.as_int(current["version"]), 6)
		assert_true(GameState.load_from_slot(SaveService.NO_SLOT, DIR), "Continuer")
		assert_eq(GameState.active_slot, 1)
		assert_eq(JSON.stringify(GameState.to_save_dict(), "", true), expected, "%s : sans perte" % fixture.get_file())
		assert_true(Campaign.is_act3())
		var profile: SimProfile = SimProfile.preset(V5_FIXTURES[fixture], 0.95)
		var ending: StringName = EveningReport.ENDING_NONE
		while ending == EveningReport.ENDING_NONE and GameState.current_day <= 30:
			ending = _play_simulated_day(profile)
		assert_true(EndingService.ALL_ENDINGS.has(ending), "%s : fin %s" % [fixture.get_file(), ending])
		SaveChecks.assert_archived(self, 1, DIR, ending, fixture.get_file())
		assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([25, 26, 27, 28, 29, 30]), "un instantané par soir")
		var characters: Array = ProfileService.load_profile(DIR)["characters_met"]
		assert_gt(characters.size(), 20, "personnages croisés depuis le J1 (mémoire des cas)")
		# Rejouer le J27 de la partie terminée : elle redevient active, J28+ effacés.
		assert_true(GameState.load_day_snapshot(1, 27, DIR))
		assert_eq(GameState.current_day, 27)
		assert_eq(_play_simulated_day(profile), EveningReport.ENDING_NONE)
		assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([25, 26, 27, 28]))
		assert_eq(str(SaveService.load_meta(1, DIR)["status"]), "active")
		assert_eq(SaveService.latest_slot(DIR), 1)


func test_v4_save_and_unreadable_legacy_files() -> void:
	# 0.9.0 (v4) : migrations en chaîne v4 → v5 → v6 puis emplacement.
	_install_legacy(V4_FIXTURE)
	assert_eq(SaveService.migrate_legacy(DIR), 1)
	assert_eq(SaveService.as_int(SaveService.load_meta(1, DIR)["current_day"]), 20)
	assert_eq(SaveService.as_int(SaveService.load_meta(1, DIR)["act"]), 2)
	# Emplacement 1 pris : une autre ancienne sauvegarde va dans le premier libre.
	_install_legacy(V4_FIXTURE)
	assert_eq(SaveService.migrate_legacy(DIR), 2)
	# Illisible : mise de côté (jamais supprimée), aucun emplacement créé.
	DirAccess.make_dir_recursive_absolute(DIR)
	var file: FileAccess = FileAccess.open(DIR.path_join(SaveService.LEGACY_FILE), FileAccess.WRITE)
	file.store_string("{ illisible")
	file.close()
	assert_eq(SaveService.migrate_legacy(DIR), SaveService.NO_SLOT)
	assert_false(SaveService.has_save(3, DIR))
	assert_eq(FileAccess.get_file_as_string(DIR.path_join(SaveService.LEGACY_BACKUP_FILE)), "{ illisible")
	assert_false(FileAccess.file_exists(DIR.path_join(SaveService.LEGACY_FILE)))
