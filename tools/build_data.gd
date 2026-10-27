## Générateur des données (`res://data/**/*.tres`) — documents, origines MVP,
## règles, RuleSets et DayDef des jours 1–3 (GDD §7, §8, §10, §12 ; LORE §5, §9) ;
## M3 : réserves de noms, champs générateur des origines, catalogue
## d'apparences placeholder (BOOTH_SCENE §12.2, identifiants seulement).
##
## Usage (depuis la racine du projet, après `godot --headless --import`) :
##   godot --headless --script res://tools/build_data.gd
##
## Pourquoi un générateur : les `.tres` contiennent des sous-ressources, des
## références partagées (une règle dans plusieurs RuleSets), des dictionnaires
## typés à clés d'enum et des dates en jours absolus : écrits à la main, ils
## sont fragiles. Le script est la source de régénération ; les UID existants
## sont conservés et les sous-ressources ont des identifiants stables pour que
## les diffs restent lisibles. Si un designer retouche un `.tres` dans
## l'inspecteur, il reporte la valeur ici (ou abandonne le script pour ce
## fichier) : le test `test_data_integrity.gd` valide le résultat dans tous les cas.
extends SceneTree

const DOCS_DIR: String = "res://data/documents"
const FACTIONS_DIR: String = "res://data/factions"
const RULES_DIR: String = "res://data/rules"
const DAYS_DIR: String = "res://data/days"
const NAMES_DIR: String = "res://data/names"
const APPEARANCE_DIR: String = "res://data/appearance"
const ECONOMY_DIR: String = "res://data/economy"

const K := AnomalyType.Kind
const FK := FieldDef.FieldKind
const CAT := Rule.RuleCategory

var _failures: int = 0


func _init() -> void:
	_build()
	print("build_data : %s" % ("OK" if _failures == 0 else "%d échec(s)" % _failures))
	quit(1 if _failures > 0 else 0)


func _build() -> void:
	_build_factions(_build_name_pools())
	_build_appearance_catalog()
	var docs: Dictionary[StringName, DocumentTypeDef] = _build_documents()
	var rules: Dictionary[StringName, Rule] = _build_rules()
	var sets: Array[RuleSet] = _build_rule_sets(rules)
	_build_days(sets)
	_build_economy()
	assert(docs.size() == 3)


# ---------------------------------------------------------------------------
# Économie du foyer (GDD §5.3, §5.4) — M5
# ---------------------------------------------------------------------------

func _build_economy() -> void:
	var e: EconomyDef = EconomyDef.new()
	# D-047 (équilibrage du foyer, `tools/balance_sim.gd`) : avance du Consortium
	# à la prise de poste, chauffage 8 → 6 ₵, réaffectation au 3ᵉ loyer impayé.
	e.starting_credits = 20
	e.rent = 15
	e.rent_raised = 20
	e.rent_raise_day = 8
	e.air_tax = 5
	e.food = 10
	e.heating = 6
	e.oxygen = 10
	e.oxygen_every_n_days = 2
	e.medicine_per_member = 15
	e.noa_cold_sick_chance = 0.5
	e.deprivation_sick_evenings = 2
	e.untreated_worsen_evenings = 2
	e.oxygen_grave_misses = 2
	e.eviction_unpaid_rent = 3
	e.debt_evenings_limit = 3
	e.detain_bonus = 5
	_save(e, ECONOMY_DIR, "economy")


# ---------------------------------------------------------------------------
# Origines (MVP : TYC, HAL, TER — GDD §8.3, LORE §5)
# ---------------------------------------------------------------------------

