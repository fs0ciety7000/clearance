## Contenu du jalon M13 « Gameplay » pour `tools/build_data.gd` (D-155) —
## fabriques statiques, chargées par `preload` (pas de `class_name` : outil).
##
## Source : `docs/M13.md` (§1 déclarations, §2 fouille, §3 améliorations, §4
## équilibrage, §5 récit, §6.1 B65 → B78) et les décisions D-139 → D-155 ;
## questions ouvertes de M13 §7 tranchées selon les recommandations. Formats
## des ressources : lot A (`scripts/core/*`, ARCHITECTURE §12) et lot B
## (`StatementTablesDef`, `SearchCatalogDef`, `SearchItemDef`,
## `StatementsConsistentRule`, `ContrabandRule`). Les textes sont des clés de
## `data/i18n/fr.csv`. Le verdict attendu reste calculé par le moteur (D-005) :
## les commentaires « attendu » sont l'intention, vérifiée par les tests
## (`tests/unit/test_m13_data.gd`, `test_m13_rules.gd`, `test_m13_generation.gd`).
##
## Écarts motivés par rapport à M13 : SC-107 en classe `C-3` (et non `C-4`) —
## un permis de 90 jours pour un `C-4` violerait R09 (séjour > 30 jours) et
## le refus ne tiendrait plus à la seule déclaration.
extends RefCounted

const Act2 := preload("res://tools/build_data_act2.gd")
const Act3 := preload("res://tools/build_data_act3.gd")
const M12 := preload("res://tools/build_data_m12.gd")

const K := AnomalyType.Kind
const CAT := Rule.RuleCategory
const KEEP := SlippedItem.Decision.KEEP
const RETURN := SlippedItem.Decision.RETURN
const REPORT := SlippedItem.Decision.REPORT

const V_CONSORTIUM: int = 0
const V_MENTOR: int = 1
const V_FAMILY: int = 2
const V_LUCIOLES: int = 3
const V_COMMISSION: int = 5

const STATEMENTS_DIR: String = "res://data/statements"
const SEARCH_DIR: String = "res://data/search"
const UPGRADES_DIR: String = "res://data/upgrades"

const R43: StringName = &"r_statements"
const R44: StringName = &"r_search_cause"
const R45: StringName = &"r_contraband"
const R46: StringName = &"r_weapons_detain"
const R47: StringName = &"r_belt_search"
const EMPLOYER_KA: String = "Kessler-Ashe Orbital"

## Paliers de R43 (M13 §1.4) : jour d'entrée → sujets.
const TIER_DAYS: Array[int] = [4, 12, 13, 24]
const TIER_TOPICS: Array[Array] = [
	[&"purpose", &"stay"],
	[&"purpose", &"stay", &"employer"],
	[&"purpose", &"stay", &"employer", &"origin"],
	[&"purpose", &"stay", &"employer", &"origin", &"host"],
]
## Noms de famille des figurants de M13 (§6.4) : seul le nom complet est
## réservé, jamais le nom de famille (QA-022 ne s'y applique pas).
const FIGURANT_FAMILY_NAMES: PackedStringArray = ["Strand", "Mbeki", "Oduya", "Nair", "Ivanova"]

## Poids de `STATEMENT_MISMATCH` par jour : M13 §1.5 relevé d'environ un tiers
## hors J4 (mesure `gen_stats`, 40 campagnes : 2,5–5 % des générés avec les
## poids du document, cible §4.1 : 4–6 %, 7–9 % aux J12, J13, J24).
const STATEMENT_WEIGHTS: Dictionary[int, float] = {
	4: 0.15, 5: 0.10, 6: 0.08, 7: 0.08, 8: 0.08, 9: 0.08, 10: 0.08, 11: 0.08, 12: 0.12, 13: 0.12,
	14: 0.08, 15: 0.08, 16: 0.08, 17: 0.08, 18: 0.08, 19: 0.08, 20: 0.08, 21: 0.07, 22: 0.08, 23: 0.08,
	24: 0.12, 25: 0.08, 26: 0.08, 27: 0.08, 28: 0.08, 29: 0.08, 30: 0.08,
}
## Poids pris à `PURPOSE_MISMATCH` (J4 : 0,21 → 0,15 ; J5 : 0,10 → 0,08).
const PURPOSE_MISMATCH_CUT: Dictionary[int, float] = {4: 0.06, 5: 0.02}
## Variantes AV-1 → AV-5 (M13 §1.5) : `[premier jour, purpose, stay, employer, origin, host]`.
const TOPIC_WEIGHTS: Array[Array] = [
	[4, 0.50, 0.50, 0.0, 0.0, 0.0],
	[12, 0.25, 0.25, 0.50, 0.0, 0.0],
	[13, 0.20, 0.20, 0.20, 0.40, 0.0],
	[14, 0.25, 0.25, 0.25, 0.25, 0.0],
	[24, 0.15, 0.15, 0.15, 0.15, 0.40],
	[25, 0.20, 0.20, 0.20, 0.20, 0.20],
]
## Anomalies de fouille : jour → `[CONTRABAND, CONCEALED_IMPLANT, CONCEALED_WEAPON,
## bruit d'indice]` ; M13 §2.7 abaissé d'environ 40 % au J8–J10 et 20 % ensuite
## (mesure `gen_stats` : 9–13 % des générés au J8–J10 et P(porteur | indice)
## jusqu'à 65 % avec les poids du document ; cibles §4.1 : 7–10 %, 30–45 %).
const SEARCH_WEIGHTS: Dictionary[int, Array] = {
	8: [0.06, 0.03, 0.01, 0.10], 9: [0.04, 0.025, 0.015, 0.10], 10: [0.04, 0.025, 0.015, 0.10],
	19: [0.08, 0.03, 0.015, 0.12], 21: [0.03, 0.015, 0.01, 0.10],
}
const SEARCH_WEIGHTS_DEFAULT: Array = [0.04, 0.025, 0.015, 0.10]
const SEARCH_NOISE_J16: float = 0.12
## Compensation du temps (M13 §4.2, levier `duration_sec`) : le document
## proposait +25 s (J4–J7) et +40 s (J8–J30), « à confirmer par
## `balance_sim --m13=compare` ». Mesuré (100 graines, 80 %) : avec +25 / +40,
## la file traitée **monte** de 3 à 6 points (coût réel ≈ +2,4 s par cas avant
## améliorations) et les profils qui dépassent le quota accumulent de la
## suspicion (F1 +5 à +8 points). Lot B : +15 s et +25 s. Finition M13 (200
## graines, 80 %) : avec +25 s, la file traitée dépasse encore la 0.12 de 2 à
## 3 points à l'Acte II et de 4 à 6 points à l'Acte III (AG-01, lampe, carnet,
## moniteur) ; retenu +15 s (J4–J7), +20 s (J8–J20), +10 s (J21–J30) : écarts
## de file entre −2 et +2 points. Passe économique (D-168, 500 à 1 000 graines
## par préréglage, `upgrades=smart`) : avec +20 / +10 s, 0,2 à 0,5 passager de
## plus par jour qu'en 0.12 aux Actes II et III (améliorations comprises), donc
## des dépassements de quota (`suspicion`, F1 de la Déposition) ; retenu +15 s,
## +10 s, +5 s, le salaire rendu par la prime de relevé (`finding_bonus`).
## Valeurs : `M13Sim.extra_seconds()` (source unique, partagée avec la simulation).
const EXTRA_SECONDS_EARLY: float = M13Sim.EXTRA_SECONDS_EARLY
const EXTRA_SECONDS_LATE: float = M13Sim.EXTRA_SECONDS_LATE
const EXTRA_SECONDS_ACT3: float = M13Sim.EXTRA_SECONDS_ACT3
## 3ᵉ avertissement gratuit aux jours de mécanique nouvelle (D-144).
const FREE_CITATION_DAYS: Array[int] = [4, 8]


