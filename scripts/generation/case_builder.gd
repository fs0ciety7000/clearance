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
## Acte II (docs/ACT2.md B20, B25, B28) : documents conditionnels (contrat de
## travail pour le motif TRAVAIL, laissez-passer des `DRV`, attestation des `TER`
## C-5), code employeur / poste / vaisseau / firmware NX, gravitaires du J18 sur
## un poste en pénurie (R31), liste des révocations liée aux index (R30, comme
## D-056), avis conditionnels ou « visages seuls », ticket de file à l'heure de
## présentation (`presentation_minute`, R29), cas scénarisés conditionnels
## (plusieurs au même index), visages fixés, répliques conditionnelles,
## documents d'un tiers, valeur injectée reprise d'un autre cas.
## Acte III (docs/ACT3.md B37–B44) : documents retirés présentés quand même
## (SC-58), bruit de prorogation (R32), réintégrations de l'onglet Révocations
## (R33), **plan des répondants** du jour (R34 : un ressortissant au motif
## VISITE FAMILIALE reçoit un répondant HAL C-1–C-3 propre placé plus tôt ;
## liens imposés `DayDef.sponsor_links`, cas scénarisés `sponsor_case_id`),
## convocations de l'Enquête (R36 : liste du jour, convoqués générés, leurres),
## lock-out (R35 : aucun `TYC` + `CT-KA` valide généré), emplacements du
## réseau (`slot_group`), Main courante tenue au fil du shift
## (`record_verdict`), poids modulés par drapeaux.
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
# Acte II : flux nouveaux (n'altèrent pas les tirages des jours 1–10).
const SALT_FIRMWARE: int = 8
const SALT_CONTRACT: int = 9
const SALT_THIRD_PARTY: int = 10
const SALT_TICKET: int = 11
# Acte III : flux nouveaux (n'altèrent pas les tirages des jours 1–20).
const SALT_PROROGATION: int = 12
const SALT_PLAN: int = 13
const SALT_RETIRED: int = 14
const SUMMONS_SALT: String = "summons"
const SUMMONS_DECOY_SALT: String = "summons_decoys"
const REINSTATED_SALT: String = "reinstated"
const WARD_SALT: String = "ward_plan"
const SUMMONS_PREFIX: String = "ENQ-"
## N° des convocations générées et des leurres (les scénarisées sont < 1000).
const SUMMONS_RANGE: Vector2i = Vector2i(1000, 8999)
const EXPIRY_DOC_PATH: StringName = &"document.expiry_date"
const REVOKED_SALT: String = "revoked_decoys"
## Acte II : documents des nouvelles règles.
const TICKET_DOCUMENT_ID: StringName = &"queue_ticket"
const NX_PREFIX: String = "NX-"
## Firmware d'un shunt `NX-` généré propre : 0–80 jours (R27 : < 90).
const FIRMWARE_MAX_AGE: int = 80
const ASYLUM_CLASS: StringName = &"C-5"
const ASYLUM_FROM_CLASS: StringName = &"C-4"
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
## Acte II : index des passagers générés révoqués (onglet Révocations).
var revoked_indices: Array[int] = []
## Acte II (R29) : heure de présentation (minutes depuis minuit) du prochain
## cas construit, imprimée sur le ticket de file ; −1 = pas de ticket (outils,
## tests). Posée par le `DayController` (horloge) ou le `DaySimulator`.
var presentation_minute: int = -1
## Acte III — plan des répondants (R34) : index du protégé → index du répondant.
var wards: Dictionary[int, int] = {}
## Acte III — protégés à lien imposé (`DayDef.sponsor_links`) : cas propres.
var linked_wards: Array[int] = []
## Acte III — répondants générés (HAL, classe C-1–C-3, cas propres).
var sponsor_indices: Array[int] = []
## Acte III — passagers générés convoqués (R36) : index → N° `ENQ-`.
var summoned_numbers: Dictionary[int, String] = {}
## Acte III — ressortissants générés sans répondant : jamais en VISITE FAMILIALE.
var _no_family: Array[int] = []
var _clean_ids: Dictionary[int, String] = {}
var _active: Array[ScriptedCaseDef] = []
var _active_ready: bool = false


## `p_flag_values` (Acte II) : valeurs des drapeaux et jauges (conditions des
## cas scénarisés, avis, révocations, répliques) ; à défaut, les drapeaux vrais.
func _init(p_data: DataCatalog, p_day: DayDef, p_day_seed: int, p_flags: Array[StringName] = [],
		p_memory: Dictionary = {}, p_flag_values: Dictionary[StringName, Variant] = {}) -> void:
	data = p_data
	day = p_day
	day_seed = p_day_seed
	flags = p_flags.duplicate()
	memory = p_memory
	_flag_values = FlagCondition.from_true_flags(flags)
	for flag: StringName in p_flag_values:
		_flag_values[flag] = p_flag_values[flag]
	ctx = RuleContext.for_day(day, data.factions, data.documents)
	if data.appearance_catalog != null:
		ctx.identity_slots = data.appearance_catalog.get_identity_slots()
	_clean_ctx = ctx.duplicate_context()
	# Acte III : Répondant et Convocation tenus pour valides au contrôle « cas
	# propre » (vérifiés à la présentation, avec la Main courante et l'onglet).
	_clean_ctx.trust_documents = true
	appearance_gen = AppearanceGenerator.new(data.appearance_catalog)
	_injectors = InjectorRegistry.create_all()
	_active = _compute_active_scripted_cases()
	_active_ready = true
	roster = appearance_gen.build_day_roster(day_seed, day.passenger_count, get_active_scripted_cases(),
			day.faction_weights, day.game_date)
	_apply_continuity()
	_plan_act3()
	_build_wanted_notices()
	_build_revocations()
	_build_summons()


## Avis de recherche du jour (publiés par le DayController, lus par R22).
func get_wanted_notices() -> Array[WantedNotice]:
	return ctx.wanted


## Acte II : liste des révocations du jour (publiée par le DayController, R30).
func get_revocations() -> Array[RevokedEntry]:
	return ctx.revoked


## Valeurs des drapeaux narratifs vues par ce jour (conditions).
func get_flag_values() -> Dictionary[StringName, Variant]:
	return _flag_values


