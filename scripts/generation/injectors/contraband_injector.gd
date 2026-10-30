## `CONTRABAND` (M13, docs/M13.md §2.5, §2.7 ; D-147, D-149 ; B73) : un objet
## interdit CB-01 → CB-05 (R45) dans une zone de fouille, avec un **indice**
## visible (invariant « porteur ⇒ indice ») : l'objet est dans la zone de
## l'indice avec la probabilité du catalogue (`cue_hit_rates`), sinon dans une
## autre zone permise. Catégorie selon l'origine (CER → O₂, semences ; TYC →
## O₂, médicaments ; HAL → données ; DRV → stimulants, semences). Le portique
## doit être en service (R44 : jamais pendant une coupure EV-05). 0 ou 1 autre
## anomalie ; jamais avec `WANTED_PERSON` ni `REVOKED_ID`.
## L'objet est posé par le `SearchGenerator` après l'injection.
## Paramètres : `item` (entrée imposée, `cb01`…), `subtle` (Garde : objet
## presque identique à un objet légitime, déjà le cas de CB-01 / CB-03 / CB-04).
class_name ContrabandInjector
extends AnomalyInjector

const INCOMPATIBLE: Array[AnomalyType.Kind] = [AnomalyType.Kind.WANTED_PERSON, AnomalyType.Kind.REVOKED_ID,
		AnomalyType.Kind.CONCEALED_WEAPON]
## Paires subtiles (Garde) : objets interdits presque identiques à un objet légitime.
const SUBTLE_ITEMS: PackedStringArray = ["cb01", "cb03", "cb04"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.CONTRABAND


func inject(state: InjectionState) -> Anomaly:
	var rule: ContrabandRule = _rule(state)
	var catalog: SearchCatalogDef = state.get_search_catalog()
	if rule == null or catalog == null or not state.search_enabled() or state.injected.size() >= 2:
		return null
	for kind: AnomalyType.Kind in state.injected:
		if INCOMPATIBLE.has(kind):
			return null
	var candidates: Array[SearchItemDef] = _candidates(state, catalog, rule)
	if candidates.is_empty():
		return null
	var def: SearchItemDef = candidates[state.rng.randi_range(0, candidates.size() - 1)]
	return plan_item(state, catalog, def, get_kind())


func _rule(state: InjectionState) -> ContrabandRule:
	for rule: Rule in active_rules(state, ContrabandRule):
		return rule
	return null


func _candidates(state: InjectionState, catalog: SearchCatalogDef, rule: ContrabandRule) -> Array[SearchItemDef]:
	var forced: StringName = StringName(str(state.param(&"item", "")))
	var ids: PackedStringArray = catalog.contraband_for(state.case.passenger_presented.faction_id)
	if state.param_bool(CaseBuilder.SUBTLE_PARAM, false):
		var subtle: PackedStringArray = []
		for item_id: String in ids:
			if SUBTLE_ITEMS.has(item_id):
				subtle.append(item_id)
		if not subtle.is_empty():
			ids = subtle
	var result: Array[SearchItemDef] = []
	for item_id: String in ids if forced == &"" else PackedStringArray([String(forced)]):
		var def: SearchItemDef = catalog.get_item(StringName(item_id))
		if def != null and def.kind == rule.item_kind and rule.categories.has(def.category):
			result.append(def)
	return result


## Planifie un objet (ou un implant, `implant_code`) avec son indice ; renvoie
## l'anomalie (sa référence `FieldRef.scan` est posée au placement).
static func plan_item(state: InjectionState, catalog: SearchCatalogDef, def: SearchItemDef,
		kind: AnomalyType.Kind, implant_code: String = "") -> Anomaly:
	var anomaly: Anomaly = AnomalyInjector.make_anomaly(kind, FieldRef.SCAN_DOCUMENT_ID, &"", null,
			implant_code if not implant_code.is_empty() else String(def.id))
	if state.param_bool(&"scripted_search", false):
		# Cas scénarisé : l'objet est écrit dans `ScriptedCaseDef.search_items`.
		state.search_plan.append({"anomaly": anomaly})
		return anomaly
	var zones: Array[StringName] = []
	if not implant_code.is_empty():
		zones.append(catalog.implant_zone(implant_code))
	else:
		for zone: String in def.zones:
			zones.append(StringName(zone))
	if zones.is_empty() or zones[0] == &"":
		return null
	# Indice : un indice dont la zone peut contenir l'objet, puis la zone réelle.
	var cues: Array[StringName] = []
	for cue: StringName in SearchLayout.CUES:
		if zones.has(SearchLayout.zone_of_cue(cue)):
			cues.append(cue)
	if cues.is_empty():
		cues = SearchLayout.CUES.duplicate()
	var cue: StringName = cues[state.rng.randi_range(0, cues.size() - 1)]
	var cue_zone: StringName = SearchLayout.zone_of_cue(cue)
	var zone: StringName = cue_zone if zones.has(cue_zone) else zones[0]
	var others: Array[StringName] = []
	for other: StringName in zones:
		if other != cue_zone:
			others.append(other)
	if not others.is_empty() and not state.rng.chance(catalog.cue_hit_rates.get(cue, 0.8)):
		zone = others[state.rng.randi_range(0, others.size() - 1)]
	state.search_plan.append({"item": def, "implant": implant_code, "zone": zone, "cue": cue, "anomaly": anomaly})
	return anomaly
