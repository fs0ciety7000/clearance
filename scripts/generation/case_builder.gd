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
## M12 (R39) : carte de répondant (monde B de l'épilogue).
const SPONSOR_CARD_ID: StringName = &"sponsor_card"
## M12 (R41) : part des bio-scans de ressortissants de Tycho émis par un
## émetteur agréé autre que celui du type (Dispensaire de Tycho, monde D).
const ALT_ISSUER_RATE: float = 0.6
const SALT_ISSUER: int = 15
const SALT_SUBTLE: int = 17
## M13 : flux des déclarations orales et de la fouille (n'altèrent aucun
## tirage existant).
const SALT_STATEMENTS: int = 18
const SALT_SEARCH: int = 19
## M13 : types combinables avec une seule autre anomalie au plus (§1.5, §2.7)
## et arme seule (0 autre anomalie).
const PAIR_ONLY_KINDS: Array[AnomalyType.Kind] = [AnomalyType.Kind.STATEMENT_MISMATCH, AnomalyType.Kind.CONTRABAND,
		AnomalyType.Kind.CONCEALED_IMPLANT]
const ALONE_KINDS: Array[AnomalyType.Kind] = [AnomalyType.Kind.CONCEALED_WEAPON]
## M12 : paramètre d'injection « anomalie subtile » (Garde, `DayDef.subtle_rate`).
const SUBTLE_PARAM: StringName = &"subtle"
## M12 : fenêtre d'exercice d'une directive de Garde (passagers qui la suivent).
const EXERCISE_WINDOW: int = 5
const EXERCISE_SALT: String = "garde_exercise"
const LISTS_SALT: String = "garde_lists"
const STOLEN_SALT: String = "stolen_list"

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
## M13 : noms présentés des passagers propres (nom imprimé du Répondant).
var _clean_names: Dictionary[int, String] = {}
var _active: Array[ScriptedCaseDef] = []
var _active_ready: bool = false
## M12 : nombre de passagers déjà construits par `build` (le prochain est cet
## index) — situe les changements de règles appliqués juste avant lui.
var _built_count: int = 0
## M12 : passagers générés imposés (exercice d'une directive de Garde, porteurs
## d'une liste nommée) : index → `{kinds, params, overrides, visor, rule_id}`.
var _forced: Dictionary[int, Dictionary] = {}
## M12 : types exclus du tirage d'un passager (au plus 3 violations de la règle
## nouvelle dans les 5 passagers qui suivent une directive) : index → types.
var _excluded_kinds: Dictionary[int, Array] = {}
## M12 : listes renouvelées par le dernier `on_rules_changed` (`wanted`,
## `revoked`, `stolen`…), à republier par le `DayController`.
var changed_lists: PackedStringArray = []
## M12 : essai d'un cas imposé (exercice) — erreurs consignées sans `push_error`.
var _probing: bool = false
## M12 : règles retirées par un événement de station (motif `sev_*`) : leur
## rétablissement n'est pas une directive (pas d'exercice ni de listes).
var _event_retired: Array[StringName] = []
## QA-051 : identités reprises d'un jour antérieur (cache de `_day_identity_names`).
var _day_identities: PackedStringArray = []
var _day_identities_ready: bool = false


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
	_apply_rule_replacements()
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


## M12 (SC-89a) : règles remplacées pour tout le jour par un cas scénarisé actif
## (`ScriptedCaseDef.rule_replacements`) — sur une copie de shift du jour
## (`DayDef.make_shift_copy`, ou celle que le `DayController` a fournie), jamais
## sur le `.tres` partagé : retrait de la règle d'origine puis ajout de la
## variante du cas, au même rang (sans badge NOUVEAU).
func _apply_rule_replacements() -> void:
	var replacements: Array[Rule] = []
	for scripted: ScriptedCaseDef in _compute_active_scripted_cases():
		for rule: Rule in scripted.rule_replacements:
			if rule != null and day.rule_set != null and day.rule_set.has_rule(rule.id):
				replacements.append(rule)
	if replacements.is_empty():
		return
	if not day.rule_set.is_shift_copy:
		day = day.make_shift_copy()
	for rule: Rule in replacements:
		var changes: Array[RuleChangeDef] = [RuleChangeDef.retire(rule.id), RuleChangeDef.add(rule, false)]
		day.rule_set.apply_changes(changes, StringName("scripted_%s" % rule.id))


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


## M12 (EV-06 « Foule nerveuse », Garde) : la file s'allonge en cours de shift
## (`day.passenger_count` augmenté par le `DayController`) — le roster suit,
## avec les tirages de chaque nouvel index (entrées existantes inchangées).
func ensure_capacity() -> void:
	if roster == null or day.passenger_count <= roster.size():
		return
	var old_size: int = roster.size()
	appearance_gen.extend_day_roster(roster, day.passenger_count, day.faction_weights, day.game_date)
	# Hors du plan du jour (répondants, R34/R37) : jamais en visite familiale ;
	# une origine fermée sauf répondant (R37) devient née-Halcyon.
	for i: int in range(old_size, roster.size()):
		_no_family.append(i)
		for rule: Rule in day.rule_set.rules:
			var banned: FactionBannedRule = rule as FactionBannedRule
			if banned != null and banned.exempt_if_sponsored and banned.exempt_posts.is_empty() \
					and banned.exempt_purposes.is_empty() and banned.is_banned_origin(roster.get_entry(i).faction_id):
				roster.get_entry(i).faction_id = &"hal"


## M12 (EV-06) : la file passe à `count` passagers (jamais moins) ; le
## roster suit. Le `DayController` peut aussi augmenter `day.passenger_count`
## directement : `build` étend alors le roster de lui-même.
func extend_queue(count: int) -> void:
	if count > day.passenger_count:
		day.passenger_count = count
	ensure_capacity()