## Cas scénarisés du jour dont le drapeau requis est satisfait (Acte II : et
## la condition) ; au plus un par index (le premier de l'ordre des données).
## Acte III : un cas d'emplacement (`slot_group`) est une **copie** placée au
## prochain index libre de son groupe ; un protégé scénarisé
## (`sponsor_case_id`) n'est actif que si son répondant l'est. Calculé une
## fois à la construction (les drapeaux du matin ne changent pas).
func get_active_scripted_cases() -> Array[ScriptedCaseDef]:
	if _active_ready:
		return _active.duplicate()
	return _compute_active_scripted_cases()


func _compute_active_scripted_cases() -> Array[ScriptedCaseDef]:
	var result: Array[ScriptedCaseDef] = []
	var taken: Array[int] = []
	var slots_used: Dictionary[StringName, int] = {}
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted == null or (scripted.requires_flag != &"" and not flags.has(scripted.requires_flag)):
			continue
		if not FlagCondition.check(scripted.condition, _flag_values):
			continue
		var forbidden: bool = false
		for flag: StringName in scripted.forbids_flags:
			forbidden = forbidden or flags.has(flag)
		if forbidden:
			continue
		if scripted.slot_group != &"":
			var slots: PackedInt32Array = day.slot_groups.get(scripted.slot_group, PackedInt32Array())
			var k: int = slots_used.get(scripted.slot_group, 0)
			while k < slots.size() and taken.has(slots[k]):
				k += 1
			if k >= slots.size():
				continue
			slots_used[scripted.slot_group] = k + 1
			var placed: ScriptedCaseDef = scripted.duplicate() as ScriptedCaseDef
			placed.at_index = slots[k]
			result.append(placed)
			taken.append(placed.at_index)
			continue
		if taken.has(scripted.at_index):
			continue
		result.append(scripted)
		taken.append(scripted.at_index)
	# Acte III : protégé scénarisé sans son répondant → passager généré.
	var kept: Array[ScriptedCaseDef] = []
	for scripted: ScriptedCaseDef in result:
		if scripted.sponsor_case_id != &"" and _find_in(result, scripted.sponsor_case_id) == null:
			continue
		kept.append(scripted)
	return kept


static func _find_in(list: Array[ScriptedCaseDef], scripted_id: StringName) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in list:
		if scripted.id == scripted_id:
			return scripted
	return null


func get_scripted_case(index: int) -> ScriptedCaseDef:
	for scripted: ScriptedCaseDef in get_active_scripted_cases():
		if scripted.at_index == index:
			return scripted
	return null


## Tous les cas du jour, dans l'ordre. Acte III : joués par un agent parfait
## (`record_verdict` du verdict attendu : la Main courante se remplit).
func build_day() -> Array[GeneratedCase]:
	var result: Array[GeneratedCase] = []
	for i: int in day.passenger_count:
		var generated: GeneratedCase = build(i)
		if generated != null and generated.case != null:
			record_verdict(generated.case, generated.key.expected_verdict)
		result.append(generated)
	return result


## Cas `index` du jour (scénarisé s'il y a lieu, sinon tirage selon le `DayDef`).
func build(index: int) -> GeneratedCase:
	var scripted: ScriptedCaseDef = get_scripted_case(index)
	if scripted != null:
		return _build(index, scripted, scripted.forced_anomalies, scripted.injection_params, true)
	if wanted_indices.has(index):
		return _build(index, null, [AnomalyType.Kind.WANTED_PERSON], {}, true)
	if revoked_indices.has(index):
		return _build(index, null, [AnomalyType.Kind.REVOKED_ID], {}, true)
	# Acte III : répondants générés et protégés à lien imposé, propres.
	if sponsor_indices.has(index) or linked_wards.has(index):
		return _build(index, null, [], {}, true)
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
	if not forced.is_empty():
		params = _resolve_params(params)
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
		_post_generate(truth, faction, overrides, attempt_rng.fork(SALT_IMPLANTS), index, scripted != null)
		c = _make_clean_case(truth, attempt_rng.fork(SALT_DOCUMENTS), result.photo_noise, extra_documents)
		c.case_id = case_id
		_add_third_party_documents(c, truth, scripted, attempt_rng.fork(SALT_THIRD_PARTY))
		c.index = index
		c.case_seed = case_seed
		result.clean_attempts = attempt + 1
		_apply_document_dates(c, scripted)
		# Cas scénarisé : ses anomalies imposées expliquent aussi le contrôle de
		# `build_clean` (avis de recherche de Mira, SC-82b, fermée par R37).
		result.clean_violation_count = _clean_violations(c, scripted, scripted.forced_anomalies if scripted != null else forced)
		if result.clean_violation_count == 0:
			break
		if attempt == MAX_CLEAN_ATTEMPTS - 1:
			push_error("CaseBuilder: aucun cas propre après %d essais (jour %d, cas %d, seed %d) : %s"
					% [MAX_CLEAN_ATTEMPTS, day.day_number, index, case_seed,
					_clean_violation_ids(c, scripted, scripted.forced_anomalies if scripted != null else forced)])

	# Acte II (R29) : ticket de file à l'heure de présentation (hors contrôle « cas propre »).
	_add_queue_ticket(c, truth, rng.fork(SALT_TICKET))
	# Acte III : documents retirés présentés quand même (SC-58), bruit de prorogation (R32).
	_add_retired_documents(c, truth, scripted, rng.fork(SALT_RETIRED))
	if scripted == null and not exact:
		result.prorogation_noise = _apply_prorogation_noise(c, rng.fork(SALT_PROROGATION))

	# 5. Injection.
	var state: InjectionState = InjectionState.new()
	state.case = c
	state.truth = truth
	state.rng = rng.fork(SALT_INJECTION)
	state.ctx = ctx
	state.data = data
	state.appearance_gen = appearance_gen
	state.params = params
	state.peek_citizen_id = peek_citizen_id
	state.passenger_count = day.passenger_count
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
		for variant: ConditionalKey in scripted.line_variants:
			if variant != null and variant.replaces != "" and not c.line_overrides.has(variant.replaces) \
					and FlagCondition.check(variant.condition, _flag_values):
				c.line_overrides[variant.replaces] = variant.key
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
	var document_ids: Array[StringName] = required_documents_for_passenger(truth)
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


