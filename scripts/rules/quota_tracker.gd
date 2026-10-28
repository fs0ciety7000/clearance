## Compteur du quota respiratoire d'un shift (Acte II, R23, D-077 ;
## docs/ACT2.md §2.5 M1) — état pur, partagé par le `DayController` (vrai
## shift) et le `DaySimulator` (équilibrage).
##
## `before_verdict(case)` dit si le quota est atteint **pour ce passager**
## (compté et compteur ≥ maximum : contexte du `ScoringService`) ;
## `after_verdict(case, verdict)` incrémente le compteur à chaque APPROBATION
## d'un passager compté et renvoie vrai si c'est une entrée **imputée**
## (approbation au-delà du quota).
class_name QuotaTracker
extends RefCounted

var rule: AirQuotaRule = null
var maximum: int = 0
var used: int = 0
var overruns: int = 0


## Compteur du jour ; inactif (maximum 0) sans règle R23 ou sans `air_quota`.
static func for_day(day: DayDef) -> QuotaTracker:
	var tracker: QuotaTracker = QuotaTracker.new()
	if day != null:
		tracker.rule = AirQuotaRule.find_in(day.rule_set)
		tracker.maximum = day.air_quota if tracker.rule != null else 0
	return tracker


func is_active() -> bool:
	return rule != null and maximum > 0


func is_full() -> bool:
	return is_active() and used >= maximum


func counts(case: Case) -> bool:
	return is_active() and rule.counts(case)


## Quota atteint pour ce passager (compté) au moment du tampon.
func before_verdict(case: Case) -> bool:
	return counts(case) and used >= maximum


## Enregistre un verdict ; vrai si l'entrée est imputée (dépassement).
func after_verdict(case: Case, verdict: VerdictKind.Kind) -> bool:
	if verdict != VerdictKind.Kind.APPROVE or not counts(case):
		return false
	var overrun: bool = used >= maximum
	used += 1
	if overrun:
		overruns += 1
	return overrun


## Copie le compteur dans le contexte de règles (paire « Compteur ↔ R23 »).
func sync(ctx: RuleContext) -> void:
	if ctx != null:
		ctx.quota_used = used
		ctx.quota_max = maximum if is_active() else 0
