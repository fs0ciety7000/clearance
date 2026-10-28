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
## Slots comparés par `FaceComparator` (dérivés de l'`AppearanceCatalog` par
## `DataCatalog.make_context()` et `CaseBuilder` ; liste par défaut sinon).
var identity_slots: Array[StringName] = FaceComparator.DEFAULT_IDENTITY_SLOTS.duplicate()
## Avis de recherche du jour (M7, R22), posé par le `CaseBuilder`.
var wanted: Array[WantedNotice] = []
## Acte II — liste des révocations du jour (R30), posée par le `CaseBuilder`.
var revoked: Array[RevokedEntry] = []
## Acte II — compteur du quota respiratoire du shift (R23, B22), tenu par le
## `DayController` (paire « Compteur ↔ R23 » du Mode Inspection).
var quota_used: int = 0
var quota_max: int = 0


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


## Numéro du jour (0 sans `DayDef`).
func get_day_number() -> int:
	return day_def.day_number if day_def != null else 0


func find_wanted(notice_id: StringName) -> WantedNotice:
	for notice: WantedNotice in wanted:
		if notice.id == notice_id:
			return notice
	return null


func find_revoked(entry_id: StringName) -> RevokedEntry:
	for entry: RevokedEntry in revoked:
		if entry.id == entry_id:
			return entry
	return null


## Vrai si le N° ID figure à l'onglet Révocations.
func is_revoked(citizen_id: Variant) -> bool:
	for entry: RevokedEntry in revoked:
		if FieldValue.equals(entry.citizen_id, citizen_id):
			return true
	return false


## Acte II : quota atteint (compteur ≥ maximum, quota actif).
func is_quota_full() -> bool:
	return quota_max > 0 and quota_used >= quota_max


## Copie superficielle (mêmes bases, autres listes d'avis et de révocations).
func duplicate_context() -> RuleContext:
	var ctx: RuleContext = RuleContext.new(today, rule_set)
	ctx.day_def = day_def
	ctx.faction_db = faction_db
	ctx.document_db = document_db
	ctx.identity_slots = identity_slots.duplicate()
	ctx.wanted = wanted.duplicate()
	ctx.revoked = revoked.duplicate()
	ctx.quota_used = quota_used
	ctx.quota_max = quota_max
	return ctx