func _build_factions(pools: Dictionary[StringName, NamePool]) -> void:
	var tyc: FactionDef = _faction(&"tyc", "TYC", "HG-4", ["Colonie Tycho (Lune)", "Cratère Tycho — dortoirs Kessler-Ashe"])
	tyc.citizen_class_weights = {&"C-3": 0.80, &"C-4": 0.15, &"C-2": 0.05}
	tyc.purpose_weights = {Passenger.PURPOSE_WORK: 0.75, Passenger.PURPOSE_FAMILY_VISIT: 0.15, Passenger.PURPOSE_RETURN: 0.10}
	tyc.employers = ["Kessler-Ashe Orbital", "Valcourt-Hsu Logistique", "Ondine Synaptique"]
	var hal: FactionDef = _faction(&"hal", "HAL", "HG-1", ["Anneaux D–F", "Anneau C — logements de service", "Coursives d'Halcyon Gate"])
	hal.citizen_class_weights = {&"C-1": 0.05, &"C-2": 0.25, &"C-3": 0.45, &"C-4": 0.25}
	hal.purpose_weights = {Passenger.PURPOSE_RETURN: 0.70, Passenger.PURPOSE_WORK: 0.20, Passenger.PURPOSE_TRADE: 0.10}
	hal.employers = ["Bureau de Continuité", "Banque Aurel", "Valcourt-Hsu Logistique", "Meridian Biosystèmes", "Ondine Synaptique"]
	var ter: FactionDef = _faction(&"ter", "TER", "HG-2", ["Terre — Concordat des Zones Sèches"])
	ter.citizen_class_weights = {&"C-4": 0.65, &"C-3": 0.35}
	ter.purpose_weights = {Passenger.PURPOSE_WORK: 0.55, Passenger.PURPOSE_FAMILY_VISIT: 0.30, Passenger.PURPOSE_TRANSIT: 0.15}
	ter.employers = ["Kessler-Ashe Orbital", "Valcourt-Hsu Logistique", "Hydroponie Ceres-Verte", "Meridian Biosystèmes"]
	for faction: FactionDef in [tyc, hal, ter]:
		faction.name_pool = pools[faction.id]
		_save(faction, FACTIONS_DIR, "faction_%s" % faction.id)


# ---------------------------------------------------------------------------
# Réserves de noms (LORE §5 : 15 prénoms + 15 noms par origine)
# ---------------------------------------------------------------------------

func _build_name_pools() -> Dictionary[StringName, NamePool]:
	var pools: Array[NamePool] = [
		_pool(&"tyc",
				["Mira", "Ilse", "Anouk", "Yara", "Rosalind", "Elena", "Sabine"],
				["Tomás", "Dmitri", "Lev", "Bastien", "Kasimir", "Joaquín", "Arkady"],
				["Noor"],
				["Vasquez-Orlov", "Brandt", "Kowalczyk", "Moreno-Lind", "Petrenko", "Achebe-Sörensen", "Duval",
				"Halvorsen", "Navarro", "Ivanova", "Lindqvist-Rey", "Mbeki", "Castellanos", "Novak", "Oyelaran-Holm"]),
		_pool(&"hal",
				["Céleste", "Ophélie", "Margaux", "Adaeze", "Mei", "Isadora", "Philippa"],
				["Auguste", "Hiro", "Soren", "Valentin", "Corentin", "Kenji", "Aurelio"],
				["Lin"],
				["Valcourt", "Hsu", "Aurel", "Delacroix-Tan", "Whitmore", "Okafor", "Langlois", "Sato", "Ferreira",
				"Lindgren", "Beaumont", "Choi", "Ravel", "Montclair", "Adeyemi"]),
		_pool(&"ter",
				["Amara", "Fatou", "Leila", "Ana-Lucía", "Priya", "Inès", "Ngozi", "Samira"],
				["Rahul", "Mateus", "Kwame", "Tariq", "Emeka", "Bilal", "Diego"],
				[],
				["Diallo", "Ramanathan", "Haddad", "Okonkwo", "Silva", "Mensah", "Rahman", "Benali", "Gutiérrez",
				"Abara", "Nair", "Mahmoud", "Tembo", "Quispe", "Ferhat"]),
	]
	# Okonkwo, le mentor du J1 (LORE §5.3), n'est jamais généré.
	pools[2].reserved_names = ["Okonkwo"]
	var result: Dictionary[StringName, NamePool] = {}
	for pool: NamePool in pools:
		_save(pool, NAMES_DIR, "namepool_%s" % pool.id)
		result[pool.id] = pool
	return result