## Documents exigés par les règles actives pour cette origine (R04 : `HAL`
## dispensé) — règles inconditionnelles seulement (voir
## `required_documents_for_passenger` pour l'Acte II).
func required_documents_for(faction_id: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for rule: Rule in day.rule_set.rules:
		if rule is RequireDocumentRule:
			var require: RequireDocumentRule = rule
			if require.is_conditional() or require.exempt_faction_ids.has(faction_id) or ids.has(require.document_id):
				continue
			if not require.applies_to_faction_ids.is_empty() and not require.applies_to_faction_ids.has(faction_id):
				continue
			ids.append(require.document_id)
	return ids


## Documents exigés pour un passager vrai (Acte II) : règles inconditionnelles,
## puis règles conditionnées au motif du permis (R24) ou à la classe (R28).
func required_documents_for_passenger(p: Passenger) -> Array[StringName]:
	var ids: Array[StringName] = required_documents_for(p.faction_id)
	var has_permit: bool = ids.has(&"entry_permit")
	for rule: Rule in day.rule_set.rules:
		if rule is RequireDocumentRule:
			var require: RequireDocumentRule = rule
			if require.is_conditional() and not ids.has(require.document_id) and require.requires_for(p, has_permit):
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
				weights.append(weight_of(candidate))
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
## (`identity_from_case`, les surcharges explicites l'emportent). Acte III :
## Répondant d'un protégé scénarisé (`sponsor_case_id`, `with_sponsor`).
func _overrides_for(scripted: ScriptedCaseDef, with_sponsor: bool = true) -> Dictionary:
	if scripted == null:
		return {}
	var sponsored: bool = with_sponsor and scripted.sponsor_case_id != &""
	if scripted.identity_from_case == &"" and not sponsored:
		return scripted.passenger_overrides
	var result: Dictionary = {}
	if scripted.identity_from_case != &"":
		result = CaseMemory.identity_overrides(_memory_entry(scripted.identity_from_case))
	for key: Variant in scripted.passenger_overrides:
		result[key] = scripted.passenger_overrides[key]
	if sponsored:
		var sponsor: ScriptedCaseDef = _find_in(get_active_scripted_cases(), scripted.sponsor_case_id)
		if sponsor != null:
			result[&"sponsor_id"] = peek_citizen_id(sponsor.at_index)
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
		var remembered: PassengerAppearance = null
		if scripted.fixed_appearance_seed != 0:
			# Acte II : visage fixé une fois pour toutes (Okonkwo, Ilan).
			var fixed_faction: StringName = StringName(str(_overrides_for(scripted, false).get(&"faction_id", &"tyc")))
			remembered = appearance_gen.generate(SeededRng.new(scripted.fixed_appearance_seed), fixed_faction)
			remembered.traits[PassengerAppearance.SLOT_HEADWEAR] = PassengerAppearance.OPTION_NONE
		elif source == &"":
			continue
		else:
			remembered = CaseMemory.appearance_of(_memory_entry(source))
		var roster_entry: AppearanceRoster.Entry = roster.get_entry(scripted.at_index)
		if remembered == null or roster_entry == null:
			continue
		var app: PassengerAppearance = remembered.derive(scripted.appearance_overrides)
		app.palette_id = app.get_trait(PassengerAppearance.SLOT_PALETTE)
		var birth: Variant = _overrides_for(scripted, false).get(&"birth_date", null)
		if birth is int:
			var birth_date: int = birth
			app.age_band = PassengerGenerator.age_band_for_age(GameDate.age_on(birth_date, day.game_date))
		roster_entry.appearance = app
		var faction: Variant = _overrides_for(scripted, false).get(&"faction_id", null)
		if faction != null:
			roster_entry.faction_id = StringName(str(faction))


## Avis de recherche : identité et portrait des passagers visés, calculés
## depuis leur cas propre ; aucun autre visage du jour ne leur ressemble.
func _build_wanted_notices() -> void:
	var notice_indices: Array[int] = []
	for def: WantedNoticeDef in day.wanted_notices:
		if def == null or not FlagCondition.check(def.condition, _flag_values):
			continue
		if def.memory_case_id != &"":
			_add_memory_notice(def)
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
		if def.faces_only:
			notice.given_name = ""
			notice.family_name = ""
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
## Acte III : plan du jour (convocation, répondant, motif), lock-out (R35).
func _post_generate(truth: Passenger, faction: FactionDef, overrides: Dictionary, rng: SeededRng, index: int,
		scripted_case: bool = false) -> void:
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
	_post_generate_act2(truth, overrides, index)
	if not scripted_case:
		_post_generate_act3(truth, faction, index)
	if overrides.has(&"purpose"):
		return
	for rule: Rule in day.rule_set.rules:
		var banned: FactionBannedRule = rule as FactionBannedRule
		# Acte III : protégé·e d'un répondant (R31, R37) ou convoqué·e (R36) : exempté·e.
		if banned != null and ((banned.exempt_if_sponsored and not truth.sponsor_id.is_empty())
				or (banned.summons_exempt and not truth.summons_id.is_empty())):
			continue
		if banned != null and banned.is_banned_origin(truth.faction_id) and not banned.exempt_purposes.is_empty() \
				and not banned.exempt_purposes.has(truth.purpose):
			truth.purpose = banned.exempt_purposes[0]
		elif banned != null and banned.is_banned_origin(truth.faction_id) and not banned.exempt_posts.is_empty():
			# R31 (J18) : un gravitaire en règle travaille sur un poste en pénurie.
			truth.purpose = Passenger.PURPOSE_WORK
			if not overrides.has(&"post") and not banned.exempt_posts.has(truth.post):
				var post_rng: SeededRng = SeededRng.new(SeededRng.mix(SeededRng.case_seed(day_seed, index), SALT_CONTRACT + 100))
				truth.post = banned.exempt_posts[post_rng.randi_range(0, banned.exempt_posts.size() - 1)]
			_assign_employer_code(truth)


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
	var rate: float = day.luciole_rate
	# Acte III : part de Lucioles relevée par un drapeau (climat Vanne).
	for flag: StringName in day.luciole_rate_bonus:
		if FlagCondition.is_flag_true(_flag_values, flag):
			rate += day.luciole_rate_bonus[flag]
	if rate <= 0.0 or not rng.chance(rate):
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


# ---------------------------------------------------------------------------
# Acte II (docs/ACT2.md B20, B25, B28)
# ---------------------------------------------------------------------------

## Champs de l'Acte II du passager vrai : vaisseau (`DRV`), firmware d'un shunt
## `NX-`, code employeur et poste (contrat), classe C-5 tolérée (asile). Flux
## aléatoires propres (`SALT_FIRMWARE`, `SALT_CONTRACT`) : les tirages des
## jours 1–10 sont inchangés.
func _post_generate_act2(truth: Passenger, overrides: Dictionary, index: int) -> void:
	var case_seed: int = SeededRng.case_seed(day_seed, index)
	if truth.faction_id == &"drv" and not overrides.has(&"vessel"):
		truth.vessel = truth.family_name.to_upper()
	if not overrides.has(&"firmware_date") and truth.firmware_date == 0:
		for code: String in truth.implants:
			if code.begins_with(NX_PREFIX):
				var firmware_rng: SeededRng = SeededRng.new(SeededRng.mix(case_seed, SALT_FIRMWARE))
				truth.firmware_date = day.game_date - firmware_rng.randi_range(0, FIRMWARE_MAX_AGE)
				break
	var contract_rule: ContractConsistentRule = _contract_rule()
	if contract_rule != null:
		var contract_rng: SeededRng = SeededRng.new(SeededRng.mix(case_seed, SALT_CONTRACT))
		if not overrides.has(&"post") and truth.post == &"" and not contract_rule.posts.is_empty():
			truth.post = StringName(contract_rule.posts[contract_rng.randi_range(0, contract_rule.posts.size() - 1)])
		if not overrides.has(&"employer_code"):
			_assign_employer_code(truth)
	if not overrides.has(&"citizen_class") and truth.citizen_class == ASYLUM_FROM_CLASS and _asylum_class_required(truth):
		var class_rng: SeededRng = SeededRng.new(SeededRng.mix(case_seed, SALT_CONTRACT + 1))
		# Part des C-4 tolérés en C-5 (R28, J15+) : `DayDef.asylum_class_rate`.
		if class_rng.chance(day.asylum_class_rate):
			truth.citizen_class = ASYLUM_CLASS


func _contract_rule() -> ContractConsistentRule:
	for rule: Rule in day.rule_set.rules:
		if rule is ContractConsistentRule:
			return rule as ContractConsistentRule
	return null


func _assign_employer_code(truth: Passenger) -> void:
	var contract_rule: ContractConsistentRule = _contract_rule()
	if contract_rule != null:
		truth.employer_code = contract_rule.code_for(truth.employer)


## Une règle active exige un document pour la classe C-5 de cette origine (R28).
func _asylum_class_required(truth: Passenger) -> bool:
	for rule: Rule in day.rule_set.rules:
		if rule is RequireDocumentRule:
			var require: RequireDocumentRule = rule
			if require.applies_to_classes.has(ASYLUM_CLASS) and (require.applies_to_faction_ids.is_empty() \
					or require.applies_to_faction_ids.has(truth.faction_id)):
				return true
	return false


## `injected_value_from_case` : valeur du champ `field_path` du cas propre d'un
## autre cas scénarisé du jour (SC-31/32 : permis échangés).
func _resolve_params(params: Dictionary) -> Dictionary:
	if not params.has(&"injected_value_from_case"):
		return params
	var resolved: Dictionary = params.duplicate()
	var source: StringName = StringName(str(params[&"injected_value_from_case"]))
	var path: StringName = StringName(str(params.get(&"field_path", "citizen_id")))
	for scripted: ScriptedCaseDef in get_active_scripted_cases():
		if scripted.id == source:
			var other: GeneratedCase = build_clean(scripted.at_index)
			if other != null and Passenger.has_truth_path(path):
				resolved[&"injected_value"] = other.case.passenger_presented.get_truth(path)
	resolved.erase(&"injected_value_from_case")
	return resolved


## Documents d'un tiers (SC-27) : valeurs imposées, `third_party`.
func _add_third_party_documents(c: Case, truth: Passenger, scripted: ScriptedCaseDef, rng: SeededRng) -> void:
	if scripted == null or scripted.third_party_documents.is_empty():
		return
	for key: Variant in scripted.third_party_documents:
		var document_id: StringName = StringName(str(key))
		var def: DocumentTypeDef = data.documents.get(document_id, null)
		var spec: Variant = scripted.third_party_documents[key]
		if def == null or not spec is Dictionary:
			push_error("CaseBuilder: document de tiers « %s » invalide (%s)" % [document_id, scripted.id])
			continue
		var values: Dictionary = spec
		var holder: Passenger = truth.copy()
		var overrides: Dictionary = values.duplicate()
		overrides.erase(&"serial")
		holder.apply_overrides(overrides)
		var doc: DocumentInstance = DocumentFactory.create(def, holder, day.game_date, rng.fork(SeededRng.hash_string(document_id)),
				appearance_gen, false, 30)
		if values.has(&"serial"):
			doc.serial = str(values[&"serial"])
		doc.third_party = true
		c.documents.append(doc)


## Ticket de file (R29, J16+) : ajouté si une `CurfewRule` est active et que
## l'heure de présentation est connue (`presentation_minute` ≥ 0).
func _add_queue_ticket(c: Case, truth: Passenger, rng: SeededRng) -> void:
	if presentation_minute < 0 or not _has_rule(CurfewRule):
		return
	var def: DocumentTypeDef = data.documents.get(TICKET_DOCUMENT_ID, null)
	if def == null:
		return
	var ticket: DocumentInstance = DocumentFactory.create(def, truth, day.game_date, rng, appearance_gen, false, 1)
	ticket.presented_at = presentation_minute
	c.documents.append(ticket)


## Avis d'une personne absente de la file (visage tiré de la mémoire d'un cas
## antérieur) : aucun passager ne correspond, les visages du jour en diffèrent.
func _add_memory_notice(def: WantedNoticeDef) -> void:
	var entry: Dictionary = _memory_entry(def.memory_case_id)
	var remembered: PassengerAppearance = CaseMemory.appearance_of(entry)
	if remembered == null:
		return
	var notice: WantedNotice = WantedNotice.new()
	notice.id = def.id
	notice.given_name = "" if def.faces_only else (def.given_name if not def.given_name.is_empty() else str(entry.get("given_name", "")))
	notice.family_name = "" if def.faces_only else (def.family_name if not def.family_name.is_empty() else str(entry.get("family_name", "")))
	notice.appearance = DocumentFactory.official_photo_of(remembered.without_visor())
	notice.reason_key = def.reason_key
	notice.case_index = -1
	ctx.wanted.append(notice)


## Liste des révocations (R30) : N° ID présentés par les passagers visés
## (cas propres), puis leurres tirés du `day_seed`. Aucune autre carte du jour
## ne porte ces numéros (tirages indépendants, 32⁴ × 10³ combinaisons).
func _build_revocations() -> void:
	for def: RevocationDef in day.revocations:
		if def == null or not FlagCondition.check(def.condition, _flag_values):
			continue
		var index: int = def.at_index
		var scripted: ScriptedCaseDef = null
		if def.scripted_case_id != &"":
			index = -1
			for candidate: ScriptedCaseDef in get_active_scripted_cases():
				if candidate.id == def.scripted_case_id:
					scripted = candidate
					index = candidate.at_index
		if index < 0 or index >= day.passenger_count or wanted_indices.has(index):
			continue
		var generated: GeneratedCase = build_clean(index)
		if generated == null:
			continue
		var presented: Passenger = generated.case.passenger_presented
		var entry: RevokedEntry = RevokedEntry.new()
		entry.id = def.id
		entry.citizen_id = presented.citizen_id
		entry.given_name = presented.given_name
		entry.family_name = presented.family_name
		entry.reason_key = def.reason_key
		entry.case_index = index
		# Acte III (R33) : réintégration datée ; un passager généré réintégré
		# est un bruit légitime (aucune anomalie).
		entry.reinstated_on = def.reinstated_on
		entry.excluded_reason_key = def.excluded_reason_key
		ctx.revoked.append(entry)
		if scripted == null and def.reinstated_on <= 0:
			revoked_indices.append(index)
	if day.revoked_decoys <= 0:
		return
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, REVOKED_SALT))
	var faction_ids: Array[StringName] = []
	faction_ids.assign(data.factions.keys())
	faction_ids.sort()
	for n: int in day.revoked_decoys:
		var faction: FactionDef = data.factions[faction_ids[rng.randi_range(0, faction_ids.size() - 1)]]
		var entry: RevokedEntry = RevokedEntry.new()
		entry.id = StringName("revoked_decoy_%d" % n)
		entry.citizen_id = PassengerGenerator.make_citizen_id(rng, faction)
		if faction.name_pool != null:
			var sex: StringName = PassengerGenerator.SEXES[rng.randi_range(0, 1)]
			entry.given_name = faction.name_pool.pick_given_name(rng, sex)
			entry.family_name = faction.name_pool.pick_family_name(rng)
		# Acte III (R33) : leurres réintégrés (flux propre, liste inchangée).
		if day.reinstated_decoy_rate > 0.0:
			var reinstated_rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, n), REINSTATED_SALT))
			if reinstated_rng.chance(day.reinstated_decoy_rate):
				entry.reinstated_on = day.game_date - reinstated_rng.randi_range(0, 1)
		ctx.revoked.append(entry)