# ---------------------------------------------------------------------------
# Règles R43 → R47 (M13 §1.4, §2.6 ; B66, B71)
# ---------------------------------------------------------------------------

## Règles de `data/rules/` (palier 1 de R43, R44 → R47).
static func build_rules() -> Array[Rule]:
	var r44: ProcedureRule = ProcedureRule.new()
	r44.procedure_id = ProcedureRule.PROCEDURE_SEARCH_CAUSE
	var r45: ContrabandRule = ContrabandRule.new()
	r45.item_kind = SearchItem.Kind.CONTRABAND
	r45.categories = [&"oxygen", &"stimulant", &"medicine", &"data", &"seeds"]
	r45.anomaly_kind = K.CONTRABAND
	r45.reason_key = "viol_contraband"
	var r46: ContrabandRule = ContrabandRule.new()
	r46.item_kind = SearchItem.Kind.WEAPON
	r46.categories = [&"blade", &"jammer"]
	r46.anomaly_kind = K.CONCEALED_WEAPON
	r46.reason_key = "viol_weapon"
	var r47: ProcedureRule = ProcedureRule.new()
	r47.procedure_id = ProcedureRule.PROCEDURE_BELT_SEARCH
	r47.applies_to_faction_ids = [&"cer"]
	r47.min_stay_days = 7
	return [
		statements_rule(1),
		Act3._rule(r44, R44, CAT.SPECIAL, 1),
		Act3._rule(r45, R45, CAT.SPECIAL, 2),
		Act3._rule(r46, R46, CAT.SPECIAL, 3),
		Act3._rule(r47, R47, CAT.SPECIAL, 1),
	]


## Paliers 2 → 4 de R43 (même identifiant, `data/rules/rule_statements_sN.tres`).
static func build_rule_tiers() -> Array[StatementsConsistentRule]:
	var tiers: Array[StatementsConsistentRule] = []
	for tier: int in range(2, 5):
		tiers.append(statements_rule(tier))
	return tiers


static func statements_rule(tier: int) -> StatementsConsistentRule:
	var rule: StatementsConsistentRule = StatementsConsistentRule.new()
	rule.tier = tier
	rule.topics.assign(TIER_TOPICS[tier - 1])
	rule.employer_codes = M12.employer_codes()
	Act3._rule(rule, R43, CAT.PURPOSE, 2)
	rule.title_key = "r_statements_title"
	rule.rulebook_text_key = "r_statements_text_s%d" % tier
	return rule


## R15 : implants de localisation dissimulable (J8+, D-147).
static func configure_existing_rules(rules: Dictionary[StringName, Rule]) -> void:
	var implants: ImplantsDeclaredRule = rules[&"r_implants_declared"]
	var codes: Array = IMPLANT_ZONES.keys()
	codes.sort()
	implants.concealable_codes = PackedStringArray(codes)
	implants.concealed_from_day = 8


## Palier de R43 en vigueur un jour de campagne (0 avant le J4).
static func tier_for_day(day_number: int) -> int:
	var tier: int = 0
	for i: int in TIER_DAYS.size():
		if day_number >= TIER_DAYS[i]:
			tier = i + 1
	return tier


## RuleSets de campagne révisés (`first_day` = jour du premier RuleSet de la
## liste) : palier de R43 (J4, J12, J13, J24), R44 → R46 (J8), R47 (J19),
## badges NOUVEAU aux jours d'entrée.
static func revise_rule_sets(sets: Array[RuleSet], first_day: int, rules: Dictionary[StringName, Rule],
		tiers: Array[StatementsConsistentRule]) -> void:
	for i: int in sets.size():
		revise_rule_set(sets[i], first_day + i, rules, tiers)


static func revise_rule_set(rs: RuleSet, n: int, rules: Dictionary[StringName, Rule],
		tiers: Array[StatementsConsistentRule]) -> void:
	var tier: int = tier_for_day(n)
	var at: int = -1
	for k: int in range(rs.rules.size() - 1, -1, -1):
		if rs.rules[k] != null and rs.rules[k].id == R43:
			at = k
			rs.rules.remove_at(k)
	if tier > 0:
		var rule: Rule = rules[R43] if tier == 1 else tiers[tier - 2]
		if at < 0:
			# Après « Motif et durée conformes » (R09), sinon en fin de liste.
			at = rs.rules.size()
			for k: int in rs.rules.size():
				if rs.rules[k] != null and rs.rules[k].id == &"r_purpose_consistent":
					at = k + 1
		rs.rules.insert(at, rule)
		if TIER_DAYS.has(n) and not rs.new_rule_ids.has(R43):
			rs.new_rule_ids.append(R43)
	if n >= 8:
		for id: StringName in [R44, R45, R46]:
			_ensure(rs, rules[id], n == 8)
	if n >= 19:
		_ensure(rs, rules[R47], n == 19)


static func _ensure(rs: RuleSet, rule: Rule, mark_new: bool) -> void:
	if not rs.has_rule(rule.id):
		rs.rules.append(rule)
	if mark_new and not rs.new_rule_ids.has(rule.id):
		rs.new_rule_ids.append(rule.id)


# ---------------------------------------------------------------------------
# Tables des déclarations (M13 §1.6, §1.11 ; B65)
# ---------------------------------------------------------------------------

const DURATIONS: Array[Array] = [
	["stmt_dur_w1", 6, 8], ["stmt_dur_d10", 9, 11], ["stmt_dur_w2", 12, 16], ["stmt_dur_w3", 18, 24],
	["stmt_dur_m1", 26, 34], ["stmt_dur_w6", 38, 46], ["stmt_dur_m2", 55, 65], ["stmt_dur_m3", 80, 100],
	["stmt_dur_m6", 170, 190], ["stmt_dur_y1", 350, 380], ["stmt_dur_y3", 1050, 1150],
]
const EMPLOYER_ALIASES: Dictionary[String, String] = {
	"Kessler-Ashe": "Kessler-Ashe Orbital",
	"Valcourt-Hsu": "Valcourt-Hsu Logistique",
	"Ondine": "Ondine Synaptique",
	"Meridian": "Meridian Biosystèmes",
	"Ceres-Verte": "Hydroponie Ceres-Verte",
	"Aurel": "Banque Aurel",
	"le Bureau": "Bureau de Continuité",
	"la Délégation": "Délégation tharsienne",
}
## Corporations du LORE (§6) dites par un menteur AV-3.
const LORE_CORPORATIONS: PackedStringArray = ["Kessler-Ashe Orbital", "Valcourt-Hsu Logistique", "Ondine Synaptique",
		"Meridian Biosystèmes", "Hydroponie Ceres-Verte", "Banque Aurel"]


