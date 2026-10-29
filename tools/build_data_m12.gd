## Contenu du jalon M12 « Rejouabilité » pour `tools/build_data.gd` (D-029) —
## fabriques statiques, chargées par `preload` (pas de `class_name` : outil).
##
## Source : `docs/M12.md` (§1 épilogue J31, §2 Garde de nuit, §3 événements de
## station, §4 échos SC-83 → SC-90, §5.2 table des personnages, §7.1 besoins
## B55, B60, B61, B63) et les décisions D-120 → D-133. Formats des ressources :
## lot A (`scripts/core/*_def.gd`, ARCHITECTURE §11). Les textes sont des clés
## de `data/i18n/fr.csv`. Le verdict attendu des cas reste calculé par le
## moteur (D-005) : les commentaires « attendu » sont l'intention, vérifiée par
## les tests (`tests/unit/test_m12_data.gd`, `test_m12_rules.gd`).
##
## Écarts d'index par rapport à M12 §4.0 (index occupés par un avis ou une
## révocation générés, vérifiés par `check_free_index`) : SC-83b J12 @14 (et
## non @13), SC-84b J18 @11 (et non @10), SC-88b J19 @7 (et non @6), SC-88a
## J27 @10 (et non @9, avis « Brûlants » conditionnel).
extends RefCounted

const Act2 := preload("res://tools/build_data_act2.gd")
const Act3 := preload("res://tools/build_data_act3.gd")

const K := AnomalyType.Kind
const KEEP := SlippedItem.Decision.KEEP
const RETURN := SlippedItem.Decision.RETURN
const REPORT := SlippedItem.Decision.REPORT
const CAT := Rule.RuleCategory

const V_CONSORTIUM: int = 0
const V_MENTOR: int = 1
const V_FAMILY: int = 2
const V_LUCIOLES: int = 3
const V_INSPECTION: int = 4
const V_COMMISSION: int = 5

## Visages fixés repris des actes II et III.
const OKONKWO_SEED: int = 0x0C0A_2141
const DORA_SEED: int = 0x0D0A_2122
const ILAN_SEED: int = 0x11A5_2152

## Émetteur de bio-scan agréé à Tycho (R41, monde D ; LORE §9 à compléter).
const ISSUER_DT: StringName = &"dispensaire_tycho"
const ISSUER_MERIDIAN: StringName = &"clinique_meridian"
const EMPLOYER_KA: String = "Kessler-Ashe Orbital"

## Mondes de l'épilogue (D-124).
const WORLDS: Array[StringName] = [&"a", &"b", &"c", &"d"]
## Variantes de fin → monde (M12 §1.3).
const ENDING_WORLDS: Dictionary[StringName, StringName] = {
	&"f1": &"a", &"f3": &"a", &"f4": &"a", &"f5b": &"a", &"f7": &"a",
	&"f5c": &"b", &"f5s": &"b", &"f9": &"b",
	&"f8": &"c", &"f10": &"c",
	&"f2": &"d", &"f6t": &"d", &"f6d": &"d",
}
## Jauge des admissions correctes de Tycho au J31 (F10, `%d`).
const PONT31: StringName = &"pont31"

## Onglets du Rulebook par monde.
const TABS: Dictionary[StringName, PackedStringArray] = {
	&"a": ["origins", "wanted", "employers"],
	&"b": ["origins", "implants", "wanted", "ledger", "revoked"],
	&"c": ["origins", "ledger", "summons"],
	&"d": ["origins", "implants", "wanted"],
}


# ---------------------------------------------------------------------------
# Dates
# ---------------------------------------------------------------------------

## J31 = vendredi 11.04.2188 (2188 bissextile : 366 jours après le J30).
static func epilogue_date() -> int:
	return GameDate.from_ymd(2188, 4, 11)


static func ymd88(month: int, day: int) -> int:
	return GameDate.from_ymd(2188, month, day)


# ---------------------------------------------------------------------------
# Règles R38 → R42 (M12 §1.5–§1.8, B55)
# ---------------------------------------------------------------------------

## Règles de l'épilogue (sauvegardées dans `data/rules/` par `build_data.gd`).
static func build_rules() -> Array[Rule]:
	# R38 « Tycho rééquilibrée » : TYC refusés sauf contrat CT-KA valide.
	var r38: FactionBannedRule = FactionBannedRule.new()
	r38.banned_faction_ids = [&"tyc"]
	r38.exempt_purposes = []
	r38.exempt_contract_codes = PackedStringArray(["KA"])
	# R39 « Accueil » : permis exigé des ressortissants, sauf répondant admis.
	var r39: RequireDocumentRule = RequireDocumentRule.new()
	r39.document_id = &"entry_permit"
	r39.exempt_faction_ids = [&"hal"]
	r39.exempt_if_sponsor = true
	# R40 « Liste du Conseil » : liste de l'onglet, réintégrations honorées.
	var r40: RevokedIdRule = RevokedIdRule.new()
	r40.list_title_key = "rb_tab_council"
	r40.honor_reinstatements = true
	# R41 « Émetteurs agréés (Tycho) » : Meridian ou Dispensaire de Tycho.
	var r41: IssuerAllowedRule = IssuerAllowedRule.new()
	r41.document_id = &"bioscan"
	r41.allowed_issuer_ids = [ISSUER_MERIDIAN, ISSUER_DT]
	# R42 « Cadres de Kessler-Ashe » : CT-KA de classe C-1 ou C-2, toutes origines.
	var r42: ContractSuspendedRule = ContractSuspendedRule.new()
	r42.any_origin = true
	r42.faction_ids = []
	r42.classes = [&"C-1", &"C-2"]
	r42.suspended_codes = PackedStringArray(["KA"])
	r42.employer_codes = employer_codes()
	return [
		Act3._rule(r38, &"r_ep_tycho_ka", CAT.FACTION, 2),
		Act3._rule(r39, &"r_ep_welcome", CAT.DOCUMENTS, 2),
		Act3._rule(r40, &"r_ep_council_list", CAT.IDENTITY, 2),
		Act3._rule(r41, &"r_ep_issuer_tycho", CAT.DOCUMENTS, 2),
		Act3._rule(r42, &"r_ep_ka_cadres", CAT.DOCUMENTS, 2),
	]


## Registre employeur → code (R25), recopié pour R42 (monde D sans R25).
static func employer_codes() -> Dictionary[String, String]:
	var codes: Dictionary[String, String] = {}
	var source: Dictionary = Act2.EMPLOYER_CODES
	for employer: Variant in source:
		codes[str(employer)] = str(source[employer])
	return codes


# ---------------------------------------------------------------------------
# Échos SC-83 → SC-89 (M12 §4, B60) — ajoutés aux jours de campagne
# ---------------------------------------------------------------------------

## Ajoute au jour `day` ses échos (cas, répliques, messages). Appelé par
## `build_data.gd` avant la sauvegarde de chaque jour de campagne. Renvoie les
## erreurs (index occupé…) ; vide si tout va bien.
static func extend_day(day: DayDef) -> PackedStringArray:
	var added: Array[ScriptedCaseDef] = echoes_for(day.day_number)
	var errors: PackedStringArray = []
	for scripted: ScriptedCaseDef in added:
		var problem: String = check_free_index(day, scripted.at_index, scripted.id)
		if not problem.is_empty():
			errors.append(problem)
	day.scripted_cases.append_array(added)
	match day.day_number:
		17:
			# SC-83a : l'habitué·e a parlé de la vanne 3 (J16) ; Ilan sourit.
			day.briefing_messages.append(Act3._msg("spk_ilan", "msg_ilan_day16_tech", V_FAMILY,
					Act3._all([&"sc83_tech_met"]), &"", 2))
		18:
			var owner: RevocationDef = Act3._revocation(&"revoked_sc84_owner", &"sc_84b", -1)
			owner.reason_key = "revoked_reason_fraud_1403"
			day.revocations.append(owner)
		26:
			# SC-87 : Idris est entré en mars, à la seconde tentative.
			for scripted: ScriptedCaseDef in day.scripted_cases:
				if scripted.id == &"sc_67":
					scripted.line_variants.insert(0, ConditionalKey.make("sc67_hana_arrival_idris",
							Act3._all([&"sc87_idris_passed"]), "arrival"))
	return errors


## Vide si l'index est libre dans le jour (cas scénarisés, avis, révocations,
## convocations, liens de répondant, emplacements de groupe), sinon un message.
static func check_free_index(day: DayDef, index: int, case_id: StringName) -> String:
	var where: String = "J%d @%d (%s)" % [day.day_number, index, case_id]
	if index < 0 or index >= day.passenger_count:
		return "%s : hors de la file (%d passagers)" % [where, day.passenger_count]
	for scripted: ScriptedCaseDef in day.scripted_cases:
		if scripted != null and scripted.at_index == index:
			return "%s : déjà pris par %s" % [where, scripted.id]
	for notice: WantedNoticeDef in day.wanted_notices:
		if notice != null and notice.scripted_case_id == &"" and notice.at_index == index:
			return "%s : avis %s" % [where, notice.id]
	for revocation: RevocationDef in day.revocations:
		if revocation != null and revocation.scripted_case_id == &"" and revocation.at_index == index:
			return "%s : révocation %s" % [where, revocation.id]
	for summons: SummonsDef in day.summons:
		if summons != null and summons.scripted_case_id == &"" and summons.at_index == index:
			return "%s : convocation %s" % [where, summons.id]
	if day.sponsor_links.has(index) or day.sponsor_links.values().has(index):
		return "%s : lien de répondant" % where
	for group: StringName in day.slot_groups:
		if day.slot_groups[group].has(index):
			return "%s : emplacement %s" % [where, group]
	return ""


## Cas d'écho d'un jour de campagne (vide s'il n'y en a pas).
static func echoes_for(day_number: int) -> Array[ScriptedCaseDef]:
	match day_number:
		4:
			return [_sc84_miner()]
		11:
			return _sc85_first_denied()
		12:
			return [_sc87_idris(), _sc83_demoted()]
		13:
			return _sc89_sefa()
		14:
			return [_sc86_kaito_again()]
		15:
			return [_sc86_kaito_declared()]
		16:
			return [_sc83_returning()]
		18:
			return [_sc84_owner()]
		19:
			return [_sc88_ngozi()]
		27:
			return [_sc88_fatou()]
	return []


static func _today(day_number: int) -> int:
	return Act3.date_of(day_number)


## SC-83a · J16 @8 — l'habitué·e de l'Anneau C, approuvé·e au J1.
static func _sc83_returning() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_83a", 8, {&"faction_id": &"hal", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc83_tech", {}, {&"sc83_tech_met": 0}, {})
	s.condition = Act3._all([&"cm_sc_01_approve"])
	s.identity_from_case = &"sc_01"
	s.appearance_from_case = &"sc_01"
	return s


