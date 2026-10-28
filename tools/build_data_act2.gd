## Contenu de l'Acte II pour `tools/build_data.gd` (D-029) — fabriques
## statiques, chargées par `preload` (pas de `class_name` : outil).
##
## Source : `docs/ACT2.md` (§1.2 soirée pivot du J10, §2 progression J11–J20,
## §4 SC-23 → SC-50, §5 briefings / soirées / annonces, §6 barème) et les
## décisions D-076 → D-079. Les textes sont des clés de `data/i18n/fr.csv`.
## Le verdict attendu des cas reste calculé par le moteur (D-005) : les
## commentaires « attendu » sont l'intention, vérifiée par les tests.
extends RefCounted

const K := AnomalyType.Kind
const VK := VerdictKind.Kind
const KEEP := SlippedItem.Decision.KEEP
const RETURN := SlippedItem.Decision.RETURN
const REPORT := SlippedItem.Decision.REPORT

## Voix des briefings (`BriefingContent.Voice`).
const V_CONSORTIUM: int = 0
const V_MENTOR: int = 1
const V_FAMILY: int = 2
const V_LUCIOLES: int = 3
const V_INSPECTION: int = 4
const V_COMMISSION: int = 5
const V_BRULANTS: int = 6

## Onglet « Codes employeurs » (R25) : LORE §5 + ajouts ACT2 §3.6 (CV, BA, AT,
## BC, DT) ; PI, DL, EQ, CR pour les employeurs sans code du LORE (proposé).
const EMPLOYER_CODES: Dictionary[String, String] = {
	"Kessler-Ashe Orbital": "KA",
	"Valcourt-Hsu Logistique": "VH",
	"Ondine Synaptique": "ON",
	"Meridian Biosystèmes": "MB",
	"Hydroponie Ceres-Verte": "CV",
	"Banque Aurel": "BA",
	"Autorité de Transit": "AT",
	"Bureau de Continuité": "BC",
	"Dispensaire de Tycho": "DT",
	"Prospection indépendante": "PI",
	"Délégation tharsienne": "DL",
	"Équipage indépendant": "EQ",
	"Commission de Rééquilibrage": "CR",
}
## Postes tirés pour un contrat généré (R31 : recycleur, soins, hydroponie en pénurie).
const CONTRACT_POSTS: PackedStringArray = ["post_recycleur", "post_soins", "post_hydroponie", "post_manutention", "post_logistique", "post_maintenance"]
## Registre des cargos (R26) : les cargos dérivants du LORE, sauf le SILLAGE
## démantelé le 20.03.2187.
const VESSELS: PackedStringArray = ["Long-Ruban", "Pierre-Bleue", "Nadir", "Vasque", "Heliodore", "Mainsoleil",
		"Corail-9", "Basse-Marée", "Tessaride", "Cendre", "Kalliope", "Lointain", "Saint-Orbe", "Varech"]

## Visages fixés (`ScriptedCaseDef.fixed_appearance_seed`).
const OKONKWO_SEED: int = 0x0C0A_2141
const ILAN_SEED: int = 0x11A5_2152

const TABS_ACT1: PackedStringArray = ["origins", "implants", "symbols", "seals", "wanted"]
const F_STANDARD: Dictionary[StringName, float] = {&"tyc": 0.28, &"hal": 0.17, &"ter": 0.20, &"cer": 0.13, &"thr": 0.12, &"drv": 0.10}
const F_DRIFT: Dictionary[StringName, float] = {&"tyc": 0.26, &"hal": 0.16, &"ter": 0.18, &"cer": 0.13, &"thr": 0.11, &"drv": 0.16}
const F_TER: Dictionary[StringName, float] = {&"tyc": 0.26, &"hal": 0.16, &"ter": 0.24, &"cer": 0.12, &"thr": 0.12, &"drv": 0.10}

## R28 (QA-026) : jour de la règle et part des TER C-4 tirés en C-5 (asile).
const ASYLUM_FIRST_DAY: int = 15
const ASYLUM_CLASS_RATE_FIRST_DAY: float = 1.0
const ASYLUM_CLASS_RATE: float = 0.30
## Ordre des types de `anomaly_weights` (docs/ACT2.md §2.2, colonnes J11 → J20).
## QA-026 : `UNREGISTERED_VESSEL` ne s'applique qu'aux `DRV` porteurs d'un
## laissez-passer (≈ 10 % de la file) — son poids est un poids **conditionnel**,
## relevé à 0,20 dès le J14 pour que R26 reste exercée (≈ 2 % des anomalies) ;
## J15 : `EXPIRED_DOCUMENT` / `MISSING_DOCUMENT` relevés (attestation d'asile) ;
## `REVOKED_ID` n'est jamais tiré au hasard (entrées de `DayDef.revocations`,
## comme `WANTED_PERSON`) : poids 0 (il ne faisait que consommer des tirages).
const WEIGHT_KINDS: Array[AnomalyType.Kind] = [K.EXPIRED_DOCUMENT, K.MISSING_DOCUMENT, K.PORTRAIT_MISMATCH,
		K.ID_MISMATCH, K.NAME_MISMATCH, K.ORIGIN_ID_MISMATCH, K.PURPOSE_MISMATCH, K.WRONG_ISSUER, K.BIOSCAN_UNFIT,
		K.UNDECLARED_IMPLANT, K.BANNED_IMPLANT, K.IMPOSTOR_LOOKALIKE, K.RELATIVE_DOCUMENTS, K.BANNED_FACTION,
		K.INVALID_SEAL, K.MRZ_MISMATCH, K.WANTED_PERSON, K.CONTRACT_MISMATCH, K.UNREGISTERED_VESSEL,
		K.OUTDATED_FIRMWARE, K.REVOKED_ID]
const WEIGHTS: Dictionary[int, Array] = {
	11: [0.05, 0.05, 0.03, 0.05, 0.05, 0.04, 0.05, 0.04, 0.04, 0.06, 0.05, 0.08, 0.07, 0.07, 0.07, 0.06, 0.08, 0, 0, 0, 0],
	12: [0.05, 0.07, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.06, 0.22, 0, 0, 0],
	13: [0.05, 0.06, 0.03, 0.05, 0.05, 0.04, 0.05, 0.04, 0.04, 0.06, 0.05, 0.07, 0.06, 0.07, 0.06, 0.06, 0.06, 0.10, 0.15, 0, 0],
	14: [0.05, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.06, 0.08, 0.20, 0.18, 0],
	15: [0.10, 0.12, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.06, 0.06, 0.06, 0.07, 0.05, 0.06, 0.07, 0.20, 0.08, 0],
	16: [0.05, 0.05, 0.03, 0.04, 0.04, 0.03, 0.05, 0.03, 0.03, 0.05, 0.04, 0.07, 0.05, 0.06, 0.05, 0.05, 0.06, 0.07, 0.20, 0.07, 0],
	17: [0.04, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.06, 0.05, 0.06, 0.05, 0.05, 0.06, 0.06, 0.20, 0.06, 0],
	18: [0.04, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.06, 0.05, 0.15, 0.05, 0.05, 0.06, 0.06, 0.20, 0.06, 0],
	19: [0.05, 0.05, 0.03, 0.05, 0.05, 0.04, 0.05, 0.04, 0.04, 0.06, 0.05, 0.07, 0.06, 0.08, 0.06, 0.06, 0.06, 0.07, 0.20, 0.07, 0],
	20: [0.04, 0.04, 0.03, 0.04, 0.04, 0.03, 0.04, 0.03, 0.03, 0.05, 0.04, 0.07, 0.05, 0.07, 0.05, 0.05, 0.12, 0.06, 0.20, 0.06, 0],
}


# ---------------------------------------------------------------------------
# Barème (docs/ACT2.md §6.1, D-079)
# ---------------------------------------------------------------------------

static func configure_economy(e: EconomyDef) -> void:
	e.pivot_day = 10
	e.pivot_suspicion_divisor = 2
	e.ration_start_day = 11
	e.ration_self = 3
	e.ration_ilan = 4
	e.ration_noa = 3
	e.ration_dora = 4
	e.meter_surcharge = 1
	e.meter_fee = 10
	e.levy_rate = 0.30
	e.levy_floor = 40
	e.levy_days = PackedInt32Array([11, 17])
	e.food_raised = 12
	e.food_raise_day = 15
	e.oxygen_raised = 15
	e.oxygen_raise_day = 16
	e.medicine_raised = 20
	e.medicine_raise_day = 16
	e.lease_cost = 5
	e.ilan_job_income = 8
	e.ilan_job_first_day = 13
	e.bail = 60
	e.dora_ticket = 40
	e.drift2_cost = 60
	e.review_arrest_score = 5
	e.review_demote_score = 3
	e.review_retention = 40
	e.double_game2_threshold = 7
	e.air2_trust_threshold = 7
	e.glory2_loyalty_threshold = 7
	e.strike_solidarity_threshold = 3
	e.registre_threshold = 3
	e.drift2_min_present = 2