## Longueurs des textes FR des cadres et fragments (sans emplacement) : le
## générateur choisit un cadre qui tient en 90 caractères une fois rempli.
static func build_statement_tables(text_of: Callable) -> StatementTablesDef:
	var t: StatementTablesDef = StatementTablesDef.new()
	for spec: Array in DURATIONS:
		t.duration_keys.append(str(spec[0]))
		t.duration_ranges.append(Vector2i(int(spec[1]), int(spec[2])))
	t.exact_duration_keys = {1: "stmt_dur_d1", 2: "stmt_dur_d2", 3: "stmt_dur_d3", 4: "stmt_dur_d4", 5: "stmt_dur_d5"}
	t.exact_key = "stmt_dur_n"
	t.exact_max = 60
	t.interval_above = 10
	t.vague_keys = PackedStringArray(["stmt_dur_vague_1", "stmt_dur_vague_2", "stmt_dur_vague_3", "stmt_dur_vague_4",
			"stmt_dur_vague_5"])
	# QA-068 : « Le temps du contrat », « Ça dépend du travail » : motif TRAVAIL seulement.
	t.vague_work_keys = PackedStringArray(["stmt_dur_vague_2", "stmt_dur_vague_5"])
	for purpose: StringName in [Passenger.PURPOSE_WORK, Passenger.PURPOSE_FAMILY_VISIT, Passenger.PURPOSE_RETURN,
			Passenger.PURPOSE_TRADE, Passenger.PURPOSE_TRANSIT, Passenger.PURPOSE_DIPLOMATIC]:
		t.purpose_keys[purpose] = PackedStringArray(["stmt_purpose_%s_1" % purpose, "stmt_purpose_%s_2" % purpose])
	for faction: StringName in [&"tyc", &"hal", &"ter", &"cer", &"thr", &"drv"]:
		t.origin_keys[faction] = "stmt_origin_%s" % faction
	t.employer_key = "stmt_employer"
	# QA-068 : « au Bureau », jamais « chez le Bureau ».
	t.employer_article_keys = {"le ": "stmt_employer_au", "les ": "stmt_employer_aux"}
	for relation: StringName in [&"sister", &"brother", &"son", &"daughter", &"mother", &"friend"]:
		t.host_keys[relation] = "stmt_host_%s" % relation
	t.family_relations = PackedStringArray(["sister", "brother", "son", "daughter", "mother"])
	t.provenance_shuttle_key = "stmt_prov_shuttle"
	t.provenance_place_key = "stmt_prov_place"
	t.provenance_tessar_key = "stmt_prov_tessar"
	t.provenance_places = PackedStringArray(["Tycho", "Cérès", "la Terre", "l'Anneau B"])
	t.employer_aliases = EMPLOYER_ALIASES.duplicate()
	t.vague_employers = PackedStringArray(["les serres", "la station"])
	t.lore_employers = LORE_CORPORATIONS.duplicate()
	t.frames = {
		&"gen": PackedStringArray(["line_stmt_frame_gen_1", "line_stmt_frame_gen_2", "line_stmt_frame_gen_3",
				"line_stmt_frame_gen_4"]),
		&"tyc": PackedStringArray(["line_stmt_frame_tyc_1", "line_stmt_frame_tyc_2", "line_stmt_frame_tyc_3"]),
		&"hal": PackedStringArray(["line_stmt_frame_hal_1", "line_stmt_frame_hal_2"]),
		&"ter": PackedStringArray(["line_stmt_frame_ter_1", "line_stmt_frame_ter_2", "line_stmt_frame_ter_3"]),
		&"cer": PackedStringArray(["line_stmt_frame_cer_1", "line_stmt_frame_cer_2"]),
		&"thr": PackedStringArray(["line_stmt_frame_thr_1", "line_stmt_frame_thr_2"]),
		&"drv": PackedStringArray(["line_stmt_frame_drv_1", "line_stmt_frame_drv_2"]),
	}
	t.work_frames = PackedStringArray(["line_stmt_frame_work_1", "line_stmt_frame_work_2"])
	t.visit_frames = PackedStringArray(["line_stmt_frame_visit_1", "line_stmt_frame_visit_2"])
	t.correction_frames = PackedStringArray(["line_stmt_frame_correct_1", "line_stmt_frame_correct_2"])
	t.stay_frames = PackedStringArray(["line_stmt_stay_1", "line_stmt_stay_2", "line_stmt_stay_3"])
	# QA-068 : durée vague — ni « C'est ce qu'on m'a accordé », ni « Pas un jour
	# de plus », ni « pour {duree} », « {duree}, pas plus », « {duree},
	# normalement », « {duree}, le temps du chantier ».
	t.stay_frames_vague = PackedStringArray(["line_stmt_stay_3", "line_stmt_stay_4"])
	t.vague_unfit_frames = PackedStringArray(["line_stmt_frame_gen_2", "line_stmt_frame_gen_3", "line_stmt_frame_work_2",
			"line_stmt_frame_visit_2"])
	t.origin_frames = PackedStringArray(["line_stmt_origin_1", "line_stmt_origin_3"])
	t.origin_contrast_frames = PackedStringArray(["line_stmt_origin_3"])
	t.origin_places = {&"tyc": "Tycho", &"cer": "Cérès", &"ter": "la Terre"}
	t.origin_frames_plain = PackedStringArray(["line_stmt_origin_2"])
	t.origin_frames_drv = PackedStringArray(["line_stmt_origin_drv_1", "line_stmt_origin_drv_2"])
	t.origin_frames_tessar = PackedStringArray(["line_stmt_origin_tessar_1"])
	t.generic_frame_rate = 0.5
	t.lie_purposes = {
		&"tyc": PackedStringArray(["work", "family_visit", "return"]),
		&"hal": PackedStringArray(["return", "work", "trade"]),
		&"ter": PackedStringArray(["work", "family_visit"]),
		&"cer": PackedStringArray(["trade", "transit"]),
		&"thr": PackedStringArray(["trade", "diplomatic"]),
		&"drv": PackedStringArray(["transit", "trade"]),
	}
	t.vague_rate = 0.12
	t.correction_rate = 0.08
	t.provenance_rate = 0.15
	t.tessar_rates = {&"tyc": 0.10, &"drv": 0.20}
	t.alias_rate = 0.5
	t.hesitation_rate = 0.25
	t.lie_gap_min = 4
	t.lie_gap_ratio = 0.40
	t.lie_gap_subtle = 2
	t.max_line_length = 90
	var token: RegEx = RegEx.create_from_string("\\{([a-z_]+)\\}")
	for key: String in _text_keys(t):
		var text: String = str(text_of.call(key))
		if key.begins_with("line_stmt_"):
			var tokens: PackedStringArray = []
			for found: RegExMatch in token.search_all(text):
				tokens.append(found.get_string(1))
			t.frame_tokens[key] = tokens
			text = token.sub(text, "", true)
		t.text_lengths[key] = text.length()
	return t


