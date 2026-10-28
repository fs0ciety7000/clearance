## Construction d'un cas (ARCHITECTURE §9.2) — pur, déterministe.
##
## Une instance par jour : le roster d'apparences (§9.3) est calculé une fois
## depuis `day_seed`, puis `build(index)` produit le cas `index` à partir de
## `case_seed = mix(day_seed, index)` seul (indépendant des autres cas).
## Pipeline : cas scénarisé ? → passager vrai (`PassengerGenerator`) →
## documents valides (`DocumentFactory`) → contrôle `RuleEngine.validate() == []`
## (8 essais) → injection (`AnomalyInjector`) → visière → clé calculée par
## `RuleEngine.build_case_key()` sur le cas **final** (D-005) → invariants.
## M7 : continuité entre jours (`CaseMemory` : `appearance_from_case`,
## `identity_from_case`), avis de recherche du jour (`RuleContext.wanted`,
## calculé à la construction ; le contrôle « cas propre » l'ignore), implants
## civils (jours R15), motif exempté pour une origine interdite (R19), bande
## MRZ (recalculée après injection), codes Lucioles, objets glissés
## (scénarisés et enveloppes générées `bribe_rate`), `truth_overrides`.
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
# M7 : flux nouveaux (n'altèrent pas les tirages des jours 1–3).
const SALT_IMPLANTS: int = 5
const SALT_BRIBE: int = 6
const SALT_LUCIOLE: int = 7
const WANTED_DEDUPE_SALT: String = "wanted_dedupe"
const TAG_LUCIOLE: StringName = &"luciole"
const TAG_LUCIOLE_PASSWORD: StringName = &"luciole_password"
const TAG_LUMIKA: StringName = &"lumika"
const PRESENTATION_KNOCK: StringName = &"knock_three"
const PRESENTATION_MAGENTA: StringName = &"magenta_thread"
const MARK_LUCIOLE: StringName = &"luciole"
## Jour d'apparition de chaque code Luciole (GDD §4.7).
const LUCIOLE_CODE_DAYS: Dictionary[int, int] = {1: 3, 2: 5, 3: 5, 4: 7, 5: 4, 6: 6, 7: 3}
## Effets d'une enveloppe générée gardée (GDD §5.5).
const BRIBE_KEEP_EFFECTS: Dictionary = {&"keep": {&"suspicion": 1}}
const ENVELOPE_LABEL_KEY: String = "wb_envelope_label"

var data: DataCatalog = null
var day: DayDef = null
var day_seed: int = 0
## Drapeaux narratifs satisfaits (`ScriptedCaseDef.requires_flag`).
var flags: Array[StringName] = []
var ctx: RuleContext = null
var roster: AppearanceRoster = null
var appearance_gen: AppearanceGenerator = null
## Mémoire des passagers scénarisés (`CaseMemory`, `GameState.case_memory`).
var memory: Dictionary = {}
## Index des passagers générés recherchés (avis du jour).
var wanted_indices: Array[int] = []
var _injectors: Dictionary[AnomalyType.Kind, AnomalyInjector] = {}
## Contexte du contrôle « cas propre » (sans avis de recherche).
var _clean_ctx: RuleContext = null
var _flag_values: Dictionary[StringName, Variant] = {}


func _init(p_data: DataCatalog, p_day: DayDef, p_day_seed: int, p_flags: Array[StringName] = [],
		p_memory: Dictionary = {}) -> void:
	data = p_data
	day = p_day
	day_seed = p_day_seed
	flags = p_flags.duplicate()
	memory = p_memory
	_flag_values = FlagCondition.from_true_flags(flags)
	ctx = RuleContext.for_day(day, data.factions, data.documents)
	if data.appearance_catalog != null:
		ctx.identity_slots = data.appearance_catalog.get_identity_slots()
	_clean_ctx = ctx.duplicate_context()
	appearance_gen = AppearanceGenerator.new(data.appearance_catalog)
	_injectors = InjectorRegistry.create_all()
	roster = appearance_gen.build_day_roster(day_seed, day.passenger_count, get_active_scripted_cases(),
			day.faction_weights, day.game_date)
	_apply_continuity()
	_build_wanted_notices()