## SC-83b · J12 @14 — refusé·e à tort au J1, revenu·e déclassé·e (C-4).
static func _sc83_demoted() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_83b", 14, {&"faction_id": &"hal", &"citizen_class": &"C-4",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc83_tech", {}, {&"sc83_tech_demoted": 0},
			{&"sc83_tech_demoted": 0})
	s.condition = Act3._all([&"cm_sc_01_deny"])
	s.identity_from_case = &"sc_01"
	s.appearance_from_case = &"sc_01"
	s.passenger_overrides[&"citizen_class"] = &"C-4"
	# Carte réémise le 20.03.2187 (classe C-4 · CONTRACTUEL).
	s.document_dates = {&"id_card": {"issue": Act3.ymd(3, 20), "expiry": GameDate.from_ymd(2192, 3, 20)}}
	s.line_variants = [
		ConditionalKey.make("sc83_tech_arrival_demoted", null, "arrival"),
		ConditionalKey.make("sc83_tech_present_demoted", null, "present"),
		ConditionalKey.make("sc83_tech_purpose_demoted", null, "purpose"),
		ConditionalKey.make("sc83_tech_exit_approve_demoted", null, "exit_approve"),
	]
	return s


## SC-84a · J4 @10 — le mineur refusé au J2 revient avec ses propres papiers.
static func _sc84_miner() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_84a", 10, {&"faction_id": &"tyc", &"sex": Passenger.SEX_M,
			&"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_WORK, &"employer": EMPLOYER_KA}, [], &"sc84_miner",
			{}, {&"sc84_miner_passed": 0}, {&"sc84_miner_refused": 0})
	s.condition = Act3._all([&"cm_sc_03_deny"])
	# Son vrai visage ; identité nouvelle (la sienne), tirée par le générateur.
	s.appearance_from_case = &"sc_03"
	return s


## SC-84b · J18 @11 — le vrai titulaire de la carte du J2, révoqué (R30).
static func _sc84_owner() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_84b", 11, {&"purpose": Passenger.PURPOSE_RETURN}, [K.REVOKED_ID],
			&"sc84_owner", {}, {&"sc84_owner_passed": 0}, {&"sc84_owner_refused": 0})
	s.condition = Act3._all([&"sc03_passed"])
	s.identity_from_case = &"sc_03"
	# Visage : celui de la photo présentée au J2 (`CaseMemory.photo_appearance`, B59).
	s.appearance_from_photo = &"sc_03"
	return s


## SC-85 · J11 @8 — la première personne refusée (a) ou passée sans rien (b).
static func _sc85_first_denied() -> Array[ScriptedCaseDef]:
	var result: Array[ScriptedCaseDef] = []
	for spec: Array in [[&"sc_85a", &"cm_tuto_missing_document_deny", Act3.ymd(3, 20)],
			[&"sc_85b", &"cm_tuto_missing_document_approve", Act3.ymd(3, 14)]]:
		var s: ScriptedCaseDef = Act3._scripted(spec[0], 8, {&"purpose": Passenger.PURPOSE_RETURN}, [],
				&"sc85_first_denied", {}, {&"sc85_passed": 0}, {})
		s.condition = Act3._all([spec[1]])
		s.identity_from_case = &"tuto_missing_document"
		s.appearance_from_case = &"tuto_missing_document"
		var issue: int = spec[2]
		s.document_dates = {&"id_card": {"issue": issue, "expiry": issue + 3650}}
		if spec[0] == &"sc_85b":
			s.line_variants = [
				ConditionalKey.make("sc85_first_denied_arrival_passed", null, "arrival"),
				ConditionalKey.make("sc85_first_denied_present_passed", null, "present"),
			]
		result.append(s)
	return result


static func _kaito() -> Dictionary:
	return {&"faction_id": &"cer", &"given_name": "Kaito", &"family_name": "Morrow", &"sex": Passenger.SEX_M,
			&"citizen_class": &"C-4", &"birth_date": GameDate.from_ymd(2155, 11, 30), &"purpose": Passenger.PURPOSE_TRADE,
			&"stay_days": 5}


## SC-86a · J15 @12 — Kaito, refusé ou détenu au J7, revient en règle (`DER-6`).
static func _sc86_kaito_declared() -> ScriptedCaseDef:
	var identity: Dictionary = _kaito()
	identity[&"implants"] = PackedStringArray(["DER-6"])
	var s: ScriptedCaseDef = Act3._scripted(&"sc_86a", 12, identity, [], &"sc86_kaito", {}, {&"sc86_kaito_passed": 0},
			{&"sc86_kaito_refused": 0})
	s.condition = Act3._any([Act3._all([&"cm_sc_14_deny"]), Act3._all([&"cm_sc_14_detain"])])
	s.appearance_from_case = &"sc_14"
	s.line_variants = [ConditionalKey.make("sc86_kaito_arrival_detained", Act3._all([&"cm_sc_14_detain"]), "arrival")]
	return s


## SC-86b · J14 @11 — Kaito, passé au J7, recommence (`DER-19` non déclaré, 25 ₵).
static func _sc86_kaito_again() -> ScriptedCaseDef:
	var identity: Dictionary = _kaito()
	identity[&"implants"] = PackedStringArray()
	var s: ScriptedCaseDef = Act3._scripted(&"sc_86b", 11, identity, [K.UNDECLARED_IMPLANT], &"sc86_kaito",
			{&"implant": "DER-19"}, {&"sc86_kaito_passed": 0, &"lucioles_trust": 1, &"suspicion": 1}, {})
	s.condition = Act3._all([&"sc14_passed"])
	s.appearance_from_case = &"sc_14"
	s.slipped_item = Act3._envelope(25, {&"keep": {&"sc86_bribe_kept": 0, &"suspicion": 1}})
	s.line_variants = [
		ConditionalKey.make("sc86_kaito_arrival_again", null, "arrival"),
		ConditionalKey.make("sc86_kaito_present_again", null, "present"),
		ConditionalKey.make("sc86_kaito_about_rule_violated_again", null, "about_implant"),
		ConditionalKey.make("sc86_kaito_exit_deny_again", null, "exit_deny"),
		ConditionalKey.make("sc86_kaito_exit_approve_again", null, "exit_approve"),
	]
	return s


## SC-87 · J12 @9 — Idris, diplomate refusé à tort au J8.
static func _sc87_idris() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_87", 9, {&"faction_id": &"thr", &"given_name": "Idris",
			&"family_name": "Hadid", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2134, 7, 7), &"purpose": Passenger.PURPOSE_DIPLOMATIC,
			&"employer": "Délégation tharsienne", &"implants": PackedStringArray()}, [], &"sc87_idris", {},
			{&"sc87_idris_passed": 0}, {&"sc87_idris_refused": 0})
	s.condition = Act3._all([&"cm_sc_15_deny"])
	s.appearance_from_case = &"sc_15"
	s.line_variants = [ConditionalKey.make("sc87_idris_arrival_split", Act3._all([&"sc16_family_split"]), "arrival")]
	return s


## SC-88a · J27 @10 — Fatou, mise en attente au J8, revient sous son nom.
static func _sc88_fatou() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_88a", 10, {&"faction_id": &"ter", &"given_name": "Fatou",
			&"family_name": "Mensah", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2157, 6, 12), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Hydroponie Ceres-Verte", &"post": &"post_hydroponie", &"implants": PackedStringArray()}, [],
			&"sc88_fatou", {}, {&"sc88_fatou_passed": 0}, {&"sc88_fatou_refused": 0})
	s.condition = Act3._all([&"sc17_detained"])
	s.appearance_from_case = &"sc_17"
	s.extra_tags = [&"companion_child"]
	return s


## SC-88b · J19 @7 — Fatou, passée au J8 sous le nom de sa sœur Ngozi : papiers
## de Ngozi (née le 04.02.2149) renouvelés, visage de Fatou (29 ans) → R18.
static func _sc88_ngozi() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_88b", 7, {&"faction_id": &"ter", &"given_name": "Fatou",
			&"family_name": "Mensah", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2157, 6, 12), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Hydroponie Ceres-Verte", &"post": &"post_hydroponie", &"implants": PackedStringArray()},
			[K.RELATIVE_DOCUMENTS], &"sc88_fatou",
			{&"relative_given_name": "Ngozi", &"relative_birth": GameDate.from_ymd(2149, 2, 4)},
			{&"sc88_fatou_passed2": 0}, {&"sc88_fatou_turned_back": 0})
	s.flags_on_detain = {&"sc88_fatou_detained": 0, &"loyalty": 1}
	s.condition = Act3._all([&"sc17_passed"])
	s.appearance_from_case = &"sc_17"
	s.extra_tags = [&"companion_child"]
	s.line_variants = [
		ConditionalKey.make("sc88_fatou_arrival_ngozi", null, "arrival"),
		ConditionalKey.make("sc88_fatou_present_ngozi", null, "present"),
		ConditionalKey.make("sc88_fatou_about_age_ngozi", null, "about_birth"),
		ConditionalKey.make("sc88_fatou_exit_detain_ngozi", null, "exit_detain"),
		ConditionalKey.make("sc88_fatou_exit_deny_ngozi", null, "exit_deny"),
		ConditionalKey.make("sc88_fatou_exit_approve_ngozi", null, "exit_approve"),
	]
	return s


## SC-89 · J13 @11 — Sefa, dont le mot a été remis (a) ou gardé (b).
static func _sc89_sefa() -> Array[ScriptedCaseDef]:
	var identity: Dictionary = {&"faction_id": &"drv", &"given_name": "Sefa", &"family_name": "Long-Ruban",
			&"sex": Passenger.SEX_F, &"citizen_class": &"C-5", &"birth_date": GameDate.year_only(2163),
			&"purpose": Passenger.PURPOSE_TRANSIT, &"implants": PackedStringArray()}
	var reported: ScriptedCaseDef = Act3._scripted(&"sc_89a", 11, identity.duplicate(), [K.UNREGISTERED_VESSEL],
			&"sc89_sefa", {&"vessel": "LONG-RUBAN"}, {&"sc89_sefa_passed": 0}, {&"sc89_sefa_refused": 0})
	reported.condition = Act3._all([&"sc18_note_reported"])
	reported.appearance_from_case = &"sc_18"
	# Le Long-Ruban est saisi le 22.03 : retiré du registre ce jour-là
	# seulement si le mot a été remis (règle du cas, ligne « Retirés »).
	var drift: DriftPassRule = DriftPassRule.new()
	drift.document_id = &"drift_pass"
	drift.applies_to_faction_ids = [&"drv"]
	drift.require_valid = true
	drift.registered_vessels = Act2.registered_vessels()
	drift.retired_vessels = {"BASSE-MARÉE": Act3.ymd(4, 2), "LONG-RUBAN": Act3.ymd(3, 22)}
	Act3._rule(drift, &"r_drift_pass", CAT.DOCUMENTS, 2)
	reported.rule_replacements = [drift]
	reported.line_variants = [ConditionalKey.make("sc89_sefa_exit_deny_reported", null, "exit_deny")]
	var kept: ScriptedCaseDef = Act3._scripted(&"sc_89b", 11, identity.duplicate(), [], &"sc89_sefa", {},
			{&"sc89_sefa_passed": 0}, {&"sc89_sefa_refused": 0})
	kept.condition = Act3._all([&"sc18_note_kept"])
	kept.appearance_from_case = &"sc_18"
	kept.extra_tags = [&"luciole_password"]
	kept.flags_on_password = {&"password_answered": 0}
	kept.line_variants = [
		ConditionalKey.make("sc89_sefa_purpose_kept", null, "purpose"),
		ConditionalKey.make("sc89_sefa_exit_approve_kept", null, "exit_approve"),
		ConditionalKey.make("sc89_sefa_luciole_reply_kept", null, "luciole_reply"),
		ConditionalKey.make("sc89_sefa_exit_deny_kept", null, "exit_deny"),
	]
	return [reported, kept]


