## Construction d'un cas (ARCHITECTURE §9.2) — pur, déterministe.
##
## Une instance par jour : le roster d'apparences (§9.3) est calculé une fois
## depuis `day_seed`, puis `build(index)` produit le cas `index` à partir de
## `case_seed = mix(day_seed, index)` seul (indépendant des autres cas).
## Pipeline : cas scénarisé ? → passager vrai (`PassengerGenerator`) →
## documents valides (`DocumentFactory`) → contrôle `RuleEngine.validate() == []`
## (8 essais) → injection (`AnomalyInjector`) → visière → clé calculée par
## `RuleEngine.build_case_key()` sur le cas **final** (D-005) → invariants.
class_name CaseBuilder
extends RefCounted

const MAX_CLEAN_ATTEMPTS: int = 8
## Visière : ×1,5 si le cas porte une anomalie de visage, plafond 0,40 (GDD §4.4).
const VISOR_FACE_MULTIPLIER: float = 1.5
const VISOR_RATE_CAP: float = 0.40
const FACE_ANOMALIES: Array[AnomalyType.Kind] = [
	AnomalyType.Kind.PORTRAIT_MISMATCH,
	AnomalyType.Kind.IMPOSTOR_LOOKALIKE,
	AnomalyType.Kind.RELATIVE_DOCUMENTS,
]
## Étiquettes de dialogue (interrogatoire) posées par le générateur.
const TAG_VISOR_DOWN: StringName = &"visor_down"
const TAG_OLD_PHOTO: StringName = &"old_photo"

# Sels des sous-générateurs d'un cas (flux indépendants).
const SALT_PASSENGER: int = 1
const SALT_DOCUMENTS: int = 2
const SALT_INJECTION: int = 3
const SALT_PRESENTATION: int = 4

var data: DataCatalog = null
var day: DayDef = null
var day_seed: int = 0
## Drapeaux narratifs satisfaits (`ScriptedCaseDef.requires_flag`).
var flags: Array[StringName] = []
var ctx: RuleContext = null
var roster: AppearanceRoster = null
var appearance_gen: AppearanceGenerator = null
var _injectors: Dictionary[AnomalyType.Kind, AnomalyInjector] = {}


func _init(p_data: DataCatalog, p_day: DayDef, p_day_seed: int, p_flags: Array[StringName] = []) -> void:
	data = p_data
	day = p_day
	day_seed = p_day_seed
	flags = p_flags.duplicate()
	ctx = RuleContext.for_day(day, data.factions, data.documents)
	if data.appearance_catalog != null:
		ctx.identity_slots = data.appearance_catalog.get_identity_slots()
	appearance_gen = AppearanceGenerator.new(data.appearance_catalog)
	_injectors = InjectorRegistry.create_all()
	roster = appearance_gen.build_day_roster(day_seed, day.passenger_count, get_active_scripted_cases(),
			day.faction_weights, day.game_date)


## Cas scénarisés du jour dont le drapeau requis est satisfait.
func get_active_scripted_cases() -> Array[ScriptedCaseDef]:
	var result: Array[ScriptedCaseDef] = []
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted != null and (scripted.requires_flag == &"" or flags.has(scripted.requires_flag)):
			result.append(scripted)
	return result


func get_scripted_case(index: int) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in get_active_scripted_cases():
		if scripted.at_index == index:
			return scripted
	return null


## Tous les cas du jour, dans l'ordre.
func build_day() -> Array[GeneratedCase]:
	var result: Array[GeneratedCase] = []
	for i: int in day.passenger_count:
		result.append(build(i))
	return result


## Cas `index` du jour (scénarisé s'il y a lieu, sinon tirage selon le `DayDef`).
func build(index: int) -> GeneratedCase:
	var scripted: ScriptedCaseDef = get_scripted_case(index)
	if scripted != null:
		return _build(index, scripted, scripted.forced_anomalies, scripted.injection_params, true)
	return _build(index, null, [], {}, false)


## Cas `index` avec une liste **exacte** d'anomalies (tests, outils).
func build_with(index: int, anomalies: Array[AnomalyType.Kind], params: Dictionary = {}) -> GeneratedCase:
	return _build(index, null, anomalies, params, true)


