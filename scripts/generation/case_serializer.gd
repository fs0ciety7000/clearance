## Sérialisation stable d'un cas et de sa clé (tests de déterminisme, golden
## files, outil de stats). Pure ; les dictionnaires produits sont comparables
## par `JSON.stringify` (clés triées).
## M13 (format 2, ARCHITECTURE §12.10) : `version`, déclarations orales
## (`statements`, `statement_frames`), fouille (`search_layout`,
## `search_cues`, `cargo_reply`, `cargo_line_key`) ; `concealed_implants`
## suit `Passenger.TRUTH_PATHS`. L'état de session (`Statement.given`,
## objets révélés) n'est pas sérialisé : le cas sérialisé est celui de la
## construction.
class_name CaseSerializer
extends RefCounted

## Version du format (1 : jusqu'à la 0.12 ; 2 : M13).
const VERSION: int = 2


static func to_json(generated: GeneratedCase) -> String:
	return JSON.stringify({"version": VERSION, "case": serialize_case(generated.case), "key": serialize_key(generated.key)},
			"", true)


static func serialize_case(c: Case) -> Dictionary:
	var docs: Array = []
	for doc: DocumentInstance in c.documents:
		docs.append(serialize_document(doc))
	var tags: Array = []
	for tag: StringName in c.dialogue_tags:
		tags.append(String(tag))
	var items: Array = []
	for item: SlippedItem in c.slipped_items:
		items.append({"id": String(item.id), "kind": SlippedItem.Kind.find_key(item.kind), "amount": item.amount,
				"text_key": item.text_key, "extra": Array(item.extra_text_keys), "default": item.default_decision})
	return {
		"case_id": String(c.case_id),
		"index": c.index,
		"case_seed": str(c.case_seed),
		"passenger": serialize_passenger(c.passenger_presented),
		"documents": docs,
		"dialogue_tags": tags,
		# M7
		"luciole_codes": Array(c.luciole_codes),
		"presentation": String(c.presentation),
		"slipped_items": items,
		# M13
		"statements": serialize_statements(c.statements),
		"statement_frames": _string_dict(c.statement_frames),
		"search_layout": c.search_layout.serialize() if c.search_layout != null else null,
		"search_cues": c.search_cues.map(func(cue: StringName) -> String: return String(cue)),
		"cargo_reply": String(c.cargo_reply),
		"cargo_line_key": c.cargo_line_key,
	}


static func serialize_statements(statements: Array[Statement]) -> Array:
	var result: Array = []
	for statement: Statement in statements:
		result.append(statement.serialize())
	return result


static func _string_dict(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[str(key)] = str(source[key])
	return result


static func serialize_key(key: CaseKey) -> Dictionary:
	var anomalies: Array = []
	for anomaly: Anomaly in key.anomalies:
		anomalies.append({
			"type": AnomalyType.name_of(anomaly.type),
			"document_id": String(anomaly.document_id),
			"field_id": String(anomaly.field_id),
			"original": value_to_variant(anomaly.original_value),
			"injected": value_to_variant(anomaly.injected_value),
			"cosmetic": anomaly.cosmetic,
		})
	var violations: Array = []
	for violation: Violation in key.expected_violations:
		var refs: Array = []
		for ref: FieldRef in violation.refs:
			refs.append(ref.key())
		violations.append({"rule_id": String(violation.rule_id), "refs": refs,
				"reason_key": violation.reason_key, "severity": violation.severity})
	return {
		"truth": serialize_passenger(key.truth),
		"anomalies": anomalies,
		"violations": violations,
		"verdict": VerdictKind.Kind.find_key(key.expected_verdict),
	}


static func serialize_passenger(p: Passenger) -> Dictionary:
	if p == null:
		return {}
	var result: Dictionary = {"id": String(p.id), "appearance_seed": str(p.appearance_seed)}
	for path: StringName in Passenger.TRUTH_PATHS:
		result[String(path)] = value_to_variant(p.get(path))
	return result


static func serialize_document(doc: DocumentInstance) -> Dictionary:
	var values: Dictionary = {}
	for field_id: StringName in doc.values:
		values[String(field_id)] = value_to_variant(doc.values[field_id])
	return {
		"type": String(doc.get_document_id()),
		"serial": doc.serial,
		"issue_date": doc.issue_date,
		"expiry_date": doc.expiry_date,
		"issuer_id": String(doc.issuer_id),
		"seal_id": String(doc.seal_id),
		"mrz": doc.mrz,
		"marks": doc.marks.map(func(mark: StringName) -> String: return String(mark)),
		"values": values,
	}


## Valeur de champ ou d'anomalie → variante JSON (types préservés en texte).
static func value_to_variant(value: Variant) -> Variant:
	if value is PassengerAppearance:
		var app: PassengerAppearance = value
		return app.serialize()
	if value is PortraitValue:
		var portrait: PortraitValue = value
		return {"appearance": value_to_variant(portrait.appearance), "photo_seed": portrait.photo_seed,
				"years_before_issue": portrait.years_before_issue}
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			var text: StringName = value
			return String(text)
		TYPE_DICTIONARY:
			var source: Dictionary = value
			var result: Dictionary = {}
			for key: Variant in source:
				result[str(key)] = value_to_variant(source[key])
			return result
		TYPE_PACKED_STRING_ARRAY:
			var list: PackedStringArray = value
			return Array(list)
	return var_to_str(value)