# ---------------------------------------------------------------------------
# Épilogue J31 « Un an plus tard » (M12 §1, B61)
# ---------------------------------------------------------------------------

## RuleSets des quatre mondes (`rs_day31_a` … `rs_day31_d`), sauvegardés par
## `build_data.gd` dans `data/epilogue/`.
static func build_epilogue_rule_sets(rules: Dictionary[StringName, Rule]) -> Dictionary[StringName, RuleSet]:
	var ids: Dictionary[StringName, Array] = {
		&"a": [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match", &"r_permit_required", &"r_permit_valid",
				&"r_identity_fields_match", &"r_purpose_consistent", &"r_origin_block", &"r_identity_fraud_detain",
				&"r_apparent_age", &"r_tharsis_banned", &"r_mrz_valid", &"r_wanted_detain", &"r_air_quota",
				&"r_contract_required", &"r_contract_consistent", &"r_ep_tycho_ka"],
		&"b": [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match", &"r_permit_valid", &"r_face_uncovered",
				&"r_identity_fields_match", &"r_origin_block", &"r_implants_declared", &"r_banned_implants",
				&"r_identity_fraud_detain", &"r_mrz_valid", &"r_wanted_detain", &"r_ep_welcome", &"r_ep_council_list"],
		&"c": [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match", &"r_permit_required", &"r_permit_valid",
				&"r_identity_fields_match", &"r_purpose_consistent", &"r_origin_block", &"r_mrz_valid", &"r_sponsor",
				&"r_summons", &"r_tycho_closed"],
		&"d": [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match", &"r_identity_fields_match",
				&"r_origin_block", &"r_bioscan_required", &"r_bioscan_valid", &"r_bioscan_fit", &"r_implants_declared",
				&"r_banned_implants", &"r_wanted_detain", &"r_ep_issuer_tycho", &"r_ep_ka_cadres"],
	}
	var new_ids: Dictionary[StringName, Array] = {
		&"a": [&"r_ep_tycho_ka"], &"b": [&"r_ep_welcome", &"r_ep_council_list"], &"c": [],
		&"d": [&"r_ep_issuer_tycho", &"r_ep_ka_cadres"],
	}
	var result: Dictionary[StringName, RuleSet] = {}
	for world: StringName in WORLDS:
		var rs: RuleSet = RuleSet.new()
		rs.id = StringName("rs_day31_%s" % world)
		for rule_id: Variant in ids[world]:
			rs.rules.append(rules[StringName(str(rule_id))])
		rs.new_rule_ids.assign(new_ids[world])
		rs.required_document_ids = rs.compute_required_document_ids()
		result[world] = rs
	return result


## `DayDef` des quatre mondes (mode épilogue), dans l'ordre A, B, C, D.
static func build_epilogue_days(sets: Dictionary[StringName, RuleSet]) -> Dictionary[StringName, DayDef]:
	return {&"a": _day31_a(sets[&"a"]), &"b": _day31_b(sets[&"b"]), &"c": _day31_c(sets[&"c"]),
			&"d": _day31_d(sets[&"d"])}


## Poids des types (M12 §1.4 : passagers générés seulement).
const EPI_WEIGHTS: Dictionary[StringName, Dictionary] = {
	&"a": {K.EXPIRED_DOCUMENT: 0.12, K.MISSING_DOCUMENT: 0.08, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.08,
			K.NAME_MISMATCH: 0.08, K.ORIGIN_ID_MISMATCH: 0.06, K.PURPOSE_MISMATCH: 0.06, K.IMPOSTOR_LOOKALIKE: 0.05,
			K.RELATIVE_DOCUMENTS: 0.04, K.BANNED_FACTION: 0.14, K.MRZ_MISMATCH: 0.08, K.CONTRACT_MISMATCH: 0.07},
	&"b": {K.EXPIRED_DOCUMENT: 0.12, K.MISSING_DOCUMENT: 0.14, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.08,
			K.NAME_MISMATCH: 0.08, K.ORIGIN_ID_MISMATCH: 0.06, K.UNDECLARED_IMPLANT: 0.08, K.BANNED_IMPLANT: 0.06,
			K.IMPOSTOR_LOOKALIKE: 0.05, K.MRZ_MISMATCH: 0.08},
	&"c": {K.EXPIRED_DOCUMENT: 0.10, K.MISSING_DOCUMENT: 0.08, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.08,
			K.NAME_MISMATCH: 0.08, K.ORIGIN_ID_MISMATCH: 0.06, K.PURPOSE_MISMATCH: 0.06, K.MRZ_MISMATCH: 0.08,
			K.SPONSOR_MISMATCH: 1.0, K.FORGED_SUMMONS: 0.10, K.BANNED_FACTION: 0.10},
	&"d": {K.EXPIRED_DOCUMENT: 0.12, K.MISSING_DOCUMENT: 0.06, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.08,
			K.NAME_MISMATCH: 0.08, K.ORIGIN_ID_MISMATCH: 0.06, K.WRONG_ISSUER: 0.12, K.BIOSCAN_UNFIT: 0.08,
			K.UNDECLARED_IMPLANT: 0.06, K.BANNED_IMPLANT: 0.05, K.SUSPENDED_CONTRACT: 0.80},
}
const F_EPI: Dictionary[StringName, float] = {&"tyc": 0.30, &"hal": 0.25, &"ter": 0.18, &"cer": 0.12, &"thr": 0.10,
		&"drv": 0.05}
const F_EPI_D: Dictionary[StringName, float] = {&"tyc": 0.55, &"hal": 0.15, &"ter": 0.10, &"cer": 0.10, &"drv": 0.10}


static func _epilogue_day(world: StringName, rule_set: RuleSet, factions: Dictionary[StringName, float],
		luciole: float) -> DayDef:
	var d: DayDef = DayDef.new()
	d.day_number = 31
	d.game_date = epilogue_date()
	d.rule_set = rule_set
	d.duration_sec = 600.0
	d.passenger_count = 7
	d.anomaly_count_weights = PackedFloat32Array([0.40, 0.40, 0.17, 0.03])
	var weights: Dictionary = EPI_WEIGHTS[world]
	for kind: Variant in weights:
		var typed_kind: AnomalyType.Kind = kind
		if rule_set.can_detect(typed_kind):
			d.anomaly_weights[typed_kind] = weights[kind]
	d.intro_text_key = "day31_%s_intro" % world
	# D-123 : aucune économie (salaire et amendes à 0, citations « AVERTISSEMENT »).
	d.credit_per_correct = 0
	d.penalty_per_error = 0
	d.penalty_escalated = 0
	d.free_citations_per_day = 7
	d.faction_weights = factions.duplicate()
	d.visor_down_rate = 0.15
	d.legit_noise_rate = 0.35
	d.bribe_rate = 0.0
	d.luciole_rate = luciole
	d.luciole_trust_on_breach = false
	d.detain_enabled = true
	d.has_evening = false
	d.rulebook_tabs = TABS[world]
	d.mode = DayDef.MODE_EPILOGUE
	d.epilogue_world = world
	d.economy_disabled = true
	d.untimed = true
	return d


## Messages du foyer communs à A, B, C (M12 §1.5 : priorité, deux au plus).
static func _home_messages() -> Array[BriefingMessageDef]:
	return [
		Act3._msg("spk_note", "msg_foyer_day31_noa_coached", V_FAMILY, Act3._all([&"hh_noa_present", &"noa_coached"]),
				&"noa", 1),
		Act3._msg("spk_note", "msg_foyer_day31_noa", V_FAMILY, Act3._all([&"hh_noa_present"]), &"noa", 1),
		Act3._msg("spk_note", "msg_foyer_day31_away", V_FAMILY, Act3._all([&"epi_ending_f1"]), &"home", 2),
		Act3._msg("spk_note", "msg_foyer_day31_ilan_estranged", V_FAMILY,
				Act3._cond([&"hh_ilan_alive", &"ilan_estranged"], [&"ilan_reconciled"]), &"home", 2),
		Act3._msg("spk_note", "msg_foyer_day31_ilan", V_FAMILY, Act3._all([&"hh_ilan_present"]), &"home", 2),
		Act3._msg("spk_note", "msg_foyer_day31_dora", V_FAMILY, Act3._all([&"hh_dora_present"]), &"home", 2),
	]


## SC-90 « Le premier » (M12 §4.8) : @0 de tous les mondes.
static func _sc90(world: StringName) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_90", 0, {}, [], &"sc90_first", {}, {&"sc90_first_passed": 0},
			{&"sc90_first_refused": 0})
	s.identity_from_case = &"tuto_concordant"
	s.appearance_from_case = &"tuto_concordant"
	s.line_variants = [ConditionalKey.make("sc90_first_purpose_%s" % world, null, "purpose")]
	if world == &"c":
		# Monde C (R37) : une convocation du Bureau des Témoins l'exempte, quelle
		# que soit son origine (« écouter les dépositions à 12:20 »).
		s.passenger_overrides = {&"purpose": Passenger.PURPOSE_RETURN, &"summons_id": "ENQ-0411"}
	return s


static func _mira_identity(purpose: StringName) -> Dictionary:
	return {&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
			&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc", &"citizen_id": "HG-4471-K2Q9",
			&"citizen_class": &"C-3", &"purpose": purpose, &"implants": PackedStringArray()}


static func _dora_identity(purpose: StringName) -> Dictionary:
	return {&"faction_id": &"tyc", &"given_name": "Dora", &"family_name": "Lindqvist-Rey", &"sex": Passenger.SEX_F,
			&"citizen_class": &"C-4", &"birth_date": GameDate.from_ymd(2122, 6, 14), &"purpose": purpose, &"stay_days": 14,
			&"implants": PackedStringArray()}


