## Notation d'un verdict (ARCHITECTURE §8, GDD §4.5, §4.6, §5.1, §5.2) — pur, statique.
##
## - **Verdict** : correct si c'est celui de la clé (`CaseKey.expected_verdict`,
##   D-005) ; un REFUS là où une DÉTENTION était attendue est correct, sans prime.
## - **Preuve** (D-024, D-032) : un REFUS / une DÉTENTION est documenté si une
##   discordance confirmée épinglée (`Verdict.flagged`) recoupe une violation
##   (`Violation.is_documented_by`). Une violation sans champ de document (document
##   manquant : seule la règle du Rulebook la prouve) est documentée d'office.
## - **Procédures** (D-031) : R06 « visage découvert » (APPROUVÉ visière baissée
##   → VISAGE NON CONTRÔLÉ), R08 « interrogatoire TYC » (tampon sans question →
##   INTERROGATOIRE OMIS), si la règle est dans le RuleSet du jour.
## - **Signalement d'un porteur du code 1** (NARRATIVE §4.9, J7+) : DÉTENTION
##   + paire « marque luciole ↔ bulletin » confirmée = cas **correct**, aucune
##   citation (ni procédure), salaire + prime de détention, quelles que soient
##   les autres violations (`CaseResult.luciole_report`).
## - **M13 — fouille** (D-146, D-148 ; ARCHITECTURE §12.9) : R44 (procédure
##   `search_cause`) → FOUILLE SANS MOTIF (`cit_unwarranted_search`, gravité 1)
##   si une fouille a été faite **sans motif** (`Verdict.search_motive` vide,
##   figé à la demande) sur un passager **attendu APPROUVÉ** ; R47
##   (`belt_search`) → FOUILLE OMISE (`cit_search_skipped`, gravité 1) sur un
##   APPROUVÉ d'un passager visé sans fouille. Citations de procédure
##   ordinaires : la plus grave l'emporte (REFUS INJUSTIFIÉ sur un innocent
##   fouillé puis refusé).
## - **Citation** : au plus une par cas, la plus grave (table `GRAVITY`).
## - **Crédits** : `credit_per_correct` si correct, + prime de détention ; 0
##   sinon. L'amende dépend du rang de la citation dans la journée
##   (`fine_for`) : le DayController l'applique (`apply_citation`).
## - **Quota respiratoire** (Acte II, R23 souple, D-077) : `quota_full` = le
##   quota est atteint pour ce passager (compté). Passager en règle : REFUSÉ =
##   correct et documenté d'office (`quota_refusal`) ; APPROUVÉ = correct mais
##   imputé, **0 ₵** (`quota_overrun` posé par l'appelant, `QuotaTracker`).
##   Un fraudeur approuvé reste une ENTRÉE IRRÉGULIÈRE.
class_name ScoringService
extends RefCounted

const CIT_IRREGULAR_ENTRY: String = "cit_irregular_entry"
const CIT_UNJUSTIFIED_DENIAL: String = "cit_unjustified_denial"
const CIT_UNDOCUMENTED_DENIAL: String = "cit_undocumented_denial"
const CIT_FACE_UNCHECKED: String = "cit_face_unchecked"
const CIT_INTERVIEW_SKIPPED: String = "cit_interview_skipped"
const CIT_ABUSIVE_DETENTION: String = "cit_abusive_detention"
const CIT_UNDOCUMENTED_DETENTION: String = "cit_undocumented_detention"
## M13 (D-146, D-148).
const CIT_UNWARRANTED_SEARCH: String = "cit_unwarranted_search"
const CIT_SEARCH_SKIPPED: String = "cit_search_skipped"

## Gravité des citations (GDD §4.6) : la plus grave l'emporte.
const GRAVITY: Dictionary[String, int] = {
	CIT_IRREGULAR_ENTRY: 3,
	CIT_UNJUSTIFIED_DENIAL: 3,
	CIT_UNDOCUMENTED_DENIAL: 2,
	CIT_FACE_UNCHECKED: 2,
	CIT_ABUSIVE_DETENTION: 2,
	CIT_UNDOCUMENTED_DETENTION: 2,
	CIT_INTERVIEW_SKIPPED: 1,
	CIT_UNWARRANTED_SEARCH: 1,
	CIT_SEARCH_SKIPPED: 1,
}

