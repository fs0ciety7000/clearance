## Garde de nuit « Endurance » (M12 §2, D-126 → D-128, B57 ; ARCHITECTURE
## §11.5) — service statique pur : graines, ordre des directives, date de
## jeu, jour de shift, accès, records.
##
## - **Graines** (D-127) : graine du jour `NUIT-AAAA-MM-JJ` (date **UTC**) ;
##   code libre de 6 symboles de l'alphabet des N° ID (A–Z, 2–9, sans O, I, 0,
##   1 : 32 symboles, 30 bits), affiché `K2Q-9TX`, saisi sans casse ni tiret.
##   Graine = FNV-1a 64 du code canonique, tronquée à 53 bits (D-119).
## - **Flux séparés** (`stream_seed`) : `order` (directives), `queue`
##   (passagers), `events`, `notices` (avis, révocations), `date`. Les
##   verdicts du joueur n'influencent aucun tirage.
## - **Ordre des directives** (`directive_plan`) : tiers débloqués par numéro
##   de directive (`GardeDef.tier_unlock_directive`), prérequis actifs, tirage
##   uniforme ; tier supérieur si rien n'est éligible ; pool épuisé →
##   rotation M1 (une directive retire une unité de tier 1 ou 2, la suivante
##   la rétablit).
class_name GardeService
extends RefCounted

const DEF_PATH: String = "res://data/garde/garde.tres"
## Alphabet des N° ID (LORE §5) : A–Z et 2–9 sans O, I, 0, 1.
const ID_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const CODE_LENGTH: int = 6
const DAILY_PREFIX: String = "NUIT-"
const KIND_DAILY: StringName = &"daily"
const KIND_FREE: StringName = &"free"
const JSON_SAFE_MASK: int = 0x1FFFFFFFFFFFFF
const ACTION_ADD: StringName = &"add"
const ACTION_RETIRE: StringName = &"retire"
const ACTION_RESTORE: StringName = &"restore"
## Accès (D-128) : premier jour terminé dans n'importe quelle partie.
const UNLOCK_MAX_DAY: int = 2
## Raisons d'un code refusé (`normalize_code` : `error_key` = clé i18n du
## message, `reason` = identifiant stable ; QA-055).
const ERROR_INVALID_CHARS: String = "garde_seed_invalid"       # O, I, 0 ou 1
const ERROR_BAD_LENGTH: String = "garde_seed_input"            # code libre ≠ 6 symboles
const ERROR_BAD_DATE: String = "garde_seed_bad_date"           # NUIT-… : pas une vraie date
const ERROR_BAD_CHAR: String = "garde_seed_bad_char"           # caractère hors alphabet (accent, ponctuation)
const REASON_NONE: StringName = &""
const REASON_INVALID_CHARS: StringName = &"invalid_chars"
const REASON_LENGTH: StringName = &"length"
const REASON_DATE: StringName = &"date"
const REASON_CHAR: StringName = &"char"

static var _def_cache: GardeDef = null


static func load_def() -> GardeDef:
	if _def_cache == null and ResourceLoader.exists(DEF_PATH):
		_def_cache = load(DEF_PATH) as GardeDef
	return _def_cache


# --- Graines ---------------------------------------------------------------------

## FNV-1a 64 tronqué à 53 bits (exact en JSON).
static func seed53(text: String) -> int:
	return SeededRng.hash_string(text) & JSON_SAFE_MASK


## Code de la graine du jour d'un instant Unix (date UTC).
static func daily_code(unix_time: int) -> String:
	var date: Dictionary = Time.get_date_dict_from_unix_time(unix_time)
	return "%s%04d-%02d-%02d" % [DAILY_PREFIX, int(date["year"]), int(date["month"]), int(date["day"])]


static func today_code() -> String:
	return daily_code(int(Time.get_unix_time_from_system()))


## Date `AAAA-MM-JJ` d'un code du jour, vide pour un code libre.
static func daily_date(code: String) -> String:
	return code.trim_prefix(DAILY_PREFIX) if code.begins_with(DAILY_PREFIX) else ""