## Cas `index` du jour (scénarisé s'il y a lieu, sinon tirage selon le `DayDef`).
func build(index: int) -> GeneratedCase:
	_built_count = maxi(_built_count, index + 1)
	var scripted: ScriptedCaseDef = get_scripted_case(index)
	if scripted != null:
		return _build(index, scripted, scripted.forced_anomalies, scripted.injection_params, true)
	# M12 : passager imposé (exercice d'une directive, porteur d'une liste
	# nommée) — sauf si ses types ne sont plus détectables (règle retirée entre
	# la directive et sa présentation : tirage ordinaire).
	if _forced.has(index):
		var spec: Dictionary = _forced[index]
		var forced_kinds: Array[AnomalyType.Kind] = _kinds_of(spec)
		var still: bool = true
		for kind: AnomalyType.Kind in forced_kinds:
			still = still and day.rule_set.can_detect(kind)
		if still:
			return _build(index, null, forced_kinds, spec.get("params", {}), true)
		_forced.erase(index)
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
	ensure_capacity()
	var entry: AppearanceRoster.Entry = roster.get_entry(index)
	if entry == null:
		return null
	var case_seed: int = SeededRng.case_seed(day_seed, index)
	var rng: SeededRng = SeededRng.new(case_seed)
	var overrides: Dictionary = _overrides_for(scripted)
	if scripted == null and _forced.has(index):
		overrides = _forced[index].get("overrides", {})
	if not forced.is_empty():
		params = _resolve_params(params)
	elif not exact and scripted == null and day.subtle_rate > 0.0 and ctx.modifier(RuleChangeDef.MOD_NO_SUBTLE) <= 0 \
			and rng.fork(SALT_SUBTLE).chance(day.subtle_rate):
		# M12 (Garde, §2.5) : anomalies plus fines (veille, un caractère, diacritique).
		params = {SUBTLE_PARAM: true}
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
		_apply_issuers(c, truth, scripted, attempt_rng.fork(SALT_ISSUER))
		_apply_shift_overrides(c, truth, attempt_rng.fork(SALT_ISSUER + 1))
		# Cas scénarisé : ses anomalies imposées expliquent aussi le contrôle de
		# `build_clean` (avis de recherche de Mira, SC-82b, fermée par R37).
		result.clean_violation_count = _clean_violations(c, scripted, scripted.forced_anomalies if scripted != null else forced)
		if result.clean_violation_count == 0:
			break
		if attempt == MAX_CLEAN_ATTEMPTS - 1 and not _probing:
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
	# M13 : déclarations et fouille imposées par un cas scénarisé.
	state.scripted_statements = scripted != null and not scripted.statements.is_empty()
	if scripted != null and not scripted.search_items.is_empty():
		state.params = params.duplicate()
		state.params[&"scripted_search"] = true
	var anomalies: Array[Anomaly] = []
	if exact:
		state.planned_count = forced.size()
		result.requested_anomalies = forced.size()
		for kind: AnomalyType.Kind in forced:
			var anomaly: Anomaly = _inject(kind, state)
			if anomaly == null and not _probing:
				push_error("CaseBuilder: anomalie imposée %s impossible (jour %d, cas %d)"
						% [AnomalyType.name_of(kind), day.day_number, index])
			elif anomaly == null:
				result.invariant_errors.append("anomalie imposée %s impossible" % AnomalyType.name_of(kind))
			else:
				anomalies.append(anomaly)
	else:
		anomalies = _inject_random(state, result)

	_finalize_documents(state)
	# M13 : déclarations orales (R43) et contenu de la fouille (R44 → R46), sur
	# les documents finaux.
	_finalize_m13(c, truth, state, scripted, rng, exact)
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
	if scripted == null and _forced.has(index) and bool(_forced[index].get("visor", false)):
		# M12 : exercice de R06 (visage découvert) — visière baissée.
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
	result.invariant_errors.append_array(check_invariants(result, ctx))
	if not result.invariant_errors.is_empty() and not _probing:
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
	# M12 (R39) : un·e protégé·e porteur d'un répondant présente une carte de
	# répondant au lieu du permis.
	for rule: Rule in day.rule_set.rules:
		var welcome: RequireDocumentRule = rule as RequireDocumentRule
		if welcome != null and welcome.exempt_if_sponsor and not p.sponsor_id.is_empty() and ids.has(welcome.document_id):
			ids.erase(welcome.document_id)
			if data.documents.has(SPONSOR_CARD_ID) and not ids.has(SPONSOR_CARD_ID):
				ids.append(SPONSOR_CARD_ID)
	var has_permit: bool = ids.has(&"entry_permit")
	for rule: Rule in day.rule_set.rules:
		if rule is RequireDocumentRule:
			var require: RequireDocumentRule = rule
			if require.is_conditional() and not ids.has(require.document_id) and require.requires_for(p, has_permit):
				ids.append(require.document_id)
	# M12 (R42, monde D sans permis ni R24) : un passager au motif TRAVAIL
	# présente son contrat (« contrat éventuel »).
	var cadres: ContractSuspendedRule = _rule_of(ContractSuspendedRule) as ContractSuspendedRule
	if cadres != null and cadres.any_origin and p.purpose == Passenger.PURPOSE_WORK and not ids.has(cadres.contract_id) \
			and not p.employer.is_empty():
		ids.append(cadres.contract_id)
	# M12 (B54, EV-08) : document dispensé par une surcharge de shift en vigueur
	# (TRANSIT sans bio-scan de 13:00 à 14:00) — jamais produit dans ce cas.
	if ctx != null and day.rule_set.is_shift_copy:
		for rule: Rule in day.rule_set.rules:
			var exempted: RequireDocumentRule = rule as RequireDocumentRule
			if exempted != null and ids.has(exempted.document_id) \
					and day.rule_set.get_param(exempted.id, RequireDocumentRule.PARAM_EXEMPT, false, p.faction_id, p.purpose,
					ctx.now_minute if ctx.now_minute >= 0 else presentation_minute) == true:
				ids.erase(exempted.document_id)
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
	# M12 (classe B, D-129 règle 4) : au plus `max_anomalies` par passager.
	var cap: int = ctx.modifier(RuleChangeDef.MOD_MAX_ANOMALIES)
	if cap > 0:
		count = mini(count, cap)
	result.requested_anomalies = count
	state.planned_count = count
	var candidates: Array[AnomalyType.Kind] = get_drawable_kinds()
	for excluded: Variant in _excluded_kinds.get(state.case.index, []):
		candidates.erase(excluded)
	# M13 : déclaration, contrebande et implant dissimulé avec une autre
	# anomalie au plus ; arme seule.
	if count >= 2:
		for kind: AnomalyType.Kind in ALONE_KINDS:
			candidates.erase(kind)
	if count >= 3:
		for kind: AnomalyType.Kind in PAIR_ONLY_KINDS:
			candidates.erase(kind)
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
	var anomaly: Anomaly = injector.inject(state)
	if anomaly != null:
		state.injected.append(kind)
	return anomaly


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
	var sponsored: bool = with_sponsor and (scripted.sponsor_case_id != &"" or scripted.sponsor_index >= 0)
	if scripted.identity_from_case == &"" and not sponsored:
		return scripted.passenger_overrides
	var result: Dictionary = {}
	if scripted.identity_from_case != &"":
		result = CaseMemory.identity_overrides(_memory_entry(scripted.identity_from_case))
	for key: Variant in scripted.passenger_overrides:
		result[key] = scripted.passenger_overrides[key]
	if sponsored and scripted.sponsor_case_id != &"":
		var sponsor: ScriptedCaseDef = _find_in(get_active_scripted_cases(), scripted.sponsor_case_id)
		if sponsor != null:
			result[&"sponsor_id"] = peek_citizen_id(sponsor.at_index)
			result[&"sponsor_name"] = peek_full_name(sponsor.at_index)
	elif sponsored and scripted.sponsor_index >= 0:
		# M12 (SC-95) : répondant généré plus tôt dans la file.
		result[&"sponsor_id"] = peek_citizen_id(scripted.sponsor_index)
		result[&"sponsor_name"] = peek_full_name(scripted.sponsor_index)
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
		elif scripted.appearance_from_photo != &"":
			# M12 (SC-84b, B59) : visage de la photo présentée par un cas antérieur.
			remembered = _photo_appearance(scripted.appearance_from_photo)
			if remembered == null and roster.get_entry(scripted.at_index) != null:
				# QA-060 : photo introuvable (mémoire 0.11 non recalculable) —
				# visage générique du roster, tranche d'âge recalculée ci-dessous
				# depuis l'identité reprise (cas propre possible).
				remembered = roster.get_entry(scripted.at_index).appearance
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


