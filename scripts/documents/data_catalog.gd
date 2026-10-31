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
const ECONOMY_PATH: String = "res://data/economy/economy.tres"
## M14 (ARCHITECTURE §12 ter.1) : données chargées **par chemin** par leurs
## propres tables (`CinematicLibraryDef.load_default`, `PaLineTable.load_default`),
## jamais par le catalogue — ni indexées ni chargées ici (66 planches de moins
## à chaque chargement du catalogue, aucune référence de type vers la
## bibliothèque des cinématiques depuis ce script chargé tôt, D-197).
const BY_PATH_DIRS: PackedStringArray = ["res://data/cinematics", "res://data/audio"]

var factions: Dictionary[StringName, FactionDef] = {}
var documents: Dictionary[StringName, DocumentTypeDef] = {}
var rules: Dictionary[StringName, Rule] = {}
var rule_sets: Dictionary[StringName, RuleSet] = {}
var days: Dictionary[int, DayDef] = {}
var name_pools: Dictionary[StringName, NamePool] = {}
## Catalogue d'apparences (unique, `data/appearance/`).
var appearance_catalog: AppearanceCatalog = null
## Barème de la soirée (unique, `data/economy/`, M5).
var economy: EconomyDef = null
## M12 (docs/M12.md, ARCHITECTURE §11) : jours J31 des mondes de l'épilogue
## (`DayDef.mode = epilogue`, par monde `a`…`d` ; jamais dans `days`).
var epilogue_days: Dictionary[StringName, DayDef] = {}
## M12 : gabarits de la Garde de nuit (`DayDef.mode = garde`, hors `days`).
var garde_days: Array[DayDef] = []
## M12 : données uniques de l'épilogue, de la Garde, des événements, du Dossier.
var epilogue: EpilogueDef = null
var garde: GardeDef = null
var station_events: StationEventsDef = null
var characters: CharacterTableDef = null
## M12 : unités de Garde (U01 → U20) et événements (EV-01 → EV-08) par id.
var garde_units: Dictionary[StringName, GardeUnitDef] = {}
var events: Dictionary[StringName, StationEventDef] = {}
## M13 (docs/M13.md ; B65, B69, B74) : tables des déclarations, catalogue de
## la fouille, améliorations du guichet (par id) et paliers de R43 au-delà du
## premier (`r_statements` s2 → s4, même identifiant : `"<id>@<palier>"`).
var statement_tables: StatementTablesDef = null
var search_catalog: SearchCatalogDef = null
var upgrades: Dictionary[StringName, UpgradeDef] = {}
var rule_tiers: Dictionary[String, Rule] = {}
## Chemins `.tres` chargés.
var paths: PackedStringArray = []
## Problèmes de chargement (ressource illisible, type inconnu, doublon).
var errors: PackedStringArray = []


static func load_from(root: String = DATA_ROOT) -> DataCatalog:
	var catalog: DataCatalog = DataCatalog.new()
	for path: String in list_resource_paths(root):
		if not _is_by_path(path):
			catalog._register(path)
	return catalog


static func _is_by_path(path: String) -> bool:
	for dir: String in BY_PATH_DIRS:
		if path.begins_with(dir + "/"):
			return true
	return false


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


## Dernier jour jouable défini dans les données (3 pour la *vertical slice*).
func get_last_day_number() -> int:
	var last: int = 0
	for n: int in days:
		last = maxi(last, n)
	return last


## Barème économique (valeurs par défaut du GDD si absent des données).
func get_economy() -> EconomyDef:
	return economy if economy != null else EconomyDef.new()


## Barème seul (sans charger tout le catalogue) ; valeurs par défaut si absent.
static func load_economy() -> EconomyDef:
	if ResourceLoader.exists(ECONOMY_PATH):
		var economy_def: EconomyDef = load(ECONOMY_PATH) as EconomyDef
		if economy_def != null:
			return economy_def
	return EconomyDef.new()


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
	elif res is StatementsConsistentRule and (res as StatementsConsistentRule).tier > 1:
		# M13 : palier de R43 (même identifiant que le palier 1).
		var tiered: StatementsConsistentRule = res
		var tier_key: String = "%s@%d" % [tiered.id, tiered.tier]
		if rule_tiers.has(tier_key):
			errors.append("%s : palier « %s » en double" % [path, tier_key])
		else:
			rule_tiers[tier_key] = tiered
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
	elif res is EconomyDef:
		if economy != null:
			errors.append("%s : barème économique en double" % path)
		else:
			economy = res
	elif res is DayDef and (res as DayDef).mode == DayDef.MODE_EPILOGUE:
		var epilogue_day: DayDef = res
		_add(epilogue_days, epilogue_day.epilogue_world, epilogue_day, path)
	elif res is DayDef and (res as DayDef).mode == DayDef.MODE_GARDE:
		garde_days.append(res as DayDef)
	elif res is DayDef:
		var day: DayDef = res
		if days.has(day.day_number):
			errors.append("%s : jour %d en double" % [path, day.day_number])
		else:
			days[day.day_number] = day
	elif res is EpilogueDef:
		epilogue = _unique(epilogue, res, path) as EpilogueDef
	elif res is GardeDef:
		garde = _unique(garde, res, path) as GardeDef
	elif res is StationEventsDef:
		station_events = _unique(station_events, res, path) as StationEventsDef
	elif res is CharacterTableDef:
		characters = _unique(characters, res, path) as CharacterTableDef
	elif res is GardeUnitDef:
		var unit: GardeUnitDef = res
		_add(garde_units, unit.id, unit, path)
	elif res is StationEventDef:
		var event: StationEventDef = res
		_add(events, event.id, event, path)
	elif res is StatementTablesDef:
		statement_tables = _unique(statement_tables, res, path) as StatementTablesDef
	elif res is SearchCatalogDef:
		search_catalog = _unique(search_catalog, res, path) as SearchCatalogDef
	elif res is UpgradeDef:
		var upgrade: UpgradeDef = res
		_add(upgrades, upgrade.id, upgrade, path)
	else:
		errors.append("%s : type de ressource inattendu" % path)


## M12 : ressource unique (la première gagne, doublon consigné).
func _unique(current: Resource, candidate: Resource, path: String) -> Resource:
	if current != null:
		errors.append("%s : ressource unique en double" % path)
		return current
	return candidate


## M12 : jour J31 d'un monde de l'épilogue (`a`…`d`), ou null.
func get_epilogue_day(world: StringName) -> DayDef:
	return epilogue_days.get(world, null)


func _add(table: Dictionary, key: StringName, value: Resource, path: String) -> void:
	if key == &"":
		errors.append("%s : identifiant vide" % path)
	elif table.has(key):
		errors.append("%s : identifiant « %s » en double" % [path, key])
	else:
		table[key] = value
