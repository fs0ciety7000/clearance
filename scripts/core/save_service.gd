## Sauvegarde de campagne (ARCHITECTURE §10, D-008) — JSON texte versionné.
##
## - Fichier `user://saves/slot_<n>.json`, jamais de `.tres` (un `.tres` peut
##   exécuter du code) ; écriture atomique (`.tmp` puis renommage).
## - Contenu : le dictionnaire produit par `GameState.to_save_dict()` (graine,
##   jour, crédits, score, citations, drapeaux narratifs, historique, foyer),
##   plus `version`, `game_version` et `saved_at` posés ici.
## - Lecture : JSON → migrations successives (`migrate`) → validation de schéma
##   (`validate`) ; tout fichier illisible, corrompu ou d'une version future est
##   refusé (`push_warning`, renvoie un dictionnaire vide).
## Pure (aucun autoload) : le dossier est paramétrable pour les tests.
class_name SaveService
extends RefCounted

## Version du format. Historique :
## 1 — contrat ARCHITECTURE §10 (sans foyer) ;
## 2 — M5 : `household` (Ilan, Noa, Dora), `day_history` détaillé ;
## 3 — M7 : `case_memory` (passagers scénarisés), membre `detained` du foyer,
##     jauge `suspicion` (SC-02 approuvé : +1 rétroactif, D-052).
const VERSION: int = 3
const GAME_VERSION: String = "0.7.0-m7"
const DEFAULT_DIR: String = "user://saves"
const DEFAULT_SLOT: int = 0
## Clés obligatoires après migration, avec leur type JSON attendu.
const SCHEMA: Dictionary[String, int] = {
	"version": TYPE_FLOAT,
	"campaign_seed": TYPE_FLOAT,
	"current_day": TYPE_FLOAT,
	"credits": TYPE_FLOAT,
	"score_total": TYPE_FLOAT,
	"citations": TYPE_FLOAT,
	"narrative_flags": TYPE_DICTIONARY,
	"day_history": TYPE_ARRAY,
	"household": TYPE_DICTIONARY,
	"case_memory": TYPE_DICTIONARY,
}


## Entier d'une valeur JSON (nombre, sinon `fallback`) — sans conversion non sûre.
static func as_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		var i: int = value
		return i
	if value is float:
		var f: float = value
		return roundi(f)
	return fallback


static func slot_path(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> String:
	return dir.path_join("slot_%d.json" % slot)


static func has_save(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> bool:
	return FileAccess.file_exists(slot_path(slot, dir))


## Écrit `data` (copié, complété de `version`/`game_version`/`saved_at`).
static func save(data: Dictionary, slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> Error:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	payload["game_version"] = GAME_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system(true)
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SaveService: dossier %s inaccessible (%s)" % [dir, error_string(err)])
		return err
	var path: String = slot_path(slot, dir)
	var tmp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveService: écriture de %s impossible (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t", true))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_warning("SaveService: renommage de %s impossible (%s)" % [tmp_path, error_string(err)])
	return err


## Lit, migre et valide une sauvegarde. Vide si absente ou invalide.
static func load_slot(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> Dictionary:
	var path: String = slot_path(slot, dir)
	if not FileAccess.file_exists(path):
		return {}
	var text: String = FileAccess.get_file_as_string(path)
	return parse(text, path)


## Analyse un texte JSON de sauvegarde (migrations + validation).
static func parse(text: String, origin: String = "<texte>") -> Dictionary:
	var json: JSON = JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		push_warning("SaveService: %s n'est pas un JSON valide (ligne %d : %s)" % [origin, json.get_error_line(), json.get_error_message()])
		return {}
	var parsed: Dictionary = json.data
	var data: Dictionary = migrate(parsed)
	if data.is_empty():
		return {}
	var problem: String = validate(data)
	if not problem.is_empty():
		push_warning("SaveService: %s refusé — %s" % [origin, problem])
		return {}
	return data


static func delete(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> void:
	var path: String = slot_path(slot, dir)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Fait monter un dictionnaire de sauvegarde jusqu'à `VERSION`. Vide si la
## version est inconnue ou postérieure à celle du jeu.
static func migrate(source: Dictionary) -> Dictionary:
	var data: Dictionary = source.duplicate(true)
	var version_value: Variant = data.get("version", 0)
	if not (version_value is int or version_value is float):
		push_warning("SaveService: version absente")
		return {}
	var version: int = as_int(version_value)
	if version < 1 or version > VERSION:
		push_warning("SaveService: version %d non prise en charge (jeu : %d)" % [version, VERSION])
		return {}
	if version == 1:
		data = _migrate_1_to_2(data)
		version = 2
	if version == 2:
		data = _migrate_2_to_3(data)
	data["version"] = float(VERSION)
	return data


## v1 → v2 : foyer en bonne santé, historique sans détail économique.
static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	if not data.has("household"):
		data["household"] = Household.new().to_dict()
	var history: Variant = data.get("day_history", [])
	if history is Array:
		for entry: Variant in history:
			if entry is Dictionary:
				var day: Dictionary = entry
				if not day.has("wage"):
					day["wage"] = day.get("credits", 0)
				if not day.has("spent"):
					day["spent"] = 0
	data["version"] = 2
	return data


## v2 → v3 : mémoire des passagers vide (recalculée à la demande,
## `CaseMemory.resolve`) ; `suspicion +1` si SC-02 a été approuvée (D-052).
static func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	if not data.has("case_memory"):
		data["case_memory"] = {}
	var flags: Variant = data.get("narrative_flags", {})
	if flags is Dictionary:
		var dict: Dictionary = flags
		var mercy: Variant = dict.get("sc02_mercy", false)
		if (mercy is bool and mercy) and not dict.has("suspicion"):
			dict["suspicion"] = 1
	data["version"] = 3
	return data


## Contrôle de schéma : message d'erreur, vide si conforme.
static func validate(data: Dictionary) -> String:
	for key: String in SCHEMA:
		if not data.has(key):
			return "clé « %s » manquante" % key
		var wanted: int = SCHEMA[key]
		var actual: int = typeof(data[key])
		var numeric: bool = wanted == TYPE_FLOAT and (actual == TYPE_INT or actual == TYPE_FLOAT)
		if actual != wanted and not numeric:
			return "clé « %s » de type %s" % [key, type_string(actual)]
	var day: int = as_int(data["current_day"])
	if day < 1:
		return "jour %d invalide" % day
	return ""