## Clés de texte dont la longueur compte pour le choix des cadres.
static func _text_keys(t: StatementTablesDef) -> PackedStringArray:
	var keys: PackedStringArray = []
	keys.append_array(t.duration_keys)
	for n: int in t.exact_duration_keys:
		keys.append(t.exact_duration_keys[n])
	keys.append(t.exact_key)
	keys.append_array(t.vague_keys)
	for purpose: StringName in t.purpose_keys:
		keys.append_array(t.purpose_keys[purpose])
	for faction: StringName in t.origin_keys:
		keys.append(t.origin_keys[faction])
	keys.append(t.employer_key)
	for article: String in t.employer_article_keys:
		keys.append(t.employer_article_keys[article])
	for relation: StringName in t.host_keys:
		keys.append(t.host_keys[relation])
	keys.append_array([t.provenance_shuttle_key, t.provenance_place_key, t.provenance_tessar_key])
	for faction: StringName in t.frames:
		keys.append_array(t.frames[faction])
	for list: PackedStringArray in [t.work_frames, t.visit_frames, t.correction_frames, t.stay_frames, t.stay_frames_vague, t.origin_frames,
			t.origin_frames_plain, t.origin_frames_drv, t.origin_frames_tessar]:
		keys.append_array(list)
	return keys


# ---------------------------------------------------------------------------
# Catalogue de la fouille (M13 §2.4–§2.7 ; B69, B73)
# ---------------------------------------------------------------------------

## Localisation des implants dissimulables (LORE §8, `ImplantCatalog.location`).
const IMPLANT_ZONES: Dictionary[String, StringName] = {
	"NX-12": &"z1", "NX-18": &"z1", "NX-25": &"z1",
	"DER-6": &"z2", "MIL-2": &"z2",
	"KIN-11": &"z3", "DER-13": &"z3", "MIL-15": &"z3",
	"KIN-17": &"z4",
}


static func build_search_catalog() -> SearchCatalogDef:
	var c: SearchCatalogDef = SearchCatalogDef.new()
	var L := SearchItem.Kind.LEGIT
	c.items = [
		_item(&"ol01", L, &"personal", ["z2", "z5"]),
		_item(&"ol02", L, &"credits", ["z2", "z5"], Vector2i(10, 100)),
		_item(&"ol03", L, &"medicine", ["z2", "z5"], Vector2i.ZERO, &"cb03"),
		_item(&"ol04", L, &"oxygen", ["z2", "z5"], Vector2i.ZERO, &"cb01"),
		_item(&"ol05", L, &"tools", ["z3", "z5"]),
		_item(&"ol06", L, &"data", ["z1", "z5"], Vector2i.ZERO, &"cb04"),
		_item(&"ol07", L, &"goods", ["z5"], Vector2i.ZERO, &"", Passenger.PURPOSE_TRADE),
		_item(&"ol08", L, &"food", ["z5"]),
		_item(&"ol09", L, &"clothes", ["z5"]),
		_item(&"ol10", SearchItem.Kind.IMPLANT, &"implant", ["z1", "z2", "z3", "z4"]),
		_item(&"cb01", SearchItem.Kind.CONTRABAND, &"oxygen", ["z2", "z5"], Vector2i(2, 8), &"ol04"),
		_item(&"cb02", SearchItem.Kind.CONTRABAND, &"stimulant", ["z2", "z5"], Vector2i(6, 12)),
		_item(&"cb03", SearchItem.Kind.CONTRABAND, &"medicine", ["z2", "z5"], Vector2i(6, 12), &"ol03"),
		_item(&"cb04", SearchItem.Kind.CONTRABAND, &"data", ["z1", "z5"], Vector2i.ZERO, &"ol06"),
		_item(&"cb05", SearchItem.Kind.CONTRABAND, &"seeds", ["z5", "z2"]),
		_item(&"cb06", SearchItem.Kind.WEAPON, &"blade", ["z3", "z4", "z5"]),
		_item(&"cb07", SearchItem.Kind.WEAPON, &"jammer", ["z2", "z5"]),
		_item(&"cb08", SearchItem.Kind.SUBVERSIVE, &"print", ["z2", "z5"]),
	]
	for item: SearchItemDef in c.items:
		match item.kind:
			SearchItem.Kind.CONTRABAND:
				item.rule_id = R45
			SearchItem.Kind.WEAPON:
				item.rule_id = R46
	c.cue_hit_rates = {&"satchel": 0.8, &"bulge": 0.8, &"glove": 0.8, &"gait": 0.7, &"collar": 0.7}
	c.cue_explanations = {&"satchel": &"ol03", &"bulge": &"ol04", &"glove": &"ol10", &"gait": &"ol10", &"collar": &"ol06"}
	c.cue_motive_keys = {&"satchel": "srch_cue_satchel", &"bulge": "srch_cue_bulge", &"glove": "srch_cue_glove",
			&"gait": "srch_cue_gait", &"collar": "srch_cue_collar"}
	c.implant_zones = IMPLANT_ZONES.duplicate()
	c.civil_concealed = {
		&"tyc": PackedStringArray(["NX-12", "KIN-11"]),
		&"hal": PackedStringArray(["NX-18", "DER-13"]),
		&"ter": PackedStringArray(["DER-6"]),
		&"cer": PackedStringArray(["KIN-11", "DER-6"]),
		&"thr": PackedStringArray(["KIN-17", "NX-25"]),
		&"drv": PackedStringArray(["DER-6"]),
	}
	c.undeclared_civil = PackedStringArray(["NX-25", "DER-6", "KIN-11", "DER-13", "KIN-17"])
	c.undeclared_military = PackedStringArray(["MIL-2", "MIL-15"])
	c.unreadable_implants = PackedStringArray(["DER-19"])
	c.contraband_by_faction = {
		&"cer": PackedStringArray(["cb01", "cb05"]),
		&"tyc": PackedStringArray(["cb01", "cb03"]),
		&"hal": PackedStringArray(["cb04"]),
		&"drv": PackedStringArray(["cb02", "cb05"]),
	}
	c.default_contraband = PackedStringArray(["cb01", "cb02", "cb03", "cb04", "cb05"])
	c.weapons = PackedStringArray(["cb06", "cb07"])
	c.body_item_rate = 0.3
	c.baggage_items = Vector2i(1, 3)
	c.declared_concealed_rate = 0.08
	c.evasive_innocent_rate = 0.04
	c.evasive_carrier_rate = 0.70
	c.evasive_carrier_share = 0.1667
	c.first_day = 8
	return c


