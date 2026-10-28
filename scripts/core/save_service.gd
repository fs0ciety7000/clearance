## Sauvegarde de campagne (ARCHITECTURE §10, D-008) — JSON texte versionné.
##
## - Fichier `user://saves/slot_<n>.json`, jamais de `.tres` (un `.tres` peut
##   exécuter du code) ; écriture atomique : `.tmp` écrit puis renommé
##   **par-dessus** la sauvegarde (jamais de suppression préalable, QA-018) ;
##   si la plateforme refuse d'écraser, l'ancienne est d'abord mise de côté en
##   `.bak`. À la lecture, une sauvegarde principale absente ou illisible est
##   remplacée par le `.tmp` complet, puis par le `.bak`.
## - Contenu : le dictionnaire produit par `GameState.to_save_dict()` (graine,
##   jour, crédits, score, citations, drapeaux narratifs, historique, foyer),
##   plus `version`, `game_version` et `saved_at` posés ici.
## - Lecture : JSON → migrations successives (`migrate`) → validation de schéma
##   (`validate`) ; tout fichier illisible, corrompu ou d'une version future est
##   refusé (`push_warning`, renvoie un dictionnaire vide), de même qu'un jour
##   hors de `1..dernier jour des données` (QA-003).
## - Version du jeu : `application/config/version` de `project.godot`
##   (`game_version()`), écrite dans `game_version` (informative).
## Pure (aucun autoload) : le dossier est paramétrable pour les tests.
class_name SaveService
extends RefCounted

## Version du format. Historique :
## 1 — contrat ARCHITECTURE §10 (sans foyer) ;
## 2 — M5 : `household` (Ilan, Noa, Dora), `day_history` détaillé ;
## 3 — M7 : `case_memory` (passagers scénarisés), membre `detained` du foyer,
##     jauge `suspicion` (SC-02 approuvé : +1 rétroactif, D-052) ;
## 4 — Acte II (docs/ACT2.md §8.6) : membres `breathless` / `breathless_streak`
##     / `away` ; « mis·e en attente » séparé de `PERDU` (vivant·e) ; jauges
##     `solidarite`, `registre`, `quota_overrun` dans les drapeaux (sans schéma) ;
## 5 — Acte III (docs/ACT3.md §8.6) : aucun champ nouveau — climat, jauges
##     `verite` / `aveux` / `pont`, logement, avance : drapeaux ; Ilan « À
##     TYCHO » : motif d'absence existant. La version monte pour qu'un build
##     0.9 (v4, J1–J20) refuse proprement une sauvegarde de l'Acte III.
const VERSION: int = 5
## Réglage de projet portant la version du jeu (R23, §16.1).
const VERSION_SETTING: String = "application/config/version"
## Dossier des `DayDef` (`day_NN.tres`) : borne haute du jour (`last_day()`).
const DAYS_DIR: String = "res://data/days"
const TMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"
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

static var _last_day_cache: int = 0


## Entier d'une valeur JSON (nombre, sinon `fallback`) — sans conversion non sûre.
static func as_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		var i: int = value
		return i
	if value is float:
		var f: float = value
		return roundi(f)
	return fallback


## Version du jeu (`project.godot`), « 0.0.0 » si absente.
static func game_version() -> String:
	var value: Variant = ProjectSettings.get_setting(VERSION_SETTING, "")
	var text: String = str(value) if value != null else ""
	return text if not text.is_empty() else "0.0.0"


## Dernier jour jouable : plus grand `NN` des `day_NN.tres` de `DAYS_DIR`
## (gère les `.remap` d'un export). Lu une fois puis mis en cache.
static func last_day() -> int:
	if _last_day_cache > 0:
		return _last_day_cache
	var dir: DirAccess = DirAccess.open(DAYS_DIR)
	if dir == null:
		return 0
	var last: int = 0
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(".remap")
		if name.begins_with("day_") and name.ends_with(".tres"):
			var number: String = name.trim_prefix("day_").trim_suffix(".tres")
			if number.is_valid_int():
				last = maxi(last, number.to_int())
	_last_day_cache = last
	return last


