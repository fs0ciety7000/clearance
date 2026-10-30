## Famille « Objets interdits » (R45 objets interdits, R46 armes ; M13,
## docs/M13.md §2.5–§2.7 ; D-147) — 28ᵉ famille.
##
## Lit le contenu de la fouille (`Case.search_layout`, partie du cas cachée
## jusqu'au scan, jamais `CaseKey`) : tout objet de la nature `item_kind`
## (CONTRABAND pour R45, WEAPON pour R46) dont la catégorie du catalogue est
## dans `categories` est une violation, de la sévérité de la règle (R45 : 2,
## REFUS ; R46 : 3, DÉTENTION). Le verdict attendu existe donc **sans fouille**
## (D-005) : approuver un porteur vaut ENTRÉE IRRÉGULIÈRE. Preuves : objet
## (`FieldRef.scan`) ↔ règle, ou objet ↔ entrée de l'onglet Contrebande
## (`FieldRef.contraband_entry`). Un objet n'est comparable qu'une fois révélé
## (`DiscrepancyChecker`).
class_name ContrabandRule
extends Rule

## Nature des objets visés (`SearchItem.Kind.CONTRABAND` ou `WEAPON`).
@export var item_kind: SearchItem.Kind = SearchItem.Kind.CONTRABAND
## Catégories du catalogue interdites (`oxygen`, `stimulant`, `medicine`,
## `data`, `seeds` ; armes : `blade`, `jammer`).
@export var categories: Array[StringName] = []
## Type d'anomalie détecté (`CONTRABAND` ou `CONCEALED_WEAPON`).
@export var anomaly_kind: AnomalyType.Kind = AnomalyType.Kind.CONTRABAND
## Clé de raison de la violation (`viol_contraband`, `viol_weapon`).
@export var reason_key: String = "viol_contraband"


## Objets du cas interdits par cette règle (révélés ou non).
func forbidden_items(case: Case) -> Array[SearchItem]:
	var result: Array[SearchItem] = []
	if case == null or case.search_layout == null:
		return result
	for item: SearchItem in case.search_layout.items:
		if is_forbidden(item):
			result.append(item)
	return result


func is_forbidden(item: SearchItem) -> bool:
	return item != null and item.kind == item_kind and categories.has(item.category)


func evaluate(case: Case, _ctx: RuleContext) -> Array[Violation]:
	var violations: Array[Violation] = []
	for item: SearchItem in forbidden_items(case):
		var refs: Array[FieldRef] = [item.get_ref(), get_ref(), FieldRef.contraband_entry(item.category)]
		violations.append(make_violation(refs, reason_key))
	return violations


func get_detectable_anomalies() -> Array[AnomalyType.Kind]:
	return [anomaly_kind]


## Objet ↔ règle : DISCORDANT s'il est interdit par elle ; CONCORDANT pour un
## objet autorisé (légitime) ; INCOMPARABLE pour un implant, un imprimé ou un
## objet visé par l'autre règle (une arme ↔ R45).
func check_against(case: Case, ref: FieldRef, _ctx: RuleContext) -> Discrepancy.Result:
	if ref == null or not ref.is_scan():
		return Discrepancy.Result.INCOMPARABLE
	var item: SearchItem = case.get_scan_item(ref)
	if item == null:
		return Discrepancy.Result.INCOMPARABLE
	if is_forbidden(item):
		return Discrepancy.Result.DISCORDANT
	if item.kind == SearchItem.Kind.LEGIT:
		return Discrepancy.Result.CONCORDANT
	return Discrepancy.Result.INCOMPARABLE


## Règles R45 / R46 actives d'un RuleSet.
static func active_in(rule_set: RuleSet) -> Array[ContrabandRule]:
	var result: Array[ContrabandRule] = []
	if rule_set == null:
		return result
	for rule: Rule in rule_set.rules:
		if rule is ContrabandRule:
			result.append(rule)
	return result
