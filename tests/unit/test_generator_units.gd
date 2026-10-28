## Briques du générateur (M3) : données (réserves de noms, origines, cas
## scénarisés), `NamePool`, `PassengerGenerator`, `DocumentFactory`.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const ALLOWED_PARAMS: Array[StringName] = [&"document_id", &"expired_days", &"trait_count", &"char_count",
		&"field_path", &"photo_noise",
		# M7 : injecteurs (motif, implants, parent, origine interdite, MRZ) et codes Lucioles.
		&"employer", &"implant", &"relative_given_name", &"relative_birth", &"purpose", &"component", &"mrz_value",
		&"mrz_issuer", &"permit_suffix", &"mark_document_id"]


func test_catalog_loads_name_pools_and_appearance_catalog() -> void:
	var data: DataCatalog = Gen.data()
	assert_eq(data.errors, PackedStringArray())
	assert_eq(data.name_pools.size(), 6)
	assert_not_null(data.appearance_catalog)


func test_name_pools_follow_lore() -> void:
	for faction: FactionDef in Gen.data().factions.values():
		var pool: NamePool = faction.name_pool
		assert_not_null(pool, String(faction.id))
		if pool == null:
			continue
		assert_eq(pool.id, faction.id)
		assert_same(pool, Gen.data().name_pools[faction.id], "ressource partagée")
		assert_eq(pool.all_given_names().size(), 15, "LORE §5 : 15 prénoms (%s)" % faction.id)
		assert_eq(pool.family_names.size(), 15, "LORE §5 : 15 noms (%s)" % faction.id)
		for given: String in pool.given_names_f:
			assert_false(pool.given_names_m.has(given) or pool.given_names_x.has(given), given)
	var ter: NamePool = Gen.data().name_pools[&"ter"]
	assert_true(ter.family_names.has("Okonkwo"), "Okonkwo reste au LORE…")
	assert_true(ter.is_reserved("Okonkwo"))
	assert_false(ter.get_family_names().has("Okonkwo"), "…mais n'est jamais tiré")
	assert_eq(ter.get_family_names().size(), 14)


func test_name_pool_filters_by_sex() -> void:
	var hal: NamePool = Gen.data().name_pools[&"hal"]
	var f: PackedStringArray = hal.given_names_for(Passenger.SEX_F)
	var m: PackedStringArray = hal.given_names_for(Passenger.SEX_M)
	assert_true(f.has("Céleste") and f.has("Lin") and not f.has("Hiro"))
	assert_true(m.has("Hiro") and m.has("Lin") and not m.has("Céleste"))
	assert_eq(hal.given_names_for(Passenger.SEX_X).size(), 15)
	var rng: SeededRng = SeededRng.new(5)
	for i: int in 200:
		assert_ne(Gen.data().name_pools[&"ter"].pick_family_name(rng), "Okonkwo")


func test_factions_generator_fields() -> void:
	var purposes: Array[StringName] = [Passenger.PURPOSE_WORK, Passenger.PURPOSE_FAMILY_VISIT, Passenger.PURPOSE_RETURN,
			Passenger.PURPOSE_TRADE, Passenger.PURPOSE_TRANSIT, Passenger.PURPOSE_DIPLOMATIC]
	for faction: FactionDef in Gen.data().factions.values():
		var label: String = String(faction.id)
		assert_almost_eq(_sum(faction.citizen_class_weights.values()), 1.0, 0.001, label)
		assert_almost_eq(_sum(faction.purpose_weights.values()), 1.0, 0.001, label)
		for purpose: StringName in faction.purpose_weights:
			assert_true(purposes.has(purpose), label + " motif " + String(purpose))
		for citizen_class: StringName in faction.citizen_class_weights:
			assert_true(String(citizen_class).begins_with("C-"), label)
		assert_gt(faction.employers.size(), 0, label)


func test_scripted_injection_params_are_valid() -> void:
	for day: DayDef in Gen.data().days.values():
		for scripted: ScriptedCaseDef in day.scripted_cases:
			for key: Variant in scripted.injection_params:
				assert_true(ALLOWED_PARAMS.has(StringName(str(key))), "%s : %s" % [scripted.id, key])
			var document_id: Variant = scripted.injection_params.get(&"document_id", null)
			if document_id != null:
				assert_true(day.rule_set.required_document_ids.has(StringName(str(document_id))), String(scripted.id))


func test_citizen_id_format() -> void:
	assert_true(PassengerGenerator.is_valid_citizen_id_format("HG-4471-K2Q9"), "canon LORE")
	for bad: String in ["HG-4471-K2O9", "HG-4471-K2Q1", "HG-447-K2Q9X", "HX-4471-K2Q9", "HG-44A1-K2Q9", "HG-4471K2Q99", ""]:
		assert_false(PassengerGenerator.is_valid_citizen_id_format(bad), bad)
	var rng: SeededRng = SeededRng.new(11)
	for faction: FactionDef in Gen.data().factions.values():
		for i: int in 100:
			var id: String = PassengerGenerator.make_citizen_id(rng, faction)
			assert_true(PassengerGenerator.is_valid_citizen_id_format(id) and faction.matches_citizen_id(id), id)