## QA-051 : « Prénom|Nom » des identités reprises d'un jour antérieur par les
## cas scénarisés actifs (`identity_from_case`) — jamais portées par un
## passager généré du jour.
func _day_identity_names() -> PackedStringArray:
	if _day_identities_ready:
		return _day_identities
	_day_identities_ready = true
	for scripted: ScriptedCaseDef in get_active_scripted_cases():
		if scripted.identity_from_case == &"":
			continue
		var identity: Dictionary = _overrides_for(scripted, false)
		var given: String = str(identity.get(&"given_name", ""))
		var family: String = str(identity.get(&"family_name", ""))
		if not given.is_empty() and not family.is_empty():
			_day_identities.append("%s|%s" % [given, family])
	return _day_identities


## Prénom qui ne reproduit aucune identité reprise du jour (ordre de la réserve,
## circulaire, comme `NamePool.avoid_reserved_full_name`) — déterministe, sans tirage.
func _avoid_day_identity(pool: NamePool, given: String, family: String, sex: StringName) -> String:
	var taken: PackedStringArray = _day_identity_names()
	if taken.is_empty() or not taken.has("%s|%s" % [given, family]):
		return given
	var names: PackedStringArray = pool.given_names_for(sex)
	var start: int = maxi(names.find(given), 0)
	for step: int in range(1, names.size() + 1):
		var candidate: String = names[(start + step) % names.size()]
		if not taken.has("%s|%s" % [candidate, family]) and not pool.is_reserved_full_name(candidate, family):
			return candidate
	return given


## M12 (B59) : apparence de la photo présentée par un cas antérieur
## (`CaseMemory.photo_appearance_of`, lot A) ; null si absente (visage du roster).
func _photo_appearance(scripted_id: StringName) -> PassengerAppearance:
	var entry: Dictionary = _memory_entry(scripted_id)
	if entry.is_empty():
		return null
	return CaseMemory.photo_appearance_of(entry)


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
	# QA-051 : homonyme fortuit d'une identité reprise d'un jour antérieur
	# (`identity_from_case`, SC-84b) : autre prénom, sans tirage (un avis de
	# recherche visant ce passager viserait aussi le cas scénarisé).
	if not scripted_case and not overrides.has(&"given_name") and faction.name_pool != null:
		truth.given_name = _avoid_day_identity(faction.name_pool, truth.given_name, truth.family_name, truth.sex)
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
		# M12 (R38) : ressortissant de Tycho en règle = contrat Kessler-Ashe valide.
		if banned != null and not banned.exempt_contract_codes.is_empty() and banned.is_banned_origin(truth.faction_id):
			_give_exempt_contract(truth, banned, overrides)
			continue
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


## M12 (R38) : motif TRAVAIL et employeur au code exempté (`KA`) ; le contrat
## est produit par R24 (motif TRAVAIL). Surcharges explicites respectées
## (SC-93a : Dora en VISITE FAMILIALE, refusée par R38).
func _give_exempt_contract(truth: Passenger, banned: FactionBannedRule, overrides: Dictionary) -> void:
	if overrides.has(&"purpose") and truth.purpose != Passenger.PURPOSE_WORK:
		return
	truth.purpose = Passenger.PURPOSE_WORK
	if overrides.has(&"employer"):
		_assign_employer_code(truth)
		return
	var contract_rule: ContractConsistentRule = _contract_rule()
	if contract_rule == null:
		return
	for employer: String in contract_rule.employer_codes:
		if banned.exempt_contract_codes.has(contract_rule.employer_codes[employer]):
			truth.employer = employer
			truth.employer_code = contract_rule.employer_codes[employer]
			return


func _has_rule(script: Script) -> bool:
	for rule: Rule in day.rule_set.rules:
		if is_instance_of(rule, script):
			return true
	return false


