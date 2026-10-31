## M14 lot A — profil v3 (B92, B93, D-191 ; ARCHITECTURE §12 ter.5) : visière
## mémorisée (`CaseMemory.visor`), portraits de la dernière rencontre tels que
## vus, liste blanche `portrait_cases`, migration v2 → v3 (et v1 → v3) depuis
## la `case_memory` **réelle** des emplacements (`profile.v2.bak`),
## `cinematics_seen`, taille, réglages M14.
extends GutTest

const GF = preload("res://tests/helpers/generation_fixtures.gd")
const SettingsScript: GDScript = preload("res://scripts/autoload/settings.gd")
const DIR: String = "user://test_m14_profile"


func before_each() -> void:
	_clear()


func after_all() -> void:
	_clear()
	DirAccess.remove_absolute(DIR)


func _clear() -> void:
	for slot: int in range(0, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot, DIR)
	for name: String in [ProfileService.FILE_NAME, ProfileService.V1_BACKUP_FILE, ProfileService.V2_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(DIR.path_join(name))


## Entrée réelle de `case_memory` : cas scénarisé `id` du jour `day_number`,
## construit par le vrai générateur (graine `campaign_seed`), visière relevée
## si `lift`.
func _snapshot(campaign_seed: int, day_number: int, id: StringName, lift: bool = false) -> Dictionary:
	var data: DataCatalog = GF.data()
	var day: DayDef = data.get_day(day_number)
	var scripted: ScriptedCaseDef = null
	for s: ScriptedCaseDef in day.scripted_cases:
		if s.id == id:
			scripted = s
	assert_not_null(scripted, "%s au J%d" % [id, day_number])
	var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign_seed, day_number), [],
			CaseMemory.resolve(data, day, campaign_seed, {}))
	var g: GeneratedCase = builder.build(scripted.at_index)
	if lift:
		g.case.remove_visor()
	return CaseMemory.snapshot(day_number, g.case, VerdictKind.Kind.APPROVE)


func _state(campaign_seed: int, day: int, memory: Dictionary) -> Dictionary:
	return {"campaign_seed": campaign_seed, "current_day": day, "credits": 40, "score_total": 0, "citations": 0,
			"narrative_flags": {}, "day_history": [], "household": Household.new().to_dict(),
			"case_memory": JSON.parse_string(JSON.stringify(memory)), "difficulty": "hard"}


func _write_profile(profile: Dictionary) -> void:
	SaveService.write_atomic(ProfileService.profile_path(DIR), JSON.stringify(profile))


func test_snapshot_records_the_visor_as_it_left() -> void:
	var down: Dictionary = _snapshot(4242, 3, &"sc_04")
	assert_eq(down["visor"], CaseMemory.VISOR_DOWN, "Mira jamais relevée")
	assert_false(CaseMemory.visor_lifted(down))
	assert_false(CaseMemory.appearance_of(down).is_face_covered(), "visage mémorisé inchangé : sans visière")
	assert_true(CaseMemory.seen_appearance(down).is_face_covered(), "vue telle qu'à la vitre : visière baissée")
	var up: Dictionary = _snapshot(4242, 3, &"sc_04", true)
	assert_eq(up["visor"], CaseMemory.VISOR_UP)
	assert_true(CaseMemory.visor_lifted(up))
	assert_false(CaseMemory.seen_appearance(up).is_face_covered())
	assert_eq(up["appearance"], down["appearance"], "même visage, seule la visière change")
	# Entrée 0.13 (sans `visor`) : une coiffe `visor_up` vaut « baissée » (D-131).
	var legacy: Dictionary = up.duplicate(true)
	legacy.erase("visor")
	assert_eq(CaseMemory.visor_of(legacy), CaseMemory.VISOR_DOWN)
	var amara: Dictionary = _snapshot(4242, 1, &"sc_02")
	var expected: String = CaseMemory.VISOR_DOWN if CaseMemory.appearance_of(amara).get_trait(PassengerAppearance.SLOT_HEADWEAR) \
			== PassengerAppearance.VISOR_UP else CaseMemory.VISOR_NONE
	assert_eq(amara["visor"], expected)
	assert_true(CaseMemory.VISOR_STATES.has(str(amara["visor"])))


