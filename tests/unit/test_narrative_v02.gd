## NARRATIVE v0.2 (§4.9, §4.10, §8.5) côté logique : signalement d'un porteur
## du code 1 au guichet, dates de naissance « 00.00.AAAA » des Dérivants.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const VK := VerdictKind.Kind

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


## Premier cas généré porteur du code 1 (marque luciole) au jour `n`.
func _code1_case(n: int) -> GeneratedCase:
	var day: DayDef = data.get_day(n)
	for campaign: int in range(1, 200):
		var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [])
		for i: int in day.passenger_count:
			if builder.get_scripted_case(i) != null:
				continue
			var generated: GeneratedCase = builder.build(i)
			if generated.case.luciole_codes.has(ScoringService.LUCIOLE_REPORT_CODE):
				return generated
	return null


func _marked_document(c: Case) -> StringName:
	for id: StringName in c.get_document_ids():
		if c.get_document(id).marks.has(CaseBuilder.MARK_LUCIOLE):
			return id
	return &""


## §4.9 : DÉTENTION + paire marque ↔ bulletin = signalement valide dès le J7.
func test_detaining_a_code1_carrier_with_the_pair_is_a_valid_report() -> void:
	var generated: GeneratedCase = _code1_case(7)
	assert_not_null(generated, "porteur du code 1 au J7")
	if generated == null:
		return
	var c: Case = generated.case
	var ctx: RuleContext = data.make_context(7)
	var doc_id: StringName = _marked_document(c)
	assert_ne(doc_id, &"", "document marqué")
	var pair: Discrepancy = DiscrepancyChecker.check(c, FieldRef.mark(doc_id, CaseBuilder.MARK_LUCIOLE),
			FieldRef.symbol(CaseBuilder.MARK_LUCIOLE), ctx)
	assert_true(pair.confirmed, "paire confirmée")
	assert_eq(pair.reason_key, Discrepancy.REASON_SYMBOL_MATCH)
	var symmetric: Discrepancy = DiscrepancyChecker.check(c, FieldRef.symbol(CaseBuilder.MARK_LUCIOLE),
			FieldRef.mark(doc_id, CaseBuilder.MARK_LUCIOLE), ctx)
	assert_true(symmetric.confirmed, "symétrique")
	var day: DayDef = data.get_day(7)
	var bonus: int = data.get_economy().detain_bonus
	var verdict: Verdict = Verdict.new(c.case_id, VK.DETAIN)
	verdict.flagged.append(pair)
	var result: CaseResult = ScoringService.score(verdict, generated.key, c.case_id, c, day, bonus)
	assert_true(result.luciole_report, "signalement")
	assert_true(result.correct, "cas correct")
	assert_false(result.has_citation(), "aucune citation")
	assert_eq(result.wage, day.credit_per_correct + bonus, "salaire + une prime")
	var flags: Dictionary[StringName, Variant] = {&"lucioles_trust": 1, &"loyalty": 0}
	var changes: Dictionary[StringName, Variant] = CaseConsequences.compute(null, c, VK.DETAIN,
			not generated.key.expected_violations.is_empty(), false, 7, flags, true)
	var reported: bool = changes.get(CaseConsequences.FLAG_REPORTED_AT_BOOTH, false)
	assert_true(reported)
	assert_eq(SaveService.as_int(changes.get(CaseConsequences.FLAG_TRUST)), -1, "−2 une seule fois")
	assert_eq(SaveService.as_int(changes.get(CaseConsequences.FLAG_LOYALTY)), 1)
	# Sans la paire : jugé par le seul moteur de règles, pas de signalement.
	var bare: CaseResult = ScoringService.score(Verdict.new(c.case_id, VK.DETAIN), generated.key, c.case_id, c, day, bonus)
	assert_false(bare.luciole_report)
	if generated.key.expected_verdict == VK.APPROVE:
		assert_true(bare.has_citation(), "détention sans preuve d'un passager en règle")


## §4.9 #1 : avant le J7 (pas de bulletin), la marque n'est pas citable.
func test_mark_is_not_citable_before_the_symbols_bulletin() -> void:
	var generated: GeneratedCase = _code1_case(6)
	assert_not_null(generated)
	if generated == null:
		return
	var doc_id: StringName = _marked_document(generated.case)
	var pair: Discrepancy = DiscrepancyChecker.check(generated.case, FieldRef.mark(doc_id, CaseBuilder.MARK_LUCIOLE),
			FieldRef.symbol(CaseBuilder.MARK_LUCIOLE), data.make_context(6))
	assert_false(pair.confirmed)