func _pool(id: StringName, f: PackedStringArray, m: PackedStringArray, x: PackedStringArray, family: PackedStringArray) -> NamePool:
	var pool: NamePool = NamePool.new()
	pool.id = id
	pool.given_names_f = f
	pool.given_names_m = m
	pool.given_names_x = x
	pool.family_names = family
	return pool


# ---------------------------------------------------------------------------
# Catalogue d'apparences placeholder (BOOTH_SCENE §12.2 : identifiants seulement)
# ---------------------------------------------------------------------------

func _build_appearance_catalog() -> void:
	var catalog: AppearanceCatalog = AppearanceCatalog.new()
	catalog.min_distance = 5
	catalog.window_size = 15
	catalog.max_attempts = 12
	catalog.age_band_weights = PackedFloat32Array([0.35, 0.45, 0.20])
	catalog.height_step_range = Vector2i(-2, 2)

	var silhouettes: Array[AppearanceOptionDef] = []
	for id: String in ["s1_stocky", "s2_slender", "s3_medium", "s4_slight"]:
		silhouettes.append(_option("silhouette_" + id))
	silhouettes[0].faction_weights = {&"ter": 1.5}

	var faces: Array[AppearanceOptionDef] = []
	for shape: String in ["round", "square", "oval", "angular"]:
		for ears: int in 3:
			faces.append(_option("face_%s_e%d" % [shape, ears + 1]))

	var eyes: Array[AppearanceOptionDef] = [
		_option("eyes_brown", 3.0), _option("eyes_hazel", 2.0), _option("eyes_green"),
		_option("eyes_blue"), _option("eyes_grey"), _option("eyes_heterochromia", 0.1),
	]

	var nose_mouth: Array[AppearanceOptionDef] = []
	for nose: int in 3:
		for lips: int in 2:
			nose_mouth.append(_option("nose_mouth_n%d_l%d" % [nose + 1, lips + 1]))

	var skins: Array[AppearanceOptionDef] = []
	for i: int in 8:
		skins.append(_option("skin_%02d" % (i + 1)))
	# Peau grise de la poussière lunaire (LORE §5.1).
	skins[7].faction_weights = {&"tyc": 3.0}
	skins[7].tags = ["tycho_grey"]

	var hair: Array[AppearanceOptionDef] = []
	for cut: String in ["short", "long", "bun", "braids", "curly", "mohawk", "shaved"]:
		for colour: int in 10:
			hair.append(_option("hair_%s_c%02d" % [cut, colour + 1], 0.6 if colour >= 6 else 1.0))

	var headwear: Array[AppearanceOptionDef] = [
		_option(String(PassengerAppearance.OPTION_NONE), 6.0), _option("hood"), _option("cap"), _option("beanie"),
		_option(String(PassengerAppearance.VISOR_DOWN), 0.0), _option(String(PassengerAppearance.VISOR_UP), 0.0),
	]

	var outfits: Array[AppearanceOptionDef] = []
	for i: int in 8:
		outfits.append(_option("outfit_%02d" % (i + 1)))

	var accessories: Array[AppearanceOptionDef] = [
		_option(String(PassengerAppearance.OPTION_NONE), 5.0), _option("half_visor"), _option("respirator_neck"),
		_option("scarf"), _option("holo_tattoo_1", 0.5), _option("holo_tattoo_2", 0.5),
		_option("holo_tattoo_3", 0.5), _option("holo_tattoo_4", 0.5),
	]

	var palettes: Array[AppearanceOptionDef] = []
	for i: int in 12:
		palettes.append(_option("palette_%02d" % (i + 1)))

	catalog.slots = [
		_slot(&"silhouette", true, false, silhouettes),
		_slot(&"face", true, true, faces),
		_slot(&"eyes", true, true, eyes),
		_slot(&"nose_mouth", true, true, nose_mouth),
		_slot(&"skin", true, true, skins),
		_slot(PassengerAppearance.SLOT_HAIR, false, true, hair),
		_slot(PassengerAppearance.SLOT_HEADWEAR, false, false, headwear),
		_slot(&"outfit", false, false, outfits),
		_slot(PassengerAppearance.SLOT_ACCESSORY, false, false, accessories),
		_slot(PassengerAppearance.SLOT_PALETTE, false, false, palettes),
	]
	for slot: AppearanceSlotDef in catalog.slots:
		slot.resource_scene_unique_id = "slot_%s" % slot.id
		for option: AppearanceOptionDef in slot.options:
			option.resource_scene_unique_id = "opt_%s_%s" % [slot.id, option.id]
	_save(catalog, APPEARANCE_DIR, "appearance_catalog")


