## Effet narratif conditionnel d'un cas scénarisé (M7) : deltas de drapeaux
## appliqués si le verdict correspond (`verdict` : `approve`, `deny`, `detain`,
## ou vide = tous) et si `condition` est vraie au moment du verdict.
## Ex. SC-16 refusée → `sc16_family_split` seulement si `sc15_idris_passed`.
class_name CaseEffectDef
extends Resource

@export var verdict: StringName = &""
@export var condition: FlagCondition = null
@export var flags: Dictionary[StringName, int] = {}
## Acte II (B26) : contexte du shift requis au moment du verdict, vide = aucun :
## `quota_reached` (quota atteint pour ce passager), `after_curfew` (ticket de
## file après le couvre-feu), `overrun` (entrée imputée).
@export var context: StringName = &""

const CONTEXT_QUOTA_REACHED: StringName = &"quota_reached"
const CONTEXT_AFTER_CURFEW: StringName = &"after_curfew"
const CONTEXT_OVERRUN: StringName = &"overrun"


func applies(verdict_kind: VerdictKind.Kind, p_flags: Dictionary[StringName, Variant],
		contexts: Array[StringName] = []) -> bool:
	if verdict != &"" and verdict != StringName(SlippedItem.VERDICT_NAMES[verdict_kind]):
		return false
	if context != &"" and not contexts.has(context):
		return false
	return FlagCondition.check(condition, p_flags)