## §4.9 #6 : SC-13 (`flags_on_detain`) garde ses drapeaux, sans double −2.
func test_scripted_detain_flags_replace_the_report_gauges() -> void:
	var scripted: ScriptedCaseDef = ScriptedCaseDef.new()
	scripted.flags_on_detain = {&"sc13_detained": 0}
	var flags: Dictionary[StringName, Variant] = {&"lucioles_trust": 0}
	var changes: Dictionary[StringName, Variant] = CaseConsequences.compute(scripted, null, VK.DETAIN, true, false, 7,
			flags, true)
	var detained: bool = changes.get(&"sc13_detained", false)
	var reported: bool = changes.get(CaseConsequences.FLAG_REPORTED_AT_BOOTH, false)
	assert_true(detained)
	assert_true(reported)
	assert_false(changes.has(CaseConsequences.FLAG_TRUST), "pas de jauge en plus")


## §4.10 : format, égalité par année, âge apparent par intervalle.
func test_year_only_birth_dates() -> void:
	var d: int = GameDate.year_only(2163)
	assert_true(GameDate.is_year_only(d))
	assert_false(GameDate.is_year_only(GameDate.from_ymd(2163, 5, 5)))
	assert_false(GameDate.is_year_only(GameDate.INVALID))
	assert_eq(GameDate.format(d), "00.00.2163")
	assert_eq(GameDate.year_of(d), 2163)
	assert_eq(GameDate.add_years(d, 2), GameDate.year_only(2165))
	var today: int = GameDate.from_ymd(2187, 3, 20)
	assert_eq(GameDate.possible_ages(d, today), Vector2i(23, 24))
	# 2157 : 29 ou 30 ans → tranches 0 et 1 admises, 2 refusée (zéro faux positif).
	var edge: int = GameDate.year_only(2157)
	assert_true(ApparentAgeRule.birth_matches_band(edge, today, 0))
	assert_true(ApparentAgeRule.birth_matches_band(edge, today, 1))
	assert_false(ApparentAgeRule.birth_matches_band(edge, today, 2))
	# NAME_MISMATCH : change l'année, jamais d'inversion jour/mois.
	var altered: int = NameMismatchInjector._alter_date(SeededRng.new(3), d)
	assert_true(GameDate.is_year_only(altered))
	assert_ne(altered, d)


## §4.10 #2 : ~½ des Dérivants générés en « 00.00.AAAA », mêmes valeurs sur tous
## les documents ; Sefa (SC-18) en 00.00.2163 ; aucune autre origine.
func test_drift_passengers_get_year_only_births() -> void:
	var drv: FactionDef = data.factions[&"drv"]
	assert_almost_eq(drv.year_only_birth_rate, 0.5, 0.001)
	for id: StringName in data.factions:
		if id != &"drv":
			assert_eq(data.factions[id].year_only_birth_rate, 0.0, String(id))
	var total: int = 0
	var year_only: int = 0
	for n: int in [8, 9, 10]:
		var day: DayDef = data.get_day(n)
		for campaign: int in range(1, 30):
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [])
			for i: int in day.passenger_count:
				var generated: GeneratedCase = builder.build(i)
				var p: Passenger = generated.case.passenger_presented
				if builder.get_scripted_case(i) != null and builder.get_scripted_case(i).id == &"sc_18":
					assert_eq(GameDate.format(p.birth_date), "00.00.2163", "Sefa")
				if p.faction_id != &"drv" or builder.get_scripted_case(i) != null:
					if p.faction_id != &"drv":
						assert_false(p.is_birth_year_only(), "année seule réservée aux DRV")
					continue
				total += 1
				if p.is_birth_year_only():
					year_only += 1
				assert_true(generated.invariant_errors.is_empty(), "invariants : %s" % [generated.invariant_errors])
	assert_gt(total, 30, "Dérivants générés")
	var rate: float = float(year_only) / float(maxi(total, 1))
	assert_between(rate, 0.3, 0.7, "≈ la moitié (%d / %d)" % [year_only, total])