## M13 (docs/M13.md §1, §2 ; B65, B69) : déclarations orales si R43 est
## active (un cas scénarisé sans `statements` garde ses réponses en prose,
## sans puce) ; contenu de la fouille, indices et réponse à « Quelque chose à
## déclarer ? » si le portique est en service (R44, J8+, hors coupure EV-05).
func _finalize_m13(c: Case, truth: Passenger, state: InjectionState, scripted: ScriptedCaseDef, rng: SeededRng,
		_exact: bool) -> void:
	var rule: StatementsConsistentRule = StatementsConsistentRule.active_in(day.rule_set)
	if rule != null and data.statement_tables != null:
		if scripted != null:
			if not scripted.statements.is_empty():
				apply_scripted_statements(c, scripted)
		else:
			StatementGenerator.generate(c, data.statement_tables, rule, rng.fork(SALT_STATEMENTS), state.statement_lie)
	if data.search_catalog == null or not SearchGenerator.search_enabled(day.rule_set):
		return
	var search_rng: SeededRng = rng.fork(SALT_SEARCH)
	if scripted != null:
		SearchGenerator.build_scripted(c, truth, data.search_catalog, scripted, search_rng, state.search_plan, day.day_number)
		return
	var card_field: StringName = AnomalyInjector.field_for(c, &"id_card", &"implants")
	var card_free: bool = card_field != &"" and state.is_free(&"id_card", card_field)
	SearchGenerator.build(c, truth, data.search_catalog, search_rng, state.search_plan, day.search_cue_noise_rate,
			card_free, day.day_number, day.detain_enabled)


## M13 : déclarations d'un cas scénarisé (`ScriptedCaseDef.statements`).
static func apply_scripted_statements(c: Case, scripted: ScriptedCaseDef) -> void:
	c.statements.clear()
	for statement_id: Variant in scripted.statements:
		var spec: Dictionary = scripted.statements[statement_id]
		var id: StringName = StringName(str(statement_id))
		var statement: Statement = null
		if bool(spec.get("vague", false)):
			statement = Statement.vague_answer(id, str(spec.get("key", "")))
		else:
			var value: Variant = spec.get("value", null)
			if value is String and id != Statement.ID_EMPLOYER and id != Statement.ID_HOST:
				value = StringName(value)
			statement = Statement.make(id, value, str(spec.get("key", "")), spec.get("args", []))
			if spec.has("truth_path"):
				statement.truth_path = StringName(str(spec["truth_path"]))
		if id == Statement.ID_PROVENANCE:
			statement.truth_path = &""
		statement.corrected_from = str(spec.get("corrected_from", ""))
		c.statements.append(statement)
	for question: Variant in scripted.statement_frames:
		c.statement_frames[StringName(str(question))] = str(scripted.statement_frames[question])


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
	if contract_rule == null and not overrides.has(&"employer_code"):
		# M12 (R42) : code employeur sans R25 (monde D).
		_assign_employer_code(truth)
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
		return
	# M12 (R42, monde D sans R25) : registre recopié dans la règle des cadres.
	var cadres: ContractSuspendedRule = _rule_of(ContractSuspendedRule) as ContractSuspendedRule
	if cadres != null and not cadres.employer_codes.is_empty():
		truth.employer_code = cadres.employer_codes.get(truth.employer, "00")


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


## M12 : émetteurs imposés d'un cas scénarisé (`document_issuers`, SC-101) ;
## R41 (monde D) : bio-scan d'un ressortissant de Tycho généré émis par un autre
## émetteur agréé que celui du type (Dispensaire de Tycho), `ALT_ISSUER_RATE`.
func _apply_issuers(c: Case, truth: Passenger, scripted: ScriptedCaseDef, rng: SeededRng) -> void:
	if scripted != null and not scripted.document_issuers.is_empty():
		for key: Variant in scripted.document_issuers:
			var doc: DocumentInstance = c.get_own_document(StringName(str(key)))
			if doc != null:
				doc.issuer_id = StringName(str(scripted.document_issuers[key]))
		return
	if scripted != null or truth.faction_id != &"tyc":
		return
	for rule: Rule in day.rule_set.rules:
		var issuer_rule: IssuerAllowedRule = rule as IssuerAllowedRule
		if issuer_rule == null or issuer_rule.allowed_issuer_ids.size() < 2:
			continue
		var doc: DocumentInstance = c.get_own_document(issuer_rule.document_id)
		if doc == null or doc.type_def == null:
			continue
		var others: Array[StringName] = []
		for issuer: StringName in issuer_rule.allowed_issuer_ids:
			if issuer != doc.type_def.issuer_id:
				others.append(issuer)
		if not others.is_empty() and rng.chance(ALT_ISSUER_RATE):
			doc.issuer_id = others[rng.randi_range(0, others.size() - 1)]


## M12 (B54, événements de station) : un document propre respecte les
## surcharges de shift en vigueur — bio-scan d'un ressortissant de Tycho émis
## il y a moins de 7 jours pendant l'alerte de quarantaine (EV-03, `max_age_days`
## surchargé). Sans copie de shift : rien (tirages inchangés).
func _apply_shift_overrides(c: Case, truth: Passenger, rng: SeededRng) -> void:
	if not day.rule_set.is_shift_copy:
		return
	for rule: Rule in day.rule_set.rules:
		var age_rule: DocumentNotExpiredRule = rule as DocumentNotExpiredRule
		if age_rule == null or age_rule.max_age_days <= 0 or age_rule.field_path != &"":
			continue
		var limit: Variant = day.rule_set.get_param(age_rule.id, &"max_age_days", age_rule.max_age_days, truth.faction_id,
				truth.purpose, ctx.now_minute if ctx != null else -1)
		if not limit is int:
			continue
		var max_age: int = limit
		var doc: DocumentInstance = c.get_own_document(age_rule.document_id)
		if doc == null or max_age <= 0 or day.game_date - doc.issue_date < max_age:
			continue
		var duration: int = doc.expiry_date - doc.issue_date
		doc.issue_date = day.game_date - rng.randi_range(0, max_age - 1)
		doc.expiry_date = doc.issue_date + duration