## Avis de recherche du jour (publiés par le DayController, lus par R22).
func get_wanted_notices() -> Array[WantedNotice]:
	return ctx.wanted

## Cas scénarisés du jour dont le drapeau requis est satisfait.
func get_active_scripted_cases() -> Array[ScriptedCaseDef]:
	var result: Array[ScriptedCaseDef] = []
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted == null or (scripted.requires_flag != &"" and not flags.has(scripted.requires_flag)):
			continue
		var forbidden: bool = false
		for flag: StringName in scripted.forbids_flags:
			forbidden = forbidden or flags.has(flag)
		if not forbidden:
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
	if wanted_indices.has(index):
		return _build(index, null, [AnomalyType.Kind.WANTED_PERSON], {}, true)
	return _build(index, null, [], {}, false)


## Cas `index` sans aucune anomalie (identité et visage seulement :
## avis de recherche, mémoire recalculée `CaseMemory.recall`).
func build_clean(index: int) -> GeneratedCase:
	var scripted: ScriptedCaseDef = get_scripted_case(index)
	return _build(index, scripted, [], scripted.injection_params if scripted != null else {}, true)


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
	var overrides: Dictionary = _overrides_for(scripted)
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

	var extra_documents: Array[StringName] = []
	if scripted != null:
		extra_documents = scripted.extra_documents
	# 1–4. Passager vrai, documents valides, contrôle.
	var truth: Passenger = null
	var c: Case = null
	for attempt: int in MAX_CLEAN_ATTEMPTS:
		var attempt_rng: SeededRng = rng.fork(attempt)
		var case_id: StringName = StringName("d%02d_c%02d" % [day.day_number, index])
		truth = PassengerGenerator.generate(attempt_rng.fork(SALT_PASSENGER), faction, day.game_date, entry,
				overrides, StringName("p_%s" % case_id))
		_post_generate(truth, faction, overrides, attempt_rng.fork(SALT_IMPLANTS), index)
		c = _make_clean_case(truth, attempt_rng.fork(SALT_DOCUMENTS), result.photo_noise, extra_documents)
		c.case_id = case_id
		c.index = index
		c.case_seed = case_seed
		result.clean_attempts = attempt + 1
		result.clean_violation_count = RuleEngine.validate(c, day.rule_set, _clean_ctx).size()
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

	_finalize_documents(state)
	if scripted != null and not scripted.truth_overrides.is_empty():
		var rejected: PackedStringArray = truth.apply_overrides(scripted.truth_overrides)
		if not rejected.is_empty():
			push_error("CaseBuilder: truth_overrides refusées %s (%s)" % [rejected, scripted.id])

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
	if scripted != null:
		for tag: StringName in scripted.extra_tags:
			if not c.dialogue_tags.has(tag):
				c.dialogue_tags.append(tag)
		_apply_luciole_codes(c, scripted.luciole_codes, params)
		if scripted.slipped_item != null:
			c.slipped_items.append(scripted.slipped_item.instantiate(c.case_id, 0, _flag_values))
	elif not exact:
		_draw_luciole(c, rng.fork(SALT_LUCIOLE))
		_draw_bribe(c, anomalies, rng.fork(SALT_BRIBE))

	# 7. Clé calculée sur le cas final, invariants.
	result.case = c
	result.key = RuleEngine.build_case_key(c, truth, anomalies, day.rule_set, ctx)
	result.invariant_errors = check_invariants(result, ctx)
	if not result.invariant_errors.is_empty():
		push_error("CaseBuilder: invariants violés (jour %d, cas %d, seed %d) : %s"
				% [day.day_number, index, case_seed, "; ".join(result.invariant_errors)])
	return result


