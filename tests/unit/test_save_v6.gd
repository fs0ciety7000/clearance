## Sauvegarde v6 (M11, D-101, ARCHITECTURE §10) : emplacements, instantanés
## par soirée, troncature à la reprise d'un jour passé, archivage des fins,
## « Continuer » = partie active la plus récente, écriture atomique de chaque
## fichier, profil global (`ProfileService`), difficulté persistée (D-102).
extends GutTest

const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")
const DIR: String = "user://test_save_v6"

var _state: Node


func before_each() -> void:
	_state = autofree(GameStateScript.new())
	_clear()


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	for slot: int in range(0, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot, DIR)
	for name: String in [ProfileService.FILE_NAME, SaveService.LEGACY_FILE, SaveService.LEGACY_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


## Partie `seed` au matin du jour `day` (historique minimal), emplacement `slot`.
func _game(p_seed: int, slot: int, day: int = 2, difficulty: StringName = &"hard") -> Node:
	var state: Node = autofree(GameStateScript.new())
	state.call(&"new_campaign", p_seed, slot, difficulty)
	state.set(&"current_day", day)
	state.set(&"credits", 10 * day)
	return state


## Soirée simulée : jour suivant (historique), puis sauvegarde automatique.
func _evening(state: Node) -> void:
	state.call(&"record_day_entry", {"processed": 5, "correct": 5, "credits": 25})
	assert_eq(state.call(&"save_to_slot", SaveService.NO_SLOT, DIR), OK)


func test_save_writes_current_snapshot_and_meta() -> void:
	var state: Node = _game(11, 2, 3)
	state.call(&"set_flag", EndingService.FLAG_ACT2, true)
	(state.get(&"household") as Household).get_member(Household.NOA).health = Household.Health.SICK
	assert_eq(state.call(&"save_to_slot", SaveService.NO_SLOT, DIR), OK, "emplacement actif")
	for path: String in [SaveService.slot_path(2, DIR), SaveService.snapshot_path(2, 3, DIR), SaveService.meta_path(2, DIR)]:
		assert_true(FileAccess.file_exists(path), path.get_file())
		assert_false(FileAccess.file_exists(path + SaveService.TMP_SUFFIX), "%s : pas de .tmp résiduel" % path.get_file())
		assert_false(FileAccess.file_exists(path + SaveService.BACKUP_SUFFIX), "%s : pas de .bak résiduel" % path.get_file())
	assert_eq(SaveService.list_snapshots(2, DIR), PackedInt32Array([3]))
	var meta: Dictionary = SaveService.load_meta(2, DIR)
	for key: String in ["version", "game_version", "saved_at", "current_day", "act", "credits", "household_summary",
			"difficulty", "status", "ending_id", "portrait_seed", "play_time_sec"]:
		assert_true(meta.has(key), "meta.%s" % key)
	assert_eq(SaveService.as_int(meta["version"]), 6)
	assert_eq(SaveService.as_int(meta["current_day"]), 3)
	assert_eq(SaveService.as_int(meta["act"]), 2)
	assert_eq(SaveService.as_int(meta["credits"]), 30)
	assert_eq(str(meta["status"]), SaveService.STATUS_ACTIVE)
	assert_eq(str(meta["difficulty"]), SaveService.DIFFICULTY_HARD)
	var home: Dictionary = meta["household_summary"]
	assert_eq(SaveService.as_int(home["alive"]), 3)
	assert_eq(SaveService.as_int(home["sick"]), 1)
	assert_eq(SaveService.as_int(home["absent"]), 0)
	var current: Dictionary = SaveService.load_current(2, DIR)
	assert_eq(current, SaveService.load_snapshot(2, 3, DIR), "instantané du matin = état courant")
	assert_eq(str(current["difficulty"]), "hard")


func test_three_slots_and_continue_picks_the_latest_active_game() -> void:
	assert_eq(SaveService.latest_slot(DIR), SaveService.NO_SLOT, "aucune partie")
	assert_eq(SaveService.first_free_slot(DIR), 1)
	var slots: Array[Dictionary] = SaveService.list_slots(DIR)
	assert_eq(slots.size(), SaveService.SLOT_COUNT)
	for meta: Dictionary in slots:
		assert_true(meta.is_empty(), "emplacement libre")
	_evening(_game(1, 1))
	_evening(_game(2, 3))
	assert_eq(SaveService.latest_slot(DIR), 3, "le plus récent")
	assert_eq(SaveService.first_free_slot(DIR), 2)
	_evening(_game(3, 2))
	assert_eq(SaveService.latest_slot(DIR), 2)
	assert_eq(SaveService.first_free_slot(DIR), SaveService.NO_SLOT, "tout occupé")
	slots = SaveService.list_slots(DIR)
	for i: int in slots.size():
		assert_eq(SaveService.as_int(slots[i]["slot"]), i + 1)
	# Fin de la partie 2 : archivée, « Continuer » revient sur la 3.
	var ended: Node = _game(3, 2)
	ended.call(&"end_campaign", EndingService.F7_REOPENS, SaveService.NO_SLOT, DIR)
	assert_eq(SaveService.latest_slot(DIR), 3)
	assert_eq(SaveService.slot_for_new_game(DIR), 2, "nouvelle partie : la terminée d'abord")
	# « Continuer » par défaut : la partie active la plus récente.
	assert_true(_state.call(&"load_from_slot", SaveService.NO_SLOT, DIR))
	assert_eq(_state.get(&"active_slot"), 3)
	assert_eq(_state.get(&"campaign_seed"), 2)
	SaveService.delete_slot(3, DIR)
	assert_false(SaveService.has_save(3, DIR))
	assert_false(DirAccess.dir_exists_absolute(SaveService.slot_dir(3, DIR)), "dossier supprimé")
	assert_eq(SaveService.latest_slot(DIR), 1)


func test_resume_a_past_day_truncates_later_snapshots_on_next_save() -> void:
	var state: Node = _game(77, 1, 1)
	for i: int in 5:
		_evening(state)
	assert_eq(state.get(&"current_day"), 6)
	assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([2, 3, 4, 5, 6]))
	assert_true(_state.call(&"load_day_snapshot", 1, 3, DIR), "matin du J3")
	assert_eq(_state.get(&"current_day"), 3)
	assert_eq(_state.get(&"active_slot"), 1)
	assert_eq((_state.get(&"day_history") as Array).size(), 2, "historique du matin du J3")
	assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([2, 3, 4, 5, 6]), "rien d'écrit au chargement")
	assert_eq(SaveService.as_int(SaveService.load_current(1, DIR)["current_day"]), 6, "quitter avant le soir : J6 intact")
	_evening(_state)
	assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([2, 3, 4]), "une seule ligne de temps")
	assert_eq(SaveService.as_int(SaveService.load_current(1, DIR)["current_day"]), 4)
	assert_false(_state.call(&"load_day_snapshot", 1, 6, DIR), "instantané supprimé")
	assert_false(_state.call(&"load_day_snapshot", 1, 9, DIR), "jour inconnu : refusé")
	assert_eq(_state.get(&"current_day"), 4, "état inchangé après un refus")


