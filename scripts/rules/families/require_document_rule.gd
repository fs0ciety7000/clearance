## Famille « Documents requis » (R01, R04, R11 ; Acte II : R24 contrat de
## travail, R26 laissez-passer de dérive via `DriftPassRule`, R28 attestation
## d'asile) : le dossier doit contenir un document donné, sauf pour les origines
## dispensées (R04 : `HAL` sans permis).
##
## Acte II (B21) : conditions d'application lues **sur les documents visibles**
## — origine (`applies_to_faction_ids`), motif du permis (`applies_to_purposes`,
## R24 : TRAVAIL), classe de la carte (`applies_to_classes`, R28 : C-5) ; avec
## `require_valid`, le document doit aussi être non expiré (« non expiré »,
## R24, R28 : violation d'expiration prouvée par le champ « Valide jusqu'au »).
## Un document **d'un tiers** (SC-27) ne compte pas (`Case.get_own_document`).
##
## Anomalies détectées : `MISSING_DOCUMENT` (+ `EXPIRED_DOCUMENT` si
## `require_valid`). Preuve : la règle du Rulebook comparée à n'importe quel
## document du dossier (GDD §4.1), ou l'expiration du document.
class_name RequireDocumentRule
extends Rule

const EXPIRY_PATH: StringName = &"document.expiry_date"

@export var document_id: StringName = &""
## Origines dispensées (`FactionDef.id`), lues sur l'origine visible.
@export var exempt_faction_ids: Array[StringName] = []
## Acte II : origines concernées (vide = toutes).
@export var applies_to_faction_ids: Array[StringName] = []
## Acte II : motifs du permis concernés (vide = tous ; sans permis visible, la
## règle ne s'applique pas).
@export var applies_to_purposes: Array[StringName] = []
## Acte II : classes citoyennes de la carte concernées (vide = toutes).
@export var applies_to_classes: Array[StringName] = []
## Acte II : le document doit aussi être non expiré.
@export var require_valid: bool = false
@export var permit_id: StringName = &"entry_permit"
@export var card_id: StringName = &"id_card"


func applies_to(case: Case) -> bool:
	var origin: StringName = Rule.visible_origin(case)
	if exempt_faction_ids.has(origin):
		return false
	if not applies_to_faction_ids.is_empty() and not applies_to_faction_ids.has(origin):
		return false
	if not applies_to_purposes.is_empty():
		var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
		if purpose == null or not _has_value(applies_to_purposes, purpose):
			return false
	if not applies_to_classes.is_empty():
		var citizen_class: Variant = PurposeConsistentRule._value(case, card_id, &"citizen_class")
		if citizen_class == null:
			citizen_class = case.passenger_presented.citizen_class if case.passenger_presented != null else null
		if citizen_class == null or not _has_value(applies_to_classes, citizen_class):
			return false
	return true


## Générateur : le document est-il exigé pour ce passager (vérité, permis
## présent ou non) ? Même lecture que `applies_to` sur un dossier conforme.
func requires_for(p: Passenger, has_permit: bool) -> bool:
	if exempt_faction_ids.has(p.faction_id):
		return false
	if not applies_to_faction_ids.is_empty() and not applies_to_faction_ids.has(p.faction_id):
		return false
	if not applies_to_purposes.is_empty() and (not has_permit or not applies_to_purposes.has(p.purpose)):
		return false
	if not applies_to_classes.is_empty() and not applies_to_classes.has(p.citizen_class):
		return false
	return true


## Vrai si la règle porte une condition sur le motif ou la classe (2ᵉ passe du
## générateur, après les documents inconditionnels).
func is_conditional() -> bool:
	return not applies_to_purposes.is_empty() or not applies_to_classes.is_empty()


func is_missing(case: Case) -> bool:
	return applies_to(case) and not case.has_own_document(document_id)


func is_expired(case: Case, ctx: RuleContext) -> bool:
	if not require_valid or ctx == null or not applies_to(case):
		return false
	var doc: DocumentInstance = case.get_own_document(document_id)
	# Acte III (R32) : prorogation de Continuité comprise.
	return doc != null and ctx.is_document_expired(doc.expiry_date)


func is_violated(case: Case) -> bool:
	return is_missing(case)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if is_missing(case):
		violations.append(make_violation([get_ref()], "viol_missing_document"))
	elif is_expired(case, ctx):
		var refs: Array[FieldRef] = []
		PurposeConsistentRule._append(refs, Rule.find_ref(case, document_id, EXPIRY_PATH))
		refs.append(get_ref())
		violations.append(make_violation(refs, "viol_document_expired"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	if require_valid:
		return [AnomalyType.Kind.MISSING_DOCUMENT, AnomalyType.Kind.EXPIRED_DOCUMENT]
	return [AnomalyType.Kind.MISSING_DOCUMENT]


## Règle ↔ n'importe quel champ d'un document présent (« le dossier ») ; avec
## `require_valid`, l'expiration du document exigé est discordante s'il est périmé.
func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	if not case.has_field(ref):
		return Discrepancy.Result.INCOMPARABLE
	if is_missing(case):
		return Discrepancy.Result.DISCORDANT
	if require_valid and ref.document_id == document_id:
		var field: FieldDef = case.get_field_def(ref)
		if field != null and field.truth_path == EXPIRY_PATH and is_expired(case, ctx):
			return Discrepancy.Result.DISCORDANT
	return Discrepancy.Result.CONCORDANT


func get_required_document_ids() -> Array[StringName]:
	return [document_id]


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	if require_valid:
		return {document_id: [EXPIRY_PATH]}
	return {document_id: []}


static func _has_value(list: Array[StringName], value: Variant) -> bool:
	for item: StringName in list:
		if FieldValue.equals(item, value):
			return true
	return false
