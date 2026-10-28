## Fabrique de documents **valides** (ARCHITECTURE §9.2 étape 3) — pure.
##
## Chaque champ est rempli via `FieldDef.truth_path` (même logique que la
## fabrique de test M2 `tests/helpers/case_factory.gd`) ; dates d'émission et
## d'expiration cohérentes avec `today` et `validity_days` ; émetteur et sceau
## légitimes (recopiés du type) ; numéro selon `serial_pattern`. Un champ
## `PORTRAIT` reçoit une photo de la **même apparence** que le titulaire
## (coiffe et accessoire retirés, règle de photo officielle, BOOTH_SCENE §12.6),
## éventuellement avec du bruit légitime (coupe différente, photo plus ancienne).
class_name DocumentFactory
extends RefCounted

## Âge minimal à l'émission d'une carte d'identité.
const ID_CARD_MIN_AGE: int = 16
## Ancienneté maximale d'émission d'un document à durée courte (permis).
const MAX_ISSUE_AGE_SHORT: int = 60
## Durée au-delà de laquelle un document est « long » (carte d'identité).
const LONG_VALIDITY: int = 365
## Ancienneté de la photo par rapport à l'émission (années).
const PHOTO_YEARS: Vector2i = Vector2i(0, 2)
const PHOTO_YEARS_OLD: Vector2i = Vector2i(4, 8)
const DIGITS: String = "0123456789"


## Document valide de type `def` pour le passager `p`.
## `min_remaining_days` : jours de validité restants au minimum (≥ 1).
static func create(def: DocumentTypeDef, p: Passenger, today: int, rng: SeededRng,
		appearance_gen: AppearanceGenerator, photo_noise: bool = false, min_remaining_days: int = 1) -> DocumentInstance:
	var doc: DocumentInstance = DocumentInstance.new(def)
	_fill_dates(doc, def, p, today, rng, min_remaining_days)
	for field: FieldDef in def.fields:
		if field.is_document_level():
			continue
		if field.kind == FieldDef.FieldKind.PORTRAIT:
			doc.values[field.id] = make_photo(p, rng, appearance_gen, photo_noise)
		else:
			var value: Variant = p.get_truth(field.truth_path)
			if value is PackedStringArray:
				var list: PackedStringArray = value
				value = list.duplicate()
			doc.values[field.id] = value
	doc.serial = make_serial(def.serial_pattern, rng, doc.issue_date, p)
	return doc


## Photo officielle du titulaire : même identité, sans coiffe ni accessoire ;
## bruit légitime éventuel (coupe différente et/ou photo ancienne, `age_band` −1).
static func make_photo(p: Passenger, rng: SeededRng, appearance_gen: AppearanceGenerator, noise: bool) -> PortraitValue:
	var photo: PassengerAppearance = official_photo_of(p.appearance)
	var years: int = rng.randi_range(PHOTO_YEARS.x, PHOTO_YEARS.y)
	if noise:
		var hair_change: bool = rng.chance(0.6)
		var older: bool = not hair_change or rng.chance(0.4)
		if hair_change and appearance_gen != null:
			photo.traits[PassengerAppearance.SLOT_HAIR] = appearance_gen.reroll_slot(rng, photo, PassengerAppearance.SLOT_HAIR, p.faction_id)
		if older:
			years = rng.randi_range(PHOTO_YEARS_OLD.x, PHOTO_YEARS_OLD.y)
			photo.age_band = maxi(photo.age_band - 1, 0)
	return PortraitValue.new(photo, rng.next_u32(), years)


## Apparence telle que photographiée : coiffe et accessoire retirés.
static func official_photo_of(app: PassengerAppearance) -> PassengerAppearance:
	var photo: PassengerAppearance = app.copy()
	if photo.traits.has(PassengerAppearance.SLOT_HEADWEAR):
		photo.traits[PassengerAppearance.SLOT_HEADWEAR] = PassengerAppearance.OPTION_NONE
	if photo.traits.has(PassengerAppearance.SLOT_ACCESSORY):
		photo.traits[PassengerAppearance.SLOT_ACCESSORY] = PassengerAppearance.OPTION_NONE
	return photo


## Numéro selon le motif : `YYYY` année d'émission, `N` chiffre, `X` caractère
## sûr ; un motif `HG-…` (carte d'identité) reprend le N° ID du titulaire.
static func make_serial(pattern: String, rng: SeededRng, issue_date: int, p: Passenger) -> String:
	if pattern.begins_with(PassengerGenerator.ID_PREFIX):
		return p.citizen_id
	var text: String = pattern.replace("YYYY", "%04d" % GameDate.year_of(issue_date))
	var result: String = ""
	for i: int in text.length():
		var c: String = text[i]
		match c:
			"N", "#":
				result += DIGITS[rng.randi_range(0, 9)]
			"X":
				result += PassengerGenerator.ID_SAFE_CHARS[rng.randi_range(0, PassengerGenerator.ID_SAFE_CHARS.length() - 1)]
			_:
				result += c
	return result


static func _fill_dates(doc: DocumentInstance, def: DocumentTypeDef, p: Passenger, today: int,
		rng: SeededRng, min_remaining_days: int) -> void:
	var lo: int = maxi(def.validity_days.x, 1)
	var hi: int = maxi(def.validity_days.y, lo)
	var margin: int = clampi(min_remaining_days, 1, hi - 1) if hi > 1 else 1
	var duration: int = rng.randi_range(clampi(margin + 1, lo, hi), hi)
	var max_age: int = maxi(duration - margin, 0)
	if hi <= LONG_VALIDITY:
		max_age = mini(max_age, MAX_ISSUE_AGE_SHORT)
	var issue: int = today - rng.randi_range(0, max_age)
	if hi > LONG_VALIDITY:
		# Carte d'identité : émise après les 16 ans du titulaire.
		issue = maxi(issue, GameDate.add_years(GameDate.latest_day(p.birth_date), ID_CARD_MIN_AGE))
		issue = mini(issue, today)
	doc.issue_date = issue
	doc.expiry_date = issue + duration
