## Profil global du joueur (ARCHITECTURE §10.3, §11.7 ; D-101, D-105, D-132)
## — JSON texte `<dossier des sauvegardes>/profile.json`
## (`user://saves/profile.json`).
##
## Progression qui survit aux parties. **v2 (M12, D-132)** :
## - `endings_seen` : `[{id, variant, act, day, date, count, last_date,
##   first_line_key}]`, unicité `(id, variant)`, `count` incrémenté à chaque
##   fin (`record_ending`) ;
## - `characters_met` (cas scénarisés traités), `known_names` (`chr_*` dont le
##   vrai nom a été appris), `max_day_reached` (accès à la Garde, D-128) ;
## - `story_mode_used`, `epilogue_unlocked` (première fin de l'Acte III) ;
## - `epilogues` : `{"<fin>:<variante>": {world, key, seed, first_date, count,
##   last_date, last_lines}}` — `seed` = graine d'épilogue (D-125), rejouable
##   même après suppression de l'emplacement ;
## - Garde de nuit (§2.7 de M12) : `best_runs` (10 meilleures), `garde_daily`
##   (60 derniers jours : meilleur, premier essai, essais), `garde_seeds` (20
##   dernières graines libres), `garde_stats` ;
## - `last_campaign` : dernière partie **terminée** (fin, variante, jour, date,
##   climat, traces, monde d'épilogue).
## Migration v1 → v2 (`migrate_v1`, au premier chargement) : `count = 1`,
## `act` déduit du jour, puis reconstruction depuis les emplacements terminés
## (variante, graine d'épilogue, `day_31.json`, `max_day_reached`,
## `last_campaign`) ; l'ancien fichier est copié en `profile.v1.bak`.
## **v3 (M14, D-183, D-191 ; ARCHITECTURE §12 ter.5)** :
## - `portraits` : `{chr_id: {appearance, visor, case_id, day, act}}`, visage
##   de la **dernière rencontre** tel que vu à la vitre (`visor` : `down`,
##   `up`, `none`), ≤ 400 o par personnage ; écrit à chaque sauvegarde du soir
##   et à la fin pour les cas du jour joué (`record_portraits`) ;
## - `cinematics_seen` : ids des cinématiques vues (`record_cinematic_seen`) ;
## - `cinematic_replays` (QA-073, ajout sans changement de version) :
##   `{cin_id: {ending, variant, world, act, day, plates, flags}}`, ce qu'il
##   faut pour que REVOIR rejoue la **dernière** séquence vue telle quelle :
##   planches retenues (ids, dans l'ordre) et drapeaux de contexte lus par ses
##   conditions (planches, légendes, figures) et par les variantes de son thème
##   (≤ `REPLAY_MAX_FLAGS`). Absent (profil antérieur) : `{}`, REVOIR retombe
##   sur la sélection sans drapeaux.
## Migration v2 → v3 (`migrate_v2`) : `portraits` reconstruits depuis la
## `case_memory` des emplacements (le plus ancien d'abord : la partie la plus
## récente l'emporte), copie `profile.v2.bak`. Un profil v1 passe par
## `migrate_v1` puis la même reconstruction (une seule réécriture).
## Jamais effacé par une fin ni par `SaveService.delete_slot`. Écriture
## atomique et lecture de secours de `SaveService`. Service statique pur.
class_name ProfileService
extends RefCounted

const VERSION: int = 3
const FILE_NAME: String = "profile.json"
const V1_BACKUP_FILE: String = "profile.v1.bak"
const V2_BACKUP_FILE: String = "profile.v2.bak"
## Taille JSON visée d'un portrait (M14 §5.2) : ≤ 400 octets.
const PORTRAIT_MAX_BYTES: int = 400
## Garde : meilleures gardes gardées, jours de graine du jour, graines libres.
const TOP_RUNS: int = 10
const DAILY_DAYS: int = 60
const FREE_SEEDS: int = 20
## `cinematic_replays` : planches et drapeaux gardés par séquence (QA-073).
const REPLAY_MAX_PLATES: int = 8
const REPLAY_MAX_FLAGS: int = 32


static func profile_path(dir: String = SaveService.DEFAULT_DIR) -> String:
	return SaveService.resolve_dir(dir).path_join(FILE_NAME)


## Profil vierge.
static func empty_profile() -> Dictionary:
	return {
		"version": VERSION,
		"endings_seen": [],
		"characters_met": [],
		"known_names": [],
		"max_day_reached": 0,
		"story_mode_used": false,
		"epilogue_unlocked": false,
		"epilogues": {},
		"best_runs": [],
		"garde_daily": {},
		"garde_seeds": [],
		"garde_stats": {"runs": 0, "total_correct": 0, "longest_run": 0},
		"last_campaign": {},
		"portraits": {},
		"cinematics_seen": [],
		"cinematic_replays": {},
	}