## Prime de détention par défaut (GDD §5.1) si aucun `EconomyDef` n'est fourni.
const DEFAULT_DETAIN_BONUS: int = 5
## Gains par défaut sans `DayDef` (tests unitaires).
const DEFAULT_CREDIT_PER_CORRECT: int = 5
## Code Luciole dont la marque se signale (code 1, GDD §4.7).
const LUCIOLE_REPORT_CODE: int = 1


## Note un verdict. `case` (cas présenté, éventuellement muté par le retrait de
## la visière) et `day` (RuleSet, barème) sont facultatifs : sans eux, pas de
## contrôle de procédure et barème par défaut.
static func score(verdict: Verdict, key: CaseKey, case_id: StringName, case: Case = null,
		day: DayDef = null, detain_bonus: int = DEFAULT_DETAIN_BONUS, quota_full: bool = false) -> CaseResult:
	var result: CaseResult = CaseResult.new(case_id)
	if verdict == null or key == null:
		push_error("ScoringService.score: verdict ou clé manquant (%s)" % case_id)
		return result
	if case != null:
		result.case_index = case.index
	result.verdict = verdict
	result.verdict_kind = verdict.kind
	result.expected_verdict = key.expected_verdict
	result.elapsed_sec = verdict.elapsed_sec
	result.expected_violations = key.expected_violations.duplicate()
	result.verdict_correct = is_correct(verdict.kind, key.expected_verdict)
	result.documented = is_documented(verdict.flagged, key.expected_violations)
	result.quota_full = quota_full
	var quota_denial: bool = quota_full and verdict.kind == VerdictKind.Kind.DENY \
			and key.expected_verdict == VerdictKind.Kind.APPROVE
	if quota_denial:
		result.verdict_correct = true
		result.documented = true
		result.quota_refusal = true
	if is_luciole_report(verdict, case):
		result.luciole_report = true
		result.verdict_correct = true
		result.documented = true
		result.correct = true
		result.wage = (day.credit_per_correct if day != null else DEFAULT_CREDIT_PER_CORRECT) + detain_bonus
		result.credits_delta = result.wage
		return result

	var citation: String = ""
	var rule_id: StringName = &""
	match verdict.kind:
		VerdictKind.Kind.APPROVE:
			if key.expected_verdict != VerdictKind.Kind.APPROVE:
				citation = CIT_IRREGULAR_ENTRY
				result.missed_violations = key.expected_violations.duplicate()
				rule_id = _first_rule_id(key.expected_violations)
		VerdictKind.Kind.DENY:
			if quota_denial:
				pass
			elif key.expected_verdict == VerdictKind.Kind.APPROVE:
				citation = CIT_UNJUSTIFIED_DENIAL
			elif not result.documented:
				citation = CIT_UNDOCUMENTED_DENIAL
				result.missed_violations = key.expected_violations.duplicate()
				rule_id = _first_rule_id(key.expected_violations)
		VerdictKind.Kind.DETAIN:
			if key.expected_verdict == VerdictKind.Kind.APPROVE:
				citation = CIT_UNJUSTIFIED_DENIAL
			elif key.expected_verdict == VerdictKind.Kind.DENY:
				citation = CIT_ABUSIVE_DETENTION
				rule_id = _first_rule_id(key.expected_violations)
			elif not result.documented:
				citation = CIT_UNDOCUMENTED_DETENTION
				result.missed_violations = key.expected_violations.duplicate()
				rule_id = _first_rule_id(key.expected_violations)

	# Procédures (D-031) : seulement si elles l'emportent en gravité.
	if case != null and day != null and day.rule_set != null:
		for rule: Rule in day.rule_set.rules:
			var procedure: ProcedureRule = rule as ProcedureRule
			if procedure == null or not procedure.applies_to(case):
				continue
			var missed: String = _procedure_citation(procedure, verdict, case, key.expected_verdict)
			if missed.is_empty():
				continue
			if citation.is_empty() or GRAVITY[missed] > GRAVITY[citation]:
				citation = missed
				rule_id = procedure.id
				result.procedure_missed = procedure.procedure_id

	result.citation_reason_key = citation
	result.citation_rule_id = rule_id
	result.correct = result.verdict_correct and citation.is_empty()
	if result.correct:
		result.wage = day.credit_per_correct if day != null else DEFAULT_CREDIT_PER_CORRECT
		if verdict.kind == VerdictKind.Kind.DETAIN and key.expected_verdict == VerdictKind.Kind.DETAIN:
			result.wage += detain_bonus
		if quota_full and verdict.kind == VerdictKind.Kind.APPROVE:
			# D-077 : entrée imputée au guichet, le cas ne rapporte rien.
			result.wage = 0
	result.credits_delta = result.wage
	return result


