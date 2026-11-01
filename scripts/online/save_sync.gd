## Règles de synchronisation des sauvegardes (M16, D-232 ; ONLINE.md §4–§5) —
## logique **pure** (aucun réseau, aucun nœud), testée seule.
##
## Un emplacement = un **jeu de fichiers** (`SaveService.read_slot_files` :
## méta, état courant, instantanés). Chaque côté est résumé par une
## **empreinte** (`fingerprint` : SHA-256 du JSON canonique) ; le serveur, par
## le `rev` de sa ligne `meta` (écrite **en dernier** : témoin de l'emplacement).
## L'**état de base** (`OnlineStore.base`) est le dernier état connu identique
## des deux côtés : `{fp, rev, serial, ms, records}` (`records` : empreinte de
## chaque ligne envoyée ou tirée, pour n'envoyer que ce qui a changé).
##
## `decide` compare local / distant / base :
## | local changé | distant changé | action |
## |---|---|---|
## | non | non | rien |
## | oui | non | envoyer (`PUSH`), ou supprimer à distance si l'emplacement a été vidé ici |
## | non | oui | tirer (`PULL`) ; distant supprimé ailleurs : `DETACH` (copie locale **gardée**, plus synchronisée tant qu'elle ne change pas) |
## | oui | oui | `CONFLICT` (comparaison des empreintes après téléchargement ; versions différentes : la gagnante — `save_serial` puis `saved_unix_ms` — reste dans l'emplacement, l'autre est copiée dans `slot_N/conflict_<horodatage>/`) |
## Jamais de perte silencieuse : une suppression distante ne supprime jamais
## une partie locale ; une partie supprimée ici mais avancée ailleurs est tirée.
class_name SaveSync
extends RefCounted

enum Action {
	NONE, ## identiques (ou vides des deux côtés)
	PUSH, ## envoyer la version locale
	PULL, ## tirer la version distante
	DELETE_REMOTE, ## emplacement vidé ici : supprimer les lignes distantes
	DETACH, ## supprimé ailleurs : garder la copie locale, base « distant absent »
	FORGET, ## vidé des deux côtés : oublier la base
	CONFLICT, ## deux versions ont avancé : télécharger, comparer, départager
}

const FAMILY_GAME: String = "game"
const FAMILY_DEMO: String = "demo"
const KIND_CURRENT: String = "current"
const KIND_META: String = "meta"
const KIND_SNAPSHOT: String = "snapshot"
const KIND_PROFILE: String = "profile"
const DEMO_PREFIX: String = "demo_"
## Clés de méta propres à l'appareil, hors empreinte (`slot` ajouté par
## `list_slots`, `damaged` recalculé à la lecture).
const VOLATILE_META_KEYS: Array[String] = ["slot", "damaged"]
## Plus grand entier exact en JSON (2^53).
const JSON_INT_LIMIT: float = 9007199254740992.0


## Famille de données : `demo` dans la démo (sauvegardes séparées, D-215 ;
## lignes `demo_*` du serveur), `game` sinon.
static func family() -> String:
	return FAMILY_DEMO if DemoMode.is_demo() else FAMILY_GAME


## `kind` du serveur pour une famille (`demo_meta`…).
static func kind_name(kind: String, p_family: String) -> String:
	return DEMO_PREFIX + kind if p_family == FAMILY_DEMO else kind


## `kind` sans préfixe de famille.
static func base_kind(name: String) -> String:
	return name.trim_prefix(DEMO_PREFIX)


## Clé d'une ligne dans `records` : `meta`, `current`, `snapshot:12`.
static func record_key(kind: String, day: int = 0) -> String:
	return "%s:%d" % [kind, day] if kind == KIND_SNAPSHOT else kind


