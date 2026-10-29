## Règles actives d'un jour (ARCHITECTURE §5.2) : `ruleset_day_NN.tres`.
##
## Liste **explicite et cumulative** par jour (pas d'héritage entre jours) ;
## les `Rule` sont des `.tres` partagés. Une règle absente du RuleSet est
## désactivée : le `RuleEngine` ne l'évalue pas.
##
## M12 (B54, ARCHITECTURE §11.3) — **règles mutables en cours de shift** : un
## `.tres` partagé n'est jamais modifié ; le `DayController` travaille sur une
## **copie de shift** (`make_shift_copy()`), seule à accepter des
## changements (`apply_changes` : `RuleChangeDef` ADD / RETIRE / FORGET /
## RESTORE / OVERRIDE / MODIFIER, chacun journalisé par source et défait par
## `revert_source`). La copie porte aussi l'état de shift partagé par le
## contexte et le contexte « cas propre » du générateur : surcharges de
## paramètres (`get_param`), modificateurs (`get_modifier`), listes nommées
## (`lists` : `stolen`…) et `overlay_suspended` (cas scénarisé : jugé sur les
## règles de sa conception, sans surcharge ni modificateur).
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

# --- État de shift (M12, copie seulement ; jamais sérialisé) -------------------

## Vrai pour une copie de shift (`make_shift_copy`) : seule mutable.
var is_shift_copy: bool = false
## Surcharges actives (`RuleChangeDef.Op.OVERRIDE`), dans l'ordre d'application.
var overrides: Array[RuleChangeDef] = []
## Modificateurs actifs (`RuleChangeDef.Op.MODIFIER`).
var modifier_changes: Array[RuleChangeDef] = []
## Listes nommées du shift (`stolen` : cartes volées, EV-07) → `Array[RevokedEntry]`.
var lists: Dictionary[StringName, Array] = {}
## Cas scénarisé en cours : surcharges et modificateurs ignorés (D-129, règle 3).
var overlay_suspended: bool = false
## Journal : `{source, change, effect}` (effet réel : `added`, `retired`…).
var _journal: Array[Dictionary] = []
## Règles déjà vues (rétablissement d'une règle oubliée).
var _known: Dictionary[StringName, Rule] = {}
## Ordre d'origine des règles (rétablissement à sa place).
var _origin_order: Array[StringName] = []


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


# --- M12 : copie de shift et mutation (B54) -------------------------------------

## Copie mutable pour un shift : mêmes `Rule` (partagées, jamais mutées),
## listes copiées. Une copie de copie repart de l'état courant.
func make_shift_copy() -> RuleSet:
	var copy: RuleSet = RuleSet.new()
	copy.id = id
	copy.rules = rules.duplicate()
	copy.new_rule_ids = new_rule_ids.duplicate()
	copy.required_document_ids = required_document_ids.duplicate()
	copy.retired_rules = retired_rules.duplicate()
	copy.retired_note_keys = retired_note_keys.duplicate()
	copy.rule_note_keys = rule_note_keys.duplicate()
	copy.is_shift_copy = true
	copy.overrides = overrides.duplicate()
	copy.modifier_changes = modifier_changes.duplicate()
	copy.lists = lists.duplicate()
	copy._journal = _journal.duplicate()
	copy._known = _known.duplicate()
	copy._origin_order = _origin_order.duplicate() if is_shift_copy else get_rule_ids()
	for list: Array[Rule] in [rules, retired_rules]:
		for rule: Rule in list:
			if rule != null:
				copy._known[rule.id] = rule
	return copy


## Applique des changements (copie de shift seulement) ; renvoie la différence,
## Rulebook compris. Un changement sans effet (règle déjà active, absente…)
## n'est pas journalisé.
func apply_changes(changes: Array[RuleChangeDef], source: StringName = &"") -> RuleDiff:
	var diff: RuleDiff = RuleDiff.new(source)
	if not is_shift_copy:
		push_error("RuleSet.apply_changes: %s n'est pas une copie de shift (make_shift_copy)" % id)
		return diff
	var marks_new: bool = false
	for change: RuleChangeDef in changes:
		if change != null and change.op == RuleChangeDef.Op.ADD and change.mark_new:
			marks_new = true
	if marks_new:
		new_rule_ids.clear()
	for change: RuleChangeDef in changes:
		if change == null:
			continue
		var effect: StringName = _apply_one(change, diff)
		if effect != &"":
			_journal.append({"source": source, "change": change, "effect": effect})
	_finish(diff)
	return diff


## Défait tout ce qu'une source a appliqué (ordre inverse) : un ajout est
## retiré sans ligne barrée, un retrait rétabli, une surcharge ou un
## modificateur supprimé.
func revert_source(source: StringName) -> RuleDiff:
	var diff: RuleDiff = RuleDiff.new(source)
	if not is_shift_copy:
		return diff
	for i: int in range(_journal.size() - 1, -1, -1):
		var row: Dictionary = _journal[i]
		if row["source"] != source:
			continue
		_journal.remove_at(i)
		var change: RuleChangeDef = row["change"]
		match StringName(row["effect"]):
			&"added":
				if _remove_active(change.rule_id) != null:
					new_rule_ids.erase(change.rule_id)
					diff.retired.append(change.rule_id)
			&"retired", &"forgotten":
				if _restore(change.rule_id):
					diff.restored.append(change.rule_id)
			&"restored":
				if _remove_active(change.rule_id) != null:
					diff.retired.append(change.rule_id)
			&"overridden":
				overrides.erase(change)
				diff.overridden.append(change.rule_id)
			&"modified":
				modifier_changes.erase(change)
				diff.modifiers.append(change.modifier)
	_finish(diff)
	return diff