static func registered_vessels() -> PackedStringArray:
	var result: PackedStringArray = []
	for name: String in VESSELS:
		result.append(name.to_upper())
	return result


# ---------------------------------------------------------------------------
# J10 — soirée pivot « La Nuit des vannes » (docs/ACT2.md §1.2, §5.3, D-076)
# ---------------------------------------------------------------------------

static func pivot_events() -> Array[EveningEventDef]:
	# 1. Les vannes : ouvertes (Mira passée, confiance ≥ 4), échouées (Mira
	#    détenue), sinon avortées.
	var opened: EveningEventDef = _letter(&"d10_vannes_opened", 0, _cond([&"final_passed"], [], {&"lucioles_trust": 4}),
			"evt_d10_vannes_text_opened", {&"vannes_opened": 0})
	opened.title_key = "evt_d10_vannes_title"
	var failed: EveningEventDef = _letter(&"d10_vannes_failed", 0, _all([&"final_detained"]), "evt_d10_vannes_text_failed",
			{&"vannes_failed": 0})
	failed.title_key = "evt_d10_vannes_title"
	var not_opened: FlagCondition = FlagCondition.any([_cond([], [&"final_passed"]), FlagCondition.make([], [], {}, {&"lucioles_trust": 3})])
	var aborted_condition: FlagCondition = _cond([], [&"final_detained"])
	aborted_condition.any_of.assign([not_opened])
	var aborted: EveningEventDef = _letter(&"d10_vannes_aborted", 0, aborted_condition, "evt_d10_vannes_text_aborted",
			{&"vannes_aborted": 0})
	aborted.title_key = "evt_d10_vannes_title"
	# 3. Double jeu : ne termine plus la partie (jugé à la Revue du J17 ou au J20).
	var double: EveningEventDef = _letter(&"d10_double", 1, _cond([], [], {&"lucioles_trust": 3, &"loyalty": 3}),
			"evt_d10_double_text", {&"double_jeu_signale": 0, &"suspicion": 2})
	# 4. Le sort d'Ilan (soutenu·e au J9).
	var arrested: EveningEventDef = _letter(&"d10_ilan_arrested", 2, _all([&"ilan_supported", &"final_detained"]),
			"evt_d10_ilan_arrested", {&"ilan_arrested_vannes": 0})
	arrested.household = EveningOptionDef.HOUSEHOLD_ILAN_DETAINED
	var hiding: EveningEventDef = _letter(&"d10_ilan_hiding", 2, _cond([&"ilan_supported", &"final_passed"], [],
			{&"lucioles_trust": 4}), "evt_d10_ilan_hiding", {&"ilan_in_hiding": 0})
	hiding.household = EveningOptionDef.HOUSEHOLD_ILAN_SOUTE
	var back_condition: FlagCondition = _cond([&"ilan_supported"], [&"final_detained"])
	back_condition.any_of.assign([not_opened])
	var back: EveningEventDef = _letter(&"d10_ilan_back", 2, back_condition, "evt_d10_ilan_back", {})
	# 5. « C-2 à l'essai » (anciennes conditions de F4).
	var promo: EveningEventDef = _letter(&"d10_promo", 3, _cond([&"final_detained"], [],
			{&"loyalty": 3, EveningService.GAUGE_COMPLIANCE: 85, &"hh_alive": 2}), "evt_d10_promo_text", {&"promotion_offered": 0})
	promo.title_key = "evt_d10_promo_title"
	# 6. Quai 6, demain 05:00 : « Embarquer » termine la campagne (F6).
	var drift: EveningEventDef = _event(&"d10_drift", EveningEventDef.Kind.CHOICE, 4, _all([&"drift_passes_bought"]), "evt_d10_drift")
	var board: EveningOptionDef = _option(&"board", "evt_d10_drift", 0, 0, {&"drift_boarded": 0}, -1)
	board.ends_campaign = EndingService.F6_DRIFT
	drift.options = [board, _option(&"stay", "evt_d10_drift", 0, 20, {&"drift_stayed": 0}, 0)]
	return [opened, failed, aborted, double, arrested, hiding, back, promo, drift]


# ---------------------------------------------------------------------------
# J11–J20
# ---------------------------------------------------------------------------

## `sets[n - 1]` = RuleSet du jour n.
static func build_days(sets: Array[RuleSet]) -> Array[DayDef]:
	return [_day11(sets[10]), _day12(sets[11]), _day13(sets[12]), _day14(sets[13]), _day15(sets[14]),
			_day16(sets[15]), _day17(sets[16]), _day18(sets[17]), _day19(sets[18]), _day20(sets[19])]


static func _act2_day(n: int, rule_set: RuleSet, duration: float, count: int, count_weights: Array[float],
		factions: Dictionary[StringName, float], noise: float, luciole: float, quota: int, tabs: PackedStringArray) -> DayDef:
	var d: DayDef = DayDef.new()
	d.day_number = n
	d.game_date = GameDate.from_ymd(2187, 3, 13) + n - 1
	d.rule_set = rule_set
	d.duration_sec = duration
	d.passenger_count = count
	d.anomaly_count_weights = PackedFloat32Array(count_weights)
	var weights: Array = WEIGHTS[n]
	for i: int in WEIGHT_KINDS.size():
		var w: float = weights[i]
		if w > 0.0:
			d.anomaly_weights[WEIGHT_KINDS[i]] = w
	d.intro_text_key = "day%02d_intro" % n
	d.credit_per_correct = 5
	d.penalty_per_error = 5
	d.faction_weights = factions.duplicate()
	d.visor_down_rate = 0.20
	d.legit_noise_rate = noise
	d.bribe_rate = 0.05
	d.luciole_rate = luciole
	d.free_citations_per_day = 2
	d.penalty_escalated = 10
	d.detain_enabled = true
	d.has_evening = n < 20
	d.bribe_amounts = Vector2i(20, 30)
	d.rulebook_tabs = tabs
	d.air_quota = quota
	d.luciole_trust_on_breach = false
	# QA-026 : R28 (attestation d'asile, J15+) réellement exercée — plus de
	# porteurs le jour de la règle, attestation visée en priorité par
	# MISSING_DOCUMENT / EXPIRED_DOCUMENT quand le passager en porte une.
	if n >= ASYLUM_FIRST_DAY:
		d.focus_documents = [&"asylum"]
		d.asylum_class_rate = ASYLUM_CLASS_RATE_FIRST_DAY if n == ASYLUM_FIRST_DAY else ASYLUM_CLASS_RATE
	return d


static func _tabs(extra: PackedStringArray) -> PackedStringArray:
	var tabs: PackedStringArray = TABS_ACT1.duplicate()
	tabs.append_array(extra)
	return tabs


# --- J11 — vendredi 23.03 : la Commission, le quota --------------------------