## Violations du cas propre (contrôle §9.2 étape 4). Acte II : pour un cas
## scénarisé, celles des règles qui détectent une anomalie **imposée** sont
## admises (l'identité scénarisée porte déjà l'infraction : le Sillage de
## Corvo, SC-33 — l'injecteur la confirme ensuite).
func _clean_violations(c: Case, scripted: ScriptedCaseDef, forced: Array[AnomalyType.Kind]) -> int:
	return _clean_violation_ids(c, scripted, forced).size()


## QA-050 : le contrôle « cas propre » valide à l'heure de présentation, avec
## le RuleSet du shift — la même heure que celle qui a choisi les documents
## (`required_documents_for_passenger` : surcharge horaire d'EV-08).
func _sync_clean_ctx() -> void:
	_clean_ctx.now_minute = ctx.now_minute if ctx.now_minute >= 0 else presentation_minute
	_clean_ctx.rule_set = day.rule_set


## Règles violées par le cas propre et non expliquées par une anomalie imposée.
func _clean_violation_ids(c: Case, scripted: ScriptedCaseDef, forced: Array[AnomalyType.Kind]) -> Array[StringName]:
	_sync_clean_ctx()
	var violations: Array[Violation] = RuleEngine.validate(c, day.rule_set, _clean_ctx)
	var ids: Array[StringName] = []
	for violation: Violation in violations:
		var rule: Rule = day.rule_set.get_rule(violation.rule_id)
		# M12 : une liste nommée du shift (cartes volées, EV-07) est calculée
		# depuis les cas propres eux-mêmes (comme les avis, D-056) : ignorée ici.
		var listed: RevokedIdRule = rule as RevokedIdRule
		if listed != null and listed.list_label != &"" and listed.list_label != &"revoked":
			continue
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


## M13 (R43 s4) : « Prénom Nom » présenté par le passager propre d'un index
## (nom imprimé du Répondant), vide si indisponible.
func peek_full_name(index: int) -> String:
	if index < 0 or index >= day.passenger_count:
		return ""
	if _clean_names.has(index):
		return _clean_names[index]
	var generated: GeneratedCase = build_clean(index)
	var name: String = generated.case.passenger_presented.full_name() if generated != null else ""
	_clean_names[index] = name
	return name


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
	if case == null or verdict != VerdictKind.Kind.APPROVE or not SponsorRule.keeps_ledger(day.rule_set):
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
	# 2. Répondants (R34 ; M12 : R39) : liens imposés, puis plan générique.
	if not SponsorRule.keeps_ledger(day.rule_set):
		return
	# M12 (SC-95) : répondants générés désignés par un cas scénarisé (`sponsor_index`).
	for scripted: ScriptedCaseDef in _active:
		var forced_sponsor: int = scripted.sponsor_index
		if forced_sponsor < 0 or forced_sponsor >= day.passenger_count or special.has(forced_sponsor):
			continue
		if not sponsor_indices.has(forced_sponsor):
			sponsor_indices.append(forced_sponsor)
		roster.get_entry(forced_sponsor).faction_id = &"hal"
		reserved.append(forced_sponsor)
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
	# Répondants générés effectivement sollicités (et désignés, M12).
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
		truth.sponsor_name = peek_full_name(wards[index])
	elif _no_family.has(index) and truth.purpose == Passenger.PURPOSE_FAMILY_VISIT:
		truth.purpose = _repick_purpose(faction, SeededRng.new(SeededRng.mix(case_seed, SALT_PLAN)))
	if sponsor_indices.has(index) and not SponsorRule.ELIGIBLE_CLASSES.has(truth.citizen_class):
		truth.citizen_class = &"C-3"
	# R35 : aucun ressortissant de Tycho généré en règle avec un contrat CT-KA.
	var lockout: ContractSuspendedRule = _rule_of(ContractSuspendedRule) as ContractSuspendedRule
	if lockout != null and not summoned_numbers.has(index) \
			and lockout.suspends(truth.faction_id, truth.employer_code, truth.citizen_class):
		var others: PackedStringArray = []
		var contract_rule: ContractConsistentRule = _contract_rule()
		for employer: String in faction.employers:
			var code: String = contract_rule.code_for(employer) if contract_rule != null \
					else str(lockout.employer_codes.get(employer, ""))
			if not lockout.suspended_codes.has(code):
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


# ---------------------------------------------------------------------------
# M12 (B54, B56, B58) : règles mutées en cours de shift, Garde, événements
# ---------------------------------------------------------------------------

## Crochet du `DayController` (ARCHITECTURE §11.3) après chaque différence de
## règles appliquée, juste avant de construire le passager `_built_count` :
## - liste nommée d'une règle ajoutée (EV-07 « Cartes volées ») : porteurs
##   parmi les passagers suivants, plus des leurres (`ctx.set_list`) ;
## - Garde de nuit : avis et révocations renouvelés à chaque directive
##   (U15, U20 ; D-056 : avant les passagers visés) et **exercice garanti** de
##   la règle nouvelle (1 ou 2 des 5 passagers suivants la violent, aucun
##   autre tirage de ses types : au plus 3).
## `changed_lists` nomme les listes à republier (`wanted`, `revoked`, `stolen`).
func on_rules_changed(diff: RuleDiff) -> void:
	changed_lists = PackedStringArray()
	if diff == null:
		return
	var start: int = _built_count
	for rule_id: StringName in diff.retired:
		if str(day.rule_set.retired_note_keys.get(rule_id, "")).begins_with("sev_") and not _event_retired.has(rule_id):
			_event_retired.append(rule_id)
	var fresh: Array[Rule] = []
	var ids: Array[StringName] = diff.added.duplicate()
	for rule_id: StringName in diff.restored:
		if _event_retired.has(rule_id):
			_event_retired.erase(rule_id)
		else:
			ids.append(rule_id)
	# M13 (EV-09) : fouille autorisée pour un profil : 1 ou 2 porteurs dans la fenêtre.
	if diff.overridden.has(SearchGenerator.SEARCH_RULE_ID):
		_plan_search_alert(start)
	for rule_id: StringName in ids:
		var rule: Rule = day.rule_set.get_rule(rule_id)
		if rule == null:
			continue
		var listed: RevokedIdRule = rule as RevokedIdRule
		if listed != null and listed.list_label != &"" and listed.list_label != &"revoked":
			_publish_named_list(listed, start)
			continue
		fresh.append(rule)
	if day.mode != DayDef.MODE_GARDE or fresh.is_empty():
		return
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, start), EXERCISE_SALT))
	var carriers: Array[int] = _renew_garde_lists(start, fresh, rng)
	_plan_exercise(fresh, start, carriers, rng)