func _slot(id: StringName, identity: bool, in_portrait: bool, options: Array[AppearanceOptionDef]) -> AppearanceSlotDef:
	var slot: AppearanceSlotDef = AppearanceSlotDef.new()
	slot.id = id
	slot.identity = identity
	slot.visible_in_portrait = in_portrait
	slot.options = options
	return slot


func _option(id: String, weight: float = 1.0) -> AppearanceOptionDef:
	var option: AppearanceOptionDef = AppearanceOptionDef.new()
	option.id = StringName(id)
	option.weight = weight
	return option


func _faction(id: StringName, code: String, prefix: String, sectors: PackedStringArray) -> FactionDef:
	var f: FactionDef = FactionDef.new()
	f.id = id
	f.name_key = "faction_%s_name" % id
	f.code = code
	f.id_prefix = prefix
	f.origin_sectors = sectors
	return f


# ---------------------------------------------------------------------------
# Documents (GDD §7, LORE §9)
# ---------------------------------------------------------------------------

func _build_documents() -> Dictionary[StringName, DocumentTypeDef]:
	var result: Dictionary[StringName, DocumentTypeDef] = {}

	var card: DocumentTypeDef = _doc(&"id_card", &"bureau_continuite", &"seal_solar_hexagon",
			"HG-#NNN-XXXX", Vector2i(1825, 3650), &"ACCENT_YELLOW")
	card.fields = [
		_field(&"portrait", FK.PORTRAIT, &"appearance"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"sex", FK.ENUM, &"sex"),
		_field(&"origin", FK.ENUM, &"faction_id"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"citizen_class", FK.ENUM, &"citizen_class"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id", false),
	]
	result[card.id] = card

	var permit: DocumentTypeDef = _doc(&"entry_permit", &"autorite_transit", &"seal_barred_ring",
			"PE-YYYY-NNNNN", Vector2i(14, 180), &"ACCENT_CYAN")
	permit.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"purpose", FK.ENUM, &"purpose"),
		_field(&"stay_days", FK.NUMBER, &"stay_days"),
		_field(&"employer", FK.TEXT, &"employer"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id", false),
	]
	result[permit.id] = permit

	var bioscan: DocumentTypeDef = _doc(&"bioscan", &"clinique_meridian", &"seal_orbit_cross",
			"BS-NNNNN", Vector2i(30, 30), &"ACCENT_CYAN")
	bioscan.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"health_status", FK.ENUM, &"health_status"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
	]
	result[bioscan.id] = bioscan

	for doc: DocumentTypeDef in result.values():
		for i: int in doc.fields.size():
			doc.fields[i].display_order = i
			doc.fields[i].resource_scene_unique_id = "field_%s" % doc.fields[i].id
		_save(doc, DOCS_DIR, "doc_%s" % doc.id)
	return result


func _doc(id: StringName, issuer: StringName, seal: StringName, pattern: String,
		validity: Vector2i, tint: StringName) -> DocumentTypeDef:
	var d: DocumentTypeDef = DocumentTypeDef.new()
	d.id = id
	d.title_key = "doc_%s_title" % id
	d.issuer_id = issuer
	d.seal_id = seal
	d.serial_pattern = pattern
	d.validity_days = validity
	d.holo_tint_token = tint
	return d


func _field(id: StringName, kind: FieldDef.FieldKind, truth_path: StringName, comparable: bool = true) -> FieldDef:
	var f: FieldDef = FieldDef.new()
	f.id = id
	f.label_key = "field_%s" % id
	f.kind = kind
	f.truth_path = truth_path
	f.comparable = comparable
	if kind == FK.DATE:
		f.format = FieldDef.DEFAULT_DATE_FORMAT
	return f


