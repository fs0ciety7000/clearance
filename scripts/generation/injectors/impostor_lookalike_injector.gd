## `IMPOSTOR_LOOKALIKE` (GDD §6, ARCHITECTURE §9.3) : un sosie usurpe
## l'identité des papiers. La photo (la victime) est dérivée du visage du
## passager avec **1–2** slots comparés modifiés ; les papiers restent
## cohérents entre eux ; `truth` reçoit la vraie identité de l'usurpateur
## (nouveaux noms, naissance, N° ID). L'apparence du passager n'est jamais
## touchée. Paramètres : `trait_count` (1–2), `photo_noise`.
class_name ImpostorLookalikeInjector
extends AnomalyInjector

const TRAITS: Vector2i = Vector2i(1, 2)
const HAIR_NOISE_CHANCE: float = 0.5


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.IMPOSTOR_LOOKALIKE


func is_face_anomaly() -> bool:
	return true


func inject(state: InjectionState) -> Anomaly:
	var ref: FieldRef = PortraitMismatchInjector.pick_portrait(self, state)
	if ref == null:
		return null
	var presented: Passenger = state.case.passenger_presented
	var faction: FactionDef = state.get_faction(state.truth.faction_id)
	if faction == null:
		return null
	var wanted: int = clampi(state.param_int(&"trait_count", state.rng.randi_range(TRAITS.x, TRAITS.y)), TRAITS.x, TRAITS.y)
	var changed: Array[StringName] = []
	var base: PassengerAppearance = DocumentFactory.official_photo_of(presented.appearance)
	var photo: PassengerAppearance = state.appearance_gen.derive_identity(state.rng, base, wanted, presented.faction_id, changed)
	if changed.is_empty():
		return null
	if state.param_bool(&"photo_noise", state.rng.chance(HAIR_NOISE_CHANCE)):
		photo.traits[PassengerAppearance.SLOT_HAIR] = state.appearance_gen.reroll_slot(
				state.rng, photo, PassengerAppearance.SLOT_HAIR, presented.faction_id)
	var anomaly: Anomaly = PortraitMismatchInjector.replace_photo(self, state, ref, photo)
	var original: Dictionary[StringName, StringName] = {}
	var injected: Dictionary[StringName, StringName] = {}
	for slot: StringName in changed:
		original[slot] = base.get_trait(slot)
		injected[slot] = photo.get_trait(slot)
	anomaly.original_value = original
	anomaly.injected_value = injected
	# L'usurpateur : même visage, autre identité civile.
	PassengerGenerator.draw_identity(state.rng, faction, state.ctx.today, state.truth)
	return anomaly
