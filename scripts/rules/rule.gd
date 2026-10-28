## Règle du Rulebook (ARCHITECTURE §6) — classe de base abstraite.
##
## Paramétrage par `.tres`, comportement par sous-classe : chaque *famille* de
## règle est une sous-classe (`scripts/rules/families/`), chaque *règle
## concrète* est un `.tres` dans `res://data/rules/`.
## Règles **pures** : pas d'état, pas d'aléa, pas d'arbre de scène ; une règle
## est partagée entre RuleSets et ne doit jamais être mutée au runtime.
@abstract
class_name Rule
extends Resource

enum RuleCategory { DOCUMENTS, IDENTITY, FACTION, PURPOSE, SPECIAL }

@export var id: StringName = &""
@export var title_key: String = ""
@export var rulebook_text_key: String = ""
@export var category: RuleCategory = RuleCategory.DOCUMENTS
## 1 = procédure, 2 = refus, ≥ 3 = détention (`RuleEngine.DETAIN_SEVERITY`).
@export_range(1, 3) var severity: int = 2


## Violations de cette règle sur le cas présenté (vide = conforme).
func evaluate(_case: Case, _ctx: RuleContext) -> Array[Violation]:
	return []


## Types d'anomalies que cette règle détecte (filtrage du générateur, §6).
func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return []


## Comparaison « champ ↔ règle » du mode Inspection (GDD §4.1) : la valeur
## désignée par `ref` est-elle conforme à cette règle ? Par défaut INCOMPARABLE.
func check_against(_case: Case, _ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	return Discrepancy.Result.INCOMPARABLE


## Documents exigés par cette règle (dérivation de `RuleSet.required_document_ids`).
func get_required_document_ids() -> Array[StringName]:
	return []


## Champs exigés par cette règle : `{document_id: [truth_path…]}`. Le test de
## validation des données vérifie que chaque document existe et porte ces champs.
func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {}


func get_rulebook_entry() -> RulebookEntry:
	var entry: RulebookEntry = RulebookEntry.new()
	entry.rule_id = id
	entry.title_key = title_key
	entry.text_key = rulebook_text_key
	entry.category = category
	entry.severity = severity
	entry.ref = get_ref()
	return entry


## Référence Rulebook de cette règle (sélectionnable en mode Inspection).
func get_ref() -> FieldRef:
	return FieldRef.rulebook_rule(id)


func make_violation(refs: Array[FieldRef], reason_key: String) -> Violation:
	return Violation.new(id, refs, reason_key, severity)


## Origine **visible** du passager : premier champ « Origine » (`faction_id`)
## des documents présentés, sinon l'origine déclarée du passager présenté.
static func visible_origin(case: Case) -> StringName:
	for ref: FieldRef in case.find_refs_by_truth_path(&"faction_id"):
		var value: Variant = case.get_value(ref)
		if value != null:
			return StringName(str(value))
	return case.passenger_presented.faction_id if case.passenger_presented != null else &""


## Référence du premier champ d'un document portant ce `truth_path`, ou null.
static func find_ref(case: Case, document_id: StringName, truth_path: StringName) -> FieldRef:
	var doc: DocumentInstance = case.get_document(document_id)
	if doc == null:
		return null
	var field: FieldDef = doc.type_def.find_field_by_truth_path(truth_path)
	return FieldRef.new(document_id, field.id) if field != null else null
