## Contenu de l'Acte III pour `tools/build_data.gd` (D-029) — fabriques
## statiques, chargées par `preload` (pas de `class_name` : outil).
##
## Source : `docs/ACT3.md` (§1.2 soirée pivot du J20 et carte de fin d'acte,
## §2 progression J21–J30, R32–R37, §4 SC-51 → SC-82, §5 briefings / soirées /
## annonces, §6 barème) et les décisions D-086 → D-089. Les textes sont des
## clés de `data/i18n/fr.csv`. Le verdict attendu des cas reste calculé par le
## moteur (D-005) : les commentaires « attendu » sont l'intention, vérifiée
## par les tests (`tests/unit/test_act3_rules.gd`).
extends RefCounted

const K := AnomalyType.Kind
const KEEP := SlippedItem.Decision.KEEP
const RETURN := SlippedItem.Decision.RETURN
const REPORT := SlippedItem.Decision.REPORT
const CAT := Rule.RuleCategory

## Voix des briefings (`BriefingContent.Voice`) : aucune voix nouvelle (§5).
const V_CONSORTIUM: int = 0
const V_MENTOR: int = 1
const V_FAMILY: int = 2
const V_LUCIOLES: int = 3
const V_INSPECTION: int = 4
const V_COMMISSION: int = 5
const V_BRULANTS: int = 6

## Visages fixés (`ScriptedCaseDef.fixed_appearance_seed`).
const OKONKWO_SEED: int = 0x0C0A_2141
const DORA_SEED: int = 0x0D0A_2122
## N° ID de l'agent·e du Guichet 04 (SC-82a : Dora le met comme répondant ;
## un agent ne se porte pas répondant à sa propre vitre, R34). Proposé.
const AGENT_ID: String = "HG-1404-AGNT"
## Classe (carte) des membres du réseau des répondants (SC-81b), reprise de
## leur première apparition.
const NETWORK_CLASSES: Dictionary[StringName, StringName] = {&"lindgren": &"C-3", &"sato": &"C-3", &"valentin": &"C-2",
		&"kerr": &"C-2", &"beaumont": &"C-1"}
## Code employeur de l'Arbitrage de Continuité (LORE à compléter, §3.7).
const EMPLOYER_AR: String = "Arbitrage de Continuité"

const TABS_ACT2: PackedStringArray = ["origins", "implants", "symbols", "seals", "wanted", "employers", "vessels", "revoked"]
## Poids des origines (§2.3) TYC/HAL/TER/CER/THR/DRV.
const F_J21: Dictionary[StringName, float] = {&"tyc": 0.28, &"hal": 0.18, &"ter": 0.21, &"cer": 0.14, &"thr": 0.13, &"drv": 0.06}
const F_J25: Dictionary[StringName, float] = {&"tyc": 0.32, &"hal": 0.17, &"ter": 0.19, &"cer": 0.13, &"thr": 0.12, &"drv": 0.07}
const F_J28: Dictionary[StringName, float] = {&"tyc": 0.34, &"hal": 0.18, &"ter": 0.19, &"cer": 0.13, &"thr": 0.11, &"drv": 0.05}
const F_J30: Dictionary[StringName, float] = {&"tyc": 0.40, &"hal": 0.18, &"ter": 0.16, &"cer": 0.12, &"thr": 0.10, &"drv": 0.04}

## Ordre des types de `anomaly_weights` (docs/ACT3.md §2.2, colonnes J21 → J30).
## `UNREGISTERED_VESSEL` : poids **conditionnel** (DRV porteurs d'un laissez-passer)
## gardé à 0,20 comme à l'Acte II (QA-026), au lieu des 0,02–0,03 du tableau ;
## `REVOKED_ID` et `WANTED_PERSON` viennent des listes du jour.
const WEIGHT_KINDS: Array[AnomalyType.Kind] = [K.EXPIRED_DOCUMENT, K.MISSING_DOCUMENT, K.PORTRAIT_MISMATCH,
		K.ID_MISMATCH, K.NAME_MISMATCH, K.ORIGIN_ID_MISMATCH, K.PURPOSE_MISMATCH, K.WRONG_ISSUER, K.BIOSCAN_UNFIT,
		K.UNDECLARED_IMPLANT, K.BANNED_IMPLANT, K.IMPOSTOR_LOOKALIKE, K.RELATIVE_DOCUMENTS, K.BANNED_FACTION,
		K.INVALID_SEAL, K.MRZ_MISMATCH, K.WANTED_PERSON, K.CONTRACT_MISMATCH, K.UNREGISTERED_VESSEL,
		K.OUTDATED_FIRMWARE, K.REVOKED_ID, K.SPONSOR_MISMATCH, K.FORGED_SUMMONS, K.SUSPENDED_CONTRACT]
const WEIGHTS: Dictionary[int, Array] = {
	21: [0.12, 0.05, 0.03, 0.05, 0.05, 0.04, 0.05, 0.04, 0.04, 0.06, 0.05, 0.07, 0.06, 0.07, 0.06, 0.06, 0.06, 0.06, 0.20, 0.05, 0, 0, 0, 0],
	22: [0.10, 0.05, 0.03, 0.05, 0.05, 0.04, 0.05, 0.04, 0.04, 0.06, 0.05, 0.07, 0.06, 0.07, 0.06, 0.06, 0.06, 0.06, 0.20, 0.07, 0, 0, 0, 0],
	23: [0.10, 0.06, 0.04, 0.06, 0.06, 0.05, 0.06, 0, 0, 0.07, 0.06, 0.08, 0.07, 0.07, 0.06, 0.06, 0.06, 0.06, 0.20, 0.05, 0, 0, 0, 0],
	24: [0.08, 0.05, 0.03, 0.05, 0.05, 0.04, 0.05, 0, 0, 0.06, 0.05, 0.07, 0.06, 0.06, 0.05, 0.05, 0.05, 0.05, 0.20, 0.04, 0, 0.18, 0, 0],
	25: [0.07, 0.05, 0.03, 0.04, 0.04, 0.04, 0.05, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.05, 0.05, 0.20, 0.04, 0, 0.10, 0, 0.15],
	26: [0.07, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.05, 0.04, 0.20, 0.04, 0, 0.08, 0.15, 0.06],
	27: [0.07, 0.05, 0.03, 0.04, 0.04, 0.04, 0.05, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.06, 0.05, 0.20, 0.04, 0, 0.08, 0.08, 0.08],
	28: [0.06, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.16, 0.05, 0.04, 0.05, 0.04, 0.20, 0.04, 0, 0.08, 0.06, 0.04],
	29: [0.08, 0.05, 0.03, 0.04, 0.04, 0.04, 0.05, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.10, 0.05, 0.05, 0.05, 0.04, 0.20, 0.04, 0, 0.08, 0.06, 0.05],
	30: [0.05, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0, 0, 0.05, 0.04, 0.06, 0.05, 0.13, 0.04, 0.04, 0.10, 0.04, 0.20, 0.03, 0, 0.09, 0.06, 0.04],
}
## Jours de règle nouvelle : 3ᵉ avertissement gratuit (§6.1, D-089).
const NEW_RULE_DAYS: Array[int] = [21, 22, 24, 25, 26, 28]


# ---------------------------------------------------------------------------
# Dates (J1 = 13.03.2187)
# ---------------------------------------------------------------------------

static func date_of(day_number: int) -> int:
	return GameDate.from_ymd(2187, 3, 13) + day_number - 1


static func ymd(month: int, day: int) -> int:
	return GameDate.from_ymd(2187, month, day)


# ---------------------------------------------------------------------------
# Barème (docs/ACT3.md §6.1, B48 ; D-089)
# ---------------------------------------------------------------------------

static func configure_economy(e: EconomyDef) -> void:
	e.act3_pivot_day = 20
	e.act3_pivot_bonus_flag = &"purge_demoted"
	e.recall_per_overrun = 5
	e.recall_cap = 30
	e.loan_amount = 30
	e.loan_repay = 35
	e.loan_day = 27
	e.loan_balance_below = 40
	e.vitres_fund = 15
	e.vitres_fund_balance_below = 20
	e.contribution_rate = 0.20
	e.contribution_floor = 60
	e.contribution_day = 25
	e.head_bonus = 10
	e.ring_d_rent = 30
	e.move_cost = 20
	e.scab_income = 10
	e.scab_first_day = 24
	e.scab_last_day = 29
	e.vanne_ration = 1
	e.act3_first_day = 21
	e.act3_last_evening = 29
	e.deposition_arrest_score = 7
	e.deposition_blame_score = 4
	e.deposition_retention = 30
	e.double_game3_threshold = 10
	e.air3_trust_threshold = 10
	e.glory3_loyalty_threshold = 10
	e.strike3_solidarity_threshold = 5
	# Mesuré (balance_sim, `passeur`) : 6 → 5, le quota du J30 (3) borne le pont.
	e.pont_threshold = 5
	e.verite_threshold = 3
	e.registre3_threshold = 5
	e.exit3_min_present = 2
	e.noa_fine = 10
	e.dora_transport = 5
	e.tycho_fund = 10
	e.exit3_tycho_cost = 30
	e.exit3_drift_cost = 70


# ---------------------------------------------------------------------------
# Règles R32 → R37 (docs/ACT3.md §2.4, B40)
# ---------------------------------------------------------------------------

## Règles de l'Acte III (sauvegardées par `build_data.gd`).
static func build_rules() -> Array[Rule]:
	var r32: ProrogationRule = ProrogationRule.new()
	r32.window_start = ymd(3, 22)
	r32.window_end = ymd(4, 1)
	r32.extended_until = ymd(4, 10)
	var r33: ReinstatementRule = ReinstatementRule.new()
	var r34: SponsorRule = SponsorRule.new()
	r34.summons_exempt = true
	var r35: ContractSuspendedRule = ContractSuspendedRule.new()
	r35.summons_exempt = true
	var r36: SummonsRule = SummonsRule.new()
	var r37: FactionBannedRule = FactionBannedRule.new()
	r37.banned_faction_ids = [&"tyc"]
	r37.exempt_purposes = []
	r37.exempt_if_sponsored = true
	r37.summons_exempt = true
	return [
		_rule(r32, &"r_prorogation", CAT.DOCUMENTS, 2),
		_rule(r33, &"r_reinstated", CAT.IDENTITY, 2),
		_rule(r34, &"r_sponsor", CAT.DOCUMENTS, 2),
		_rule(r35, &"r_tycho_lockout", CAT.DOCUMENTS, 2),
		_rule(r36, &"r_summons", CAT.DOCUMENTS, 2),
		_rule(r37, &"r_tycho_closed", CAT.FACTION, 2),
	]


## Exemptions déclaratives de R36 sur les règles existantes (R19, R23, R30,
## R31) ; R31 est aussi levée par un répondant valide (SC-61, D-091 proposé).
## Sans effet avant le J24 / J26 (aucune règle de répondant ni convocation).
static func configure_existing_rules(rules: Dictionary[StringName, Rule]) -> void:
	for id: StringName in [&"r_tharsis_banned", &"r_air_quota", &"r_revoked_ids", &"r_ter_closed"]:
		rules[id].summons_exempt = true
	(rules[&"r_ter_closed"] as FactionBannedRule).exempt_if_sponsored = true
	# SC-72 : le Basse-Marée est désarmé à la fermeture du quai 6 (02.04).
	(rules[&"r_drift_pass"] as DriftPassRule).retired_vessels = {"BASSE-MARÉE": ymd(4, 2)}


