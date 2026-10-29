## Sauvegarde de campagne (ARCHITECTURE §10, D-008, D-101) — JSON texte versionné.
##
## v6 (M11) : trois emplacements `user://saves/slot_N/` (N = 1..`SLOT_COUNT`) :
## - `current.json` : état courant (écrit à chaque fin de soirée, D-041) ;
## - `day_NN.json` : instantané « matin du jour NN », écrit en même temps que
##   `current.json` ; toute écriture supprime les instantanés **postérieurs**
##   au jour écrit (une seule ligne de temps par emplacement) ;
## - `meta.json` : résumé pour l'écran Charger (`build_meta`) ; `status`
##   `active` | `ended` (fin F1–F10 archivée, `mark_ended`) ;
## à côté : `profile.json` (`ProfileService`, progression globale).
## « Continuer » = `latest_slot()` (emplacement actif au `saved_at` le plus récent).
## Robustesse (QA M11, QA-043 → QA-046) : `current.json` illisible → repli sur
## l'instantané lisible le plus récent (`load_current`) ; rien de lisible →
## méta marquée `damaged` (`META_DAMAGED`) ; le statut « terminée » est aussi
## écrit dans `current.json` (`mark_ended`, survit à la perte de `meta.json`) ;
## `list_snapshots` ne liste que les jours chargeables ; Récit → Dur écrit
## aussitôt (`persist_difficulty`).
## - Jamais de `.tres` (un `.tres` peut exécuter du code) ; écriture atomique
##   de **chaque** fichier (`write_atomic`) : `.tmp` écrit puis renommé
##   par-dessus (jamais de suppression préalable, QA-018) ; si la plateforme
##   refuse d'écraser, l'ancien passe d'abord en `.bak`. À la lecture
##   (`read_text`), un fichier absent ou refusé est remplacé par le `.tmp`
##   complet, puis par le `.bak`.
## - Contenu d'un état : le dictionnaire de `GameState.to_save_dict()`, plus
##   `version`, `game_version` et `saved_at` posés ici.
## - Lecture : JSON → migrations successives (`migrate`) → validation de schéma
##   (`validate`) ; tout fichier illisible, corrompu ou d'une version future est
##   refusé (`push_warning`, dictionnaire vide), de même qu'un jour hors de
##   `1..dernier jour des données` (QA-003).
## - Migration des fichiers v5 → v6 (`migrate_legacy`, appelée par
##   `list_slots` / `latest_slot`) : `slot_0.json` devient l'emplacement 1 (ou
##   le premier libre) ; l'ancien fichier est renommé `slot_0.v5.bak`, jamais
##   supprimé.
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
##     0.9 (v4, J1–J20) refuse proprement une sauvegarde de l'Acte III ;
## 6 — M11 (D-101, D-102) : emplacements en dossiers, instantanés, `meta.json` ;
##     clés de premier niveau optionnelles `difficulty` (`"hard"` | `"story"`,
##     absente ⇒ `"hard"`), `play_time_sec`, `portrait_seed` (absentes ⇒ 0).
const VERSION: int = 6
## Réglage de projet portant la version du jeu (R23, §16.1).
const VERSION_SETTING: String = "application/config/version"
## Dossier des `DayDef` (`day_NN.tres`) : borne haute du jour (`last_day()`).
const DAYS_DIR: String = "res://data/days"
const TMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"
const DEFAULT_DIR: String = "user://saves"
## Emplacements visibles : 1..`SLOT_COUNT` (D-101).
const SLOT_COUNT: int = 3
## Emplacement par défaut (nouvelle partie de l'écran titre actuel, migration).
const DEFAULT_SLOT: int = 1
## « Pas d'emplacement » / « emplacement actif » selon l'API.
const NO_SLOT: int = -1
const CURRENT_FILE: String = "current.json"
const META_FILE: String = "meta.json"
## Ancien fichier v5 (`slot_0.json`) et son nom après migration.
const LEGACY_FILE: String = "slot_0.json"
const LEGACY_BACKUP_FILE: String = "slot_0.v5.bak"
const STATUS_ACTIVE: String = "active"
const STATUS_ENDED: String = "ended"
## Clés de statut aussi écrites dans `current.json` par `mark_ended` (QA-044),
## effacées à la sauvegarde suivante (`save_slot` : partie rouverte).
const KEY_STATUS: String = "status"
const KEY_ENDING_ID: String = "ending_id"
## Méta : emplacement occupé dont aucun état n'est lisible (ni `current.json`
## ni instantané, QA-043) — ni « Continuer », ni reprise ; l'UI désactive ses
## actions (sauf supprimer / écraser). Absente sinon.
const META_DAMAGED: String = "damaged"
const DIFFICULTY_HARD: String = "hard"
const DIFFICULTY_STORY: String = "story"
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
## Compteur d'écritures du processus (départage deux sauvegardes de la même ms).
static var _save_serial: int = 0
## Dossier qui remplace `DEFAULT_DIR` (`use_root`), vide sinon.
static var _root: String = ""


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