func _build(index: int, scripted: ScriptedCaseDef, forced: Array[AnomalyType.Kind], params: Dictionary,
		exact: bool) -> GeneratedCase:
	var result: GeneratedCase = GeneratedCase.new()
	var entry: AppearanceRoster.Entry = roster.get_entry(index)
	if entry == null:
		return null
	var case_seed: int = SeededRng.case_seed(day_seed, index)
	var rng: SeededRng = SeededRng.new(case_seed)
	var overrides: Dictionary = scripted.passenger_overrides if scripted != null else {}
	var faction: FactionDef = data.factions.get(entry.faction_id, null)
	if faction == null:
		push_error("CaseBuilder: origine inconnue « %s » (jour %d, cas %d)" % [entry.faction_id, day.day_number, index])
		return null
	result.scripted_id = scripted.id if scripted != null else &""
	var noise_rng: SeededRng = rng.fork(SALT_PRESENTATION)
	result.photo_noise = scripted == null and noise_rng.chance(day.legit_noise_rate)
	if scripted != null:
		var forced_noise: bool = scripted.injection_params.get(&"photo_noise", false)
		result.photo_noise = result.photo_noise or forced_noise

	# 1–4. Passager vrai, documents valides, contrôle.
	var truth: Passenger = null
	var c: Case = null
	for attempt: int in MAX_CLEAN_ATTEMPTS:
		var attempt_rng: SeededRng = rng.fork(attempt)
		var case_id: StringName = StringName("d%02d_c%02d" % [day.day_number, index])
		truth = PassengerGenerator.generate(attempt_rng.fork(SALT_PASSENGER), faction, day.game_date, entry,
				overrides, StringName("p_%s" % case_id))
		c = _make_clean_case(truth, attempt_rng.fork(SALT_DOCUMENTS), result.photo_noise)
		c.case_id = case_id
		c.index = index
		c.case_seed = case_seed
		result.clean_attempts = attempt + 1
		result.clean_violation_count = RuleEngine.validate(c, day.rule_set, ctx).size()
		if result.clean_violation_count == 0:
			break
		if attempt == MAX_CLEAN_ATTEMPTS - 1:
			push_error("CaseBuilder: aucun cas propre après %d essais (jour %d, cas %d, seed %d)"
					% [MAX_CLEAN_ATTEMPTS, day.day_number, index, case_seed])

	# 5. Injection.
	var state: InjectionState = InjectionState.new()
	state.case = c
	state.truth = truth
	state.rng = rng.fork(SALT_INJECTION)
	state.ctx = ctx
	state.data = data
	state.appearance_gen = appearance_gen
	state.params = params
	var anomalies: Array[Anomaly] = []
	if exact:
		result.requested_anomalies = forced.size()
		for kind: AnomalyType.Kind in forced:
			var anomaly: Anomaly = _inject(kind, state)
			if anomaly == null:
				push_error("CaseBuilder: anomalie imposée %s impossible (jour %d, cas %d)"
						% [AnomalyType.name_of(kind), day.day_number, index])
			else:
				anomalies.append(anomaly)
	else:
		anomalies = _inject_random(state, result)

	# 6. Présentation : visière (état physique, vérité et présenté), étiquettes.
	var face: bool = false
	for anomaly: Anomaly in anomalies:
		face = face or FACE_ANOMALIES.has(anomaly.type)
	if scripted == null and not exact:
		var rate: float = day.visor_down_rate * (VISOR_FACE_MULTIPLIER if face else 1.0)
		if noise_rng.chance(minf(rate, VISOR_RATE_CAP)):
			truth.appearance.traits[PassengerAppearance.SLOT_HEADWEAR] = PassengerAppearance.VISOR_DOWN
			c.passenger_presented.appearance.traits[PassengerAppearance.SLOT_HEADWEAR] = PassengerAppearance.VISOR_DOWN
	result.visor_down = c.passenger_presented.appearance.is_face_covered()
	if scripted != null and scripted.dialogue_id != &"":
		c.dialogue_tags.append(scripted.dialogue_id)
	if result.visor_down:
		c.dialogue_tags.append(TAG_VISOR_DOWN)
	if result.photo_noise:
		c.dialogue_tags.append(TAG_OLD_PHOTO)

	# 7. Clé calculée sur le cas final, invariants.
	result.case = c
	result.key = RuleEngine.build_case_key(c, truth, anomalies, day.rule_set, ctx)
	result.invariant_errors = check_invariants(result, ctx)
	if not result.invariant_errors.is_empty():
		push_error("CaseBuilder: invariants violés (jour %d, cas %d, seed %d) : %s"
				% [day.day_number, index, case_seed, "; ".join(result.invariant_errors)])
	return result


