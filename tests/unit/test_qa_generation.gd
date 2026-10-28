## QA (docs/QA.md §6) — cohérence du générateur avec les passagers scénarisés.
## QA-002 corrigé : noms (et noms de famille distinctifs) des personnages
## réservés aux tirages (`NamePool.reserved_names` / `reserved_full_names`).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const SEEDS: int = 12

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


## Nom complet de chaque passager scénarisé dont l'identité ne dépend pas de la
## graine (même nom sur deux campagnes) : `{nom complet: id scénarisé}`.
func _fixed_scripted_names() -> Dictionary:
	var seen: Dictionary = {}
	for campaign: int in [101, 202]:
		for n: int in range(1, data.get_last_day_number() + 1):
			var day: DayDef = data.get_day(n)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [])
			for scripted: ScriptedCaseDef in builder.get_active_scripted_cases():
				var p: Passenger = builder.build(scripted.at_index).case.passenger_presented
				var key: StringName = scripted.id
				if not seen.has(key):
					seen[key] = {}
				(seen[key] as Dictionary)["%s %s" % [p.given_name, p.family_name]] = true
	var fixed: Dictionary = {}
	for id: Variant in seen:
		var names: Dictionary = seen[id]
		if names.size() == 1:
			fixed[names.keys()[0]] = id
	return fixed


## QA-002 (corrigé) : aucun passager généré ne porte le nom complet d'un
## personnage scénarisé (avant : ≈ 1,9 %, une seconde « Mira Vasquez-Orlov »
## au J3, « Lev Petrenko », l'inspecteur « Corentin Ravel » au guichet…), ni un
## nom de famille distinctif réservé.
func test_generated_passengers_never_reuse_a_scripted_full_name() -> void:
	var fixed: Dictionary = _fixed_scripted_names()
	assert_gt(fixed.size(), 10, "personnages scénarisés à nom fixe")
	var hits: PackedStringArray = []
	for campaign: int in range(1, SEEDS + 1):
		for n: int in range(1, data.get_last_day_number() + 1):
			var day: DayDef = data.get_day(n)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [])
			for i: int in day.passenger_count:
				if builder.get_scripted_case(i) != null:
					continue
				var p: Passenger = builder.build(i).case.passenger_presented
				var full: String = "%s %s" % [p.given_name, p.family_name]
				if fixed.has(full):
					hits.append("graine %d J%d #%d %s (= %s)" % [campaign, n, i, full, fixed[full]])
				var pool: NamePool = data.factions[p.faction_id].name_pool
				if pool.is_reserved(p.family_name):
					hits.append("graine %d J%d #%d nom réservé %s" % [campaign, n, i, p.family_name])
	assert_eq(hits.size(), 0, ", ".join(hits.slice(0, 6)))