func _make_clean_case(truth: Passenger, rng: SeededRng, photo_noise: bool, extra: Array[StringName] = []) -> Case:
	var c: Case = Case.new()
	c.passenger_presented = truth.copy()
	var document_ids: Array[StringName] = required_documents_for(truth.faction_id)
	for document_id: StringName in extra:
		if not document_ids.has(document_id):
			document_ids.append(document_id)
	for document_id: StringName in document_ids:
		var def: DocumentTypeDef = data.documents.get(document_id, null)
		if def == null:
			push_error("CaseBuilder: document inconnu « %s »" % document_id)
			continue
		var remaining: int = truth.stay_days if def.find_field_by_truth_path(&"stay_days") != null else 1
		var noise: bool = photo_noise and def.find_field_by_truth_path(&"appearance") != null
		var doc: DocumentInstance = DocumentFactory.create(def, truth, day.game_date, rng.fork(SeededRng.hash_string(document_id)),
				appearance_gen, noise, remaining)
		if def.find_field_by_truth_path(MrzConsistentRule.MRZ_PATH) != null:
			doc.mrz = Mrz.compose_for(doc, data.factions)
		c.documents.append(doc)
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
		if anomaly.document_id == FieldRef.PASSENGER_DOCUMENT_ID:
			if violation.has_ref(FieldRef.passenger_face()):
				return true
			continue
		if anomaly.field_id == &"":
			if rule is RequireDocumentRule and (rule as RequireDocumentRule).document_id == anomaly.document_id:
				return true
			continue
		if violation.has_ref(FieldRef.new(anomaly.document_id, anomaly.field_id)):
			return true
	return false



# ---------------------------------------------------------------------------
# M7 : continuité, avis de recherche, implants, bans, MRZ, Lucioles, objets
# ---------------------------------------------------------------------------

## Surcharges d'un cas scénarisé, complétées de l'identité mémorisée
## (`identity_from_case`, les surcharges explicites l'emportent).
func _overrides_for(scripted: ScriptedCaseDef) -> Dictionary:
	if scripted == null:
		return {}
	if scripted.identity_from_case == &"":
		return scripted.passenger_overrides
	var result: Dictionary = CaseMemory.identity_overrides(_memory_entry(scripted.identity_from_case))
	for key: Variant in scripted.passenger_overrides:
		result[key] = scripted.passenger_overrides[key]
	return result


func _memory_entry(scripted_id: StringName) -> Dictionary:
	var entry: Variant = memory.get(String(scripted_id), memory.get(scripted_id, {}))
	return entry if entry is Dictionary else {}


## Visages repris d'un jour antérieur (`appearance_from_case` / `identity_from_case`).
func _apply_continuity() -> void:
	for scripted: ScriptedCaseDef in get_active_scripted_cases():
		var source: StringName = scripted.appearance_from_case
		if source == &"":
			source = scripted.identity_from_case
		if source == &"":
			continue
		var entry: Dictionary = _memory_entry(source)
		var remembered: PassengerAppearance = CaseMemory.appearance_of(entry)
		var roster_entry: AppearanceRoster.Entry = roster.get_entry(scripted.at_index)
		if remembered == null or roster_entry == null:
			continue
		var app: PassengerAppearance = remembered.derive(scripted.appearance_overrides)
		app.palette_id = app.get_trait(PassengerAppearance.SLOT_PALETTE)
		var birth: Variant = _overrides_for(scripted).get(&"birth_date", null)
		if birth is int:
			var birth_date: int = birth
			app.age_band = PassengerGenerator.age_band_for_age(GameDate.age_on(birth_date, day.game_date))
		roster_entry.appearance = app
		var faction: Variant = _overrides_for(scripted).get(&"faction_id", null)
		if faction != null:
			roster_entry.faction_id = StringName(str(faction))