## Dates imposées des documents d'un cas scénarisé (`document_dates`, SC-48).
func _apply_document_dates(c: Case, scripted: ScriptedCaseDef) -> void:
	if scripted == null or scripted.document_dates.is_empty():
		return
	for key: Variant in scripted.document_dates:
		var doc: DocumentInstance = c.get_own_document(StringName(str(key)))
		var spec: Variant = scripted.document_dates[key]
		if doc == null or not spec is Dictionary:
			continue
		var dates: Dictionary = spec
		if dates.has("issue"):
			doc.issue_date = SaveService.as_int(dates["issue"])
		if dates.has("expiry"):
			doc.expiry_date = SaveService.as_int(dates["expiry"])


## Violations du cas propre (contrôle §9.2 étape 4). Acte II : pour un cas
## scénarisé, celles des règles qui détectent une anomalie **imposée** sont
## admises (l'identité scénarisée porte déjà l'infraction : le Sillage de
## Corvo, SC-33 — l'injecteur la confirme ensuite).
func _clean_violations(c: Case, scripted: ScriptedCaseDef, forced: Array[AnomalyType.Kind]) -> int:
	return _clean_violation_ids(c, scripted, forced).size()


## Règles violées par le cas propre et non expliquées par une anomalie imposée.
func _clean_violation_ids(c: Case, scripted: ScriptedCaseDef, forced: Array[AnomalyType.Kind]) -> Array[StringName]:
	var violations: Array[Violation] = RuleEngine.validate(c, day.rule_set, _clean_ctx)
	var ids: Array[StringName] = []
	for violation: Violation in violations:
		var rule: Rule = day.rule_set.get_rule(violation.rule_id)
		var explained: bool = false
		if rule != null and scripted != null:
			for kind: AnomalyType.Kind in forced:
				explained = explained or rule.get_detectable_anomalies().has(kind) or _lifts_exemption(rule, kind)
		if not explained:
			ids.append(violation.rule_id)
	return ids