## Code canonique d'une saisie : `{ok, code, kind, error_key, reason}`.
## Accepte un code du jour (`NUIT-AAAA-MM-JJ`, vraie date du calendrier) ou un
## code libre (casse, espaces et tiret indifférents). Refus (QA-055) :
## `ERROR_BAD_DATE` (`reason` `date` : préfixe `NUIT-` sans date réelle),
## `ERROR_INVALID_CHARS` (`invalid_chars` : O, I, 0, 1), `ERROR_BAD_CHAR`
## (`char` : autre caractère hors alphabet), `ERROR_BAD_LENGTH` (`length`).
static func normalize_code(text: String) -> Dictionary:
	var raw: String = text.strip_edges().to_upper()
	if raw.begins_with(DAILY_PREFIX):
		var parts: PackedStringArray = raw.trim_prefix(DAILY_PREFIX).split("-")
		if parts.size() == 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int():
			var year: int = parts[0].to_int()
			var month: int = parts[1].to_int()
			var day: int = parts[2].to_int()
			if year >= 2000 and month >= 1 and month <= 12 and day >= 1 and day <= days_in_month(year, month):
				return _code_result(true, "%s%04d-%02d-%02d" % [DAILY_PREFIX, year, month, day], KIND_DAILY, "", REASON_NONE)
		return _code_result(false, "", KIND_DAILY, ERROR_BAD_DATE, REASON_DATE)
	var compact: String = raw.replace("-", "").replace(" ", "")
	for character: String in compact:
		if character in ["O", "I", "0", "1"]:
			return _code_result(false, "", KIND_FREE, ERROR_INVALID_CHARS, REASON_INVALID_CHARS)
	for character: String in compact:
		if not ID_ALPHABET.contains(character):
			return _code_result(false, "", KIND_FREE, ERROR_BAD_CHAR, REASON_CHAR)
	if compact.length() != CODE_LENGTH:
		return _code_result(false, "", KIND_FREE, ERROR_BAD_LENGTH, REASON_LENGTH)
	return _code_result(true, "%s-%s" % [compact.substr(0, 3), compact.substr(3)], KIND_FREE, "", REASON_NONE)


static func _code_result(ok: bool, code: String, kind: StringName, error_key: String, reason: StringName) -> Dictionary:
	return {"ok": ok, "code": code, "kind": kind, "error_key": error_key, "reason": reason}


## Nombre de jours d'un mois du calendrier grégorien.
static func days_in_month(year: int, month: int) -> int:
	match month:
		2:
			var leap: bool = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
			return 29 if leap else 28
		4, 6, 9, 11:
			return 30
	return 31


## Code libre de 30 bits (`bits` & 0x3FFFFFFF), 6 symboles, tiret décoratif.
static func code_from_bits(bits: int) -> String:
	var value: int = bits & 0x3FFFFFFF
	var symbols: String = ""
	for i: int in CODE_LENGTH:
		symbols = ID_ALPHABET[value & 31] + symbols
		value >>= 5
	return "%s-%s" % [symbols.substr(0, 3), symbols.substr(3)]


## Valeur 30 bits d'un code libre canonique (−1 si invalide).
static func bits_of(code: String) -> int:
	var normalized: Dictionary = normalize_code(code)
	if not normalized["ok"] or normalized["kind"] != KIND_FREE:
		return -1
	var value: int = 0
	for character: String in str(normalized["code"]).replace("-", ""):
		value = (value << 5) | ID_ALPHABET.find(character)
	return value


## Code libre au hasard (seul tirage non déterministe de la Garde, au choix
## « GRAINE LIBRE ») ; `entropy` ≠ 0 pour un tirage reproductible.
static func random_code(entropy: int = 0) -> String:
	var value: int = entropy
	if value == 0:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		value = rng.randi()
	return code_from_bits(SeededRng.avalanche(value))


## Graine d'un code (canonique ou saisi) ; 0 si invalide.
static func seed_of(code: String) -> int:
	var normalized: Dictionary = normalize_code(code)
	if not normalized["ok"]:
		return 0
	return seed53(str(normalized["code"]))


## Graine d'un flux (`order`, `queue`, `events`, `notices`, `date`).
static func stream_seed(garde_seed: int, stream: StringName) -> int:
	return SeededRng.mix_string(garde_seed, "garde_" + String(stream))


# --- Accès -------------------------------------------------------------------------

## Garde accessible (D-128) : `max_day_reached ≥ 2` au profil.
static func is_unlocked(profile: Dictionary) -> bool:
	return SaveService.as_int(profile.get("max_day_reached", 0)) >= UNLOCK_MAX_DAY


# --- Directives -----------------------------------------------------------------------

## Tier maximal ouvert à la directive `number` (1-based).
static func tier_cap(def: GardeDef, number: int) -> int:
	var cap: int = 1
	for i: int in def.tier_unlock_directive.size():
		if number >= def.tier_unlock_directive[i]:
			cap = i + 1
	return cap


## Les `count` premières directives d'une graine : `{number, unit_id, action}`
## (`add` / `retire` / `restore`). Fonction pure de la graine et des données.
static func directive_plan(def: GardeDef, garde_seed: int, count: int) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	if def == null:
		return plan
	var rng: SeededRng = SeededRng.new(stream_seed(garde_seed, &"order"))
	var active: Array[StringName] = []
	var remaining: Array[GardeUnitDef] = []
	for unit: GardeUnitDef in def.units:
		if unit != null:
			remaining.append(unit)
	var retired: StringName = &""
	for number: int in range(1, count + 1):
		var unit: GardeUnitDef = _pick_unit(def, remaining, active, number, rng)
		if unit != null:
			remaining.erase(unit)
			active.append(unit.id)
			plan.append({"number": number, "unit_id": unit.id, "action": ACTION_ADD})
			continue
		# Rotation (pool épuisé) : retrait, puis rétablissement.
		if retired != &"":
			plan.append({"number": number, "unit_id": retired, "action": ACTION_RESTORE})
			active.append(retired)
			retired = &""
			continue
		var candidates: Array[StringName] = []
		for unit_id: StringName in active:
			var candidate: GardeUnitDef = def.get_unit(unit_id)
			if candidate != null and candidate.tier <= 2 and not _is_prerequisite(def, unit_id, active):
				candidates.append(unit_id)
		if candidates.is_empty():
			break
		retired = candidates[rng.randi_range(0, candidates.size() - 1)]
		active.erase(retired)
		plan.append({"number": number, "unit_id": retired, "action": ACTION_RETIRE})
	return plan


