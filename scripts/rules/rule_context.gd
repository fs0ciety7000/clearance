## Contexte d'évaluation des règles (ARCHITECTURE §5.3, §6).
##
## Passé explicitement plutôt que lu dans un autoload : règles pures et
## testables. `rule_set` sert au `DiscrepancyChecker` (comparaison champ ↔
## règle : seules les règles actives du jour sont comparables).
##
## M12 (B54, ARCHITECTURE §11.3) — règles mutables en cours de shift : les
## changements (`RuleChangeDef`) s'appliquent à la **copie de shift** du
## RuleSet (`ensure_shift_rules`), tout de suite (`apply_changes`) ou au
## passager suivant (`queue_changes` puis `apply_pending`, appelé par le
## `DayController` juste avant de construire le cas : verdict attendu calculé
## à la présentation, D-077). Les familles de règles lisent leurs paramètres
## surchargés par `param()` et les listes nommées par `get_list()` ;
## `now_minute` = heure de présentation du passager en cours.
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
## M12 : heure de présentation du passager en cours (minutes depuis minuit),
## −1 si inconnue (surcharges horaires, EV-08).
var now_minute: int = -1
## M12 : changements en attente du passager suivant (`queue_changes`) :
## `{source, changes: Array[RuleChangeDef]}` ou `{source, revert: true}`.
var _pending: Array[Dictionary] = []


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
	ctx.now_minute = now_minute
	return ctx


# ---------------------------------------------------------------------------
# M12 (B54) : règles mutables en cours de shift
# ---------------------------------------------------------------------------

## Garantit que `rule_set` est une copie de shift (mutable) ; renvoie la copie.
## Le `DayController` la crée au début du shift (copie de `DayDef` comprise,
## pour que le générateur lise la même) ; ici, repli pour les tests.
func ensure_shift_rules() -> RuleSet:
	if rule_set == null:
		rule_set = RuleSet.new()
		rule_set.is_shift_copy = true
	elif not rule_set.is_shift_copy:
		rule_set = rule_set.make_shift_copy()
	return rule_set


## Applique tout de suite des changements ; renvoie la différence.
func apply_changes(changes: Array[RuleChangeDef], source: StringName = &"") -> RuleDiff:
	return ensure_shift_rules().apply_changes(changes, source)


## Défait tout de suite les changements d'une source.
func revert_source(source: StringName) -> RuleDiff:
	return ensure_shift_rules().revert_source(source)


## Met des changements en attente : ils prennent effet au passager suivant
## (`apply_pending`), jamais sur le passager déjà à la vitre (D-129, règle 1).
func queue_changes(changes: Array[RuleChangeDef], source: StringName = &"") -> void:
	_pending.append({"source": source, "changes": changes.duplicate()})


## Met en attente l'annulation d'une source (fin d'événement, au passager suivant).
func queue_revert(source: StringName) -> void:
	_pending.append({"source": source, "revert": true})


func has_pending_changes() -> bool:
	return not _pending.is_empty()


## Applique les changements en attente, dans l'ordre ; différence fusionnée
## (vide s'il n'y avait rien).
func apply_pending() -> RuleDiff:
	var total: RuleDiff = RuleDiff.new()
	var queue: Array[Dictionary] = _pending.duplicate()
	_pending.clear()
	for row: Dictionary in queue:
		var source: StringName = row.get("source", &"")
		var diff: RuleDiff
		if row.get("revert", false):
			diff = revert_source(source)
		else:
			var changes: Array[RuleChangeDef] = []
			for change: Variant in row.get("changes", []):
				if change is RuleChangeDef:
					changes.append(change)
			diff = apply_changes(changes, source)
		total.merge(diff)
	return total


## Paramètre `param` de la règle `rule_id` pour ce cas (surcharge en cours,
## sinon `default`). Portée : origine et motif du passager présenté, heure de
## présentation (`now_minute`). Les familles de règles (lot B) l'appellent pour
## tout paramètre surchargeable : `ctx.param(id, &"max_age_days", max_age_days, case)`.
func param(rule_id: StringName, key: StringName, default: Variant, case: Case = null) -> Variant:
	if rule_set == null or not rule_set.is_shift_copy:
		return default
	var faction_id: StringName = &""
	var purpose: StringName = &""
	if case != null and case.passenger_presented != null:
		faction_id = case.passenger_presented.faction_id
		purpose = case.passenger_presented.purpose
	return rule_set.get_param(rule_id, key, default, faction_id, purpose, now_minute)


## Modificateur entier du shift (`RuleChangeDef.MOD_*`), 0 si aucun.
func modifier(name: StringName) -> int:
	if rule_set == null or not rule_set.is_shift_copy:
		return 0
	return rule_set.get_modifier(name)


## Liste nommée du shift (`stolen` : cartes volées, EV-07). `&""` ou
## `&"revoked"` : l'onglet Révocations (`revoked`).
func get_list(label: StringName) -> Array[RevokedEntry]:
	if label == &"" or label == &"revoked":
		return revoked
	var result: Array[RevokedEntry] = []
	if rule_set == null or not rule_set.lists.has(label) or rule_set.overlay_suspended:
		return result
	for entry: Variant in rule_set.lists[label]:
		if entry is RevokedEntry:
			result.append(entry)
	return result


## Publie une liste nommée (générateur ou `DayController`) ; vide = retirée.
func set_list(label: StringName, entries: Array[RevokedEntry]) -> void:
	if label == &"" or label == &"revoked":
		revoked = entries.duplicate()
		return
	var shift: RuleSet = ensure_shift_rules()
	if entries.is_empty():
		shift.lists.erase(label)
	else:
		shift.lists[label] = entries.duplicate()


## Vrai si le N° ID figure dans la liste nommée.
func is_listed(label: StringName, citizen_id: Variant) -> bool:
	for entry: RevokedEntry in get_list(label):
		if FieldValue.equals(entry.citizen_id, citizen_id):
			return true
	return false


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