# ---------------------------------------------------------------------------
# Acte III (docs/ACT3.md B37–B44)
# ---------------------------------------------------------------------------

## Acte III : une anomalie imposée qui **ôte une exemption** explique la
## violation de la règle exemptée — répondant absent (R31/R37 levées par un
## Répondant, SC-62) ou convocation fausse (règles levées par R36, SC-75d).
static func _lifts_exemption(rule: Rule, kind: AnomalyType.Kind) -> bool:
	if kind == AnomalyType.Kind.FORGED_SUMMONS:
		return rule.summons_exempt
	if kind == AnomalyType.Kind.SPONSOR_MISMATCH:
		return rule is FactionBannedRule and (rule as FactionBannedRule).exempt_if_sponsored
	return false


## Poids d'un type d'anomalie ce jour, modulé par les drapeaux du matin
## (`DayDef.anomaly_weight_modifiers`).
func weight_of(kind: AnomalyType.Kind) -> float:
	var weight: float = day.anomaly_weights.get(kind, 0.0)
	for flag: StringName in day.anomaly_weight_modifiers:
		if not FlagCondition.is_flag_true(_flag_values, flag):
			continue
		var table: Dictionary = day.anomaly_weight_modifiers[flag]
		if table.has(kind):
			var factor: float = table[kind]
			weight *= factor
	return weight