## Sources ayant au moins un changement en vigueur.
func active_sources() -> Array[StringName]:
	var sources: Array[StringName] = []
	for row: Dictionary in _journal:
		var source: StringName = row["source"]
		if not sources.has(source):
			sources.append(source)
	return sources


## Paramètre `param` de la règle `rule_id` : dernière surcharge applicable
## (origine, motif, heure de présentation), sinon `default`.
func get_param(rule_id: StringName, param: StringName, default: Variant, faction_id: StringName = &"",
		purpose: StringName = &"", minute: int = -1) -> Variant:
	if overlay_suspended:
		return default
	var value: Variant = default
	for change: RuleChangeDef in overrides:
		if change.rule_id == rule_id and change.params.has(param) and change.applies_to(faction_id, purpose, minute):
			value = change.params[param]
	return value


## Vrai si une surcharge de `rule_id` existe (sans tenir compte de la portée).
func has_override(rule_id: StringName) -> bool:
	if overlay_suspended:
		return false
	for change: RuleChangeDef in overrides:
		if change.rule_id == rule_id:
			return true
	return false


## Somme des modificateurs `name` en vigueur (0 si aucun).
func get_modifier(name: StringName) -> int:
	if overlay_suspended:
		return 0
	var total: int = 0
	for change: RuleChangeDef in modifier_changes:
		if change.modifier == name:
			total += change.amount
	return total


func _apply_one(change: RuleChangeDef, diff: RuleDiff) -> StringName:
	match change.op:
		RuleChangeDef.Op.ADD:
			if change.rule == null or has_rule(change.rule.id):
				return &""
			_known[change.rule.id] = change.rule
			_drop_retired(change.rule.id)
			# Règle d'origine remplacée (SC-89a) : à sa place ; nouvelle : à la fin.
			_insert_at_origin(change.rule)
			if change.mark_new and not new_rule_ids.has(change.rule.id):
				new_rule_ids.append(change.rule.id)
			diff.added.append(change.rule.id)
			return &"added"
		RuleChangeDef.Op.RETIRE:
			var rule: Rule = _remove_active(change.rule_id)
			if rule == null:
				return &""
			retired_rules.append(rule)
			retired_note_keys[rule.id] = change.note_key
			diff.retired.append(rule.id)
			return &"retired"
		RuleChangeDef.Op.FORGET:
			if not _drop_retired(change.rule_id):
				return &""
			diff.forgotten.append(change.rule_id)
			return &"forgotten"
		RuleChangeDef.Op.RESTORE:
			if not _restore(change.rule_id):
				return &""
			diff.restored.append(change.rule_id)
			return &"restored"
		RuleChangeDef.Op.OVERRIDE:
			overrides.append(change)
			diff.overridden.append(change.rule_id)
			return &"overridden"
		RuleChangeDef.Op.MODIFIER:
			if change.modifier == &"":
				return &""
			modifier_changes.append(change)
			diff.modifiers.append(change.modifier)
			return &"modified"
	return &""


## Retire une règle active (sans ligne barrée) ; null si absente.
func _remove_active(rule_id: StringName) -> Rule:
	for i: int in rules.size():
		var rule: Rule = rules[i]
		if rule != null and rule.id == rule_id:
			rules.remove_at(i)
			new_rule_ids.erase(rule_id)
			_known[rule_id] = rule
			return rule
	return null


## Supprime la ligne barrée d'une règle ; faux si absente.
func _drop_retired(rule_id: StringName) -> bool:
	for i: int in retired_rules.size():
		var rule: Rule = retired_rules[i]
		if rule != null and rule.id == rule_id:
			retired_rules.remove_at(i)
			retired_note_keys.erase(rule_id)
			return true
	return false


## Rétablit une règle retirée ou oubliée, à sa place d'origine ; faux si déjà
## active ou inconnue.
func _restore(rule_id: StringName) -> bool:
	if has_rule(rule_id) or not _known.has(rule_id):
		return false
	_drop_retired(rule_id)
	_insert_at_origin(_known[rule_id])
	return true


## Insère une règle à son rang d'origine (avant la première règle de rang
## supérieur) ; une règle hors de l'ordre d'origine va à la fin.
func _insert_at_origin(rule: Rule) -> void:
	var rank: int = _origin_rank(rule.id)
	var at: int = rules.size()
	for i: int in rules.size():
		if rules[i] != null and _origin_rank(rules[i].id) > rank:
			at = i
			break
	rules.insert(at, rule)


func _origin_rank(rule_id: StringName) -> int:
	var index: int = _origin_order.find(rule_id)
	return index if index >= 0 else 1_000_000


func _finish(diff: RuleDiff) -> void:
	required_document_ids = compute_required_document_ids()
	diff.rulebook = build_rulebook()
	diff.retired_entries = build_retired_entries()


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
