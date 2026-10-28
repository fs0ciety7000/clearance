## Règles actives d'un jour (ARCHITECTURE §5.2) : `ruleset_day_NN.tres`.
##
## Liste **explicite et cumulative** par jour (pas d'héritage entre jours) ;
## les `Rule` sont des `.tres` partagés. Une règle absente du RuleSet est
## désactivée : le `RuleEngine` ne l'évalue pas.
class_name RuleSet
extends Resource

@export var id: StringName = &""
@export var rules: Array[Rule] = []
## Badge « NOUVEAU » au Rulebook.
@export var new_rule_ids: Array[StringName] = []
## Documents exigés (dérivé des `RequireDocumentRule`, vérifié par les tests de données).
@export var required_document_ids: Array[StringName] = []


func get_rule(rule_id: StringName) -> Rule:
	for rule: Rule in rules:
		if rule != null and rule.id == rule_id:
			return rule
	return null


func has_rule(rule_id: StringName) -> bool:
	return get_rule(rule_id) != null


func get_rule_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule: Rule in rules:
		if rule != null:
			ids.append(rule.id)
	return ids


## Rulebook du jour, dans l'ordre du RuleSet, avec le badge « NOUVEAU ».
func build_rulebook() -> Array[RulebookEntry]:
	var entries: Array[RulebookEntry] = []
	for rule: Rule in rules:
		if rule == null:
			continue
		var entry: RulebookEntry = rule.get_rulebook_entry()
		entry.is_new = new_rule_ids.has(rule.id)
		entries.append(entry)
	return entries


## Union des anomalies détectables par les règles actives (sans doublon).
func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	for rule: Rule in rules:
		if rule == null:
			continue
		for kind: AnomalyType.Kind in rule.get_detectable_anomalies():
			if not kinds.has(kind):
				kinds.append(kind)
	return kinds


func can_detect(kind: AnomalyType.Kind) -> bool:
	return get_detectable_anomalies().has(kind)


## Documents exigés par les règles actives (sans doublon, ordre des règles).
func compute_required_document_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule: Rule in rules:
		if rule == null:
			continue
		for document_id: StringName in rule.get_required_document_ids():
			if not ids.has(document_id):
				ids.append(document_id)
	return ids