## N° ID présenté par le passager **propre** de l'index (répondants, R34) ;
## vide hors de la file. Mis en cache (cas indépendants, déterministes).
func peek_citizen_id(index: int) -> String:
	if index < 0 or index >= day.passenger_count:
		return ""
	if _clean_ids.has(index):
		return _clean_ids[index]
	var generated: GeneratedCase = build_clean(index)
	var citizen_id: String = generated.case.passenger_presented.citizen_id if generated != null else ""
	_clean_ids[index] = citizen_id
	return citizen_id


## Répondant (index) prévu pour un protégé, −1 sinon.
func sponsor_index_of(index: int) -> int:
	if wards.has(index):
		return wards[index]
	var scripted: ScriptedCaseDef = get_scripted_case(index)
	if scripted != null and scripted.sponsor_case_id != &"":
		var sponsor: ScriptedCaseDef = _find_in(get_active_scripted_cases(), scripted.sponsor_case_id)
		return sponsor.at_index if sponsor != null else -1
	return -1


## Main courante (R34) : un passager **approuvé** et admissible (HAL, C-1 à
## C-3, lus sur sa carte) y est inscrit, que l'approbation soit juste ou non
## (D-087). Renvoie l'entrée ajoutée, ou null. Appelé par le `DayController`
## et le `DaySimulator` après chaque tampon (et par `build_day`).
func record_verdict(case: Case, verdict: VerdictKind.Kind) -> LedgerEntry:
	if case == null or verdict != VerdictKind.Kind.APPROVE or SponsorRule.find_in(day.rule_set) == null:
		return null
	var faction: Variant = PurposeConsistentRule._value(case, &"id_card", &"faction_id")
	var citizen_class: Variant = PurposeConsistentRule._value(case, &"id_card", &"citizen_class")
	var citizen_id: Variant = PurposeConsistentRule._value(case, &"id_card", &"citizen_id")
	if citizen_id == null or not SponsorRule.is_eligible(faction, citizen_class):
		return null
	var entry: LedgerEntry = LedgerEntry.new()
	entry.id = StringName("ledger_%02d" % case.index)
	entry.citizen_id = str(citizen_id)
	var given: Variant = PurposeConsistentRule._value(case, &"id_card", &"given_name")
	var family: Variant = PurposeConsistentRule._value(case, &"id_card", &"family_name")
	entry.given_name = str(given) if given != null else ""
	entry.family_name = str(family) if family != null else ""
	entry.citizen_class = StringName(str(citizen_class))
	entry.faction_id = StringName(str(faction))
	entry.case_index = case.index
	ctx.ledger.append(entry)
	return entry


## Main courante du shift (publiée par `EventBus.ledger_changed`).
func get_ledger() -> Array[LedgerEntry]:
	return ctx.ledger


## Onglet Convocations du jour (publié par `EventBus.summons_published`).
func get_summons() -> Array[SummonsEntry]:
	return ctx.summons


func _rule_of(script: Script) -> Rule:
	for rule: Rule in day.rule_set.rules:
		if is_instance_of(rule, script):
			return rule
	return null


## Plan du jour (au début du jour, avant toute construction) : passagers
## générés convoqués (R36), protégés et répondants (R34, R37), motifs.
func _plan_act3() -> void:
	var special: Array[int] = []
	for scripted: ScriptedCaseDef in _active:
		special.append(scripted.at_index)
	var reserved: Array[int] = []
	for def: WantedNoticeDef in day.wanted_notices:
		if def != null and def.scripted_case_id == &"" and def.memory_case_id == &"" and def.at_index >= 0 \
				and FlagCondition.check(def.condition, _flag_values):
			reserved.append(def.at_index)
	for def: RevocationDef in day.revocations:
		if def != null and def.scripted_case_id == &"" and def.at_index >= 0 and FlagCondition.check(def.condition, _flag_values):
			reserved.append(def.at_index)
	# 1. Convocations (R36) : passagers générés des `SummonsDef`, puis tirage.
	if _rule_of(SummonsRule) != null:
		for def: SummonsDef in day.summons:
			if def != null and def.scripted_case_id == &"" and def.at_index >= 0 and def.at_index < day.passenger_count \
					and not special.has(def.at_index) and FlagCondition.check(def.condition, _flag_values):
				summoned_numbers[def.at_index] = _summons_number(def.at_index)
		if day.summons_rate > 0.0:
			for i: int in day.passenger_count:
				if special.has(i) or reserved.has(i) or summoned_numbers.has(i) or roster.get_entry(i).faction_id == &"hal":
					continue
				var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, i), SUMMONS_SALT))
				if rng.chance(day.summons_rate):
					summoned_numbers[i] = _summons_number(i)
	# 2. Répondants (R34) : liens imposés, puis plan générique.
	if SponsorRule.find_in(day.rule_set) == null:
		return
	var forced_factions: Array[StringName] = []
	var blocked_factions: Array[StringName] = []
	for rule: Rule in day.rule_set.rules:
		var banned: FactionBannedRule = rule as FactionBannedRule
		if banned == null:
			continue
		# Origine fermée sans autre exemption (R37) : tout ressortissant propre
		# a un répondant ; fermée sans exemption par répondant : jamais de
		# visite familiale ; sinon (R31 : postes exemptés) tirage ordinaire.
		var only_sponsor: bool = banned.exempt_posts.is_empty() and banned.exempt_purposes.is_empty()
		for faction_id: StringName in banned.banned_faction_ids:
			if banned.exempt_if_sponsored and only_sponsor:
				forced_factions.append(faction_id)
			elif not banned.exempt_if_sponsored:
				blocked_factions.append(faction_id)
	var link_keys: Array[int] = []
	link_keys.assign(day.sponsor_links.keys())
	link_keys.sort()
	for ward: int in link_keys:
		var sponsor: int = day.sponsor_links[ward]
		if get_scripted_case(sponsor) == null or special.has(ward) or reserved.has(ward) or ward >= day.passenger_count:
			continue
		wards[ward] = sponsor
		linked_wards.append(ward)
		var entry: AppearanceRoster.Entry = roster.get_entry(ward)
		if day.linked_ward_faction != &"" and entry != null:
			entry.faction_id = day.linked_ward_faction
	var capable: Array[int] = []
	var load: Dictionary[int, int] = {}
	for i: int in day.passenger_count:
		if special.has(i) or wards.has(i) or summoned_numbers.has(i):
			continue
		var faction_id: StringName = roster.get_entry(i).faction_id
		if faction_id == &"hal":
			if not reserved.has(i):
				capable.append(i)
			continue
		if blocked_factions.has(faction_id):
			_no_family.append(i)
			continue
		var must: bool = forced_factions.has(faction_id)
		if reserved.has(i) and not must:
			# Avis ou révocation générés : protégé seulement si l'origine l'exige (R37).
			_no_family.append(i)
			continue
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, i), WARD_SALT))
		if not must and not rng.chance(_family_visit_rate(faction_id)):
			_no_family.append(i)
			continue
		var sponsor: int = _pick_sponsor(capable, load, i)
		if sponsor < 0 and must:
			sponsor = _convert_to_sponsor(i, special, reserved, capable)
		if sponsor < 0:
			if must:
				# Aucun répondant possible (tête de file) : passager né-Halcyon.
				roster.get_entry(i).faction_id = &"hal"
				if not reserved.has(i):
					capable.append(i)
			else:
				_no_family.append(i)
			continue
		wards[i] = sponsor
		load[sponsor] = load.get(sponsor, 0) + 1
	# Répondants générés effectivement sollicités.
	for ward: int in wards:
		var sponsor_index: int = wards[ward]
		if get_scripted_case(sponsor_index) == null and not sponsor_indices.has(sponsor_index):
			sponsor_indices.append(sponsor_index)
	sponsor_indices.sort()


