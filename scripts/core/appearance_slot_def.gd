## Slot d'apparence (ARCHITECTURE §5.2, BOOTH_SCENE §12.1).
##
## `identity` : trait de la personne (stable, comparable) ; sinon trait
## changeable (tenue, coiffe, accessoire : bruit légitime). `FaceComparator`
## ne compare que les slots `identity && visible_in_portrait`.
class_name AppearanceSlotDef
extends Resource

@export var id: StringName = &""
@export var identity: bool = false
@export var visible_in_portrait: bool = false
@export var options: Array[AppearanceOptionDef] = []


func get_option(option_id: StringName) -> AppearanceOptionDef:
	for option: AppearanceOptionDef in options:
		if option != null and option.id == option_id:
			return option
	return null


func has_option(option_id: StringName) -> bool:
	return get_option(option_id) != null


func get_option_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for option: AppearanceOptionDef in options:
		if option != null:
			ids.append(option.id)
	return ids


## Vrai si le slot entre dans la comparaison de visages.
func is_compared() -> bool:
	return identity and visible_in_portrait