## M13 (EV-09, M13 §2.10) : « fouille autorisée » (surcharge
## `search_authorized` de R44) pour une origine ou un motif ; 1 ou 2 passagers
## générés du profil, dans les `ALERT_WINDOW` suivants, portent de la
## contrebande (jamais un index scénarisé ni imposé).
const ALERT_WINDOW: int = 5
const ALERT_SALT: String = "contraband_alert"


func _plan_search_alert(start: int) -> void:
	var change: RuleChangeDef = null
	for candidate: RuleChangeDef in day.rule_set.overrides:
		if candidate.rule_id == SearchGenerator.SEARCH_RULE_ID and candidate.params.get(&"search_authorized", false) == true:
			change = candidate
	if change == null or not day.rule_set.can_detect(AnomalyType.Kind.CONTRABAND):
		return
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, start), ALERT_SALT))
	var matching: Array[int] = []
	for index: int in _free_window(start, ALERT_WINDOW):
		var entry: AppearanceRoster.Entry = roster.get_entry(index)
		if entry == null:
			continue
		if change.faction_ids.is_empty() or change.faction_ids.has(entry.faction_id):
			matching.append(index)
	var carriers: int = mini(rng.randi_range(1, 2), matching.size())
	var picked: Array = rng.shuffled(matching)
	for k: int in carriers:
		var overrides: Dictionary = {}
		if not change.purposes.is_empty():
			overrides[&"purpose"] = change.purposes[rng.randi_range(0, change.purposes.size() - 1)]
		_forced[int(picked[k])] = {"kinds": [AnomalyType.Kind.CONTRABAND], "params": {}, "overrides": overrides,
				"rule_id": SearchGenerator.SEARCH_RULE_ID}


## Index libres de la fenêtre `[start, start + size)` (ni scénarisés, ni imposés,
## ni porteurs d'un avis ou d'une révocation), dans l'ordre.
func _free_window(start: int, size: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in range(start, mini(start + size, day.passenger_count)):
		if get_scripted_case(i) != null or _forced.has(i) or wanted_indices.has(i) or revoked_indices.has(i):
			continue
		result.append(i)
	return result


## EV-07 : bulletin de `list_size` N° ID (un ou deux porteurs parmi les dix
## passagers suivants, après le premier ; leurres sinon).
func _publish_named_list(rule: RevokedIdRule, start: int) -> void:
	var size: int = 3
	if data != null:
		for event: StationEventDef in data.events.values():
			if event.list_label == rule.list_label and event.list_size > 0:
				size = event.list_size
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, start), STOLEN_SALT))
	var entries: Array[RevokedEntry] = []
	var window: Array = rng.shuffled(_free_window(start + 1, 10))
	var carriers: int = mini(rng.randi_range(1, 2), window.size())
	for k: int in carriers:
		var index: int = window[k]
		var generated: GeneratedCase = build_clean(index)
		if generated == null:
			continue
		var presented: Passenger = generated.case.passenger_presented
		var entry: RevokedEntry = RevokedEntry.new()
		entry.id = StringName("%s_%02d" % [rule.list_label, index])
		entry.citizen_id = presented.citizen_id
		entry.given_name = presented.given_name
		entry.family_name = presented.family_name
		entry.reason_key = "revoked_reason_%s" % rule.list_label
		entry.case_index = index
		entries.append(entry)
		_forced[index] = {"kinds": [AnomalyType.Kind.REVOKED_ID], "params": {}, "overrides": {}, "rule_id": rule.id}
	while entries.size() < size:
		entries.append(_decoy_entry(rng, StringName("%s_decoy_%d" % [rule.list_label, entries.size()]),
				"revoked_reason_%s" % rule.list_label))
	ctx.set_list(rule.list_label, entries)
	changed_lists.append(String(rule.list_label))


## N° ID sans passager (leurre d'une liste), d'une origine tirée.
func _decoy_entry(rng: SeededRng, id: StringName, reason_key: String) -> RevokedEntry:
	var faction_ids: Array[StringName] = []
	faction_ids.assign(data.factions.keys())
	faction_ids.sort()
	var faction: FactionDef = data.factions[faction_ids[rng.randi_range(0, faction_ids.size() - 1)]]
	var entry: RevokedEntry = RevokedEntry.new()
	entry.id = id
	entry.citizen_id = PassengerGenerator.make_citizen_id(rng, faction)
	if faction.name_pool != null:
		var sex: StringName = PassengerGenerator.SEXES[rng.randi_range(0, 1)]
		entry.given_name = faction.name_pool.pick_given_name(rng, sex)
		entry.family_name = faction.name_pool.pick_family_name(rng)
	entry.reason_key = reason_key
	return entry