static func _rule(rule: Rule, id: StringName, category: Rule.RuleCategory, severity: int) -> Rule:
	rule.id = id
	rule.title_key = "%s_title" % id
	rule.rulebook_text_key = "%s_text" % id
	rule.category = category
	rule.severity = severity
	return rule


## RuleSets J21 → J30 : liste explicite, **non cumulative** (M1 « Retour aux
## quais ») — `j20` : identifiants actifs au J20.
static func build_rule_sets(rules: Dictionary[StringName, Rule], j20: Array[StringName]) -> Array[RuleSet]:
	var bioscan: Array[StringName] = [&"r_bioscan_required", &"r_bioscan_valid", &"r_bioscan_issuer", &"r_bioscan_fit"]
	var sets: Array[RuleSet] = []
	var ids: Array[StringName] = j20.duplicate()
	var suspended: Dictionary[StringName, String] = {&"r_air_quota": "rb_suspended_quota"}
	for n: int in range(21, 31):
		var added: Array[StringName] = []
		var retired: Array[StringName] = []
		var retired_key: String = ""
		match n:
			21:
				retired = [&"r_curfew"]
				retired_key = "rb_retired_curfew"
				added = [&"r_prorogation"]
			22:
				added = [&"r_reinstated"]
			23:
				retired = bioscan
				retired_key = "rb_retired_quais"
			24:
				added = [&"r_sponsor"]
			25:
				added = [&"r_tycho_lockout"]
			26:
				added = [&"r_summons"]
			28:
				added = [&"r_tycho_closed"]
		for id: StringName in retired:
			ids.erase(id)
		ids.append_array(added)
		var rs: RuleSet = RuleSet.new()
		rs.id = StringName("rs_day%02d" % n)
		for id: StringName in ids:
			rs.rules.append(rules[id])
		rs.new_rule_ids = added.duplicate()
		rs.required_document_ids = rs.compute_required_document_ids()
		for id: StringName in retired:
			rs.retired_rules.append(rules[id])
			rs.retired_note_keys[id] = retired_key
		if n <= 26:
			rs.rule_note_keys = suspended.duplicate()
		sets.append(rs)
	return sets


# ---------------------------------------------------------------------------
# J20 — soirée pivot « La Nuit du 1ᵉʳ avril » (docs/ACT3.md §1.2, §5.3, D-086)
# ---------------------------------------------------------------------------

## Le J20 gagne une soirée (le shift est inchangé).
static func extend_day20(d: DayDef) -> void:
	d.has_evening = true
	d.evening_events = pivot_events()


static func pivot_events() -> Array[EveningEventDef]:
	var events: Array[EveningEventDef] = []
	# 0. Carte de fin d'acte : climat d'entrée (prévisualisé dans le contexte
	#    du soir, `EveningService.evening_context`), posé par la lettre.
	var cards: Array[Array] = [
		["brulants", _cond([&"climate_vanne", &"vanne2_brulants"], []), "end2_f5_title",
				{&"climate_vanne": 0, &"vanne2_brulants": 0, &"suspicion": 1}],
		["vanne", _cond([&"climate_vanne"], [&"vanne2_brulants"]), "end2_f5_title", {&"climate_vanne": 0}],
		["vitres", _all([&"climate_vitres"]), "end2_f9_title", {&"climate_vitres": 0, &"solidarite": 1}],
		["registre", _all([&"climate_registre"]), "end2_f8_title", {&"climate_registre": 0}],
		["promu", _all([&"climate_promu"]), "end2_f4_title", {&"climate_promu": 0}],
		["statu_quo", _all([&"climate_statu_quo"]), "end2_f7_title", {&"climate_statu_quo": 0}],
	]
	for spec: Array in cards:
		var climate: String = spec[0]
		var flag_values: Dictionary = spec[3]
		var flags: Dictionary[StringName, int] = {}
		flags.assign(flag_values)
		var condition: FlagCondition = spec[1]
		var card: EveningEventDef = _letter(StringName("d20_card_%s" % climate), 0, condition, "act2_card_%s_l1" % climate, flags)
		card.title_key = str(spec[2])
		card.extra_keys = [ConditionalKey.make("act2_card_%s_l2" % climate)]
		events.append(card)
	# 1. La Nuit du 1ᵉʳ avril (lettre, variante selon le climat).
	var night: EveningEventDef = _letter(&"d20_night", 1, null, "evt_d20_night_text_statu_quo", {})
	night.title_key = "evt_d20_night_title"
	night.text_variants = [
		ConditionalKey.make("evt_d20_night_text_brulants", _all([&"climate_vanne", &"vanne2_brulants"])),
		ConditionalKey.make("evt_d20_night_text_vanne", _all([&"climate_vanne"])),
		ConditionalKey.make("evt_d20_night_text_vitres", _all([&"climate_vitres"])),
		ConditionalKey.make("evt_d20_night_text_registre", _all([&"climate_registre"])),
		ConditionalKey.make("evt_d20_night_text_promu", _all([&"climate_promu"])),
	]
	events.append(night)
	# 3. Double jeu : cible de l'Enquête (ne termine plus la partie).
	var double: EveningEventDef = _letter(&"d20_double", 3, null, "evt_d20_double_text", {&"enquete_cible": 0})
	double.economy_gauges_min = {&"lucioles_trust": &"double_game2_threshold", &"loyalty": &"double_game2_threshold"}
	events.append(double)
	# 4. Le sort de la figure finale.
	var held: EveningEventDef = _letter(&"d20_ilan_detained", 4, _all([&"ilan_detained_final"]), "evt_d20_ilan_detained", {})
	held.household = EveningOptionDef.HOUSEHOLD_ILAN_DETAINED
	var soute: EveningEventDef = _letter(&"d20_ilan_soute", 4, _all([&"ilan_joined_soute", &"final2_passed", &"climate_vanne"]),
			"evt_d20_ilan_soute", {&"ilan_soute3": 0})
	var back_condition: FlagCondition = _cond([&"ilan_joined_soute"], [&"ilan_detained_final"])
	back_condition.any_of.assign([_cond([], [&"final2_passed"]), _cond([], [&"climate_vanne"])])
	var back: EveningEventDef = _letter(&"d20_ilan_back", 4, back_condition, "evt_d20_ilan_back", {})
	back.household = EveningOptionDef.HOUSEHOLD_ILAN_HOME
	var mira: EveningEventDef = _letter(&"d20_mira_detained", 4, _cond([&"final2_detained"], [&"ilan_joined_soute"]),
			"evt_d20_mira_detained", {&"mira_detained2": 0})
	events.append_array([held, soute, back, mira])
	# 5. Un bureau à l'Anneau D (climat Promu·e).
	var flat: EveningEventDef = _event(&"d20_flat", EveningEventDef.Kind.CHOICE, 5, _all([&"climate_promu"]), "evt_d20_flat")
	flat.options = [_option(&"move", "evt_d20_flat", 20, 0, {&"moved_ring_d": 0}, 1),
			_option(&"stay", "evt_d20_flat", 0, 0, {}, 0)]
	events.append(flat)
	# 6. Quai 6, lundi 05:00 : « Embarquer » termine la campagne (F6, D-086).
	var drift: EveningEventDef = _event(&"d20_drift", EveningEventDef.Kind.CHOICE, 6,
			_cond([&"drift2_passes_bought"], [&"final2_detained"]), "evt_d20_drift")
	var board: EveningOptionDef = _option(&"board", "evt_d20_drift", 0, 0, {&"drift2_boarded": 0}, -1)
	board.ends_campaign = EndingService.F6_DRIFT
	drift.options = [board, _option(&"stay", "evt_d20_drift", 0, 30, {&"drift2_stayed": 0}, 0)]
	var refused: EveningEventDef = _letter(&"d20_drift_refused", 6, _all([&"drift2_passes_bought", &"final2_detained"]),
			"evt_d20_drift_text_refused", {&"drift2_stayed": 0})
	refused.gain = 30
	events.append_array([drift, refused])
	return events


# ---------------------------------------------------------------------------
# J21–J30
# ---------------------------------------------------------------------------

## `sets[n - 21]` = RuleSet du jour n.
static func build_days(sets: Array[RuleSet]) -> Array[DayDef]:
	return [_day21(sets[0]), _day22(sets[1]), _day23(sets[2]), _day24(sets[3]), _day25(sets[4]),
			_day26(sets[5]), _day27(sets[6]), _day28(sets[7]), _day29(sets[8]), _day30(sets[9])]


static func _act3_day(n: int, rule_set: RuleSet, duration: float, count: int, count_weights: Array[float],
		factions: Dictionary[StringName, float], noise: float, luciole: float, quota: int) -> DayDef:
	var d: DayDef = DayDef.new()
	d.day_number = n
	d.game_date = date_of(n)
	d.rule_set = rule_set
	d.duration_sec = duration
	d.passenger_count = count
	d.anomaly_count_weights = PackedFloat32Array(count_weights)
	var weights: Array = WEIGHTS[n]
	for i: int in WEIGHT_KINDS.size():
		var w: float = weights[i]
		if w > 0.0 and rule_set.can_detect(WEIGHT_KINDS[i]):
			d.anomaly_weights[WEIGHT_KINDS[i]] = w
	d.intro_text_key = "day%02d_intro" % n
	d.credit_per_correct = 5
	d.penalty_per_error = 5
	d.faction_weights = factions.duplicate()
	d.visor_down_rate = 0.20
	d.legit_noise_rate = noise
	d.bribe_rate = 0.05
	d.luciole_rate = luciole
	d.free_citations_per_day = 3 if NEW_RULE_DAYS.has(n) else 2
	d.penalty_escalated = 10
	d.detain_enabled = true
	d.has_evening = n < 30
	d.bribe_amounts = Vector2i(20, 30)
	d.air_quota = quota
	d.luciole_trust_on_breach = false
	d.focus_documents = [&"asylum"]
	d.asylum_class_rate = 0.30
	var tabs: PackedStringArray = TABS_ACT2.duplicate()
	if n >= 24:
		tabs.append("ledger")
	if n >= 26:
		tabs.append("summons")
	d.rulebook_tabs = tabs
	d.retired_documents = [&"queue_ticket"]
	if n >= 23:
		d.retired_documents.append(&"bioscan")
	if n >= 27:
		d.quota_suspended_if = _all([&"climate_vanne"])
	if n <= 26:
		d.luciole_rate_bonus = {&"climate_vanne": 0.02}
	if n <= 29:
		d.prorogation_noise_rate = 0.15 if n <= 23 else (0.12 if n <= 25 else 0.10)
	if n >= 22:
		d.reinstated_decoy_rate = 0.5
	if n >= 26:
		d.summons_rate = 0.12 if n == 26 or n == 28 else 0.10
		d.summons_decoys = 4
	if n >= 25:
		d.family_visit_rates = {&"tyc": 0.40 if n <= 27 else (0.55 if n <= 29 else 0.60)}
	d.revoked_decoys = 4
	return d


## Avis du jour : une entrée générée (+1 au climat Brûlants, D-056).
static func _wanted_generated(index: int, brulants_index: int) -> Array[WantedNoticeDef]:
	var generated: WantedNoticeDef = _wanted(&"wanted_generated", &"", index, "wanted_generated_reason")
	var extra: WantedNoticeDef = _wanted(&"wanted_generated_brulants", &"", brulants_index, "wanted_generated_reason")
	extra.condition = _all([&"vanne2_brulants"])
	return [generated, extra]


