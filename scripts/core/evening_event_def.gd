## Événement du soir d'un jour (M7, NARRATIVE §5, B12) — données de
## `DayDef.evening_events`, généralisation du « mot glissé » du J3.
##
## - `LETTER` : texte seul (lettre, récit), effets automatiques (`flags`,
##   `line_costs`) dès qu'il est affiché ;
## - `CHOICE` : options (`EveningOptionDef`), une seule choisie ;
## - `AUDIT` : audit de l'Inspecteur Ravel (J9, `EndingService.audit_outcome`),
##   résultat automatique, peut terminer la partie (F1).
## Affichage : par `order` croissant (au J9 : audit → aveu → déposition →
## laissez-passer). `condition` nulle = toujours. `text_variants` : première
## variante vraie à la place de `text_key` ; `extra_keys` : lignes ajoutées.
class_name EveningEventDef
extends Resource

enum Kind { LETTER, CHOICE, AUDIT }

@export var id: StringName = &""
@export var kind: Kind = Kind.CHOICE
@export var order: int = 0
@export var condition: FlagCondition = null
@export var title_key: String = ""
@export var text_key: String = ""
@export var text_variants: Array[ConditionalKey] = []
@export var extra_keys: Array[ConditionalKey] = []
@export var options: Array[EveningOptionDef] = []
## Effets automatiques (lettres) : deltas de drapeaux, coûts de postes imposés.
@export var flags: Dictionary[StringName, int] = {}
@export var line_costs: Dictionary[StringName, int] = {}


func get_option(option_id: StringName) -> EveningOptionDef:
	for option: EveningOptionDef in options:
		if option != null and option.id == option_id:
			return option
	return null