## Copie canonique d'une valeur JSON : nombres flottants entiers redevenus
## entiers (graines 53 bits et horodatages exacts à la réécriture ; JSON relu
## ne connaît que des flottants), clés en texte.
static func canon(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		var source: Dictionary = value
		for key: Variant in source:
			out[str(key)] = canon(source[key])
		return out
	if value is Array:
		var list: Array = []
		for item: Variant in value:
			list.append(canon(item))
		return list
	if value is float:
		var f: float = value
		if is_finite(f) and absf(f) < JSON_INT_LIMIT and is_equal_approx(f, roundf(f)) and f == roundf(f):
			return int(f)
	return value


## Jour d'une clé d'instantané (entier, ou texte relu d'un JSON).
static func day_of(key: Variant) -> int:
	return (key as String).to_int() if key is String else SaveService.as_int(key)


## Jeu de fichiers d'un emplacement, canonique (`{meta, current, snapshots}`,
## instantanés indexés par jour entier) ; vide si l'emplacement est libre.
static func slot_files(slot: int, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	var raw: Dictionary = SaveService.read_slot_files(slot, dir)
	if raw.is_empty():
		return {}
	var meta: Dictionary = canon(raw["meta"])
	for key: String in VOLATILE_META_KEYS:
		meta.erase(key)
	var snapshots: Dictionary = {}
	for day: Variant in raw["snapshots"]:
		snapshots[day_of(day)] = canon(raw["snapshots"][day])
	return {"meta": meta, "current": canon(raw["current"]), "snapshots": snapshots}


## Empreinte d'un jeu de fichiers (vide pour un emplacement libre).
static func fingerprint(files: Dictionary) -> String:
	if files.is_empty():
		return ""
	var snapshots: Dictionary = {}
	var source: Dictionary = files.get("snapshots", {})
	for day: Variant in source:
		snapshots["%02d" % day_of(day)] = source[day]
	var meta: Dictionary = (files.get("meta", {}) as Dictionary).duplicate()
	for key: String in VOLATILE_META_KEYS:
		meta.erase(key)
	return JSON.stringify(canon({"meta": meta, "current": files.get("current", {}), "snapshots": snapshots}), "", true).sha256_text()


## Empreinte d'une ligne (charge utile) ou d'un profil.
static func payload_fingerprint(payload: Dictionary) -> String:
	return JSON.stringify(canon(payload), "", true).sha256_text()


## Empreintes par ligne d'un jeu de fichiers (`records` de la base).
static func record_fingerprints(files: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if files.is_empty():
		return out
	out[KIND_META] = payload_fingerprint(files["meta"])
	out[KIND_CURRENT] = payload_fingerprint(files["current"])
	var snapshots: Dictionary = files["snapshots"]
	for day: Variant in snapshots:
		out[record_key(KIND_SNAPSHOT, day_of(day))] = payload_fingerprint(snapshots[day])
	return out


## Action à mener pour un emplacement. `local_fp` : empreinte locale (vide :
## emplacement libre) ; `remote_rev` : `rev` de la ligne `meta` distante (0 :
## absente) ; `base` : `{fp, rev}` du dernier état commun (vide : jamais
## synchronisé sur ce compte).
static func decide(local_fp: String, remote_rev: int, base: Dictionary) -> Action:
	var base_fp: String = str(base.get("fp", ""))
	var base_rev: int = SaveService.as_int(base.get("rev", 0))
	var local_changed: bool = local_fp != base_fp
	var remote_changed: bool = remote_rev != base_rev
	if not local_changed and not remote_changed:
		return Action.NONE
	if local_changed and not remote_changed:
		if not local_fp.is_empty():
			return Action.PUSH
		return Action.DELETE_REMOTE if remote_rev > 0 else Action.FORGET
	if not local_changed:
		if remote_rev == 0:
			return Action.DETACH if not local_fp.is_empty() else Action.FORGET
		return Action.PULL
	# Les deux côtés ont changé.
	if remote_rev == 0:
		return Action.PUSH if not local_fp.is_empty() else Action.FORGET
	if local_fp.is_empty():
		return Action.PULL
	return Action.CONFLICT


## Vrai si la version locale l'emporte (D-232) : `save_serial` le plus grand,
## puis `saved_unix_ms` le plus grand ; à égalité, la version locale (rien ne
## bouge sur cet appareil).
static func local_wins(local_meta: Dictionary, remote_meta: Dictionary) -> bool:
	var ls: int = SaveService.as_int(local_meta.get("save_serial", 0))
	var rs: int = SaveService.as_int(remote_meta.get("save_serial", 0))
	if ls != rs:
		return ls > rs
	return SaveService.as_int(local_meta.get("saved_unix_ms", 0)) >= SaveService.as_int(remote_meta.get("saved_unix_ms", 0))


## Fichiers distants assemblés depuis les lignes tirées (`{kind, day, payload}`) ;
## vide s'il manque la méta ou l'état courant.
static func files_from_rows(rows: Array) -> Dictionary:
	var meta: Dictionary = {}
	var current: Dictionary = {}
	var snapshots: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var payload: Variant = row.get("payload", null)
		if not payload is Dictionary:
			continue
		match base_kind(str(row.get("kind", ""))):
			KIND_META:
				meta = canon(payload)
			KIND_CURRENT:
				current = canon(payload)
			KIND_SNAPSHOT:
				var day: int = SaveService.as_int(row.get("day", 0))
				if day >= 1 and day <= SaveService.EPILOGUE_DAY:
					snapshots[day] = canon(payload)
	if meta.is_empty() or current.is_empty():
		return {}
	for key: String in VOLATILE_META_KEYS:
		meta.erase(key)
	return {"meta": meta, "current": current, "snapshots": snapshots}


## Vrai si un jeu de fichiers tiré est **chargeable** par ce jeu (état courant
## migré et validé : version connue, jour dans les bornes — une sauvegarde
## d'une version future n'écrase jamais l'emplacement local).
static func files_loadable(files: Dictionary) -> bool:
	if files.is_empty():
		return false
	return not SaveService.parse(JSON.stringify(files["current"]), "<distant>").is_empty()
