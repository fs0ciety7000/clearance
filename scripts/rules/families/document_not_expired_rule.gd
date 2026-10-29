## Famille « Document non expiré » (R02, R05, R12).
##
## Par défaut : violation si `expiry_date < today` (valide le jour même de
## l'expiration). Avec `max_age_days > 0` (R12 « bio-scan émis il y a moins de
## 30 jours ») : violation si `today − issue_date ≥ max_age_days`.
## Un document absent n'est pas une violation ici (cf. `RequireDocumentRule`).
## Anomalie détectée : `EXPIRED_DOCUMENT`.
## Acte II (R27, firmware NX < 90 jours) : `field_path` désigne un champ date du
## passager recopié sur le document (`firmware_date`) dont l'**âge** est
## contrôlé (`max_age_days`) ; champ vide (pas de shunt `NX-`) = conforme ;
## anomalie détectée paramétrable (`OUTDATED_FIRMWARE`).
class_name DocumentNotExpiredRule
extends Rule

const EXPIRY_PATH: StringName = &"document.expiry_date"
const ISSUE_PATH: StringName = &"document.issue_date"

@export var document_id: StringName = &""
## 0 = date d'expiration imprimée ; > 0 = âge maximal depuis l'émission, en jours.
@export var max_age_days: int = 0
## Acte II : champ daté contrôlé à la place de l'émission (`firmware_date`).
@export var field_path: StringName = &""
## Anomalies détectées (vide = `EXPIRED_DOCUMENT`).
@export var detected_anomalies: Array[AnomalyType.Kind] = []


## M12 (B54, EV-03 « Alerte de quarantaine ») : âge maximal en vigueur pour ce
## cas — surcharge de shift `max_age_days` (`RuleContext.param`, portée par
## origine : `TYC` 7 jours au lieu de 30), sinon `max_age_days`.
func effective_max_age(ctx: RuleContext = null, case: Case = null) -> int:
	if ctx == null or max_age_days <= 0:
		return max_age_days
	var value: Variant = ctx.param(id, &"max_age_days", max_age_days, case)
	return value if value is int else max_age_days


## Champ qui prouve la violation (expiration, ou émission si `max_age_days`).
func get_evidence_path() -> StringName:
	if field_path != &"":
		return field_path
	return ISSUE_PATH if max_age_days > 0 else EXPIRY_PATH


## Acte III (R32) : `ctx` fourni, un document expiré dans la fenêtre de
## prorogation est valide (`RuleContext.is_document_expired`).
func is_expired(doc: DocumentInstance, today: int, ctx: RuleContext = null, case: Case = null) -> bool:
	var max_age: int = effective_max_age(ctx, case)
	if field_path != &"":
		var field: FieldDef = doc.type_def.find_field_by_truth_path(field_path) if doc.type_def != null else null
		var value: Variant = doc.get_value(field.id) if field != null else null
		if not value is int:
			return false
		var date: int = value
		return date > 0 and today - date >= max_age
	if max_age > 0:
		return today - doc.issue_date >= max_age
	if ctx != null:
		return ctx.is_document_expired(doc.expiry_date)
	return doc.expiry_date < today


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var doc: DocumentInstance = case.get_document(document_id)
	if doc == null or not is_expired(doc, ctx.today, ctx, case):
		return violations
	var refs: Array[FieldRef] = []
	var evidence: FieldRef = Rule.find_ref(case, document_id, get_evidence_path())
	if evidence != null:
		refs.append(evidence)
	refs.append(get_ref())
	violations.append(make_violation(refs, "viol_document_expired"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	if not detected_anomalies.is_empty():
		return detected_anomalies.duplicate()
	return [AnomalyType.Kind.EXPIRED_DOCUMENT]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	if ref.document_id != document_id:
		return Discrepancy.Result.INCOMPARABLE
	var field: FieldDef = case.get_field_def(ref)
	if field == null or field.truth_path != get_evidence_path():
		return Discrepancy.Result.INCOMPARABLE
	var doc: DocumentInstance = case.get_document(document_id)
	return Discrepancy.Result.DISCORDANT if is_expired(doc, ctx.today, ctx, case) else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [get_evidence_path()]}
