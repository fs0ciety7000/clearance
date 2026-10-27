## Contexte d'évaluation des règles (ARCHITECTURE §5.3, §6).
##
## Passé explicitement plutôt que lu dans un autoload : règles pures et
## testables. `rule_set` sert au `DiscrepancyChecker` (comparaison champ ↔
## règle : seules les règles actives du jour sont comparables).
class_name RuleContext
extends RefCounted

## Date du jour (`GameDate`).
var today: int = 0
var day_def: DayDef = null
var rule_set: RuleSet = null
var faction_db: Dictionary[StringName, FactionDef] = {}
var document_db: Dictionary[StringName, DocumentTypeDef] = {}
## Slots comparés par `FaceComparator` (M3 : dérivés de l'`AppearanceCatalog`).
var identity_slots: Array[StringName] = FaceComparator.DEFAULT_IDENTITY_SLOTS.duplicate()


func _init(p_today: int = 0, p_rule_set: RuleSet = null) -> void:
	today = p_today
	rule_set = p_rule_set


## Contexte d'un jour : date et RuleSet tirés du `DayDef`.
static func for_day(day: DayDef, factions: Dictionary[StringName, FactionDef] = {},
		documents: Dictionary[StringName, DocumentTypeDef] = {}) -> RuleContext:
	var ctx: RuleContext = RuleContext.new(day.game_date, day.rule_set)
	ctx.day_def = day
	ctx.faction_db = factions
	ctx.document_db = documents
	return ctx


## Règle active du jour, ou null (absente du RuleSet = désactivée).
func find_active_rule(rule_id: StringName) -> Rule:
	return rule_set.get_rule(rule_id) if rule_set != null else null


func get_faction(faction_id: StringName) -> FactionDef:
	return faction_db.get(faction_id, null)