func test_v2_profile_migrates_portraits_from_real_slot_memory() -> void:
	var older: Dictionary = {"sc_04": _snapshot(111, 3, &"sc_04", true), "sc_02": _snapshot(111, 1, &"sc_02")}
	var newer: Dictionary = {"sc_04": _snapshot(222, 3, &"sc_04")}
	assert_eq(SaveService.save_slot(_state(111, 5, older), 1, DIR, "2026-10-01T10:00:00"), OK)
	assert_eq(SaveService.save_slot(_state(222, 4, newer), 2, DIR, "2026-10-20T10:00:00"), OK)
	_write_profile({"version": 2, "endings_seen": [], "characters_met": ["sc_02", "sc_04"], "futur": 7,
			"cinematics_seen": ["cin_f1", "cin_f1", 3]})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["version"], 3)
	assert_true(FileAccess.file_exists(DIR.path_join(ProfileService.V2_BACKUP_FILE)), "profile.v2.bak")
	assert_eq(SaveService.as_int(SaveService.read_json(DIR.path_join(ProfileService.V2_BACKUP_FILE))["version"]), 2)
	assert_eq(SaveService.as_int(SaveService.read_json(ProfileService.profile_path(DIR))["version"]), 3, "réécrit en v3")
	assert_eq(SaveService.as_int(profile["futur"]), 7, "champ inconnu conservé")
	assert_eq(profile["cinematics_seen"], ["cin_f1"], "assaini")
	var portraits: Dictionary = profile["portraits"]
	assert_eq(portraits.keys().size(), 2, "Mira et Amara")
	var mira: Dictionary = ProfileService.portrait_of(profile, "chr_mira")
	assert_eq(mira["case_id"], "sc_04")
	assert_eq(mira["day"], 3)
	assert_eq(mira["act"], 1)
	assert_eq(mira["visor"], CaseMemory.VISOR_DOWN, "la partie la plus récente l'emporte (jamais relevée)")
	assert_eq(mira["appearance"], newer["sc_04"]["appearance"])
	assert_true(ProfileService.portrait_appearance(mira).is_face_covered())
	assert_eq(ProfileService.portrait_of(profile, "chr_amara")["case_id"], "sc_02")
	assert_true(ProfileService.portrait_of(profile, "chr_lev").is_empty(), "jamais vu : initiales")
	# Idempotent.
	assert_eq(ProfileService.load_profile(DIR), profile)


func test_v1_profile_goes_straight_to_v3() -> void:
	assert_eq(SaveService.save_slot(_state(333, 4, {"sc_04": _snapshot(333, 3, &"sc_04", true)}), 1, DIR), OK)
	_write_profile({"version": 1, "endings_seen": [], "characters_met": ["sc_04"]})
	var profile: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(profile["version"], ProfileService.VERSION)
	assert_true(FileAccess.file_exists(DIR.path_join(ProfileService.V1_BACKUP_FILE)))
	assert_eq(ProfileService.portrait_of(profile, "chr_mira")["visor"], CaseMemory.VISOR_UP)