static func _okonkwo_identity(citizen_class: StringName) -> Dictionary:
	return {&"faction_id": &"ter", &"given_name": "Emeka", &"family_name": "Okonkwo", &"sex": Passenger.SEX_M,
			&"birth_date": GameDate.from_ymd(2141, 7, 9), &"citizen_class": citizen_class,
			&"purpose": Passenger.PURPOSE_RETURN, &"stay_days": 30, &"implants": PackedStringArray()}


## Mira, visière baissée, phrase de passe (B, D) : `‹Lumika.›`.
static func _mira_luciole(s: ScriptedCaseDef, visor: bool) -> void:
	s.appearance_from_case = &"sc_04"
	if visor:
		s.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN}
	s.extra_tags = [&"luciole_password"]
	s.password_grants_trust = false


# --- Monde A — « La Continuité » ---------------------------------------------

static func _day31_a(rs: RuleSet) -> DayDef:
	var d: DayDef = _epilogue_day(&"a", rs, F_EPI, 0.0)
	d.air_quota = 3
	var sato_on: FlagCondition = Act3._any([Act3._all([&"sc54_sato_reinstated"]), Act3._all([&"sc41_sato_spared"])])
	# SC-91 (a) Sato inspecteur des bornes : MRZ « SAT0 » (un zéro), test → REFUSÉ.
	var inspector: ScriptedCaseDef = Act3._scripted(&"sc_91a", 2, {&"faction_id": &"hal", &"citizen_class": &"C-2",
			&"purpose": Passenger.PURPOSE_RETURN, &"employer": "Bureau de Continuité"}, [K.MRZ_MISMATCH], &"sc91_sato",
			{&"component": "family_name", &"mrz_value": "SAT0"}, {&"sc91_sato_passed": 0}, {&"sc91_sato_refused": 0})
	inspector.condition = sato_on
	inspector.identity_from_case = &"sc_38"
	inspector.appearance_from_case = &"sc_38"
	inspector.line_variants = [ConditionalKey.make("sc91_sato_about_mrz", null, "about_id_number")]
	# SC-91 (b) Sato déclassé (maintenance des bornes, C-4) → APPROUVÉ.
	var fallen: ScriptedCaseDef = Act3._scripted(&"sc_91b", 2, {&"faction_id": &"hal", &"citizen_class": &"C-4",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc91_sato_fallen", {}, {&"sc91_sato_passed": 0},
			{&"sc91_sato_refused": 0})
	fallen.identity_from_case = &"sc_38"
	fallen.appearance_from_case = &"sc_38"
	# SC-92 Okonkwo : (b) dénoncé > (c) dans la Soute > (a) retraité.
	var denounced: ScriptedCaseDef = Act3._scripted(&"sc_92b", 4, _okonkwo_identity(&"C-5"), [K.EXPIRED_DOCUMENT],
			&"sc92_okonkwo", {&"document_id": &"entry_permit", &"expired_days": 2}, {&"sc92_okonkwo_passed": 0},
			{&"sc92_okonkwo_refused": 0})
	denounced.condition = Act3._all([&"okonkwo_denounced"])
	var soute: ScriptedCaseDef = Act3._scripted(&"sc_92c", 4, _okonkwo_identity(&"C-3"), [], &"sc92_okonkwo", {},
			{&"sc92_okonkwo_passed": 0}, {&"sc92_okonkwo_refused": 0})
	soute.condition = Act3._all([&"okonkwo_warned"])
	var retired: ScriptedCaseDef = Act3._scripted(&"sc_92a", 4, _okonkwo_identity(&"C-3"), [], &"sc92_okonkwo", {},
			{&"sc92_okonkwo_passed": 0}, {&"sc92_okonkwo_refused": 0})
	retired.condition = Act3._any([Act3._all([&"okonkwo_shielded"]), Act3._all([&"sc75_okonkwo_passed"])])
	for variant: ScriptedCaseDef in [denounced, soute, retired]:
		variant.fixed_appearance_seed = OKONKWO_SEED
	denounced.line_variants = [
		ConditionalKey.make("sc92_okonkwo_arrival_denounced", null, "arrival"),
		ConditionalKey.make("sc92_okonkwo_present_denounced", null, "present"),
		ConditionalKey.make("sc92_okonkwo_purpose_denounced", null, "purpose"),
		ConditionalKey.make("sc92_okonkwo_confront_denounced", null, "confront"),
		ConditionalKey.make("sc92_okonkwo_exit_deny_denounced", null, "exit_deny"),
		ConditionalKey.make("sc92_okonkwo_exit_approve_denounced", null, "exit_approve"),
	]
	soute.line_variants = [
		ConditionalKey.make("sc92_okonkwo_arrival_soute", null, "arrival"),
		ConditionalKey.make("sc92_okonkwo_advice", null, "stay"),
		ConditionalKey.make("sc92_okonkwo_exit_approve_soute", null, "exit_approve"),
		ConditionalKey.make("sc92_okonkwo_exit_deny_soute", null, "exit_deny"),
	]
	retired.line_variants = [ConditionalKey.make("sc92_okonkwo_advice", null, "stay")]
	# SC-93 La figure : (a) Dora > (b) Mira > (c) Ilan > (d) le mot.
	var dora: ScriptedCaseDef = Act3._scripted(&"sc_93a", 6, _dora_identity(Passenger.PURPOSE_FAMILY_VISIT),
			[K.BANNED_FACTION], &"sc93_dora", {}, {&"sc93_dora_passed": 0}, {&"sc93_dora_refused": 0})
	dora.condition = Act3._all([&"final3_dora", &"dora_detained_final", &"hh_dora_alive"])
	dora.fixed_appearance_seed = DORA_SEED
	var mira_identity: Dictionary = _mira_identity(Passenger.PURPOSE_WORK)
	mira_identity[&"employer"] = EMPLOYER_KA
	mira_identity[&"post"] = &"post_manutention"
	var mira: ScriptedCaseDef = Act3._scripted(&"sc_93b", 6, mira_identity, [], &"sc93_mira", {},
			{&"sc93_mira_passed": 0}, {&"sc93_mira_refused": 0})
	mira.flags_on_detain = {&"sc93_mira_detained": 0}
	mira.condition = Act3._cond([&"final3_detained"], [&"final3_dora"])
	mira.appearance_from_case = &"sc_04"
	var ilan: ScriptedCaseDef = Act3._scripted(&"sc_93c", 6, {&"faction_id": &"tyc", &"given_name": "Ilan",
			&"family_name": "Lindqvist-Rey", &"sex": Passenger.SEX_X, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2152, 3, 3), &"purpose": Passenger.PURPOSE_WORK, &"employer": EMPLOYER_KA,
			&"post": &"post_recycleur", &"implants": PackedStringArray()}, [], &"sc93_ilan", {},
			{&"sc93_ilan_passed": 0}, {&"sc93_ilan_refused": 0})
	ilan.condition = Act3._all([&"hh_ilan_alive"])
	ilan.fixed_appearance_seed = ILAN_SEED
	ilan.line_variants = [ConditionalKey.make("sc93_ilan_arrival_estranged",
			Act3._cond([&"ilan_estranged"], [&"ilan_reconciled"]), "arrival")]
	var bearer: ScriptedCaseDef = Act3._scripted(&"sc_93d", 6, {&"faction_id": &"tyc"}, [], &"sc93_note", {}, {}, {})
	bearer.slipped_item = Act3._item(SlippedItem.Kind.NOTE, "wb_note_label", "sc93_note", [KEEP, REPORT], KEEP,
			{&"keep": {&"sc93_note_kept": 0}, &"report": {&"sc93_note_reported": 0}})
	d.scripted_cases = [_sc90(&"a"), inspector, fallen, denounced, soute, retired, dora, mira, ilan, bearer]
	d.wanted_notices = [Act3._wanted(&"wanted_generated", &"", 5, "wanted_generated_reason")]
	d.briefing_messages = _home_messages()
	return d


# --- Monde B — « L'Air commun » ----------------------------------------------

static func _day31_b(rs: RuleSet) -> DayDef:
	var d: DayDef = _epilogue_day(&"b", rs, F_EPI, 0.10)
	# R39 : part des ressortissants sans permis, avec un répondant plus tôt dans la file.
	d.family_visit_rates = {&"tyc": 0.35, &"ter": 0.35, &"cer": 0.35, &"thr": 0.35, &"drv": 0.35}
	var reinstated: FlagCondition = Act3._all([&"sc59_beaumont_spared", &"sc81b_beaumont_passed"])
	var not_reinstated: FlagCondition = Act3._any([Act3._cond([], [&"sc59_beaumont_spared"]),
			Act3._cond([], [&"sc81b_beaumont_passed"])])
	# SC-94 Beaumont, sur la Liste du Conseil (a) ou réintégrée (b).
	var listed: ScriptedCaseDef = Act3._scripted(&"sc_94a", 2, {&"faction_id": &"hal", &"citizen_class": &"C-1",
			&"purpose": Passenger.PURPOSE_RETURN}, [K.REVOKED_ID], &"sc94_beaumont", {}, {&"sc94_beaumont_passed": 0},
			{&"sc94_beaumont_refused": 0})
	listed.condition = not_reinstated
	listed.line_variants = [ConditionalKey.make("sc94_beaumont_exit_approve_irregular", null, "exit_approve")]
	var back: ScriptedCaseDef = Act3._scripted(&"sc_94b", 2, {&"faction_id": &"hal", &"citizen_class": &"C-1",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc94_beaumont", {}, {&"sc94_beaumont_passed": 0},
			{&"sc94_beaumont_refused": 0})
	back.condition = reinstated
	back.line_variants = [ConditionalKey.make("sc94_beaumont_about_revoked_reinstated", null, "about_revoked")]
	for beaumont: ScriptedCaseDef in [listed, back]:
		beaumont.identity_from_case = &"sc_42"
		beaumont.appearance_from_case = &"sc_42"
	# SC-95 Yara : pas de permis, répondant = passager généré @3 (R39).
	var yara: ScriptedCaseDef = Act3._scripted(&"sc_95", 4, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_TRANSIT, &"stay_days": 3}, [], &"sc95_yara", {}, {&"sc95_yara_passed": 0},
			{&"sc95_yara_refused": 0})
	yara.identity_from_case = &"sc_10"
	yara.appearance_from_case = &"sc_10"
	yara.sponsor_index = 3
	yara.line_variants = [ConditionalKey.make("sc95_yara_arrival_known", Act3._all([&"sc65_yara_passed"]), "arrival")]
	# SC-96 La figure : (c) libérée par la grève (Dora ou Mira) > (a) Dora > (b) Mira.
	var freed_dora: ScriptedCaseDef = Act3._scripted(&"sc_96c", 6, _dora_identity(Passenger.PURPOSE_FAMILY_VISIT), [],
			&"sc96_freed", {}, {&"sc96_figure_passed": 0}, {&"sc96_figure_refused": 0})
	freed_dora.condition = Act3._all([&"final3_detained", &"final3_dora"])
	freed_dora.fixed_appearance_seed = DORA_SEED
	var freed_mira: ScriptedCaseDef = Act3._scripted(&"sc_96d", 6, _mira_identity(Passenger.PURPOSE_TRANSIT), [],
			&"sc96_freed", {}, {&"sc96_figure_passed": 0}, {&"sc96_figure_refused": 0})
	freed_mira.condition = Act3._cond([&"final3_detained"], [&"final3_dora"])
	freed_mira.appearance_from_case = &"sc_04"
	var dora: ScriptedCaseDef = Act3._scripted(&"sc_96a", 6, _dora_identity(Passenger.PURPOSE_FAMILY_VISIT), [],
			&"sc96_dora", {}, {&"sc96_figure_passed": 0}, {&"sc96_figure_refused": 0})
	dora.condition = Act3._all([&"final3_dora", &"final3_passed", &"hh_dora_alive"])
	dora.fixed_appearance_seed = DORA_SEED
	var mira: ScriptedCaseDef = Act3._scripted(&"sc_96b", 6, _mira_identity(Passenger.PURPOSE_TRANSIT), [],
			&"sc96_mira", {}, {&"sc96_figure_passed": 0}, {&"sc96_figure_refused": 0})
	mira.condition = Act3._cond([], [&"final3_dora", &"final3_detained"])
	_mira_luciole(mira, true)
	mira.luciole_codes = PackedInt32Array([7])
	d.scripted_cases = [_sc90(&"b"), listed, back, yara, freed_dora, freed_mira, dora, mira]
	d.wanted_notices = [Act3._wanted(&"wanted_council", &"", 1, "wanted_council_reason")]
	var on_list: RevocationDef = Act3._revocation(&"council_beaumont", &"sc_94a", -1)
	on_list.reason_key = "revoked_reason_council"
	var cleared: RevocationDef = Act3._revocation(&"council_beaumont_reinstated", &"sc_94b", -1)
	cleared.reason_key = "revoked_reason_council"
	cleared.reinstated_on = ymd88(3, 1)
	d.revocations = [on_list, cleared]
	d.revoked_decoys = 2
	d.briefing_messages = _home_messages()
	return d