func test_ending_archives_instead_of_deleting_and_can_be_resumed() -> void:
	var state: Node = _game(5, 1, 1)
	_evening(state)
	_evening(state)
	state.call(&"end_campaign", EndingService.F2_REASSIGNED, SaveService.NO_SLOT, DIR)
	state.call(&"end_campaign", EndingService.F2_REASSIGNED, SaveService.NO_SLOT, DIR)
	assert_true(SaveService.has_save(1, DIR), "D-101 : la partie n'est plus effacée")
	var meta: Dictionary = SaveService.load_meta(1, DIR)
	assert_eq(str(meta["status"]), SaveService.STATUS_ENDED)
	assert_eq(str(meta["ending_id"]), String(EndingService.F2_REASSIGNED))
	assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([2, 3]), "instantanés gardés")
	assert_eq(SaveService.latest_slot(DIR), SaveService.NO_SLOT, "pas de « Continuer » sur une partie terminée")
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(ProfileService.ending_ids(profile), PackedStringArray([String(EndingService.F2_REASSIGNED)]), "inscrite une fois")
	assert_eq(SaveService.as_int(profile["endings_seen"][0]["day"]), 2, "jour de la fin (dernier jour joué)")
	# Reprise d'un jour passé d'une partie terminée : elle redevient active.
	assert_true(_state.call(&"load_day_snapshot", 1, 2, DIR))
	_evening(_state)
	meta = SaveService.load_meta(1, DIR)
	assert_eq(str(meta["status"]), SaveService.STATUS_ACTIVE)
	assert_eq(str(meta["ending_id"]), "")
	assert_eq(SaveService.latest_slot(DIR), 1)


func test_ending_never_archives_another_campaign() -> void:
	_evening(_game(5, 1))
	var other: Node = _game(6, 1)
	other.call(&"end_campaign", EndingService.F4_GLORY, SaveService.NO_SLOT, DIR)
	assert_eq(str(SaveService.load_meta(1, DIR)["status"]), SaveService.STATUS_ACTIVE, "graine différente : intacte")
	assert_true(ProfileService.has_seen_ending(ProfileService.load_profile(DIR), String(EndingService.F4_GLORY)))
	var demo: Node = _game(5, 1)
	demo.call(&"end_campaign", &"demo_complete", SaveService.NO_SLOT, DIR)
	assert_false(ProfileService.has_seen_ending(ProfileService.load_profile(DIR), "demo_complete"), "hors F1–F10")


