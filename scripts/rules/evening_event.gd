## Événement du soir résolu pour un jour (M7) — produit par
## `EveningService.build_events()`, vu par l'UI (écran Soirée).
##
## Textes résolus selon les drapeaux (`text_key`, `extra_keys`), options
## disponibles (condition vraie ; la disponibilité financière est vérifiée au
## choix : `EveningService.can_choose`). Un audit porte son résultat (`audit`).
class_name EveningEvent
extends RefCounted

var def: EveningEventDef = null
var id: StringName = &""
var kind: EveningEventDef.Kind = EveningEventDef.Kind.LETTER
var title_key: String = ""
var text_key: String = ""
var extra_keys: PackedStringArray = []
var options: Array[EveningOptionDef] = []
## Option choisie par défaut sans UI (vide pour une lettre ou un audit).
var default_option: StringName = &""
## Audit (J9) : `EndingService.audit_outcome()` ; Revue (J17) : `review_outcome()`.
var audit: Dictionary = {}
## Acte II : valeurs du gabarit de `text_key` (`%d`), ex. pages du registre.
var text_args: Array = []


func get_option(option_id: StringName) -> EveningOptionDef:
	for option: EveningOptionDef in options:
		if option.id == option_id:
			return option
	return null


func is_choice() -> bool:
	return kind == EveningEventDef.Kind.CHOICE and not options.is_empty()
