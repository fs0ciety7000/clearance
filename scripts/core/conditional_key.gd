## Clé de texte conditionnelle (M7) : variante de texte d'un événement du soir,
## ligne additionnelle d'une lettre, mention d'un objet glissé. `condition`
## nulle = toujours.
class_name ConditionalKey
extends Resource

@export var key: String = ""
@export var condition: FlagCondition = null


static func make(p_key: String, p_condition: FlagCondition = null) -> ConditionalKey:
	var c: ConditionalKey = ConditionalKey.new()
	c.key = p_key
	c.condition = p_condition
	return c


## Première clé dont la condition est vraie, sinon `fallback`.
static func first_match(entries: Array[ConditionalKey], flags: Dictionary[StringName, Variant], fallback: String) -> String:
	for entry: ConditionalKey in entries:
		if entry != null and FlagCondition.check(entry.condition, flags):
			return entry.key
	return fallback


## Toutes les clés dont la condition est vraie, dans l'ordre.
static func all_matches(entries: Array[ConditionalKey], flags: Dictionary[StringName, Variant]) -> PackedStringArray:
	var result: PackedStringArray = []
	for entry: ConditionalKey in entries:
		if entry != null and FlagCondition.check(entry.condition, flags):
			result.append(entry.key)
	return result
