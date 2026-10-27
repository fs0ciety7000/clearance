## Condition sur les drapeaux narratifs (M7 : briefings, soirées, effets de cas,
## objets glissés) — `Resource` de données, évaluation pure.
##
## Vraie si **toutes** les clauses renseignées le sont : `all_of` (drapeaux
## vrais), `none_of` (drapeaux faux ou absents), `gauges_min` / `gauges_max`
## (jauges entières `loyalty`, `lucioles_trust`, `suspicion`…, bornes
## incluses), `any_of` (au moins une sous-condition vraie). Une condition vide
## est toujours vraie. Un drapeau est « vrai » s'il vaut `true`, un entier non
## nul ou un texte non vide (même lecture que `GameState.get_true_flags()`).
class_name FlagCondition
extends Resource

@export var all_of: Array[StringName] = []
@export var none_of: Array[StringName] = []
@export var gauges_min: Dictionary[StringName, int] = {}
@export var gauges_max: Dictionary[StringName, int] = {}
@export var any_of: Array[FlagCondition] = []


func evaluate(flags: Dictionary[StringName, Variant]) -> bool:
	for flag: StringName in all_of:
		if not is_flag_true(flags, flag):
			return false
	for flag: StringName in none_of:
		if is_flag_true(flags, flag):
			return false
	for gauge: StringName in gauges_min:
		if gauge_value(flags, gauge) < gauges_min[gauge]:
			return false
	for gauge: StringName in gauges_max:
		if gauge_value(flags, gauge) > gauges_max[gauge]:
			return false
	if not any_of.is_empty():
		for sub: FlagCondition in any_of:
			if sub != null and sub.evaluate(flags):
				return true
		return false
	return true


## Évalue une condition éventuellement nulle (null = toujours vraie).
static func check(condition: FlagCondition, flags: Dictionary[StringName, Variant]) -> bool:
	return condition == null or condition.evaluate(flags)


static func is_flag_true(flags: Dictionary[StringName, Variant], flag: StringName) -> bool:
	var value: Variant = flags.get(flag, false)
	if value is bool:
		return value
	if value is int or value is float:
		return SaveService.as_int(value) != 0
	if value is String or value is StringName:
		return not str(value).is_empty()
	return false


static func gauge_value(flags: Dictionary[StringName, Variant], gauge: StringName) -> int:
	return SaveService.as_int(flags.get(gauge, 0))


## Dictionnaire de drapeaux « vrais » à partir d'une liste (`requires_flag`).
static func from_true_flags(true_flags: Array[StringName]) -> Dictionary[StringName, Variant]:
	var result: Dictionary[StringName, Variant] = {}
	for flag: StringName in true_flags:
		result[flag] = true
	return result


## Fabrique (outils de données, tests).
static func make(p_all: Array[StringName] = [], p_none: Array[StringName] = [],
		p_min: Dictionary[StringName, int] = {}, p_max: Dictionary[StringName, int] = {}) -> FlagCondition:
	var c: FlagCondition = FlagCondition.new()
	c.all_of = p_all
	c.none_of = p_none
	c.gauges_min = p_min
	c.gauges_max = p_max
	return c


## « Au moins une de ces conditions ».
static func any(conditions: Array[FlagCondition]) -> FlagCondition:
	var c: FlagCondition = FlagCondition.new()
	c.any_of = conditions
	return c