func test_record_portraits_keeps_the_last_encounter_of_the_played_day() -> void:
	var memory: Dictionary = {"sc_04": _snapshot(444, 3, &"sc_04")}
	assert_false(ProfileService.record_portraits(DIR, memory, 2), "aucun cas du J2")
	assert_true(ProfileService.record_portraits(DIR, memory, 3))
	assert_false(ProfileService.record_portraits(DIR, memory, 3), "rien de neuf : pas d'écriture")
	var later: Dictionary = memory.duplicate(true)
	var sc22: Dictionary = (memory["sc_04"] as Dictionary).duplicate(true)
	sc22["day"] = 10
	sc22["index"] = 4
	sc22["visor"] = CaseMemory.VISOR_UP
	later["sc_22"] = sc22
	assert_true(ProfileService.record_portraits(DIR, later, 10))
	var mira: Dictionary = ProfileService.portrait_of(ProfileService.load_profile(DIR), "chr_mira")
	assert_eq(mira["case_id"], "sc_22", "dernière rencontre")
	assert_eq(mira["visor"], CaseMemory.VISOR_UP)
	assert_eq(mira["act"], 1)
	# Toute la mémoire : la rencontre la plus tardive l'emporte (jour, index).
	var all: Dictionary = ProfileService.portraits_from_memory(later)
	assert_eq(all["chr_mira"]["case_id"], "sc_22")
	# Liste blanche : un cas exclu ne prête pas son visage.
	var guarded: CharacterDef = CharacterTableDef.load_default().character_of(&"sc_04").duplicate() as CharacterDef
	guarded.portrait_cases = [&"sc_04"] # nouveau tableau : la table partagée n'est pas touchée
	var table: CharacterTableDef = CharacterTableDef.new()
	table.characters = [guarded]
	assert_eq(ProfileService.portraits_from_memory(later, 0, table)["chr_mira"]["case_id"], "sc_04")
	# Recalculée ou sans visage : jamais un portrait.
	var recalled: Dictionary = {"sc_04": CaseMemory.recall(GF.data(), 444, &"sc_04")}
	assert_true(ProfileService.portraits_from_memory(recalled).is_empty())
	assert_true(ProfileService.portraits_from_memory({"sc_04": {"day": 3, "verdict": "approve"}}).is_empty())
	assert_false(ProfileService.record_portrait(DIR, "chr_x", {}), "portrait vide refusé")


func test_portrait_size_budget() -> void:
	var memory: Dictionary = {"sc_04": _snapshot(555, 3, &"sc_04"), "sc_02": _snapshot(555, 1, &"sc_02")}
	var found: Dictionary = ProfileService.portraits_from_memory(memory)
	assert_eq(found.size(), 2)
	for chr_id: Variant in found:
		var size: int = JSON.stringify(found[chr_id]).to_utf8_buffer().size()
		assert_true(size <= ProfileService.PORTRAIT_MAX_BYTES, "%s : %d o ≤ 400" % [chr_id, size])
		assert_true(size * 44 <= 20 * 1024, "44 personnages ≤ 20 Ko")


func test_cinematics_seen_and_sanitize() -> void:
	assert_false(ProfileService.has_seen_cinematic(ProfileService.load_profile(DIR), "cin_f9"))
	assert_true(ProfileService.record_cinematic_seen(DIR, "cin_f9"))
	assert_false(ProfileService.record_cinematic_seen(DIR, "cin_f9"), "une fois")
	assert_false(ProfileService.record_cinematic_seen(DIR, ""))
	assert_true(ProfileService.has_seen_cinematic(ProfileService.load_profile(DIR), "cin_f9"))
	var dirty: Dictionary = ProfileService.sanitize({"portraits": {"chr_a": {"appearance": {}}, "chr_b": "x",
			"chr_c": {"appearance": {"traits": {"headwear": "visor_up"}}, "visor": "??", "day": 25}}})
	assert_eq((dirty["portraits"] as Dictionary).keys(), ["chr_c"], "sans visage : retiré")
	assert_eq(dirty["portraits"]["chr_c"]["visor"], CaseMemory.VISOR_DOWN, "état inconnu : baissée")
	assert_eq(dirty["portraits"]["chr_c"]["act"], 3)
	assert_eq(ProfileService.empty_profile()["portraits"], {})