# --- Monde C — « La Mémoire » ------------------------------------------------

static func _day31_c(rs: RuleSet) -> DayDef:
	var d: DayDef = _epilogue_day(&"c", rs, F_EPI, 0.10)
	d.family_visit_rates = {&"tyc": 0.50}
	d.summons_rate = 0.10
	d.summons_decoys = 3
	d.admission_gauges = {&"tyc": PONT31}
	var lindgren: ScriptedCaseDef = Act3._scripted(&"sc_97", 2, {&"faction_id": &"hal", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc97_lindgren", {}, {&"sc97_lindgren_passed": 0},
			{&"sc97_lindgren_refused": 0})
	lindgren.identity_from_case = &"sc_23"
	lindgren.appearance_from_case = &"sc_23"
	lindgren.slipped_item = Act3._item(SlippedItem.Kind.FORM, "wb_form_label", "sc97_form", [KEEP, RETURN], RETURN,
			{&"keep": {&"sc97_form_signed": 0}})
	var okafor: ScriptedCaseDef = Act3._scripted(&"sc_98", 3, {&"faction_id": &"hal", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc98_okafor", {}, {&"sc98_okafor_passed": 0},
			{&"sc98_okafor_refused": 0})
	okafor.identity_from_case = &"sc_56"
	okafor.appearance_from_case = &"sc_56"
	okafor.extra_tags = [&"prop_school_satchel"]
	okafor.line_variants = [ConditionalKey.make("sc98_okafor_arrival_refused",
			Act3._any([Act3._all([&"sc56_okafor_refused"]), Act3._all([&"sc81_okafor_refused"])]), "arrival")]
	var elena: ScriptedCaseDef = Act3._scripted(&"sc_99", 4, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 7, &"implants": PackedStringArray()}, [],
			&"sc99_elena", {}, {&"sc99_elena_passed": 0}, {&"sc99_elena_refused": 0})
	elena.identity_from_case = &"sc_25"
	elena.appearance_from_case = &"sc_25"
	elena.sponsor_case_id = &"sc_98"
	elena.extra_tags = [&"companion_child"]
	elena.line_variants = [ConditionalKey.make("sc99_elena_arrival_passed", Act3._all([&"sc74_elena_passed"]), "arrival")]
	var dora: ScriptedCaseDef = Act3._scripted(&"sc_100a", 6, _dora_identity(Passenger.PURPOSE_TRANSIT), [],
			&"sc100_dora", {}, {&"sc100_figure_passed": 0}, {&"sc100_figure_refused": 0})
	dora.passenger_overrides[&"summons_id"] = "ENQ-0412"
	dora.condition = Act3._all([&"final3_dora", &"hh_dora_alive"])
	dora.fixed_appearance_seed = DORA_SEED
	dora.line_variants = [ConditionalKey.make("sc100_dora_arrival_detained", Act3._all([&"dora_detained_final"]), "arrival")]
	var mira_identity: Dictionary = _mira_identity(Passenger.PURPOSE_TRANSIT)
	mira_identity[&"summons_id"] = "ENQ-0412"
	var mira: ScriptedCaseDef = Act3._scripted(&"sc_100b", 6, mira_identity, [], &"sc100_mira", {},
			{&"sc100_figure_passed": 0}, {&"sc100_figure_refused": 0})
	_mira_luciole(mira, false)
	mira.line_variants = [ConditionalKey.make("sc100_mira_arrival_detained", Act3._all([&"final3_detained"]), "arrival")]
	d.scripted_cases = [_sc90(&"c"), lindgren, okafor, elena, dora, mira]
	d.summons = [Act3._summons(&"summons_first", &"sc_90", -1, "summons_reason_witness"),
			Act3._summons(&"summons_figure_dora", &"sc_100a", -1, "summons_reason_witness"),
			Act3._summons(&"summons_figure_mira", &"sc_100b", -1, "summons_reason_witness")]
	d.briefing_messages = [Act3._msg("spk_okafor", "msg_okafor_day31", V_FAMILY, Act3._all([&"epi_ending_f10"]),
			&"", 1)]
	d.briefing_messages.append_array(_home_messages())
	return d


# --- Monde D — « L'Autre côté » (sas Castellanos, Tycho) ---------------------

static func _day31_d(rs: RuleSet) -> DayDef:
	var d: DayDef = _epilogue_day(&"d", rs, F_EPI_D, 0.0)
	var dmitri: ScriptedCaseDef = Act3._scripted(&"sc_101", 2, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"purpose": Passenger.PURPOSE_RETURN}, [], &"sc101_dmitri", {}, {&"sc101_dmitri_passed": 0},
			{&"sc101_dmitri_refused": 0})
	dmitri.identity_from_case = &"sc_08"
	dmitri.appearance_from_case = &"sc_08"
	dmitri.document_issuers = {&"bioscan": ISSUER_DT}
	dmitri.line_variants = [
		ConditionalKey.make("sc101_dmitri_arrival_locked", Act3._all([&"sc63_dmitri_locked_out"]), "arrival"),
		ConditionalKey.make("sc101_dmitri_arrival_hired", Act3._all([&"sc24_dmitri_hired"]), "arrival"),
	]
	var wren: ScriptedCaseDef = Act3._scripted(&"sc_102", 4, {&"faction_id": &"drv", &"given_name": "Wren",
			&"family_name": "Basse-Marée", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2142, 8, 30), &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 3,
			&"implants": PackedStringArray()}, [K.EXPIRED_DOCUMENT], &"sc102_wren",
			{&"document_id": &"bioscan", &"expired_days": 11}, {&"sc102_wren_passed": 0}, {&"sc102_wren_refused": 0})
	wren.appearance_from_case = &"sc_19"
	wren.document_issuers = {&"bioscan": ISSUER_MERIDIAN}
	wren.slipped_item = Act3._item(SlippedItem.Kind.DOCK_CARD, "wb_dock_card_label", "sc102_note", [KEEP, RETURN],
			RETURN, {&"keep": {&"sc102_note_kept": 0}})
	wren.line_variants = [ConditionalKey.make("sc102_wren_arrival_drift", Act3._all([&"exit3_drift"]), "arrival")]
	var mira: ScriptedCaseDef = Act3._scripted(&"sc_103", 6, _mira_identity(Passenger.PURPOSE_RETURN), [], &"sc103_mira",
			{}, {&"sc103_mira_passed": 0}, {&"sc103_mira_refused": 0})
	_mira_luciole(mira, true)
	mira.document_issuers = {&"bioscan": ISSUER_DT}
	var denied_condition: FlagCondition = Act3._cond([], [&"final3_dora"])
	denied_condition.any_of.assign([Act3._all([&"final3_denied"]), Act3._all([&"final3_unprocessed"])])
	mira.line_variants = [
		ConditionalKey.make("sc103_mira_arrival_passed", Act3._cond([&"final3_passed"], [&"final3_dora"]), "arrival"),
		ConditionalKey.make("sc103_mira_arrival_denied", denied_condition, "arrival"),
	]
	d.scripted_cases = [_sc90(&"d"), dmitri, wren, mira]
	d.wanted_notices = [Act3._wanted(&"wanted_committee", &"", 5, "wanted_committee_reason")]
	d.briefing_messages = [
		Act3._msg("spk_note", "msg_foyer_day31_d_ilan", V_FAMILY,
				Act3._any([Act3._all([&"ilan_tycho"]), Act3._all([&"hh_ilan_alive"])]), &"home", 1),
		Act3._msg("spk_note", "msg_foyer_day31_d_dora", V_FAMILY, Act3._cond([&"hh_dora_alive"], [&"hh_dora_held"]),
				&"dora", 2),
	]
	return d


# --- Conclusions (M12 §1.9) ----------------------------------------------------

