## Résultat d'un cas après le tampon (ARCHITECTURE §5.3, §7 ; GDD §4.6, §5.1)
## — émis par `EventBus.case_resolved`.
##
## Produit par `ScoringService.score()` (notation, preuve, procédures,
## citation), complété par le `DayController` (numéro de citation du jour,
## amende, drapeaux narratifs). Les violations attendues ne sont **révélées**
## qu'ici, après le verdict (feedback pédagogique du bilan).
## Le booth n'en lit que `verdict_kind` (choix de la sortie).
class_name CaseResult
extends RefCounted

var case_id: StringName = &""
## Index 0-based du cas dans la file du jour.
var case_index: int = 0
## Nom présenté (« E. VALCOURT ») — affichage du registre de fin de shift.
var passenger_label: String = ""
## Verdict tamponné par le joueur.
var verdict_kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE
## Verdict attendu (`CaseKey.expected_verdict`), révélé après le tampon.
var expected_verdict: VerdictKind.Kind = VerdictKind.Kind.APPROVE
## Verdict juste **et** procédure respectée (GDD §5.1 : « ✗ (procédure) »).
var correct: bool = false
## Verdict juste, indépendamment de la procédure et de la preuve.
var verdict_correct: bool = false
## Refus / détention appuyé par une discordance confirmée (D-024, D-032).
var documented: bool = false
## Toutes les violations du cas (révélées après le verdict).
var expected_violations: Array[Violation] = []
## Violations non sanctionnées (approbation d'un cas fautif) ou non
## documentées (refus non motivé) : feedback du bilan.
var missed_violations: Array[Violation] = []
## Temps d'inspection depuis `documents_presented`.
var elapsed_sec: float = 0.0
## Le verdict tamponné (discordances épinglées, questions posées).
var verdict: Verdict = null
## Salaire du cas (+5 ₵, + prime de détention), avant amende.
var wage: int = 0
## Amende de la citation (0 pour un avertissement).
var fine: int = 0
## Net du cas : `wage - fine`.
var credits_delta: int = 0
## Citation émise (`cit_*`, GDD §4.6), vide sinon. Au plus une par cas.
var citation_reason_key: String = ""
## Règle enfreinte citée sur le ticket (vide pour une erreur sans règle).
var citation_rule_id: StringName = &""
## Rang de la citation dans la journée (1, 2, 3…), 0 sans citation.
var citation_number: int = 0
## Procédure manquée (`ProcedureRule.procedure_id`), vide sinon.
var procedure_missed: StringName = &""
## Cas scénarisé (`ScriptedCaseDef.id`), vide sinon.
var scripted_id: StringName = &""
## Drapeaux narratifs modifiés par ce cas : `{flag: valeur}`.
var narrative_changes: Dictionary[StringName, Variant] = {}
## M7 : décisions finales sur les objets glissés `{item_id: SlippedItem.Decision}`.
var item_decisions: Dictionary[StringName, int] = {}
## Enveloppes gardées (₵, « divers non déclaré » : hors salaire et hors score).
var bribe_credits: int = 0
## Primes de signalement (objet remis à la Garde).
var report_credits: int = 0
## Le passager a reçu la réponse à la phrase de passe (code 4).
var password_answered: bool = false
## M7 (NARRATIVE §4.9) : DÉTENTION d'un porteur du code 1 documentée par la
## paire marque ↔ bulletin = signalement valide (cas correct, sans citation).
var luciole_report: bool = false
## Acte II (R23, D-077) : le passager compte dans le quota respiratoire.
var quota_counted: bool = false
## Acte II : le quota était atteint au moment du tampon (passager compté).
var quota_full: bool = false
## Acte II : REFUS motivé par le seul quota (correct, documenté d'office).
var quota_refusal: bool = false
## Acte II : entrée **imputée** au guichet (APPROUVÉ au-delà du quota : 0 ₵).
var quota_overrun: bool = false


func _init(p_case_id: StringName = &"") -> void:
	case_id = p_case_id


func has_citation() -> bool:
	return not citation_reason_key.is_empty()


## M11, mode Récit (D-102) : citation gardée (comptée), amende à 0 ₵.
func waive_fine() -> void:
	fine = 0
	credits_delta = wage


## Avertissement : citation sans amende (les `free_citations_per_day` premières).
func is_warning() -> bool:
	return has_citation() and fine == 0