# ---------------------------------------------------------------------------
# Règles (GDD §7) : R01–R08 (MVP + R08 procédure J4), R10–R14 (J4–J5)
# ---------------------------------------------------------------------------

func _build_rules() -> Dictionary[StringName, Rule]:
	var rules: Array[Rule] = []

	var r01: RequireDocumentRule = RequireDocumentRule.new()
	r01.document_id = &"id_card"
	rules.append(_rule(r01, &"r_id_card_required", CAT.DOCUMENTS, 2))

	var r02: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r02.document_id = &"id_card"
	rules.append(_rule(r02, &"r_id_card_valid", CAT.DOCUMENTS, 2))

	var r03: PortraitMatchRule = PortraitMatchRule.new()
	rules.append(_rule(r03, &"r_portrait_match", CAT.IDENTITY, 2))

	var r04: RequireDocumentRule = RequireDocumentRule.new()
	r04.document_id = &"entry_permit"
	r04.exempt_faction_ids = [&"hal"]
	rules.append(_rule(r04, &"r_permit_required", CAT.DOCUMENTS, 2))

	var r05: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r05.document_id = &"entry_permit"
	rules.append(_rule(r05, &"r_permit_valid", CAT.DOCUMENTS, 2))

	var r06: ProcedureRule = ProcedureRule.new()
	r06.procedure_id = ProcedureRule.PROCEDURE_FACE_UNCOVERED
	rules.append(_rule(r06, &"r_face_uncovered", CAT.SPECIAL, 1))

	var r07: FieldsMatchRule = FieldsMatchRule.new()
	r07.truth_paths = [&"family_name", &"given_name", &"birth_date", &"citizen_id"]
	r07.detected_anomalies = [K.NAME_MISMATCH, K.ID_MISMATCH]
	rules.append(_rule(r07, &"r_identity_fields_match", CAT.IDENTITY, 2))

	var r08: ProcedureRule = ProcedureRule.new()
	r08.procedure_id = ProcedureRule.PROCEDURE_TYCHO_INTERVIEW
	r08.applies_to_faction_ids = [&"tyc"]
	rules.append(_rule(r08, &"r_tycho_interview", CAT.SPECIAL, 1))

	var r10: OriginIdBlockRule = OriginIdBlockRule.new()
	rules.append(_rule(r10, &"r_origin_block", CAT.IDENTITY, 2))

	var r11: RequireDocumentRule = RequireDocumentRule.new()
	r11.document_id = &"bioscan"
	rules.append(_rule(r11, &"r_bioscan_required", CAT.DOCUMENTS, 2))

	var r12: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r12.document_id = &"bioscan"
	r12.max_age_days = 30
	rules.append(_rule(r12, &"r_bioscan_valid", CAT.DOCUMENTS, 2))

	var r13: IssuerAllowedRule = IssuerAllowedRule.new()
	r13.document_id = &"bioscan"
	r13.allowed_issuer_ids = [&"clinique_meridian"]
	rules.append(_rule(r13, &"r_bioscan_issuer", CAT.DOCUMENTS, 2))

	var r14: FieldValueAllowedRule = FieldValueAllowedRule.new()
	r14.document_id = &"bioscan"
	r14.truth_path = &"health_status"
	r14.allowed_values = [Passenger.HEALTH_FIT]
	r14.detected_anomalies = [K.BIOSCAN_UNFIT]
	rules.append(_rule(r14, &"r_bioscan_fit", CAT.SPECIAL, 2))

	var result: Dictionary[StringName, Rule] = {}
	for rule: Rule in rules:
		_save(rule, RULES_DIR, "rule_%s" % String(rule.id).trim_prefix("r_"))
		result[rule.id] = rule
	return result


func _rule(rule: Rule, id: StringName, category: Rule.RuleCategory, severity: int) -> Rule:
	rule.id = id
	rule.title_key = "%s_title" % id
	rule.rulebook_text_key = "%s_text" % id
	rule.category = category
	rule.severity = severity
	return rule