static func _item(id: StringName, kind: SearchItem.Kind, category: StringName, zones: Array, quantity: Vector2i = Vector2i.ZERO,
		twin: StringName = &"", purpose: StringName = &"") -> SearchItemDef:
	var item: SearchItemDef = SearchItemDef.new()
	item.id = id
	item.kind = kind
	item.category = category
	item.name_key = "item_%s_name" % id
	item.desc_key = "item_%s_desc" % id
	item.zones = PackedStringArray(zones)
	item.quantity = quantity
	item.twin_id = twin
	item.purpose = purpose
	return item


# ---------------------------------------------------------------------------
# Améliorations du guichet AG-01 → AG-06 (M13 §3 ; B74, D-150)
# ---------------------------------------------------------------------------

static func build_upgrades() -> Array[UpgradeDef]:
	# Passe économique (D-168) : AG-01 → AG-03 à 25 ₵ (20 ₵ au lot B) — achats
	# `smart` à 80 % ramenés dans les cibles de M13 §4.4 (AG-01 75 → 70 %,
	# AG-03 49 → 44 %) et moins de vitesse gagnée à l'Acte II.
	var ag01: UpgradeDef = _upgrade(UpgradeDef.ID_HYGIAPHONE, 25, 5, 29)
	var ag02: UpgradeDef = _upgrade(UpgradeDef.ID_WOOD_LAMP, 25, 9, 29)
	var ag03: UpgradeDef = _upgrade(UpgradeDef.ID_CALIBRATED_GATE, 25, 9, 29)
	ag03.note_key = "upg_ag03_note"
	ag03.effects = {UpgradeDef.EFFECT_SUSPICION_ON_FOUND: 1}
	var ag04: UpgradeDef = _upgrade(UpgradeDef.ID_DOUBLE_DRAWER, 15, 5, 16)
	ag04.note_key = "upg_ag04_note"
	ag04.condition = Act3._all([&"bribe_seen"])
	ag04.off_catalog = true
	ag04.offer_message_key = "msg_soute_drawer"
	# QA-069 : M13 §3.5 — un mot glissé (voix sans signature), Okonkwo, le Bureau.
	ag04.offer_speaker_key = "spk_note"
	ag04.offer_voice = BriefingContent.Voice.BRULANTS
	ag04.expense_key = "exp_upgrade_ag04"
	ag04.effects = {UpgradeDef.EFFECT_ENVELOPE_TRACE_EVERY: 2, UpgradeDef.EFFECT_AUDIT_PENALTY: 2}
	var ag05: UpgradeDef = _upgrade(UpgradeDef.ID_ANNOTATED_BOOK, 10, 6, 8)
	ag05.off_catalog = true
	ag05.offer_message_key = "msg_okonkwo_book"
	ag05.offer_speaker_key = BriefingContent.SPEAKER_OKONKWO
	ag05.offer_voice = BriefingContent.Voice.MENTOR
	ag05.purchase_flags = {&"okonkwo_book": 0}
	var ag06: UpgradeDef = _upgrade(UpgradeDef.ID_QUEUE_MONITOR, 35, 11, 29)
	ag06.note_key = "upg_ag06_note"
	ag06.offer_message_key = "msg_vh_monitor"
	ag06.offer_speaker_key = "spk_consortium"
	ag06.offer_voice = BriefingContent.Voice.CONSORTIUM
	ag06.purchase_flags = {&"loyalty": 1}
	return [ag01, ag02, ag03, ag04, ag05, ag06]


static func _upgrade(id: StringName, price: int, first: int, last: int) -> UpgradeDef:
	var u: UpgradeDef = UpgradeDef.new()
	u.id = id
	u.name_key = "upg_%s_name" % id
	u.desc_key = "upg_%s_desc" % id
	u.price = price
	u.expense_key = "exp_upgrade_%s" % id
	u.first_evening = first
	u.last_evening = last
	return u


## Barème : coûts en temps (M13 §1.10, §2.3), catalogue de l'Économat.
static func configure_economy(e: EconomyDef, upgrades: Array[UpgradeDef]) -> void:
	e.interrogation_timing = InterrogationTiming.new()
	e.upgrades = upgrades.duplicate()
	e.shop_open_evening = 5
	e.upgrades_per_evening = 1
	# Passe économique (D-168) : prime de relevé (REFUS / DÉTENTION justes et
	# documentés d'une trouvaille de M13) — rend les 7 à 10 ₵ de citations et de
	# salaire que M13 coûtait au J20 et au J29, et le salaire de la compensation
	# de temps réduite (`M13Sim.extra_seconds`).
	e.finding_bonus = 2


# ---------------------------------------------------------------------------
# Garde de nuit : U21 → U24 (M13 §2.11 ; B76, D-152)
# ---------------------------------------------------------------------------

static func build_garde_units(rules: Dictionary[StringName, Rule],
		tiers: Array[StatementsConsistentRule]) -> Array[GardeUnitDef]:
	var u21: GardeUnitDef = _unit(&"u21", [rules[R43]], 2, [&"u01"], [])
	var u22: GardeUnitDef = _unit(&"u22", [rules[R44], rules[R45]], 3, [], ["contraband"])
	var u23: GardeUnitDef = _unit(&"u23", [rules[R46]], 3, [&"u22", &"u11"], [])
	# Palier s3 (employeur et origine) : remplace le palier s1 de U21 (même identifiant).
	var u24: GardeUnitDef = _unit(&"u24", [tiers[1]], 3, [&"u21", &"u16"], [])
	return [u21, u22, u23, u24]


static func _unit(id: StringName, unit_rules: Array[Rule], tier: int, prerequisites: Array[StringName],
		tabs: Array) -> GardeUnitDef:
	var unit: GardeUnitDef = GardeUnitDef.new()
	unit.id = id
	unit.title_key = "garde_unit_%s" % id
	unit.rules = unit_rules
	unit.tier = tier
	unit.prerequisites = prerequisites
	unit.rulebook_tabs = PackedStringArray(tabs)
	return unit


## `garde_version` 2 ; poids des nouveaux types (filtrés par les règles actives).
static func configure_garde(g: GardeDef) -> void:
	g.version = 2
	var d: DayDef = g.day_template
	d.anomaly_weights[K.STATEMENT_MISMATCH] = 0.08
	d.anomaly_weights[K.CONTRABAND] = 0.06
	d.anomaly_weights[K.CONCEALED_IMPLANT] = 0.03
	d.anomaly_weights[K.CONCEALED_WEAPON] = 0.02
	d.statement_topic_weights = {&"purpose": 0.25, &"stay": 0.25, &"employer": 0.25, &"origin": 0.25}
	d.search_cue_noise_rate = 0.10


# ---------------------------------------------------------------------------
# Événements : EV-05 suspend R44 et R47 (D-172), EV-09 « Alerte des quais » (M13 §2.10 ; B77)
# ---------------------------------------------------------------------------