static func _day11(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(11, rs, 720.0, 16, [0.42, 0.38, 0.15, 0.05], F_STANDARD, 0.35, 0.08, 5, TABS_ACT1)
	var lindgren: ScriptedCaseDef = _scripted(&"sc_23", 1, _lindgren_identity(), [], &"sc23_lindgren", {},
			{&"sc23_lindgren_passed": 0}, {&"sc23_lindgren_refused": 0})
	lindgren.slipped_item = _item(SlippedItem.Kind.FORM, "wb_form_label", "sc23_lindgren_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"lindgren_form_kept": 0}})
	var dmitri: ScriptedCaseDef = _scripted(&"sc_24", 4, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Kessler-Ashe Orbital", &"implants": PackedStringArray(["KIN-5"])}, [], &"sc24_dmitri", {},
			{&"sc24_dmitri_hired": 0}, {&"sc24_dmitri_refused": 0})
	dmitri.requires_flag = &"sc08_turned_away"
	dmitri.identity_from_case = &"sc_08"
	dmitri.appearance_from_case = &"sc_08"
	var elena: ScriptedCaseDef = _scripted(&"sc_25", 12, {&"faction_id": &"tyc", &"given_name": "Elena",
			&"family_name": "Navarro", &"sex": Passenger.SEX_F, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2156, 1, 19), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 7,
			&"implants": PackedStringArray()}, [], &"sc25_elena", {}, {&"sc25_elena_passed": 0}, {&"sc25_elena_turned_away": 0})
	elena.extra_tags = [&"companion_child"]
	elena.extra_effects = [_effect(&"approve", _gauge(&"lucioles_trust", 2), {&"lucioles_trust": 1}, CaseEffectDef.CONTEXT_QUOTA_REACHED)]
	d.scripted_cases = [lindgren, dmitri, elena]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 9, "wanted_generated_reason")]
	d.briefing_messages = [
		_msg("spk_commission", "msg_comm_day11_failed", V_COMMISSION, _all([&"vannes_failed"]), &"comm", 0),
		_msg("spk_commission", "msg_comm_day11", V_COMMISSION, null, &"comm", 0),
		_msg("spk_note", "msg_ilan_day11_hiding", V_FAMILY, _all([&"ilan_in_hiding"]), &"note", 1),
		_msg("spk_lucioles", "msg_luc_day11_place", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 1),
		_msg("spk_lucioles", "msg_luc_day11_opened", V_LUCIOLES, _all([&"vannes_opened"]), &"luc", 2),
		_msg("spk_lucioles", "msg_luc_day11_aborted", V_LUCIOLES, _cond([&"vannes_aborted"], [], {&"lucioles_trust": 1}), &"luc", 2),
		_msg("spk_brulants", "msg_brul_day11", V_BRULANTS, _all([&"vannes_failed"]), &"luc", 2),
		# QA-019 : le bulletin Albédo (vannes ouvertes) porte aussi l'annonce du
		# prélèvement (même groupe : un seul bulletin) ; priorité 0 : le joueur
		# est toujours prévenu des 30 % retenus le soir (plafond de 4 messages).
		_msg("spk_consortium", "msg_cons_day11_albedo", V_CONSORTIUM, _all([&"vannes_opened"]), &"levy", 0),
		_msg("spk_consortium", "msg_cons_day11_levy", V_CONSORTIUM, null, &"levy", 0),
		_family_msg("spk_dora", "msg_dora_day11_arrested", _all([&"ilan_arrested_vannes"])),
		_family("msg_ilan_day11"),
	]
	var levy: EveningEventDef = _letter(&"d11_levy", 0, null, "evt_d11_levy_text", {})
	levy.title_key = "evt_d11_levy_title"
	levy.text_gauges = ["levy_amount"]
	var meter: EveningEventDef = _event(&"d11_meter", EveningEventDef.Kind.CHOICE, 1, null, "evt_d11_meter")
	meter.options = [_option(&"pay", "evt_d11_meter", 10, 0, {&"meter_installed": 0}, 0),
			_option(&"refuse", "evt_d11_meter", 0, 0, {&"meter_refused": 0}, 1)]
	var petition: EveningEventDef = _event(&"d11_petition", EveningEventDef.Kind.CHOICE, 2, null, "evt_d11_petition")
	petition.options = [_option(&"sign", "evt_d11_petition", 0, 0, {&"petition_signed": 0, &"solidarite": 1}, 1),
			_option(&"ignore", "evt_d11_petition", 0, 0, {}, 0)]
	d.evening_events = [levy, meter, petition]
	return d


# --- J12 — samedi 24.03 : contrats de travail --------------------------------

static func _day12(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(12, rs, 735.0, 16, [0.40, 0.38, 0.17, 0.05], F_STANDARD, 0.35, 0.08, 5,
			_tabs(["employers"]))
	var elena: ScriptedCaseDef = _scripted(&"sc_26", 0, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 7,
			&"implants": PackedStringArray()}, [], &"sc26_elena", {}, {&"sc26_elena_passed": 0}, {&"sc26_elena_refused_again": 0})
	elena.requires_flag = &"sc25_elena_turned_away"
	elena.identity_from_case = &"sc_25"
	elena.appearance_from_case = &"sc_25"
	elena.extra_tags = [&"companion_child"]
	var margaux: ScriptedCaseDef = _scripted(&"sc_27", 3, {&"faction_id": &"hal", &"given_name": "Margaux",
			&"family_name": "Ferreira", &"sex": Passenger.SEX_F, &"citizen_class": &"C-2",
			&"birth_date": GameDate.from_ymd(2125, 5, 3), &"purpose": Passenger.PURPOSE_RETURN, &"employer": "Banque Aurel",
			&"implants": PackedStringArray()}, [], &"sc27_margaux", {}, {&"sc27_mistigri_passed": 0}, {&"sc27_mistigri_refused": 0})
	margaux.extra_tags = [&"prop_cat_crate"]
	margaux.third_party_documents = {&"work_contract": {&"given_name": "(FÉLIN)", &"family_name": "MISTIGRI",
			&"citizen_id": "HG-9000-CHAT", &"post": &"post_ratier", &"employer": "Hydroponie Ceres-Verte", &"employer_code": "CV",
			&"serial": "CT-CV-0412"}}
	var tariq: ScriptedCaseDef = _scripted(&"sc_28", 7, {&"faction_id": &"ter", &"given_name": "Tariq",
			&"family_name": "Benali", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2163, 7, 2), &"purpose": Passenger.PURPOSE_WORK, &"employer": "Hydroponie Ceres-Verte",
			&"post": &"post_hydroponie", &"implants": PackedStringArray()},
			[K.CONTRACT_MISMATCH], &"sc28_tariq", {&"document_id": &"work_contract", &"contract_code": "MB"},
			{&"sc28_tariq_passed": 0}, {&"sc28_tariq_refused": 0})
	var katya: ScriptedCaseDef = _scripted(&"sc_29", 11, {&"faction_id": &"thr", &"given_name": "Katya",
			&"family_name": "Mazur", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2149, 3, 8), &"employer": "Hydroponie Ceres-Verte", &"post": &"post_hydroponie",
			&"implants": PackedStringArray()}, [K.BANNED_FACTION], &"sc29_katya", {&"purpose": "work"},
			{&"sc29_katya_passed": 0}, {&"sc29_katya_locked_out": 0})
	katya.requires_flag = &"sc11_veteran_passed"
	katya.extra_documents = [&"work_contract"]
	katya.flags_on_detain = {&"sc29_katya_detained": 0}
	d.scripted_cases = [elena, margaux, tariq, katya]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 13, "wanted_generated_reason")]
	d.briefing_messages = [
		_msg("spk_sato", "msg_sato_day12", V_MENTOR, null, &"", 1),
		_msg("spk_hall", "msg_echo_sc25_turned_away", V_CONSORTIUM, _all([&"sc25_elena_turned_away"]), &"", 2),
		_overrun_msg(),
		_msg("spk_okonkwo", "msg_okonkwo_day12_quai", V_MENTOR, _all([&"okonkwo_shielded"]), &"", 1),
		_family("msg_ilan_day12"),
	]
	var job: EveningEventDef = _event(&"d12_job", EveningEventDef.Kind.CHOICE, 0, _cond([&"hh_ilan_present"], [&"ilan_estranged"]),
			"evt_d12_job")
	job.options = [_option(&"accept", "evt_d12_job", 0, 0, {&"ilan_meter_job": 0, &"loyalty": 1, &"lucioles_trust": -1}, 1),
			_option(&"refuse", "evt_d12_job", 0, 0, {&"ilan_job_refused": 0}, 0)]
	var page: EveningEventDef = _event(&"d12_page", EveningEventDef.Kind.CHOICE, 1, null, "evt_d12_page")
	page.condition = FlagCondition.any([_all([&"vannes_opened"]), _gauge(&"lucioles_trust", 4)])
	page.condition.none_of = [&"lucioles_hostile"]
	page.extra_keys = [ConditionalKey.make("evt_d12_page_text_lev", FlagCondition.any([_all([&"sc13_turned_back"]), _all([&"sc13_passed"])]))]
	page.options = [_option(&"keep", "evt_d12_page", 0, 0, {&"page_lucioles_kept": 0, &"registre": 1}, 0),
			_option(&"burn", "evt_d12_page", 0, 0, {&"page_burned": 0}, 1),
			_option(&"report", "evt_d12_page", 0, 10, {&"page_reported": 0, &"loyalty": 1, &"lucioles_trust": -2}, -1)]
	d.evening_events = [_bail_event(12), job, page]
	return d