func test_corrupt_meta_is_rebuilt_and_files_fall_back_to_tmp() -> void:
	_evening(_game(9, 1, 4))
	var meta_path: String = SaveService.meta_path(1, DIR)
	var file: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	file.store_string("{ cassé")
	file.close()
	var meta: Dictionary = SaveService.load_meta(1, DIR)
	assert_eq(SaveService.as_int(meta.get("current_day")), 5, "méta reconstruite depuis current.json")
	assert_eq(SaveService.latest_slot(DIR), 1)
	# Arrêt simulé entre l'écriture du .tmp et le renommage de l'instantané.
	var snap: String = SaveService.snapshot_path(1, 5, DIR)
	DirAccess.rename_absolute(snap, snap + SaveService.TMP_SUFFIX)
	assert_eq(SaveService.list_snapshots(1, DIR), PackedInt32Array([5]), ".tmp compté")
	assert_eq(SaveService.as_int(SaveService.load_snapshot(1, 5, DIR)["current_day"]), 5, "relu depuis le .tmp")


func test_difficulty_and_play_time_persist() -> void:
	var state: Node = _game(12, 1, 2, &"story")
	assert_true(state.call(&"is_story_mode"))
	assert_false(state.call(&"set_difficulty", &"easy"), "valeur inconnue refusée")
	_evening(state)
	assert_eq(str(SaveService.load_meta(1, DIR)["difficulty"]), SaveService.DIFFICULTY_STORY)
	assert_true(ProfileService.load_profile(DIR)["story_mode_used"], "profil : mode Récit utilisé")
	assert_true(_state.call(&"load_from_slot", 1, DIR))
	assert_eq(_state.get(&"difficulty"), &"story")
	assert_eq(_state.call(&"to_save_dict"), state.call(&"to_save_dict"), "aller-retour exact")
	# Récit → Dur, jamais l'inverse (D-102).
	assert_true(_state.call(&"set_difficulty", &"hard"))
	assert_false(_state.call(&"set_difficulty", &"story"), "Dur → Récit refusé")
	assert_eq(_state.get(&"difficulty"), &"hard")
	_evening(_state)
	# Un instantané plus ancien (en Récit) repris : la partie reste en Dur.
	assert_true(_state.call(&"load_day_snapshot", 1, 3, DIR))
	assert_eq(_state.get(&"difficulty"), &"hard")
	assert_true(_state.call(&"load_day_snapshot", 1, 2, DIR) == false, "pas d'instantané du J2 (partie commencée au J2)")
	# Absente d'un état : Dur.
	var raw: Dictionary = _state.call(&"to_save_dict")
	raw.erase("difficulty")
	raw["version"] = 5
	assert_eq(str(SaveService.parse(JSON.stringify(raw))["difficulty"]), "hard", "v5 → v6 : Dur")
	raw["version"] = 6
	_state.call(&"apply_save_dict", SaveService.parse(JSON.stringify(raw)))
	assert_eq(_state.get(&"difficulty"), &"hard")
	assert_true(SaveService.as_int(SaveService.load_meta(1, DIR)["play_time_sec"]) >= 0)


func test_profile_survives_slot_deletion_and_sanitizes_garbage() -> void:
	var state: Node = _game(31, 1)
	state.call(&"remember_case", &"sc_01", {"day": 1})
	state.call(&"remember_case", &"sc22_mira", {"day": 2})
	_evening(state)
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["characters_met"], ["sc_01", "sc22_mira"], "personnages croisés")
	assert_false(profile["story_mode_used"])
	assert_false(profile["epilogue_unlocked"], "réservé M12")
	assert_eq(profile["best_runs"], [], "réservé M12")
	state.call(&"end_campaign", EndingService.F5_AIR, SaveService.NO_SLOT, DIR)
	SaveService.delete_slot(1, DIR)
	profile = ProfileService.load_profile(DIR)
	assert_true(ProfileService.has_seen_ending(profile, String(EndingService.F5_AIR)), "survit à la suppression")
	assert_eq((profile["characters_met"] as Array).size(), 2)
	assert_false(ProfileService.record(DIR, String(EndingService.F5_AIR), 9, ["sc_01"]), "rien de neuf : pas d'écriture")
	var file: FileAccess = FileAccess.open(ProfileService.profile_path(DIR), FileAccess.WRITE)
	file.store_string(JSON.stringify({"endings_seen": "n'importe quoi", "characters_met": [1, "sc_01", "sc_01"],
			"story_mode_used": "oui", "inconnu": 3}))
	file.close()
	profile = ProfileService.load_profile(DIR)
	assert_eq(profile["endings_seen"], [])
	assert_eq(profile["characters_met"], ["sc_01"], "identifiants texte uniques seulement")
	assert_false(profile["story_mode_used"])
	assert_eq(SaveService.as_int(profile["inconnu"]), 3, "champ inconnu conservé (versions futures)")
