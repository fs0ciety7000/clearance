## Simulation rapide d'un jour sans scène ni signaux (debug `--screen=…`,
## équilibrage) : construit les cas du `CaseBuilder`, joue une politique et
## note avec le vrai `ScoringService`. Le résultat est un `DaySummary`
## identique à celui d'un vrai shift (citations numérotées, amendes).
class_name DaySimulator
extends RefCounted


## `policy(case: Case, key: CaseKey, index: int) -> VerdictKind.Kind`. Les refus
## sont documentés par les preuves visibles (`evidence_for`) si `document` ;
## la visière est retirée avant le verdict si `remove_visors`.
static func simulate(data: DataCatalog, day_number: int, day_seed: int, policy: Callable,
		document: bool = true, remove_visors: bool = true, processed_limit: int = -1,
		undocumented_indices: Array[int] = []) -> DaySummary:
	var day: DayDef = data.get_day(day_number)
	var builder: CaseBuilder = CaseBuilder.new(data, day, day_seed, [])
	var summary: DaySummary = DaySummary.new()
	summary.day_number = day_number
	summary.planned_cases = day.passenger_count
	var citations: int = 0
	var count: int = day.passenger_count if processed_limit < 0 else mini(processed_limit, day.passenger_count)
	for i: int in count:
		var generated: GeneratedCase = builder.build(i)
		var case: Case = generated.case
		var kind: VerdictKind.Kind = policy.call(case, generated.key, i)
		if remove_visors:
			case.remove_visor()
		var verdict: Verdict = Verdict.new(case.case_id, kind)
		if document and kind != VerdictKind.Kind.APPROVE and not undocumented_indices.has(i):
			verdict.flagged = evidence_for(case, generated.key, builder.ctx)
		verdict.elapsed_sec = 30.0
		var result: CaseResult = ScoringService.score(verdict, generated.key, case.case_id, case, day, data.get_economy().detain_bonus)
		result.passenger_label = case.passenger_presented.short_label() if case.passenger_presented != null else ""
		if result.has_citation():
			citations += 1
			ScoringService.apply_citation(result, citations, day)
		summary.add_result(result)
	summary.time_expired = count < day.passenger_count
	return summary


## Discordances confirmées qui prouvent les violations d'un cas, telles qu'un
## agent les obtiendrait en comparant les champs désignés par chaque violation.
static func evidence_for(case: Case, key: CaseKey, ctx: RuleContext) -> Array[Discrepancy]:
	var found: Array[Discrepancy] = []
	for violation: Violation in key.expected_violations:
		var refs: Array[FieldRef] = violation.refs
		if refs.size() < 2:
			continue
		var result: Discrepancy = DiscrepancyChecker.check(case, refs[0], refs[1], ctx)
		if not result.confirmed and refs.size() > 2:
			result = DiscrepancyChecker.check(case, refs[0], refs[refs.size() - 1], ctx)
		if result.confirmed:
			found.append(result)
	return found
