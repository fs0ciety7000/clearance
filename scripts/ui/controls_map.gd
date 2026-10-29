## Schéma de commandes clavier + manette (M11, UI_FLOW §9) : actions de
## `project.godot` dont chaque écran dépend, et rappel affiché dans les
## Options. Source unique pour l'interface et les tests (chaque action a une
## liaison clavier **et** une liaison manette).
class_name ControlsMap
extends RefCounted

## Actions du jeu : clavier + manette obligatoires (campagne à la manette seule).
const GAME_ACTIONS: Array[StringName] = [
	&"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right",
	&"inspect_toggle", &"interrogate", &"stamp_approve", &"stamp_deny", &"stamp_detain", &"rulebook_toggle",
	&"next_case", &"cancel", &"inspect_face", &"rulebook_prev", &"rulebook_next",
	&"pause", &"doc_prev", &"doc_next", &"doc_zoom", &"scroll_up", &"scroll_down",
]

## Rappel des Options : [action, clé du libellé, libellé par défaut].
const SUMMARY: Array[Array] = [
	[&"ui_accept", "ctl_accept", "Valider · choisir un champ"],
	[&"ui_cancel", "ctl_cancel", "Annuler · retour"],
	[&"next_case", "ctl_next", "Passager suivant"],
	[&"inspect_toggle", "ctl_inspect", "Mode Inspection"],
	[&"interrogate", "ctl_ask", "Interroger"],
	[&"inspect_face", "ctl_face", "Visage (inspection)"],
	[&"stamp_approve", "ctl_approve", "APPROUVÉ (maintenir)"],
	[&"stamp_deny", "ctl_deny", "REFUSÉ (maintenir)"],
	[&"stamp_detain", "ctl_detain", "DÉTENTION (maintenir)"],
	[&"rulebook_toggle", "ctl_rulebook", "Rulebook"],
	[&"rulebook_next", "ctl_rulebook_tabs", "Onglet du Rulebook"],
	[&"doc_next", "ctl_doc_next", "Document suivant"],
	[&"doc_zoom", "ctl_zoom", "Loupe (hors inspection)"],
	[&"scroll_down", "ctl_scroll", "Faire défiler"],
	[&"pause", "ctl_pause", "Pause"],
]