## Part des ressortissants au motif VISITE FAMILIALE pour une origine :
## `DayDef.family_visit_rates`, sinon le poids du motif dans l'origine.
func _family_visit_rate(faction_id: StringName) -> float:
	if day.family_visit_rates.has(faction_id):
		return day.family_visit_rates[faction_id]
	var faction: FactionDef = data.factions.get(faction_id, null)
	if faction == null or faction.purpose_weights.is_empty():
		return 0.0
	var total: float = 0.0
	for purpose: StringName in faction.purpose_weights:
		total += faction.purpose_weights[purpose]
	return faction.purpose_weights.get(Passenger.PURPOSE_FAMILY_VISIT, 0.0) / total if total > 0.0 else 0.0


## Répondant le plus proche avant `index` encore disponible, −1 sinon.
func _pick_sponsor(capable: Array[int], load: Dictionary[int, int], index: int) -> int:
	for k: int in range(capable.size() - 1, -1, -1):
		var candidate: int = capable[k]
		if candidate < index and load.get(candidate, 0) < maxi(day.max_wards_per_sponsor, 1):
			return candidate
	return -1


## Un passager générique plus tôt dans la file devient né-Halcyon répondant
## (R37 : tout ressortissant de l'origine fermée doit avoir un répondant).
func _convert_to_sponsor(index: int, special: Array[int], reserved: Array[int], capable: Array[int]) -> int:
	for j: int in range(index - 1, -1, -1):
		if special.has(j) or reserved.has(j) or wards.has(j) or summoned_numbers.has(j) or capable.has(j):
			continue
		if roster.get_entry(j).faction_id == &"hal":
			continue
		roster.get_entry(j).faction_id = &"hal"
		_no_family.erase(j)
		capable.append(j)
		capable.sort()
		return j
	return -1


func _summons_number(index: int) -> String:
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, index), SUMMONS_SALT + "_number"))
	return "%s%04d" % [SUMMONS_PREFIX, rng.randi_range(SUMMONS_RANGE.x, SUMMONS_RANGE.y)]


## Plan du jour appliqué au passager vrai d'un index généré.
func _post_generate_act3(truth: Passenger, faction: FactionDef, index: int) -> void:
	var case_seed: int = SeededRng.case_seed(day_seed, index)
	if summoned_numbers.has(index):
		truth.summons_id = summoned_numbers[index]
	if wards.has(index):
		truth.purpose = Passenger.PURPOSE_FAMILY_VISIT
		truth.sponsor_id = peek_citizen_id(wards[index])
	elif _no_family.has(index) and truth.purpose == Passenger.PURPOSE_FAMILY_VISIT:
		truth.purpose = _repick_purpose(faction, SeededRng.new(SeededRng.mix(case_seed, SALT_PLAN)))
	if sponsor_indices.has(index) and not SponsorRule.ELIGIBLE_CLASSES.has(truth.citizen_class):
		truth.citizen_class = &"C-3"
	# R35 : aucun ressortissant de Tycho généré en règle avec un contrat CT-KA.
	var lockout: ContractSuspendedRule = _rule_of(ContractSuspendedRule) as ContractSuspendedRule
	if lockout != null and not summoned_numbers.has(index) and lockout.suspends(truth.faction_id, truth.employer_code):
		var others: PackedStringArray = []
		var contract_rule: ContractConsistentRule = _contract_rule()
		for employer: String in faction.employers:
			if contract_rule == null or not lockout.suspended_codes.has(contract_rule.code_for(employer)):
				others.append(employer)
		if not others.is_empty():
			var employer_rng: SeededRng = SeededRng.new(SeededRng.mix(case_seed, SALT_PLAN + 1))
			truth.employer = others[employer_rng.randi_range(0, others.size() - 1)]
			_assign_employer_code(truth)


## Motif tiré de l'origine, hors VISITE FAMILIALE.
static func _repick_purpose(faction: FactionDef, rng: SeededRng) -> StringName:
	var keys: Array[StringName] = []
	var weights: PackedFloat32Array = []
	for purpose: StringName in faction.purpose_weights:
		if purpose == Passenger.PURPOSE_FAMILY_VISIT:
			continue
		keys.append(purpose)
		weights.append(faction.purpose_weights[purpose])
	if keys.is_empty():
		return Passenger.PURPOSE_TRANSIT
	var index: int = rng.weighted_index(weights)
	return keys[index] if index >= 0 else keys[0]