## Complète un résultat cité : rang de la citation dans la journée et amende
## (GDD §5.2 : avertissements, puis `penalty_per_error`, puis `penalty_escalated`).
static func apply_citation(result: CaseResult, citation_number: int, day: DayDef) -> void:
	if result == null or not result.has_citation():
		return
	result.citation_number = citation_number
	result.fine = fine_for(citation_number, day)
	result.credits_delta = result.wage - result.fine


## Amende de la n-ième citation du jour (n ≥ 1).
static func fine_for(citation_number: int, day: DayDef) -> int:
	var free: int = day.free_citations_per_day if day != null else 2
	var first_fine: int = day.penalty_per_error if day != null else 5
	var escalated: int = day.penalty_escalated if day != null else 10
	if citation_number <= free:
		return 0
	if citation_number == free + 1:
		return first_fine
	return escalated


## Signalement valide (§4.9) : DÉTENTION d'un porteur du code 1 avec une paire
## marque ↔ bulletin confirmée et épinglée. Les codes 2 à 7 ne prouvent rien.
static func is_luciole_report(verdict: Verdict, case: Case) -> bool:
	if verdict == null or verdict.kind != VerdictKind.Kind.DETAIN or case == null \
			or not case.luciole_codes.has(LUCIOLE_REPORT_CODE):
		return false
	for discrepancy: Discrepancy in verdict.flagged:
		if discrepancy != null and discrepancy.confirmed and discrepancy.reason_key == Discrepancy.REASON_SYMBOL_MATCH:
			return true
	return false


static func is_correct(given: VerdictKind.Kind, expected: VerdictKind.Kind) -> bool:
	if given == expected:
		return true
	return given == VerdictKind.Kind.DENY and expected == VerdictKind.Kind.DETAIN


## Vrai si une discordance confirmée épinglée recoupe au moins une violation,
## ou si une violation ne repose sur aucun champ de document (D-032).
static func is_documented(flagged: Array[Discrepancy], violations: Array[Violation]) -> bool:
	for violation: Violation in violations:
		if is_self_evident(violation):
			return true
		for discrepancy: Discrepancy in flagged:
			if violation.is_documented_by(discrepancy):
				return true
	return false


## Violation prouvée par la seule règle du Rulebook (document manquant).
static func is_self_evident(violation: Violation) -> bool:
	if violation == null:
		return false
	for ref: FieldRef in violation.refs:
		if not ref.is_rule():
			return false
	return true


static func _procedure_citation(procedure: ProcedureRule, verdict: Verdict, case: Case,
		expected: VerdictKind.Kind = VerdictKind.Kind.APPROVE) -> String:
	match procedure.procedure_id:
		ProcedureRule.PROCEDURE_FACE_UNCOVERED:
			var appearance: PassengerAppearance = case.passenger_presented.appearance if case.passenger_presented != null else null
			if verdict.kind == VerdictKind.Kind.APPROVE and appearance != null and appearance.is_face_covered():
				return CIT_FACE_UNCHECKED
		ProcedureRule.PROCEDURE_TYCHO_INTERVIEW:
			if verdict.questions_asked.is_empty():
				return CIT_INTERVIEW_SKIPPED
		ProcedureRule.PROCEDURE_SEARCH_CAUSE:
			if is_unwarranted_search(verdict, expected):
				return CIT_UNWARRANTED_SEARCH
		ProcedureRule.PROCEDURE_BELT_SEARCH:
			if verdict.kind == VerdictKind.Kind.APPROVE and not verdict.search_done and procedure.requires_search(case):
				return CIT_SEARCH_SKIPPED
	return ""


## M13 (R44) : fouille faite sans motif sur un passager attendu APPROUVÉ.
## Fouiller sans motif un passager en infraction n'est pas sanctionné.
static func is_unwarranted_search(verdict: Verdict, expected: VerdictKind.Kind) -> bool:
	return verdict != null and verdict.search_done and verdict.search_motive == &"" \
			and expected == VerdictKind.Kind.APPROVE


static func _first_rule_id(violations: Array[Violation]) -> StringName:
	return violations[0].rule_id if not violations.is_empty() else &""
