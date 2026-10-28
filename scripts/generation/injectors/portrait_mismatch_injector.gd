## `PORTRAIT_MISMATCH` (GDD §6, ARCHITECTURE §9.3) : la photo est celle d'une
## autre personne, à au moins 3 slots comparés (`identity && visible_in_portrait`)
## du porteur. L'apparence du passager n'est jamais touchée.
## Paramètres : `trait_count` (≥ 3), `photo_noise` (coupe différente).
class_name PortraitMismatchInjector
extends AnomalyInjector

const MIN_TRAITS: int = 3


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.PORTRAIT_MISMATCH


func is_face_anomaly() -> bool:
	return true


func inject(state: InjectionState) -> Anomaly:
	var ref: FieldRef = pick_portrait(self, state)
	if ref == null:
		return null
	var holder: PassengerAppearance = state.case.passenger_presented.appearance
	var faction_id: StringName = state.case.passenger_presented.faction_id
	var slots: Array[StringName] = state.appearance_gen.catalog.get_identity_slots()
	var wanted: int = clampi(state.param_int(&"trait_count", state.rng.randi_range(MIN_TRAITS, slots.size())), MIN_TRAITS, slots.size())
	var other: PassengerAppearance = DocumentFactory.official_photo_of(state.appearance_gen.generate(state.rng, faction_id))
	var forced: Array = state.rng.shuffled(slots)
	for i: int in wanted:
		var slot: StringName = forced[i]
		if other.get_trait(slot) == holder.get_trait(slot):
			other.traits[slot] = state.appearance_gen.reroll_slot(state.rng, other, slot, faction_id)
	if state.param_bool(&"photo_noise", false):
		other.traits[PassengerAppearance.SLOT_HAIR] = state.appearance_gen.reroll_slot(
				state.rng, holder, PassengerAppearance.SLOT_HAIR, faction_id)
	return replace_photo(self, state, ref, other)


## Premier portrait libre d'un document présent si la règle de photo est active.
static func pick_portrait(injector: AnomalyInjector, state: InjectionState) -> FieldRef:
	if state.face_anomaly:
		return null
	var active: bool = false
	for rule: Rule in injector.active_rules(state, PortraitMatchRule):
		var portrait_rule: PortraitMatchRule = rule
		active = active or portrait_rule.check_passenger_face
	if not active:
		return null
	var refs: Array[FieldRef] = []
	var allowed: Array[StringName] = state.filter_documents(state.case.get_document_ids())
	for ref: FieldRef in state.case.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT):
		if allowed.has(ref.document_id) and state.is_free(ref.document_id, ref.field_id):
			refs.append(ref)
	if refs.is_empty():
		return null
	return refs[state.rng.randi_range(0, refs.size() - 1)]


## Remplace l'apparence de la photo (cadrage et ancienneté conservés).
static func replace_photo(injector: AnomalyInjector, state: InjectionState, ref: FieldRef,
		photo: PassengerAppearance) -> Anomaly:
	var doc: DocumentInstance = state.case.get_document(ref.document_id)
	var old: PortraitValue = doc.get_value(ref.field_id)
	var portrait: PortraitValue = old.copy()
	portrait.appearance = photo
	doc.set_value(ref.field_id, portrait)
	state.mark(ref.document_id, ref.field_id)
	state.face_anomaly = true
	return AnomalyInjector.make_anomaly(injector.get_kind(), ref.document_id, ref.field_id, old.appearance, photo)
