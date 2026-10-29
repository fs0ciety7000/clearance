## Différence de règles appliquée en cours de shift (M12, B54 ; ARCHITECTURE
## §11.3) — porté par `EventBus.rules_changed(diff)`.
##
## Identifiants des règles touchées par opération, Rulebook **complet** après
## le changement (lignes actives, puis lignes barrées) et contexte libre de la
## source (`context` : `kind` = `garde_directive` | `garde_rotation` |
## `station_event` | `station_event_end` ; `directive`, `unit_id`, `event_id`,
## `window` (Vector2i : index du premier passager visé → index exclu, −1 =
## fin du jour)). Le générateur (lot B) lit `context` dans
## `CaseBuilder.on_rules_changed(diff)` (exercice garanti, listes renouvelées).
class_name RuleDiff
extends RefCounted

var source: StringName = &""
var added: Array[StringName] = []
var retired: Array[StringName] = []
var forgotten: Array[StringName] = []
var restored: Array[StringName] = []
## Règles dont un paramètre est surchargé (ajout ou retrait de surcharge).
var overridden: Array[StringName] = []
## Modificateurs du shift changés (`RuleChangeDef.MOD_*`).
var modifiers: Array[StringName] = []
## Rulebook après le changement (`RuleSet.build_rulebook()`).
var rulebook: Array[RulebookEntry] = []
## Lignes barrées après le changement (`RuleSet.build_retired_entries()`).
var retired_entries: Array[RulebookEntry] = []
var context: Dictionary = {}


func _init(p_source: StringName = &"") -> void:
	source = p_source


func is_empty() -> bool:
	return added.is_empty() and retired.is_empty() and forgotten.is_empty() and restored.is_empty() \
			and overridden.is_empty() and modifiers.is_empty()


## Ajoute les changements de `other` (Rulebook et contexte de `other` gardés
## s'ils sont renseignés).
func merge(other: RuleDiff) -> void:
	if other == null:
		return
	for pair: Array in [[added, other.added], [retired, other.retired], [forgotten, other.forgotten],
			[restored, other.restored], [overridden, other.overridden], [modifiers, other.modifiers]]:
		var mine: Array = pair[0]
		var theirs: Array = pair[1]
		for id: Variant in theirs:
			if not mine.has(id):
				mine.append(id)
	if not other.rulebook.is_empty() or not other.retired_entries.is_empty():
		rulebook = other.rulebook
		retired_entries = other.retired_entries
	if source == &"":
		source = other.source
	for key: Variant in other.context:
		context[key] = other.context[key]
