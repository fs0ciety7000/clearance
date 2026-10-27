## Famille « Motif et durée conformes » (R09, GDD §6 `PURPOSE_MISMATCH`, M7).
##
## Sur le permis d'entrée : (1) motif TRAVAIL sans employeur (« SANS
## EMPLOYEUR ») ; (2) classe `C-4` (carte) avec un séjour > `short_stay_max`
## jours ; (3) séjour plus long que la validité restante d'un permis non expiré.
## Une violation par contrôle enfreint ; preuves : le champ fautif, la règle,
## le champ de référence (ordre choisi pour que les deux premières références
## forment une comparaison confirmable « champ ↔ règle »).
class_name PurposeConsistentRule
extends Rule

const CHECK_EMPLOYER: StringName = &"employer"
const CHECK_CLASS_STAY: StringName = &"class_stay"
const CHECK_VALIDITY: StringName = &"validity"

@export var permit_id: StringName = &"entry_permit"
@export var card_id: StringName = &"id_card"
@export var work_purpose: StringName = Passenger.PURPOSE_WORK
## Valeurs d'employeur équivalentes à « aucun » (comparées en capitales).
@export var no_employer_values: PackedStringArray = ["", "SANS EMPLOYEUR"]
@export var short_stay_class: StringName = &"C-4"
@export var short_stay_max: int = 30


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for check: StringName in failed_checks(case, ctx):
		violations.append(make_violation(evidence(case, check), "viol_purpose_%s" % check))
	return violations


## Contrôles enfreints (`CHECK_*`), dans l'ordre.
func failed_checks(case: Case, ctx: RuleContext) -> Array[StringName]:
	var failed: Array[StringName] = []
	var permit: DocumentInstance = case.get_document(permit_id)
	if permit == null:
		return failed
	var purpose: Variant = _value(case, permit_id, &"purpose")
	var employer: Variant = _value(case, permit_id, &"employer")
	if purpose != null and FieldValue.equals(purpose, work_purpose) and _is_no_employer(employer):
		failed.append(CHECK_EMPLOYER)
	var stay: Variant = _value(case, permit_id, &"stay_days")
	var citizen_class: Variant = _value(case, card_id, &"citizen_class")
	if stay is int and citizen_class != null and FieldValue.equals(citizen_class, short_stay_class):
		var days: int = stay
		if days > short_stay_max:
			failed.append(CHECK_CLASS_STAY)
	if stay is int and permit.expiry_date >= ctx.today:
		var stay_days: int = stay
		if stay_days > permit.expiry_date - ctx.today:
			failed.append(CHECK_VALIDITY)
	return failed


## Références qui prouvent un contrôle enfreint.
func evidence(case: Case, check: StringName) -> Array[FieldRef]:
	var refs: Array[FieldRef] = []
	match check:
		CHECK_EMPLOYER:
			_append(refs, Rule.find_ref(case, permit_id, &"employer"))
			refs.append(get_ref())
			_append(refs, Rule.find_ref(case, permit_id, &"purpose"))
		CHECK_CLASS_STAY:
			_append(refs, Rule.find_ref(case, permit_id, &"stay_days"))
			refs.append(get_ref())
			_append(refs, Rule.find_ref(case, card_id, &"citizen_class"))
		CHECK_VALIDITY:
			_append(refs, Rule.find_ref(case, permit_id, &"stay_days"))
			refs.append(get_ref())
			_append(refs, Rule.find_ref(case, permit_id, &"document.expiry_date"))
	return refs


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.PURPOSE_MISMATCH]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var relevant: bool = false
	var failed: Array[StringName] = failed_checks(case, ctx)
	for check: StringName in [CHECK_EMPLOYER, CHECK_CLASS_STAY, CHECK_VALIDITY]:
		for own: FieldRef in evidence(case, check):
			if own.equals(ref):
				relevant = true
				if failed.has(check):
					return Discrepancy.Result.DISCORDANT
	return Discrepancy.Result.CONCORDANT if relevant else Discrepancy.Result.INCOMPARABLE


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {permit_id: [&"purpose", &"employer", &"stay_days"], card_id: [&"citizen_class"]}


func _is_no_employer(value: Variant) -> bool:
	var text: String = str(value).strip_edges().to_upper() if value != null else ""
	for empty: String in no_employer_values:
		if text == empty.to_upper():
			return true
	return false


static func _value(case: Case, document_id: StringName, path: StringName) -> Variant:
	var ref: FieldRef = Rule.find_ref(case, document_id, path)
	return case.get_value(ref) if ref != null else null


static func _append(refs: Array[FieldRef], ref: FieldRef) -> void:
	if ref != null:
		refs.append(ref)