# --- J13 — dimanche 25.03 : laissez-passer de dérive (respiration) -----------

static func _day13(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(13, rs, 720.0, 16, [0.45, 0.37, 0.14, 0.04], F_DRIFT, 0.35, 0.08, 5,
			_tabs(["employers", "vessels"]))
	var kerr1: ScriptedCaseDef = _scripted(&"sc_30", 3, _kerr(Passenger.SEX_F, GameDate.from_ymd(2152, 2, 2)), [],
			&"sc30_kerr", {}, {&"sc30_kerr_ok": 0}, {&"sc30_kerr_refused": 0})
	var kerr2: ScriptedCaseDef = _scripted(&"sc_31", 4, _kerr(Passenger.SEX_M, GameDate.from_ymd(2160, 9, 17)),
			[K.ID_MISMATCH], &"sc31_kerr", {&"document_id": &"entry_permit", &"field_path": "citizen_id",
			&"injected_value_from_case": "sc_32"}, {&"kerr_mixup_approved": 0}, {&"sc31_kerr_refused": 0})
	var kerr3: ScriptedCaseDef = _scripted(&"sc_32", 5, _kerr(Passenger.SEX_X, GameDate.from_ymd(2135, 12, 21)),
			[K.ID_MISMATCH], &"sc32_kerr", {&"document_id": &"entry_permit", &"field_path": "citizen_id",
			&"injected_value_from_case": "sc_31"}, {&"kerr_mixup_approved": 0}, {&"sc32_kerr_refused": 0})
	for verdict: StringName in [&"deny", &"detain"]:
		kerr3.extra_effects.append(_effect(verdict, _all([&"sc30_kerr_ok", &"sc31_kerr_refused"]), {&"kerr_all_correct": 0}))
	var corvo: ScriptedCaseDef = _scripted(&"sc_33", 9, {&"faction_id": &"drv", &"given_name": "Corvo",
			&"family_name": "Sillage", &"sex": Passenger.SEX_M, &"citizen_class": &"C-5", &"birth_date": GameDate.year_only(2119),
			&"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 3, &"implants": PackedStringArray()},
			[K.UNREGISTERED_VESSEL], &"sc33_corvo", {&"vessel": "SILLAGE"}, {&"sc33_corvo_passed": 0}, {&"sc33_corvo_refused": 0})
	corvo.slipped_item = _item(SlippedItem.Kind.OBJECT, "wb_object_label", "sc33_corvo_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"sc33_manifest_kept": 0, &"registre": 1}})
	d.scripted_cases = [kerr1, kerr2, kerr3, corvo]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 10, "wanted_generated_reason")]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc26_refused_again", V_CONSORTIUM, _all([&"sc26_elena_refused_again"]), &"", 2),
		_msg("spk_hall", "msg_echo_sc27_rats_down", V_CONSORTIUM, _all([&"sc27_mistigri_passed"]), &"rats", 3),
		_msg("spk_hall", "msg_echo_sc27_rats_up", V_CONSORTIUM, _all([&"sc27_mistigri_refused"]), &"rats", 3),
		_msg("spk_okonkwo", "msg_okonkwo_day13_katya", V_MENTOR, _all([&"sc29_katya_locked_out", &"okonkwo_shielded"]), &"", 1),
		_msg("spk_sato", "msg_sato_day13", V_MENTOR, null, &"", 1),
		_overrun_msg(),
		_family("msg_ilan_day13_dmitri", _all([&"sc24_dmitri_hired"])),
		_family("msg_ilan_day13"),
	]
	var vigil: EveningEventDef = _event(&"d13_vigil", EveningEventDef.Kind.CHOICE, 0, null, "evt_d13_vigil")
	vigil.options = [_option(&"pay", "evt_d13_vigil", 5, 0, {&"noa_armband": 0}, 0),
			_option(&"ignore", "evt_d13_vigil", 0, 0, {&"noa_armband_refused": 0, &"suspicion": 1}, 1)]
	var scanner: EveningEventDef = _event(&"d13_scanner", EveningEventDef.Kind.CHOICE, 1,
			_cond([], [&"lucioles_hostile"], {&"lucioles_trust": 3}), "evt_d13_scanner")
	scanner.options = [_option(&"install", "evt_d13_scanner", 0, 0, {&"scanner_luciole": 0, &"lucioles_trust": 1}, 1),
			_option(&"refuse", "evt_d13_scanner", 0, 0, {&"scanner_luciole_refused": 0}, 0)]
	var ecrou: EveningEventDef = _letter(&"d13_ecrou", 2, _all([&"sc33_manifest_kept"]), "evt_d13_ecrou", {})
	d.evening_events = [vigil, scanner, ecrou]
	return d


# --- J14 — lundi 26.03 : firmware NX, ACV-2, Okonkwo -------------------------

