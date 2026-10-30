## Joueur simulé face aux mécaniques de M13 (docs/M13.md §4.2, §4.5 ; D-151 ;
## B78) — pur, statique ; utilisé par le `DaySimulator` et `tools/balance_sim.gd`.
##
## - `strip()` : jour « 0.12 » (règles R43 → R47, anomalies 24 → 27, cas
##   SC-104 → SC-111, compensation de temps et 3ᵉ avertissement retirés) pour
##   `balance_sim --m13=off|compare` ;
## - `play_case()` : ce que fait le joueur d'un `SimProfile` sur un cas —
##   question de motif (`ask_rate`, Tycho toujours : R08), fausse déclaration
##   relevée (`statement_catch`), indice remarqué (`cue_spot`), fouille selon
##   `search_policy` / `search_zones` (motif figé MF-1 → MF-5, sinon aucun),
##   objets trouvés, et le **temps** dépensé (`InterrogationTiming`, AG-01,
##   AG-03 ; gains d'AG-02, AG-05, AG-06) ;
## - `adjust_verdict()` : un verdict « juste » ne peut pas reposer sur une
##   violation que le joueur n'a pas vue (mensonge sans question, objet sans
##   fouille) : il approuve alors (ENTRÉE IRRÉGULIÈRE).
## Jamais de `CaseKey` pour décider de fouiller : seulement ce qui est visible
## (indice, réponse, discordance) — la clé ne sert qu'à savoir ce qui est trouvé.
class_name M13Sim
extends RefCounted

const RULE_IDS: Array[StringName] = [&"r_statements", &"r_search_cause", &"r_contraband", &"r_weapons_detain",
		&"r_belt_search"]
const KINDS: Array[AnomalyType.Kind] = [AnomalyType.Kind.STATEMENT_MISMATCH, AnomalyType.Kind.CONTRABAND,
		AnomalyType.Kind.CONCEALED_IMPLANT, AnomalyType.Kind.CONCEALED_WEAPON]
const SCRIPTED_IDS: Array[StringName] = [&"sc_104", &"sc_105", &"sc_106", &"sc_107", &"sc_108", &"sc_109", &"sc_110",
		&"sc_111"]
## Compensation de M13 §4.2 (`duration_sec`, retirée par `strip`) — seule
## source, lue par `tools/build_data_m13.gd` : J4–J7, J8–J20, J21–J30
## (finition M13 : +15 / +20 / +10 s ; lot B : +15 / +25 / +25 s).
const EXTRA_SECONDS_EARLY: float = 15.0
const EXTRA_SECONDS_LATE: float = 20.0
const EXTRA_SECONDS_ACT3: float = 10.0
const ACT3_FIRST_DAY: int = 21
const FREE_CITATION_DAYS: Array[int] = [4, 8]
const PURPOSE_MISMATCH_CUT: Dictionary[int, float] = {4: 0.06, 5: 0.02}
## Coût d'une question avant M13 (durée d'un sous-titre, ≈ 2,5 s).
const LEGACY_QUESTION_SEC: float = 2.5
## Gains de lecture des améliorations (M13 §3.2 : 1 à 2 s par cas).
const GAIN_WOOD_LAMP: float = 1.0
const GAIN_BOOK: float = 1.0
const GAIN_MONITOR: float = 1.5
const WOOD_LAMP_FROM_DAY: int = 9
## Part des menteurs d'origine dont la question d'origine est aussi posée.
const ORIGIN_QUESTION_RATE: float = 0.6
## Part des confrontations après une déclaration contradictoire relevée.
const CONFRONT_RATE: float = 0.3
## Seconde zone scannée en fouille ciblée.
const SECOND_ZONE_RATE: float = 0.5
const SALT: String = "m13_player"
const R08_ID: StringName = &"r_tycho_interview"


## Secondes ajoutées au shift du jour `day_number` par M13 (0 avant le J4).
static func extra_seconds(day_number: int) -> float:
	if day_number < 4:
		return 0.0
	if day_number <= 7:
		return EXTRA_SECONDS_EARLY
	return EXTRA_SECONDS_LATE if day_number < ACT3_FIRST_DAY else EXTRA_SECONDS_ACT3


