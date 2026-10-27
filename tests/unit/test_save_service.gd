## Sauvegarde JSON versionnée (ARCHITECTURE §10, D-008) : aller-retour via
## `GameState`, écriture atomique, migration v1 → v2, fichiers refusés.
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")
const DIR: String = "user://test_saves"

var _state: Node


func before_each() -> void:
	_state = autofree(GameStateScript.new())
	SaveService.delete(0, DIR)
	SaveService.delete(1, DIR)


func after_all() -> void:
	SaveService.delete(0, DIR)
	SaveService.delete(1, DIR)
	DirAccess.remove_absolute(DIR)


func _fill(state: Node) -> void:
	state.call(&"new_campaign", 987_654)
	state.set(&"current_day", 3)
	state.set(&"credits", -7)
	state.set(&"score_total", 85)
	state.set(&"citations", 4)
	state.call(&"set_flag", &"met_mira", true)
	state.call(&"add_to_flag", &"lucioles_trust", 2)
	state.call(&"set_flag", &"ending", "none")
	var home: Household = state.get(&"household")
	home.get_member(Household.NOA).health = Household.Health.SICK
	home.cold_streak = 1
	var history: Array[Dictionary] = state.get(&"day_history")
	history.append({"day": 1, "correct": 7, "errors": 1, "credits": 35, "wage": 35, "spent": 33, "balance": 2})


func test_roundtrip_through_game_state() -> void:
	_fill(_state)
	assert_false(SaveService.has_save(0, DIR))
	assert_eq(_state.call(&"save_to_slot", 0, DIR), OK)
	assert_true(SaveService.has_save(0, DIR))
	assert_false(FileAccess.file_exists(SaveService.slot_path(0, DIR) + ".tmp"), "écriture atomique : pas de .tmp résiduel")
	var other: Node = autofree(GameStateScript.new())
	assert_true(other.call(&"load_from_slot", 0, DIR))
	assert_eq(other.call(&"to_save_dict"), _state.call(&"to_save_dict"), "aller-retour exact")
	assert_eq(typeof(other.call(&"get_flag", &"lucioles_trust")), TYPE_INT, "entiers restaurés en int")
	var home: Household = other.get(&"household")
	assert_eq(home.get_member(Household.NOA).health, Household.Health.SICK)


func test_file_is_versioned_json() -> void:
	_fill(_state)
	_state.call(&"save_to_slot", 0, DIR)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveService.slot_path(0, DIR)))
	assert_true(parsed is Dictionary)
	var data: Dictionary = parsed
	assert_eq(SaveService.as_int(data["version"]), SaveService.VERSION)
	assert_true(data.has("saved_at"))
	assert_true(data.has("household"))


func test_migration_from_v1() -> void:
	var v1: Dictionary = {
		"version": 1, "campaign_seed": 42, "current_day": 2, "credits": 12, "score_total": 40,
		"citations": 1, "narrative_flags": {"met_okonkwo": true},
		"day_history": [{"day": 1, "correct": 8, "errors": 0, "credits": 40}],
	}
	var data: Dictionary = SaveService.parse(JSON.stringify(v1))
	assert_false(data.is_empty(), "v1 migrée")
	assert_eq(SaveService.as_int(data["version"]), 2)
	var home: Dictionary = data["household"]
	assert_eq(Household.from_dict(home).to_dict(), Household.new().to_dict(), "foyer par défaut")
	var history: Array = data["day_history"]
	var day: Dictionary = history[0]
	assert_eq(SaveService.as_int(day["wage"]), 40)
	assert_true(_state.call(&"load_from_slot", 0, DIR) == false)
	_state.call(&"apply_save_dict", data)
	assert_eq(_state.get(&"current_day"), 2)
	assert_eq(_state.get(&"credits"), 12)


func test_rejects_invalid_files() -> void:
	assert_true(SaveService.parse("{ pas du json").is_empty())
	assert_true(SaveService.parse(JSON.stringify({"version": 99, "current_day": 1})).is_empty(), "version future")
	assert_true(SaveService.parse(JSON.stringify({"version": 2, "current_day": 1})).is_empty(), "schéma incomplet")
	var bad_type: Dictionary = {"version": 2, "campaign_seed": 1, "current_day": 1, "credits": "beaucoup",
			"score_total": 0, "citations": 0, "narrative_flags": {}, "day_history": [], "household": {}}
	assert_true(SaveService.parse(JSON.stringify(bad_type)).is_empty(), "type invalide")
	DirAccess.make_dir_recursive_absolute(DIR)
	var file: FileAccess = FileAccess.open(SaveService.slot_path(1, DIR), FileAccess.WRITE)
	file.store_string("<resource>")
	file.close()
	assert_false(_state.call(&"load_from_slot", 1, DIR), "fichier corrompu refusé")


func test_delete() -> void:
	_fill(_state)
	_state.call(&"save_to_slot", 0, DIR)
	SaveService.delete(0, DIR)
	assert_false(SaveService.has_save(0, DIR))
