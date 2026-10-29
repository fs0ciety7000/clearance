## M12 lot A — profil v2 (B51, D-132, ARCHITECTURE §11.7) : migration v1 → v2
## avec reconstruction depuis les emplacements terminés (variante, graine
## d'épilogue, `day_31.json`, jour atteint, dernière partie), sauvegarde
## `profile.v1.bak`, comptage des fins, noms appris, épilogues joués.
extends GutTest

const DIR: String = "user://test_m12_profile"


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	for slot: int in range(0, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot, DIR)
	for name: String in [ProfileService.FILE_NAME, ProfileService.V1_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


## État de partie minimal (format v6) au matin du jour `day`.
func _state(campaign_seed: int, day: int, flags: Dictionary) -> Dictionary:
	return {"campaign_seed": campaign_seed, "current_day": day, "credits": 40, "score_total": 0, "citations": 1,
			"narrative_flags": flags, "day_history": [], "household": Household.new().to_dict(),
			"case_memory": {"sc_04": {"day": 3, "verdict": "approve"}, "sc_10": {"day": 5, "verdict": "deny"}},
			"difficulty": "hard"}


func _write_v1(profile: Dictionary) -> void:
	SaveService.write_atomic(ProfileService.profile_path(DIR), JSON.stringify(profile))


func test_v1_profile_migrates_and_rebuilds_from_finished_slots() -> void:
	# Emplacement 1 : partie terminée à l'Acte III (F5 Charte, J30).
	assert_eq(SaveService.save_slot(_state(901, 30, {"act2_started": true, "act3_started": true, "climate_vanne": true}), 1,
			DIR, "2026-10-20T10:00:00"), OK)
	SaveService.mark_ended(1, "f5_air", DIR)
	# Emplacement 2 : partie terminée à l'Acte II (F7, J20), plus récente.
	assert_eq(SaveService.save_slot(_state(902, 20, {"act2_started": true}), 2, DIR, "2026-10-25T10:00:00"), OK)
	SaveService.mark_ended(2, "f7_reopens", DIR)
	# Emplacement 3 : partie en cours au J12.
	assert_eq(SaveService.save_slot(_state(903, 12, {"act2_started": true}), 3, DIR), OK)
	_write_v1({"version": 1, "endings_seen": [{"id": "f5_air", "day": 30, "date": "2026-10-20T09:00:00"},
			{"id": "f7_reopens", "day": 20, "date": "2026-10-25T09:00:00"}, {"id": "f2_reassigned", "day": 4, "date": "x"}],
			"characters_met": ["sc_01", "sc_04"], "story_mode_used": true, "best_runs": [], "epilogue_unlocked": false,
			"futur": "gardé"})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["version"], ProfileService.VERSION)
	assert_true(FileAccess.file_exists(DIR.path_join(ProfileService.V1_BACKUP_FILE)), "profile.v1.bak")
	var raw: Dictionary = SaveService.read_json(ProfileService.profile_path(DIR))
	assert_eq(SaveService.as_int(raw["version"]), 2, "profil réécrit en v2")
	var endings: Array = profile["endings_seen"]
	assert_eq(endings.size(), 3, "aucune fin perdue")
	for entry: Dictionary in endings:
		assert_eq(entry["count"], 1)
		match str(entry["id"]):
			"f5_air":
				assert_eq(entry["variant"], "c", "variante recalculée depuis current.json (Charte)")
				assert_eq(entry["act"], 3)
			"f7_reopens":
				assert_eq(entry["act"], 2)
				assert_eq(entry["variant"], "")
			"f2_reassigned":
				assert_eq(entry["act"], 1, "acte déduit du jour")
	assert_eq(profile["max_day_reached"], 30)
	assert_true(profile["epilogue_unlocked"])
	assert_true((profile["epilogues"] as Dictionary).has("f5_air:c"))
	var epi: Dictionary = ProfileService.epilogue_seed(profile, "f5_air:c")
	assert_eq(epi["world"], "b")
	assert_eq(epi["campaign_seed"], 901)
	assert_true(SaveService.has_epilogue(1, DIR), "day_31.json reconstruit")
	assert_true(SaveService.load_meta(1, DIR).get(SaveService.KEY_EPILOGUE_AVAILABLE, false))
	assert_false(SaveService.has_epilogue(2, DIR), "Acte II : pas d'épilogue")
	assert_eq(profile["last_campaign"]["ending"], "f7_reopens", "la plus récente")
	assert_eq(profile["characters_met"], ["sc_01", "sc_04"])
	assert_true(profile["story_mode_used"])
	assert_eq(profile["futur"], "gardé", "champ inconnu conservé")
	# Idempotent : relu en v2, rien ne bouge.
	var again: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(ProfileService.load_profile(DIR), again)
	assert_eq((again["endings_seen"] as Array).size(), 3)
	assert_eq(again["max_day_reached"], 30)


func test_empty_or_unversioned_profile() -> void:
	assert_eq(ProfileService.load_profile(DIR), ProfileService.empty_profile(), "absent : vierge")
	_write_v1({"characters_met": ["sc_02"]})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["version"], 2)
	assert_eq(profile["characters_met"], ["sc_02"])
	assert_eq(profile["max_day_reached"], 0)