# ---------------------------------------------------------------------------
# RuleSets J1–J3 (liste explicite et cumulative, GDD §8.1)
# ---------------------------------------------------------------------------

func _build_rule_sets(rules: Dictionary[StringName, Rule]) -> Array[RuleSet]:
	var new_d1: Array[StringName] = [&"r_id_card_required", &"r_id_card_valid"]
	var new_d2: Array[StringName] = [&"r_portrait_match"]
	var new_d3: Array[StringName] = [&"r_permit_required", &"r_permit_valid", &"r_face_uncovered", &"r_identity_fields_match"]
	var d1: Array[StringName] = new_d1.duplicate()
	var d2: Array[StringName] = d1.duplicate()
	d2.append_array(new_d2)
	var d3: Array[StringName] = d2.duplicate()
	d3.append_array(new_d3)
	var sets: Array[RuleSet] = [
		_rule_set(&"rs_day01", rules, d1, new_d1),
		_rule_set(&"rs_day02", rules, d2, new_d2),
		_rule_set(&"rs_day03", rules, d3, new_d3),
	]
	for i: int in sets.size():
		_save(sets[i], DAYS_DIR, "ruleset_day_%02d" % (i + 1))
	return sets


func _rule_set(id: StringName, rules: Dictionary[StringName, Rule], ids: Array[StringName], new_ids: Array[StringName]) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	rs.id = id
	for rule_id: StringName in ids:
		rs.rules.append(rules[rule_id])
	rs.new_rule_ids = new_ids.duplicate()
	rs.required_document_ids = rs.compute_required_document_ids()
	return rs


# ---------------------------------------------------------------------------
# Jours 1–3 (GDD §10) et passagers scénarisés (GDD §12)
# ---------------------------------------------------------------------------

func _build_days(sets: Array[RuleSet]) -> void:
	var mvp_factions: Dictionary[StringName, float] = {&"tyc": 0.45, &"hal": 0.25, &"ter": 0.30}

	var d1: DayDef = _day(1, sets[0], 540.0, 8, [0.55, 0.45, 0.0, 0.0],
			{K.EXPIRED_DOCUMENT: 0.6, K.MISSING_DOCUMENT: 0.4}, mvp_factions, 0.0, 0.10)
	d1.scripted_cases = [
		_scripted(&"sc_01", 0, {&"faction_id": &"hal", &"citizen_class": &"C-3", &"purpose": Passenger.PURPOSE_RETURN,
				&"origin_sector": "Anneau C — logements de service"}, [], &"sc01_returning_technician"),
		_scripted(&"sc_02", 1, {&"faction_id": &"ter", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4"},
				[K.EXPIRED_DOCUMENT], &"sc02_hurried_mother", {&"document_id": &"id_card", &"expired_days": 3},
				{&"sc02_mercy": 0}, {&"sc02_turned_away": 0}),
		_scripted(&"tuto_concordant", 2, {}, [], &""),
		_scripted(&"tuto_missing_document", 3, {}, [K.MISSING_DOCUMENT], &""),
	]

	var d2: DayDef = _day(2, sets[1], 570.0, 10, [0.50, 0.45, 0.05, 0.0],
			{K.EXPIRED_DOCUMENT: 0.4, K.MISSING_DOCUMENT: 0.2, K.PORTRAIT_MISMATCH: 0.4}, mvp_factions, 0.0, 0.15)
	d2.scripted_cases = [
		_scripted(&"sc_03", 3, {&"faction_id": &"tyc", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
				&"purpose": Passenger.PURPOSE_WORK}, [K.PORTRAIT_MISMATCH], &"sc03_nervous_miner",
				{&"trait_count": 3, &"photo_noise": true}, {&"sc03_passed": 0}, {}),
	]

	var d3: DayDef = _day(3, sets[2], 600.0, 11, [0.45, 0.45, 0.10, 0.0],
			{K.EXPIRED_DOCUMENT: 0.25, K.MISSING_DOCUMENT: 0.15, K.PORTRAIT_MISMATCH: 0.2,
			K.ID_MISMATCH: 0.2, K.NAME_MISMATCH: 0.2}, mvp_factions, 0.15, 0.20)
	var mira: ScriptedCaseDef = _scripted(&"sc_04", 2, {
		&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
		&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc",
		&"citizen_id": "HG-4471-K2Q9", &"citizen_class": &"C-3",
		&"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital",
	}, [], &"sc04_mira")
	mira.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: &"visor_down"}
	mira.sets_flag = &"met_mira"
	var messenger: ScriptedCaseDef = _scripted(&"sc_05", 7, {&"faction_id": &"tyc", &"citizen_class": &"C-3"},
			[K.ID_MISMATCH], &"sc05_luciole_messenger", {&"document_id": &"entry_permit", &"char_count": 1},
			{&"lucioles_trust": 1, &"sc05_helped": 0}, {})
	messenger.sets_flag = &"lucioles_contact"
	d3.scripted_cases = [mira, messenger]

	for day: DayDef in [d1, d2, d3]:
		for scripted: ScriptedCaseDef in day.scripted_cases:
			scripted.resource_scene_unique_id = "scripted_%s" % scripted.id
		_save(day, DAYS_DIR, "day_%02d" % day.day_number)


