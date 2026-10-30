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
## M7 (NARRATIVE §4.9) : marque au coin d'un document ↔ bulletin « Symboles
## subversifs » ; confirmée, elle documente un signalement (DÉTENTION, code 1).
const REASON_SYMBOL_MATCH: String = "disc_symbol_match"
## Acte II (R30) : N° ID ↔ entrée de l'onglet Révocations.
const REASON_REVOKED_MATCH: String = "disc_revoked_match"
const REASON_REVOKED_NO_MATCH: String = "disc_revoked_no_match"
## Acte III : document expiré dans la fenêtre de prorogation (R32, CONCORDANT) ;
## N° ID révoqué puis réintégré (R33, CONCORDANT) ; Répondant ↔ entrée de la
## Main courante (R34) ; Convocation ↔ entrée de l'onglet Convocations (R36 :
## même N°, autre nom = DISCORDANT) ; document retiré (M1, INCOMPARABLE).
const REASON_PROROGATED: String = "disc_prorogated"
const REASON_REINSTATED: String = "disc_reinstated"
const REASON_SPONSOR_MATCH: String = "disc_sponsor_match"
const REASON_SUMMONS_MATCH: String = "disc_summons_match"
const REASON_SUMMONS_NAME: String = "disc_summons_name"
const REASON_RETIRED: String = "disc_retired"
## M13 (docs/M13.md §1.8, §2.5) : puce ↔ champ (déclaration contradictoire,
## réponse imprécise, provenance, réponse en prose libre d'un cas scénarisé,
## puce pas encore obtenue) ; objet de fouille ↔ règle ou onglet Contrebande
## (objet interdit, arme, objet autorisé, contenu illisible).
const REASON_STATEMENT_MISMATCH: String = "disc_statement_mismatch"
const REASON_STATEMENT_VAGUE: String = "disc_statement_vague"
const REASON_STATEMENT_FREE: String = "disc_statement_free"
const REASON_STATEMENT_NOT_GIVEN: String = "disc_statement_not_given"
const REASON_PROVENANCE: String = "disc_provenance"
const REASON_CONTRABAND: String = "disc_contraband"
const REASON_WEAPON: String = "disc_weapon"
const REASON_ITEM_ALLOWED: String = "disc_item_allowed"
const REASON_SCAN_UNREADABLE: String = "disc_scan_unreadable"

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