## Copie de shift du jour sans M13 (« 0.12 »).
static func strip(day: DayDef) -> DayDef:
	var copy: DayDef = day.make_shift_copy()
	var rules: Array[Rule] = []
	for rule: Rule in copy.rule_set.rules:
		if rule != null and not RULE_IDS.has(rule.id):
			rules.append(rule)
	copy.rule_set.rules = rules
	var new_ids: Array[StringName] = []
	for id: StringName in copy.rule_set.new_rule_ids:
		if not RULE_IDS.has(id):
			new_ids.append(id)
	copy.rule_set.new_rule_ids = new_ids
	var weights: Dictionary[AnomalyType.Kind, float] = {}
	for kind: AnomalyType.Kind in day.anomaly_weights:
		if not KINDS.has(kind):
			weights[kind] = day.anomaly_weights[kind]
	if PURPOSE_MISMATCH_CUT.has(day.day_number) and weights.has(AnomalyType.Kind.PURPOSE_MISMATCH):
		weights[AnomalyType.Kind.PURPOSE_MISMATCH] += PURPOSE_MISMATCH_CUT[day.day_number]
	copy.anomaly_weights = weights
	var scripted: Array[ScriptedCaseDef] = []
	for case_def: ScriptedCaseDef in day.scripted_cases:
		if case_def != null and not SCRIPTED_IDS.has(case_def.id):
			scripted.append(case_def)
	copy.scripted_cases = scripted
	copy.statement_topic_weights = {}
	copy.search_cue_noise_rate = 0.0
	if day.mode == DayDef.MODE_CAMPAIGN and day.day_number >= 4:
		copy.duration_sec = day.duration_sec - extra_seconds(day.day_number)
		if FREE_CITATION_DAYS.has(day.day_number):
			copy.free_citations_per_day = 2
	return copy


## Ce que fait le joueur sur un cas. Renvoie `{seconds, asked, searched,
## motive, zones, saw_lie, found}` : `seconds` = temps ajouté par M13 (questions,
## confrontation, fouille, moins les gains de lecture) ; `saw_lie` = fausse
## déclaration relevée ; `found` = objets interdits ou implants non déclarés
## révélés (zones scannées).
static func play_case(case: Case, key: CaseKey, profile: SimProfile, rng: SeededRng, rule_set: RuleSet, day_number: int,
		owned: Dictionary[StringName, Variant], timing: InterrogationTiming) -> Dictionary:
	var result: Dictionary = {"seconds": 0.0, "asked": false, "searched": false, "motive": SearchLayout.MOTIVE_NONE,
			"zones": [] as Array[StringName], "saw_lie": false, "found": false}
	var hygiaphone: bool = UpgradeDef.owns(owned, UpgradeDef.ID_HYGIAPHONE)
	var calibrated: bool = UpgradeDef.owns(owned, UpgradeDef.ID_CALIBRATED_GATE)
	var statements_on: bool = StatementsConsistentRule.active_in(rule_set) != null
	var tycho: bool = Rule.visible_origin(case) == &"tyc" and rule_set.has_rule(R08_ID)
	var asked: bool = tycho or rng.chance(profile.ask_rate)
	result["asked"] = asked
	var seconds: float = 0.0
	if asked:
		var corrected: bool = false
		for statement: Statement in case.statements:
			corrected = corrected or (statement.id == Statement.ID_STAY and statement.is_corrected())
		seconds += timing.question_cost(hygiaphone, false, corrected) if statements_on else LEGACY_QUESTION_SEC
		var lie_topic: StringName = _lie_topic(key)
		if lie_topic != &"":
			var heard: bool = lie_topic != Statement.ID_ORIGIN or rng.chance(ORIGIN_QUESTION_RATE)
			if lie_topic == Statement.ID_ORIGIN and heard:
				seconds += timing.question_cost(hygiaphone)
			if heard and rng.chance(profile.statement_catch_rate()):
				result["saw_lie"] = true
				if rng.chance(CONFRONT_RATE):
					seconds += timing.confront_cost(hygiaphone)
	# Fouille (R44 active : portique en service).
	if SearchGenerator.search_enabled(rule_set) and profile.search_policy != SimProfile.SEARCH_NEVER:
		var cue_seen: bool = not case.search_cues.is_empty() and rng.chance(profile.cue_spot)
		var mandatory: bool = false
		for rule: Rule in rule_set.rules:
			var procedure: ProcedureRule = rule as ProcedureRule
			mandatory = mandatory or (procedure != null and procedure.requires_search(case))
		var discord: bool = bool(result["saw_lie"])
		var motive: StringName = SearchLayout.MOTIVE_NONE
		if discord:
			motive = SearchLayout.MOTIVE_DISCORD
		elif cue_seen:
			motive = SearchLayout.MOTIVE_CUE
		elif mandatory:
			motive = SearchLayout.MOTIVE_MANDATORY
		var search: bool = false
		match profile.search_policy:
			SimProfile.SEARCH_CUE:
				search = cue_seen or mandatory
			SimProfile.SEARCH_CUE_DISCORD:
				search = cue_seen or mandatory or discord
			SimProfile.SEARCH_ALWAYS:
				search = true
		if search:
			result["searched"] = true
			result["motive"] = motive
			var zones: Array[StringName] = _zones(case, profile, rng, cue_seen)
			result["zones"] = zones
			if zones.size() == SearchLayout.ZONES.size():
				seconds += timing.full_search_cost(calibrated)
			else:
				seconds += timing.activation_cost(calibrated) + timing.zone_cost(calibrated) * zones.size()
			if case.search_layout != null:
				for zone: StringName in zones:
					case.search_layout.scan(zone)
				result["found"] = case.search_found_forbidden()
	# Gains de lecture des améliorations.
	if UpgradeDef.owns(owned, UpgradeDef.ID_WOOD_LAMP) and day_number >= WOOD_LAMP_FROM_DAY:
		seconds -= GAIN_WOOD_LAMP
	if UpgradeDef.owns(owned, UpgradeDef.ID_ANNOTATED_BOOK):
		seconds -= GAIN_BOOK
	if UpgradeDef.owns(owned, UpgradeDef.ID_QUEUE_MONITOR):
		seconds -= GAIN_MONITOR
	result["seconds"] = seconds
	return result