## Révocations du jour : un révoqué généré, un réintégré généré (J22+, bruit
## légitime de R33), leurres.
static func _revocations(n: int, revoked_index: int, reinstated_index: int) -> Array[RevocationDef]:
	var list: Array[RevocationDef] = [_revocation(&"revoked_generated", &"", revoked_index)]
	if n >= 22 and reinstated_index >= 0:
		var reinstated: RevocationDef = _revocation(&"revoked_reinstated", &"", reinstated_index)
		reinstated.reinstated_on = date_of(22)
		list.append(reinstated)
	return list


# --- J21 — lundi 02.04 : Prorogation de Continuité (respiration) ------------

static func _day21(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(21, rs, 720.0, 15, [0.48, 0.37, 0.13, 0.02], F_J21, 0.38, 0.08, 0)
	var valcourt: ScriptedCaseDef = _scripted(&"sc_51", 1, {&"faction_id": &"hal", &"citizen_class": &"C-1", &"purpose": Passenger.PURPOSE_RETURN}, [K.EXPIRED_DOCUMENT],
			&"sc51_valcourt", {&"document_id": &"id_card", &"expiry": ymd(3, 4)},
			{&"sc51_valcourt_passed": 0}, {&"sc51_valcourt_refused": 0})
	valcourt.identity_from_case = &"sc_07"
	valcourt.appearance_from_case = &"sc_07"
	valcourt.slipped_item = _envelope(40, {&"keep": {&"sc51_bribe_kept": 0, &"suspicion": 1}})
	valcourt.line_variants = [ConditionalKey.make("sc51_valcourt_arrival_kept", _all([&"sc07_bribe_kept"]), "arrival")]
	var today: int = date_of(21)
	var paz: ScriptedCaseDef = _scripted(&"sc_52", 5, {&"faction_id": &"cer", &"citizen_class": &"C-4", &"purpose": Passenger.PURPOSE_TRADE,
			&"stay_days": 4}, [],
			&"sc52_paz", {}, {&"sc52_paz_passed": 0}, {&"sc52_paz_refused": 0})
	paz.identity_from_case = &"sc_48"
	paz.appearance_from_case = &"sc_48"
	paz.document_dates = {
		&"id_card": {"issue": GameDate.from_ymd(2177, 4, 1), "expiry": today - 1},
		&"entry_permit": {"issue": today - 1, "expiry": today + 4},
		&"bioscan": {"issue": today - 1, "expiry": today + 29},
	}
	paz.line_variants = [ConditionalKey.make("sc52_paz_arrival_refused", _all([&"sc48_paz_refused"]), "arrival")]
	var anouk: ScriptedCaseDef = _scripted(&"sc_53", 10, {&"faction_id": &"tyc", &"given_name": "Anouk",
			&"family_name": "Halvorsen", &"sex": Passenger.SEX_F, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2151, 5, 18), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Kessler-Ashe Orbital", &"post": &"post_recycleur", &"implants": PackedStringArray()},
			[K.WANTED_PERSON], &"sc53_anouk", {}, {&"sc53_anouk_passed": 0, &"lucioles_trust": 1},
			{&"sc53_anouk_turned_back": 0})
	anouk.flags_on_detain = {&"sc53_anouk_detained": 0, &"loyalty": 1, &"lucioles_trust": -1}
	anouk.extra_tags = [&"prop_bandaged_hands"]
	# Contrat expiré le 31.03 : prorogé (R32).
	anouk.document_dates = {&"work_contract": {"issue": GameDate.from_ymd(2186, 3, 31), "expiry": ymd(3, 31)}}
	anouk.line_variants = [
		ConditionalKey.make("sc53_anouk_arrival_vanne", _all([&"climate_vanne"]), "arrival"),
		ConditionalKey.make("sc53_anouk_arrival_vitres", _all([&"climate_vitres"]), "arrival"),
		ConditionalKey.make("sc53_anouk_arrival_registre", _all([&"climate_registre"]), "arrival"),
	]
	d.scripted_cases = [valcourt, paz, anouk]
	var notice: WantedNoticeDef = _wanted(&"wanted_anouk", &"sc_53", -1, "wanted_anouk_reason")
	notice.faces_only = true
	d.wanted_notices = [notice]
	d.wanted_notices.append_array(_wanted_generated(13, 7))
	d.revocations = _revocations(21, 12, -1)
	d.announcements = [_announce("hall_quota_suspended", -1, DayDef.SHIFT_START_MIN, null)]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day21_kept", V_COMMISSION, _all([&"sc21_bribe_kept"]), &"arb", 0),
		_msg("spk_arbitre", "msg_arb_day21", V_COMMISSION, null, &"arb", 0),
		_msg("spk_consortium", "msg_cons_day21_amnesty", V_CONSORTIUM, null, &"cons", 0),
		_msg("spk_brulants", "msg_brul_day21", V_BRULANTS, _all([&"vanne2_brulants"]), &"luc", 1),
		_msg("spk_lucioles", "msg_luc_day21_vanne", V_LUCIOLES, _all([&"climate_vanne"]), &"luc", 1),
		_msg("spk_comite", "msg_comite_day21", V_MENTOR, _all([&"climate_vitres"]), &"luc", 1),
		_msg("spk_tycho", "msg_tycho_day23", V_LUCIOLES, _all([&"climate_registre"]), &"luc", 1),
		_msg("spk_consortium", "msg_cons_day21_albedo", V_CONSORTIUM, null, &"cons", 2),
		_family_msg("spk_note", "msg_ilan_day21_soute", _all([&"ilan_soute3"])),
		_family_msg("spk_dora", "msg_dora_day21_detained", _all([&"hh_ilan_held"])),
		_family_msg("spk_dora", "msg_dora_day21_tycho", _all([&"dora_departed"])),
		_family("msg_ilan_day21"),
	]
	var amnesty: EveningEventDef = _event(&"d21_amnesty", EveningEventDef.Kind.CHOICE, 0, _all([&"hh_ilan_held"]),
			"evt_d21_amnesty")
	var sign: EveningOptionDef = _option(&"sign", "evt_d21_amnesty", 0, 0, {&"amnesty_signed": 0, &"ilan_estranged": 0,
			&"loyalty": 1, &"lucioles_trust": -2}, -1)
	sign.household = EveningOptionDef.HOUSEHOLD_ILAN_RELEASED
	amnesty.options = [sign, _option(&"refuse", "evt_d21_amnesty", 0, 0, {&"amnesty_refused": 0}, 0)]
	var recall: EveningEventDef = _letter(&"d21_recall", 1, null, "evt_d21_recall_text", {&"acv_returned": 0})
	recall.title_key = "evt_d21_recall_title"
	recall.text_variants = [ConditionalKey.make("evt_d21_recall_text_none", FlagCondition.make([], [], {}, {&"quota_overrun": 0}))]
	recall.text_gauges = ["recall_amount"]
	recall.gain_gauge = &"recall_amount"
	var loan: EveningEventDef = _event(&"d21_loan", EveningEventDef.Kind.CHOICE, 2, null, "evt_d21_loan")
	loan.economy_gauges_below = {&"balance": &"loan_balance_below"}
	loan.options = [_option(&"take", "evt_d21_loan", 0, 30, {&"arbitre_loan": 0}, 1),
			_option(&"decline", "evt_d21_loan", 0, 0, {}, 0)]
	d.evening_events = [amnesty, recall, loan]
	return d


# --- J22 — mardi 03.04 : Réintégrations ------------------------------------

