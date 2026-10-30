## `CONCEALED_WEAPON` (M13, docs/M13.md §2.5, §2.7 ; D-147, D-149 ; B73) :
## une arme CB-06 (lame) ou CB-07 (émetteur de brouillage), R46 → DÉTENTION,
## avec un indice visible. **Seule** anomalie du cas ; tampon DÉTENTION
## disponible (`DayDef.detain_enabled`) ; portique en service (R44).
## Paramètre : `item` (`cb06` | `cb07`).
class_name ConcealedWeaponInjector
extends AnomalyInjector


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.CONCEALED_WEAPON


func inject(state: InjectionState) -> Anomaly:
	var catalog: SearchCatalogDef = state.get_search_catalog()
	if catalog == null or not state.search_enabled() or not state.injected.is_empty() or state.planned_count > 1:
		return null
	if state.ctx.day_def != null and not state.ctx.day_def.detain_enabled:
		return null
	var rule: ContrabandRule = null
	for candidate: Rule in active_rules(state, ContrabandRule):
		rule = candidate
	if rule == null:
		return null
	var forced: StringName = StringName(str(state.param(&"item", "")))
	var options: Array[SearchItemDef] = []
	for item_id: String in catalog.weapons if forced == &"" else PackedStringArray([String(forced)]):
		var def: SearchItemDef = catalog.get_item(StringName(item_id))
		if def != null and def.kind == rule.item_kind and rule.categories.has(def.category):
			options.append(def)
	if options.is_empty():
		return null
	var def: SearchItemDef = options[state.rng.randi_range(0, options.size() - 1)]
	return ContrabandInjector.plan_item(state, catalog, def, get_kind())
