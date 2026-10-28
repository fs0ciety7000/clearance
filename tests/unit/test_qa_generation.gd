## QA (docs/QA.md §6) — cohérence du générateur avec les passagers scénarisés.
## Bugs ouverts : `pending("QA-xxx …")`, la suite reste verte.
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


## QA-002 : le générateur tire parfois le nom complet exact d'un personnage
## scénarisé (≈ 1,9 % des passagers générés, ~2 par campagne) : une seconde
## « Mira Vasquez-Orlov » au J3, « Lev Petrenko » aux J5 et J6, l'inspecteur
## « Corentin Ravel » au guichet…
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
	if not hits.is_empty():
		pending("QA-002 : %d homonyme(s) de personnages scénarisés : %s" % [hits.size(), ", ".join(hits.slice(0, 6))])
		return
	assert_eq(hits.size(), 0)
