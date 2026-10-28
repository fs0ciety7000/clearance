## `OUTDATED_FIRMWARE` (Acte II, R27 ; docs/ACT2.md §2.2) : la mise à jour du
## shunt `NX-` (champ « Firmware NX » de la carte) date de 90 jours ou plus. Si
## le passager ne porte pas de `NX-`, le générateur lui en ajoute un, visible
## **et** déclaré sur la carte (aucune autre discordance).
## Paramètre : `firmware_age_days` (âge imposé, SC-34 : 91).
class_name OutdatedFirmwareInjector
extends AnomalyInjector

const FIRMWARE_PATH: StringName = &"firmware_date"
const NX_PREFIX: String = "NX-"
const DEFAULT_SHUNT: String = "NX-12"
const EXTRA_DAYS_MAX: int = 40


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.OUTDATED_FIRMWARE


func inject(state: InjectionState) -> Anomaly:
	for rule: Rule in active_rules(state, DocumentNotExpiredRule):
		var age_rule: DocumentNotExpiredRule = rule
		if age_rule.field_path != FIRMWARE_PATH:
			continue
		var card: DocumentInstance = state.case.get_own_document(age_rule.document_id)
		var field_id: StringName = field_for(state.case, age_rule.document_id, FIRMWARE_PATH)
		if card == null or field_id == &"" or not state.is_free(age_rule.document_id, field_id) \
				or state.filter_documents([age_rule.document_id]).is_empty():
			continue
		var implants_field: StringName = field_for(state.case, age_rule.document_id, &"implants")
		var presented: Passenger = state.case.passenger_presented
		if not has_shunt(presented.implants):
			# Ajout d'un shunt déclaré (carte + corps) : jamais sur un champ déjà altéré.
			if implants_field != &"" and not state.is_free(age_rule.document_id, implants_field):
				continue
			presented.implants.append(DEFAULT_SHUNT)
			state.truth.implants.append(DEFAULT_SHUNT)
			if implants_field != &"":
				var declared: PackedStringArray = ImplantsDeclaredRule.as_list(card.get_value(implants_field)).duplicate()
				declared.append(DEFAULT_SHUNT)
				card.set_value(implants_field, declared)
		var original: Variant = card.get_value(field_id)
		var age: int = state.param_int(&"firmware_age_days", age_rule.max_age_days + state.rng.randi_range(1, EXTRA_DAYS_MAX))
		age = maxi(age, age_rule.max_age_days)
		var date: int = state.ctx.today - age
		card.set_value(field_id, date)
		presented.firmware_date = date
		state.truth.firmware_date = date
		state.mark(age_rule.document_id, field_id)
		return make_anomaly(get_kind(), age_rule.document_id, field_id, original, date)
	return null


static func has_shunt(implants: PackedStringArray) -> bool:
	for code: String in implants:
		if code.begins_with(NX_PREFIX):
			return true
	return false
