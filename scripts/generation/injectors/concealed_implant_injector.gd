## `CONCEALED_IMPLANT` (M13, docs/M13.md §2.5, §2.7 ; D-147, D-149 ; B73) : un
## implant de localisation **dissimulée** (bras, jambes, torse, nuque),
## **absent** de la liste « Implants déclarés » : R15 le relève à la fouille
## (objet ↔ champ déclaré) ; `MIL-` (seulement si `detain_enabled`) →
## sévérité 3, DÉTENTION. Jamais visible sur l'acteur ni comparé au visage.
## Un indice visible l'accompagne (zone de l'implant, ou un autre indice selon
## `cue_hit_rates`). 0 ou 1 autre anomalie ; portique en service (R44).
## Paramètre : `implant` (code imposé, ex. `MIL-15`).
class_name ConcealedImplantInjector
extends AnomalyInjector

const CARD_ID: StringName = &"id_card"


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.CONCEALED_IMPLANT


func inject(state: InjectionState) -> Anomaly:
	var catalog: SearchCatalogDef = state.get_search_catalog()
	var rules: Array[Rule] = active_rules(state, ImplantsDeclaredRule)
	if catalog == null or rules.is_empty() or not state.search_enabled() or state.injected.size() >= 2:
		return null
	if state.injected.has(AnomalyType.Kind.CONCEALED_WEAPON) or state.case.get_own_document(CARD_ID) == null:
		return null
	var presented: Passenger = state.case.passenger_presented
	var declared: PackedStringArray = state.case.declared_implants()
	var forced: String = str(state.param(&"implant", ""))
	var pool: PackedStringArray = catalog.undeclared_civil.duplicate()
	if state.ctx.day_def == null or state.ctx.day_def.detain_enabled:
		pool.append_array(catalog.undeclared_military)
	if not forced.is_empty():
		pool = PackedStringArray([forced])
	var options: PackedStringArray = []
	for code: String in pool:
		if catalog.is_concealable(code) and not declared.has(code) and not presented.implants.has(code) \
				and not presented.concealed_implants.has(code):
			options.append(code)
	if options.is_empty():
		return null
	var code: String = options[state.rng.randi_range(0, options.size() - 1)]
	var anomaly: Anomaly = ContrabandInjector.plan_item(state, catalog, null, get_kind(), code)
	if anomaly == null:
		return null
	# La carte doit rester présentée et sa liste intacte : c'est la preuve (R15).
	state.mark(CARD_ID, field_for(state.case, CARD_ID, &"implants"))
	presented.concealed_implants.append(code)
	if not state.truth.concealed_implants.has(code):
		state.truth.concealed_implants.append(code)
	return anomaly