# --- Chemins -------------------------------------------------------------------

## Dossier réel de `dir` : `DEFAULT_DIR` est redirigé par `use_root` (suite
## de tests : `tests/helpers/gut_pre_run.gd`, jamais les parties du joueur).
static func resolve_dir(dir: String) -> String:
	return _root if dir == DEFAULT_DIR and not _root.is_empty() else dir


## Redirige `DEFAULT_DIR` (vide : `user://saves`). Réservé aux tests.
static func use_root(dir: String) -> void:
	_root = dir


## Dossier d'un emplacement (`<dir>/slot_N`).
static func slot_dir(slot: int, dir: String = DEFAULT_DIR) -> String:
	return resolve_dir(dir).path_join("slot_%d" % slot)


## État courant d'un emplacement (`slot_N/current.json`).
static func slot_path(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> String:
	return slot_dir(slot, dir).path_join(CURRENT_FILE)


static func meta_path(slot: int, dir: String = DEFAULT_DIR) -> String:
	return slot_dir(slot, dir).path_join(META_FILE)


## Instantané « matin du jour `day` » (`slot_N/day_NN.json`).
static func snapshot_path(slot: int, day: int, dir: String = DEFAULT_DIR) -> String:
	return slot_dir(slot, dir).path_join("day_%02d.json" % day)


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


# --- Fichiers atomiques ------------------------------------------------------------

## Vrai si `path` (ou son `.tmp` / `.bak` de secours) existe.
static func file_exists_any(path: String) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + TMP_SUFFIX) \
			or FileAccess.file_exists(path + BACKUP_SUFFIX)