static func _day22(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(22, rs, 735.0, 16, [0.42, 0.38, 0.16, 0.04], F_J21, 0.38, 0.08, 0)
	var sato: ScriptedCaseDef = _scripted(&"sc_54", 2, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité"}, [], &"sc54_sato", {}, {&"sc54_sato_reinstated": 0}, {&"sc54_sato_refused": 0})
	sato.identity_from_case = &"sc_38"
	sato.appearance_from_case = &"sc_38"
	sato.line_variants = [ConditionalKey.make("sc54_sato_arrival_spared", _all([&"sc41_sato_spared"]), "arrival")]
	var valentin: ScriptedCaseDef = _scripted(&"sc_55", 6, {&"faction_id": &"hal", &"citizen_class": &"C-2", &"purpose": Passenger.PURPOSE_RETURN}, [K.REVOKED_ID],
			&"sc55_valentin", {}, {&"sc55_valentin_passed": 0, &"solidarite": 1, &"lucioles_trust": 1},
			{&"sc55_valentin_refused": 0})
	valentin.requires_flag = &"sc40_valentin_revoked"
	valentin.identity_from_case = &"sc_40"
	valentin.appearance_from_case = &"sc_40"
	var okafor: ScriptedCaseDef = _scripted(&"sc_56", 11, _okafor_identity(), [], &"sc56_okafor", {},
			{&"sc56_okafor_passed": 0}, {&"sc56_okafor_refused": 0})
	okafor.slipped_item = _item(SlippedItem.Kind.OBJECT, "wb_object_label", "sc56_okafor_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"noa_drawing_kept": 0}})
	okafor.slipped_item.text_variants = [ConditionalKey.make("sc56_okafor_note_vitres", _all([&"climate_vitres"]))]
	okafor.extra_tags = [&"prop_school_satchel"]
	d.scripted_cases = [sato, valentin, okafor]
	d.wanted_notices = _wanted_generated(9, 14)
	var reinstated_sato: RevocationDef = _revocation(&"revoked_sato", &"sc_54", -1)
	reinstated_sato.reinstated_on = date_of(22)
	var choi: RevocationDef = _revocation(&"revoked_choi", &"sc_55", -1)
	choi.excluded_reason_key = "rb_reinstated_excluded"
	d.revocations = [reinstated_sato, choi]
	d.revocations.append_array(_revocations(22, 13, 4))
	d.briefing_messages = [
		_msg("spk_sato_former", "msg_sato_day22", V_MENTOR, null, &"", 1),
		_msg("spk_arbitre", "msg_arb_day22", V_COMMISSION, null, &"", 1),
		_msg("spk_hall", "msg_echo_sc51_queue", V_CONSORTIUM, _all([&"sc51_valcourt_refused"]), &"", 2),
		_msg("spk_hall", "msg_echo_sc53_amnesty", V_CONSORTIUM, _all([&"sc53_anouk_detained"]), &"", 2),
		_family("msg_ilan_day22"),
	]
	var q1: EveningEventDef = _question(&"d22_q1", "evt_d22_q1", _any([_all([&"final_passed"]), _all([&"sc51_bribe_kept"])]))
	q1.text_variants = [ConditionalKey.make("evt_d22_q1_text_kept", _all([&"sc51_bribe_kept"]))]
	var drawing: EveningEventDef = _letter(&"d22_drawing", 1, _all([&"noa_drawing_kept"]), "evt_d22_drawing", {})
	var corvo: EveningEventDef = _letter(&"d22_corvo", 2, _all([&"sc33_manifest_kept"]), "evt_d22_corvo", {})
	d.evening_events = [q1, drawing, corvo]
	return d


# --- J23 — mercredi 04.04 : Retour aux quais (bio-scan retiré) --------------

static func _day23(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(23, rs, 720.0, 16, [0.44, 0.37, 0.15, 0.04], F_J21, 0.38, 0.08, 0)
	var noor: ScriptedCaseDef = _scripted(&"sc_57", 3, {&"faction_id": &"tyc", &"citizen_class": &"C-2", &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Dispensaire de Tycho", &"post": &"post_soins", &"implants": PackedStringArray(["OPT-3"])}, [],
			&"sc57_noor", {}, {&"sc57_noor_passed": 0}, {&"sc57_noor_refused": 0})
	noor.identity_from_case = &"sc_09"
	noor.appearance_from_case = &"sc_09"
	noor.slipped_item = _item(SlippedItem.Kind.OBJECT, "wb_object_label", "sc57_noor_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"noor_medicine": 0}})
	noor.line_variants = [
		ConditionalKey.make("sc57_noor_arrival_refused", _all([&"sc09_doctor_refused"]), "arrival"),
		ConditionalKey.make("sc57_noor_arrival_passed", _all([&"sc09_doctor_passed"]), "arrival"),
	]
	var today: int = date_of(23)
	var ophelie: ScriptedCaseDef = _scripted(&"sc_58", 7, {&"faction_id": &"hal", &"given_name": "Ophélie",
			&"family_name": "Delacroix-Tan", &"sex": Passenger.SEX_F, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2157, 12, 3), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Meridian Biosystèmes", &"implants": PackedStringArray()}, [], &"sc58_ophelie", {},
			{&"sc58_ophelie_passed": 0}, {&"sc58_ophelie_refused": 0})
	# Bio-scan retiré présenté quand même, expiré de 3 jours (M1) : hors règles.
	ophelie.retired_documents = [&"bioscan"]
	ophelie.document_dates = {&"bioscan": {"issue": today - 33, "expiry": today - 3}}
	ophelie.extra_tags = [&"prop_certificate_crate"]
	var beaumont: ScriptedCaseDef = _scripted(&"sc_59", 12, {&"faction_id": &"hal", &"citizen_class": &"C-1", &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Commission de Rééquilibrage"}, [K.REVOKED_ID], &"sc59_beaumont", {},
			{&"sc59_beaumont_spared": 0, &"beaumont_witness": 0}, {&"sc59_beaumont_refused": 0})
	beaumont.identity_from_case = &"sc_42"
	beaumont.appearance_from_case = &"sc_42"
	beaumont.line_variants = [
		ConditionalKey.make("sc59_beaumont_confront_obeyed", _all([&"beaumont_obeyed"]), "confront"),
		ConditionalKey.make("sc59_beaumont_confront_defied", _all([&"beaumont_defied"]), "confront"),
	]
	d.scripted_cases = [noor, ophelie, beaumont]
	d.wanted_notices = _wanted_generated(10, 5)
	var excluded: RevocationDef = _revocation(&"revoked_beaumont", &"sc_59", -1)
	excluded.excluded_reason_key = "rb_excluded_commission"
	d.revocations = [excluded]
	d.revocations.append_array(_revocations(23, 14, 6))
	d.announcements = [_announce("hall_j23_quais", 1, -1, null)]
	d.briefing_messages = [
		_msg("spk_tycho", "msg_tycho_day23", V_LUCIOLES, _cond([], [&"climate_registre"]), &"", 1),
		_msg("spk_hall", "msg_hall_day23_commission", V_CONSORTIUM, null, &"", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day23", V_MENTOR, _all([&"okonkwo_shielded"]), &"", 2),
		_msg("spk_sato_greffier", "msg_sato_day23", V_MENTOR, _all([&"sc54_sato_reinstated"]), &"sato", 1),
		_msg("spk_sato_greffier", "msg_sato_day23_refused", V_MENTOR, _all([&"sc54_sato_refused"]), &"sato", 1),
		_family("msg_ilan_day23"),
	]
	var job: EveningEventDef = _event(&"d23_job", EveningEventDef.Kind.CHOICE, 0, _cond([&"hh_ilan_present"], [&"ilan_estranged"]),
			"evt_d23_job")
	var tycho: EveningOptionDef = _option(&"tycho", "evt_d23_job", 0, 0, {&"ilan_tycho": 0, &"solidarite": 1, &"lucioles_trust": 1}, 2)
	tycho.household = EveningOptionDef.HOUSEHOLD_ILAN_TYCHO
	job.options = [tycho, _option(&"scab", "evt_d23_job", 0, 0, {&"ilan_scab": 0, &"loyalty": 1, &"solidarite": -2}, 1),
			_option(&"none", "evt_d23_job", 0, 0, {&"ilan_idle": 0}, 0)]
	var noor_letter: EveningEventDef = _letter(&"d23_noor", 1, _all([&"noor_medicine"]), "evt_d23_noor", {})
	noor_letter.line_costs = {&"meds": 0}
	var fund: EveningEventDef = _letter(&"d23_fund", 2, _gauge(&"solidarite", 2), "evt_d23_fund", {&"vitres_fund": 0})
	fund.economy_gauges_below = {&"balance": &"vitres_fund_balance_below"}
	fund.gain = 15
	d.evening_events = [job, noor_letter, fund]
	return d


# --- J24 — jeudi 05.04 : Répondants (M2) -------------------------------------

static func _day24(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(24, rs, 735.0, 16, [0.40, 0.38, 0.17, 0.05], F_J21, 0.40, 0.08, 0)
	var margaux: ScriptedCaseDef = _scripted(&"sc_60", 1, {&"faction_id": &"hal", &"citizen_class": &"C-2", &"purpose": Passenger.PURPOSE_RETURN}, [], &"sc60_margaux", {},
			{&"sc60_margaux_passed": 0}, {&"sc60_margaux_refused": 0})
	margaux.identity_from_case = &"sc_27"
	margaux.appearance_from_case = &"sc_27"
	margaux.extra_tags = [&"prop_cat_crate"]
	var amara: ScriptedCaseDef = _scripted(&"sc_61", 2, {&"faction_id": &"ter", &"citizen_class": &"C-4", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 14},
			[], &"sc61_amara", {}, {&"sc61_amara_passed": 0}, {&"sc61_amara_turned_away": 0})
	amara.identity_from_case = &"sc_02"
	amara.appearance_from_case = &"sc_02"
	amara.sponsor_case_id = &"sc_60"
	amara.line_variants = [
		ConditionalKey.make("sc61_amara_arrival_reunited", _all([&"sc06_reunited"]), "arrival"),
		ConditionalKey.make("sc61_amara_arrival_refused", _all([&"sc06_refused_again"]), "arrival"),
		ConditionalKey.make("sc61_amara_arrival_mercy", _all([&"sc02_mercy"]), "arrival"),
	]
	var tariq: ScriptedCaseDef = _scripted(&"sc_62", 9, {&"faction_id": &"ter", &"citizen_class": &"C-4", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 10},
			[K.SPONSOR_MISMATCH], &"sc62_tariq", {&"variant": "absent"}, {&"sc62_tariq_passed": 0}, {&"sc62_tariq_refused": 0})
	tariq.identity_from_case = &"sc_28"
	tariq.appearance_from_case = &"sc_28"
	tariq.line_variants = [ConditionalKey.make("sc62_tariq_arrival_passed", _all([&"sc28_tariq_passed"]), "arrival")]
	d.scripted_cases = [margaux, amara, tariq]
	d.wanted_notices = _wanted_generated(12, 6)
	d.revocations = _revocations(24, 14, 7)
	d.briefing_messages = [
		_msg("spk_lucioles", "msg_luc_day24", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 1),
		_msg("spk_hall", "msg_echo_sc58_crate", V_CONSORTIUM, _all([&"sc58_ophelie_refused"]), &"", 2),
		_msg("spk_okafor", "msg_okafor_day24", V_FAMILY, _all([&"sc56_okafor_passed"]), &"", 1),
		_family("msg_ilan_day24"),
	]
	var noa: EveningEventDef = _event(&"d24_noa", EveningEventDef.Kind.CHOICE, 0, null, "evt_d24_noa")
	noa.text_variants = [ConditionalKey.make("evt_d24_noa_text_cold", _all([&"sc56_okafor_refused"]))]
	var truth: EveningOptionDef = _option(&"truth", "evt_d24_noa", 0, 0, {&"noa_testified": 0, &"verite": 1}, 1)
	truth.conditional_flags = [_effect(&"", _any([_all([&"climate_vanne"]), _all([&"final2_passed"])]), {&"suspicion": 1})]
	var keep: EveningOptionDef = _option(&"keep", "evt_d24_noa", 10, 0, {&"noa_kept_home": 0}, 0)
	keep.condition = _gauge(&"balance", 10)
	# À découvert : `suspicion +1` au lieu de l'amende (même libellé).
	var keep_broke: EveningOptionDef = _option(&"keep_broke", "evt_d24_noa", 0, 0, {&"noa_kept_home": 0, &"suspicion": 1}, 0)
	keep_broke.label_key = "evt_d24_noa_opt_keep"
	keep_broke.result_key = "evt_d24_noa_res_keep"
	keep_broke.condition = FlagCondition.make([], [], {}, {&"balance": 9})
	noa.options = [truth, _option(&"coach", "evt_d24_noa", 0, 0, {&"noa_coached": 0}, 2), keep, keep_broke]
	var luc: EveningEventDef = _letter(&"d24_luc", 1, _gauge(&"lucioles_trust", 2), "evt_d24_luc", {})
	d.evening_events = [noa, luc]
	return d


# --- J25 — vendredi 06.04 : Lock-out et air coupé ----------------------------

static func _day25(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(25, rs, 750.0, 17, [0.40, 0.38, 0.17, 0.05], F_J25, 0.40, 0.08, 0)
	d.anomaly_weight_modifiers = {&"sc62_tariq_passed": {K.SPONSOR_MISMATCH: 1.5}}
	var dmitri: ScriptedCaseDef = _scripted(&"sc_63", 3, {&"faction_id": &"tyc", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Kessler-Ashe Orbital", &"post": &"post_recycleur", &"implants": PackedStringArray(["KIN-5"])},
			[K.SUSPENDED_CONTRACT], &"sc63_dmitri", {}, {&"sc63_dmitri_passed": 0, &"solidarite": 1},
			{&"sc63_dmitri_locked_out": 0})
	dmitri.requires_flag = &"sc24_dmitri_hired"
	dmitri.identity_from_case = &"sc_08"
	dmitri.appearance_from_case = &"sc_08"
	var lindgren: ScriptedCaseDef = _lindgren(&"sc_64", 8, &"sc64_lindgren", {&"sc64_lindgren_passed": 0},
			{&"sc64_lindgren_refused": 0})
	lindgren.slipped_item = _item(SlippedItem.Kind.FORM, "wb_form_label", "sc64_lindgren_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"lindgren_form2_signed": 0}})
	lindgren.line_variants = [ConditionalKey.make("sc64_lindgren_arrival_signed", _all([&"lindgren_signed"]), "arrival")]
	var yara: ScriptedCaseDef = _scripted(&"sc_65", 13, {&"faction_id": &"tyc", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 3}, [], &"sc65_yara", {&"permit_suffix": 7}, {&"sc65_yara_passed": 0}, {&"sc65_yara_turned_away": 0})
	yara.identity_from_case = &"sc_10"
	yara.appearance_from_case = &"sc_10"
	yara.sponsor_case_id = &"sc_64"
	yara.luciole_codes = PackedInt32Array([3])
	yara.slipped_item = _item(SlippedItem.Kind.NOTE, "wb_note_label", "sc65_yara_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"tycho_message_kept": 0, &"registre": 1, &"lucioles_trust": 1},
			&"report": {&"tycho_message_reported": 0, &"loyalty": 1, &"lucioles_trust": -2}}, 10)
	d.scripted_cases = [dmitri, lindgren, yara]
	d.wanted_notices = _wanted_generated(11, 5)
	d.revocations = _revocations(25, 15, 6)
	d.announcements = [_announce("hall_j25_tycho", 6, -1, null)]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day25", V_COMMISSION, null, &"", 1),
		_msg("spk_tycho", "msg_tycho_day25_dora", V_LUCIOLES, _all([&"dora_departed"]), &"tycho", 1),
		_msg("spk_tycho", "msg_tycho_day25", V_LUCIOLES, null, &"tycho", 1),
		_msg("spk_hall", "msg_echo_sc61_plants", V_CONSORTIUM, _all([&"sc61_amara_passed"]), &"sc61", 3),
		_msg("spk_hall", "msg_echo_sc61_chain", V_CONSORTIUM, _all([&"sc61_amara_turned_away"]), &"sc61", 3),
		_msg("spk_hall", "msg_echo_sc62_ring", V_CONSORTIUM, _all([&"sc62_tariq_refused"]), &"sc62", 2),
		_msg("spk_hall", "msg_echo_sc62_flood", V_CONSORTIUM, _all([&"sc62_tariq_passed"]), &"sc62", 2),
		_family("msg_ilan_day25_truth", _all([&"noa_testified"])),
		_family("msg_ilan_day25_coached", _all([&"noa_coached"])),
		_family("msg_ilan_day25_home", _all([&"noa_kept_home"])),
	]
	var dora: EveningEventDef = _event(&"d25_dora", EveningEventDef.Kind.CHOICE, 0, _all([&"hh_dora_present"]), "evt_d25_dora")
	var go: EveningOptionDef = _option(&"go", "evt_d25_dora", 5, 0, {&"dora_testimony": 0, &"registre": 1, &"verite": 1,
			&"suspicion": 1}, 2)
	go.household = EveningOptionDef.HOUSEHOLD_DORA_SICK
	dora.options = [_option(&"write", "evt_d25_dora", 0, 0, {&"dora_testimony": 0, &"registre": 1, &"verite": 1}, 1), go,
			_option(&"rest", "evt_d25_dora", 0, 0, {}, 0)]
	var letter: EveningEventDef = _letter(&"d25_dora_letter", 0, _all([&"dora_departed", &"hh_dora_away"]), "evt_d25_dora_letter", {})
	var ilan_back: EveningEventDef = _letter(&"d25_ilan_back", 0, _all([&"ilan_soute3", &"hh_ilan_away"]), "evt_d25_ilan_back", {})
	ilan_back.household = EveningOptionDef.HOUSEHOLD_ILAN_HOME
	var fund: EveningEventDef = _event(&"d25_tycho_fund", EveningEventDef.Kind.CHOICE, 1, null, "evt_d25_tycho_fund")
	fund.options = [_option(&"give", "evt_d25_tycho_fund", 10, 0, {&"tycho_fund": 0, &"solidarite": 1}, 1),
			_option(&"pass", "evt_d25_tycho_fund", 0, 0, {}, 0),
			_option(&"report", "evt_d25_tycho_fund", 0, 10, {&"tycho_fund_reported": 0, &"loyalty": 1, &"solidarite": -2}, -1)]
	var levy: EveningEventDef = _letter(&"d25_levy", 2, null, "evt_d25_levy_text", {})
	levy.title_key = "evt_d25_levy_title"
	levy.text_gauges = ["levy_amount"]
	d.evening_events = [dora, letter, ilan_back, fund, levy]
	return d


# --- J26 — samedi 07.04 : Convocations de l'Enquête --------------------------

static func _day26(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(26, rs, 765.0, 17, [0.38, 0.38, 0.19, 0.05], F_J25, 0.40, 0.08, 0)
	var lev: ScriptedCaseDef = _scripted(&"sc_66", 2, {&"faction_id": &"tyc", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_TRANSIT,
			&"stay_days": 3, &"summons_id": "ENQ-0907", &"implants": PackedStringArray()}, [K.FORGED_SUMMONS], &"sc66_lev",
			{&"variant": "absent"}, {&"sc66_lev_passed": 0, &"lucioles_trust": 2}, {&"sc66_lev_turned_back": 0})
	lev.flags_on_detain = {&"sc66_lev_detained": 0, &"loyalty": 1, &"lucioles_trust": -2}
	lev.condition = _cond([], [&"sc13_detained"])
	lev.identity_from_case = &"sc_05"
	lev.appearance_from_case = &"sc_05"
	lev.luciole_codes = PackedInt32Array([4])
	lev.flags_on_password = {&"sc66_password_answered": 0}
	lev.slipped_item = _item(SlippedItem.Kind.OBJECT, "wb_object_label", "sc66_lev_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"forged_summons_kept": 0, &"lucioles_trust": 1, &"suspicion": 1},
			&"report": {&"forged_summons_reported": 0, &"loyalty": 2, &"lucioles_trust": -2}}, 15)
	lev.line_variants = [ConditionalKey.make("sc66_lev_arrival_passed", _all([&"sc13_passed"]), "arrival")]
	var hana: ScriptedCaseDef = _scripted(&"sc_67", 6, {&"faction_id": &"thr", &"citizen_class": &"C-5", &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 14,
			&"summons_id": "ENQ-0412"}, [], &"sc67_hana", {}, {&"sc67_hana_reunited": 0}, {&"sc67_hana_refused": 0})
	hana.requires_flag = &"sc16_family_split"
	hana.identity_from_case = &"sc_16"
	hana.appearance_from_case = &"sc_16"
	hana.luciole_codes = PackedInt32Array([6])
	var kerr: ScriptedCaseDef = _scripted(&"sc_68", 10, {&"faction_id": &"hal", &"given_name": "Ren", &"family_name": "Kerr",
			&"sex": Passenger.SEX_M, &"citizen_class": &"C-2", &"birth_date": GameDate.from_ymd(2127, 3, 15),
			&"purpose": Passenger.PURPOSE_RETURN, &"employer": "Banque Aurel", &"implants": PackedStringArray()}, [],
			&"sc68_kerr", {}, {&"sc68_kerr_passed": 0}, {&"sc68_kerr_refused": 0})
	var kerr2: ScriptedCaseDef = _scripted(&"sc_69", 11, {&"faction_id": &"cer", &"citizen_class": &"C-4", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 5}, [],
			&"sc69_kerr", {}, {&"sc69_kerr_passed": 0}, {&"sc69_kerr_refused": 0})
	kerr2.identity_from_case = &"sc_30"
	kerr2.appearance_from_case = &"sc_30"
	kerr2.sponsor_case_id = &"sc_68"
	kerr2.extra_effects = [_effect(&"approve", _all([&"sc68_kerr_passed"]), {&"kerr_sponsor_ok": 0})]
	d.scripted_cases = [lev, hana, kerr, kerr2]
	d.wanted_notices = _wanted_generated(14, 4)
	d.revocations = _revocations(26, 15, 8)
	d.summons = [_summons(&"summons_hana", &"sc_67", -1, "summons_reason_albedo")]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day26", V_COMMISSION, null, &"", 1),
		_msg("spk_lucioles", "msg_luc_day26", V_LUCIOLES, _gauge(&"lucioles_trust", 3), &"", 1),
		_msg("spk_hall", "msg_hall_day26_bornes", V_CONSORTIUM, _all([&"climate_vitres"]), &"", 2),
		_family("msg_ilan_day26_summoned", _all([&"ilan_joined_soute"])),
		_family("msg_ilan_day26"),
	]
	var q2: EveningEventDef = _question(&"d26_q2", "evt_d26_q2", _all([&"final2_passed"]))
	var summoned: EveningEventDef = _event(&"d26_ilan", EveningEventDef.Kind.CHOICE, 1, _all([&"ilan_joined_soute",
			&"hh_ilan_present"]), "evt_d26_ilan")
	var hide: EveningOptionDef = _option(&"hide", "evt_d26_ilan", 0, 0, {&"ilan_hidden3": 0, &"suspicion": 2}, 1)
	hide.household = EveningOptionDef.HOUSEHOLD_ILAN_SOUTE
	summoned.options = [_option(&"go", "evt_d26_ilan", 0, 0, {&"ilan_testifies": 0, &"verite": 1, &"suspicion": 1}, 0), hide]
	var released: EveningEventDef = _letter(&"d26_ilan_released", 2, _all([&"amnesty_refused", &"hh_ilan_held"]),
			"evt_d26_ilan_released", {&"ilan_released_late": 0})
	released.household = EveningOptionDef.HOUSEHOLD_ILAN_RELEASED
	d.evening_events = [q2, summoned, released]
	return d


# --- J27 — dimanche 08.04 : l'Arbitre au guichet (respiration) ---------------

static func _day27(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(27, rs, 750.0, 17, [0.42, 0.37, 0.16, 0.05], F_J25, 0.40, 0.06, 4)
	d.intro_variants = [ConditionalKey.make("day27_intro_vanne", _all([&"climate_vanne"]))]
	d.anomaly_weight_modifiers = {&"forged_summons_reported": {K.FORGED_SUMMONS: 0.5}}
	var montclair: ScriptedCaseDef = _scripted(&"sc_70", 1, {&"faction_id": &"hal", &"citizen_class": &"C-1", &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": EMPLOYER_AR},
			[K.MRZ_MISMATCH], &"sc70_montclair", {&"component": "given_name", &"mrz_value": "PHILIPA"},
			{&"sc70_montclair_passed": 0, &"montclair_pliable": 0, &"loyalty": 1},
			{&"sc70_montclair_refused": 0, &"montclair_impressed": 0})
	montclair.flags_on_detain = {&"sc70_montclair_detained": 0, &"suspicion": 2}
	montclair.identity_from_case = &"sc_21"
	montclair.appearance_from_case = &"sc_21"
	montclair.line_variants = [
		ConditionalKey.make("sc70_montclair_arrival_kept", _all([&"sc21_bribe_kept"]), "arrival"),
		ConditionalKey.make("sc70_montclair_arrival_refused", _cond([], [&"sc21_passed"]), "arrival"),
	]
	var kasimirs: Array[ScriptedCaseDef] = []
	for spec: Array in [[&"sc_71a", [K.WANTED_PERSON], _all([&"sc47_kasimir_passed"]), "sc71_kasimir_arrival_quai"],
			[&"sc_71b", [], _all([&"sc47_kasimir_detained"]), "sc71_kasimir_arrival_detained"],
			[&"sc_71c", [], _cond([], [&"sc47_kasimir_passed", &"sc47_kasimir_detained"]), ""]]:
		var kinds: Array = spec[1]
		var anomalies: Array[AnomalyType.Kind] = []
		anomalies.assign(kinds)
		var kasimir_id: StringName = spec[0]
		var arrival: String = spec[3]
		var kasimir: ScriptedCaseDef = _scripted(kasimir_id, 7, {&"faction_id": &"tyc", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_TRANSIT,
				&"stay_days": 3, &"summons_id": "ENQ-0001", &"implants": PackedStringArray()}, anomalies, &"sc71_kasimir", {},
				{&"sc71_kasimir_passed": 0}, {&"sc71_kasimir_refused": 0})
		kasimir.flags_on_detain = {&"sc71_kasimir_detained": 0, &"loyalty": 1}
		kasimir.identity_from_case = &"sc_47"
		kasimir.appearance_from_case = &"sc_47"
		kasimir.condition = spec[2]
		if not arrival.is_empty():
			kasimir.line_variants = [ConditionalKey.make(arrival, null, "arrival")]
		kasimirs.append(kasimir)
	var wren: ScriptedCaseDef = _scripted(&"sc_72", 12, {&"faction_id": &"drv", &"given_name": "Wren",
			&"family_name": "Basse-Marée", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2142, 8, 30), &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 3,
			&"implants": PackedStringArray()}, [K.UNREGISTERED_VESSEL], &"sc72_wren", {&"vessel": "BASSE-MARÉE"},
			{&"sc72_wren_passed": 0, &"drift3_offer": 0}, {&"sc72_wren_refused": 0, &"drift3_offer": 0})
	wren.flags_on_detain = {&"drift3_offer": 0}
	wren.appearance_from_case = &"sc_19"
	wren.slipped_item = _item(SlippedItem.Kind.DOCK_CARD, "wb_dock_card_label", "sc72_wren_note", [KEEP], KEEP, {})
	wren.line_variants = [ConditionalKey.make("sc72_wren_arrival_stayed", _any([_all([&"drift2_stayed"]),
			_all([&"drift_stayed"])]), "arrival")]
	d.scripted_cases = [montclair]
	d.scripted_cases.append_array(kasimirs)
	d.scripted_cases.append(wren)
	var notice: WantedNoticeDef = _wanted(&"wanted_kasimir3", &"sc_71a", -1, "wanted_kasimir3_reason")
	d.wanted_notices = [notice]
	d.wanted_notices.append_array(_wanted_generated(15, 9))
	d.revocations = _revocations(27, 14, 4)
	d.summons = [_summons(&"summons_kasimir_a", &"sc_71a", -1, "summons_reason_confession"),
			_summons(&"summons_kasimir_b", &"sc_71b", -1, "summons_reason_confession"),
			_summons(&"summons_kasimir_c", &"sc_71c", -1, "summons_reason_confession")]
	d.announcements = [_announce("hall_j27_arbitre", -1, DayDef.SHIFT_START_MIN, null)]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day27", V_COMMISSION, null, &"", 0),
		_msg("spk_hall", "msg_echo_sc67_reunited", V_CONSORTIUM, _all([&"sc67_hana_reunited"]), &"sc67", 2),
		_msg("spk_hall", "msg_echo_sc67_refused", V_CONSORTIUM, _all([&"sc67_hana_refused"]), &"sc67", 2),
		_msg("spk_sato_greffier", "msg_sato_day27_kerr", V_MENTOR, _all([&"kerr_sponsor_ok"]), &"", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day27", V_MENTOR, _all([&"okonkwo_shielded"]), &"", 1),
		_family("msg_ilan_day27"),
	]
	var drift: EveningEventDef = _event(&"d27_drift", EveningEventDef.Kind.CHOICE, 0, _all([&"drift3_offer"]), "evt_d27_drift")
	drift.options = [_option(&"buy", "evt_d27_drift", 70, 0, {&"exit3_bought": 0, &"exit3_drift": 0}, 1),
			_option(&"keep", "evt_d27_drift", 0, 0, {}, 0)]
	var tycho: EveningEventDef = _event(&"d27_tycho", EveningEventDef.Kind.CHOICE, 1, _cond([], [&"exit3_bought"],
			{&"hh_present": 2}), "evt_d27_tycho")
	tycho.text_variants = [ConditionalKey.make("evt_d27_tycho_text_dora", _all([&"dora_departed"]))]
	var tickets: EveningOptionDef = _option(&"buy", "evt_d27_tycho", 30, 0, {&"exit3_bought": 0, &"exit3_tycho": 0}, 1)
	# Revérifiée à l'application : pas de billets après les places de la Soute.
	tickets.condition = _cond([], [&"exit3_bought"])
	tycho.options = [tickets, _option(&"keep", "evt_d27_tycho", 0, 0, {}, 0)]
	var loan: EveningEventDef = _letter(&"d27_loan", 2, _all([&"arbitre_loan"]), "evt_d27_loan", {&"loan_settled": 0})
	d.evening_events = [drift, tycho, loan]
	return d


# --- J28 — lundi 09.04 : Fermeture de Tycho ----------------------------------

static func _day28(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(28, rs, 780.0, 18, [0.36, 0.38, 0.20, 0.06], F_J28, 0.40, 0.08, 4)
	d.anomaly_weight_modifiers = {&"forged_summons_reported": {K.FORGED_SUMMONS: 0.5}}
	var celeste: ScriptedCaseDef = _scripted(&"sc_73", 2, {&"faction_id": &"hal", &"given_name": "Céleste",
			&"family_name": "Sorel", &"sex": Passenger.SEX_F, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2144, 2, 7), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Meridian Biosystèmes", &"implants": PackedStringArray()}, [K.EXPIRED_DOCUMENT], &"sc73_celeste",
			{&"document_id": &"id_card", &"expiry": ymd(3, 21)},
			{&"sc73_celeste_passed": 0}, {&"sc73_celeste_refused": 0})
	var elena: ScriptedCaseDef = _scripted(&"sc_74", 3, {&"faction_id": &"tyc", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 7,
			&"implants": PackedStringArray()}, [], &"sc74_elena", {}, {&"sc74_elena_passed": 0}, {&"sc74_elena_turned_away": 0})
	elena.identity_from_case = &"sc_25"
	elena.appearance_from_case = &"sc_25"
	elena.sponsor_case_id = &"sc_73"
	elena.extra_tags = [&"companion_child"]
	elena.line_variants = [
		ConditionalKey.make("sc74_elena_arrival_turned", _all([&"sc25_elena_turned_away"]), "arrival"),
		ConditionalKey.make("sc74_elena_name", _all([&"registre_sent"]), "stay"),
	]
	var okonkwo: Dictionary = {&"faction_id": &"ter", &"given_name": "Emeka", &"family_name": "Okonkwo",
			&"sex": Passenger.SEX_M, &"birth_date": GameDate.from_ymd(2141, 7, 9), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Autorité de Transit", &"implants": PackedStringArray()}
	var variants: Array[ScriptedCaseDef] = []
	for spec: Array in [
			[&"sc_75a", _all([&"okonkwo_shielded"]), &"C-3", &"post_soins", "", [], "quai"],
			[&"sc_75b", _all([&"okonkwo_denounced"]), &"C-5", &"post_manutention", "ENQ-0315", [], "docker"],
			[&"sc_75c", _all([&"okonkwo_warned", &"sc35_okonkwo_detained"]), &"C-4", &"post_manutention", "ENQ-0316", [], "amnesty"],
			[&"sc_75d", _all([&"okonkwo_warned"]), &"C-4", &"post_manutention", "ENQ-0317", [K.FORGED_SUMMONS], "veilleur"]]:
		var identity: Dictionary = okonkwo.duplicate()
		identity[&"citizen_class"] = spec[2]
		identity[&"post"] = spec[3]
		if not str(spec[4]).is_empty():
			identity[&"summons_id"] = spec[4]
		var variant_id: StringName = spec[0]
		var kinds: Array = spec[5]
		var anomalies: Array[AnomalyType.Kind] = []
		anomalies.assign(kinds)
		var forged: bool = not anomalies.is_empty()
		var approve: Dictionary[StringName, int] = {&"sc75_okonkwo_passed": 0}
		var deny: Dictionary[StringName, int] = {&"sc75_okonkwo_refused": 0}
		if spec[0] == &"sc_75b" or spec[0] == &"sc_75c":
			approve[&"okonkwo_testifies"] = 0
		if forged:
			approve = {&"sc75_okonkwo_helped": 0, &"solidarite": 1, &"lucioles_trust": 1}
			deny = {&"sc75_okonkwo_turned_back": 0}
		var variant: ScriptedCaseDef = _scripted(variant_id, 8, identity, anomalies, &"sc75_okonkwo",
				{&"variant": "absent"} if forged else {}, approve, deny)
		variant.condition = spec[1]
		variant.fixed_appearance_seed = OKONKWO_SEED
		variant.line_variants = [
			ConditionalKey.make("sc75_okonkwo_arrival_%s" % spec[6], null, "arrival"),
			ConditionalKey.make("sc75_okonkwo_present_%s" % spec[6], null, "present"),
			ConditionalKey.make("sc75_okonkwo_advice", null, "stay"),
		]
		variants.append(variant)
	var sato: ScriptedCaseDef = _scripted(&"sc_76", 12, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN,
			&"stay_days": 2,
			&"employer": "Bureau de Continuité", &"summons_id": "ENQ-0003"}, [K.FORGED_SUMMONS], &"sc76_sato",
			{&"variant": "absent"}, {&"sc76_sato_passed": 0, &"suspicion": 1}, {&"sc76_sato_refused": 0})
	sato.identity_from_case = &"sc_38"
	sato.appearance_from_case = &"sc_38"
	sato.extra_documents = [&"entry_permit"]
	sato.slipped_item = _item(SlippedItem.Kind.FORM, "wb_summons_label", "sc76_sato_note", [KEEP], KEEP,
			{&"keep": {&"deposition_summoned": 0}})
	d.scripted_cases = [celeste, elena]
	d.scripted_cases.append_array(variants)
	d.scripted_cases.append(sato)
	d.wanted_notices = _wanted_generated(15, 9)
	d.revocations = _revocations(28, 16, 5)
	d.summons = [_summons(&"summons_okonkwo_b", &"sc_75b", -1, "summons_reason_guichet03"),
			_summons(&"summons_okonkwo_c", &"sc_75c", -1, "summons_reason_guichet03")]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day28_refused", V_COMMISSION, _all([&"sc70_montclair_refused"]), &"arb", 1),
		_msg("spk_arbitre", "msg_arb_day28_detained", V_COMMISSION, _all([&"sc70_montclair_detained"]), &"arb", 1),
		_msg("spk_arbitre", "msg_arb_day28_confession", V_COMMISSION, _all([&"sc71_kasimir_passed"]), &"arb", 1),
		_msg("spk_brulants", "msg_brul_day28", V_BRULANTS, _all([&"sc71_kasimir_refused"]), &"", 2),
		_msg("spk_tycho", "msg_tycho_day28", V_LUCIOLES, null, &"", 1),
		_msg("spk_lucioles", "msg_luc_day28", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 2),
		_family_msg("spk_dora", "msg_dora_day28_tycho", _all([&"dora_departed"])),
		_family("msg_ilan_day28"),
	]
	var q3: EveningEventDef = _event(&"d28_q3", EveningEventDef.Kind.CHOICE, 0, null, "evt_d28_q3")
	var tell: EveningOptionDef = _option(&"tell", "evt_d28_q3", 0, 0, {&"verite": 1, &"aveux": 1}, 1)
	var silent: EveningOptionDef = _option(&"silent", "evt_d28_q3", 0, 0, {&"suspicion": 1, &"lucioles_trust": 1}, 0)
	silent.label_key = "evt_enq_opt_silent"
	var accuse: EveningOptionDef = _option(&"accuse", "evt_d28_q3", 0, 10, {&"names_given": 0, &"enquete_accused": 0,
			&"loyalty": 2, &"lucioles_trust": -3, &"solidarite": -1}, -1)
	q3.options = [tell, silent, accuse]
	var summons: EveningEventDef = _letter(&"d28_summons", 1, _all([&"deposition_summoned"]), "evt_d28_summons", {})
	var radio: EveningEventDef = _letter(&"d28_radio", 2, _all([&"hh_dora_present"]), "evt_d28_radio", {})
	d.evening_events = [q3, summons, radio]
	return d


# --- J29 — mardi 10.04 : la Déposition (respiration) -------------------------

static func _day29(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(29, rs, 750.0, 17, [0.42, 0.38, 0.15, 0.05], F_J28, 0.40, 0.08, 3)
	d.anomaly_weight_modifiers = {&"forged_summons_reported": {K.FORGED_SUMMONS: 0.5}}
	var lindgren: ScriptedCaseDef = _lindgren(&"sc_77", 4, &"sc77_lindgren", {&"sc77_lindgren_passed": 0},
			{&"sc77_lindgren_refused": 0})
	# Carte expirée le 31.03, prorogée jusqu'à ce soir (dernier jour, R32).
	lindgren.document_dates = {&"id_card": {"issue": GameDate.from_ymd(2182, 3, 31), "expiry": ymd(3, 31)}}
	lindgren.slipped_item = _item(SlippedItem.Kind.FILE, "wb_file_label", "sc77_lindgren_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"albedo_reports_kept": 0, &"registre": 1}, &"report": {&"albedo_reports_reported": 0, &"loyalty": 1}}, 10)
	var mazur: ScriptedCaseDef = _scripted(&"sc_78", 9, {&"faction_id": &"thr", &"citizen_class": &"C-4", &"purpose": Passenger.PURPOSE_FAMILY_VISIT,
			&"stay_days": 10,
			&"implants": PackedStringArray(["MIL-9"]), &"summons_id": "ENQ-0220"}, [], &"sc78_mazur", {},
			{&"sc78_mazur_reunited": 0}, {&"sc78_mazur_refused": 0})
	mazur.requires_flag = &"sc11_veteran_passed"
	mazur.identity_from_case = &"sc_11"
	mazur.appearance_from_case = &"sc_11"
	mazur.extra_documents = [&"mil_waiver"]
	mazur.document_dates = {&"mil_waiver": {"issue": GameDate.from_ymd(2186, 12, 25), "expiry": ymd(3, 25)}}
	mazur.line_variants = [ConditionalKey.make("sc78_mazur_confront_katya", _all([&"sc29_katya_locked_out"]), "confront")]
	var adeyemi: ScriptedCaseDef = _scripted(&"sc_79", 13, {&"faction_id": &"hal", &"given_name": "Lin",
			&"family_name": "Adeyemi", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2154, 11, 11), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité", &"implants": PackedStringArray()}, [], &"sc79_adeyemi", {},
			{&"sc79_adeyemi_passed": 0}, {&"sc79_adeyemi_refused": 0})
	adeyemi.slipped_item = _item(SlippedItem.Kind.FILE, "wb_file_label", "sc79_adeyemi_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"tycho_list_saved": 0, &"registre": 1, &"lucioles_trust": 1, &"suspicion": 1},
			&"return": {&"tycho_list_applied": 0},
			&"report": {&"tycho_list_reported": 0, &"tycho_list_applied": 0, &"loyalty": 2}}, 15)
	adeyemi.extra_tags = [&"prop_armband_pocket"]
	d.scripted_cases = [lindgren, mazur, adeyemi]
	d.wanted_notices = _wanted_generated(15, 7)
	d.revocations = _revocations(29, 11, 5)
	d.summons = [_summons(&"summons_mazur", &"sc_78", -1, "summons_reason_quai2")]
	d.announcements = [_announce("hall_j29_prorogation", -1, 17 * 60 + 30, null)]
	d.briefing_messages = [
		_msg("spk_enquete", "msg_enquete_day29_spared", V_INSPECTION, _all([&"sc45_ravel_spared"]), &"enq", 0),
		_msg("spk_enquete", "msg_enquete_day29_destroyed", V_INSPECTION, _all([&"ravel_file_destroyed"]), &"enq", 0),
		_msg("spk_enquete", "msg_enquete_day29", V_INSPECTION, null, &"enq", 0),
		_msg("spk_hall", "msg_echo_sc74_transit", V_CONSORTIUM, _all([&"sc74_elena_turned_away"]), &"", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day29", V_MENTOR, _all([&"sc75_okonkwo_passed", &"okonkwo_shielded"]), &"", 1),
		_family("msg_ilan_day29"),
	]
	var deposition: EveningEventDef = _event(&"d29_deposition", EveningEventDef.Kind.CHOICE, 0, null, "evt_d29_deposition")
	var truth: EveningOptionDef = _option(&"truth", "evt_d29_deposition", 0, 0, {&"deposition_truth": 0, &"verite": 1}, 1)
	truth.conditional_flags = [
		_effect(&"", _all([&"ilan_estranged"]), {&"aveux": 1, &"ilan_reconciled": 0}),
		_effect(&"", _all([&"forged_summons_kept"]), {&"aveux": 1}),
	]
	var loyal: EveningOptionDef = _option(&"loyal", "evt_d29_deposition", 0, 0, {&"deposition_loyal": 0, &"loyalty": 2,
			&"lucioles_trust": -3, &"solidarite": -2}, 2)
	loyal.condition = _cond([], [&"montclair_pliable"])
	var loyal_paid: EveningOptionDef = _option(&"loyal_paid", "evt_d29_deposition", 0, 20, {&"deposition_loyal": 0,
			&"loyalty": 2, &"lucioles_trust": -3, &"solidarite": -2}, 2)
	loyal_paid.label_key = "evt_d29_deposition_opt_loyal"
	loyal_paid.result_key = "evt_d29_deposition_res_loyal"
	loyal_paid.condition = _all([&"montclair_pliable"])
	var silent: EveningOptionDef = _option(&"silent", "evt_d29_deposition", 0, 0, {&"deposition_silent": 0, &"suspicion": 1}, 0)
	deposition.options = [truth, loyal, loyal_paid, silent]
	var verdict: EveningEventDef = _event(&"d29_verdict", EveningEventDef.Kind.AUDIT, 1, null, "")
	verdict.title_key = "evt_d29_deposition_title"
	verdict.audit_id = EndingService.AUDIT_DEPOSITION
	var strike: EveningEventDef = _event(&"d29_strike", EveningEventDef.Kind.CHOICE, 2, null, "evt_d29_strike")
	strike.economy_gauges_min = {&"solidarite": &"strike3_solidarity_threshold"}
	strike.options = [_option(&"join", "evt_d29_strike", 0, 0, {&"strike2_joined": 0, &"loyalty": -2}, 1),
			_option(&"abstain", "evt_d29_strike", 0, 0, {}, 0)]
	var essay: EveningEventDef = _letter(&"d29_essay", 3, null, "evt_d29_essay", {})
	essay.title_key = "evt_d29_essay_title"
	essay.text_variants = [
		ConditionalKey.make("evt_d29_essay_vitre", _any([_all([&"strike2_joined"]), _all([&"climate_vitres"])])),
		ConditionalKey.make("evt_d29_essay_luciole", _gauge(&"lucioles_trust", 7)),
		ConditionalKey.make("evt_d29_essay_agent", _gauge(&"loyalty", 7)),
		ConditionalKey.make("evt_d29_essay_coached", _all([&"noa_coached"])),
	]
	d.evening_events = [deposition, verdict, strike, essay]
	return d


# --- J30 — mercredi 11.04 : la dernière navette (pas de soirée) --------------

static func _day30(rs: RuleSet) -> DayDef:
	var d: DayDef = _act3_day(30, rs, 780.0, 18, [0.36, 0.38, 0.20, 0.06], F_J30, 0.40, 0.10, 3)
	d.anomaly_weight_modifiers = {&"forged_summons_reported": {K.FORGED_SUMMONS: 0.5}}
	var margaux: ScriptedCaseDef = _scripted(&"sc_80", 2, {&"faction_id": &"hal", &"citizen_class": &"C-2", &"purpose": Passenger.PURPOSE_RETURN}, [K.EXPIRED_DOCUMENT],
			&"sc80_margaux", {&"document_id": &"id_card", &"expiry": ymd(3, 28)},
			{&"sc80_margaux_passed": 0}, {&"sc80_margaux_refused": 0})
	margaux.identity_from_case = &"sc_27"
	margaux.appearance_from_case = &"sc_27"
	margaux.extra_tags = [&"prop_cat_crate"]
	var okafor: ScriptedCaseDef = _scripted(&"sc_81", 5, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN}, [], &"sc81_okafor", {},
			{&"sc81_okafor_passed": 0}, {&"sc81_okafor_refused": 0})
	okafor.identity_from_case = &"sc_56"
	okafor.appearance_from_case = &"sc_56"
	okafor.extra_tags = [&"prop_school_satchel"]
	okafor.line_variants = [ConditionalKey.make("sc81_okafor_arrival_refused", _all([&"sc56_okafor_refused"]), "arrival")]
	# SC-81b : le réseau des répondants (au plus 4, emplacements 8, 11, 13, 15).
	var network: Array[ScriptedCaseDef] = []
	for spec: Array in [
			[&"lindgren", &"sc_23", _all([&"sc64_lindgren_passed", &"sc77_lindgren_passed"])],
			[&"sato", &"sc_38", _any([_all([&"sc54_sato_reinstated"]), _all([&"sc41_sato_spared"])])],
			[&"valentin", &"sc_40", _any([_all([&"sc40_valentin_passed"]), _all([&"sc55_valentin_passed"])])],
			[&"kerr", &"sc_68", _all([&"sc68_kerr_passed"])],
			[&"beaumont", &"sc_42", _all([&"sc59_beaumont_spared"])]]:
		var member: StringName = spec[0]
		var friend: ScriptedCaseDef = _scripted(StringName("sc_81b_%s" % member), 8, {&"faction_id": &"hal",
				&"citizen_class": NETWORK_CLASSES[member], &"purpose": Passenger.PURPOSE_RETURN}, [],
				StringName("sc81b_%s" % member), {}, {StringName("sc81b_%s_passed" % member): 0},
				{StringName("sc81b_%s_refused" % member): 0})
		friend.identity_from_case = spec[1]
		friend.appearance_from_case = spec[1]
		friend.condition = spec[2]
		friend.slot_group = &"reseau"
		friend.extra_tags = [&"sc81b"]
		network.append(friend)
	d.slot_groups = {&"reseau": PackedInt32Array([8, 11, 13, 15])}
	# Familles de Tycho derrière chaque répondant scénarisé (§4.10).
	d.sponsor_links = {3: 2, 6: 5, 7: 5, 9: 8, 12: 11, 14: 13, 16: 15}
	d.linked_ward_faction = &"tyc"
	d.admission_gauges = {&"tyc": &"pont"}
	var registre: SlippedItemDef = _item(SlippedItem.Kind.FILE, "wb_registre_label", "sc82_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"tycho_registre": 0, &"registre": 2}, &"report": {&"tycho_registre_reported": 0, &"loyalty": 2}}, 20)
	var dora: ScriptedCaseDef = _scripted(&"sc_82a", 10, {&"faction_id": &"tyc", &"given_name": "Dora",
			&"family_name": "Lindqvist-Rey", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2122, 6, 14), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 14,
			&"sponsor_id": AGENT_ID, &"implants": PackedStringArray()}, [K.WANTED_PERSON], &"sc82_dora", {},
			{&"final3_passed": 0, &"lucioles_trust": 1}, {&"final3_denied": 0})
	dora.flags_on_detain = {&"final3_detained": 0, &"loyalty": 1, &"lucioles_trust": -2, &"dora_detained_final": 0}
	dora.flags_if_unprocessed = {&"final3_unprocessed": 0}
	dora.sets_flag = &"final3_dora"
	dora.condition = _all([&"dora_departed"])
	dora.fixed_appearance_seed = DORA_SEED
	dora.slipped_item = registre
	var mira: ScriptedCaseDef = _scripted(&"sc_82b", 10, {
		&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
		&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc",
		&"citizen_id": "HG-4471-K2Q9", &"citizen_class": &"C-3",
		&"purpose": Passenger.PURPOSE_TRANSIT, &"stay_days": 3, &"employer": "Kessler-Ashe Orbital",
		&"implants": PackedStringArray(),
	}, [K.WANTED_PERSON, K.BANNED_FACTION], &"sc82_mira", {}, {&"final3_passed": 0, &"lucioles_trust": 1}, {&"final3_denied": 0})
	mira.flags_on_detain = {&"final3_detained": 0, &"loyalty": 1, &"lucioles_trust": -2}
	mira.flags_if_unprocessed = {&"final3_unprocessed": 0}
	mira.appearance_from_case = &"sc_04"
	mira.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN}
	mira.luciole_codes = PackedInt32Array([4, 6, 7])
	mira.slipped_item = registre
	mira.line_variants = [
		ConditionalKey.make("sc82_mira_arrival_detained", _all([&"mira_detained2"]), "arrival"),
		ConditionalKey.make("sc82_mira_arrival_passed", _cond([&"final2_passed"], [&"ilan_joined_soute"]), "arrival"),
	]
	d.scripted_cases = [margaux, okafor]
	d.scripted_cases.append_array(network)
	d.scripted_cases.append_array([dora, mira])
	var dora_notice: WantedNoticeDef = _wanted(&"wanted_final_dora", &"sc_82a", -1, "wanted_dora_reason")
	var mira_notice: WantedNoticeDef = _wanted(&"wanted_final_mira3", &"sc_82b", -1, "wanted_mira3_reason")
	var generated: WantedNoticeDef = _wanted(&"wanted_generated", &"", 17, "wanted_generated_reason")
	var kasimir: WantedNoticeDef = _wanted(&"wanted_kasimir3", &"", -1, "wanted_kasimir3_reason")
	kasimir.memory_case_id = &"sc_47"
	kasimir.condition = _cond([&"sc71_kasimir_passed"], [&"sc71_kasimir_detained"])
	for notice: WantedNoticeDef in [dora_notice, mira_notice, generated, kasimir]:
		notice.faces_only = true
	d.wanted_notices = [dora_notice, mira_notice, generated, kasimir]
	d.revocations = _revocations(30, 4, 1)
	d.announcements = [
		_announce("hall_j30_transit", 5, -1, null),
		_announce("hall_j30_arrests", 6, -1, _all([&"tycho_list_applied"])),
		_announce("hall_j30_strike", 12, -1, _all([&"strike2_joined"]), true),
	]
	d.briefing_messages = [
		_msg("spk_arbitre", "msg_arb_day30_promo", V_COMMISSION, _cond([], [&"promotion_revoked"], {&"loyalty": 8}), &"", 1),
		_msg("spk_tycho", "msg_tycho_day30", V_LUCIOLES, null, &"", 1),
		_msg("spk_lucioles", "msg_luc_day30", V_LUCIOLES, _cond([], [&"dora_departed"], {&"lucioles_trust": 3}), &"", 2),
		_family_msg("spk_dora", "msg_dora_day30", _all([&"dora_departed"])),
		_family("msg_ilan_day30"),
	]
	return d


# ---------------------------------------------------------------------------
# Fabriques
# ---------------------------------------------------------------------------

static func _okafor_identity() -> Dictionary:
	return {&"faction_id": &"hal", &"given_name": "Adaeze", &"family_name": "Okafor", &"sex": Passenger.SEX_F,
			&"citizen_class": &"C-3", &"birth_date": GameDate.from_ymd(2145, 9, 22), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité", &"implants": PackedStringArray()}


## Kenji Lindgren, archiviste de l'Enquête (identité et visage de SC-23).
static func _lindgren(id: StringName, index: int, dialogue: StringName, on_approve: Dictionary[StringName, int],
		on_deny: Dictionary[StringName, int]) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = _scripted(id, index, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": EMPLOYER_AR}, [],
			dialogue, {}, on_approve, on_deny)
	s.identity_from_case = &"sc_23"
	s.appearance_from_case = &"sc_23"
	return s


## Question de l'Enquête (J22, J26) : Dire (`verite +1`, `aveux +1` si la
## vérité incrimine), Se taire ★ (`suspicion +1`), Accuser (+10 ₵).
static func _question(id: StringName, stem: String, incriminating: FlagCondition) -> EveningEventDef:
	var event: EveningEventDef = _event(id, EveningEventDef.Kind.CHOICE, 0, null, stem)
	var tell: EveningOptionDef = _option(&"tell", stem, 0, 0, {&"verite": 1}, 1)
	tell.label_key = "evt_enq_opt_tell"
	tell.conditional_flags = [_effect(&"", incriminating, {&"aveux": 1})]
	var silent: EveningOptionDef = _option(&"silent", stem, 0, 0, {&"suspicion": 1}, 0)
	silent.label_key = "evt_enq_opt_silent"
	var accuse: EveningOptionDef = _option(&"accuse", stem, 0, 10, {&"enquete_accused": 0, &"loyalty": 1, &"solidarite": -1,
			&"lucioles_trust": -1}, -1)
	accuse.label_key = "evt_enq_opt_accuse"
	event.options = [tell, silent, accuse]
	return event


static func _scripted(id: StringName, index: int, overrides: Dictionary, anomalies: Array[AnomalyType.Kind],
		dialogue: StringName, params: Dictionary = {}, on_approve: Dictionary[StringName, int] = {},
		on_deny: Dictionary[StringName, int] = {}) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = ScriptedCaseDef.new()
	s.id = id
	s.at_index = index
	s.passenger_overrides = overrides
	s.forced_anomalies = anomalies
	s.dialogue_id = dialogue
	s.injection_params = params
	s.flags_on_approve = on_approve
	s.flags_on_deny = on_deny
	return s


static func _effect(verdict: StringName, condition: FlagCondition, flags: Dictionary[StringName, int]) -> CaseEffectDef:
	var e: CaseEffectDef = CaseEffectDef.new()
	e.verdict = verdict
	e.condition = condition
	e.flags = flags
	return e


static func _item(kind: SlippedItem.Kind, label: String, text: String, allowed: Array[SlippedItem.Decision],
		default_decision: SlippedItem.Decision, effects: Dictionary[StringName, Dictionary], bonus: int = 0) -> SlippedItemDef:
	var item: SlippedItemDef = SlippedItemDef.new()
	item.kind = kind
	item.label_key = label
	item.text_key = text
	item.allowed = allowed
	item.default_decision = default_decision
	item.effects = effects
	item.report_bonus = bonus
	return item


static func _envelope(amount: int, effects: Dictionary[StringName, Dictionary]) -> SlippedItemDef:
	var e: SlippedItemDef = _item(SlippedItem.Kind.ENVELOPE, "wb_envelope_label", "", [KEEP, RETURN], RETURN, effects)
	e.amount = amount
	return e


static func _wanted(id: StringName, scripted_id: StringName, index: int, reason: String) -> WantedNoticeDef:
	var w: WantedNoticeDef = WantedNoticeDef.new()
	w.id = id
	w.scripted_case_id = scripted_id
	w.at_index = index
	w.reason_key = reason
	return w


static func _revocation(id: StringName, scripted_id: StringName, index: int) -> RevocationDef:
	var r: RevocationDef = RevocationDef.new()
	r.id = id
	r.scripted_case_id = scripted_id
	r.at_index = index
	return r


static func _summons(id: StringName, scripted_id: StringName, index: int, reason: String) -> SummonsDef:
	var s: SummonsDef = SummonsDef.new()
	s.id = id
	s.scripted_case_id = scripted_id
	s.at_index = index
	s.reason_key = reason
	return s


static func _announce(key: String, after_case: int, at_minute: int, condition: FlagCondition,
		ends_shift: bool = false) -> HallAnnouncementDef:
	var a: HallAnnouncementDef = HallAnnouncementDef.new()
	a.text_key = key
	a.after_case = after_case
	a.at_minute = at_minute
	a.condition = condition
	a.ends_shift = ends_shift
	return a


static func _all(flags: Array[StringName]) -> FlagCondition:
	return FlagCondition.make(flags)


static func _any(conditions: Array[FlagCondition]) -> FlagCondition:
	return FlagCondition.any(conditions)


static func _gauge(gauge: StringName, minimum: int) -> FlagCondition:
	return FlagCondition.make([], [], {gauge: minimum})


static func _cond(all_of: Array[StringName], none_of: Array[StringName], minimum: Dictionary[StringName, int] = {}) -> FlagCondition:
	return FlagCondition.make(all_of, none_of, minimum)


static func _msg(speaker: String, text: String, voice: int, condition: FlagCondition, group: StringName,
		priority: int) -> BriefingMessageDef:
	var m: BriefingMessageDef = BriefingMessageDef.new()
	m.speaker_key = speaker
	m.text_key = text
	m.voice = voice
	m.condition = condition
	m.group = group
	m.priority = priority
	return m


## Message narratif d'Ilan (emplacement « foyer », groupe `ilan`).
static func _family(text: String, condition: FlagCondition = null) -> BriefingMessageDef:
	return _family_msg("spk_ilan", text, condition)


static func _family_msg(speaker: String, text: String, condition: FlagCondition) -> BriefingMessageDef:
	var m: BriefingMessageDef = _msg(speaker, text, V_FAMILY, condition, &"ilan", 0)
	m.family_slot = true
	return m


static func _event(id: StringName, kind: EveningEventDef.Kind, order: int, condition: FlagCondition,
		stem: String) -> EveningEventDef:
	var e: EveningEventDef = EveningEventDef.new()
	e.id = id
	e.kind = kind
	e.order = order
	e.condition = condition
	if not stem.is_empty():
		e.title_key = stem + "_title"
		e.text_key = stem + "_text"
	return e


static func _letter(id: StringName, order: int, condition: FlagCondition, text: String,
		flags: Dictionary[StringName, int]) -> EveningEventDef:
	var e: EveningEventDef = _event(id, EveningEventDef.Kind.LETTER, order, condition, "")
	e.text_key = text
	e.flags = flags
	return e


static func _option(id: StringName, stem: String, cost: int, gain: int, flags: Dictionary[StringName, int],
		rank: int) -> EveningOptionDef:
	var o: EveningOptionDef = EveningOptionDef.new()
	o.id = id
	o.label_key = "%s_opt_%s" % [stem, id]
	o.result_key = "%s_res_%s" % [stem, id]
	o.cost = cost
	o.gain = gain
	o.flags = flags
	o.default_rank = rank
	return o
