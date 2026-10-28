## Objet glissé avec les papiers (M7, NARRATIVE §8.2 I1, GDD §5.5) : enveloppe
## (pot-de-vin), mot plié, carte de quai — instance d'un cas, vue par l'UI.
##
## Cycle : `DayController` émet `EventBus.item_slipped(item)` avec les
## documents ; l'UI propose `allowed` et demande une décision
## (`item_decision_requested(item_id, decision)`) ; le contrôleur la valide et
## émet `item_decided(item, decision)`. Au tampon, un objet non tranché reçoit
## `default_decision` (**refus automatique** : enveloppe et mot rendus / laissés,
## carte de quai gardée) et `item_decided` est émis à ce moment-là.
## Les effets (`effects`) sont des deltas de drapeaux indexés par
## `"<verdict>_<décision>"` (prioritaire) ou `"<décision>"` : `keep`, `return`,
## `report` ; verdicts `approve`, `deny`, `detain` (repli `deny_*` pour une
## détention). Crédits : `amount` si gardée (enveloppe), `report_bonus` si
## signalée (prime de signalement).
class_name SlippedItem
extends RefCounted

enum Kind { ENVELOPE, NOTE, DOCK_CARD }
## `NONE` = pas encore tranché ; `KEEP` = garder (tiroir) ; `RETURN` = rendre
## (fente) ou laisser ; `REPORT` = remettre à la Garde.
enum Decision { NONE, KEEP, RETURN, REPORT }

const DECISION_NAMES: Array[String] = ["none", "keep", "return", "report"]
const VERDICT_NAMES: Array[String] = ["approve", "deny", "detain"]

## `<case_id>_item<n>`.
var id: StringName = &""
var case_id: StringName = &""
var kind: Kind = Kind.ENVELOPE
## Crédits contenus (enveloppe), 0 sinon.
var amount: int = 0
## Libellé du plan de travail (`wb_envelope_label` « ENVELOPPE · %d ₵ »…).
var label_key: String = ""
## Texte lisible (mot, carte), vide pour une enveloppe.
var text_key: String = ""
## Lignes additionnelles résolues à la construction (ex. `sc18_sefa_note_lev`).
var extra_text_keys: PackedStringArray = []
var allowed: Array[Decision] = []
var default_decision: Decision = Decision.RETURN
var decision: Decision = Decision.NONE
## Prime versée si l'objet est remis à la Garde.
var report_bonus: int = 0
var effects: Dictionary[StringName, Dictionary] = {}


func is_allowed(p_decision: Decision) -> bool:
	return allowed.has(p_decision)


func is_decided() -> bool:
	return decision != Decision.NONE


## Décision retenue (la décision par défaut si rien n'a été tranché).
func final_decision() -> Decision:
	return decision if decision != Decision.NONE else default_decision


## Crédits gagnés pour cette décision.
func credits_for(p_decision: Decision) -> int:
	match p_decision:
		Decision.KEEP:
			return amount if kind == Kind.ENVELOPE else 0
		Decision.REPORT:
			return report_bonus
	return 0


## Deltas de drapeaux pour un verdict et une décision (0 = drapeau mis à vrai).
func effects_for(verdict: VerdictKind.Kind, p_decision: Decision) -> Dictionary:
	var d: String = DECISION_NAMES[p_decision]
	var keys: Array[String] = ["%s_%s" % [VERDICT_NAMES[verdict], d]]
	if verdict == VerdictKind.Kind.DETAIN:
		keys.append("deny_%s" % d)
	keys.append(d)
	for key: String in keys:
		if effects.has(StringName(key)):
			return effects[StringName(key)]
	return {}


static func decision_name(p_decision: Decision) -> String:
	return DECISION_NAMES[p_decision]


func _to_string() -> String:
	return "SlippedItem(%s, %s, %d ₵)" % [id, Kind.keys()[kind], amount]