## Supprime `path` et ses `.tmp` / `.bak`.
static func remove_with_fallbacks(path: String) -> void:
	for candidate: String in [path, path + TMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


## Écrit `text` dans `path` de façon atomique (QA-018) : `.tmp` écrit et vidé,
## renommé par-dessus ; si la plateforme refuse d'écraser, l'ancien passe
## d'abord en `.bak` (relu en secours), jamais supprimé avant.
static func write_atomic(path: String, text: String) -> Error:
	var folder: String = path.get_base_dir()
	var err: Error = DirAccess.make_dir_recursive_absolute(folder)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_warning("SaveService: dossier %s inaccessible (%s)" % [folder, error_string(err)])
		return err
	var tmp_path: String = path + TMP_SUFFIX
	var backup_path: String = path + BACKUP_SUFFIX
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		err = FileAccess.get_open_error()
		push_warning("SaveService: écriture de %s impossible (%s)" % [tmp_path, error_string(err)])
		return err
	file.store_string(text)
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


## Dictionnaire JSON lu dans `path`, sinon son `.tmp`, sinon son `.bak` ;
## `accept(dict) -> Dictionary` (optionnel) transforme / refuse (vide) chaque
## candidat. Vide si rien n'est lisible.
static func read_json(path: String, accept: Callable = Callable()) -> Dictionary:
	for candidate: String in [path, path + TMP_SUFFIX, path + BACKUP_SUFFIX]:
		if not FileAccess.file_exists(candidate):
			continue
		var text: String = FileAccess.get_file_as_string(candidate)
		var data: Dictionary = {}
		if accept.is_valid():
			data = accept.call(text, candidate)
		else:
			var json: JSON = JSON.new()
			if json.parse(text) == OK and json.data is Dictionary:
				data = json.data
		if not data.is_empty():
			return data
	return {}


# --- Emplacements (D-101) --------------------------------------------------------------

## Vrai si l'emplacement a un état courant (principal, `.tmp` ou `.bak`) ou,
## à défaut, un instantané (secours de `load_current`).
static func has_save(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> bool:
	return file_exists_any(slot_path(slot, dir)) or not _snapshot_days(slot, dir).is_empty()


## Écrit l'état `data` dans l'emplacement : `current.json`, instantané du jour
## courant (`day_NN.json`), suppression des instantanés postérieurs (reprise
## d'un jour passé : une seule ligne de temps), puis `meta.json` (`active`).
## `saved_at` : horodatage imposé (migration), sinon maintenant.
static func save_slot(data: Dictionary, slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR,
		saved_at: String = "") -> Error:
	if slot < 0:
		push_warning("SaveService: emplacement %d invalide" % slot)
		return ERR_INVALID_PARAMETER
	var payload: Dictionary = data.duplicate(true)
	# Une sauvegarde rouvre la partie (statut d'archive de `mark_ended` retiré).
	for key: String in [KEY_STATUS, KEY_ENDING_ID, META_DAMAGED]:
		payload.erase(key)
	payload["version"] = VERSION
	payload["game_version"] = game_version()
	payload["saved_at"] = saved_at if not saved_at.is_empty() else Time.get_datetime_string_from_system(true)
	var text: String = JSON.stringify(payload, "\t", true)
	var day: int = as_int(payload.get("current_day", 0))
	var err: Error = OK
	if day >= 1:
		err = write_atomic(snapshot_path(slot, day, dir), text)
		if err != OK:
			return err
	err = write_atomic(slot_path(slot, dir), text)
	if err != OK:
		return err
	for later: int in _snapshot_days(slot, dir):
		if later > day:
			remove_with_fallbacks(snapshot_path(slot, later, dir))
	var meta: Dictionary = build_meta(payload)
	_save_serial += 1
	meta["saved_unix_ms"] = int(Time.get_unix_time_from_system() * 1000.0) if saved_at.is_empty() else 0
	meta["save_serial"] = _save_serial
	return write_atomic(meta_path(slot, dir), JSON.stringify(meta, "\t", true))


## État courant d'un emplacement (migré, validé). Si `current.json` (et ses
## `.tmp` / `.bak`) est illisible, repli sur l'instantané lisible le plus
## récent (QA-043 : `day_NN.json` du même matin, écrit avec le même contenu) ;
## vide si rien n'est lisible.
static func load_current(slot: int = DEFAULT_SLOT, dir: String = DEFAULT_DIR) -> Dictionary:
	if slot < 0:
		return {}
	var data: Dictionary = read_json(slot_path(slot, dir), parse)
	if not data.is_empty():
		return data
	var days: PackedInt32Array = _snapshot_days(slot, dir)
	for i: int in range(days.size() - 1, -1, -1):
		data = load_snapshot(slot, days[i], dir)
		if not data.is_empty():
			if file_exists_any(slot_path(slot, dir)):
				push_warning("SaveService: %s illisible, reprise de l'instantané du jour %d" % [slot_path(slot, dir), days[i]])
			return data
	return {}


## Jours dont l'emplacement garde un instantané **chargeable** (QA-045 : un
## `.tmp` orphelin tronqué n'est pas proposé), croissants.
static func list_snapshots(slot: int, dir: String = DEFAULT_DIR) -> PackedInt32Array:
	var days: PackedInt32Array = []
	for day: int in _snapshot_days(slot, dir):
		if not load_snapshot(slot, day, dir).is_empty():
			days.append(day)
	return days


## Jours dont l'emplacement a un fichier d'instantané (principal, `.tmp` ou
## `.bak`, lisible ou non), croissants.
static func _snapshot_days(slot: int, dir: String = DEFAULT_DIR) -> PackedInt32Array:
	var days: PackedInt32Array = []
	var folder: DirAccess = DirAccess.open(slot_dir(slot, dir))
	if folder == null:
		return days
	for file: String in folder.get_files():
		var name: String = file.trim_suffix(BACKUP_SUFFIX).trim_suffix(TMP_SUFFIX)
		if not (name.begins_with("day_") and name.ends_with(".json")):
			continue
		var number: String = name.trim_prefix("day_").trim_suffix(".json")
		if number.is_valid_int() and not days.has(number.to_int()):
			days.append(number.to_int())
	days.sort()
	return days


## Instantané « matin du jour `day` » (migré, validé) ; vide si absent.
static func load_snapshot(slot: int, day: int, dir: String = DEFAULT_DIR) -> Dictionary:
	if slot < 0 or day < 1:
		return {}
	return read_json(snapshot_path(slot, day, dir), parse)


## Résumé d'un emplacement (`meta.json`), reconstruit depuis l'état courant
## (`load_current`, avec son statut d'archive, QA-044) s'il manque ou est
## illisible ; vide si l'emplacement est libre. Emplacement occupé sans aucun
## état lisible : méta (lue, sinon minimale) avec `damaged = true` (QA-043).
static func load_meta(slot: int, dir: String = DEFAULT_DIR) -> Dictionary:
	var meta: Dictionary = read_json(meta_path(slot, dir))
	var meta_ok: bool = not meta.is_empty() and meta.has("status") and meta.has("current_day")
	var current: Dictionary = load_current(slot, dir)
	if current.is_empty():
		if not meta_ok and not _slot_has_files(slot, dir):
			return {}
		if not meta_ok:
			var days: PackedInt32Array = _snapshot_days(slot, dir)
			meta = {"version": VERSION, "status": STATUS_ACTIVE, "ending_id": "",
				"current_day": days[days.size() - 1] if not days.is_empty() else 0}
		meta[META_DAMAGED] = true
		return meta
	meta.erase(META_DAMAGED)
	if meta_ok:
		return meta
	return build_meta(current, str(current.get(KEY_STATUS, STATUS_ACTIVE)), str(current.get(KEY_ENDING_ID, "")))


## Vrai si le dossier de l'emplacement contient au moins un fichier.
static func _slot_has_files(slot: int, dir: String) -> bool:
	var folder: DirAccess = DirAccess.open(slot_dir(slot, dir))
	return folder != null and not folder.get_files().is_empty()


## Vrai si une méta d'emplacement est marquée endommagée (`META_DAMAGED`).
static func is_damaged(meta: Dictionary) -> bool:
	var value: Variant = meta.get(META_DAMAGED, false)
	return value is bool and value


## Méta de chaque emplacement 1..`SLOT_COUNT` (`{}` pour un emplacement
## libre), avec `slot` ajouté. Migre d'abord un `slot_0.json` v5.
static func list_slots(dir: String = DEFAULT_DIR) -> Array[Dictionary]:
	migrate_legacy(dir)
	var result: Array[Dictionary] = []
	for slot: int in range(1, SLOT_COUNT + 1):
		var meta: Dictionary = load_meta(slot, dir)
		if not meta.is_empty():
			meta["slot"] = slot
		result.append(meta)
	return result


## Emplacement de « Continuer » : partie `active` (non endommagée) au
## `saved_at` le plus récent ; `NO_SLOT` (-1) si aucune. Migre d'abord un `slot_0.json` v5.
static func latest_slot(dir: String = DEFAULT_DIR) -> int:
	var best: int = NO_SLOT
	var best_key: String = ""
	for meta: Dictionary in list_slots(dir):
		if meta.is_empty() or is_damaged(meta) or str(meta.get("status", STATUS_ACTIVE)) != STATUS_ACTIVE:
			continue
		var key: String = _recency_key(meta)
		if best == NO_SLOT or key > best_key:
			best = as_int(meta["slot"])
			best_key = key
	return best


## Premier emplacement libre, sinon `NO_SLOT`.
static func first_free_slot(dir: String = DEFAULT_DIR) -> int:
	migrate_legacy(dir)
	for slot: int in range(1, SLOT_COUNT + 1):
		if not has_save(slot, dir) and not _slot_has_files(slot, dir):
			return slot
	return NO_SLOT


## Archive une partie terminée (F1–F10, D-101) : `status = ended`,
## `ending_id` dans `meta.json` **et** dans `current.json` (QA-044 : la
## méta reconstruite garde le statut) ; état et instantanés gardés.
static func mark_ended(slot: int, ending_id: String, dir: String = DEFAULT_DIR) -> Error:
	var meta: Dictionary = load_meta(slot, dir)
	if meta.is_empty():
		return ERR_DOES_NOT_EXIST
	var current: Dictionary = load_current(slot, dir)
	if not current.is_empty():
		current[KEY_STATUS] = STATUS_ENDED
		current[KEY_ENDING_ID] = ending_id
		var err: Error = write_atomic(slot_path(slot, dir), JSON.stringify(current, "\t", true))
		if err != OK:
			return err
	meta.erase("slot")
	meta.erase(META_DAMAGED)
	meta["status"] = STATUS_ENDED
	meta["ending_id"] = ending_id
	return write_atomic(meta_path(slot, dir), JSON.stringify(meta, "\t", true))


## Inscrit tout de suite la difficulté d'une partie dans son emplacement
## (QA-046 : Récit → Dur, D-102 — un « Quitter » avant la soirée ne l'annule
## pas) : `current.json` et `meta.json` seulement, ni instantané ni
## `saved_at` changés. `campaign_seed` ≠ 0 : n'écrit que si l'emplacement
## contient cette campagne. Erreur si l'emplacement n'a pas d'état lisible.
static func persist_difficulty(slot: int, difficulty: String, campaign_seed: int = 0,
		dir: String = DEFAULT_DIR) -> Error:
	var current: Dictionary = load_current(slot, dir)
	if current.is_empty():
		return ERR_DOES_NOT_EXIST
	if campaign_seed != 0 and as_int(float(as_int(current.get("campaign_seed", 0)))) != as_int(float(campaign_seed)):
		return ERR_INVALID_PARAMETER
	var value: String = DIFFICULTY_STORY if difficulty == DIFFICULTY_STORY else DIFFICULTY_HARD
	current["difficulty"] = value
	var err: Error = write_atomic(slot_path(slot, dir), JSON.stringify(current, "\t", true))
	if err != OK:
		return err
	var meta: Dictionary = read_json(meta_path(slot, dir))
	if meta.is_empty() or not meta.has("status"):
		return OK
	meta["difficulty"] = value
	return write_atomic(meta_path(slot, dir), JSON.stringify(meta, "\t", true))


## Vide un emplacement (état, instantanés, méta) ; le profil n'est pas touché.
static func delete_slot(slot: int, dir: String = DEFAULT_DIR) -> void:
	var path: String = slot_dir(slot, dir)
	var folder: DirAccess = DirAccess.open(path)
	if folder == null:
		return
	for file: String in folder.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


## Résumé d'un état sauvegardé pour l'écran Charger (`meta.json`).
static func build_meta(data: Dictionary, status: String = STATUS_ACTIVE, ending_id: String = "") -> Dictionary:
	var flags: Dictionary = data.get("narrative_flags", {}) if data.get("narrative_flags") is Dictionary else {}
	var act: int = 1
	if _truthy(flags.get(String(EndingService.FLAG_ACT3), false)):
		act = 3
	elif _truthy(flags.get(String(EndingService.FLAG_ACT2), false)):
		act = 2
	var home_data: Dictionary = data.get("household", {}) if data.get("household") is Dictionary else {}
	var home: Household = Household.from_dict(home_data)
	var alive: int = 0
	var sick: int = 0
	var absent: int = 0
	for member: Household.Member in home.members:
		if not member.is_alive():
			continue
		alive += 1
		if member.is_sick():
			sick += 1
		if not member.is_present():
			absent += 1
	var saved_at: String = str(data.get("saved_at", ""))
	return {
		"version": VERSION,
		"game_version": str(data.get("game_version", game_version())),
		"saved_at": saved_at,
		"current_day": as_int(data.get("current_day", 0)),
		"act": act,
		"credits": as_int(data.get("credits", 0)),
		"household_summary": {"alive": alive, "sick": sick, "absent": absent, "total": home.members.size()},
		"difficulty": difficulty_of(data),
		"status": status,
		"ending_id": ending_id,
		"portrait_seed": as_int(data.get("portrait_seed", 0)),
		"play_time_sec": as_int(data.get("play_time_sec", 0)),
		"campaign_seed": as_int(data.get("campaign_seed", 0)),
	}


## Difficulté d'un état (`"hard"` si absente ou inconnue).
static func difficulty_of(data: Dictionary) -> String:
	var value: String = str(data.get("difficulty", DIFFICULTY_HARD))
	return value if value == DIFFICULTY_STORY else DIFFICULTY_HARD


# --- Migration des fichiers v5 → v6 ----------------------------------------------

## Déplace une sauvegarde v5 (`<dir>/slot_0.json`, ou son `.tmp` / `.bak`)
## dans l'emplacement 1 (ou le premier libre) : `current.json`, `meta.json`,
## instantané du jour courant ; `saved_at` d'origine conservé. L'ancien
## fichier est renommé `slot_0.v5.bak` (jamais supprimé), même s'il est
## illisible. Renvoie l'emplacement rempli, `NO_SLOT` sinon. Idempotent.
static func migrate_legacy(dir: String = DEFAULT_DIR) -> int:
	var legacy: String = resolve_dir(dir).path_join(LEGACY_FILE)
	if not file_exists_any(legacy):
		return NO_SLOT
	var data: Dictionary = read_json(legacy, parse)
	var target: int = NO_SLOT
	if data.is_empty():
		push_warning("SaveService: %s illisible, mis de côté sans migration" % legacy)
	else:
		for slot: int in range(1, SLOT_COUNT + 1):
			if not has_save(slot, dir):
				target = slot
				break
		if target == NO_SLOT:
			push_warning("SaveService: aucun emplacement libre pour migrer %s" % legacy)
			return NO_SLOT
		var err: Error = save_slot(data, target, dir, str(data.get("saved_at", "")))
		if err != OK:
			push_warning("SaveService: migration de %s impossible (%s)" % [legacy, error_string(err)])
			return NO_SLOT
	var backup: String = resolve_dir(dir).path_join(LEGACY_BACKUP_FILE)
	if FileAccess.file_exists(legacy):
		_rename_aside(legacy, backup)
	for suffix: String in [TMP_SUFFIX, BACKUP_SUFFIX]:
		if FileAccess.file_exists(legacy + suffix):
			_rename_aside(legacy + suffix, backup if not FileAccess.file_exists(backup) else backup + suffix)
	return target


static func _rename_aside(from: String, to: String) -> void:
	if FileAccess.file_exists(to):
		DirAccess.remove_absolute(to)
	var err: Error = DirAccess.rename_absolute(from, to)
	if err != OK:
		push_warning("SaveService: renommage de %s en %s impossible (%s)" % [from, to, error_string(err)])


static func _recency_key(meta: Dictionary) -> String:
	return "%s|%015d|%09d" % [str(meta.get("saved_at", "")), as_int(meta.get("saved_unix_ms", 0)),
			as_int(meta.get("save_serial", 0))]


static func _truthy(value: Variant) -> bool:
	return (value is bool and value) or ((value is int or value is float) and as_int(value) != 0)


# --- Lecture d'un état -----------------------------------------------------------

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
		version = 5
	if version == 5:
		data = _migrate_5_to_6(data)
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


## v5 → v6 : état inchangé ; difficulté « Dur » explicite (D-102 : une partie
## antérieure n'a jamais connu le mode Récit). Le déplacement du fichier vers
## un emplacement est fait par `migrate_legacy`.
static func _migrate_5_to_6(data: Dictionary) -> Dictionary:
	if not data.has("difficulty"):
		data["difficulty"] = DIFFICULTY_HARD
	data["version"] = 6
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