func _day(n: int, rule_set: RuleSet, duration: float, count: int, count_weights: Array[float],
		weights: Dictionary[AnomalyType.Kind, float], factions: Dictionary[StringName, float], visor: float, noise: float) -> DayDef:
	var d: DayDef = DayDef.new()
	d.day_number = n
	d.game_date = GameDate.from_ymd(2187, 3, 12 + n)
	d.rule_set = rule_set
	d.duration_sec = duration
	d.passenger_count = count
	d.anomaly_count_weights = PackedFloat32Array(count_weights)
	d.anomaly_weights = weights.duplicate()
	d.intro_text_key = "day%02d_intro" % n
	d.credit_per_correct = 5
	d.penalty_per_error = 5
	d.faction_weights = factions.duplicate()
	d.visor_down_rate = visor
	d.legit_noise_rate = noise
	d.bribe_rate = 0.0
	d.luciole_rate = 0.0
	d.free_citations_per_day = 2
	d.penalty_escalated = 10
	return d


func _scripted(id: StringName, index: int, overrides: Dictionary, anomalies: Array[AnomalyType.Kind],
		dialogue: StringName, params: Dictionary = {}, on_approve: Dictionary[StringName, int] = {},
		on_deny: Dictionary[StringName, int] = {}) -> ScriptedCaseDef:
	var s: ScriptedCaseDef = ScriptedCaseDef.new()
	s.flags_on_approve = on_approve
	s.flags_on_deny = on_deny
	s.injection_params = params
	s.id = id
	s.at_index = index
	s.passenger_overrides = overrides
	s.forced_anomalies = anomalies
	s.dialogue_id = dialogue
	return s


# ---------------------------------------------------------------------------
# Sauvegarde (UID conservés, chemin pris en charge pour les références partagées)
# ---------------------------------------------------------------------------

func _save(res: Resource, dir: String, basename: String) -> void:
	var path: String = dir.path_join(basename + ".tres")
	var old_uid: int = ResourceUID.INVALID_ID
	if FileAccess.file_exists(path):
		old_uid = ResourceLoader.get_resource_uid(path)
	res.take_over_path(path)
	var err: Error = ResourceSaver.save(res, path)
	if err != OK:
		push_error("build_data: échec de sauvegarde %s (%s)" % [path, error_string(err)])
		_failures += 1
		return
	# Hors éditeur, le TextResourceSaver n'écrit pas d'UID : on pose (ou on
	# conserve) celui du fichier pour des références stables (D-027).
	var uid: int = old_uid if old_uid != ResourceUID.INVALID_ID else ResourceUID.create_id_for_path(path)
	if ResourceSaver.set_uid(path, uid) != OK:
		push_error("build_data: UID non écrit pour %s" % path)
		_failures += 1
	print("  écrit %s" % path)
