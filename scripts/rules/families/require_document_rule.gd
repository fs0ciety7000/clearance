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
## M12 (R39 « Accueil », B55) : le document n'est pas exigé si le porteur
## présente un **répondant valide** (N° ID d'un·e Né·e-Halcyon C-1 à C-3
## admis·e aujourd'hui à cette vitre, Main courante), lu sur n'importe lequel
## de ses documents (`sponsor_id` : permis, carte de répondant).
@export var exempt_if_sponsor: bool = false

## M12 (B54, événements) : paramètres surchargeables en cours de shift
## (`RuleContext.param`) — `exempt` (bool : la règle ne s'applique pas au
## passager, EV-08 « TRANSIT dispensé de bio-scan » de 13:00 à 14:00).
const PARAM_EXEMPT: StringName = &"exempt"
const PARAM_EXEMPT_PURPOSES: StringName = &"exempt_purposes"


func applies_to(case: Case, ctx: RuleContext = null) -> bool:
	if ctx != null and ctx.param(id, PARAM_EXEMPT, false, case) == true:
		return false
	# Variante : motifs dispensés (`exempt_purposes`, lus sur le permis ou le
	# motif déclaré).
	if ctx != null:
		var exempt: Variant = ctx.param(id, PARAM_EXEMPT_PURPOSES, [], case)
		if exempt is Array and not (exempt as Array).is_empty():
			var purpose: Variant = PurposeConsistentRule._value(case, permit_id, &"purpose")
			if purpose == null and case.passenger_presented != null:
				purpose = case.passenger_presented.purpose
			for item: Variant in exempt:
				if purpose != null and FieldValue.equals(item, purpose):
					return false
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


func is_missing(case: Case, ctx: RuleContext = null) -> bool:
	if not applies_to(case, ctx) or case.has_own_document(document_id):
		return false
	return not (exempt_if_sponsor and SponsorRule.has_listed_sponsor(case, ctx))


func is_expired(case: Case, ctx: RuleContext) -> bool:
	if not require_valid or ctx == null or not applies_to(case, ctx):
		return false
	var doc: DocumentInstance = case.get_own_document(document_id)
	# Acte III (R32) : prorogation de Continuité comprise.
	return doc != null and ctx.is_document_expired(doc.expiry_date)


func is_violated(case: Case, ctx: RuleContext = null) -> bool:
	return is_missing(case, ctx)


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	if is_missing(case, ctx):
		var refs: Array[FieldRef] = [get_ref()]
		# M12 (R39) : le répondant présenté (non admis) prouve aussi le refus.
		if exempt_if_sponsor:
			PurposeConsistentRule._append(refs, SponsorRule.find_sponsor_ref(case))
		violations.append(make_violation(refs, "viol_missing_document"))
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
	if is_missing(case, ctx):
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