## Avis de recherche : identité et portrait des passagers visés, calculés
## depuis leur cas propre ; aucun autre visage du jour ne leur ressemble.
func _build_wanted_notices() -> void:
	var notice_indices: Array[int] = []
	for def: WantedNoticeDef in day.wanted_notices:
		if def == null:
			continue
		var index: int = def.at_index
		var scripted: ScriptedCaseDef = null
		if def.scripted_case_id != &"":
			index = -1
			for candidate: ScriptedCaseDef in get_active_scripted_cases():
				if candidate.id == def.scripted_case_id:
					scripted = candidate
					index = candidate.at_index
		if index < 0 or index >= day.passenger_count:
			continue
		var generated: GeneratedCase = build_clean(index)
		if generated == null:
			continue
		var presented: Passenger = generated.case.passenger_presented
		var notice: WantedNotice = WantedNotice.new()
		notice.id = def.id
		notice.given_name = def.given_name if not def.given_name.is_empty() else presented.given_name
		notice.family_name = def.family_name if not def.family_name.is_empty() else presented.family_name
		notice.appearance = DocumentFactory.official_photo_of(presented.appearance.without_visor())
		notice.reason_key = def.reason_key
		notice.case_index = index
		ctx.wanted.append(notice)
		notice_indices.append(index)
		if scripted == null:
			wanted_indices.append(index)
	if ctx.wanted.is_empty():
		return
	for i: int in roster.size():
		if notice_indices.has(i):
			continue
		var entry: AppearanceRoster.Entry = roster.get_entry(i)
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, i), WANTED_DEDUPE_SALT))
		for notice: WantedNotice in ctx.wanted:
			var guard: int = 0
			while guard < 8 and FaceComparator.compare(notice.appearance, entry.appearance, ctx.identity_slots).is_empty():
				guard += 1
				var slot: StringName = ctx.identity_slots[rng.randi_range(0, ctx.identity_slots.size() - 1)]
				entry.appearance.traits[slot] = appearance_gen.reroll_slot(rng, entry.appearance, slot, entry.faction_id)


## Après le tirage du passager : implant civil éventuel (jours où R15 est
## active), motif exempté pour une origine interdite (R19) — cas propre.
func _post_generate(truth: Passenger, faction: FactionDef, overrides: Dictionary, rng: SeededRng, index: int) -> void:
	# Homonyme fortuit d'une personne recherchée : autre prénom.
	if not overrides.has(&"given_name") and faction.name_pool != null:
		for notice: WantedNotice in ctx.wanted:
			var guard: int = 0
			while notice.case_index != index and guard < 8 and FieldValue.equals(truth.given_name, notice.given_name) \
					and FieldValue.equals(truth.family_name, notice.family_name):
				guard += 1
				truth.given_name = faction.name_pool.pick_given_name(rng, truth.sex)
				truth.given_name = faction.name_pool.avoid_reserved_full_name(truth.given_name, truth.family_name,
						truth.sex)
	if not overrides.has(&"implants") and _has_rule(ImplantsDeclaredRule) and faction.implant_rate > 0.0 \
			and not faction.implant_weights.is_empty() and rng.chance(faction.implant_rate):
		var codes: Array = faction.implant_weights.keys()
		var weights: PackedFloat32Array = []
		for code: Variant in codes:
			weights.append(faction.implant_weights[code])
		truth.implants = PackedStringArray([str(rng.weighted_pick(codes, weights))])
	if overrides.has(&"purpose"):
		return
	for rule: Rule in day.rule_set.rules:
		var banned: FactionBannedRule = rule as FactionBannedRule
		if banned != null and banned.is_banned_origin(truth.faction_id) and not banned.exempt_purposes.is_empty() \
				and not banned.exempt_purposes.has(truth.purpose):
			truth.purpose = banned.exempt_purposes[0]


func _has_rule(script: Script) -> bool:
	for rule: Rule in day.rule_set.rules:
		if is_instance_of(rule, script):
			return true
	return false


## Bande MRZ recalculée sur les valeurs finales de la carte (après les
## injecteurs qui changent l'identité), sauf si une anomalie MRZ l'a altérée.
func _finalize_documents(state: InjectionState) -> void:
	for doc: DocumentInstance in state.case.documents:
		var field: FieldDef = doc.type_def.find_field_by_truth_path(MrzConsistentRule.MRZ_PATH)
		if field != null and state.is_free(doc.get_document_id(), field.id):
			doc.mrz = Mrz.compose_for(doc, data.factions)


