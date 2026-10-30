## Famille « Implants déclarés » (R15, GDD §6 `UNDECLARED_IMPLANT`, LORE §8, M7).
##
## Les implants visibles sur le passager (`passenger_presented.implants`)
## doivent être exactement ceux de la liste « Implants déclarés » de la carte.
## Preuve : visage du passager ↔ champ déclaré (comparaison du mode Inspection).
## Sévérité : celle de la règle, portée à `escalated_severity` (DÉTENTION) si
## un implant non déclaré commence par un préfixe de `escalated_prefixes`
## (`MIL-`) à partir du jour `escalated_from_day` (GDD §7 : J7).
## M13 (docs/M13.md §2.5, D-147 ; B71) : à partir de `concealed_from_day` (J8,
## portique), un implant déclaré de **localisation dissimulée**
## (`concealable_codes`, table `ImplantCatalog.location` des données) absent du
## visage est « non visible — fouille » : jamais comparé au visage. Un implant
## dissimulé **trouvé** (objet `IMPLANT` du `SearchLayout`) absent de la liste
## est une violation (`CONCEALED_IMPLANT`), preuve : objet ↔ champ déclaré ;
## `MIL-` → sévérité 3 comme un implant visible. Le verdict existe sans
## fouille (D-005) ; un implant illisible (`DER-19` blindé) reste un implant.
class_name ImplantsDeclaredRule
extends Rule

@export var document_id: StringName = &"id_card"
@export var escalated_prefixes: PackedStringArray = ["MIL-"]
@export var escalated_from_day: int = 7
@export var escalated_severity: int = 3
## M13 : codes de localisation dissimulable et premier jour du portique.
@export var concealable_codes: PackedStringArray = []
@export var concealed_from_day: int = 8


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var ref: FieldRef = Rule.find_ref(case, document_id, &"implants")
	if ref == null or case.passenger_presented == null:
		return violations
	var declared: PackedStringArray = FieldValue.normalize(as_list(case.get_value(ref)))
	var visible: PackedStringArray = FieldValue.normalize(case.passenger_presented.implants)
	if face_declared(declared, visible, ctx) != visible:
		var violation: Violation = make_violation([FieldRef.passenger_face(), ref, get_ref()], "viol_implant_undeclared")
		_escalate(violation, visible, declared, ctx)
		violations.append(violation)
	# M13 : implants dissimulés non déclarés (trouvés à la fouille).
	if case.search_layout != null:
		for item: SearchItem in case.search_layout.items:
			if not item.is_implant() or item.implant_code.is_empty():
				continue
			var code: String = FieldValue.normalize(PackedStringArray([item.implant_code]))[0]
			if declared.has(code):
				continue
			var hidden: Violation = make_violation([item.get_ref(), ref, get_ref()], "viol_implant_concealed")
			_escalate(hidden, PackedStringArray([code]), declared, ctx)
			violations.append(hidden)
	return violations


## Implants déclarés **comparés au visage** : la liste de la carte, moins (J8+)
## les codes de localisation dissimulable qui ne sont pas visibles (« non
## visible — fouille »). Listes normalisées.
func face_declared(declared: PackedStringArray, visible: PackedStringArray, ctx: RuleContext) -> PackedStringArray:
	if concealable_codes.is_empty() or ctx == null or ctx.get_day_number() < concealed_from_day:
		return declared
	var result: PackedStringArray = []
	for code: String in declared:
		if visible.has(code) or not is_concealable(code):
			result.append(code)
	return result


## Vrai si le code est de localisation dissimulable (comparaison normalisée).
func is_concealable(code: String) -> bool:
	for concealable: String in concealable_codes:
		if FieldValue.equals(concealable, code):
			return true
	return false


## Déclarés « non visible — fouille » de la carte (onglet Implants, J8+).
func hidden_declared(case: Case, ctx: RuleContext) -> PackedStringArray:
	var ref: FieldRef = Rule.find_ref(case, document_id, &"implants")
	if ref == null or case.passenger_presented == null:
		return PackedStringArray()
	var declared: PackedStringArray = FieldValue.normalize(as_list(case.get_value(ref)))
	var visible: PackedStringArray = FieldValue.normalize(case.passenger_presented.implants)
	var shown: PackedStringArray = face_declared(declared, visible, ctx)
	var result: PackedStringArray = []
	for code: String in declared:
		if not shown.has(code):
			result.append(code)
	return result


func _escalate(violation: Violation, codes: PackedStringArray, declared: PackedStringArray, ctx: RuleContext) -> void:
	if ctx == null or ctx.get_day_number() < escalated_from_day:
		return
	for code: String in codes:
		if declared.has(code):
			continue
		for prefix: String in escalated_prefixes:
			if code.begins_with(prefix):
				violation.severity = maxi(violation.severity, escalated_severity)


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.UNDECLARED_IMPLANT, AnomalyType.Kind.CONCEALED_IMPLANT]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	if ref.is_scan():
		# M13 : implant trouvé ↔ R15 (déclaré ou non sur la carte).
		var item: SearchItem = case.get_scan_item(ref)
		if item == null or not item.is_implant() or item.implant_code.is_empty():
			return Discrepancy.Result.INCOMPARABLE
		var listed: PackedStringArray = FieldValue.normalize(case.declared_implants())
		var code: String = FieldValue.normalize(PackedStringArray([item.implant_code]))[0]
		return Discrepancy.Result.CONCORDANT if listed.has(code) else Discrepancy.Result.DISCORDANT
	var field: FieldDef = case.get_field_def(ref)
	if ref.document_id != document_id or field == null or field.truth_path != &"implants":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if not evaluate(case, ctx).is_empty() else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"implants"]}


## Liste de codes d'une valeur de champ LIST (vide si absente).
static func as_list(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var result: PackedStringArray = []
	if value is Array:
		for item: Variant in value:
			result.append(str(item))
	return result