func test_birth_dates_fall_in_age_band() -> void:
	assert_eq(PassengerGenerator.age_band_for_age(18), 0)
	assert_eq(PassengerGenerator.age_band_for_age(29), 0)
	assert_eq(PassengerGenerator.age_band_for_age(30), 1)
	assert_eq(PassengerGenerator.age_band_for_age(54), 1)
	assert_eq(PassengerGenerator.age_band_for_age(55), 2)
	var rng: SeededRng = SeededRng.new(2)
	# 29.02 et 01.03 d'une année bissextile, et un jour ordinaire.
	for today: int in [GameDate.from_ymd(2188, 2, 29), GameDate.from_ymd(2188, 3, 1), GameDate.from_ymd(2187, 3, 15)]:
		for i: int in 300:
			var band: int = i % 3
			var age: int = GameDate.age_on(PassengerGenerator.birth_date_for_band(rng, band, today), today)
			assert_eq(PassengerGenerator.age_band_for_age(age), band, "âge %d" % age)


func test_document_factory_builds_valid_documents() -> void:
	var data: DataCatalog = Gen.data()
	var gen: AppearanceGenerator = AppearanceGenerator.new(data.appearance_catalog)
	var today: int = GameDate.from_ymd(2187, 3, 15)
	var rng: SeededRng = SeededRng.new(77)
	var entry: AppearanceRoster.Entry = AppearanceRoster.Entry.new()
	for i: int in 100:
		entry.appearance = gen.generate(rng, &"tyc").derive({PassengerAppearance.SLOT_HEADWEAR: &"cap"})
		var p: Passenger = PassengerGenerator.generate(rng, data.factions[&"tyc"], today, entry)
		var card: DocumentInstance = DocumentFactory.create(data.documents[&"id_card"], p, today, rng, gen)
		var permit: DocumentInstance = DocumentFactory.create(data.documents[&"entry_permit"], p, today, rng, gen, false, p.stay_days)
		var bioscan: DocumentInstance = DocumentFactory.create(data.documents[&"bioscan"], p, today, rng, gen)
		assert_eq(card.serial, p.citizen_id)
		assert_true(permit.serial.begins_with("PE-%04d-" % GameDate.year_of(permit.issue_date)) and permit.serial.length() == 13, permit.serial)
		assert_true(bioscan.serial.begins_with("BS-") and bioscan.serial.length() == 8, bioscan.serial)
		for doc: DocumentInstance in [card, permit, bioscan]:
			assert_true(doc.issue_date <= today and doc.expiry_date >= today, String(doc.get_document_id()))
			var span: int = doc.expiry_date - doc.issue_date
			assert_between(span, doc.type_def.validity_days.x, doc.type_def.validity_days.y)
			assert_eq(doc.issuer_id, doc.type_def.issuer_id)
			assert_eq(doc.seal_id, doc.type_def.seal_id)
		assert_gte(permit.expiry_date - today, p.stay_days, "permis valide pour tout le séjour")
		assert_lt(today - bioscan.issue_date, 30, "R12")
		assert_gte(card.issue_date, GameDate.add_years(p.birth_date, DocumentFactory.ID_CARD_MIN_AGE))
		var photo: PortraitValue = card.get_value(&"portrait")
		assert_eq(photo.appearance.get_trait(PassengerAppearance.SLOT_HEADWEAR), PassengerAppearance.OPTION_NONE, "photo officielle")
		assert_eq(FaceComparator.compare_in(photo.appearance, p.appearance, data.appearance_catalog).size(), 0)
		var family: String = card.get_value(&"family_name")
		assert_eq(family, p.family_name)


func test_photo_noise_is_legitimate() -> void:
	var data: DataCatalog = Gen.data()
	var gen: AppearanceGenerator = AppearanceGenerator.new(data.appearance_catalog)
	var rng: SeededRng = SeededRng.new(4)
	var p: Passenger = Passenger.new()
	p.faction_id = &"hal"
	var noisy: int = 0
	for i: int in 200:
		p.appearance = gen.generate(rng, &"hal")
		var photo: PortraitValue = DocumentFactory.make_photo(p, rng, gen, true)
		assert_eq(FaceComparator.compare_in(photo.appearance, p.appearance, data.appearance_catalog).size(), 0, "bruit ≠ discordance")
		noisy += int(not photo.appearance.equals(DocumentFactory.official_photo_of(p.appearance)) or photo.years_before_issue >= 4)
	assert_eq(noisy, 200)


func _sum(values: Array) -> float:
	var total: float = 0.0
	for v: Variant in values:
		var value: float = v
		total += value
	return total