## Données de l'épilogue : mondes (jours), variantes de fin, lignes communes,
## liste blanche des drapeaux lus par le J31 (calculée depuis les conditions).
static func build_epilogue(days: Dictionary[StringName, DayDef]) -> EpilogueDef:
	var def: EpilogueDef = EpilogueDef.new()
	def.version = 1
	def.memory_case_ids = [&"tuto_concordant", &"sc_04", &"sc_82a", &"sc_82b"]
	def.first_lines = [
		ConditionalKey.make("epi_first_passed", Act3._all([&"sc90_first_passed"])),
		ConditionalKey.make("epi_first_refused", Act3._all([&"sc90_first_refused"])),
	]
	def.home_lines = [
		ConditionalKey.make("epi_home_ilan_reconciled", Act3._all([&"ilan_reconciled", &"hh_ilan_alive"])),
		ConditionalKey.make("epi_home_noa", Act3._all([&"hh_noa_alive"])),
	]
	def.max_lines = 8
	for world: StringName in WORLDS:
		var w: EpilogueWorldDef = EpilogueWorldDef.new()
		w.id = world
		w.day_def = days[world]
		w.eyebrow_key = "epi_eyebrow_%s" % world
		w.name_key = "dos_world_%s" % world
		w.line_groups = _line_groups(world)
		w.farewell_lines = _farewells(world)
		def.worlds.append(w)
	var keys: Array[StringName] = []
	keys.assign(ENDING_WORLDS.keys())
	for key: StringName in keys:
		var e: EpilogueEndingDef = EpilogueEndingDef.new()
		e.key = key
		e.world = ENDING_WORLDS[key]
		e.open_key = "epi_%s_open" % key
		e.close_key = "epi_%s_close" % key
		e.intro_key = "day31_%s_intro_%s" % [e.world, key]
		if key == &"f10":
			e.open_gauge = PONT31
		if key == &"f3":
			e.no_home_line = true
		if e.world == &"d":
			e.home_lines = [
				ConditionalKey.make("epi_home_ilan_tycho", Act3._all([&"ilan_tycho", &"hh_ilan_alive"])),
				ConditionalKey.make("epi_home_ilan_reconciled", Act3._all([&"ilan_reconciled", &"hh_ilan_alive"])),
				ConditionalKey.make("epi_home_noa", Act3._all([&"hh_noa_alive"])),
			]
		def.endings.append(e)
	def.read_flags = read_flags(def)
	return def


static func _group(id: StringName, entries: Array[Array]) -> EpilogueLineGroupDef:
	var group: EpilogueLineGroupDef = EpilogueLineGroupDef.new()
	group.id = id
	for entry: Array in entries:
		group.lines.append(ConditionalKey.make(str(entry[0]), entry[1]))
	return group


## Condition « tous ces drapeaux » à partir d'un tableau non typé.
static func _on(flags: Array) -> FlagCondition:
	var typed: Array[StringName] = []
	typed.assign(flags)
	return Act3._all(typed)


static func _line_groups(world: StringName) -> Array[EpilogueLineGroupDef]:
	match world:
		&"a":
			var inspector: FlagCondition = Act3._any([Act3._all([&"sc54_sato_reinstated"]), Act3._all([&"sc41_sato_spared"])])
			var fallen: FlagCondition = Act3._cond([], [&"sc54_sato_reinstated", &"sc41_sato_spared"])
			fallen.any_of.assign([Act3._all([&"sc91_sato_passed"]), Act3._all([&"sc91_sato_refused"])])
			var refused: FlagCondition = _on([&"sc91_sato_refused"])
			refused.any_of.assign([inspector])
			var passed: FlagCondition = _on([&"sc91_sato_passed"])
			passed.any_of.assign([inspector.duplicate(true)])
			return [
				_group(&"sato", [["epi_a_sato_fallen", fallen], ["epi_a_sato_refused", refused], ["epi_a_sato_passed", passed]]),
				_group(&"okonkwo", [
					["epi_a_okonkwo_refused_denounced", _on([&"okonkwo_denounced", &"sc92_okonkwo_refused"])],
					["epi_a_okonkwo_passed_denounced", _on([&"okonkwo_denounced", &"sc92_okonkwo_passed"])],
					["epi_a_okonkwo_passed", _on([&"sc92_okonkwo_passed"])],
					["epi_a_okonkwo_refused", _on([&"sc92_okonkwo_refused"])]]),
				_group(&"figure", [
					["epi_a_dora_refused", _on([&"sc93_dora_refused"])],
					["epi_a_dora_passed", _on([&"sc93_dora_passed"])],
					["epi_a_mira_detained", _on([&"sc93_mira_detained"])],
					["epi_a_mira_passed", _on([&"sc93_mira_passed"])],
					["epi_a_mira_refused", _on([&"sc93_mira_refused"])],
					["epi_a_ilan_passed", _on([&"sc93_ilan_passed"])],
					["epi_a_ilan_refused", _on([&"sc93_ilan_refused"])],
					["epi_a_note_kept", _on([&"sc93_note_kept"])],
					["epi_a_note_reported", _on([&"sc93_note_reported"])]]),
			]
		&"b":
			return [
				_group(&"beaumont", [["epi_b_beaumont_refused", _on([&"sc94_beaumont_refused"])],
						["epi_b_beaumont_passed", _on([&"sc94_beaumont_passed"])]]),
				_group(&"yara", [["epi_b_yara_passed", _on([&"sc95_yara_passed"])],
						["epi_b_yara_refused", _on([&"sc95_yara_refused"])]]),
				_group(&"figure", [["epi_b_fig_passed", _on([&"sc96_figure_passed"])],
						["epi_b_fig_refused", _on([&"sc96_figure_refused"])]]),
			]
		&"c":
			return [
				_group(&"lindgren", [["epi_c_lindgren_signed", _on([&"sc97_form_signed"])],
						["epi_c_lindgren_passed", _on([&"sc97_lindgren_passed"])]]),
				_group(&"okafor", [["epi_c_okafor_chain", _on([&"sc98_okafor_passed", &"sc99_elena_passed"])],
						["epi_c_okafor_broken", _on([&"sc98_okafor_refused"])]]),
				_group(&"figure", [["epi_c_fig_passed", _on([&"sc100_figure_passed"])],
						["epi_c_fig_refused", _on([&"sc100_figure_refused"])]]),
			]
		&"d":
			return [
				_group(&"dmitri", [["epi_d_dmitri_passed", _on([&"sc101_dmitri_passed"])]]),
				_group(&"wren", [["epi_d_wren_refused", _on([&"sc102_wren_refused"])],
						["epi_d_wren_passed", _on([&"sc102_wren_passed"])]]),
				_group(&"figure", [["epi_d_mira_passed", _on([&"sc103_mira_passed"])],
						["epi_d_mira_refused", _on([&"sc103_mira_refused"])]]),
			]
	return []


## Réplique Tessar de fin (D-048) si la figure a été approuvée : ‹Tu vanu.›
## (Dora), ‹Shen tavi.› (Mira, Yara), ‹Oru ka.› (Wren).
static func _farewells(world: StringName) -> Array[ConditionalKey]:
	match world:
		&"a":
			return [ConditionalKey.make("epi_farewell_dora", Act3._all([&"sc93_dora_passed"])),
					ConditionalKey.make("epi_farewell_mira", Act3._all([&"sc93_mira_passed"]))]
		&"b":
			return [ConditionalKey.make("epi_farewell_dora", Act3._all([&"sc96_figure_passed", &"final3_dora"])),
					ConditionalKey.make("epi_farewell_mira", Act3._all([&"sc96_figure_passed"])),
					ConditionalKey.make("epi_farewell_mira", Act3._all([&"sc95_yara_passed"]))]
		&"c":
			return [ConditionalKey.make("epi_farewell_dora", Act3._all([&"sc100_figure_passed", &"final3_dora"])),
					ConditionalKey.make("epi_farewell_mira", Act3._all([&"sc100_figure_passed"]))]
		&"d":
			return [ConditionalKey.make("epi_farewell_mira", Act3._all([&"sc103_mira_passed"])),
					ConditionalKey.make("epi_farewell_wren", Act3._all([&"sc102_wren_passed"]))]
	return []


## Drapeaux lus par le J31 : ceux des conditions des jours (cas, répliques,
## messages, avis, révocations, convocations) et des lignes de conclusion, hors
## drapeaux posés pendant le J31 et pseudo-drapeaux du foyer (`hh_*`) et de la
## fin (`epi_ending_*`), recalculés.
static func read_flags(def: EpilogueDef) -> Array[StringName]:
	var found: Dictionary[StringName, bool] = {}
	var produced: Dictionary[StringName, bool] = {}
	for world: EpilogueWorldDef in def.worlds:
		var day: DayDef = world.day_def
		for scripted: ScriptedCaseDef in day.scripted_cases:
			_collect(scripted.condition, found)
			for variant: ConditionalKey in scripted.line_variants:
				_collect(variant.condition, found)
			for flags: Dictionary in [scripted.flags_on_approve, scripted.flags_on_deny, scripted.flags_on_detain]:
				for flag: Variant in flags:
					produced[StringName(str(flag))] = true
			if scripted.slipped_item != null:
				for decision: Variant in scripted.slipped_item.effects:
					var effects: Dictionary = scripted.slipped_item.effects[decision]
					for flag: Variant in effects:
						produced[StringName(str(flag))] = true
		for message: BriefingMessageDef in day.briefing_messages:
			_collect(message.condition, found)
		for notice: WantedNoticeDef in day.wanted_notices:
			_collect(notice.condition, found)
		for revocation: RevocationDef in day.revocations:
			_collect(revocation.condition, found)
		for group: EpilogueLineGroupDef in world.line_groups:
			for line: ConditionalKey in group.lines:
				_collect(line.condition, found)
		for line: ConditionalKey in world.farewell_lines:
			_collect(line.condition, found)
	for list: Array[ConditionalKey] in [def.first_lines, def.home_lines]:
		for line: ConditionalKey in list:
			_collect(line.condition, found)
	for ending: EpilogueEndingDef in def.endings:
		for line: ConditionalKey in ending.home_lines:
			_collect(line.condition, found)
	var result: Array[StringName] = []
	for flag: StringName in found:
		var text: String = String(flag)
		if produced.has(flag) or text.begins_with("hh_") or text.begins_with("epi_ending_"):
			continue
		result.append(flag)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result


static func _collect(condition: FlagCondition, into: Dictionary[StringName, bool]) -> void:
	if condition == null:
		return
	for flag: StringName in condition.all_of:
		into[flag] = true
	for flag: StringName in condition.none_of:
		into[flag] = true
	for gauge: StringName in condition.gauges_min:
		into[gauge] = true
	for gauge: StringName in condition.gauges_max:
		into[gauge] = true
	for sub: Resource in condition.any_of:
		_collect(sub as FlagCondition, into)


# ---------------------------------------------------------------------------
# Garde de nuit « Endurance » (M12 §2, D-126 → D-128, B57 données)
# ---------------------------------------------------------------------------