## Sujet de la fausse déclaration du cas (vide sinon).
static func _lie_topic(key: CaseKey) -> StringName:
	for anomaly: Anomaly in key.anomalies:
		if anomaly.type == AnomalyType.Kind.STATEMENT_MISMATCH:
			return anomaly.field_id
	return &""


## Zones scannées : TOUT SCANNER, ou la zone de l'indice (sinon une zone au
## hasard) puis une autre à 50 %.
static func _zones(case: Case, profile: SimProfile, rng: SeededRng, cue_seen: bool) -> Array[StringName]:
	var zones: Array[StringName] = []
	if profile.search_zones == SimProfile.ZONES_FULL:
		zones.assign(SearchLayout.ZONES)
		return zones
	var first: StringName = SearchLayout.zone_of_cue(case.search_cues[0]) if cue_seen \
			else SearchLayout.ZONES[rng.randi_range(0, SearchLayout.ZONES.size() - 1)]
	zones.append(first)
	if rng.chance(SECOND_ZONE_RATE):
		var others: Array[StringName] = []
		for zone: StringName in SearchLayout.ZONES:
			if zone != first:
				others.append(zone)
		zones.append(others[rng.randi_range(0, others.size() - 1)])
	return zones


## Une violation « vue » par le joueur : mensonge relevé ou objet révélé ; les
## autres violations (papiers) relèvent du modèle de précision habituel.
static func is_observed(violation: Violation, played: Dictionary, case: Case) -> bool:
	if violation.rule_id == &"r_statements":
		return bool(played.get("saw_lie", false))
	if not violation.refs.is_empty() and violation.refs[0].is_scan():
		return case.is_scan_item_revealed(violation.refs[0])
	return true


## Verdict d'un joueur qui « juge juste » sur ce qu'il a vu : sans aucune
## violation observée, il approuve ; une DÉTENTION n'est tamponnée que si une
## violation de sévérité 3 a été vue.
static func adjust_verdict(kind: VerdictKind.Kind, key: CaseKey, played: Dictionary, case: Case) -> VerdictKind.Kind:
	if kind == VerdictKind.Kind.APPROVE or key.expected_violations.is_empty() or kind != key.expected_verdict:
		return kind
	var seen: bool = false
	var seen_severe: bool = false
	for violation: Violation in key.expected_violations:
		if is_observed(violation, played, case):
			seen = true
			seen_severe = seen_severe or violation.severity >= RuleEngine.DETAIN_SEVERITY
	if not seen:
		return VerdictKind.Kind.APPROVE
	if kind == VerdictKind.Kind.DETAIN and not seen_severe:
		return VerdictKind.Kind.DENY
	return kind
