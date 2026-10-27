## Résultat d'une comparaison A ↔ B du mode Inspection (ARCHITECTURE §5.3,
## GDD §4.1) — émis par `EventBus.discrepancy_checked`.
class_name Discrepancy
extends RefCounted

enum Result { CONCORDANT, DISCORDANT, INCOMPARABLE }

const REASON_CONCORDANT: String = "disc_concordant"
const REASON_MISMATCH: String = "disc_mismatch"
const REASON_EXPIRED: String = "disc_expired"
const REASON_FACE_MISMATCH: String = "disc_face_mismatch"
const REASON_FACE_MASKED: String = "disc_face_masked"
const REASON_RULE_VIOLATED: String = "disc_rule_violated"
const REASON_RULE_INACTIVE: String = "disc_rule_inactive"
const REASON_SAME_FIELD: String = "disc_same_field"
const REASON_UNKNOWN_FIELD: String = "disc_unknown_field"
const REASON_INCOMPARABLE: String = "disc_incomparable"
## M7 : implants visibles ≠ déclarés, âge apparent ≠ naissance, MRZ ≠ champ,
## correspondance avec l'avis de recherche, personne absente de l'avis.
const REASON_IMPLANT_MISMATCH: String = "disc_implant_mismatch"
const REASON_AGE_MISMATCH: String = "disc_age_mismatch"
const REASON_MRZ_MISMATCH: String = "disc_mrz_mismatch"
const REASON_WANTED_MATCH: String = "disc_wanted_match"
const REASON_WANTED_NO_MATCH: String = "disc_wanted_no_match"

var a: FieldRef = null
var b: FieldRef = null
var result: Result = Result.INCOMPARABLE
## Vrai ⇔ `result == DISCORDANT` (discordance épinglable, preuve d'un refus).
var confirmed: bool = false
## Slots d'apparence qui diffèrent (comparaison de visages), pour le surlignage.
var differing_traits: Array[StringName] = []
## Clé de texte du résultat (« VISAGE MASQUÉ — demandez le retrait… »).
var reason_key: String = REASON_INCOMPARABLE


func _init(p_a: FieldRef = null, p_b: FieldRef = null) -> void:
	a = p_a
	b = p_b


func set_result(p_result: Result, p_reason_key: String) -> Discrepancy:
	result = p_result
	confirmed = p_result == Result.DISCORDANT
	reason_key = p_reason_key
	return self