## Codes Lucioles (LORE §7) : jamais des discordances.
func _apply_luciole_codes(c: Case, codes: PackedInt32Array, params: Dictionary) -> void:
	if codes.is_empty():
		return
	c.luciole_codes = codes.duplicate()
	if not c.dialogue_tags.has(TAG_LUCIOLE):
		c.dialogue_tags.append(TAG_LUCIOLE)
	for code: int in codes:
		match code:
			1:
				var target: DocumentInstance = c.get_document(StringName(str(params.get(&"mark_document_id", "entry_permit"))))
				if target == null and not c.documents.is_empty():
					target = c.documents[c.documents.size() - 1]
				if target != null and not target.marks.has(MARK_LUCIOLE):
					target.marks.append(MARK_LUCIOLE)
			2:
				for doc: DocumentInstance in c.documents:
					if not doc.mrz.is_empty():
						doc.mrz = doc.mrz.left(doc.mrz.length() - 2) + str(params.get(&"mrz_issuer", Mrz.LUCIOLE_ISSUER))
			3:
				var permit: DocumentInstance = c.get_document(&"entry_permit")
				if permit != null and not permit.serial.is_empty():
					permit.serial = permit.serial.left(permit.serial.length() - 1) + str(params.get(&"permit_suffix", 7))
			4:
				if not c.dialogue_tags.has(TAG_LUCIOLE_PASSWORD):
					c.dialogue_tags.append(TAG_LUCIOLE_PASSWORD)
			5:
				c.presentation = PRESENTATION_KNOCK
			6:
				if not c.dialogue_tags.has(PRESENTATION_MAGENTA):
					c.dialogue_tags.append(PRESENTATION_MAGENTA)
			7:
				if not c.dialogue_tags.has(TAG_LUMIKA):
					c.dialogue_tags.append(TAG_LUMIKA)


## Passager généré porteur d'un code Luciole (`DayDef.luciole_rate`).
func _draw_luciole(c: Case, rng: SeededRng) -> void:
	if day.luciole_rate <= 0.0 or not rng.chance(day.luciole_rate):
		return
	var codes: Array[int] = []
	for code: int in LUCIOLE_CODE_DAYS:
		if day.day_number < LUCIOLE_CODE_DAYS[code]:
			continue
		if code == 3 and c.passenger_presented.purpose != Passenger.PURPOSE_FAMILY_VISIT:
			continue
		if code == 2 and c.get_document(&"id_card") == null:
			continue
		codes.append(code)
	codes.sort()
	if codes.is_empty():
		return
	_apply_luciole_codes(c, PackedInt32Array([codes[rng.randi_range(0, codes.size() - 1)]]), {})


## Enveloppe glissée par un passager en infraction (`DayDef.bribe_rate`, GDD §5.5).
func _draw_bribe(c: Case, anomalies: Array[Anomaly], rng: SeededRng) -> void:
	if anomalies.is_empty() or day.bribe_rate <= 0.0 or not rng.chance(day.bribe_rate):
		return
	var item: SlippedItem = SlippedItem.new()
	item.id = StringName("%s_item0" % c.case_id)
	item.case_id = c.case_id
	item.kind = SlippedItem.Kind.ENVELOPE
	var lo: int = maxi(floori(day.bribe_amounts.x / 10.0), 1)
	var hi: int = maxi(floori(day.bribe_amounts.y / 10.0), lo)
	item.amount = 10 * rng.randi_range(lo, hi)
	item.label_key = ENVELOPE_LABEL_KEY
	item.allowed = [SlippedItem.Decision.KEEP, SlippedItem.Decision.RETURN]
	item.default_decision = SlippedItem.Decision.RETURN
	for key: Variant in BRIBE_KEEP_EFFECTS:
		var table: Dictionary = BRIBE_KEEP_EFFECTS[key]
		item.effects[StringName(str(key))] = table.duplicate(true)
	c.slipped_items.append(item)
