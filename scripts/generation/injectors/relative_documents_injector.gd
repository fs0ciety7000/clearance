## `RELATIVE_DOCUMENTS` (GDD §6, ARCHITECTURE §9.3, M7) : le passager porte les
## papiers d'un parent — même nom de famille, prénom, naissance et N° ID du
## parent (cohérents sur tous les documents), photo « air de famille » (2 traits
## d'identité modifiés) d'une autre tranche d'âge. La vérité (`truth`) reste la
## personne réelle ; son visage n'est jamais touché. Détecté par R03 (photo) et
## R18 (âge apparent ↔ naissance, DÉTENTION).
## Paramètres : `relative_given_name`, `relative_birth` (jour `GameDate`).
class_name RelativeDocumentsInjector
extends AnomalyInjector

const PATHS: Array[StringName] = [&"given_name", &"birth_date", &"citizen_id"]
const FAMILY_TRAITS: int = 2


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.RELATIVE_DOCUMENTS


func is_face_anomaly() -> bool:
	return true


func inject(state: InjectionState) -> Anomaly:
	var c: Case = state.case
	var refs: Dictionary[StringName, Array] = {}
	for path: StringName in PATHS:
		var path_refs: Array[FieldRef] = c.find_refs_by_truth_path(path)
		for ref: FieldRef in path_refs:
			if not state.is_free(ref.document_id, ref.field_id):
				return null
		refs[path] = path_refs
	var portrait: FieldRef = PortraitMismatchInjector.pick_portrait(self, state)
	if portrait == null:
		return null
	var presented: Passenger = c.passenger_presented
	var faction: FactionDef = state.get_faction(presented.faction_id)
	if faction == null or faction.name_pool == null:
		return null
	var band: int = presented.appearance.age_band
	var forced_birth: Variant = state.param(&"relative_birth", null)
	var birth: int = 0
	var relative_band: int = band
	if forced_birth is int:
		birth = forced_birth
		relative_band = ApparentAgeRule.band_of_birth(birth, state.ctx.today)
	else:
		var bands: Array[int] = []
		for candidate: int in [band - 1, band + 1]:
			if candidate >= 0 and candidate < PassengerGenerator.AGE_BANDS.size():
				bands.append(candidate)
		relative_band = bands[state.rng.randi_range(0, bands.size() - 1)]
		birth = PassengerGenerator.birth_date_for_band(state.rng, relative_band, state.ctx.today)
	var given: String = str(state.param(&"relative_given_name", ""))
	if given.is_empty():
		given = faction.name_pool.pick_given_name(state.rng, presented.sex)
	var citizen_id: String = PassengerGenerator.make_citizen_id(state.rng, faction)
	var values: Dictionary[StringName, Variant] = {&"given_name": given, &"birth_date": birth, &"citizen_id": citizen_id}
	for path: StringName in PATHS:
		for ref: FieldRef in refs[path]:
			c.get_document(ref.document_id).set_value(ref.field_id, values[path])
			state.mark(ref.document_id, ref.field_id)
		presented.set(path, values[path])
	var changed: Array[StringName] = []
	var base: PassengerAppearance = DocumentFactory.official_photo_of(presented.appearance)
	var photo: PassengerAppearance = state.appearance_gen.derive_identity(state.rng, base, FAMILY_TRAITS,
			presented.faction_id, changed)
	photo.age_band = relative_band
	var anomaly: Anomaly = PortraitMismatchInjector.replace_photo(self, state, portrait, photo)
	anomaly.original_value = state.truth.full_name()
	anomaly.injected_value = "%s %s" % [given, presented.family_name]
	return anomaly