static func extend_events(events: Array[StationEventDef]) -> void:
	for event: StationEventDef in events:
		if event.key == &"blackout":
			# Portique hors tension : ni fouille sur motif (R44) ni fouille
			# obligatoire des Ceinturiers (R47, D-172 / QA-063 : sans quoi un
			# Ceinturier au long séjour en règle ne peut être que cité FOUILLE
			# OMISE ou refusé à tort). Retirer une règle absente (R47 avant le
			# J19) ne fait rien.
			for rule_id: StringName in [R44, R47]:
				var note: String = "sev_blackout_rb_search" if rule_id == R44 else "sev_blackout_rb_belt_search"
				event.changes.append(RuleChangeDef.retire(rule_id, note))
				event.garde_changes.append(RuleChangeDef.retire(rule_id, note))
	var alert: StationEventDef = M12._event(9, &"contraband_alert", StationEventDef.EventClass.A)
	alert.required_rule_id = R44
	alert.day_min = 8
	alert.window_kind = StationEventDef.WindowKind.PASSENGERS
	alert.window_passengers = 5
	alert.rulebook_key = "sev_contraband_alert_rb"
	# Profil « fouille autorisée » (MF-4, M13 §2.10) tiré par plan (graine du
	# jour, ou de la directive en Garde) : Tycho, Cérès, motif COMMERCE ou motif
	# TRANSIT ; 1 ou 2 porteurs du profil dans la fenêtre
	# (`CaseBuilder.on_rules_changed`). La portée des données (Cérès) reste le
	# repli d'un plan sans profil.
	alert.changes = [RuleChangeDef.override(R44, {&"search_authorized": true}, [&"cer"])]
	alert.garde_changes = [RuleChangeDef.override(R44, {&"search_authorized": true}, [&"cer"])]
	alert.override_profiles = [
		{"faction_ids": [&"tyc"], "purposes": [], "label_key": "sev_contraband_alert_tyc"},
		{"faction_ids": [&"cer"], "purposes": [], "label_key": "sev_contraband_alert_cer"},
		{"faction_ids": [], "purposes": [Passenger.PURPOSE_TRADE], "label_key": "sev_contraband_alert_trade"},
		{"faction_ids": [], "purposes": [Passenger.PURPOSE_TRANSIT], "label_key": "sev_contraband_alert_transit"},
	] as Array[Dictionary]
	alert.garde_required_unit = &"u22"
	alert.garde_window_passengers = 5
	alert.garde_announce_key = "sev_contraband_alert_announce_garde"
	events.append(alert)


## `events_version` + 1 (D-136 : tirage stratifié par version).
static func configure_station_events(def: StationEventsDef) -> void:
	def.version = 2


# ---------------------------------------------------------------------------
# Jours de campagne (M13 §4.2, §5 ; B75)
# ---------------------------------------------------------------------------

## Révise un jour de campagne avant sa sauvegarde. Renvoie les erreurs (index
## occupé…) ; vide si tout va bien.
static func extend_day(day: DayDef) -> PackedStringArray:
	var n: int = day.day_number
	var errors: PackedStringArray = []
	if n < 4:
		return errors
	day.duration_sec += M13Sim.extra_seconds(n)
	if FREE_CITATION_DAYS.has(n):
		day.free_citations_per_day = maxi(day.free_citations_per_day, 3)
	# Déclarations (R43).
	if PURPOSE_MISMATCH_CUT.has(n) and day.anomaly_weights.has(K.PURPOSE_MISMATCH):
		day.anomaly_weights[K.PURPOSE_MISMATCH] = snappedf(day.anomaly_weights[K.PURPOSE_MISMATCH] - PURPOSE_MISMATCH_CUT[n], 0.001)
	day.anomaly_weights[K.STATEMENT_MISMATCH] = STATEMENT_WEIGHTS.get(n, 0.06)
	day.statement_topic_weights = topic_weights_for(n)
	# Fouille (R44 → R46, J8+).
	if n >= 8:
		var search: Array = SEARCH_WEIGHTS.get(n, SEARCH_WEIGHTS_DEFAULT)
		day.anomaly_weights[K.CONTRABAND] = search[0]
		day.anomaly_weights[K.CONCEALED_IMPLANT] = search[1]
		day.anomaly_weights[K.CONCEALED_WEAPON] = search[2]
		day.search_cue_noise_rate = SEARCH_NOISE_J16 if n == 16 else float(search[3])
		if not day.rulebook_tabs.has("contraband"):
			day.rulebook_tabs.append("contraband")
	for scripted: ScriptedCaseDef in cases_for(n):
		var problem: String = M12.check_free_index(day, scripted.at_index, scripted.id)
		if not problem.is_empty():
			errors.append(problem)
		day.scripted_cases.append(scripted)
	_extend_narrative(day)
	return errors


## Poids conditionnels AV-1 → AV-5 du jour (M13 §1.5).
static func topic_weights_for(n: int) -> Dictionary[StringName, float]:
	var row: Array = TOPIC_WEIGHTS[0]
	for spec: Array in TOPIC_WEIGHTS:
		if n >= int(spec[0]):
			row = spec
	var result: Dictionary[StringName, float] = {}
	var topics: Array[StringName] = [&"purpose", &"stay", &"employer", &"origin", &"host"]
	for i: int in topics.size():
		if float(row[i + 1]) > 0.0:
			result[topics[i]] = float(row[i + 1])
	return result