static func _day14(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(14, rs, 750.0, 17, [0.40, 0.38, 0.17, 0.05], F_STANDARD, 0.38, 0.08, 5,
			_tabs(["employers", "vessels"]))
	var hiro: ScriptedCaseDef = _scripted(&"sc_34", 2, {&"faction_id": &"hal", &"given_name": "Hiro",
			&"family_name": "Langlois", &"sex": Passenger.SEX_M, &"citizen_class": &"C-2",
			&"birth_date": GameDate.from_ymd(2143, 4, 5), &"purpose": Passenger.PURPOSE_RETURN, &"employer": "Ondine Synaptique",
			&"implants": PackedStringArray(["NX-18"])}, [K.OUTDATED_FIRMWARE], &"sc34_hiro", {&"firmware_age_days": 91},
			{&"sc34_hiro_passed": 0}, {&"sc34_hiro_refused": 0})
	hiro.extra_tags = [&"prop_shunt_led"]
	var okonkwo: Dictionary = {&"faction_id": &"ter", &"given_name": "Emeka", &"family_name": "Okonkwo",
			&"sex": Passenger.SEX_M, &"birth_date": GameDate.from_ymd(2141, 7, 9), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Autorité de Transit", &"post": &"post_manutention", &"implants": PackedStringArray()}
	var released_identity: Dictionary = okonkwo.duplicate()
	released_identity[&"citizen_class"] = &"C-5"
	var released: ScriptedCaseDef = _scripted(&"sc_35a", 8, released_identity, [K.MISSING_DOCUMENT], &"sc35_okonkwo_released",
			{&"document_id": &"bioscan"}, {&"sc35_okonkwo_helped": 0, &"solidarite": 1}, {&"sc35_okonkwo_refused": 0})
	released.condition = _all([&"okonkwo_denounced"])
	released.fixed_appearance_seed = OKONKWO_SEED
	var veilleur_identity: Dictionary = okonkwo.duplicate()
	veilleur_identity[&"given_name"] = "Bilal"
	veilleur_identity[&"family_name"] = "Tembo"
	veilleur_identity[&"citizen_class"] = &"C-4"
	var veilleur: ScriptedCaseDef = _scripted(&"sc_35b", 8, veilleur_identity, [K.WANTED_PERSON], &"sc35_okonkwo_veilleur", {},
			{&"sc35_okonkwo_passed": 0, &"lucioles_trust": 1, &"solidarite": 1}, {&"sc35_okonkwo_turned_back": 0})
	veilleur.flags_on_detain = {&"sc35_okonkwo_detained": 0, &"loyalty": 2, &"lucioles_trust": -2, &"solidarite": -2}
	veilleur.truth_overrides = {&"given_name": "Emeka", &"family_name": "Okonkwo"}
	veilleur.condition = _all([&"okonkwo_warned"])
	veilleur.fixed_appearance_seed = OKONKWO_SEED
	var quai_identity: Dictionary = okonkwo.duplicate()
	quai_identity[&"citizen_class"] = &"C-3"
	var quai: ScriptedCaseDef = _scripted(&"sc_35c", 8, quai_identity, [K.EXPIRED_DOCUMENT], &"sc35_okonkwo_quai",
			{&"document_id": &"work_contract", &"expired_days": 1}, {&"sc35_okonkwo_helped": 0, &"solidarite": 1},
			{&"sc35_okonkwo_refused": 0})
	quai.condition = _all([&"okonkwo_shielded"])
	quai.fixed_appearance_seed = OKONKWO_SEED
	d.scripted_cases = [hiro, released, veilleur, quai]
	d.wanted_notices = [
		_wanted(&"wanted_okonkwo", &"sc_35b", -1, "wanted_okonkwo_reason", "Emeka", "Okonkwo"),
		_wanted(&"wanted_generated", &"", 12, "wanted_generated_reason"),
	]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_kerr_mixup", V_CONSORTIUM, _all([&"kerr_mixup_approved"]), &"kerr", 3),
		_msg("spk_sato", "msg_sato_day14_kerr", V_MENTOR, _all([&"kerr_all_correct"]), &"kerr", 2),
		_msg("spk_lucioles", "msg_luc_day14", V_LUCIOLES, _cond([&"okonkwo_warned"], [], {&"lucioles_trust": 1}), &"", 1),
		_msg("spk_hall", "msg_hall_day14_okonkwo", V_CONSORTIUM, _all([&"okonkwo_denounced"]), &"", 1),
		_overrun_msg(),
		_family("msg_ilan_day14"),
	]
	var names: EveningEventDef = _event(&"d14_names", EveningEventDef.Kind.CHOICE, 0, _all([&"dora_told_puits9", &"hh_dora_present"]),
			"evt_d14_names")
	names.options = [_option(&"write", "evt_d14_names", 0, 0, {&"dora_names_written": 0, &"registre": 1}, 0),
			_option(&"sleep", "evt_d14_names", 0, 0, {}, 1)]
	var lease: EveningEventDef = _event(&"d14_lease", EveningEventDef.Kind.CHOICE, 1, null, "evt_d14_lease")
	lease.options = [_option(&"take", "evt_d14_lease", 5, 0, {&"scanner_consortium": 0, &"loyalty": 1}, 1),
			_option(&"decline", "evt_d14_lease", 0, 0, {&"lease_declined": 0}, 0)]
	var noor: EveningEventDef = _letter(&"d14_noor", 2, _all([&"hh_any_sick", &"sc09_doctor_passed"]), "evt_d14_noor", {})
	noor.line_costs = {&"meds": 5}
	d.evening_events = [_bail_event(14), names, lease, noor]
	return d


# --- J15 — mardi 27.03 : attestation d'asile, quota 4 ------------------------

static func _day15(rs: RuleSet) -> DayDef:
	# QA-026 : file plus gravitaire le jour de l'attestation d'asile (R28).
	var d: DayDef = _act2_day(15, rs, 750.0, 17, [0.40, 0.38, 0.17, 0.05], F_TER, 0.38, 0.08, 4,
			_tabs(["employers", "vessels"]))
	var lindgren: ScriptedCaseDef = _lindgren_again(&"sc_36", 4, [K.EXPIRED_DOCUMENT], &"sc36_lindgren",
			{&"document_id": &"id_card", &"expired_days": 1}, {&"sc36_lindgren_passed": 0}, {&"sc36_lindgren_refused": 0})
	lindgren.line_variants = [ConditionalKey.make("sc36_lindgren_arrival_refused", _all([&"sc23_lindgren_refused"]), "arrival")]
	var fatou: ScriptedCaseDef = _scripted(&"sc_37", 10, {&"faction_id": &"ter", &"given_name": "Fatou",
			&"family_name": "Mensah", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2157, 6, 12), &"purpose": Passenger.PURPOSE_WORK, &"employer": "Hydroponie Ceres-Verte",
			&"post": &"post_hydroponie", &"implants": PackedStringArray()}, [], &"sc37_fatou", {},
			{&"sc37_fatou_passed": 0}, {&"sc37_fatou_turned_away": 0})
	fatou.requires_flag = &"sc17_turned_back"
	fatou.appearance_from_case = &"sc_17"
	fatou.extra_tags = [&"companion_child"]
	fatou.extra_effects = [_effect(&"approve", _gauge(&"lucioles_trust", 2), {&"lucioles_trust": 1}, CaseEffectDef.CONTEXT_QUOTA_REACHED)]
	d.scripted_cases = [lindgren, fatou]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 14, "wanted_generated_reason")]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc28_ring", V_CONSORTIUM, _all([&"sc28_tariq_refused"]), &"sc28", 3),
		_msg("spk_hall", "msg_echo_sc28_arrested", V_CONSORTIUM, _all([&"sc28_tariq_passed"]), &"sc28", 3),
		_msg("spk_hall", "msg_echo_ondine_sorry", V_CONSORTIUM,
				FlagCondition.any([_all([&"sc34_hiro_refused"]), _all([&"sc34_hiro_passed"])]), &"", 3),
		_msg("spk_hall", "msg_echo_sc35_detained", V_CONSORTIUM, _all([&"sc35_okonkwo_detained"]), &"", 2),
		_msg("spk_lucioles", "msg_luc_day15", V_LUCIOLES, _cond([&"sc17_turned_back"], [], {&"lucioles_trust": 2}), &"", 1),
		_overrun_msg(),
		_family("msg_ilan_day15"),
	]
	var fund: EveningEventDef = _event(&"d15_fund", EveningEventDef.Kind.CHOICE, 0, null, "evt_d15_fund")
	fund.options = [_option(&"give", "evt_d15_fund", 10, 0, {&"fund_given": 0, &"solidarite": 1}, 1),
			_option(&"pass", "evt_d15_fund", 0, 0, {}, 0),
			_option(&"report", "evt_d15_fund", 0, 0, {&"fund_reported": 0, &"loyalty": 1, &"solidarite": -2}, -1)]
	var food: EveningEventDef = _letter(&"d15_food", 1, null, "evt_d15_food", {})
	var back: EveningEventDef = _letter(&"d15_ilan_back", 2, _all([&"ilan_in_hiding", &"hh_ilan_away"]), "evt_d15_ilan_back",
			{&"ilan_returned": 0})
	back.household = EveningOptionDef.HOUSEHOLD_ILAN_BACK
	d.evening_events = [fund, food, back]
	return d


# --- J16 — mercredi 28.03 : couvre-feu respiratoire --------------------------

static func _day16(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(16, rs, 765.0, 17, [0.40, 0.37, 0.18, 0.05], F_STANDARD, 0.38, 0.08, 4,
			_tabs(["employers", "vessels"]))
	var sato: ScriptedCaseDef = _scripted(&"sc_38", 3, {&"faction_id": &"hal", &"given_name": "Aurelio",
			&"family_name": "Sato", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2161, 10, 10), &"purpose": Passenger.PURPOSE_RETURN, &"employer": "Bureau de Continuité",
			&"implants": PackedStringArray()}, [K.NAME_MISMATCH], &"sc38_sato",
			{&"field_path": "family_name", &"document_id": &"bioscan", &"injected_value": "Satō"},
			{&"sc38_sato_reported": 0, &"suspicion": 1}, {&"sc38_sato_impressed": 0})
	var leila: ScriptedCaseDef = _scripted(&"sc_39", 13, {&"faction_id": &"ter", &"given_name": "Leila",
			&"family_name": "Haddad", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2147, 4, 22), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 3,
			&"implants": PackedStringArray()}, [], &"sc39_leila", {}, {&"sc39_leila_passed": 0}, {&"sc39_leila_late": 0})
	d.scripted_cases = [sato, leila]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 9, "wanted_generated_reason")]
	d.announcements = [_announce("hall_j16_curfew", -1, 16 * 60, null)]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc37_turned_away", V_CONSORTIUM, _all([&"sc37_fatou_turned_away"]), &"", 2),
		_msg("spk_commission", "msg_comm_day16", V_COMMISSION, null, &"", 1),
		_msg("spk_sato", "msg_sato_day16", V_MENTOR, null, &"", 2),
		_overrun_msg(),
		_family("msg_ilan_day16"),
	]
	var call: EveningEventDef = _event(&"d16_call", EveningEventDef.Kind.CHOICE, 0, null, "evt_d16_call")
	call.condition = FlagCondition.any([_all([&"ilan_supported"]), _all([&"ilan_meter_job"]), _gauge(&"lucioles_trust", 4)])
	call.condition.all_of = [&"hh_ilan_present"]
	call.condition.none_of = [&"ilan_estranged"]
	call.text_variants = [ConditionalKey.make("evt_d16_call_text_meter", _all([&"ilan_meter_job"]))]
	var go: EveningOptionDef = _option(&"go", "evt_d16_call", 0, 0, {&"ilan_joined_soute": 0, &"lucioles_trust": 1}, 1)
	go.household = EveningOptionDef.HOUSEHOLD_ILAN_SOUTE
	call.options = [go, _option(&"stay", "evt_d16_call", 0, 0, {&"ilan_stayed": 0}, 0)]
	var unplug: EveningEventDef = _event(&"d16_unplug", EveningEventDef.Kind.CHOICE, 1,
			_cond([&"scanner_luciole"], [&"scanner_luciole_removed", &"scanner_consortium"]), "evt_d16_unplug")
	unplug.options = [_option(&"unplug", "evt_d16_unplug", 0, 0, {&"scanner_luciole_removed": 0}, 0),
			_option(&"keep", "evt_d16_unplug", 0, 0, {&"scanner_luciole_kept": 0}, 1)]
	var tariffs: EveningEventDef = _letter(&"d16_tariffs", 2, null, "evt_d16_tariffs", {})
	d.evening_events = [_bail_event(16), call, unplug, tariffs]
	return d


