## Famille « Quota respiratoire » (R23, Acte II J11 ; docs/ACT2.md §2.5 M1,
## D-077) — règle de **contexte du shift**, souple : elle ne produit jamais de
## violation (le verdict attendu d'un passager en règle reste APPROUVÉ, D-005),
## mais le `ScoringService` lit le compteur : quota atteint, un REFUS d'un
## passager compté et en règle est correct et documenté d'office ; un
## APPROUVÉ reste correct mais **imputé** (0 ₵, `quota_overrun`).
## Compté : toute APPROBATION d'un passager non exempté (origine
## `exempt_faction_ids`, motif `exempt_purposes` lus sur les documents).
## Mode Inspection : paire « Compteur QUOTA ↔ R23 » (`FieldRef.quota_counter()`)
## DISCORDANTE quand le quota est atteint pour ce passager.
class_name AirQuotaRule
extends Rule

@export var exempt_faction_ids: Array[StringName] = [&"hal"]
@export var exempt_purposes: Array[StringName] = [Passenger.PURPOSE_DIPLOMATIC]
@export var permit_id: StringName = &"entry_permit"


## Règle de quota active d'un RuleSet, ou null.
static func find_in(rule_set: RuleSet) -> AirQuotaRule:
	if rule_set == null:
		return null
	for rule: Rule in rule_set.rules:
		if rule is AirQuotaRule:
			return rule as AirQuotaRule
	return null


## Vrai si une approbation de ce passager compte dans le quota (Acte III :
## un convoqué de l'Enquête, convocation authentique, n'est pas compté — R36).
func counts(case: Case, ctx: RuleContext = null) -> bool:
	if case == null or exempt_faction_ids.has(Rule.visible_origin(case)):
		return false
	if is_exempted(case, ctx):
		return false
	var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
	if purpose != null:
		for exempt: StringName in exempt_purposes:
			if FieldValue.equals(purpose, exempt):
				return false
	return true


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	if ref == null or not ref.is_quota_counter() or ctx == null or ctx.quota_max <= 0:
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if ctx.is_quota_full() and counts(case, ctx) else Discrepancy.Result.CONCORDANT
