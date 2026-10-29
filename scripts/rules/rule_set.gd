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
## Acte III (M1 « Retour aux quais », B37) : règles retirées ce jour, affichées
## barrées au Rulebook (jamais évaluées) ; motif par règle (`rb_retired_*`).
@export var retired_rules: Array[Rule] = []
@export var retired_note_keys: Dictionary[StringName, String] = {}
## Acte III : note du jour sous une règle active (`r_air_quota` →
## `rb_suspended_quota`).
@export var rule_note_keys: Dictionary[StringName, String] = {}


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
		entry.note_key = rule_note_keys.get(rule.id, "")
		entries.append(entry)
	return entries


## Acte III (M1, I21) : lignes barrées des règles retirées ce jour (motif dans
## `note_key`, `retired` vrai). Séparées de `build_rulebook()` : l'UI qui ne
## les connaît pas n'affiche pas une règle retirée comme active.
func build_retired_entries() -> Array[RulebookEntry]:
	var entries: Array[RulebookEntry] = []
	for rule: Rule in retired_rules:
		if rule == null:
			continue
		var entry: RulebookEntry = rule.get_rulebook_entry()
		entry.retired = true
		entry.note_key = retired_note_keys.get(rule.id, "")
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