# --- J17 — jeudi 29.03 : révocations, la Revue --------------------------------

static func _day17(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(17, rs, 765.0, 17, [0.38, 0.38, 0.18, 0.06], F_STANDARD, 0.40, 0.06, 4,
			_tabs(["employers", "vessels", "revoked"]))
	var valentin: ScriptedCaseDef = _scripted(&"sc_40", 2, {&"faction_id": &"hal", &"given_name": "Valentin",
			&"family_name": "Choi", &"sex": Passenger.SEX_M, &"citizen_class": &"C-2",
			&"birth_date": GameDate.from_ymd(2144, 8, 12), &"purpose": Passenger.PURPOSE_RETURN, &"employer": "Kessler-Ashe Orbital",
			&"implants": PackedStringArray()}, [K.REVOKED_ID], &"sc40_valentin", {},
			{&"sc40_valentin_passed": 0, &"lucioles_trust": 1}, {&"sc40_valentin_revoked": 0})
	var sato: ScriptedCaseDef = _scripted(&"sc_41", 7, {&"faction_id": &"hal", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN, &"employer": "Bureau de Continuité",
			&"implants": PackedStringArray()}, [K.REVOKED_ID], &"sc41_sato", {},
			{&"sc41_sato_spared": 0, &"solidarite": 1}, {&"sc41_sato_revoked": 0})
	sato.identity_from_case = &"sc_38"
	sato.appearance_from_case = &"sc_38"
	d.scripted_cases = [valentin, sato]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 13, "wanted_generated_reason")]
	d.revocations = [_revocation(&"revoked_choi", &"sc_40", -1), _revocation(&"revoked_sato", &"sc_41", -1),
			_revocation(&"revoked_generated", &"", 11)]
	d.revoked_decoys = 4
	d.hall_announcements = {3: "hall_j17_review"}
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc39_late", V_CONSORTIUM, _all([&"sc39_leila_late"]), &"", 2),
		_msg("spk_sato", "msg_sato_day17_impressed", V_MENTOR, _all([&"sc38_sato_impressed"]), &"sato", 1),
		_msg("spk_sato", "msg_sato_day17_reported", V_MENTOR, _all([&"sc38_sato_reported"]), &"sato", 1),
		_msg("spk_commission", "msg_comm_day17", V_COMMISSION, null, &"", 0),
		_overrun_msg(),
		_family("msg_ilan_day17"),
	]
	var review: EveningEventDef = _event(&"d17_review", EveningEventDef.Kind.AUDIT, 0, null, "")
	review.title_key = "evt_d17_review_title"
	review.audit_id = EndingService.AUDIT_REVIEW
	var listing: EveningEventDef = _event(&"d17_list", EveningEventDef.Kind.CHOICE, 1, null, "evt_d17_list")
	listing.options = [
		_option(&"sign", "evt_d17_list", 0, 15, {&"colleagues_listed": 0, &"loyalty": 2, &"solidarite": -2}, -1),
		_option(&"refuse", "evt_d17_list", 0, 0, {&"colleagues_refused": 0, &"solidarite": 1, &"suspicion": 1}, 0),
		_option(&"warn", "evt_d17_list", 0, 0, {&"colleagues_warned": 0, &"solidarite": 2, &"suspicion": 1, &"loyalty": -1}, 1),
	]
	var file: EveningEventDef = _event(&"d17_file", EveningEventDef.Kind.CHOICE, 2, null, "evt_d17_file")
	file.options = [_option(&"copy", "evt_d17_file", 0, 0, {&"puits9_file_copied": 0, &"registre": 1, &"suspicion": 1}, 1),
			_option(&"leave", "evt_d17_file", 0, 0, {}, 0)]
	var mira: EveningEventDef = _letter(&"d17_mira", 3, _all([&"final_detained"]), "evt_d17_mira", {&"mira_escaped": 0})
	d.evening_events = [review, listing, file, mira]
	return d


# --- J18 — vendredi 30.03 : le Puits est clos, la Commissaire ----------------

static func _day18(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(18, rs, 780.0, 18, [0.36, 0.38, 0.20, 0.06], F_TER, 0.40, 0.06, 4,
			_tabs(["employers", "vessels", "revoked"]))
	var beaumont: ScriptedCaseDef = _scripted(&"sc_42", 1, {&"faction_id": &"hal", &"given_name": "Isadora",
			&"family_name": "Beaumont", &"sex": Passenger.SEX_F, &"citizen_class": &"C-1",
			&"birth_date": GameDate.from_ymd(2132, 11, 7), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Commission de Rééquilibrage", &"implants": PackedStringArray()}, [], &"sc42_beaumont", {},
			{&"beaumont_order": 0}, {&"beaumont_order": 0, &"beaumont_refused": 0})
	beaumont.extra_tags = [&"prop_drone"]
	var mateus: ScriptedCaseDef = _scripted(&"sc_43", 2, {&"faction_id": &"ter", &"given_name": "Mateus",
			&"family_name": "Silva", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2154, 3, 3), &"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital",
			&"post": &"post_recycleur", &"implants": PackedStringArray()}, [], &"sc43_mateus", {}, {}, {})
	var order: FlagCondition = _all([&"beaumont_order"])
	mateus.extra_effects = [
		_effect(&"approve", order, {&"beaumont_defied": 0, &"promotion_revoked": 0, &"loyalty": -1, &"suspicion": 1}),
		_effect(&"detain", order, {&"beaumont_obeyed": 0, &"sc43_mateus_detained": 0, &"loyalty": 2}),
		_effect(&"deny", order, {&"beaumont_half": 0}),
	]
	var lindgren: ScriptedCaseDef = _lindgren_again(&"sc_44", 12, [], &"sc44_lindgren", {}, {&"sc44_lindgren_passed": 0}, {})
	lindgren.slipped_item = _item(SlippedItem.Kind.FORM, "wb_form_label", "sc44_lindgren_note", [KEEP, RETURN], RETURN,
			{&"keep": {&"lindgren_signed": 0, &"registre": 1}})
	lindgren.line_variants = [ConditionalKey.make("sc44_lindgren_arrival_kept", _all([&"lindgren_form_kept"]), "arrival")]
	d.scripted_cases = [beaumont, mateus, lindgren]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 10, "wanted_generated_reason")]
	d.revocations = [_revocation(&"revoked_generated", &"", 15)]
	d.revoked_decoys = 4
	d.briefing_messages = [
		_msg("spk_hall", "msg_hall_day18_guichet03", V_CONSORTIUM, _all([&"sc41_sato_revoked"]), &"sato", 2),
		_msg("spk_sato_former", "msg_sato_day18_spared", V_MENTOR, _all([&"sc41_sato_spared"]), &"sato", 1),
		_msg("spk_lucioles", "msg_luc_day18", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 1),
		_overrun_msg(),
		_family("msg_ilan_day18"),
	]
	var dora: EveningEventDef = _event(&"d18_dora", EveningEventDef.Kind.CHOICE, 0, _all([&"hh_dora_present"]), "evt_d18_dora")
	var ticket: EveningOptionDef = _option(&"pay", "evt_d18_dora", 40, 0, {&"dora_departed": 0}, 1)
	ticket.household = EveningOptionDef.HOUSEHOLD_DORA_TYCHO
	dora.options = [ticket, _option(&"keep", "evt_d18_dora", 0, 0, {&"dora_stayed": 0}, 0)]
	var obeyed: EveningEventDef = _letter(&"d18_obeyed", 1, _all([&"beaumont_obeyed"]), "evt_d18_beaumont_obeyed",
			{&"promotion_offered": 0})
	var defied: EveningEventDef = _letter(&"d18_defied", 1, _all([&"beaumont_defied"]), "evt_d18_beaumont_defied",
			{&"promotion_revoked": 0})
	d.evening_events = [dora, obeyed, defied]
	return d


