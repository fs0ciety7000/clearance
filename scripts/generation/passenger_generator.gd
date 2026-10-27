## Générateur de passagers « vrais » (ARCHITECTURE §9.2 étape 2) — pur.
##
## Identité cohérente avec l'origine (LORE §4–§5) : nom tiré du `NamePool`
## (jamais un nom réservé), N° ID `HG-NNNN-XXXX` dont le 1ᵉʳ chiffre encode
## l'origine, date de naissance cohérente avec la tranche d'âge apparent de
## l'apparence du roster, classe citoyenne, motif, durée et employeur pondérés
## par l'origine. Les surcharges d'un cas scénarisé sont appliquées en dernier
## (le sexe et l'origine, eux, sont lus avant le tirage des noms).
class_name PassengerGenerator
extends RefCounted

## `XXXX` du N° ID : alphanumérique sans `O`, `I`, `0`, `1` (LORE §5).
const ID_SAFE_CHARS: String = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
const ID_PREFIX: String = "HG-"
const SEXES: Array[StringName] = [Passenger.SEX_F, Passenger.SEX_M, Passenger.SEX_X]
const SEX_WEIGHTS: PackedFloat32Array = [0.48, 0.48, 0.04]
## Âges révolus (min, max) de chaque tranche d'âge apparent.
const AGE_BANDS: Array[Vector2i] = [Vector2i(18, 29), Vector2i(30, 54), Vector2i(55, 79)]
## Durée de séjour (jours) : classe `C-4` ≤ 30 (R09, GDD §7).
const STAY_SHORT: Vector2i = Vector2i(3, 30)
const STAY_RETURN: Vector2i = Vector2i(1, 14)
const STAY_DEFAULT: Vector2i = Vector2i(7, 90)
const SHORT_STAY_CLASS: StringName = &"C-4"
const DEFAULT_CLASS: StringName = &"C-3"


## Passager vrai pour l'entrée `entry` du roster (origine et apparence).
static func generate(rng: SeededRng, faction: FactionDef, today: int, entry: AppearanceRoster.Entry,
		overrides: Dictionary = {}, passenger_id: StringName = &"") -> Passenger:
	var p: Passenger = Passenger.new()
	p.id = passenger_id
	p.faction_id = faction.id
	p.appearance = entry.appearance.copy()
	p.appearance_seed = entry.appearance_seed
	var sex: Variant = overrides.get(&"sex", null)
	p.sex = StringName(str(sex)) if sex != null else _weighted(rng, SEXES, SEX_WEIGHTS, Passenger.SEX_X)
	draw_identity(rng, faction, today, p)
	p.citizen_class = _weighted_dict(rng, faction.citizen_class_weights, DEFAULT_CLASS)
	p.purpose = _weighted_dict(rng, faction.purpose_weights, Passenger.PURPOSE_WORK)
	p.stay_days = _stay_days(rng, p)
	p.employer = faction.employers[rng.randi_range(0, faction.employers.size() - 1)] if not faction.employers.is_empty() else ""
	p.origin_sector = faction.origin_sectors[rng.randi_range(0, faction.origin_sectors.size() - 1)] if not faction.origin_sectors.is_empty() else ""
	p.health_status = Passenger.HEALTH_FIT
	if not overrides.is_empty():
		var rejected: PackedStringArray = p.apply_overrides(overrides)
		if not rejected.is_empty():
			push_error("PassengerGenerator: surcharges refusées %s" % [rejected])
	return p


## (Re)tire l'identité civile de `p` : prénom, nom, naissance (selon
## `p.appearance.age_band`) et N° ID. Sert aussi à l'usurpateur d'un
## `IMPOSTOR_LOOKALIKE` (vraie identité ≠ identité des papiers).
static func draw_identity(rng: SeededRng, faction: FactionDef, today: int, p: Passenger) -> void:
	var pool: NamePool = faction.name_pool
	if pool == null:
		push_error("PassengerGenerator: origine « %s » sans NamePool" % faction.id)
	else:
		p.given_name = pool.pick_given_name(rng, p.sex)
		p.family_name = pool.pick_family_name(rng)
	var band: int = p.appearance.age_band if p.appearance != null else 1
	p.birth_date = birth_date_for_band(rng, band, today)
	p.citizen_id = make_citizen_id(rng, faction)


## N° ID `HG-#NNN-XXXX` : `#` = chiffre d'origine, `NNN` chiffres, `XXXX` sûrs.
static func make_citizen_id(rng: SeededRng, faction: FactionDef) -> String:
	var digits: String = ""
	for i: int in 3:
		digits += str(rng.randi_range(0, 9))
	var tail: String = ""
	for i: int in 4:
		tail += ID_SAFE_CHARS[rng.randi_range(0, ID_SAFE_CHARS.length() - 1)]
	return "%s%s-%s" % [faction.id_prefix, digits, tail]


## Vrai si `citizen_id` respecte `HG-NNNN-XXXX` (LORE §5 ; origine non vérifiée).
static func is_valid_citizen_id_format(citizen_id: String) -> bool:
	if citizen_id.length() != 12 or not citizen_id.begins_with(ID_PREFIX) or citizen_id[7] != "-":
		return false
	for i: int in range(3, 7):
		if not "0123456789".contains(citizen_id[i]):
			return false
	for i: int in range(8, 12):
		if not ID_SAFE_CHARS.contains(citizen_id[i]):
			return false
	return true


## Tranche d'âge apparent d'un âge révolu (bornes de `AGE_BANDS`).
static func age_band_for_age(age: int) -> int:
	for band: int in AGE_BANDS.size():
		if age <= AGE_BANDS[band].y:
			return band
	return AGE_BANDS.size() - 1


## Date de naissance donnant un âge révolu dans la tranche, au jour `today`.
static func birth_date_for_band(rng: SeededRng, band: int, today: int) -> int:
	var ages: Vector2i = AGE_BANDS[clampi(band, 0, AGE_BANDS.size() - 1)]
	var age: int = rng.randi_range(ages.x, ages.y)
	# Entre « anniversaire aujourd'hui » et la veille de l'anniversaire suivant.
	return GameDate.add_years(today, -age) - rng.randi_range(0, 364)


static func _stay_days(rng: SeededRng, p: Passenger) -> int:
	var range_days: Vector2i = STAY_DEFAULT
	if p.citizen_class == SHORT_STAY_CLASS:
		range_days = STAY_SHORT
	elif p.purpose == Passenger.PURPOSE_RETURN:
		range_days = STAY_RETURN
	return rng.randi_range(range_days.x, range_days.y)


static func _weighted(rng: SeededRng, items: Array[StringName], weights: PackedFloat32Array, fallback: StringName) -> StringName:
	var index: int = rng.weighted_index(weights)
	return items[index] if index >= 0 else fallback


static func _weighted_dict(rng: SeededRng, table: Dictionary[StringName, float], fallback: StringName) -> StringName:
	if table.is_empty():
		return fallback
	var keys: Array[StringName] = []
	keys.assign(table.keys())
	var weights: PackedFloat32Array = []
	for key: StringName in keys:
		weights.append(table[key])
	return _weighted(rng, keys, weights, fallback)