## Unités U01 → U20 : `[id, règles, tier, prérequis, documents, onglets, listes renouvelées]`.
const UNITS: Array[Array] = [
	[&"u01", [&"r_permit_required", &"r_permit_valid"], 1, [], [&"entry_permit"], [], []],
	[&"u02", [&"r_purpose_consistent"], 1, [&"u01"], [], [], []],
	[&"u03", [&"r_origin_block"], 1, [], [], ["origins"], []],
	[&"u04", [&"r_face_uncovered"], 1, [], [], [], []],
	[&"u05", [&"r_mrz_valid"], 1, [], [], [], []],
	[&"u06", [&"r_tycho_interview"], 2, [], [], [], []],
	[&"u07", [&"r_bioscan_required", &"r_bioscan_valid"], 2, [], [&"bioscan"], [], []],
	[&"u08", [&"r_bioscan_issuer", &"r_bioscan_fit"], 2, [&"u07"], [], [], []],
	[&"u09", [&"r_implants_declared"], 2, [], [], ["implants"], []],
	[&"u10", [&"r_banned_implants"], 2, [&"u09"], [&"mil_waiver"], [], []],
	[&"u11", [&"r_identity_fraud_detain"], 2, [], [], [], []],
	[&"u12", [&"r_apparent_age"], 3, [&"u11"], [], [], []],
	[&"u13", [&"r_tharsis_banned"], 3, [&"u01"], [], [], []],
	[&"u14", [&"r_seals_valid"], 3, [], [], ["seals"], []],
	[&"u15", [&"r_wanted_detain"], 3, [&"u11"], [], ["wanted"], ["wanted"]],
	[&"u16", [&"r_contract_required", &"r_contract_consistent"], 3, [&"u02"], [&"work_contract"], ["employers"], []],
	[&"u17", [&"r_drift_pass"], 3, [], [&"drift_pass"], ["vessels"], []],
	[&"u18", [&"r_nx_firmware"], 3, [&"u09"], [], [], []],
	[&"u19", [&"r_asylum_required"], 3, [&"u01"], [&"asylum"], [], []],
	[&"u20", [&"r_revoked_ids"], 3, [], [], ["revoked"], ["revoked"]],
]
## Paliers (M12 §2.5) : `[index, premier passager, poids 0–3, subtil, bruit, visière, rotation]`.
const TIERS: Array[Array] = [
	[0, 1, [0.45, 0.45, 0.10, 0.00], 0.10, 0.20, 0.10, false],
	[1, 21, [0.40, 0.42, 0.15, 0.03], 0.25, 0.30, 0.15, false],
	[2, 41, [0.36, 0.40, 0.19, 0.05], 0.40, 0.35, 0.20, false],
	[3, 61, [0.33, 0.38, 0.22, 0.07], 0.55, 0.40, 0.20, false],
	[4, 101, [0.30, 0.38, 0.24, 0.08], 0.65, 0.40, 0.20, true],
]
## Poids des types de la Garde : filtrés par les règles actives (un type dont la
## règle n'est pas en vigueur n'est jamais tiré, comme en campagne).
const GARDE_WEIGHTS: Dictionary = {
	K.EXPIRED_DOCUMENT: 0.10, K.MISSING_DOCUMENT: 0.06, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.07,
	K.NAME_MISMATCH: 0.07, K.ORIGIN_ID_MISMATCH: 0.05, K.PURPOSE_MISMATCH: 0.05, K.WRONG_ISSUER: 0.05,
	K.BIOSCAN_UNFIT: 0.04, K.UNDECLARED_IMPLANT: 0.05, K.BANNED_IMPLANT: 0.04, K.IMPOSTOR_LOOKALIKE: 0.05,
	K.RELATIVE_DOCUMENTS: 0.04, K.BANNED_FACTION: 0.05, K.INVALID_SEAL: 0.05, K.MRZ_MISMATCH: 0.06,
	K.CONTRACT_MISMATCH: 0.05, K.UNREGISTERED_VESSEL: 0.20, K.OUTDATED_FIRMWARE: 0.05,
}
## File maximale d'une garde (au-delà, la garde s'arrête d'elle-même).
const GARDE_MAX_PASSENGERS: int = 400


## RuleSet du socle (R01, R02, R03, R07), sauvegardé dans `data/garde/`.
static func build_garde_rule_set(rules: Dictionary[StringName, Rule]) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	rs.id = &"rs_garde"
	for rule_id: StringName in [&"r_id_card_required", &"r_id_card_valid", &"r_portrait_match", &"r_identity_fields_match"]:
		rs.rules.append(rules[rule_id])
	rs.required_document_ids = rs.compute_required_document_ids()
	return rs


## Unités U01 → U20 (sauvegardées une par fichier, `data/garde/unit_uNN.tres`).
static func build_garde_units(rules: Dictionary[StringName, Rule]) -> Array[GardeUnitDef]:
	var units: Array[GardeUnitDef] = []
	for spec: Array in UNITS:
		var unit: GardeUnitDef = GardeUnitDef.new()
		unit.id = spec[0]
		unit.title_key = "garde_unit_%s" % unit.id
		for rule_id: Variant in spec[1]:
			unit.rules.append(rules[StringName(str(rule_id))])
		unit.tier = spec[2]
		unit.prerequisites.assign(spec[3])
		unit.document_ids.assign(spec[4])
		unit.rulebook_tabs = PackedStringArray(spec[5])
		unit.renews_lists = PackedStringArray(spec[6])
		unit.enables_detain = unit.id == &"u11"
		units.append(unit)
	return units


static func build_garde(rule_set: RuleSet, units: Array[GardeUnitDef]) -> GardeDef:
	var g: GardeDef = GardeDef.new()
	g.version = 1
	var d: DayDef = DayDef.new()
	d.day_number = 0
	d.game_date = GameDate.from_ymd(2187, 5, 1)
	d.rule_set = rule_set
	d.duration_sec = 0.0
	d.passenger_count = GARDE_MAX_PASSENGERS
	d.anomaly_count_weights = PackedFloat32Array(TIERS[0][2])
	for kind: Variant in GARDE_WEIGHTS:
		var typed_kind: AnomalyType.Kind = kind
		d.anomaly_weights[typed_kind] = GARDE_WEIGHTS[kind]
	d.intro_text_key = "garde_intro"
	d.credit_per_correct = 0
	d.penalty_per_error = 0
	d.penalty_escalated = 0
	d.free_citations_per_day = 0
	d.faction_weights = {&"tyc": 0.25, &"hal": 0.20, &"ter": 0.20, &"cer": 0.15, &"thr": 0.12, &"drv": 0.08}
	d.visor_down_rate = TIERS[0][5]
	d.legit_noise_rate = TIERS[0][4]
	d.subtle_rate = TIERS[0][3]
	d.bribe_rate = 0.0
	d.luciole_rate = 0.0
	d.luciole_trust_on_breach = false
	d.detain_enabled = false
	d.has_evening = false
	d.revoked_decoys = 3
	d.asylum_class_rate = 0.30
	d.mode = DayDef.MODE_GARDE
	d.economy_disabled = true
	d.untimed = true
	g.day_template = d
	g.units = units
	for spec: Array in TIERS:
		var tier: GardeTierDef = GardeTierDef.new()
		tier.index = spec[0]
		tier.name_key = "garde_tier_%d" % tier.index
		tier.from_passenger = spec[1]
		tier.anomaly_count_weights = PackedFloat32Array(spec[2])
		tier.subtle_rate = spec[3]
		tier.legit_noise_rate = spec[4]
		tier.visor_down_rate = spec[5]
		tier.rotation = spec[6]
		g.tiers.append(tier)
	g.directive_every = 5
	g.max_errors = 3
	g.tier_unlock_directive = PackedInt32Array([1, 4, 9])
	g.date_min = GameDate.from_ymd(2187, 5, 1)
	g.date_max = GameDate.from_ymd(2187, 11, 30)
	g.clock_start_minute = 22 * 60
	g.minutes_per_passenger = 6
	g.dawn_passenger = 80
	g.first_event_range = Vector2i(16, 20)
	g.event_gap = Vector2i(12, 18)
	# M12 §3.5 dit « 5 » : impossible avec une directive tous les 5 passagers
	# (aucun passager hors fenêtre) ; 2 retenu (proposition, voir rapport).
	g.event_quiet_after_directive = 2
	g.rotation_note_key = "rb_retired_quais"
	return g


# ---------------------------------------------------------------------------
# Événements de station EV-01 → EV-08 (M12 §3, D-129, B58 données)
# ---------------------------------------------------------------------------

const CLASS_A: int = 1
const CLASS_B: int = 2
## Jours éligibles et classes permises (M12 §3.3).
const ELIGIBLE_DAYS: Dictionary[int, int] = {
	4: CLASS_A, 5: CLASS_A, 6: CLASS_A | CLASS_B, 7: CLASS_A, 8: CLASS_A | CLASS_B, 12: CLASS_A, 13: CLASS_A,
	14: CLASS_A | CLASS_B, 15: CLASS_A, 16: CLASS_A, 18: CLASS_A | CLASS_B, 19: CLASS_A | CLASS_B,
	22: CLASS_A | CLASS_B, 23: CLASS_A | CLASS_B, 25: CLASS_A | CLASS_B, 26: CLASS_A, 27: CLASS_A | CLASS_B,
	28: CLASS_A | CLASS_B,
}


## Compensation et bornes d'un resserrement (classe B, M12 §3.1 règle 4) :
## au plus une anomalie par passager, aucune subtile (l'avertissement gratuit
## de plus est porté par `StationEventsDef.class_b_free_citations`).
static func _class_b_limits() -> Array[RuleChangeDef]:
	return [RuleChangeDef.modify(RuleChangeDef.MOD_MAX_ANOMALIES, 1), RuleChangeDef.modify(RuleChangeDef.MOD_NO_SUBTLE, 1)]


static func _event(number: int, key: StringName, event_class: StationEventDef.EventClass) -> StationEventDef:
	var e: StationEventDef = StationEventDef.new()
	e.id = StringName("ev_%02d" % number)
	e.key = key
	e.event_class = event_class
	e.announce_key = "sev_%s_announce" % key
	e.title_key = "sev_%s_title" % key
	e.end_key = "sev_%s_end" % key
	return e


## Règle des cartes volées (EV-07) : `RevokedIdRule` sur la liste `stolen`.
static func stolen_ids_rule() -> RevokedIdRule:
	var rule: RevokedIdRule = RevokedIdRule.new()
	rule.list_label = &"stolen"
	rule.list_title_key = "rb_tab_stolen"
	Act3._rule(rule, &"r_ev_stolen_ids", CAT.IDENTITY, 2)
	return rule