## QA-073 : contexte REVOIR (`cinematic_replays`) — ajout sans changement de
## version : un profil v3 qui ne l'a pas le reçoit vide, rien d'autre ne bouge ;
## valeurs assainies, bornées, le dernier contexte vu l'emporte.
func test_cinematic_replays_context() -> void:
	var older: Dictionary = ProfileService.empty_profile()
	older.erase("cinematic_replays")
	older["cinematics_seen"] = ["cin_f3"]
	ProfileService.save_profile(older, DIR)
	var w: FileAccess = FileAccess.open(SaveService.resolve_dir(DIR).path_join(ProfileService.FILE_NAME), FileAccess.WRITE)
	w.store_string(JSON.stringify(older))
	w.close()
	var loaded: Dictionary = ProfileService.load_profile(DIR)
	assert_eq(int(loaded["version"]), ProfileService.VERSION, "même version")
	assert_eq(loaded["cinematic_replays"], {}, "migration triviale : vide")
	assert_eq(loaded["cinematics_seen"], ["cin_f3"])
	assert_eq(ProfileService.cinematic_replay(loaded, "cin_f3"), {}, "sans contexte")
	var ctx: Dictionary = {"ending": "f3_family_lost", "variant": "", "act": 3, "day": 30,
			"plates": ["pl_f3_1", "pl_f3_2", "pl_f3_2", 7], "flags": {"lumika_learned": true, "pont": 2.0, "x": [1]}}
	assert_true(ProfileService.record_cinematic_seen(DIR, "cin_f3", ctx), "déjà vue, contexte nouveau : écrit")
	assert_false(ProfileService.record_cinematic_seen(DIR, "cin_f3", ctx), "même contexte : rien")
	var got: Dictionary = ProfileService.cinematic_replay(ProfileService.load_profile(DIR), "cin_f3")
	assert_eq(got["plates"], ["pl_f3_1", "pl_f3_2"], "ids uniques, textes seulement")
	assert_eq(got["flags"], {"lumika_learned": true, "pont": 2}, "booléens, entiers, textes")
	assert_eq(int(got["act"]), 3)
	assert_eq(int(got["day"]), 30)
	ctx["flags"] = {}
	assert_true(ProfileService.record_cinematic_seen(DIR, "cin_f3", ctx), "dernière séquence vue")
	assert_eq(ProfileService.cinematic_replay(ProfileService.load_profile(DIR), "cin_f3")["flags"], {})
	var many: Dictionary = {}
	for i: int in 60:
		many["flag_%02d" % i] = true
	var big: Dictionary = ProfileService.sanitize({"cinematic_replays": {"cin_x": {"flags": many, "plates": range(20).map(func(i: int) -> String: return "p%d" % i)},
			"": {}, "cin_y": "?"}})
	assert_eq((big["cinematic_replays"] as Dictionary).keys(), ["cin_x"], "entrées invalides retirées")
	assert_eq((big["cinematic_replays"]["cin_x"]["flags"] as Dictionary).size(), ProfileService.REPLAY_MAX_FLAGS)
	assert_eq((big["cinematic_replays"]["cin_x"]["plates"] as Array).size(), ProfileService.REPLAY_MAX_PLATES)


func test_m14_settings_defaults_and_domains() -> void:
	var settings: Node = autofree(SettingsScript.new())
	assert_eq(settings.call(&"get_value", &"music_inspection_reduce"), true, "discrète par défaut (§8 n° 3)")
	assert_eq(settings.call(&"get_value", &"music_dynamics"), 0.0, "Dynamique par défaut")
	assert_eq(settings.call(&"get_value", &"cinematic_advance"), 0.0, "Automatique par défaut")
	assert_false(settings.call(&"is_music_stable"))
	assert_false(settings.call(&"is_cinematic_manual"))
	settings.call(&"set_value", &"music_dynamics", 0.8, false)
	assert_eq(settings.call(&"get_value", &"music_dynamics"), 1.0)
	assert_true(settings.call(&"is_music_stable"))
	settings.call(&"set_value", &"cinematic_advance", 7, false)
	assert_eq(settings.call(&"get_value", &"cinematic_advance"), 1.0)
	assert_true(settings.call(&"is_cinematic_manual"))
	settings.call(&"set_value", &"music_inspection_reduce", 0, false)
	assert_eq(settings.call(&"get_value", &"music_inspection_reduce"), false)
