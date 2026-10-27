## Ligne du Rulebook affichée au joueur (ARCHITECTURE §6, §7 `day_started`).
##
## Construite depuis la règle elle-même (`Rule.get_rulebook_entry()`) : une
## seule source de vérité pour le texte affiché et la logique.
class_name RulebookEntry
extends RefCounted

var rule_id: StringName = &""
var title_key: String = ""
var text_key: String = ""
var category: Rule.RuleCategory = Rule.RuleCategory.DOCUMENTS
var severity: int = 2
## Badge « NOUVEAU » (`RuleSet.new_rule_ids`).
var is_new: bool = false
## Référence sélectionnable en mode Inspection (champ ↔ règle).
var ref: FieldRef = null
