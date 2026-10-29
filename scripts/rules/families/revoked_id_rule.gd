## Famille « Révocations » (R30, Acte II J17 ; docs/ACT2.md §2.4) : le N° ID de
## la carte figure à l'onglet « Révocations » du jour (`RuleContext.revoked`,
## liste liée à des passagers du jour comme les avis, D-056) : le titulaire
## n'est plus citoyen, refus.
## Anomalie détectée : `REVOKED_ID`. Preuve : N° ID (carte) ↔ règle, ou N° ID ↔
## entrée de l'onglet (`FieldRef.revoked`).
##
## M12 (B55) : la même famille lit une **liste nommée** (`list_label`) — vide
## ou `revoked` : l'onglet Révocations (R30, R40 « Liste du Conseil » du
## monde B, intitulée par `list_title_key`) ; `stolen` : bulletin des cartes
## volées (EV-07, `RuleContext.get_list`). `honor_reinstatements` : les
## réintégrations datées de la liste sont honorées même sans R33
## (R40 : « Réintégré·es par le Conseil : admis·es »).
class_name RevokedIdRule
extends Rule

@export var document_id: StringName = &"id_card"
## M12 : liste lue (`&""` = onglet Révocations ; `stolen` = cartes volées).
@export var list_label: StringName = &""
## M12 : intitulé de l'onglet de la liste (`rb_tab_council`, `rb_tab_stolen`), vide = Révocations.
@export var list_title_key: String = ""
## M12 (R40) : réintégrations datées honorées sans règle R33.
@export var honor_reinstatements: bool = false


## Ligne du Rulebook : expose la liste lue (`list_label`, `list_title_key`).
func get_rulebook_entry() -> RulebookEntry:
	var entry: RulebookEntry = super.get_rulebook_entry()
	entry.list_label = list_label
	entry.list_title_key = list_title_key
	return entry


## Entrées de la liste lue par cette règle.
func entries(ctx: RuleContext) -> Array[RevokedEntry]:
	if ctx == null:
		return []
	if list_label == &"" or list_label == &"revoked":
		return ctx.revoked
	return ctx.get_list(list_label)


## Vrai si les réintégrations de la liste sont honorées aujourd'hui (R33
## active, ou une règle de révocation active qui les honore, R40).
static func reinstatements_honored(ctx: RuleContext) -> bool:
	if ctx == null:
		return false
	if ctx.honors_reinstatements():
		return true
	if ctx.rule_set == null:
		return false
	for rule: Rule in ctx.rule_set.rules:
		if rule is RevokedIdRule and (rule as RevokedIdRule).honor_reinstatements:
			return true
	return false


## Entrée d'identifiant `entry_id` de l'onglet Révocations ou d'une liste
## nommée active (cartes volées), null sinon.
static func find_any_entry(ctx: RuleContext, entry_id: StringName) -> RevokedEntry:
	if ctx == null:
		return null
	var found: RevokedEntry = ctx.find_revoked(entry_id)
	if found != null or ctx.rule_set == null:
		return found
	for rule: Rule in ctx.rule_set.rules:
		var listed: RevokedIdRule = rule as RevokedIdRule
		if listed == null:
			continue
		for entry: RevokedEntry in listed.entries(ctx):
			if entry.id == entry_id:
				return entry
	return null


func find_entry(case: Case, ctx: RuleContext) -> RevokedEntry:
	if ctx == null:
		return null
	var value: Variant = PurposeConsistentRule._value(case, document_id, &"citizen_id")
	if value == null:
		return null
	var reinstatements: bool = honor_reinstatements or ctx.honors_reinstatements()
	for entry: RevokedEntry in entries(ctx):
		if FieldValue.equals(entry.citizen_id, value):
			# Acte III (R33) : réintégré·e à la date du jour → valide.
			if reinstatements and entry.is_reinstated(ctx.today):
				continue
			return entry
	return null


func evaluate(case: Case, ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	var entry: RevokedEntry = find_entry(case, ctx)
	if entry == null:
		return violations
	var refs: Array[FieldRef] = []
	PurposeConsistentRule._append(refs, Rule.find_ref(case, document_id, &"citizen_id"))
	refs.append(get_ref())
	refs.append(entry.get_ref())
	violations.append(make_violation(refs, "viol_revoked"))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [AnomalyType.Kind.REVOKED_ID]


func check_against(case: Case, ref: FieldRef, ctx: RuleContext) -> Discrepancy.Result:
	var field: FieldDef = case.get_field_def(ref)
	if field == null or ref.document_id != document_id or field.truth_path != &"citizen_id":
		return Discrepancy.Result.INCOMPARABLE
	return Discrepancy.Result.DISCORDANT if find_entry(case, ctx) != null else Discrepancy.Result.CONCORDANT


func get_referenced_truth_paths() -> Dictionary[StringName, Array]:
	return {document_id: [&"citizen_id"]}