## Profil lu (migré, complété des champs manquants) ; vierge si absent ou illisible.
static func load_profile(dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	var raw: Dictionary = SaveService.read_json(profile_path(dir))
	if not raw.is_empty():
		var version: int = SaveService.as_int(raw.get("version", 1), 1)
		if version < 2:
			return migrate_v1(raw, dir)
		if version < VERSION:
			return migrate_v2(raw, dir)
	return sanitize(raw)


## Copie du profil `raw` aux types attendus (champs inconnus conservés).
static func sanitize(raw: Dictionary) -> Dictionary:
	var profile: Dictionary = empty_profile()
	for key: Variant in raw:
		profile[str(key)] = raw[key]
	var endings: Array = []
	var seen: Variant = profile.get("endings_seen", [])
	if seen is Array:
		for entry: Variant in seen:
			if not entry is Dictionary or str((entry as Dictionary).get("id", "")).is_empty():
				continue
			var row: Dictionary = entry
			var clean: Dictionary = {
				"id": str(row["id"]),
				"variant": str(row.get("variant", "")),
				"day": SaveService.as_int(row.get("day", 0)),
				"date": str(row.get("date", "")),
				"count": maxi(SaveService.as_int(row.get("count", 1), 1), 1),
				"last_date": str(row.get("last_date", row.get("date", ""))),
				"first_line_key": str(row.get("first_line_key", "")),
			}
			clean["act"] = clampi(SaveService.as_int(row.get("act", act_of_day(clean["day"]))), 1, 3)
			var existing: Dictionary = _find_ending(endings, clean["id"], clean["variant"])
			if existing.is_empty():
				endings.append(clean)
			else:
				existing["count"] = SaveService.as_int(existing["count"]) + SaveService.as_int(clean["count"])
	profile["endings_seen"] = endings
	profile["characters_met"] = _unique_strings(profile.get("characters_met", []))
	profile["known_names"] = _unique_strings(profile.get("known_names", []))
	profile["max_day_reached"] = maxi(SaveService.as_int(profile.get("max_day_reached", 0)), 0)
	profile["story_mode_used"] = _is_true(profile.get("story_mode_used", false))
	profile["epilogue_unlocked"] = _is_true(profile.get("epilogue_unlocked", false))
	profile["epilogues"] = _sanitize_epilogues(profile.get("epilogues", {}))
	profile["best_runs"] = _sanitize_runs(profile.get("best_runs", []))
	profile["garde_daily"] = _sanitize_daily(profile.get("garde_daily", {}))
	var seeds: Array = []
	var raw_seeds: Variant = profile.get("garde_seeds", [])
	if raw_seeds is Array:
		for entry: Variant in raw_seeds:
			if entry is Dictionary and not str((entry as Dictionary).get("seed_code", "")).is_empty():
				var row: Dictionary = entry
				seeds.append({"seed_code": str(row["seed_code"]), "best": SaveService.as_int(row.get("best", 0)),
						"garde_version": SaveService.as_int(row.get("garde_version", 1), 1)})
	profile["garde_seeds"] = seeds.slice(0, FREE_SEEDS)
	var stats: Dictionary = profile.get("garde_stats", {}) if profile.get("garde_stats") is Dictionary else {}
	profile["garde_stats"] = {"runs": SaveService.as_int(stats.get("runs", 0)),
			"total_correct": SaveService.as_int(stats.get("total_correct", 0)),
			"longest_run": SaveService.as_int(stats.get("longest_run", 0))}
	if not profile.get("last_campaign") is Dictionary:
		profile["last_campaign"] = {}
	profile["portraits"] = _sanitize_portraits(profile.get("portraits", {}))
	profile["cinematics_seen"] = _unique_strings(profile.get("cinematics_seen", []))
	profile["cinematic_replays"] = _sanitize_replays(profile.get("cinematic_replays", {}))
	profile["version"] = VERSION
	return profile


static func save_profile(profile: Dictionary, dir: String = SaveService.DEFAULT_DIR) -> Error:
	return SaveService.write_atomic(profile_path(dir), JSON.stringify(sanitize(profile), "\t", true))


## Acte d'une fin d'après son jour (migration v1 : 1 jusqu'au J10, 2 jusqu'au J20).
static func act_of_day(day: int) -> int:
	if day <= 10:
		return 1
	return 2 if day <= 20 else 3


## Identifiants des fins vues (sans doublon).
static func ending_ids(profile: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = []
	for entry: Dictionary in sanitize(profile)["endings_seen"]:
		if not ids.has(str(entry["id"])):
			ids.append(str(entry["id"]))
	return ids


static func has_seen_ending(profile: Dictionary, ending_id: String) -> bool:
	return ending_ids(profile).has(ending_id)


## Nombre de fois qu'une fin (toutes variantes, ou une variante) a été vue.
static func ending_count(profile: Dictionary, ending_id: String, variant: String = "*") -> int:
	var total: int = 0
	for entry: Dictionary in sanitize(profile)["endings_seen"]:
		if str(entry["id"]) == ending_id and (variant == "*" or str(entry["variant"]) == variant):
			total += SaveService.as_int(entry["count"])
	return total


## Garde accessible (D-128).
static func is_garde_unlocked(profile: Dictionary) -> bool:
	return GardeService.is_unlocked(profile)


## Fusionne une partie dans le profil de `dir` : fin vue (`ending_id` non vide,
## **première fois seulement** : jour et date gardés — compter les passages :
## `record_ending`), personnages croisés, mode Récit utilisé, jour atteint
## (`max_day`, 0 = inchangé). N'écrit que si quelque chose change. Renvoie vrai si écrit.
static func record(dir: String, ending_id: String = "", day: int = 0, characters: Array = [],
		story_mode: bool = false, max_day: int = 0) -> bool:
	var profile: Dictionary = load_profile(dir)
	var changed: bool = false
	if not ending_id.is_empty() and not has_seen_ending(profile, ending_id):
		var now: String = _now()
		var endings: Array = profile["endings_seen"]
		endings.append({"id": ending_id, "variant": "", "act": act_of_day(day), "day": day, "date": now, "count": 1,
				"last_date": now, "first_line_key": ""})
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
	if max_day > SaveService.as_int(profile["max_day_reached"]):
		profile["max_day_reached"] = max_day
		changed = true
	if not changed:
		return false
	return save_profile(profile, dir) == OK


## Inscrit une fin (D-132) : `info` = `{id, variant, act, day, first_line_key,
## campaign_seed, climate, traces, world}`. Entrée `(id, variant)` créée ou
## `count` + 1 (une entrée v1 sans variante reste à part). Met à jour `last_campaign` et `max_day_reached`. Renvoie vrai si écrit.
static func record_ending(dir: String, info: Dictionary) -> bool:
	var ending_id: String = str(info.get("id", ""))
	if ending_id.is_empty():
		return false
	var profile: Dictionary = load_profile(dir)
	var variant: String = str(info.get("variant", ""))
	var day: int = SaveService.as_int(info.get("day", 0))
	var now: String = _now()
	var endings: Array = profile["endings_seen"]
	var entry: Dictionary = _find_ending(endings, ending_id, variant)
	if entry.is_empty():
		entry = {"id": ending_id, "variant": variant, "act": SaveService.as_int(info.get("act", act_of_day(day))),
				"day": day, "date": now, "count": 0, "last_date": now,
				"first_line_key": str(info.get("first_line_key", ""))}
		endings.append(entry)
	entry["count"] = SaveService.as_int(entry["count"]) + 1
	entry["last_date"] = now
	if str(entry.get("first_line_key", "")).is_empty():
		entry["first_line_key"] = str(info.get("first_line_key", ""))
	profile["max_day_reached"] = maxi(SaveService.as_int(profile["max_day_reached"]), day)
	profile["last_campaign"] = {
		"ending": ending_id,
		"variant": variant,
		"ending_key": str(info.get("ending_key", "")),
		"act": SaveService.as_int(info.get("act", act_of_day(day))),
		"day": day,
		"date": now,
		"campaign_seed": SaveService.as_int(info.get("campaign_seed", 0)),
		"climate": str(info.get("climate", "")),
		"traces": _unique_strings(info.get("traces", [])),
		"world": str(info.get("world", "")),
	}
	return save_profile(profile, dir) == OK


## Personnages dont le vrai nom est appris (D-131, B63). Renvoie vrai si écrit.
static func record_known_names(dir: String, chr_ids: PackedStringArray) -> bool:
	var profile: Dictionary = load_profile(dir)
	var known: Array = profile["known_names"]
	var changed: bool = false
	for id: String in chr_ids:
		if not id.is_empty() and not known.has(id):
			known.append(id)
			changed = true
	return save_profile(profile, dir) == OK if changed else false


# --- Épilogues -----------------------------------------------------------------------

## Débloque l'épilogue d'une variante de fin (D-125) : graine stockée (remplace
## la précédente de même clé), `epilogue_unlocked`. Renvoie vrai si écrit.
static func unlock_epilogue(dir: String, epi: Dictionary) -> bool:
	if epi.is_empty():
		return false
	var profile: Dictionary = load_profile(dir)
	_store_epilogue(profile, epi)
	return save_profile(profile, dir) == OK


static func _store_epilogue(profile: Dictionary, epi: Dictionary) -> void:
	var epilogues: Dictionary = profile["epilogues"]
	var key: String = EpilogueService.profile_key(epi)
	var entry: Dictionary = epilogues.get(key, {})
	entry["world"] = str(epi.get("world", ""))
	entry["key"] = str(epi.get("ending_key", ""))
	entry["seed"] = epi.duplicate(true)
	entry["first_date"] = str(entry.get("first_date", ""))
	entry["count"] = SaveService.as_int(entry.get("count", 0))
	entry["last_date"] = str(entry.get("last_date", ""))
	if not entry.get("last_lines") is Array:
		entry["last_lines"] = []
	epilogues[key] = entry
	profile["epilogue_unlocked"] = true


## Un J31 joué jusqu'à la conclusion : nombre de fois, dates, dernières lignes.
static func record_epilogue_played(dir: String, key: String, lines: PackedStringArray, epi: Dictionary = {}) -> bool:
	var profile: Dictionary = load_profile(dir)
	var epilogues: Dictionary = profile["epilogues"]
	if not epilogues.has(key):
		if epi.is_empty():
			return false
		_store_epilogue(profile, epi)
	var entry: Dictionary = epilogues[key]
	var now: String = _now()
	if str(entry.get("first_date", "")).is_empty():
		entry["first_date"] = now
	entry["count"] = SaveService.as_int(entry.get("count", 0)) + 1
	entry["last_date"] = now
	entry["last_lines"] = Array(lines)
	return save_profile(profile, dir) == OK


## Graine d'épilogue d'une variante (`<fin>:<variante>`), vide si absente.
static func epilogue_seed(profile: Dictionary, key: String) -> Dictionary:
	var epilogues: Dictionary = sanitize(profile)["epilogues"]
	var entry: Dictionary = epilogues.get(key, {})
	return EpilogueService.sanitize_seed(entry.get("seed", {}) if entry.get("seed") is Dictionary else {})


# --- Garde de nuit ------------------------------------------------------------------

## Inscrit une garde terminée (`GardeRun.to_record()`) : statistiques, 10
## meilleures (`best_runs`), graine du jour (`garde_daily`, premier essai,
## 60 jours), graines libres (`garde_seeds`, 20). Renvoie les pastilles
## `{new_record, daily_record, first_try, rank}` (`rank` −1 hors du top 10).
## Un record ne se compare qu'à `garde_version` égale.
static func record_garde(dir: String, run: Dictionary) -> Dictionary:
	var profile: Dictionary = load_profile(dir)
	var score: int = SaveService.as_int(run.get("score", 0))
	var version: int = SaveService.as_int(run.get("garde_version", 1), 1)
	var kind: String = str(run.get("kind", "free"))
	var code: String = str(run.get("seed_code", ""))
	var badges: Dictionary = {"new_record": false, "daily_record": false, "first_try": false, "rank": -1}
	var stats: Dictionary = profile["garde_stats"]
	stats["runs"] = SaveService.as_int(stats["runs"]) + 1
	stats["total_correct"] = SaveService.as_int(stats["total_correct"]) + score
	stats["longest_run"] = maxi(SaveService.as_int(stats["longest_run"]), SaveService.as_int(run.get("passengers", 0)))
	var best: int = -1
	for entry: Dictionary in profile["best_runs"]:
		if SaveService.as_int(entry["garde_version"]) == version:
			best = maxi(best, SaveService.as_int(entry["score"]))
	badges["new_record"] = score > best
	var row: Dictionary = {"score": score, "seed_code": code, "kind": kind, "date": str(run.get("played_on", run.get("date", _today()))),
			"garde_version": version, "duration_sec": SaveService.as_int(run.get("duration_sec", 0)),
			"directives": SaveService.as_int(run.get("directives", 0)), "palier": SaveService.as_int(run.get("palier", 0))}
	var runs: Array = profile["best_runs"]
	var rank: int = runs.size()
	for i: int in runs.size():
		if score > SaveService.as_int((runs[i] as Dictionary)["score"]):
			rank = i
			break
	if rank < TOP_RUNS:
		runs.insert(rank, row)
		badges["rank"] = rank
	profile["best_runs"] = runs.slice(0, TOP_RUNS)
	if kind == String(GardeService.KIND_DAILY):
		var date: String = str(run.get("date", ""))
		var daily: Dictionary = profile["garde_daily"]
		var entry: Dictionary = daily.get(date, {})
		if entry.is_empty() or SaveService.as_int(entry.get("garde_version", version)) != version:
			entry = {"best": score, "first_try": score, "attempts": 0, "garde_version": version}
			badges["first_try"] = true
			badges["daily_record"] = true
		elif score > SaveService.as_int(entry["best"]):
			entry["best"] = score
			badges["daily_record"] = true
		entry["attempts"] = SaveService.as_int(entry["attempts"]) + 1
		daily[date] = entry
		profile["garde_daily"] = _purge_daily(daily, date)
	elif not code.is_empty():
		var seeds: Array = profile["garde_seeds"]
		var previous: int = -1
		for i: int in range(seeds.size() - 1, -1, -1):
			if str((seeds[i] as Dictionary)["seed_code"]) == code:
				previous = SaveService.as_int((seeds[i] as Dictionary)["best"])
				seeds.remove_at(i)
		seeds.insert(0, {"seed_code": code, "best": maxi(previous, score), "garde_version": version})
		profile["garde_seeds"] = seeds.slice(0, FREE_SEEDS)
	save_profile(profile, dir)
	return badges


## Garde les entrées de graine du jour des `DAILY_DAYS` derniers jours (par
## rapport à `latest`, `AAAA-MM-JJ`).
static func _purge_daily(daily: Dictionary, latest: String) -> Dictionary:
	var limit: int = _date_number(latest) - (DAILY_DAYS - 1)
	var kept: Dictionary = {}
	for key: Variant in daily:
		if _date_number(str(key)) >= limit:
			kept[key] = daily[key]
	return kept


## Jour absolu d'une date `AAAA-MM-JJ` (comparaisons de jours), 0 si invalide.
static func _date_number(text: String) -> int:
	var parts: PackedStringArray = text.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return 0
	var unix: int = int(Time.get_unix_time_from_datetime_dict({"year": parts[0].to_int(), "month": parts[1].to_int(),
			"day": parts[2].to_int(), "hour": 0, "minute": 0, "second": 0}))
	return floori(unix / 86400.0)


# --- M14 : portraits du Dossier, cinématiques vues (v3) ----------------------------

## Portrait d'un personnage (`{appearance, visor, case_id, day, act}`), vide si
## le visage n'a jamais été vu.
static func portrait_of(profile: Dictionary, chr_id: String) -> Dictionary:
	var portraits: Dictionary = sanitize(profile)["portraits"]
	return portraits.get(chr_id, {})


## Visage d'un portrait tel que vu (visière remise si jamais relevée), null si vide.
static func portrait_appearance(entry: Dictionary) -> PassengerAppearance:
	return CaseMemory.seen_appearance(entry) if not entry.is_empty() else null


## Entrée de portrait tirée d'une entrée de `case_memory` (vide si elle n'a
## pas de visage ou si elle est recalculée, jamais vue).
static func portrait_entry(case_id: String, memory_entry: Dictionary) -> Dictionary:
	if memory_entry.get("recalled", false) or CaseMemory.appearance_of(memory_entry) == null:
		return {}
	var day: int = SaveService.as_int(memory_entry.get("day", 0))
	return {"appearance": (memory_entry["appearance"] as Dictionary).duplicate(true),
			"visor": CaseMemory.visor_of(memory_entry), "case_id": case_id, "day": day,
			"act": act_of_day(day)}


## Inscrit (remplace) le portrait d'un personnage. Renvoie vrai si écrit.
static func record_portrait(dir: String, chr_id: String, entry: Dictionary) -> bool:
	if chr_id.is_empty() or _sanitize_portrait(entry).is_empty():
		return false
	var profile: Dictionary = load_profile(dir)
	var portraits: Dictionary = profile["portraits"]
	var clean: Dictionary = _sanitize_portrait(entry)
	if portraits.get(chr_id, {}) == clean:
		return false
	portraits[chr_id] = clean
	return save_profile(profile, dir) == OK


## Portraits du jour joué `day` (≤ 0 : toutes les entrées) tirés de
## `memory` (`GameState.case_memory`) : pour chaque personnage
## (`CharacterTableDef`, liste blanche `portrait_cases`), la rencontre la plus
## tardive (jour, index) **remplace** la précédente (dernière rencontre,
## D-191). Une seule écriture ; renvoie vrai si écrit.
static func record_portraits(dir: String, memory: Dictionary, day: int = 0, table: CharacterTableDef = null) -> bool:
	var found: Dictionary = portraits_from_memory(memory, day, table)
	if found.is_empty():
		return false
	var profile: Dictionary = load_profile(dir)
	var portraits: Dictionary = profile["portraits"]
	var changed: bool = false
	for chr_id: Variant in found:
		if portraits.get(chr_id, {}) != found[chr_id]:
			portraits[chr_id] = found[chr_id]
			changed = true
	return save_profile(profile, dir) == OK if changed else false


## Portraits (`{chr_id: entrée}`) d'une mémoire de cas : dernière rencontre
## par personnage (jour, puis index), cas autorisés seulement ; `day` > 0 :
## seulement les cas de ce jour.
static func portraits_from_memory(memory: Dictionary, day: int = 0, table: CharacterTableDef = null) -> Dictionary:
	var result: Dictionary = {}
	var chars: CharacterTableDef = table if table != null else CharacterTableDef.load_default()
	if chars == null:
		return result
	var order: Dictionary = {}
	var keys: Array = memory.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for key: Variant in keys:
		if not memory[key] is Dictionary:
			continue
		var raw: Dictionary = memory[key]
		var case_id: String = str(key)
		if day > 0 and SaveService.as_int(raw.get("day", 0)) != day:
			continue
		var character: CharacterDef = chars.character_of(StringName(case_id))
		if character == null or not character.allows_portrait(StringName(case_id)):
			continue
		var entry: Dictionary = portrait_entry(case_id, raw)
		if entry.is_empty():
			continue
		var rank: int = SaveService.as_int(raw.get("day", 0)) * 1000 + SaveService.as_int(raw.get("index", 0))
		var chr_id: String = String(character.id)
		if not order.has(chr_id) or rank >= int(order[chr_id]):
			order[chr_id] = rank
			result[chr_id] = entry
	return result


## Cinématique vue (`CIN-…` : `cin_f1`…). Renvoie vrai si écrit. `replay`
## (QA-073) : contexte de la séquence vue (`{ending, variant, world, act, day,
## plates, flags}`, voir `cinematic_replays`), remplace le précédent.
static func record_cinematic_seen(dir: String, cinematic_id: String, replay: Dictionary = {}) -> bool:
	if cinematic_id.is_empty():
		return false
	var profile: Dictionary = load_profile(dir)
	var seen: Array = profile["cinematics_seen"]
	var changed: bool = false
	if not seen.has(cinematic_id):
		seen.append(cinematic_id)
		changed = true
	if not replay.is_empty():
		var clean: Dictionary = _sanitize_replay(replay)
		var replays: Dictionary = profile["cinematic_replays"]
		if JSON.stringify(replays.get(cinematic_id, {})) != JSON.stringify(clean):
			replays[cinematic_id] = clean
			changed = true
	if not changed:
		return false
	return save_profile(profile, dir) == OK


## Contexte REVOIR d'une séquence vue (`cinematic_replays`), `{}` si absent.
static func cinematic_replay(profile: Dictionary, cinematic_id: String) -> Dictionary:
	var replays: Variant = profile.get("cinematic_replays", {})
	if not replays is Dictionary or not (replays as Dictionary).has(cinematic_id):
		return {}
	return _sanitize_replay((replays as Dictionary)[cinematic_id])


static func _sanitize_replays(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if not raw is Dictionary:
		return out
	for key: Variant in raw:
		if str(key).is_empty() or not (raw as Dictionary)[key] is Dictionary:
			continue
		out[str(key)] = _sanitize_replay((raw as Dictionary)[key])
	return out


static func _sanitize_replay(raw: Variant) -> Dictionary:
	var row: Dictionary = raw if raw is Dictionary else {}
	var plates: Array = _unique_strings(row.get("plates", []))
	var flags: Dictionary = {}
	var raw_flags: Variant = row.get("flags", {})
	if raw_flags is Dictionary:
		var names: Array = (raw_flags as Dictionary).keys()
		names.sort()
		for name: Variant in names:
			if flags.size() >= REPLAY_MAX_FLAGS or str(name).is_empty():
				break
			var value: Variant = (raw_flags as Dictionary)[name]
			if value is bool:
				flags[str(name)] = value
			elif value is int or value is float:
				flags[str(name)] = SaveService.as_int(value)
			elif value is String or value is StringName:
				flags[str(name)] = str(value)
	return {
		"ending": str(row.get("ending", "")),
		"variant": str(row.get("variant", "")),
		"world": str(row.get("world", "")),
		"act": clampi(SaveService.as_int(row.get("act", 3), 3), 1, 3),
		"day": maxi(SaveService.as_int(row.get("day", 0)), 0),
		"plates": plates.slice(0, REPLAY_MAX_PLATES),
		"flags": flags,
	}


static func has_seen_cinematic(profile: Dictionary, cinematic_id: String) -> bool:
	return (sanitize(profile)["cinematics_seen"] as Array).has(cinematic_id)


## Profil v2 → v3 : `portraits` reconstruits depuis les emplacements, copie
## `profile.v2.bak` (jamais écrasée). Champs inconnus conservés.
static func migrate_v2(raw: Dictionary, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	var backup: String = SaveService.resolve_dir(dir).path_join(V2_BACKUP_FILE)
	if not FileAccess.file_exists(backup):
		SaveService.write_atomic(backup, JSON.stringify(raw, "\t", true))
	var profile: Dictionary = sanitize(raw)
	_rebuild_portraits(profile, dir)
	profile["version"] = VERSION
	save_profile(profile, dir)
	return sanitize(profile)


## Portraits reconstruits depuis la `case_memory` (`current.json`) de chaque
## emplacement lisible, du plus ancien au plus récent (`saved_at`) : la partie
## la plus récente l'emporte ; les portraits déjà présents sont gardés pour
## les personnages absents des emplacements.
static func _rebuild_portraits(profile: Dictionary, dir: String) -> void:
	var table: CharacterTableDef = CharacterTableDef.load_default()
	if table == null:
		return
	var metas: Array = []
	for meta: Dictionary in SaveService.list_slots(dir):
		if not meta.is_empty() and not SaveService.is_damaged(meta):
			metas.append(meta)
	metas.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("saved_at", "")) < str(b.get("saved_at", "")))
	var portraits: Dictionary = profile["portraits"] if profile.get("portraits") is Dictionary else {}
	for meta: Dictionary in metas:
		var current: Dictionary = SaveService.load_current(SaveService.as_int(meta.get("slot", SaveService.NO_SLOT)), dir)
		var memory: Variant = current.get("case_memory", {})
		if not memory is Dictionary:
			continue
		var found: Dictionary = portraits_from_memory(memory, 0, table)
		for chr_id: Variant in found:
			portraits[chr_id] = found[chr_id]
	profile["portraits"] = portraits


# --- Migration v1 → v2 ---------------------------------------------------------------

## Profil v1 → v2 (B51) : `count = 1`, `act` déduit du jour, variante vide ;
## puis lecture des emplacements de `dir` : `max_day_reached` (plus grand
## jour courant), et pour chaque partie terminée variante recalculée depuis
## `current.json`, graine d'épilogue (fins de l'Acte III : profil +
## `day_31.json` + méta `epilogue_available`), `last_campaign` (la plus
## récente). Copie de l'ancien fichier en `profile.v1.bak` (jamais écrasée).
static func migrate_v1(raw: Dictionary, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	var backup: String = SaveService.resolve_dir(dir).path_join(V1_BACKUP_FILE)
	if not FileAccess.file_exists(backup):
		SaveService.write_atomic(backup, JSON.stringify(raw, "\t", true))
	var profile: Dictionary = sanitize(raw)
	var latest_key: String = ""
	var known_flags: Array = []
	for meta: Dictionary in SaveService.list_slots(dir):
		if meta.is_empty() or SaveService.is_damaged(meta):
			continue
		var slot: int = SaveService.as_int(meta.get("slot", SaveService.NO_SLOT))
		profile["max_day_reached"] = maxi(SaveService.as_int(profile["max_day_reached"]),
				SaveService.as_int(meta.get("current_day", 0)))
		if str(meta.get("status", "")) != SaveService.STATUS_ENDED:
			continue
		var current: Dictionary = SaveService.load_current(slot, dir)
		var ending: StringName = StringName(str(meta.get("ending_id", "")))
		if current.is_empty() or not EndingService.ALL_ENDINGS.has(ending):
			continue
		var flags: Dictionary[StringName, Variant] = _flags_of(current)
		known_flags.append(flags)
		var variant: StringName = EpilogueService.variant_of(ending, flags)
		var day: int = maxi(SaveService.as_int(current.get("current_day", 1)), 1)
		var endings: Array = profile["endings_seen"]
		var entry: Dictionary = _find_ending(endings, String(ending), String(variant))
		if entry.is_empty():
			entry = _find_ending(endings, String(ending), "")
			if not entry.is_empty():
				entry["variant"] = String(variant)
		if entry.is_empty():
			endings.append({"id": String(ending), "variant": String(variant), "act": EpilogueService.act_of(flags),
					"day": day, "date": str(meta.get("saved_at", "")), "count": 1,
					"last_date": str(meta.get("saved_at", "")), "first_line_key": ""})
		var memory: Dictionary = current.get("case_memory", {}) if current.get("case_memory") is Dictionary else {}
		var home: Household = Household.from_dict(current.get("household", {}) if current.get("household") is Dictionary else {})
		var epi: Dictionary = EpilogueService.make_seed(ending, flags, home, memory,
				SaveService.as_int(current.get("campaign_seed", 0)), day)
		if not epi.is_empty():
			_store_epilogue(profile, epi)
			if SaveService.load_epilogue(slot, dir).is_empty():
				SaveService.write_epilogue(slot, epi, dir)
		var key: String = str(meta.get("saved_at", ""))
		if latest_key.is_empty() or key > latest_key:
			latest_key = key
			profile["last_campaign"] = {"ending": String(ending), "variant": String(variant),
					"ending_key": String(EpilogueService.ending_key(ending, variant)), "act": EpilogueService.act_of(flags),
					"day": day, "date": key, "campaign_seed": SaveService.as_int(current.get("campaign_seed", 0)),
					"climate": String(EndingService.climate_of(flags)), "traces": [], "world": str(epi.get("world", ""))}
	_infer_from_endings(profile, known_flags)
	_rebuild_portraits(profile, dir)
	profile["version"] = VERSION
	save_profile(profile, dir)
	return sanitize(profile)


## QA-052 : progrès déduit des fins vues du profil v1 lui-même (un joueur 0.11
## qui a supprimé sa partie n'a plus d'emplacement) : `max_day_reached` ≥ jour
## de chaque fin, `epilogue_unlocked` si une fin de l'Acte III (F1–F10) est
## vue, `known_names` appris à toute fin (`known_on_ending`) ou par les
## drapeaux des parties terminées encore présentes (`known_flags`).
static func _infer_from_endings(profile: Dictionary, known_flags: Array) -> void:
	var endings: Array = profile["endings_seen"]
	for entry: Variant in endings:
		if not entry is Dictionary:
			continue
		var row: Dictionary = entry
		var day: int = SaveService.as_int(row.get("day", 0))
		profile["max_day_reached"] = maxi(SaveService.as_int(profile["max_day_reached"]), day)
		var act: int = SaveService.as_int(row.get("act", act_of_day(day)))
		if act == 3 and EndingService.ALL_ENDINGS.has(StringName(str(row.get("id", "")))):
			profile["epilogue_unlocked"] = true
	if endings.is_empty():
		return
	var table: CharacterTableDef = CharacterTableDef.load_default()
	if table == null:
		return
	var known: Array = profile["known_names"]
	var none: Dictionary[StringName, Variant] = {}
	var sources: Array = known_flags.duplicate()
	sources.append(none)
	for item: Variant in sources:
		var flags: Dictionary[StringName, Variant] = item
		for chr_id: String in table.known_names(flags, true):
			if not known.has(chr_id):
				known.append(chr_id)


# --- Outils ---------------------------------------------------------------------------

static func _find_ending(endings: Array, ending_id: String, variant: String) -> Dictionary:
	for entry: Variant in endings:
		if entry is Dictionary and str((entry as Dictionary)["id"]) == ending_id \
				and str((entry as Dictionary).get("variant", "")) == variant:
			return entry
	return {}


static func _unique_strings(value: Variant) -> Array:
	var result: Array = []
	if value is Array or value is PackedStringArray:
		for id: Variant in value:
			if (id is String or id is StringName) and not str(id).is_empty() and not result.has(str(id)):
				result.append(str(id))
	return result


static func _sanitize_epilogues(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var dict: Dictionary = value
	for key: Variant in dict:
		if not dict[key] is Dictionary:
			continue
		var entry: Dictionary = dict[key]
		var lines: Array = []
		if entry.get("last_lines") is Array:
			for line: Variant in entry["last_lines"]:
				lines.append(str(line))
		result[str(key)] = {
			"world": str(entry.get("world", "")),
			"key": str(entry.get("key", "")),
			"seed": entry.get("seed", {}) if entry.get("seed") is Dictionary else {},
			"first_date": str(entry.get("first_date", "")),
			"count": maxi(SaveService.as_int(entry.get("count", 0)), 0),
			"last_date": str(entry.get("last_date", "")),
			"last_lines": lines,
		}
	return result


static func _sanitize_portraits(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var dict: Dictionary = value
	for key: Variant in dict:
		if str(key).is_empty() or not dict[key] is Dictionary:
			continue
		var clean: Dictionary = _sanitize_portrait(dict[key])
		if not clean.is_empty():
			result[str(key)] = clean
	return result


## Portrait aux types attendus ; vide sans apparence.
static func _sanitize_portrait(entry: Dictionary) -> Dictionary:
	var app: Variant = entry.get("appearance", {})
	if not app is Dictionary or (app as Dictionary).is_empty():
		return {}
	var visor: String = str(entry.get("visor", CaseMemory.VISOR_NONE))
	if not CaseMemory.VISOR_STATES.has(visor):
		visor = CaseMemory.VISOR_DOWN
	var day: int = SaveService.as_int(entry.get("day", 0))
	return {"appearance": PassengerAppearance.deserialize(app).serialize(), "visor": visor,
			"case_id": str(entry.get("case_id", "")), "day": day,
			"act": clampi(SaveService.as_int(entry.get("act", act_of_day(day))), 1, 3)}


static func _sanitize_runs(value: Variant) -> Array:
	var runs: Array = []
	if not value is Array:
		return runs
	for entry: Variant in value:
		if not entry is Dictionary:
			continue
		var row: Dictionary = entry
		runs.append({"score": SaveService.as_int(row.get("score", 0)), "seed_code": str(row.get("seed_code", "")),
				"kind": str(row.get("kind", "free")), "date": str(row.get("date", "")),
				"garde_version": SaveService.as_int(row.get("garde_version", 1), 1),
				"duration_sec": SaveService.as_int(row.get("duration_sec", 0)),
				"directives": SaveService.as_int(row.get("directives", 0)), "palier": SaveService.as_int(row.get("palier", 0))})
	runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return runs.slice(0, TOP_RUNS)


static func _sanitize_daily(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not value is Dictionary:
		return result
	var dict: Dictionary = value
	for key: Variant in dict:
		if dict[key] is Dictionary:
			var entry: Dictionary = dict[key]
			result[str(key)] = {"best": SaveService.as_int(entry.get("best", 0)),
					"first_try": SaveService.as_int(entry.get("first_try", 0)),
					"attempts": SaveService.as_int(entry.get("attempts", 0)),
					"garde_version": SaveService.as_int(entry.get("garde_version", 1), 1)}
	return result


## Drapeaux narratifs d'un état sauvegardé (nombres JSON entiers redevenus `int`).
static func _flags_of(state: Dictionary) -> Dictionary[StringName, Variant]:
	var flags: Dictionary[StringName, Variant] = {}
	var raw: Variant = state.get("narrative_flags", {})
	if raw is Dictionary:
		var dict: Dictionary = raw
		for key: Variant in dict:
			flags[StringName(str(key))] = EpilogueService.json_value(dict[key])
	return flags


static func _now() -> String:
	return Time.get_datetime_string_from_system(true)


static func _today() -> String:
	return Time.get_date_string_from_system(true)


static func _is_true(value: Variant) -> bool:
	return value is bool and value
