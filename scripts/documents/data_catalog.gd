## Chargement des définitions de `res://data/` (documents, origines, règles,
## RuleSets, jours ; M3 : réserves de noms et catalogue d'apparences),
## indexées par identifiant.
##
## Pur (aucun Node, aucun autoload) : utilisé par les tests de validation des
## données et, en M5, par la scène de jour pour construire le `RuleContext`.
## Les doublons d'identifiants sont consignés dans `errors` (le premier gagne).
class_name DataCatalog
extends RefCounted

const DATA_ROOT: String = "res://data"

var factions: Dictionary[StringName, FactionDef] = {}
var documents: Dictionary[StringName, DocumentTypeDef] = {}
var rules: Dictionary[StringName, Rule] = {}
var rule_sets: Dictionary[StringName, RuleSet] = {}
var days: Dictionary[int, DayDef] = {}
var name_pools: Dictionary[StringName, NamePool] = {}
## Catalogue d'apparences (unique, `data/appearance/`).
var appearance_catalog: AppearanceCatalog = null
## Chemins `.tres` chargés.
var paths: PackedStringArray = []
## Problèmes de chargement (ressource illisible, type inconnu, doublon).
var errors: PackedStringArray = []


static func load_from(root: String = DATA_ROOT) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for path: String in list_resource_paths(root):
		catalog._register(path)
	return catalog


## Chemins de toutes les ressources (`.tres`/`.res`) sous `root`, triés.
## Gère les `.remap` des exports.
static func list_resource_paths(root: String) -> PackedStringArray:
	var result: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		push_error("DataCatalog: dossier introuvable « %s »" % root)
		return result
	for sub: String in dir.get_directories():
		result.append_array(list_resource_paths(root.path_join(sub)))
	for file: String in dir.get_files():
		var name: String = file.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			result.append(root.path_join(name))
	result.sort()
	return result


func get_day(day_number: int) -> DayDef:
	return days.get(day_number, null)


## Contexte de règles d'un jour (date, RuleSet, bases origines et documents ;
## slots de visage comparés tirés du catalogue d'apparences).
func make_context(day_number: int) -> RuleContext:
	var day: DayDef = get_day(day_number)
	if day == null:
		push_error("DataCatalog.make_context: jour %d introuvable" % day_number)
		return null
	var ctx: RuleContext = RuleContext.for_day(day, factions, documents)
	if appearance_catalog != null:
		ctx.identity_slots = FaceComparator.identity_slots_of(appearance_catalog)
	return ctx


func _register(path: String) -> void:
	var res: Resource = load(path)
	if res == null:
		errors.append("%s : chargement impossible" % path)
		return
	paths.append(path)
	if res is FactionDef:
		var faction: FactionDef = res
		_add(factions, faction.id, faction, path)
	elif res is DocumentTypeDef:
		var doc: DocumentTypeDef = res
		_add(documents, doc.id, doc, path)
	elif res is RuleSet:
		var rule_set: RuleSet = res
		_add(rule_sets, rule_set.id, rule_set, path)
	elif res is Rule:
		var rule: Rule = res
		_add(rules, rule.id, rule, path)
	elif res is NamePool:
		var pool: NamePool = res
		_add(name_pools, pool.id, pool, path)
	elif res is AppearanceCatalog:
		if appearance_catalog != null:
			errors.append("%s : catalogue d'apparences en double" % path)
		else:
			appearance_catalog = res
	elif res is DayDef:
		var day: DayDef = res
		if days.has(day.day_number):
			errors.append("%s : jour %d en double" % [path, day.day_number])
		else:
			days[day.day_number] = day
	else:
		errors.append("%s : type de ressource inattendu" % path)


func _add(table: Dictionary, key: StringName, value: Resource, path: String) -> void:
	if key == &"":
		errors.append("%s : identifiant vide" % path)
	elif table.has(key):
		errors.append("%s : identifiant « %s » en double" % [path, key])
	else:
		table[key] = value