## Briefings, intercom, soirées, échos (M13 §5.1, §5.2).
static func _extend_narrative(day: DayDef) -> void:
	match day.day_number:
		4:
			day.intercom_lines.append_array([
				IntercomLineDef.make("okonkwo_j4_statement", IntercomLineDef.TRIGGER_STATEMENT_GIVEN),
				IntercomLineDef.make("okonkwo_j4_statement_pinned", IntercomLineDef.TRIGGER_STATEMENT_PINNED),
				IntercomLineDef.make("okonkwo_j4_statement_vague", IntercomLineDef.TRIGGER_STATEMENT_VAGUE),
				IntercomLineDef.make("okonkwo_j4_statement_missed", IntercomLineDef.TRIGGER_CASE_RESOLVED, &"sc_104:approve"),
			])
		8:
			day.briefing_messages.append_array([
				Act3._msg("spk_consortium", "msg_cons_day08_portique", V_CONSORTIUM, null, &"", 1),
				Act3._msg("spk_lucioles", "msg_luc_day08_search", V_LUCIOLES, Act3._gauge(&"lucioles_trust", 1), &"", 0),
			])
			day.intercom_lines.append_array([
				IntercomLineDef.make("okonkwo_j8_search_nomotive", IntercomLineDef.TRIGGER_SEARCH_OPENED,
						IntercomLineDef.ARG_NO_MOTIVE),
				IntercomLineDef.make("okonkwo_j8_search_first", IntercomLineDef.TRIGGER_SEARCH_OPENED),
				IntercomLineDef.make("okonkwo_j8_search_clean", IntercomLineDef.TRIGGER_SEARCH_CLEAN),
			])
			_add_extra_line(day, &"d08_dora", "hh_dora_search", null)
		9:
			var zeal: BriefingMessageDef = Act3._msg("spk_okonkwo", "msg_okonkwo_day09_zeal", V_MENTOR,
					Act3._gauge(&"fouille_abus", 2), &"okonkwo09", 0)
			for message: BriefingMessageDef in day.briefing_messages:
				if message.text_key == "msg_okonkwo_day09":
					message.group = &"okonkwo09"
			day.briefing_messages.insert(0, zeal)
			day.briefing_messages.append(Act3._msg("spk_hall", "msg_hall_day09_portique", V_CONSORTIUM, null, &"", 0))
			_add_extra_line(day, &"d09_ilan", "msg_ilan_day09_portique", null)
			day.evening_events.append(_letter(&"d09_air_refused", 4, Act3._all([&"sc106_air_refused"]),
					"hh_dora_air_refused", {}))
		10:
			day.evening_events.append(_letter(&"d10_air_cartridge", 5, Act3._all([&"sc106_air_passed"]),
					"hh_air_cartridge", {&"oxygen": 0}))
		12:
			day.intercom_lines.append(IntercomLineDef.make("sato_j12_employer", IntercomLineDef.TRIGGER_STATEMENT_GIVEN,
					&"employer", "spk_sato"))
		16:
			day.evening_events.append(_letter(&"d16_soute_medicine", 9, Act3._all([&"sc108_ilse_passed"]),
					"hh_soute_medicine_cheap", {&"meds": 10}))
		17:
			day.briefing_messages.append(Act3._msg("spk_lucioles", "msg_luc_day17_ilse", V_LUCIOLES,
					Act3._all([&"sc108_ilse_passed"]), &"", 0))
			_add_extra_line(day, &"d17_review", "evt_d17_review_search_zeal", Act3._gauge(&"fouille_abus", 3))
		23:
			day.briefing_messages.append(Act3._msg("spk_hall", "msg_echo_sc111_detained", V_CONSORTIUM,
					Act3._all([&"sc111_whitmore_detained"]), &"", 0))
		25:
			day.briefing_messages.append(Act3._msg("spk_hall", "msg_echo_sc107_nair_passed", V_CONSORTIUM,
					Act3._all([&"sc107_nair_passed"]), &"", 0))
			for scripted: ScriptedCaseDef in day.scripted_cases:
				if scripted.id == &"sc_65":
					scripted.line_variants.insert(0, ConditionalKey.make("sc65_yara_arrival_mother_refused",
							Act3._all([&"sc110_sabine_refused"]), "arrival"))
					scripted.line_variants.insert(1, ConditionalKey.make("sc65_yara_arrival_mother_passed",
							Act3._all([&"sc110_sabine_passed"]), "arrival"))
		27:
			day.announcements.append(Act3._announce("hall_j27_cameras", 3, -1, Act3._all([&"sc111_whitmore_passed"])))


static func _add_extra_line(day: DayDef, event_id: StringName, key: String, condition: FlagCondition) -> void:
	for event: EveningEventDef in day.evening_events:
		if event.id == event_id:
			event.extra_keys.append(ConditionalKey.make(key, condition))
			return
	push_error("build_data_m13: événement %s absent du J%d" % [event_id, day.day_number])


static func _letter(id: StringName, order: int, condition: FlagCondition, text: String,
		costs: Dictionary[StringName, int]) -> EveningEventDef:
	var e: EveningEventDef = EveningEventDef.new()
	e.id = id
	e.kind = EveningEventDef.Kind.LETTER
	e.order = order
	e.condition = condition
	e.text_key = text
	e.line_costs = costs
	return e


# ---------------------------------------------------------------------------
# Cas scénarisés SC-104 → SC-111 (M13 §5.3)
# ---------------------------------------------------------------------------

static func cases_for(day_number: int) -> Array[ScriptedCaseDef]:
	match day_number:
		4:
			return [_sc104_strand()]
		8:
			return [_sc105_mbeki()]
		9:
			return [_sc106_zuri()]
		12:
			return [_sc107_nair()]
		16:
			return [_sc108_ilse()]
		19:
			return [_sc109_kerr()]
		22:
			return [_sc111_whitmore()]
		24:
			return [_sc110_sabine()] if Passenger.has_truth_path(Statement.PATH_SPONSOR_NAME) else []
	return []


static func _stmt(value: Variant, key: String, args: Array = []) -> Dictionary:
	return {"value": value, "key": key, "args": args}


static func _duration(min_days: int, max_days: int, key: String, args: Array = []) -> Dictionary:
	return {"value": Vector2i(min_days, max_days), "key": key, "args": args}


## SC-104 · J4 @5 — « Trois semaines » : premier mensonge oral (AV-2), REFUSÉ par R43.
static func _sc104_strand() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_104", 5, {&"faction_id": &"cer", &"citizen_class": &"C-4",
			&"sex": Passenger.SEX_M, &"given_name": "Jory", &"family_name": "Strand",
			&"birth_date": GameDate.from_ymd(2160, 2, 11), &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 5,
			&"implants": PackedStringArray()}, [K.STATEMENT_MISMATCH], &"sc104_strand", {&"topic": "stay"},
			{&"sc104_strand_passed": 0}, {&"sc104_strand_refused": 0})
	s.statements = {
		"purpose": _stmt("trade", "stmt_purpose_trade_1"),
		"stay": _duration(18, 24, "stmt_dur_w3"),
	}
	s.statement_frames = {"purpose": "line_stmt_frame_gen_1", "stay": "line_stmt_stay_1"}
	return s


## SC-105 · J8 @5 — « Le gant » : première fouille, une innocente (KIN-11 déclaré) ; APPROUVÉ.
static func _sc105_mbeki() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_105", 5, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"sex": Passenger.SEX_F, &"given_name": "Rosalind", &"family_name": "Mbeki",
			&"birth_date": GameDate.from_ymd(2143, 1, 19), &"purpose": Passenger.PURPOSE_WORK, &"stay_days": 30,
			&"employer": EMPLOYER_KA, &"implants": PackedStringArray()}, [], &"sc105_mbeki", {},
			{&"sc105_mbeki_passed": 0}, {&"sc105_mbeki_refused": 0})
	s.statements = {
		"purpose": _stmt("work", "stmt_purpose_work_1"),
		"stay": _duration(26, 34, "stmt_dur_m1"),
	}
	s.search_items = [
		{"zone": "z3", "implant": "KIN-11", "declared": true},
		{"zone": "z5", "item": "ol01"},
		{"zone": "z5", "item": "ol05"},
	]
	s.search_cues = [SearchLayout.CUE_GLOVE]
	s.cargo_reply = Case.CARGO_NONE
	s.flags_on_search = {&"sc105_searched": 0}
	return s


