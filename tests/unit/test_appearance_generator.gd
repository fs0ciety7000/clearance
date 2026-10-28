## Apparences (ARCHITECTURE §9.3, §12 ; BOOTH_SCENE §12) : catalogue, tirage,
## roster du jour sur 1 000 `day_seed` (unicité sur fenêtre, déterminisme,
## origines), comparateur branché sur le catalogue, visière.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SEEDS: int = 1000
## Roster le plus long de la campagne (J10, GDD §8.1).
const ROSTER_SIZE: int = 16

var _catalog: AppearanceCatalog
var _gen: AppearanceGenerator
var _rosters: Array[AppearanceRoster] = []


func before_all() -> void:
	_catalog = Gen.data().appearance_catalog
	_gen = AppearanceGenerator.new(_catalog)
	var empty: Array[ScriptedCaseDef] = []
	for s: int in SEEDS:
		_rosters.append(_gen.build_day_roster(Gen.day_seed(s, 7), ROSTER_SIZE, empty, Gen.MVP_FACTIONS, GameDate.from_ymd(2187, 3, 19)))


func test_catalog_slots_follow_booth_scene() -> void:
	assert_eq(_catalog.get_slot_ids(), [&"silhouette", &"face", &"eyes", &"nose_mouth", &"skin", &"hair",
			&"headwear", &"outfit", &"accessory", &"palette"] as Array[StringName])
	assert_eq(_catalog.min_distance, 5)
	assert_eq(_catalog.window_size, 15)
	# Slots comparés = identité ∩ visible en portrait = liste par défaut de M2.
	assert_eq(FaceComparator.identity_slots_of(_catalog), FaceComparator.DEFAULT_IDENTITY_SLOTS)
	assert_eq(Gen.data().make_context(3).identity_slots, _catalog.get_identity_slots())
	assert_true(_catalog.get_slot(&"silhouette").identity and not _catalog.get_slot(&"silhouette").visible_in_portrait)
	for slot: AppearanceSlotDef in _catalog.slots:
		var ids: Array[StringName] = slot.get_option_ids()
		assert_gte(ids.size(), 3, String(slot.id))
		for option: AppearanceOptionDef in slot.options:
			assert_eq(ids.count(option.id), 1, "%s/%s en double" % [slot.id, option.id])
			assert_gte(option.weight, 0.0)
			assert_null(option.mesh, "catalogue placeholder : aucune référence visuelle")
	var headwear: AppearanceSlotDef = _catalog.get_slot(PassengerAppearance.SLOT_HEADWEAR)
	assert_eq(headwear.get_option(PassengerAppearance.VISOR_DOWN).weight, 0.0, "visière : jamais tirée au hasard")
	assert_eq(headwear.get_option(PassengerAppearance.VISOR_UP).weight, 0.0)


func test_generated_traits_are_catalog_options() -> void:
	var failures: PackedStringArray = []
	var valid: Dictionary[StringName, Array] = {}
	for slot: AppearanceSlotDef in _catalog.slots:
		valid[slot.id] = slot.get_option_ids()
	for roster: AppearanceRoster in _rosters.slice(0, 200):
		for entry: AppearanceRoster.Entry in roster.entries:
			var app: PassengerAppearance = entry.appearance
			for slot_id: StringName in valid:
				if not valid[slot_id].has(app.get_trait(slot_id)):
					failures.append("%s=%s" % [slot_id, app.get_trait(slot_id)])
			if app.is_face_covered() or app.get_trait(PassengerAppearance.SLOT_HEADWEAR) == PassengerAppearance.VISOR_UP:
				failures.append("visière tirée par le roster")
			if app.palette_id != app.get_trait(PassengerAppearance.SLOT_PALETTE):
				failures.append("palette_id")
			if app.age_band < 0 or app.age_band > 2 or absi(app.height_step) > 2:
				failures.append("âge/taille hors bornes")
	assert_eq(failures.size(), 0, Gen.head(failures))


func test_window_uniqueness_with_rare_fallback() -> void:
	var failures: PackedStringArray = []
	var fallbacks: int = 0
	var entries: int = 0
	var slots: Array[StringName] = _catalog.get_slot_ids()
	for roster: AppearanceRoster in _rosters:
		fallbacks += roster.get_fallback_count()
		for i: int in roster.size():
			entries += 1
			for j: int in range(maxi(i - _catalog.window_size, 0), i):
				var d: int = roster.entries[i].appearance.distance(roster.entries[j].appearance, slots)
				if d < _catalog.min_distance and not (roster.entries[i].fallback or roster.entries[j].fallback):
					failures.append("seed %d : %d↔%d distance %d" % [roster.day_seed, i, j, d])
	assert_eq(failures.size(), 0, Gen.head(failures))
	assert_lt(float(fallbacks) / entries, 0.01, "replis « meilleur candidat » < 1 %% (%d/%d)" % [fallbacks, entries])


