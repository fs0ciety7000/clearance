## `UNREGISTERED_VESSEL` (Acte II, R26 ; docs/ACT2.md §2.2) : le vaisseau du
## laissez-passer de dérive d'un `DRV` n'est pas (ou plus) au Registre des
## cargos — cargo démantelé (SILLAGE) ou inconnu. Seulement sur un `DRV`
## porteur d'un laissez-passer.
## Paramètre : `vessel` (nom imposé ; s'il est aussi le nom de famille du
## porteur, seule l'inscription au registre est fautive : SC-33).
class_name UnregisteredVesselInjector
extends AnomalyInjector

const VESSEL_PATH: StringName = &"vessel"
## Cargos hors registre (démantelés ou fantômes), tirés pour un cas généré.
const UNREGISTERED: PackedStringArray = ["Sillage", "Écume-Grise", "Albatros-3", "Nocturne", "Ferraille"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.UNREGISTERED_VESSEL


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, DriftPassRule):
		var drift: DriftPassRule = rule
		if not drift.applies_to(state.case):
			continue
		var pass_doc: DocumentInstance = state.case.get_own_document(drift.document_id)
		var field_id: StringName = field_for(state.case, drift.document_id, VESSEL_PATH)
		if pass_doc == null or field_id == &"" or not state.is_free(drift.document_id, field_id) \
				or state.filter_documents([drift.document_id]).is_empty():
			continue
		var original: Variant = pass_doc.get_value(field_id)
		var vessel: String = str(state.param(&"vessel", ""))
		if vessel.is_empty():
			var pool: PackedStringArray = []
			for name: String in UNREGISTERED:
				if not drift.is_registered(name):
					pool.append(name)
			if pool.is_empty():
				return null
			vessel = pool[state.rng.randi_range(0, pool.size() - 1)]
		if drift.is_registered(vessel):
			return null
		pass_doc.set_value(field_id, vessel.to_upper())
		state.mark(drift.document_id, field_id)
		state.mark(drift.card_id, field_for(state.case, drift.card_id, &"faction_id"))
		return make_anomaly(get_kind(), drift.document_id, field_id, original, vessel.to_upper())
	return null
