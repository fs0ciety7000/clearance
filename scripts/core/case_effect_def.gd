## Effet narratif conditionnel d'un cas scénarisé (M7) : deltas de drapeaux
## appliqués si le verdict correspond (`verdict` : `approve`, `deny`, `detain`,
## ou vide = tous) et si `condition` est vraie au moment du verdict.
## Ex. SC-16 refusée → `sc16_family_split` seulement si `sc15_idris_passed`.
class_name CaseEffectDef
extends Resource

@export var verdict: StringName = &""
@export var condition: FlagCondition = null
@export var flags: Dictionary[StringName, int] = {}


func applies(verdict_kind: VerdictKind.Kind, p_flags: Dictionary[StringName, Variant]) -> bool:
	if verdict != &"" and verdict != StringName(SlippedItem.VERDICT_NAMES[verdict_kind]):
		return false
	return FlagCondition.check(condition, p_flags)