func test_roster_is_deterministic_from_day_seed() -> void:
	var failures: int = 0
	var empty: Array[ScriptedCaseDef] = []
	var other: AppearanceGenerator = AppearanceGenerator.new(_catalog)
	for s: int in SEEDS:
		var again: AppearanceRoster = other.build_day_roster(Gen.day_seed(s, 7), ROSTER_SIZE, empty, Gen.MVP_FACTIONS, GameDate.from_ymd(2187, 3, 19))
		if JSON.stringify(again.serialize()) != JSON.stringify(_rosters[s].serialize()):
			failures += 1
	assert_eq(failures, 0)
	assert_ne(JSON.stringify(_rosters[0].serialize()), JSON.stringify(_rosters[1].serialize()))


func test_roster_factions_follow_day_weights() -> void:
	var counts: Dictionary[StringName, int] = {}
	var total: int = 0
	for roster: AppearanceRoster in _rosters:
		for entry: AppearanceRoster.Entry in roster.entries:
			counts[entry.faction_id] = counts.get(entry.faction_id, 0) + 1
			total += 1
	for faction_id: StringName in Gen.MVP_FACTIONS:
		var count: int = counts.get(faction_id, 0)
		var share: float = float(count) / total
		assert_almost_eq(share, Gen.MVP_FACTIONS[faction_id], 0.02, String(faction_id))
	# La faction de l'index i ne dépend que de (day_seed, i).
	assert_eq(_rosters[3].entries[5].faction_id, AppearanceGenerator.roster_faction(_rosters[3].day_seed, 5, Gen.MVP_FACTIONS))


func test_scripted_overrides_are_placed_first() -> void:
	var day: DayDef = Gen.data().get_day(3)
	for s: int in 50:
		var roster: AppearanceRoster = _gen.build_day_roster(Gen.day_seed(s, 3), day.passenger_count, day.scripted_cases,
				day.faction_weights, day.game_date)
		var mira: AppearanceRoster.Entry = roster.get_entry(2)
		assert_eq(mira.scripted_id, &"sc_04")
		assert_eq(mira.faction_id, &"tyc")
		assert_true(mira.appearance.is_face_covered(), "SC-04 visière baissée")
		assert_eq(mira.appearance.age_band, 1, "Mira, 35 ans : adulte")
		assert_eq(roster.get_entry(7).faction_id, &"tyc", "SC-05 Tycho")


func test_derive_identity_changes_exactly_the_requested_slots() -> void:
	var rng: SeededRng = SeededRng.new(42)
	for i: int in 200:
		var base: PassengerAppearance = _gen.generate(rng, &"tyc")
		var changed: Array[StringName] = []
		var count: int = 1 + i % 2
		var derived: PassengerAppearance = _gen.derive_identity(rng, base, count, &"tyc", changed)
		assert_eq(changed.size(), count)
		var differing: Array[StringName] = FaceComparator.compare_in(base, derived, _catalog)
		differing.sort()
		changed.sort()
		assert_eq(differing, changed)


func test_comparator_ignores_changeable_slots_and_small_age_gap() -> void:
	var base: PassengerAppearance = _gen.generate(SeededRng.new(3), &"hal")
	var noise: PassengerAppearance = base.derive({PassengerAppearance.SLOT_HAIR: &"hair_shaved_c01",
			PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN, &"outfit": &"outfit_08",
			PassengerAppearance.SLOT_ACCESSORY: &"scarf", &"silhouette": &"silhouette_s4_slight"})
	noise.age_band = base.age_band + 1 if base.age_band < 2 else base.age_band - 1
	assert_eq(FaceComparator.compare_in(base, noise, _catalog).size(), 0, "bruit légitime ≠ discordance")


func test_visor_masks_the_face_until_removed() -> void:
	var app: PassengerAppearance = _gen.generate(SeededRng.new(8), &"ter").derive(
			{PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN})
	assert_true(app.is_face_covered())
	var lifted: PassengerAppearance = app.without_visor()
	assert_false(lifted.is_face_covered())
	assert_eq(lifted.get_trait(PassengerAppearance.SLOT_HEADWEAR), PassengerAppearance.VISOR_UP)
	assert_true(app.is_face_covered(), "without_visor() renvoie une copie")
	assert_eq(FaceComparator.compare_in(app, lifted, _catalog).size(), 0, "le retrait ne change aucun trait d'identité")
	var open: PassengerAppearance = _gen.generate(SeededRng.new(9), &"ter")
	assert_true(open.without_visor().equals(open), "sans visière : inchangé")
