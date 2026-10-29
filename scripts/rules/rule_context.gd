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
## Acte III — Main courante du shift (R34) : répondants admissibles admis
## aujourd'hui à cette vitre, dans l'ordre (tenue par le `CaseBuilder`,
## `record_verdict`) ; le verdict attendu est calculé **au moment de la
## présentation** (comme le quota, D-077).
var ledger: Array[LedgerEntry] = []
## Acte III — onglet Convocations du jour (R36), posé par le `CaseBuilder`.
var summons: Array[SummonsEntry] = []
## Acte III — contrôle « cas propre » du générateur : un Répondant ou une
## Convocation présents sur le permis sont tenus pour valides (le lien est
## vérifié au moment de la présentation, avec la vraie liste).
var trust_documents: bool = false


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
	ctx.ledger = ledger.duplicate()
	ctx.summons = summons.duplicate()
	ctx.trust_documents = trust_documents
	return ctx


# ---------------------------------------------------------------------------
# Acte III (docs/ACT3.md §2.4) : règles de contexte lues par les autres règles
# ---------------------------------------------------------------------------

## R32 active du jour (prorogation de Continuité), ou null.
func prorogation() -> ProrogationRule:
	if rule_set == null:
		return null
	for rule: Rule in rule_set.rules:
		if rule is ProrogationRule:
			return rule as ProrogationRule
	return null


## Document daté `expiry_date` expiré aujourd'hui, prorogation (R32) comprise.
func is_document_expired(expiry_date: int) -> bool:
	if expiry_date >= today:
		return false
	return not is_prorogated(expiry_date)


## Vrai si un document expiré le `expiry_date` est prorogé aujourd'hui (R32).
func is_prorogated(expiry_date: int) -> bool:
	if expiry_date >= today:
		return false
	var rule: ProrogationRule = prorogation()
	return rule != null and rule.covers(expiry_date, today)


## R33 active : les réintégrations de l'onglet Révocations sont honorées.
func honors_reinstatements() -> bool:
	if rule_set == null:
		return false
	for rule: Rule in rule_set.rules:
		if rule is ReinstatementRule:
			return true
	return false


func find_ledger(entry_id: StringName) -> LedgerEntry:
	for entry: LedgerEntry in ledger:
		if entry.id == entry_id:
			return entry
	return null


## Entrée de la Main courante portant ce N° ID, ou null.
func find_ledger_by_citizen(citizen_id: Variant) -> LedgerEntry:
	for entry: LedgerEntry in ledger:
		if FieldValue.equals(entry.citizen_id, citizen_id):
			return entry
	return null


func find_summons(entry_id: StringName) -> SummonsEntry:
	for entry: SummonsEntry in summons:
		if entry.id == entry_id:
			return entry
	return null


## Entrée de l'onglet Convocations portant ce N°, ou null.
func find_summons_by_number(number: Variant) -> SummonsEntry:
	for entry: SummonsEntry in summons:
		if FieldValue.equals(entry.number, number):
			return entry
	return null


## R36 active du jour (convocations de l'Enquête), ou null.
func summons_rule() -> SummonsRule:
	if rule_set == null:
		return null
	for rule: Rule in rule_set.rules:
		if rule is SummonsRule:
			return rule as SummonsRule
	return null


## Le porteur présente une convocation **authentique** (R36 active) : N° à
## l'onglet Convocations, au nom de la carte. Exempte des règles déclarées
## `summons_exempt` (R19, R23, R30, R31, R34, R35, R37 ; jamais R22).
func has_valid_summons(case: Case) -> bool:
	var rule: SummonsRule = summons_rule()
	return rule != null and rule.is_valid_summons(case, self)