static func slot_path(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> String:
	return dir.path_join("slot_%d.json" % slot)


## Vrai si une sauvegarde (principale, ou `.tmp` / `.bak` de secours) existe.
static func has_save(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> bool:
	var path: String = slot_path(slot, dir)
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + TMP_SUFFIX) \
			or FileAccess.file_exists(path + BACKUP_SUFFIX)


## Écrit `data` (copié, complété de `version`/`game_version`/`saved_at`).
## Atomique : la sauvegarde précédente reste lisible jusqu'au renommage.
static func save(data: Dictionary, slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> Error:
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = VERSION
	payload["game_version"] = game_version()
	payload["saved_at"] = Time.get_datetime_string_from_system(true)
	var err: Error = DirAccess.make_dir_recursive_absolute(dir)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SaveService: dossier %s inaccessible (%s)" % [dir, error_string(err)])
		return err
	var path: String = slot_path(slot, dir)
	var tmp_path: String = path + TMP_SUFFIX
	var backup_path: String = path + BACKUP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		err = FileAccess.get_open_error()
		push_warning("SaveService: écriture de %s impossible (%s)" % [tmp_path, error_string(err)])
		return err
	file.store_string(JSON.stringify(payload, "\t", true))
	file.flush()
	err = file.get_error()
	file.close()
	if err != OK:
		push_warning("SaveService: écriture de %s incomplète (%s)" % [tmp_path, error_string(err)])
		DirAccess.remove_absolute(tmp_path)
		return err
	# Renommage par-dessus : atomique sous Linux / macOS (rename) et Windows.
	err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK and FileAccess.file_exists(path):
		# Plateforme qui refuse d'écraser : l'ancienne passe en `.bak` (relue
		# en secours) avant le renommage, jamais supprimée avant.
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		err = DirAccess.rename_absolute(path, backup_path)
		if err == OK:
			err = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_warning("SaveService: renommage de %s impossible (%s)" % [tmp_path, error_string(err)])
		return err
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return OK


## Lit, migre et valide une sauvegarde. Vide si absente ou invalide.
## Secours (QA-018) : si la sauvegarde principale manque ou est refusée, le
## `.tmp` (écriture terminée mais pas encore renommée) puis le `.bak`.
static func load_slot(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> Dictionary:
	var path: String = slot_path(slot, dir)
	for candidate: String in [path, path + TMP_SUFFIX, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var data: Dictionary = parse(FileAccess.get_file_as_string(candidate), candidate)
		if not data.is_empty():
			return data
	return {}


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
	for candidate: String in [path, path + TMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


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
		version = 3
	if version == 3:
		data = _migrate_3_to_4(data)
		version = 4
	if version == 4:
		data = _migrate_4_to_5(data)
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


## v3 → v4 : une sauvegarde v3 date au plus du soir du J9. Champs du foyer par
## défaut (rations « payées » : pas d'essoufflement, aucun absent) ; un proche
## `lost` **et** `detained` (Ilan dénoncé·e à l'Acte I) redevient vivant·e,
## mis·e en attente (`well`, `detained`).
static func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	var home: Variant = data.get("household", {})
	if home is Dictionary:
		var dict: Dictionary = home
		var members: Variant = dict.get("members", [])
		if members is Array:
			for entry: Variant in members:
				if not entry is Dictionary:
					continue
				var member: Dictionary = entry
				if str(member.get("health", "")) == "lost" and member.get("detained", false) == true:
					member["health"] = "well"
				if not member.has("breathless"):
					member["breathless"] = false
				if not member.has("breathless_streak"):
					member["breathless_streak"] = 0
				if not member.has("away"):
					member["away"] = ""
	data["version"] = 4
	return data


## v4 → v5 : une sauvegarde v4 date au plus du soir du J19 (le J20 de la
## 0.9 n'a pas de soirée) : aucune conversion d'état ; la partie rejoue le J20
## et découvre la soirée pivot de l'Acte III.
static func _migrate_4_to_5(data: Dictionary) -> Dictionary:
	data["version"] = 5
	return data


## Contrôle de schéma : message d'erreur, vide si conforme. `max_day` : borne
## haute du jour (défaut : `last_day()`, dernier jour des données ; ≤ 0 si les
## données sont introuvables = pas de borne).
static func validate(data: Dictionary, max_day: int = -1) -> String:
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
	var last: int = max_day if max_day >= 0 else last_day()
	if last > 0 and day > last:
		return "jour %d au-delà du dernier jour (%d)" % [day, last]
	return ""
