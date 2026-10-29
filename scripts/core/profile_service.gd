## Profil global du joueur (ARCHITECTURE §10, D-101, docs/M11.md §3) — JSON
## texte `<dossier des sauvegardes>/profile.json` (`user://saves/profile.json`).
##
## Progression qui survit aux parties : fins vues (`endings_seen`, avec jour et
## date de la première fois), personnages scénarisés croisés
## (`characters_met` : identifiants `ScriptedCaseDef.id` des cas traités),
## `story_mode_used` ; champs réservés M12 (`best_runs`, `epilogue_unlocked`).
## Jamais effacé par une fin ni par `SaveService.delete_slot`. Écriture
## atomique et lecture de secours de `SaveService` (`.tmp` / `.bak`).
## Service statique pur (pas d'autoload) : `GameState` l'alimente aux
## sauvegardes du soir et aux fins, puis émet `EventBus.profile_changed`.
class_name ProfileService
extends RefCounted

const VERSION: int = 1
const FILE_NAME: String = "profile.json"


static func profile_path(dir: String = SaveService.DEFAULT_DIR) -> String:
	return SaveService.resolve_dir(dir).path_join(FILE_NAME)


## Profil vierge.
static func empty_profile() -> Dictionary:
	return {
		"version": VERSION,
		"endings_seen": [],
		"characters_met": [],
		"story_mode_used": false,
		# Réservés M12 (Garde de nuit, épilogue).
		"best_runs": [],
		"epilogue_unlocked": false,
	}


## Profil lu (complété des champs manquants) ; vierge si absent ou illisible.
static func load_profile(dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	return sanitize(SaveService.read_json(profile_path(dir)))


## Copie du profil `raw` aux types attendus (champs inconnus conservés).
static func sanitize(raw: Dictionary) -> Dictionary:
	var profile: Dictionary = empty_profile()
	for key: Variant in raw:
		profile[str(key)] = raw[key]
	var endings: Array = []
	var seen: Variant = profile.get("endings_seen", [])
	if seen is Array:
		for entry: Variant in seen:
			if entry is Dictionary and str((entry as Dictionary).get("id", "")) != "":
				var row: Dictionary = entry
				endings.append({"id": str(row["id"]), "day": SaveService.as_int(row.get("day", 0)),
						"date": str(row.get("date", ""))})
	profile["endings_seen"] = endings
	var characters: Array = []
	var met: Variant = profile.get("characters_met", [])
	if met is Array:
		for id: Variant in met:
			if id is String and not characters.has(id) and str(id) != "":
				characters.append(id)
	profile["characters_met"] = characters
	profile["story_mode_used"] = _is_true(profile.get("story_mode_used", false))
	profile["epilogue_unlocked"] = _is_true(profile.get("epilogue_unlocked", false))
	if not profile.get("best_runs") is Array:
		profile["best_runs"] = []
	profile["version"] = VERSION
	return profile


static func save_profile(profile: Dictionary, dir: String = SaveService.DEFAULT_DIR) -> Error:
	return SaveService.write_atomic(profile_path(dir), JSON.stringify(sanitize(profile), "\t", true))


## Identifiants des fins vues.
static func ending_ids(profile: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry: Dictionary in sanitize(profile)["endings_seen"]:
		ids.append(str(entry["id"]))
	return ids


static func has_seen_ending(profile: Dictionary, ending_id: String) -> bool:
	return ending_ids(profile).has(ending_id)


## Fusionne une partie dans le profil de `dir` : fin vue (`ending_id` non vide,
## première fois seulement : jour et date gardés), personnages croisés, mode
## Récit utilisé. N'écrit que si quelque chose change. Renvoie vrai si écrit.
static func record(dir: String, ending_id: String = "", day: int = 0, characters: Array = [],
		story_mode: bool = false) -> bool:
	var profile: Dictionary = load_profile(dir)
	var changed: bool = false
	if not ending_id.is_empty() and not has_seen_ending(profile, ending_id):
		var endings: Array = profile["endings_seen"]
		endings.append({"id": ending_id, "day": day, "date": Time.get_datetime_string_from_system(true)})
		changed = true
	var met: Array = profile["characters_met"]
	for id: Variant in characters:
		var text: String = str(id)
		if not text.is_empty() and not met.has(text):
			met.append(text)
			changed = true
	if story_mode and not profile["story_mode_used"]:
		profile["story_mode_used"] = true
		changed = true
	if not changed:
		return false
	return save_profile(profile, dir) == OK


static func _is_true(value: Variant) -> bool:
	return value is bool and value