static func _pick_unit(def: GardeDef, remaining: Array[GardeUnitDef], active: Array[StringName], number: int,
		rng: SeededRng) -> GardeUnitDef:
	var cap: int = tier_cap(def, number)
	while cap <= 3:
		var eligible: Array[GardeUnitDef] = []
		for unit: GardeUnitDef in remaining:
			if unit.tier <= cap and _prerequisites_met(unit, active):
				eligible.append(unit)
		if not eligible.is_empty():
			return eligible[rng.randi_range(0, eligible.size() - 1)]
		cap += 1
	return null


static func _prerequisites_met(unit: GardeUnitDef, active: Array[StringName]) -> bool:
	for prerequisite: StringName in unit.prerequisites:
		if not active.has(prerequisite):
			return false
	return true


## Vrai si une unité active dépend de `unit_id`.
static func _is_prerequisite(def: GardeDef, unit_id: StringName, active: Array[StringName]) -> bool:
	for other_id: StringName in active:
		var other: GardeUnitDef = def.get_unit(other_id)
		if other != null and other.prerequisites.has(unit_id):
			return true
	return false


## Changements de règles d'une directive (`add` : règles de l'unité, badge
## NOUVEAU ; `retire` : lignes barrées au motif de rotation ; `restore`).
static func directive_changes(def: GardeDef, entry: Dictionary) -> Array[RuleChangeDef]:
	var changes: Array[RuleChangeDef] = []
	var unit: GardeUnitDef = def.get_unit(StringName(entry.get("unit_id", &"")))
	if unit == null:
		return changes
	for rule: Rule in unit.rules:
		if rule == null:
			continue
		match StringName(entry.get("action", ACTION_ADD)):
			ACTION_ADD:
				# M13 (U24) : un palier de R43 (même identifiant) remplace le
				# palier en vigueur, à sa place (`RuleChangeDef.replace`).
				if rule is StatementsConsistentRule and (rule as StatementsConsistentRule).tier > 1:
					changes.append(RuleChangeDef.replace(rule, true))
				else:
					changes.append(RuleChangeDef.add(rule, true))
			ACTION_RETIRE:
				changes.append(RuleChangeDef.retire(rule.id, def.rotation_note_key))
			ACTION_RESTORE:
				changes.append(RuleChangeDef.restore(rule.id))
	return changes


# --- Shift ----------------------------------------------------------------------------

## Date de jeu tirée de la graine entre `date_min` et `date_max` (inclus).
static func game_date_for(def: GardeDef, garde_seed: int) -> int:
	if def.date_max <= def.date_min:
		return def.date_min
	var rng: SeededRng = SeededRng.new(stream_seed(garde_seed, &"date"))
	return def.date_min + rng.randi_range(0, def.date_max - def.date_min)


## Jour de shift de la garde : copie du gabarit (RuleSet de shift = socle),
## date de la graine, paramètres du palier 0.
static func make_day(def: GardeDef, run: GardeRun) -> DayDef:
	var template: DayDef = def.day_template if def.day_template != null else DayDef.new()
	var day: DayDef = template.make_shift_copy()
	day.mode = DayDef.MODE_GARDE
	day.untimed = true
	day.economy_disabled = true
	day.game_date = run.game_date
	apply_tier(day, def.tier_for(1))
	return day


## Recopie les paramètres d'un palier dans le jour de shift.
static func apply_tier(day: DayDef, tier: GardeTierDef) -> void:
	if day == null or tier == null:
		return
	day.anomaly_count_weights = tier.anomaly_count_weights
	day.subtle_rate = tier.subtle_rate
	day.legit_noise_rate = tier.legit_noise_rate
	day.visor_down_rate = tier.visor_down_rate


## Nouvelle garde sur un code (canonique ou saisi) ; null si le code ou les
## données sont invalides. `events` : catalogue des événements (null = données).
static func new_run(code: String, def: GardeDef = null, events: StationEventsDef = null) -> GardeRun:
	var source: GardeDef = def if def != null else load_def()
	var normalized: Dictionary = normalize_code(code)
	if source == null or not normalized["ok"]:
		return null
	var run: GardeRun = GardeRun.new()
	run.setup(source, str(normalized["code"]), StringName(normalized["kind"]),
			events if events != null else StationEventService.load_def())
	return run


## Inscrit une garde terminée au profil ; renvoie les pastilles
## (`ProfileService.record_garde`).
static func record_run(run: GardeRun, dir: String = SaveService.DEFAULT_DIR) -> Dictionary:
	if run == null:
		return {}
	return ProfileService.record_garde(dir, run.to_record())