# --- J19 — samedi 31.03 : quota 3, le dernier cargo, le registre -------------

static func _day19(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(19, rs, 750.0, 17, [0.42, 0.38, 0.15, 0.05], F_STANDARD, 0.40, 0.08, 3,
			_tabs(["employers", "vessels", "revoked"]))
	var ravel: ScriptedCaseDef = _scripted(&"sc_45", 3, {&"faction_id": &"hal", &"given_name": "Corentin",
			&"family_name": "Ravel", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2146, 1, 9), &"purpose": Passenger.PURPOSE_RETURN, &"employer": "Bureau de Continuité",
			&"implants": PackedStringArray(["OPT-14"])}, [K.REVOKED_ID], &"sc45_ravel", {},
			{&"sc45_ravel_spared": 0, &"solidarite": 1}, {&"sc45_ravel_refused": 0})
	ravel.appearance_from_case = &"sc_12"
	ravel.slipped_item = _item(SlippedItem.Kind.FILE, "wb_file_label", "sc45_ravel_note", [KEEP, RETURN, REPORT], RETURN,
			{&"keep": {&"ravel_file_destroyed": 0, &"suspicion": -2}, &"report": {&"ravel_file_reported": 0, &"loyalty": 1}}, 10)
	ravel.line_variants = [
		ConditionalKey.make("sc45_ravel_confront_passed", _all([&"inspector_test_passed"]), "confront"),
		ConditionalKey.make("sc45_ravel_confront_kept", _all([&"inspector_bribe_taken"]), "confront"),
	]
	var wren: ScriptedCaseDef = _scripted(&"sc_46", 9, {&"faction_id": &"drv", &"given_name": "Wren",
			&"family_name": "Basse-Marée", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2142, 8, 30), &"purpose": Passenger.PURPOSE_TRADE,
			&"implants": PackedStringArray()}, [], &"sc46_wren", {}, {&"sc46_wren_passed": 0, &"drift2_offer": 0},
			{&"drift2_offer": 0})
	wren.flags_on_detain = {&"drift2_offer": 0}
	wren.appearance_from_case = &"sc_19"
	wren.slipped_item = _item(SlippedItem.Kind.DOCK_CARD, "wb_dock_card_label", "sc46_wren_note", [KEEP], KEEP, {})
	wren.line_variants = [ConditionalKey.make("sc46_wren_arrival_stayed", _all([&"drift_stayed"]), "arrival")]
	var kasimir: ScriptedCaseDef = _scripted(&"sc_47", 12, {&"faction_id": &"tyc", &"given_name": "Kasimir",
			&"family_name": "Oyelaran-Holm", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2153, 2, 14), &"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital",
			&"post": &"post_maintenance", &"implants": PackedStringArray()}, [K.UNDECLARED_IMPLANT], &"sc47_kasimir",
			{&"implant": "DER-19"}, {&"sc47_kasimir_passed": 0}, {&"sc47_kasimir_refused": 0})
	kasimir.flags_on_detain = {&"sc47_kasimir_detained": 0, &"loyalty": 1}
	kasimir.extra_tags = [CaseBuilder.TAG_LUCIOLE_PASSWORD]
	kasimir.password_grants_trust = false
	kasimir.flags_on_password = {&"sc47_password_answered": 0}
	kasimir.line_variants = [
		ConditionalKey.make("sc47_kasimir_arrival_pkg", _all([&"brulants_package"]), "arrival"),
		ConditionalKey.make("sc47_kasimir_arrival_arkady", _all([&"sc20_detained"]), "arrival"),
	]
	d.scripted_cases = [ravel, wren, kasimir]
	d.wanted_notices = [_wanted(&"wanted_generated", &"", 14, "wanted_generated_reason")]
	d.revocations = [_revocation(&"revoked_ravel", &"sc_45", -1), _revocation(&"revoked_generated", &"", 6)]
	d.revoked_decoys = 4
	d.briefing_messages = [
		_msg("spk_commission", "msg_comm_day19_obeyed", V_COMMISSION, _all([&"beaumont_obeyed"]), &"comm", 1),
		_msg("spk_commission", "msg_comm_day19_defied", V_COMMISSION, _all([&"beaumont_defied"]), &"comm", 1),
		_msg("spk_commission", "msg_comm_day19_half", V_COMMISSION, _all([&"beaumont_half"]), &"comm", 1),
		_msg("spk_okonkwo", "msg_okonkwo_day19_quai", V_MENTOR, _all([&"okonkwo_shielded"]), &"", 2),
		_msg("spk_lucioles", "msg_luc_day19_ilan", V_LUCIOLES, _all([&"ilan_joined_soute"]), &"luc", 0),
		_msg("spk_lucioles", "msg_luc_day19", V_LUCIOLES, _gauge(&"lucioles_trust", 3), &"luc", 0),
		_overrun_msg(),
		_family("msg_ilan_day19"),
	]
	var drift: EveningEventDef = _event(&"d19_drift", EveningEventDef.Kind.CHOICE, 0, _all([&"drift2_offer"]), "evt_d19_drift")
	drift.options = [_option(&"buy", "evt_d19_drift", 60, 0, {&"drift2_passes_bought": 0}, 1),
			_option(&"keep", "evt_d19_drift", 0, 0, {}, 0)]
	# Seuils lus dans l'`EconomyDef` à l'exécution (R28 : une seule source).
	var strike: EveningEventDef = _event(&"d19_strike", EveningEventDef.Kind.CHOICE, 1, null, "evt_d19_strike")
	strike.economy_gauges_min = {&"solidarite": &"strike_solidarity_threshold"}
	strike.options = [_option(&"join", "evt_d19_strike", 0, 0, {&"strike_joined": 0, &"loyalty": -2}, 1),
			_option(&"abstain", "evt_d19_strike", 0, 0, {}, 0)]
	var registre: EveningEventDef = _event(&"d19_registre", EveningEventDef.Kind.CHOICE, 2, null, "evt_d19_registre")
	registre.economy_gauges_min = {&"registre": &"registre_threshold"}
	registre.text_gauges = ["registre"]
	var surrender: EveningOptionDef = _option(&"surrender", "evt_d19_registre", 0, 20, {&"registre_surrendered": 0, &"loyalty": 2}, -1)
	surrender.set_gauges = {&"registre": 0}
	registre.options = [_option(&"send", "evt_d19_registre", 0, 0, {&"registre_sent": 0, &"suspicion": 2}, 1), surrender,
			_option(&"keep", "evt_d19_registre", 0, 0, {}, 0)]
	d.evening_events = [drift, strike, registre]
	return d


# --- J20 — dimanche 01.04 : la clé (pas de soirée) ---------------------------