## SC-106 · J9 @6 — « Six souffles » : six cartouches d'O₂ sans scellé (CB-01) ; REFUSÉ par R45.
static func _sc106_zuri() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_106", 6, {&"faction_id": &"cer", &"citizen_class": &"C-4",
			&"sex": Passenger.SEX_F, &"given_name": "Zuri", &"family_name": "Oduya",
			&"birth_date": GameDate.from_ymd(2152, 7, 3), &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 4,
			&"implants": PackedStringArray()}, [K.CONTRABAND], &"sc106_zuri", {},
			{&"sc106_air_passed": 0}, {&"sc106_air_refused": 0})
	s.statements = {
		"purpose": _stmt("trade", "stmt_purpose_trade_1"),
		"stay": _duration(4, 4, "stmt_dur_d4"),
	}
	s.search_items = [{"zone": "z2", "item": "cb01", "qty": 6}, {"zone": "z5", "item": "ol09"}]
	s.search_cues = [SearchLayout.CUE_BULGE]
	s.cargo_reply = Case.CARGO_NONE
	s.flags_on_search = {&"sc106_searched": 0}
	# Ravel dans le Hall : un scan qui montre les cartouches suivi d'une approbation se voit.
	s.extra_effects = [Act3._effect(&"approve", Act3._all([&"sc106_searched"]), {&"suspicion": 1})]
	return s


## SC-107 · J12 @5 — « Le courtier » : contradiction honnête sur l'employeur (AV-3) ; REFUSÉ par R43.
static func _sc107_nair() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_107", 5, {&"faction_id": &"ter", &"citizen_class": &"C-3",
			&"sex": Passenger.SEX_F, &"given_name": "Priya", &"family_name": "Nair",
			&"birth_date": GameDate.from_ymd(2163, 5, 27), &"purpose": Passenger.PURPOSE_WORK, &"stay_days": 90,
			&"employer": EMPLOYER_KA, &"implants": PackedStringArray()}, [K.STATEMENT_MISMATCH], &"sc107_nair",
			{&"topic": "employer"}, {&"sc107_nair_passed": 0}, {&"sc107_nair_refused": 0})
	s.statements = {
		"purpose": _stmt("work", "stmt_purpose_work_1"),
		"stay": _duration(80, 100, "stmt_dur_m3"),
		"employer": _stmt("Hydroponie Ceres-Verte", "stmt_employer", ["Ceres-Verte"]),
	}
	s.statement_frames = {"purpose": "line_stmt_frame_work_1"}
	return s


## SC-108 · J16 @5 — « Ce qui manque en bas » : antiviraux sans étiquette (CB-03), mot des
## Lucioles ; REFUSÉ par R45.
static func _sc108_ilse() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_108", 5, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"sex": Passenger.SEX_F, &"given_name": "Ilse", &"family_name": "Ivanova",
			&"birth_date": GameDate.from_ymd(2149, 9, 14), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 3,
			&"implants": PackedStringArray()}, [K.CONTRABAND], &"sc108_ilse", {&"permit_suffix": 7},
			{&"sc108_ilse_passed": 0, &"lucioles_trust": 1}, {&"sc108_ilse_refused": 0})
	s.flags_on_detain = {&"lucioles_trust": -2}
	s.luciole_codes = PackedInt32Array([3, 6])
	s.statements = {
		"purpose": _stmt("family_visit", "stmt_purpose_family_visit_1"),
		"stay": _duration(3, 3, "stmt_dur_d3"),
	}
	s.search_items = [{"zone": "z5", "item": "cb03", "qty": 12}, {"zone": "z5", "item": "ol08"}]
	s.search_cues = [SearchLayout.CUE_SATCHEL]
	s.cargo_reply = Case.CARGO_EVASIVE
	s.flags_on_search = {&"sc108_searched": 0}
	s.extra_effects = [Act3._effect(&"deny", Act3._all([&"sc108_searched"]), {&"lucioles_trust": -1})]
	s.slipped_item = Act3._item(SlippedItem.Kind.NOTE, "sc108_note_label", "sc108_note", [KEEP, RETURN, REPORT], RETURN,
			{&"report": {&"sc108_note_reported": 0, &"loyalty": 1, &"lucioles_trust": -2}}, 10)
	return s


## SC-109 · J19 @4 — « Le doyen » : R47, fouille obligatoire d'un passager propre ; APPROUVÉ après fouille.
static func _sc109_kerr() -> ScriptedCaseDef:
	var identity: Dictionary = Act2._kerr(Passenger.SEX_X, GameDate.from_ymd(2135, 12, 21))
	identity[&"stay_days"] = 14
	var s: ScriptedCaseDef = Act3._scripted(&"sc_109", 4, identity, [], &"sc109_kerr", {},
			{&"sc109_kerr_passed": 0}, {&"sc109_kerr_refused": 0})
	s.identity_from_case = &"sc_32"
	s.appearance_from_case = &"sc_32"
	s.statements = {
		"purpose": _stmt("trade", "stmt_purpose_trade_1"),
		"stay": _duration(12, 16, "stmt_dur_w2"),
	}
	s.search_items = [{"zone": "z5", "item": "ol07"}, {"zone": "z5", "item": "ol08"}, {"zone": "z2", "item": "ol02", "qty": 60}]
	s.cargo_reply = Case.CARGO_GOODS
	return s


## SC-110 · J24 @4 (répondant généré @3) — « La personne visitée » : répondant acheté (AV-5) ;
## REFUSÉ par R43 (et R34 si @3 a été refusé).
static func _sc110_sabine() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_110", 4, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"sex": Passenger.SEX_F, &"given_name": "Sabine", &"family_name": "Moreno-Lind",
			&"birth_date": GameDate.from_ymd(2129, 8, 2), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 7,
			&"implants": PackedStringArray()}, [K.STATEMENT_MISMATCH], &"sc110_sabine", {&"topic": "host"},
			{&"sc110_sabine_passed": 0}, {&"sc110_sabine_refused": 0})
	s.sponsor_index = 3
	s.statements = {
		"purpose": _stmt("family_visit", "stmt_purpose_family_visit_1"),
		"stay": _duration(6, 8, "stmt_dur_w1"),
		"host": _stmt("Tomás Moreno-Lind", "stmt_host_son", ["Tomás Moreno-Lind"]),
	}
	s.statement_frames = {"purpose": "line_stmt_frame_visit_1"}
	return s


## SC-111 · J22 @5 — « La valise de Mme Whitmore » : émetteur de brouillage (CB-07) ; DÉTENTION (R46).
static func _sc111_whitmore() -> ScriptedCaseDef:
	var s: ScriptedCaseDef = Act3._scripted(&"sc_111", 5, {&"faction_id": &"hal", &"citizen_class": &"C-2",
			&"sex": Passenger.SEX_F, &"given_name": "Mei", &"family_name": "Whitmore",
			&"birth_date": GameDate.from_ymd(2141, 4, 9), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Valcourt-Hsu Logistique", &"implants": PackedStringArray()}, [K.CONCEALED_WEAPON],
			&"sc111_whitmore", {}, {&"sc111_whitmore_passed": 0}, {&"sc111_whitmore_refused": 0})
	s.flags_on_detain = {&"sc111_whitmore_detained": 0}
	s.statements = {"purpose": _stmt("return", "stmt_purpose_return_1")}
	s.search_items = [{"zone": "z5", "item": "cb07"}, {"zone": "z5", "item": "ol09"}]
	s.search_cues = [SearchLayout.CUE_SATCHEL]
	s.cargo_reply = Case.CARGO_EVASIVE
	return s