## Garde : avis (U15) et révocations (U20) renouvelés à chaque directive — un
## porteur parmi les 5 passagers suivants (toujours si la règle est nouvelle,
## une fois sur deux sinon) et des leurres. Renvoie les porteurs choisis.
func _renew_garde_lists(start: int, fresh: Array[Rule], rng: SeededRng) -> Array[int]:
	var carriers: Array[int] = []
	var lists_rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, start), LISTS_SALT))
	var wanted_rule: Rule = _rule_of(WantedRule)
	if wanted_rule != null:
		var notices: Array[WantedNotice] = []
		var kept: Array[int] = []
		for i: int in wanted_indices:
			if i < start:
				kept.append(i)
		wanted_indices = kept
		var window: Array[int] = _free_window(start, EXERCISE_WINDOW)
		if not window.is_empty() and (fresh.has(wanted_rule) or rng.chance(0.5)):
			var index: int = window[rng.randi_range(0, window.size() - 1)]
			var generated: GeneratedCase = build_clean(index)
			if generated != null:
				var presented: Passenger = generated.case.passenger_presented
				var notice: WantedNotice = WantedNotice.new()
				notice.id = StringName("wanted_garde_%03d" % index)
				notice.given_name = presented.given_name
				notice.family_name = presented.family_name
				notice.appearance = DocumentFactory.official_photo_of(presented.appearance.without_visor())
				notice.reason_key = "wanted_generated_reason"
				notice.case_index = index
				notices.append(notice)
				wanted_indices.append(index)
				carriers.append(index)
		notices.append(_decoy_notice(lists_rng, StringName("wanted_garde_decoy_%03d" % start)))
		ctx.wanted = notices
		_dedupe_faces_from(start, carriers)
		changed_lists.append("wanted")
	var revoked_rule: RevokedIdRule = null
	for rule: Rule in day.rule_set.rules:
		var listed: RevokedIdRule = rule as RevokedIdRule
		if listed != null and (listed.list_label == &"" or listed.list_label == &"revoked"):
			revoked_rule = listed
	if revoked_rule != null:
		var entries: Array[RevokedEntry] = []
		var kept_revoked: Array[int] = []
		for i: int in revoked_indices:
			if i < start:
				kept_revoked.append(i)
		revoked_indices = kept_revoked
		var window: Array[int] = _free_window(start, EXERCISE_WINDOW)
		if not window.is_empty() and (fresh.has(revoked_rule) or rng.chance(0.5)):
			var index: int = window[rng.randi_range(0, window.size() - 1)]
			var generated: GeneratedCase = build_clean(index)
			if generated != null:
				var presented: Passenger = generated.case.passenger_presented
				var entry: RevokedEntry = RevokedEntry.new()
				entry.id = StringName("revoked_garde_%03d" % index)
				entry.citizen_id = presented.citizen_id
				entry.given_name = presented.given_name
				entry.family_name = presented.family_name
				entry.case_index = index
				entries.append(entry)
				revoked_indices.append(index)
				carriers.append(index)
		for n: int in maxi(day.revoked_decoys, 1):
			entries.append(_decoy_entry(lists_rng, StringName("revoked_garde_decoy_%03d_%d" % [start, n]), ""))
		ctx.revoked = entries
		changed_lists.append("revoked")
	return carriers


## Avis d'une personne absente de la file (visage et nom tirés).
func _decoy_notice(rng: SeededRng, id: StringName) -> WantedNotice:
	var faction_ids: Array[StringName] = []
	faction_ids.assign(day.faction_weights.keys())
	faction_ids.sort()
	var faction_id: StringName = faction_ids[rng.randi_range(0, faction_ids.size() - 1)] if not faction_ids.is_empty() else &"tyc"
	var notice: WantedNotice = WantedNotice.new()
	notice.id = id
	notice.appearance = DocumentFactory.official_photo_of(appearance_gen.generate(rng, faction_id).without_visor())
	var faction: FactionDef = data.factions.get(faction_id, null)
	if faction != null and faction.name_pool != null:
		var sex: StringName = PassengerGenerator.SEXES[rng.randi_range(0, 1)]
		notice.given_name = faction.name_pool.pick_given_name(rng, sex)
		notice.family_name = faction.name_pool.pick_family_name(rng)
	notice.reason_key = "wanted_generated_reason"
	notice.case_index = -1
	return notice


## Aucun visage à venir (hors porteurs) identique à un avis en vigueur.
func _dedupe_faces_from(start: int, carriers: Array[int]) -> void:
	for i: int in range(start, mini(roster.size(), start + EXERCISE_WINDOW * 4)):
		if carriers.has(i) or get_scripted_case(i) != null:
			continue
		var entry: AppearanceRoster.Entry = roster.get_entry(i)
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(day_seed, i), WANTED_DEDUPE_SALT))
		for notice: WantedNotice in ctx.wanted:
			var guard: int = 0
			while guard < 8 and FaceComparator.compare(notice.appearance, entry.appearance, ctx.identity_slots).is_empty():
				guard += 1
				var slot: StringName = ctx.identity_slots[rng.randi_range(0, ctx.identity_slots.size() - 1)]
				entry.appearance.traits[slot] = appearance_gen.reroll_slot(rng, entry.appearance, slot, entry.faction_id)


## Exercice garanti d'une directive de Garde (M12 §2.4) : 1 ou 2 des 5
## passagers suivants violent une règle nouvelle (cas imposé vérifié par le
## moteur) ; les autres passagers de la fenêtre ne tirent pas ses types.
func _plan_exercise(fresh: Array[Rule], start: int, carriers: Array[int], rng: SeededRng) -> void:
	var kinds: Array[AnomalyType.Kind] = []
	var needs_case: Array[Rule] = []
	for rule: Rule in fresh:
		for kind: AnomalyType.Kind in rule.get_detectable_anomalies():
			if not kinds.has(kind):
				kinds.append(kind)
		# Avis et révocations : exercés par leurs porteurs.
		if rule is WantedRule or (rule is RevokedIdRule and carriers.size() > 0):
			continue
		# M13 : R44 (fouille sur motif) n'a pas de passager « en infraction » ;
		# l'unité s'exerce par R45 (contrebande).
		if rule is ProcedureRule and (rule as ProcedureRule).procedure_id in [ProcedureRule.PROCEDURE_SEARCH_CAUSE,
				ProcedureRule.PROCEDURE_BELT_SEARCH]:
			continue
		needs_case.append(rule)
	var window: Array[int] = _free_window(start, EXERCISE_WINDOW)
	for carrier: int in carriers:
		window.erase(carrier)
	# Les cas imposés d'abord parmi les premiers passagers de la fenêtre :
	# aucun événement n'y commence (`GardeDef.event_quiet_after_directive`), la
	# règle nouvelle y est donc toujours en vigueur.
	var quiet: int = 2
	var order: Array = rng.shuffled(window.slice(0, quiet))
	order.append_array(rng.shuffled(window.slice(quiet)))
	var target: int = rng.randi_range(1, 2) if not needs_case.is_empty() else 0
	var planted: int = 0
	for raw: Variant in order:
		var index: int = raw
		if planted < target:
			var rule: Rule = needs_case[planted % needs_case.size()]
			if _plant_exercise(rule, index, rng):
				planted += 1
				continue
		if not kinds.is_empty():
			_excluded_kinds[index] = kinds.duplicate()