func _make_clean_case(truth: Passenger, rng: SeededRng, photo_noise: bool) -> Case:
	var c: Case = Case.new()
	c.passenger_presented = truth.copy()
	for document_id: StringName in required_documents_for(truth.faction_id):
		var def: DocumentTypeDef = data.documents.get(document_id, null)
		if def == null:
			push_error("CaseBuilder: document inconnu « %s »" % document_id)
			continue
		var remaining: int = truth.stay_days if def.find_field_by_truth_path(&"stay_days") != null else 1
		var noise: bool = photo_noise and def.find_field_by_truth_path(&"appearance") != null
		c.documents.append(DocumentFactory.create(def, truth, day.game_date, rng.fork(SeededRng.hash_string(document_id)),
				appearance_gen, noise, remaining))
	return c


## Documents exigés par les règles actives pour cette origine (R04 : `HAL` dispensé).
func required_documents_for(faction_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule: Rule in day.rule_set.rules:
		if rule is RequireDocumentRule:
			var require: RequireDocumentRule = rule
			if not require.exempt_faction_ids.has(faction_id) and not ids.has(require.document_id):
				ids.append(require.document_id)
	return ids


## Types tirables ce jour : poids > 0, détectables par le RuleSet, injecteur disponible.
func get_drawable_kinds() -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	for kind: AnomalyType.Kind in day.anomaly_weights:
		if day.anomaly_weights[kind] > 0.0 and day.rule_set.can_detect(kind) and _injectors.has(kind):
			kinds.append(kind)
	return kinds


func _inject_random(state: InjectionState, result: GeneratedCase) -> Array[Anomaly]:
	var anomalies: Array[Anomaly] = []
	var count: int = maxi(state.rng.weighted_index(day.anomaly_count_weights), 0)
	result.requested_anomalies = count
	var candidates: Array[AnomalyType.Kind] = get_drawable_kinds()
	for n: int in count:
		while not candidates.is_empty():
			var weights: PackedFloat32Array = []
			for candidate: AnomalyType.Kind in candidates:
				weights.append(day.anomaly_weights[candidate])
			var kind: AnomalyType.Kind = candidates[maxi(state.rng.weighted_index(weights), 0)]
			var anomaly: Anomaly = _inject(kind, state)
			if anomaly != null:
				anomalies.append(anomaly)
				break
			candidates.erase(kind)
	return anomalies


func _inject(kind: AnomalyType.Kind, state: InjectionState) -> Anomaly:
	var injector: AnomalyInjector = _injectors.get(kind, null)
	if injector == null:
		return null
	if injector.is_face_anomaly() and state.face_anomaly:
		return null
	return injector.inject(state)


## Invariants (ARCHITECTURE §6, §9.3) : chaque anomalie non cosmétique est
## prouvée par une violation d'une règle active qui la détecte (et qui cite le
## champ corrompu) ; le visage présenté est l'apparence réelle ; sans anomalie
## de visage, aucune photo ne diffère du porteur.
static func check_invariants(generated: GeneratedCase, p_ctx: RuleContext) -> PackedStringArray:
	var errors: PackedStringArray = []
	var c: Case = generated.case
	var key: CaseKey = generated.key
	for anomaly: Anomaly in key.anomalies:
		if anomaly.cosmetic:
			continue
		if not _is_proven(anomaly, key.expected_violations, p_ctx):
			errors.append("%s non détectée" % anomaly)
	if not c.passenger_presented.appearance.equals(key.truth.appearance):
		errors.append("apparence présentée ≠ apparence réelle")
	var face: bool = generated.has_face_anomaly()
	for ref: FieldRef in c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT):
		var portrait: PortraitValue = c.get_value(ref)
		var differing: Array[StringName] = FaceComparator.compare(portrait.appearance, key.truth.appearance, p_ctx.identity_slots)
		if not face and not differing.is_empty():
			errors.append("photo %s ≠ porteur sans anomalie de visage" % ref.key())
	if RuleEngine.expected_verdict(key.expected_violations) != key.expected_verdict:
		errors.append("verdict incohérent avec D-030")
	return errors


static func _is_proven(anomaly: Anomaly, violations: Array[Violation], p_ctx: RuleContext) -> bool:
	for violation: Violation in violations:
		var rule: Rule = p_ctx.find_active_rule(violation.rule_id)
		if rule == null or not rule.get_detectable_anomalies().has(anomaly.type):
			continue
		if anomaly.field_id == &"":
			if rule is RequireDocumentRule and (rule as RequireDocumentRule).document_id == anomaly.document_id:
				return true
			continue
		if violation.has_ref(FieldRef.new(anomaly.document_id, anomaly.field_id)):
			return true
	return false