## Onglet Convocations (R36) : N° et noms des permis des passagers convoqués
## (cas propres), puis leurres tirés du `day_seed` ; trié par N°.
func _build_summons() -> void:
	if _rule_of(SummonsRule) == null:
		return
	var taken: Array[int] = []
	for def: SummonsDef in day.summons:
		if def == null or not FlagCondition.check(def.condition, _flag_values):
			continue
		var index: int = def.at_index
		if def.scripted_case_id != &"":
			var scripted: ScriptedCaseDef = _find_in(get_active_scripted_cases(), def.scripted_case_id)
			index = scripted.at_index if scripted != null else -1
		if index < 0 or index >= day.passenger_count or taken.has(index):
			continue
		_add_summons_entry(def.id, index, def.reason_key)
		taken.append(index)
	var generated: Array[int] = []
	generated.assign(summoned_numbers.keys())
	generated.sort()
	for index: int in generated:
		if not taken.has(index):
			_add_summons_entry(StringName("summons_%02d" % index), index, "")
			taken.append(index)
	if day.summons_decoys > 0:
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(day_seed, SUMMONS_DECOY_SALT))
		var faction_ids: Array[StringName] = []
		faction_ids.assign(data.factions.keys())
		faction_ids.sort()
		for n: int in day.summons_decoys:
			var faction: FactionDef = data.factions[faction_ids[rng.randi_range(0, faction_ids.size() - 1)]]
			var entry: SummonsEntry = SummonsEntry.new()
			entry.id = StringName("summons_decoy_%d" % n)
			var number: String = "%s%04d" % [SUMMONS_PREFIX, rng.randi_range(SUMMONS_RANGE.x, SUMMONS_RANGE.y)]
			while ctx.find_summons_by_number(number) != null:
				number = "%s%04d" % [SUMMONS_PREFIX, rng.randi_range(SUMMONS_RANGE.x, SUMMONS_RANGE.y)]
			entry.number = number
			if faction.name_pool != null:
				var sex: StringName = PassengerGenerator.SEXES[rng.randi_range(0, 1)]
				entry.given_name = faction.name_pool.pick_given_name(rng, sex)
				entry.family_name = faction.name_pool.pick_family_name(rng)
			ctx.summons.append(entry)
	ctx.summons.sort_custom(func(a: SummonsEntry, b: SummonsEntry) -> bool: return a.number < b.number)


func _add_summons_entry(id: StringName, index: int, reason_key: String) -> void:
	var generated: GeneratedCase = build_clean(index)
	if generated == null:
		return
	var presented: Passenger = generated.case.passenger_presented
	if presented.summons_id.is_empty():
		push_error("CaseBuilder: convocation « %s » sans N° sur le permis (jour %d, cas %d)" % [id, day.day_number, index])
		return
	var entry: SummonsEntry = SummonsEntry.new()
	entry.id = id
	entry.number = presented.summons_id
	entry.given_name = presented.given_name
	entry.family_name = presented.family_name
	entry.reason_key = reason_key
	entry.case_index = index
	ctx.summons.append(entry)


## M1 « Retour aux quais » (SC-58) : documents retirés présentés quand même
## (`DocumentInstance.retired`), dates imposées par `document_dates`.
func _add_retired_documents(c: Case, truth: Passenger, scripted: ScriptedCaseDef, rng: SeededRng) -> void:
	if scripted == null or scripted.retired_documents.is_empty():
		return
	for document_id: StringName in scripted.retired_documents:
		var def: DocumentTypeDef = data.documents.get(document_id, null)
		if def == null:
			push_error("CaseBuilder: document retiré inconnu « %s » (%s)" % [document_id, scripted.id])
			continue
		var doc: DocumentInstance = DocumentFactory.create(def, truth, day.game_date, rng.fork(SeededRng.hash_string(document_id)),
				appearance_gen, false, 1)
		doc.retired = true
		var spec: Variant = scripted.document_dates.get(document_id, scripted.document_dates.get(String(document_id), null))
		if spec is Dictionary:
			var dates: Dictionary = spec
			if dates.has("issue"):
				doc.issue_date = SaveService.as_int(dates["issue"])
			if dates.has("expiry"):
				doc.expiry_date = SaveService.as_int(dates["expiry"])
		c.documents.append(doc)


## R32 : un document daté contrôlé d'un passager généré propre expire **dans**
## la fenêtre de prorogation (bruit légitime, `prorogation_noise_rate`).
func _apply_prorogation_noise(c: Case, rng: SeededRng) -> bool:
	if day.prorogation_noise_rate <= 0.0 or not rng.chance(day.prorogation_noise_rate):
		return false
	var rule: ProrogationRule = ctx.prorogation()
	if rule == null or day.game_date > rule.extended_until:
		return false
	var latest: int = mini(rule.window_end, day.game_date - 1)
	if latest < rule.window_start:
		return false
	var candidates: Array[DocumentInstance] = []
	for doc: DocumentInstance in c.documents:
		if doc.is_foreign() or doc.type_def == null or doc.type_def.find_field_by_truth_path(EXPIRY_DOC_PATH) == null:
			continue
		if _expiry_checked(doc.get_document_id()):
			candidates.append(doc)
	if candidates.is_empty():
		return false
	var target: DocumentInstance = candidates[rng.randi_range(0, candidates.size() - 1)]
	var duration: int = target.expiry_date - target.issue_date
	target.expiry_date = rng.randi_range(rule.window_start, latest)
	target.issue_date = target.expiry_date - duration
	return true


## Une règle active contrôle la date d'expiration de ce document.
func _expiry_checked(document_id: StringName) -> bool:
	for rule: Rule in day.rule_set.rules:
		var expiry: DocumentNotExpiredRule = rule as DocumentNotExpiredRule
		if expiry != null and expiry.document_id == document_id and expiry.max_age_days == 0 and expiry.field_path == &"":
			return true
		var require: RequireDocumentRule = rule as RequireDocumentRule
		if require != null and require.require_valid and require.document_id == document_id:
			return true
	return false
