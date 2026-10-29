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
## Acte III (M1, I21) : note du jour sous la règle (`rb_suspended_quota` :
## quota suspendu pendant l'Enquête), vide sinon.
var note_key: String = ""
## Acte III (M1) : règle **retirée** affichée barrée un jour, avec son motif
## (`note_key` : `rb_retired_quais`, `rb_retired_curfew`) ; jamais évaluée.
var retired: bool = false
## M12 (B55) : liste nommée lue par la règle (`RevokedIdRule.list_label` :
## `stolen`, `council`…), vide sinon — l'UI n'a pas à lire la ressource
## (souvent une sous-ressource sans chemin).
var list_label: StringName = &""
## M12 : intitulé de l'onglet de cette liste (`rb_tab_stolen`, `rb_tab_council`), vide sinon.
var list_title_key: String = ""