static func build_events() -> Array[StationEventDef]:
	var mrz: StationEventDef = _event(1, &"mrz_reader", StationEventDef.EventClass.A)
	mrz.required_rule_id = &"r_mrz_valid"
	mrz.day_min = 9
	mrz.window_kind = StationEventDef.WindowKind.PASSENGERS
	mrz.window_passengers = 4
	mrz.rulebook_key = "sev_mrz_reader_rb"
	mrz.changes = [RuleChangeDef.retire(&"r_mrz_valid", "sev_mrz_reader_rb")]
	mrz.garde_required_unit = &"u05"
	mrz.garde_window_passengers = 4
	var comparator: StationEventDef = _event(2, &"comparator", StationEventDef.EventClass.B)
	comparator.window_kind = StationEventDef.WindowKind.PASSENGERS
	comparator.window_passengers = 3
	comparator.rulebook_key = "sev_comparator_rb"
	comparator.changes = [RuleChangeDef.modify(RuleChangeDef.MOD_COMPARATOR_DOWN, 1)]
	comparator.changes.append_array(_class_b_limits())
	comparator.garde_window_passengers = 3
	var quarantine: StationEventDef = _event(3, &"quarantine", StationEventDef.EventClass.B)
	quarantine.required_rule_id = &"r_bioscan_valid"
	quarantine.day_min = 5
	quarantine.day_max = 22
	quarantine.window_kind = StationEventDef.WindowKind.REST_OF_DAY
	quarantine.rulebook_key = "sev_quarantine_rb"
	quarantine.end_key = ""
	quarantine.changes = [RuleChangeDef.override(&"r_bioscan_valid", {&"max_age_days": 7}, [&"tyc"])]
	quarantine.changes.append_array(_class_b_limits())
	quarantine.garde_required_unit = &"u07"
	quarantine.garde_window_passengers = 10
	var inspection: StationEventDef = _event(4, &"inspection", StationEventDef.EventClass.A)
	inspection.window_kind = StationEventDef.WindowKind.PASSENGERS
	inspection.window_passengers = 5
	inspection.changes = [RuleChangeDef.modify(RuleChangeDef.MOD_NO_FREE_CITATIONS, 1),
			RuleChangeDef.modify(RuleChangeDef.MOD_CORRECT_BONUS, 2)]
	# Garde : chaque verdict juste compte double (1 + 1, `GardeRun.points_for_correct`).
	inspection.garde_changes = [RuleChangeDef.modify(RuleChangeDef.MOD_SCORE_PER_CORRECT, 1)]
	inspection.garde_announce_key = "sev_inspection_announce_garde"
	inspection.garde_window_passengers = 5
	var blackout: StationEventDef = _event(5, &"blackout", StationEventDef.EventClass.A)
	blackout.window_kind = StationEventDef.WindowKind.SECONDS
	blackout.window_seconds = 60.0
	blackout.rulebook_key = "sev_blackout_title"
	blackout.changes = [RuleChangeDef.retire(&"r_seals_valid", "sev_blackout_title"),
			RuleChangeDef.modify(RuleChangeDef.MOD_CLOCK_FROZEN, 1)]
	blackout.garde_changes = [RuleChangeDef.retire(&"r_seals_valid", "sev_blackout_title")]
	blackout.garde_window_passengers = 2
	var crowd: StationEventDef = _event(6, &"crowd", StationEventDef.EventClass.A)
	crowd.window_kind = StationEventDef.WindowKind.REST_OF_DAY
	crowd.end_key = ""
	crowd.changes = [RuleChangeDef.modify(RuleChangeDef.MOD_EXTRA_PASSENGERS, 3),
			RuleChangeDef.modify(RuleChangeDef.MOD_EXTRA_SECONDS, 120)]
	crowd.garde_allowed = false
	var stolen: StationEventDef = _event(7, &"stolen_ids", StationEventDef.EventClass.B)
	stolen.day_min = 3
	stolen.window_kind = StationEventDef.WindowKind.REST_OF_DAY
	stolen.start_delay = 1
	stolen.end_key = ""
	stolen.rulebook_key = "sev_stolen_ids_rb"
	stolen.list_label = &"stolen"
	stolen.list_size = 3
	stolen.changes = [RuleChangeDef.add(stolen_ids_rule())]
	stolen.changes.append_array(_class_b_limits())
	stolen.garde_window_passengers = 10
	var exemption: StationEventDef = _event(8, &"exemption", StationEventDef.EventClass.A)
	exemption.required_rule_id = &"r_bioscan_required"
	exemption.day_min = 5
	exemption.day_max = 22
	exemption.window_kind = StationEventDef.WindowKind.CLOCK
	exemption.clock_from = 13 * 60
	exemption.clock_to = 14 * 60
	exemption.end_key = ""
	exemption.rulebook_key = "sev_exemption_rb"
	exemption.changes = [RuleChangeDef.override(&"r_bioscan_required", {&"exempt": true}, [],
			[Passenger.PURPOSE_TRANSIT], 13 * 60, 14 * 60)]
	exemption.garde_changes = [RuleChangeDef.override(&"r_bioscan_required", {&"exempt": true}, [],
			[Passenger.PURPOSE_TRANSIT])]
	exemption.garde_required_unit = &"u07"
	exemption.garde_window_passengers = 5
	return [mrz, comparator, quarantine, inspection, blackout, crowd, stolen, exemption]


static func build_station_events(events: Array[StationEventDef]) -> StationEventsDef:
	var def: StationEventsDef = StationEventsDef.new()
	def.version = 1
	def.events = events
	def.eligible_days = ELIGIBLE_DAYS.duplicate()
	def.probability = 0.30
	def.max_per_type = 2
	def.no_consecutive_days = true
	def.class_b_free_citations = 1
	return def


# ---------------------------------------------------------------------------
# Dossier de l'agent : table des personnages (M12 §5.2, D-131, B63)
# ---------------------------------------------------------------------------

## `[chr_id, origine, cas…]` dans l'ordre de première apparition.
const CHARACTERS: Array[Array] = [
	[&"chr_premiers", &"", [&"tuto_concordant", &"tuto_missing_document", &"sc_85a", &"sc_85b", &"sc_90"]],
	[&"chr_technicien", &"hal", [&"sc_01", &"sc_83a", &"sc_83b"]],
	[&"chr_amara", &"ter", [&"sc_02", &"sc_06", &"sc_61"]],
	[&"chr_mineur", &"tyc", [&"sc_03", &"sc_84a"]],
	[&"chr_mira", &"tyc", [&"sc_04", &"sc_22", &"sc_50b", &"sc_82b", &"sc_93b", &"sc_96b", &"sc_96d", &"sc_100b", &"sc_103"]],
	[&"chr_lev", &"tyc", [&"sc_05", &"sc_13", &"sc_66"]],
	[&"chr_valcourt", &"hal", [&"sc_07", &"sc_51"]],
	[&"chr_dmitri", &"tyc", [&"sc_08", &"sc_24", &"sc_63", &"sc_101"]],
	[&"chr_noor", &"tyc", [&"sc_09", &"sc_57"]],
	[&"chr_yara", &"tyc", [&"sc_10", &"sc_65", &"sc_95"]],
	[&"chr_mazur", &"thr", [&"sc_11", &"sc_29", &"sc_78"]],
	[&"chr_ravel", &"hal", [&"sc_12", &"sc_45"]],
	[&"chr_kaito", &"cer", [&"sc_14", &"sc_86a", &"sc_86b"]],
	[&"chr_idris", &"thr", [&"sc_15", &"sc_87"]],
	[&"chr_hana", &"thr", [&"sc_16", &"sc_67"]],
	[&"chr_fatou", &"ter", [&"sc_17", &"sc_37", &"sc_88a", &"sc_88b"]],
	[&"chr_sefa", &"drv", [&"sc_18", &"sc_89a", &"sc_89b"]],
	[&"chr_wren", &"drv", [&"sc_19", &"sc_46", &"sc_72", &"sc_102"]],
	[&"chr_arkady", &"tyc", [&"sc_20"]],
	[&"chr_montclair", &"hal", [&"sc_21", &"sc_70"]],
	[&"chr_lindgren", &"hal", [&"sc_23", &"sc_36", &"sc_44", &"sc_49a", &"sc_49b", &"sc_64", &"sc_77", &"sc_81b_lindgren",
			&"sc_97"]],
	[&"chr_elena", &"tyc", [&"sc_25", &"sc_26", &"sc_74", &"sc_99"]],
	[&"chr_margaux", &"hal", [&"sc_27", &"sc_60", &"sc_80"]],
	[&"chr_tariq", &"ter", [&"sc_28", &"sc_62"]],
	[&"chr_kerr_ceres", &"cer", [&"sc_30", &"sc_31", &"sc_32", &"sc_69"]],
	[&"chr_corvo", &"drv", [&"sc_33"]],
	[&"chr_hiro", &"hal", [&"sc_34"]],
	[&"chr_okonkwo", &"ter", [&"sc_35a", &"sc_35b", &"sc_35c", &"sc_75a", &"sc_75b", &"sc_75c", &"sc_75d", &"sc_92a",
			&"sc_92b", &"sc_92c"]],
	[&"chr_sato", &"hal", [&"sc_38", &"sc_41", &"sc_54", &"sc_76", &"sc_81b_sato", &"sc_91a", &"sc_91b"]],
	[&"chr_leila", &"ter", [&"sc_39"]],
	[&"chr_valentin", &"hal", [&"sc_40", &"sc_55", &"sc_81b_valentin"]],
	[&"chr_beaumont", &"hal", [&"sc_42", &"sc_59", &"sc_81b_beaumont", &"sc_94a", &"sc_94b"]],
	[&"chr_mateus", &"ter", [&"sc_43"]],
	[&"chr_kasimir", &"tyc", [&"sc_47", &"sc_71a", &"sc_71b", &"sc_71c"]],
	[&"chr_paz", &"cer", [&"sc_48", &"sc_52"]],
	[&"chr_ilan", &"tyc", [&"sc_50a", &"sc_93c"]],
	[&"chr_anouk", &"tyc", [&"sc_53"]],
	[&"chr_okafor", &"hal", [&"sc_56", &"sc_81", &"sc_98"]],
	[&"chr_ophelie", &"hal", [&"sc_58"]],
	[&"chr_kerr_hal", &"hal", [&"sc_68", &"sc_81b_kerr"]],
	[&"chr_celeste", &"hal", [&"sc_73"]],
	[&"chr_adeyemi", &"hal", [&"sc_79"]],
	[&"chr_dora", &"tyc", [&"sc_82a", &"sc_93a", &"sc_96a", &"sc_96c", &"sc_100a"]],
	[&"chr_titulaire", &"tyc", [&"sc_84b"]],
]


static func build_characters() -> CharacterTableDef:
	var table: CharacterTableDef = CharacterTableDef.new()
	for spec: Array in CHARACTERS:
		var c: CharacterDef = CharacterDef.new()
		c.id = spec[0]
		c.faction = spec[1]
		c.case_ids.assign(spec[2])
		var short: String = String(c.id).trim_prefix("chr_")
		c.display_name = "dos_name_%s" % short
		c.blurb_key = "dos_chr_%s" % short
		if c.id == &"chr_arkady":
			# « Bastien Duval » jusqu'à la détention (vrai nom révélé) ou une fin vue.
			c.true_name = "dos_name_arkady_true"
			c.known_name_if = Act3._all([&"sc20_detained"])
			c.known_on_ending = true
		table.characters.append(c)
	return table