static func _day20(rs: RuleSet) -> DayDef:
	var d: DayDef = _act2_day(20, rs, 780.0, 18, [0.36, 0.38, 0.20, 0.06], F_STANDARD, 0.40, 0.10, 3,
			_tabs(["employers", "vessels", "revoked"]))
	var today: int = d.game_date
	var paz: ScriptedCaseDef = _scripted(&"sc_48", 2, {&"faction_id": &"cer", &"given_name": "Paz", &"family_name": "Vela",
			&"sex": Passenger.SEX_F, &"citizen_class": &"C-4", &"birth_date": GameDate.from_ymd(2160, 4, 1),
			&"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 5, &"implants": PackedStringArray()}, [], &"sc48_paz", {},
			{&"sc48_paz_passed": 0}, {&"sc48_paz_refused": 0})
	paz.document_dates = {
		&"id_card": {"issue": GameDate.from_ymd(2177, 4, 1), "expiry": today},
		&"entry_permit": {"issue": today, "expiry": today + 5},
		&"bioscan": {"issue": today, "expiry": today + 30},
	}
	var signed: ScriptedCaseDef = _lindgren_again(&"sc_49a", 5, [], &"sc49_lindgren", {}, {&"sc49_lindgren_yes": 0}, {})
	signed.passenger_overrides[&"employer"] = "Commission de Rééquilibrage"
	signed.condition = _all([&"lindgren_signed"])
	var plain: ScriptedCaseDef = _lindgren_again(&"sc_49b", 5, [], &"sc49_lindgren", {}, {&"sc49_lindgren_yes": 0}, {})
	for lindgren: ScriptedCaseDef in [signed, plain]:
		lindgren.line_variants = [
			ConditionalKey.make("sc49_lindgren_arrival_signed", _all([&"lindgren_signed"]), "arrival"),
			ConditionalKey.make("sc49_lindgren_registre", _all([&"registre_sent"]), "stay"),
		]
	var ilan: ScriptedCaseDef = _scripted(&"sc_50a", 8, {&"faction_id": &"tyc", &"given_name": "Ilan",
			&"family_name": "Lindqvist-Rey", &"sex": Passenger.SEX_X, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2152, 3, 3), &"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital",
			&"post": &"post_recycleur", &"implants": PackedStringArray()}, [K.WANTED_PERSON], &"sc50_ilan", {},
			{&"final2_passed": 0, &"lucioles_trust": 1}, {&"final2_denied": 0})
	ilan.flags_on_detain = {&"final2_detained": 0, &"loyalty": 1, &"lucioles_trust": -2, &"ilan_detained_final": 0}
	ilan.flags_if_unprocessed = {&"final2_unprocessed": 0}
	ilan.condition = _all([&"ilan_joined_soute"])
	ilan.fixed_appearance_seed = ILAN_SEED
	ilan.luciole_codes = PackedInt32Array([4])
	var mira: ScriptedCaseDef = _scripted(&"sc_50b", 8, {
		&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
		&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc",
		&"citizen_id": "HG-4471-K2Q9", &"citizen_class": &"C-3",
		&"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital", &"post": &"post_recycleur",
		&"implants": PackedStringArray(),
	}, [K.WANTED_PERSON], &"sc50_mira", {}, {&"final2_passed": 0, &"lucioles_trust": 1}, {&"final2_denied": 0})
	mira.flags_on_detain = {&"final2_detained": 0, &"loyalty": 1, &"lucioles_trust": -2}
	mira.flags_if_unprocessed = {&"final2_unprocessed": 0}
	mira.appearance_from_case = &"sc_04"
	mira.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN}
	mira.luciole_codes = PackedInt32Array([4, 6, 7])
	mira.line_variants = [
		ConditionalKey.make("sc50_mira_arrival_detained", _all([&"final_detained"]), "arrival"),
		ConditionalKey.make("sc50_mira_arrival_passed", _all([&"final_passed"]), "arrival"),
	]
	d.scripted_cases = [paz, signed, plain, ilan, mira]
	var ilan_notice: WantedNoticeDef = _wanted(&"wanted_final_ilan", &"sc_50a", -1, "wanted_ilan_reason")
	var mira_notice: WantedNoticeDef = _wanted(&"wanted_final_mira", &"sc_50b", -1, "wanted_mira2_reason")
	var generated: WantedNoticeDef = _wanted(&"wanted_generated", &"", 14, "wanted_generated_reason")
	var kasimir_notice: WantedNoticeDef = _wanted(&"wanted_kasimir", &"", -1, "wanted_kasimir_reason")
	kasimir_notice.memory_case_id = &"sc_47"
	kasimir_notice.condition = _cond([], [&"sc47_kasimir_detained"])
	for notice: WantedNoticeDef in [ilan_notice, mira_notice, generated, kasimir_notice]:
		notice.faces_only = true
	d.wanted_notices = [ilan_notice, mira_notice, generated, kasimir_notice]
	d.revocations = [_revocation(&"revoked_generated", &"", 11)]
	d.revoked_decoys = 4
	d.announcements = [
		_announce("hall_j20_registre", 4, -1, _all([&"registre_sent"])),
		_announce("hall_j20_strike", 10, -1, _all([&"strike_joined"]), true),
	]
	d.briefing_messages = [
		_msg("spk_commission", "msg_comm_day20_promo", V_COMMISSION, _cond([], [&"promotion_revoked"], {&"loyalty": 5}), &"", 1),
		_msg("spk_commission", "msg_comm_day20_kasimir", V_COMMISSION, _all([&"sc47_kasimir_detained"]), &"", 2),
		_family_msg("spk_note", "msg_ilan_day20", _all([&"ilan_joined_soute"])),
		_family_msg("spk_dora", "msg_dora_day20_tycho", _all([&"dora_departed"])),
		_family("msg_ilan_day20_home"),
	]
	return d


# ---------------------------------------------------------------------------
# Fabriques
# ---------------------------------------------------------------------------

## Kenji Lindgren (SC-23) : archiviste du Bureau.
static func _lindgren_identity() -> Dictionary:
	return {&"faction_id": &"hal", &"given_name": "Kenji", &"family_name": "Lindgren", &"sex": Passenger.SEX_M,
			&"citizen_class": &"C-3", &"birth_date": GameDate.from_ymd(2139, 9, 14), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité", &"implants": PackedStringArray()}


## Lindgren revient (SC-36, SC-44, SC-49) : identité et visage de SC-23.
static func _lindgren_again(id: StringName, index: int, anomalies: Array[AnomalyType.Kind], dialogue: StringName,
		params: Dictionary, on_approve: Dictionary[StringName, int], on_deny: Dictionary[StringName, int]) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = _scripted(id, index, {&"faction_id": &"hal", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN, &"employer": "Bureau de Continuité",
			&"implants": PackedStringArray()}, anomalies, dialogue, params, on_approve, on_deny)
	s.identity_from_case = &"sc_23"
	s.appearance_from_case = &"sc_23"
	return s


## Ren Kerr (SC-30 → SC-32) : trois homonymes de Cérès.
static func _kerr(sex: StringName, birth: int) -> Dictionary:
	return {&"faction_id": &"cer", &"given_name": "Ren", &"family_name": "Kerr", &"sex": sex, &"citizen_class": &"C-4",
			&"birth_date": birth, &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 5, &"employer": "Prospection indépendante",
			&"implants": PackedStringArray()}


## La caution d'Ilan (J12, J14, J16), tant qu'Ilan est mis·e en attente.
static func _bail_event(day_number: int) -> EveningEventDef:
	var bail: EveningEventDef = _event(StringName("d%02d_bail" % day_number), EveningEventDef.Kind.CHOICE, 0,
			_all([&"hh_ilan_held"]), "evt_d12_bail")
	bail.text_variants = [ConditionalKey.make("evt_d12_bail_text_denounced", _all([&"ilan_denounced"]))]
	var pay: EveningOptionDef = _option(&"pay", "evt_d12_bail", 60, 0, {&"ilan_released": 0}, 0)
	pay.condition = _cond([], [&"ilan_denounced"])
	pay.household = EveningOptionDef.HOUSEHOLD_ILAN_RELEASED
	var pay_denounced: EveningOptionDef = _option(&"pay_denounced", "evt_d12_bail", 60, 0, {&"ilan_released": 0, &"ilan_estranged": 0}, 0)
	pay_denounced.label_key = "evt_d12_bail_opt_pay"
	pay_denounced.result_key = "evt_d12_bail_res_pay"
	pay_denounced.condition = _all([&"ilan_denounced"])
	pay_denounced.household = EveningOptionDef.HOUSEHOLD_ILAN_RELEASED
	bail.options = [pay, pay_denounced, _option(&"wait", "evt_d12_bail", 0, 0, {}, 1)]
	return bail


static func _overrun_msg() -> BriefingMessageDef:
	return _msg("spk_commission", "msg_comm_overrun", V_COMMISSION, _all([&"overrun_yesterday"]), &"overrun", 2)


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


static func _effect(verdict: StringName, condition: FlagCondition, flags: Dictionary[StringName, int],
		context: StringName = &"") -> CaseEffectDef:
	var e: CaseEffectDef = CaseEffectDef.new()
	e.verdict = verdict
	e.condition = condition
	e.flags = flags
	e.context = context
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


static func _wanted(id: StringName, scripted_id: StringName, index: int, reason: String, given: String = "",
		family: String = "") -> WantedNoticeDef:
	var w: WantedNoticeDef = WantedNoticeDef.new()
	w.id = id
	w.scripted_case_id = scripted_id
	w.at_index = index
	w.reason_key = reason
	w.given_name = given
	w.family_name = family
	return w


static func _revocation(id: StringName, scripted_id: StringName, index: int) -> RevocationDef:
	var r: RevocationDef = RevocationDef.new()
	r.id = id
	r.scripted_case_id = scripted_id
	r.at_index = index
	return r


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


## Message de l'emplacement « foyer » d'un autre locuteur (Dora, un mot).
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