func test_record_ending_counts_by_variant_and_tracks_last_campaign() -> void:
	assert_true(ProfileService.record_ending(DIR, {"id": "f6_drift", "variant": "t", "act": 3, "day": 30, "world": "d",
			"climate": "climate_vitres", "traces": ["end_trace_a", "end_trace_a", "end_trace_b"], "campaign_seed": 4}))
	ProfileService.record_ending(DIR, {"id": "f6_drift", "variant": "t", "act": 3, "day": 30})
	ProfileService.record_ending(DIR, {"id": "f6_drift", "variant": "j10", "act": 1, "day": 10})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(ProfileService.ending_count(profile, "f6_drift", "t"), 2)
	assert_eq(ProfileService.ending_count(profile, "f6_drift"), 3)
	assert_eq(ProfileService.ending_ids(profile), PackedStringArray(["f6_drift"]))
	assert_eq(profile["last_campaign"]["variant"], "j10")
	assert_eq(profile["max_day_reached"], 30)
	assert_false(ProfileService.record_ending(DIR, {}), "fin vide ignorée")
	# Ancienne API : première fois seulement, sans compter.
	assert_false(ProfileService.record(DIR, "f6_drift", 30))
	assert_eq(ProfileService.ending_count(ProfileService.load_profile(DIR), "f6_drift"), 3)
	assert_true(ProfileService.record(DIR, "", 0, [], false, 31))
	assert_false(ProfileService.record(DIR, "", 0, [], false, 12), "jour atteint : jamais en baisse")
	assert_true(ProfileService.record_known_names(DIR, PackedStringArray(["chr_arkady", "chr_arkady"])))
	assert_false(ProfileService.record_known_names(DIR, PackedStringArray(["chr_arkady"])))
	assert_eq(ProfileService.load_profile(DIR)["known_names"], ["chr_arkady"])


func test_epilogue_entries_and_garbage() -> void:
	var epi: Dictionary = {"ending": "f9_strike", "variant": "", "ending_key": "f9", "world": "b", "campaign_seed": 3,
			"flags": {}, "household": {}, "memory": {}}
	assert_true(ProfileService.unlock_epilogue(DIR, epi))
	assert_true(ProfileService.record_epilogue_played(DIR, "f9_strike:", PackedStringArray(["epi_f9_open", "epi_f9_close"])))
	ProfileService.record_epilogue_played(DIR, "f9_strike:", PackedStringArray(["epi_f9_open"]))
	var entry: Dictionary = ProfileService.load_profile(DIR)["epilogues"]["f9_strike:"]
	assert_eq(entry["count"], 2)
	assert_eq(entry["last_lines"], ["epi_f9_open"])
	assert_false(entry["first_date"].is_empty())
	ProfileService.unlock_epilogue(DIR, epi)
	assert_eq(ProfileService.load_profile(DIR)["epilogues"]["f9_strike:"]["count"], 2, "nouvelle graine : compte gardé")
	assert_false(ProfileService.record_epilogue_played(DIR, "inconnu:", PackedStringArray()))
	_write_v1({"version": 2, "epilogues": "x", "best_runs": [3, {"score": 7.0}], "garde_daily": [], "garde_seeds": {},
			"garde_stats": 5, "last_campaign": [], "known_names": [1, "chr_a"], "max_day_reached": -4})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["epilogues"], {})
	assert_eq(profile["best_runs"].size(), 1)
	assert_eq(profile["best_runs"][0]["score"], 7)
	assert_eq(profile["garde_daily"], {})
	assert_eq(profile["garde_seeds"], [])
	assert_eq(profile["garde_stats"]["runs"], 0)
	assert_eq(profile["last_campaign"], {})
	assert_eq(profile["known_names"], ["chr_a"])
	assert_eq(profile["max_day_reached"], 0)


func test_character_table_known_names() -> void:
	var arkady: CharacterDef = CharacterDef.new()
	arkady.id = &"chr_arkady"
	arkady.case_ids = [&"sc_20"]
	arkady.display_name = "« Bastien Duval »"
	arkady.true_name = "Arkady Novak"
	arkady.known_name_if = FlagCondition.make([&"sc20_detained"] as Array[StringName])
	arkady.known_on_ending = true
	var mira: CharacterDef = CharacterDef.new()
	mira.id = &"chr_mira"
	mira.case_ids = [&"sc_04", &"sc_103"]
	var table: CharacterTableDef = CharacterTableDef.new()
	table.characters = [arkady, mira]
	var none: Dictionary[StringName, Variant] = {}
	assert_eq(table.known_names(none), PackedStringArray(), "nom vrai jamais montré")
	assert_eq(table.known_names(none, true), PackedStringArray(["chr_arkady"]), "une fin vue")
	var detained: Dictionary[StringName, Variant] = {&"sc20_detained": true}
	assert_eq(table.known_names(detained), PackedStringArray(["chr_arkady"]))
	assert_eq(table.character_of(&"sc_103"), mira)
	assert_null(table.character_of(&"sc_999"))