## Passager `index` imposé pour violer `rule` : options essayées dans l'ordre
## jusqu'à ce que le moteur cite la règle (procédures : passager concerné).
func _plant_exercise(rule: Rule, index: int, rng: SeededRng) -> bool:
	var entry: AppearanceRoster.Entry = roster.get_entry(index)
	var roster_faction: StringName = entry.faction_id
	for spec: Dictionary in _exercise_options(rule, index, rng):
		_forced[index] = spec
		# L'origine imposée est aussi celle du roster (réserve de noms, bloc ID).
		var overrides: Dictionary = spec.get("overrides", {})
		entry.faction_id = StringName(str(overrides.get(&"faction_id", roster_faction)))
		_probing = true
		var probe: GeneratedCase = _build(index, null, _kinds_of(spec), spec.get("params", {}), true)
		_probing = false
		if probe != null and probe.invariant_errors.is_empty() and probe.clean_violation_count == 0 \
				and _exercises(rule, spec, probe):
			_clean_ids.erase(index)
			return true
		_forced.erase(index)
	entry.faction_id = roster_faction
	return false


static func _kinds_of(spec: Dictionary) -> Array[AnomalyType.Kind]:
	var kinds: Array[AnomalyType.Kind] = []
	kinds.assign(spec.get("kinds", []))
	return kinds


## Le cas imposé exerce la règle : violation citée, ou procédure applicable
## (R06 : visière baissée ; R08 : ressortissant de Tycho).
static func _exercises(rule: Rule, spec: Dictionary, probe: GeneratedCase) -> bool:
	if rule is ProcedureRule:
		var procedure: ProcedureRule = rule
		if procedure.procedure_id == ProcedureRule.PROCEDURE_FACE_UNCOVERED:
			return probe.visor_down
		return procedure.applies_to(probe.case)
	if _kinds_of(spec).is_empty():
		return false
	for violation: Violation in probe.key.expected_violations:
		if violation.rule_id == rule.id:
			return true
	return false


## Options d'exercice d'une règle (types détectables, origine, classe, motif,
## document visé), de la plus directe à la plus large.
func _exercise_options(rule: Rule, index: int, rng: SeededRng) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var roster_faction: StringName = roster.get_entry(index).faction_id
	# Ressortissant ordinaire (ni Né-Halcyon dispensé de permis, ni Tharsien
	# refusé hors DIPLOMATIQUE quand R19 est active).
	var not_hal: StringName = roster_faction if roster_faction != &"hal" and roster_faction != &"thr" else &"tyc"
	if rule is ProcedureRule:
		var procedure: ProcedureRule = rule
		if procedure.procedure_id == ProcedureRule.PROCEDURE_FACE_UNCOVERED:
			options.append({"kinds": [], "params": {}, "overrides": {}, "visor": true})
		else:
			var faction: StringName = procedure.applies_to_faction_ids[0] if not procedure.applies_to_faction_ids.is_empty() else not_hal
			options.append({"kinds": [], "params": {}, "overrides": {&"faction_id": faction}})
		return options
	var overrides: Dictionary = {}
	var document_id: StringName = &""
	if rule is RequireDocumentRule:
		var require: RequireDocumentRule = rule
		document_id = require.document_id
		var faction: StringName = not_hal
		if not require.applies_to_faction_ids.is_empty():
			faction = require.applies_to_faction_ids[0]
		elif require.exempt_faction_ids.is_empty():
			faction = roster_faction if roster_faction != &"thr" else not_hal
		overrides[&"faction_id"] = faction
		if not require.applies_to_classes.is_empty():
			overrides[&"citizen_class"] = require.applies_to_classes[0]
		if not require.applies_to_purposes.is_empty():
			overrides[&"purpose"] = require.applies_to_purposes[0]
	elif rule is DocumentNotExpiredRule:
		var expiry: DocumentNotExpiredRule = rule
		document_id = expiry.document_id
		overrides[&"faction_id"] = not_hal if document_id == &"entry_permit" else roster_faction
		if expiry.field_path == &"firmware_date":
			overrides[&"implants"] = PackedStringArray(["NX-12"])
	elif rule is FactionBannedRule:
		var banned: FactionBannedRule = rule
		overrides[&"faction_id"] = banned.banned_faction_ids[0] if not banned.banned_faction_ids.is_empty() else not_hal
	elif rule is PurposeConsistentRule or rule is ContractConsistentRule:
		overrides[&"faction_id"] = &"tyc" if rule is ContractConsistentRule else not_hal
		if rule is ContractConsistentRule:
			overrides[&"purpose"] = Passenger.PURPOSE_WORK
	elif rule is BannedImplantsRule or rule is ImplantsDeclaredRule:
		overrides[&"faction_id"] = roster_faction
	elif rule is StatementsConsistentRule:
		# M13 : une fausse déclaration se compare au permis (pas un Né-Halcyon).
		overrides[&"faction_id"] = not_hal
	var params: Dictionary = {}
	if document_id != &"":
		params[&"document_id"] = document_id
	var kinds: Array = rng.shuffled(rule.get_detectable_anomalies())
	for kind: AnomalyType.Kind in kinds:
		if kind == AnomalyType.Kind.WANTED_PERSON or kind == AnomalyType.Kind.REVOKED_ID:
			continue
		options.append({"kinds": [kind], "params": params.duplicate(), "overrides": overrides.duplicate(), "rule_id": rule.id})
		# Repli : sans les surcharges (origine du roster).
		options.append({"kinds": [kind], "params": params.duplicate(), "overrides": {}, "rule_id": rule.id})
	return options
