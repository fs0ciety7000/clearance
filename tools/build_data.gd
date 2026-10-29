## Générateur des données (`res://data/**/*.tres`) — documents, origines MVP,
## règles, RuleSets et DayDef des jours 1–3 (GDD §7, §8, §10, §12 ; LORE §5, §9) ;
## M3 : réserves de noms, champs générateur des origines, catalogue
## d'apparences placeholder (BOOTH_SCENE §12.2, identifiants seulement).
## M7 : origines CER/THR/DRV, implants, MRZ, sceaux, dérogation MIL, règles
## R09, R15–R22, jours 4–10 (GDD §8, NARRATIVE §3–§5 : SC-06 → SC-22,
## briefings conditionnels, soirées, avis de recherche). Toutes les
## sous-ressources reçoivent un identifiant stable (`_tag_subresources`).
## Acte II (docs/ACT2.md, D-076 → D-079) : documents Contrat de travail,
## Laissez-passer de dérive, Attestation d'asile, Ticket de file, champ
## Firmware NX ; règles R23–R31 ; RuleSets et `DayDef` J11–J20 ; soirée pivot
## du J10 ; barème de l'Acte II. Le contenu des jours de l'Acte II est dans
## `tools/build_data_act2.gd` (fabriques statiques).
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
const Act2 := preload("res://tools/build_data_act2.gd")
const Act3 := preload("res://tools/build_data_act3.gd")
const FK := FieldDef.FieldKind
const CAT := Rule.RuleCategory

## Noms de famille distinctifs des personnages (NARRATIVE §1, §4 ; LORE §5.3) :
## jamais tirés pour un passager généré (QA-002). QA-022 : s'y ajoutent, calculés
## depuis les `DayDef`, les noms de famille de **tous** les personnages
## scénarisés des deux actes (Navarro, Kerr, Sato, Mensah…) et des avis nommés ;
## `reserved_full_names` (nom complet) reste le filet des noms non réservés.
const RESERVED_FAMILY_NAMES: PackedStringArray = ["Okonkwo", "Vasquez-Orlov", "Ravel", "Valcourt", "Petrenko",
		"Whitmore", "Novak", "Montclair", "Achebe-Sörensen", "Moreno-Lind", "Long-Ruban", "Basse-Marée",
		# Acte II (docs/ACT2.md §8.5) : récurrents et le cargo démantelé.
		"Lindgren", "Beaumont", "Oyelaran-Holm", "Lindqvist-Rey", "Sillage",
		# Acte III (docs/ACT3.md §4) : nouveaux personnages nommés.
		"Okafor", "Halvorsen", "Delacroix-Tan", "Sorel", "Adeyemi", "Kerr"]
## QA-022 : noms de famille de figurants ajoutés après les 15 du LORE §5 pour
## les origines dont la réserve tirable fondait (TYC et HAL : 5 noms sur 15 une
## fois les personnages réservés ; TER : 8) — 15 noms tirables au moins.
## Proposition au Lore Master (LORE §5 à compléter).
const EXTRA_FAMILY_NAMES: Dictionary[StringName, PackedStringArray] = {
	&"tyc": ["Ostrowski", "Varga", "Lindahl-Moreau", "Kuznetsova", "Abebe", "Rasmussen", "Tanaka-Roy", "Soto-Berg",
			"Hallorann", "Mendes-Ivers"],
	&"hal": ["Delaunay", "Ashworth", "Kobayashi", "Vidal-Mori", "Thorne", "Achterberg", "Nakamura",
			"Castelli", "Hargreave",
			# Acte III : Sorel, Okafor, Delacroix-Tan et Adeyemi deviennent des personnages.
			"Marchetti", "Ellery", "Fontaine-Wu", "Quennell", "Brightwater"],
	&"ter": ["Owusu", "Bello", "Chaudhry", "Kamau", "Sarr", "Mwangi", "Touré"],
}
## Prénoms du foyer de l'agent·e (LORE §6, NARRATIVE §1.2) : jamais générés.
const RESERVED_HOUSEHOLD_NAMES: PackedStringArray = ["Ilan", "Noa", "Dora"]

## Scripts de données chargés par ce générateur. Un script qui ne s'analyse pas
## ne bloque pas l'exécution (appels « Nonexistent function », `_build()`
## interrompu sans bruit) : vérifiés avant toute écriture.
const DATA_SCRIPTS: PackedStringArray = ["res://tools/build_data_act2.gd", "res://tools/build_data_act3.gd"]

## Compte les erreurs moteur et de script (`push_error`, erreurs d'exécution)
## émises pendant la génération : toute erreur fait échouer le build.
class ErrorCounter:
	extends Logger
	var count: int = 0
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		_mutex.unlock()

var _failures: int = 0
## Jours construits (ordre de construction), pour les noms réservés.
var _days: Array[DayDef] = []
## Vrai si `_build()` est allé à son terme (une erreur de script l'interrompt).
var _completed: bool = false


func _init() -> void:
	var errors: ErrorCounter = ErrorCounter.new()
	OS.add_logger(errors)
	if _data_scripts_ok():
		_build()
	OS.remove_logger(errors)
	var problems: PackedStringArray = []
	if _failures > 0:
		problems.append("%d échec(s) de chargement ou d'enregistrement" % _failures)
	if errors.count > 0:
		problems.append("%d erreur(s) moteur ou de script" % errors.count)
	if not _completed:
		problems.append("génération interrompue")
	if problems.is_empty():
		print("build_data : OK")
		quit(0)
		return
	printerr("build_data : ÉCHEC — %s ; données de res://data/ incomplètes ou invalides, voir les erreurs ci-dessus"
			% ", ".join(problems))
	quit(1)


## Chaque script de `DATA_SCRIPTS` se charge et compile ; sinon `_failures`.
func _data_scripts_ok() -> bool:
	var ok: bool = true
	for path: String in DATA_SCRIPTS:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			push_error("build_data: script de données illisible (erreur d'analyse ?) : %s" % path)
			_failures += 1
			ok = false
	return ok


func _build() -> void:
	var pools: Dictionary[StringName, NamePool] = _build_name_pools()
	_build_factions(pools)
	_build_appearance_catalog()
	var docs: Dictionary[StringName, DocumentTypeDef] = _build_documents()
	var rules: Dictionary[StringName, Rule] = _build_rules()
	var sets: Array[RuleSet] = _build_rule_sets(rules)
	_build_days(sets)
	_build_days_m7(sets)
	var act2_days: Array[DayDef] = Act2.build_days(sets)
	# Acte III (D-086) : le J20 gagne sa soirée pivot.
	Act3.extend_day20(act2_days[act2_days.size() - 1])
	for day: DayDef in act2_days:
		_save_day(day)
	var act3_sets: Array[RuleSet] = Act3.build_rule_sets(rules, sets[sets.size() - 1].get_rule_ids())
	for i: int in act3_sets.size():
		_save(act3_sets[i], DAYS_DIR, "ruleset_day_%02d" % (i + 21))
	for day: DayDef in Act3.build_days(act3_sets):
		_save_day(day)
	_build_economy()
	_reserve_character_names(pools)
	assert(docs.size() == 8)
	_completed = true


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
	# M7 (équilibrage J4–J10) : « mesures d'urgence » du J8, la taxe d'air double
	# avec l'ajustement des loyers (pression croissante des bons joueurs).
	e.air_tax_raised = 10
	e.air_tax_raise_day = 8
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
	# M7 (GDD §4.7, §5.5 ; NARRATIVE §5 J9, §6).
	e.report_bonus = 10
	e.audit_arrest_score = 4
	e.audit_retention_score = 2
	e.audit_retention = 30
	e.drift_min_credits = 30
	e.glory_min_compliance = 0.85
	# M11 (D-113, QA-049) : mode Récit plus protecteur, Dur inchangé. Mesuré
	# (`balance_sim --story`, 20 graines, profils à 65 %) : F1 5–15 % hors
	# mercenaire (50–80 % avant), F3 0 % (5–15 % avant).
	e.story_review_arrest_score = 7
	e.story_deposition_arrest_score = 10
	e.story_untreated_worsen_evenings = 3
	Act2.configure_economy(e)
	Act3.configure_economy(e)
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
	# M7 (LORE §8) : implants civils visibles, tirés les jours où R15 est active.
	tyc.implant_rate = 0.25
	tyc.implant_weights = {&"OPT-3": 1.0, &"NX-12": 1.0, &"KIN-5": 1.0}
	hal.implant_rate = 0.15
	hal.implant_weights = {&"OPT-14": 0.5, &"NX-18": 1.0, &"DER-13": 1.0, &"OPT-7": 0.5}
	ter.implant_rate = 0.10
	ter.implant_weights = {&"KIN-5": 0.5, &"DER-6": 1.0}
	# M7 : Ceinturiers (J4), Tharsiens (J6), Dérivants (J8) — LORE §5.4–§5.6.
	var cer: FactionDef = _faction(&"cer", "CER", "HG-6", ["Libre-Fédération de Cérès", "Ceinture — stations de prospection"])
	cer.citizen_class_weights = {&"C-4": 0.80, &"C-3": 0.20}
	cer.purpose_weights = {Passenger.PURPOSE_TRADE: 0.70, Passenger.PURPOSE_WORK: 0.20, Passenger.PURPOSE_TRANSIT: 0.10}
	cer.employers = ["Hydroponie Ceres-Verte", "Valcourt-Hsu Logistique", "Prospection indépendante"]
	cer.implant_rate = 0.25
	cer.implant_weights = {&"OPT-3": 1.0, &"DER-6": 1.0, &"KIN-11": 0.5, &"NX-4": 0.5}
	var thr: FactionDef = _faction(&"thr", "THR", "HG-7", ["Républiques de Tharsis (Mars)", "Tharsis — dômes d'Olympus"])
	thr.citizen_class_weights = {&"C-4": 0.60, &"C-5": 0.40}
	thr.purpose_weights = {Passenger.PURPOSE_DIPLOMATIC: 0.25, Passenger.PURPOSE_TRADE: 0.35,
			Passenger.PURPOSE_TRANSIT: 0.25, Passenger.PURPOSE_FAMILY_VISIT: 0.15}
	thr.employers = ["Délégation tharsienne", "Valcourt-Hsu Logistique", "Hydroponie Ceres-Verte"]
	thr.implant_rate = 0.20
	thr.implant_weights = {&"OPT-7": 1.0, &"NX-4": 0.5, &"KIN-17": 0.5}
	var drv: FactionDef = _faction(&"drv", "DRV", "HG-9", ["Cargos dérivants — sans port d'attache", "La Soute — amarrages des cargos"])
	drv.citizen_class_weights = {&"C-5": 1.0}
	drv.purpose_weights = {Passenger.PURPOSE_TRANSIT: 0.50, Passenger.PURPOSE_TRADE: 0.40, Passenger.PURPOSE_FAMILY_VISIT: 0.10}
	drv.employers = ["Équipage indépendant", "Valcourt-Hsu Logistique"]
	drv.implant_rate = 0.20
	drv.implant_weights = {&"DER-1": 1.0, &"NX-4": 0.5}
	# NARRATIVE §4.10 : environ la moitié des Dérivants nés « 00.00.AAAA ».
	drv.year_only_birth_rate = 0.5
	for faction: FactionDef in [tyc, hal, ter, cer, thr, drv]:
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
				PackedStringArray(["Vasquez-Orlov", "Brandt", "Kowalczyk", "Moreno-Lind", "Petrenko", "Achebe-Sörensen", "Duval",
				"Halvorsen", "Navarro", "Ivanova", "Lindqvist-Rey", "Mbeki", "Castellanos", "Novak", "Oyelaran-Holm"])
				+ PackedStringArray(EXTRA_FAMILY_NAMES[&"tyc"])),
		_pool(&"hal",
				["Céleste", "Ophélie", "Margaux", "Adaeze", "Mei", "Isadora", "Philippa"],
				["Auguste", "Hiro", "Soren", "Valentin", "Corentin", "Kenji", "Aurelio"],
				["Lin"],
				PackedStringArray(["Valcourt", "Hsu", "Aurel", "Delacroix-Tan", "Whitmore", "Okafor", "Langlois", "Sato", "Ferreira",
				"Lindgren", "Beaumont", "Choi", "Ravel", "Montclair", "Adeyemi"]) + PackedStringArray(EXTRA_FAMILY_NAMES[&"hal"])),
		_pool(&"ter",
				["Amara", "Fatou", "Leila", "Ana-Lucía", "Priya", "Inès", "Ngozi", "Samira"],
				["Rahul", "Mateus", "Kwame", "Tariq", "Emeka", "Bilal", "Diego"],
				[],
				PackedStringArray(["Diallo", "Ramanathan", "Haddad", "Okonkwo", "Silva", "Mensah", "Rahman", "Benali", "Gutiérrez",
				"Abara", "Nair", "Mahmoud", "Tembo", "Quispe", "Ferhat"]) + PackedStringArray(EXTRA_FAMILY_NAMES[&"ter"])),
		# M7 : LORE §5.4–§5.6 (prénoms répartis F / M / épicènes).
		_pool(&"cer",
				["Zuri", "Oksana", "Ilka", "Suvi", "Nadia", "Linnea"],
				["Kaito", "Ansel", "Matteo", "Jory", "Ezra", "Kofi"],
				["Tavi", "Ren", "Paz"],
				["Morrow", "Vance", "Takahashi-Bell", "Ruuska", "Calder", "Ibarra", "Szabo", "Kerr", "Amundsen",
				"Pak", "Oduya", "Strand", "Vela", "Marsh", "Kovač"]),
		_pool(&"thr",
				["Soledad", "Katya", "Hana", "Teodora", "Branka", "Ayla"],
				["Alexei", "Idris", "Marcus", "Dariusz", "Yusuf", "Elias", "Radomir", "Viktor"],
				["Ming"],
				["Arkhipov", "Reyes-Kahn", "Mazur", "Okoro", "Sandoval", "Jovanović", "Hadid", "Wei", "Kaczmarek",
				"Ulloa", "Demir", "Fonseca", "Rostova", "Abiodun", "Krall"]),
		_pool(&"drv",
				["Sefa", "Lumi", "Tamsin", "Ysolde", "Ezri", "Wren"],
				["Orin", "Pell", "Corvo", "Brin", "Mott"],
				["Kesh", "Nim", "Ashe", "Halo"],
				["Long-Ruban", "Sillage", "Pierre-Bleue", "Nadir", "Vasque", "Heliodore", "Mainsoleil", "Corail-9",
				"Basse-Marée", "Tessaride", "Cendre", "Kalliope", "Lointain", "Saint-Orbe", "Varech"]),
	]
	# Noms réservés (Okonkwo, personnages, foyer) : `_reserve_character_names`,
	# une fois les jours construits.
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
		# M7 : implants déclarés (R15/R16), sceau (R20), bande MRZ (R21).
		_field(&"implants", FK.LIST, &"implants"),
		# Acte II (R27) : mise à jour d'un shunt NX- (vide sans shunt).
		_field(&"firmware", FK.DATE, &"firmware_date"),
		_field(&"seal", FK.ENUM, &"document.seal_id"),
		_field(&"mrz", FK.ID_CODE, &"document.mrz"),
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
		_field(&"seal", FK.ENUM, &"document.seal_id"),
		# Acte III (M2, M3) : répondant (R34) et convocation (R36), vides sinon.
		_optional_field(&"sponsor", FK.ID_CODE, &"sponsor_id"),
		_optional_field(&"summons", FK.ID_CODE, &"summons_id"),
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
		_field(&"seal", FK.ENUM, &"document.seal_id"),
	]
	result[bioscan.id] = bioscan

	# M7 : dérogation d'implant militaire (LORE §9, document d'extension avancé
	# pour SC-11) — Autorité de Transit, anneau barré rouge, N° DM-NNNN.
	var waiver: DocumentTypeDef = _doc(&"mil_waiver", &"autorite_transit", &"seal_barred_ring_red",
			"DM-NNNN", Vector2i(90, 365), &"STATE_RED")
	waiver.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"authorized_implants", FK.LIST, &"implants"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"issuer", FK.ENUM, &"document.issuer_id", false),
		_field(&"seal", FK.ENUM, &"document.seal_id"),
	]
	result[waiver.id] = waiver

	# Acte II (docs/ACT2.md B19, LORE §9 « documents d'extension »).
	var contract: DocumentTypeDef = _doc(&"work_contract", &"bureau_contrats", &"seal_corporate",
			"CT-{EMP}-NNNN", Vector2i(90, 1095), &"ACCENT_CYAN")
	contract.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"employer", FK.TEXT, &"employer"),
		_field(&"contract_code", FK.ID_CODE, &"employer_code"),
		_field(&"post", FK.ENUM, &"post"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"seal", FK.ENUM, &"document.seal_id"),
	]
	result[contract.id] = contract
	var drift_pass: DocumentTypeDef = _doc(&"drift_pass", &"capitainerie_soute", &"seal_drift_ink",
			"LD-NNNN", Vector2i(30, 365), &"ACCENT_MAGENTA")
	drift_pass.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"vessel", FK.TEXT, &"vessel"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"seal", FK.ENUM, &"document.seal_id"),
	]
	result[drift_pass.id] = drift_pass
	var asylum: DocumentTypeDef = _doc(&"asylum", &"bureau_continuite", &"seal_asylum",
			"AA-NNNN", Vector2i(90, 365), &"TEXT_SECONDARY")
	asylum.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial"),
		_field(&"family_name", FK.TEXT, &"family_name"),
		_field(&"given_name", FK.TEXT, &"given_name"),
		_field(&"birth_date", FK.DATE, &"birth_date"),
		_field(&"citizen_id", FK.ID_CODE, &"citizen_id"),
		_field(&"zone", FK.TEXT, &"origin_sector"),
		_field(&"issue_date", FK.DATE, &"document.issue_date"),
		_field(&"expiry_date", FK.DATE, &"document.expiry_date"),
		_field(&"seal", FK.ENUM, &"document.seal_id"),
	]
	result[asylum.id] = asylum
	var ticket: DocumentTypeDef = _doc(&"queue_ticket", &"hall_guichets", &"",
			"TF-NNNN", Vector2i(1, 1), &"TEXT_SECONDARY")
	ticket.fields = [
		_field(&"serial", FK.ID_CODE, &"document.serial", false),
		_field(&"presented_at", FK.TIME, &"document.presented_at"),
	]
	result[ticket.id] = ticket

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


## Champ affiché seulement s'il est renseigné (`FieldDef.optional`).
func _optional_field(id: StringName, kind: FieldDef.FieldKind, truth_path: StringName) -> FieldDef:
	var f: FieldDef = _field(id, kind, truth_path)
	f.optional = true
	return f


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

	# --- M7 : R09, R15–R22 (GDD §7) ---
	rules.append(_rule(PurposeConsistentRule.new(), &"r_purpose_consistent", CAT.PURPOSE, 2))
	rules.append(_rule(ImplantsDeclaredRule.new(), &"r_implants_declared", CAT.IDENTITY, 2))
	rules.append(_rule(BannedImplantsRule.new(), &"r_banned_implants", CAT.SPECIAL, 2))
	var r17: PortraitMatchRule = PortraitMatchRule.new()
	r17.check_between_documents = false
	r17.max_differing_traits = 2
	r17.detected_anomalies = [K.IMPOSTOR_LOOKALIKE]
	rules.append(_rule(r17, &"r_identity_fraud_detain", CAT.IDENTITY, 3))
	rules.append(_rule(ApparentAgeRule.new(), &"r_apparent_age", CAT.IDENTITY, 3))
	var r19: FactionBannedRule = FactionBannedRule.new()
	r19.banned_faction_ids = [&"thr"]
	r19.exempt_purposes = [Passenger.PURPOSE_DIPLOMATIC]
	rules.append(_rule(r19, &"r_tharsis_banned", CAT.FACTION, 2))
	rules.append(_rule(SealValidRule.new(), &"r_seals_valid", CAT.DOCUMENTS, 2))
	rules.append(_rule(MrzConsistentRule.new(), &"r_mrz_valid", CAT.IDENTITY, 2))
	rules.append(_rule(WantedRule.new(), &"r_wanted_detain", CAT.IDENTITY, 3))

	# --- Acte II : R23–R31 (docs/ACT2.md §2.4) ---
	rules.append(_rule(AirQuotaRule.new(), &"r_air_quota", CAT.SPECIAL, 1))
	var r24: RequireDocumentRule = RequireDocumentRule.new()
	r24.document_id = &"work_contract"
	r24.applies_to_purposes = [Passenger.PURPOSE_WORK]
	r24.require_valid = true
	rules.append(_rule(r24, &"r_contract_required", CAT.DOCUMENTS, 2))
	var r25: ContractConsistentRule = ContractConsistentRule.new()
	r25.employer_codes = Act2.EMPLOYER_CODES.duplicate()
	# Acte III (SC-70, SC-64, SC-77) : l'Arbitrage de Continuité.
	r25.employer_codes[Act3.EMPLOYER_AR] = "AR"
	r25.posts = Act2.CONTRACT_POSTS.duplicate()
	rules.append(_rule(r25, &"r_contract_consistent", CAT.DOCUMENTS, 2))
	var r26: DriftPassRule = DriftPassRule.new()
	r26.document_id = &"drift_pass"
	r26.applies_to_faction_ids = [&"drv"]
	r26.require_valid = true
	r26.registered_vessels = Act2.registered_vessels()
	rules.append(_rule(r26, &"r_drift_pass", CAT.DOCUMENTS, 2))
	var r27: DocumentNotExpiredRule = DocumentNotExpiredRule.new()
	r27.document_id = &"id_card"
	r27.field_path = &"firmware_date"
	r27.max_age_days = 90
	r27.detected_anomalies = [K.OUTDATED_FIRMWARE]
	rules.append(_rule(r27, &"r_nx_firmware", CAT.IDENTITY, 2))
	var r28: RequireDocumentRule = RequireDocumentRule.new()
	r28.document_id = &"asylum"
	r28.applies_to_faction_ids = [&"ter"]
	r28.applies_to_classes = [&"C-5"]
	r28.require_valid = true
	rules.append(_rule(r28, &"r_asylum_required", CAT.DOCUMENTS, 2))
	rules.append(_rule(CurfewRule.new(), &"r_curfew", CAT.PURPOSE, 2))
	rules.append(_rule(RevokedIdRule.new(), &"r_revoked_ids", CAT.IDENTITY, 2))
	var r31: FactionBannedRule = FactionBannedRule.new()
	r31.banned_faction_ids = [&"ter"]
	r31.exempt_purposes = []
	r31.exempt_posts = [&"post_recycleur", &"post_soins", &"post_hydroponie"]
	rules.append(_rule(r31, &"r_ter_closed", CAT.FACTION, 2))

	# --- Acte III : R32–R37 (docs/ACT3.md §2.4) ---
	rules.append_array(Act3.build_rules())
	var result: Dictionary[StringName, Rule] = {}
	for rule: Rule in rules:
		result[rule.id] = rule
	Act3.configure_existing_rules(result)
	for rule: Rule in rules:
		_save(rule, RULES_DIR, "rule_%s" % String(rule.id).trim_prefix("r_"))
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
	# M7 : J4–J10 (GDD §8.1 — liste explicite et cumulative).
	var news: Array[Array] = [
		[&"r_tycho_interview", &"r_purpose_consistent", &"r_origin_block"],
		[&"r_bioscan_required", &"r_bioscan_valid", &"r_bioscan_issuer", &"r_bioscan_fit"],
		[&"r_implants_declared", &"r_banned_implants"],
		[&"r_identity_fraud_detain"],
		[&"r_apparent_age", &"r_tharsis_banned"],
		[&"r_seals_valid", &"r_mrz_valid"],
		[&"r_wanted_detain"],
	]
	# Acte II : J11–J20 (docs/ACT2.md §2.1 ; J19 et J20 sans règle nouvelle).
	news.append_array([
		[&"r_air_quota"],
		[&"r_contract_required", &"r_contract_consistent"],
		[&"r_drift_pass"],
		[&"r_nx_firmware"],
		[&"r_asylum_required"],
		[&"r_curfew"],
		[&"r_revoked_ids"],
		[&"r_ter_closed"],
		[],
		[],
	])
	var cumulative: Array[StringName] = d3.duplicate()
	for i: int in news.size():
		var new_ids: Array[StringName] = []
		new_ids.assign(news[i])
		cumulative.append_array(new_ids)
		sets.append(_rule_set(StringName("rs_day%02d" % (i + 4)), rules, cumulative.duplicate(), new_ids))
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
		# M7 (NARRATIVE §4.1, D-052) : Amara Diallo, revue au J4 (SC-06) ; approuver = suspicion +1.
		# Naissance fixée (NARRATIVE §4.1) : SC-06 la reprend au J4 via la mémoire des cas (D-057).
		_scripted(&"sc_02", 1, {&"faction_id": &"ter", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4",
				&"given_name": "Amara", &"family_name": "Diallo", &"birth_date": GameDate.from_ymd(2154, 6, 8)},
				[K.EXPIRED_DOCUMENT], &"sc02_hurried_mother", {&"document_id": &"id_card", &"expired_days": 3},
				{&"sc02_mercy": 0, &"suspicion": 1}, {&"sc02_turned_away": 0}),
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
	# M7 (D-052) : le messager s'appelle Lev Petrenko (retour au J7, SC-13) ;
	# codes 1 (luciole au coin du permis) et 7 (*lumika*).
	var messenger: ScriptedCaseDef = _scripted(&"sc_05", 7, {&"faction_id": &"tyc", &"citizen_class": &"C-3",
			&"sex": Passenger.SEX_M, &"given_name": "Lev", &"family_name": "Petrenko"},
			[K.ID_MISMATCH], &"sc05_luciole_messenger", {&"document_id": &"entry_permit", &"char_count": 1},
			{&"lucioles_trust": 1, &"sc05_helped": 0}, {})
	messenger.sets_flag = &"lucioles_contact"
	messenger.luciole_codes = PackedInt32Array([1, 7])
	d3.scripted_cases = [mira, messenger]

	for day: DayDef in [d1, d2, d3]:
		_save_day(day)


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


# ---------------------------------------------------------------------------
# M7 — Jours 4–10 (GDD §8 ; NARRATIVE §3 briefings, §4 SC-06 → SC-22, §5 soirées)
# ---------------------------------------------------------------------------

const V_CONSORTIUM: int = 0
const V_MENTOR: int = 1
const V_FAMILY: int = 2
const V_LUCIOLES: int = 3
const V_INSPECTION: int = 4
const KEEP := SlippedItem.Decision.KEEP
const RETURN := SlippedItem.Decision.RETURN
const REPORT := SlippedItem.Decision.REPORT


func _build_days_m7(sets: Array[RuleSet]) -> void:
	var f4: Dictionary[StringName, float] = {&"tyc": 0.38, &"hal": 0.20, &"ter": 0.25, &"cer": 0.17}
	var f6: Dictionary[StringName, float] = {&"tyc": 0.33, &"hal": 0.18, &"ter": 0.22, &"cer": 0.15, &"thr": 0.12}
	var f8: Dictionary[StringName, float] = {&"tyc": 0.30, &"hal": 0.17, &"ter": 0.20, &"cer": 0.13, &"thr": 0.12, &"drv": 0.08}
	var days: Array[DayDef] = [
		_day4(sets[3], f4), _day5(sets[4], f4), _day6(sets[5], f6), _day7(sets[6], f6),
		_day8(sets[7], f8), _day9(sets[8], f8), _day10(sets[9], f8),
	]
	for day: DayDef in days:
		_save_day(day)


func _m7_day(n: int, rule_set: RuleSet, duration: float, count: int, count_weights: Array[float],
		weights: Dictionary[AnomalyType.Kind, float], factions: Dictionary[StringName, float], visor: float,
		noise: float, bribe: float, luciole: float, tabs: PackedStringArray) -> DayDef:
	var d: DayDef = _day(n, rule_set, duration, count, count_weights, weights, factions, visor, noise)
	d.bribe_rate = bribe
	d.luciole_rate = luciole
	d.bribe_amounts = Vector2i(10, 20) if n <= 6 else Vector2i(20, 30)
	d.detain_enabled = n >= 7
	# D-076 : le J10 a une soirée (pivot « Nuit des vannes »).
	d.has_evening = n <= 10
	d.rulebook_tabs = tabs
	return d


# --- J4 — vendredi 16.03 : interrogatoire Tycho, motifs, origines ----------

func _day4(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(4, rs, 600.0, 12, [0.45, 0.45, 0.10, 0.0],
			{K.EXPIRED_DOCUMENT: 0.15, K.MISSING_DOCUMENT: 0.10, K.PORTRAIT_MISMATCH: 0.10, K.ID_MISMATCH: 0.12,
			K.NAME_MISMATCH: 0.12, K.ORIGIN_ID_MISMATCH: 0.20, K.PURPOSE_MISMATCH: 0.21},
			factions, 0.15, 0.20, 0.05, 0.04, ["origins"])
	var amara: ScriptedCaseDef = _scripted(&"sc_06", 1, {&"faction_id": &"ter", &"citizen_class": &"C-4",
			&"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 14}, [], &"sc06_amara", {},
			{&"sc06_reunited": 0}, {&"sc06_refused_again": 0})
	amara.requires_flag = &"sc02_turned_away"
	amara.identity_from_case = &"sc_02"
	var valcourt: ScriptedCaseDef = _scripted(&"sc_07", 4, {&"faction_id": &"hal", &"given_name": "Auguste",
			&"family_name": "Valcourt", &"sex": Passenger.SEX_M, &"citizen_class": &"C-1",
			&"birth_date": GameDate.from_ymd(2152, 9, 3), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Valcourt-Hsu Logistique", &"origin_sector": "Anneaux D–F"},
			[K.EXPIRED_DOCUMENT], &"sc07_valcourt", {&"document_id": &"id_card", &"expired_days": 12},
			{&"sc07_passed": 0}, {})
	valcourt.slipped_item = _envelope(20, {
		&"keep": {&"sc07_bribe_kept": 0, &"suspicion": 1},
		&"deny_keep": {&"sc07_bribe_kept": 0, &"sc07_complaint": 0, &"suspicion": 2},
		&"return": {&"sc07_bribe_returned": 0},
	})
	var dmitri: ScriptedCaseDef = _scripted(&"sc_08", 8, {&"faction_id": &"tyc", &"given_name": "Dmitri",
			&"family_name": "Kowalczyk", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2140, 5, 11), &"purpose": Passenger.PURPOSE_WORK,
			&"implants": PackedStringArray(["KIN-5"])},
			[K.PURPOSE_MISMATCH], &"sc08_dmitri", {&"field_path": "employer", &"employer": "SANS EMPLOYEUR"},
			{&"sc08_passed": 0, &"lucioles_trust": 1}, {&"sc08_turned_away": 0})
	dmitri.luciole_codes = PackedInt32Array([5])
	d.scripted_cases = [amara, valcourt, dmitri]
	d.briefing_messages = [
		_msg("spk_consortium", "msg_cons_day04", V_CONSORTIUM, null, &"", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day04", V_MENTOR, null, &"", 0),
		_msg("spk_okonkwo", "msg_okonkwo_day04_reported", V_MENTOR, _all([&"lucioles_reported"]), &"", 3),
		_msg("spk_lucioles", "msg_luc_day04", V_LUCIOLES, _any([_all([&"lucioles_note_burned"]), _all([&"sc05_helped"])]), &"", 1),
		_family("msg_ilan_day04"),
	]
	var birthday: EveningEventDef = _event(&"d04_birthday", EveningEventDef.Kind.CHOICE, 0, null, "evt_d04_birthday")
	birthday.extra_keys = [ConditionalKey.make("evt_d04_money", _all([&"sc07_bribe_kept"]))]
	birthday.options = [
		_evt_option(&"gift", "evt_d04_birthday", 5, 0, {&"noa_birthday_gift": 0}, 1),
		_evt_option(&"none", "evt_d04_birthday", 0, 0, {}, 0),
	]
	d.evening_events = [birthday]
	return d


# --- J5 — samedi 17.03 : bio-scan, la médecin, le chauffage payé ----------

func _day5(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(5, rs, 630.0, 12, [0.40, 0.45, 0.15, 0.0],
			{K.EXPIRED_DOCUMENT: 0.12, K.MISSING_DOCUMENT: 0.10, K.PORTRAIT_MISMATCH: 0.08, K.ID_MISMATCH: 0.10,
			K.NAME_MISMATCH: 0.10, K.ORIGIN_ID_MISMATCH: 0.08, K.PURPOSE_MISMATCH: 0.10, K.WRONG_ISSUER: 0.16,
			K.BIOSCAN_UNFIT: 0.16},
			factions, 0.15, 0.25, 0.05, 0.05, ["origins"])
	var noor: ScriptedCaseDef = _scripted(&"sc_09", 3, {&"faction_id": &"tyc", &"given_name": "Noor",
			&"family_name": "Achebe-Sörensen", &"sex": Passenger.SEX_F, &"citizen_class": &"C-2",
			&"birth_date": GameDate.from_ymd(2147, 8, 21), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Dispensaire de Tycho", &"implants": PackedStringArray(["OPT-3"])},
			[K.MISSING_DOCUMENT], &"sc09_noor", {&"document_id": &"bioscan", &"mrz_issuer": "07"},
			{&"sc09_doctor_passed": 0, &"lucioles_trust": 1}, {&"sc09_doctor_refused": 0})
	noor.luciole_codes = PackedInt32Array([2])
	var yara: ScriptedCaseDef = _scripted(&"sc_10", 7, {&"faction_id": &"tyc", &"given_name": "Yara",
			&"family_name": "Moreno-Lind", &"sex": Passenger.SEX_F, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2158, 12, 2), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 3},
			[], &"sc10_yara", {&"permit_suffix": 7}, {&"sc10_passed": 0, &"lumika_learned": 0}, {})
	yara.luciole_codes = PackedInt32Array([3])
	d.scripted_cases = [noor, yara]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc06_reunited", V_CONSORTIUM, _all([&"sc06_reunited"]), &"echo06", 3),
		_msg("spk_hall", "msg_echo_sc06_refused_again", V_CONSORTIUM, _all([&"sc06_refused_again"]), &"echo06", 3),
		_msg("spk_inspector", "msg_insp_day05_complaint", V_INSPECTION, _all([&"sc07_complaint"]), &"", 2),
		_msg("spk_hall", "msg_echo_sc08_passed", V_CONSORTIUM, _all([&"sc08_passed"]), &"", 3),
		_msg("spk_okonkwo", "msg_okonkwo_day05", V_MENTOR, null, &"", 0),
		_msg("spk_lucioles", "msg_luc_day05", V_LUCIOLES, _any([_gauge(&"lucioles_trust", 1), _all([&"lucioles_note_burned"])]), &"", 1),
		_family("msg_ilan_day05", _all([&"sc07_bribe_kept"])),
	]
	var heat: EveningEventDef = _event(&"d05_heat", EveningEventDef.Kind.CHOICE, 0,
			_any([_all([&"sc10_passed"]), _gauge(&"lucioles_trust", 2)]), "evt_d05_heat")
	var accept: EveningOptionDef = _evt_option(&"accept", "evt_d05_heat", 0, 0, {&"lucioles_heating_accepted": 0, &"lucioles_trust": 1}, 1)
	accept.line_costs = {&"heating": 0}
	heat.options = [accept, _evt_option(&"refuse", "evt_d05_heat", 0, 0, {&"lucioles_heating_refused": 0}, 0)]
	var night: EveningEventDef = _event(&"d05_ilan_night", EveningEventDef.Kind.LETTER, 1, null, "")
	night.text_key = "evt_d05_ilan_night"
	d.evening_events = [heat, night]
	return d


# --- J6 — dimanche 18.03 : implants, le vétéran, l'inspecteur -------------

func _day6(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(6, rs, 630.0, 13, [0.35, 0.45, 0.15, 0.05],
			{K.EXPIRED_DOCUMENT: 0.10, K.MISSING_DOCUMENT: 0.07, K.PORTRAIT_MISMATCH: 0.06, K.ID_MISMATCH: 0.08,
			K.NAME_MISMATCH: 0.08, K.ORIGIN_ID_MISMATCH: 0.07, K.PURPOSE_MISMATCH: 0.08, K.WRONG_ISSUER: 0.08,
			K.BIOSCAN_UNFIT: 0.08, K.UNDECLARED_IMPLANT: 0.20, K.BANNED_IMPLANT: 0.10},
			factions, 0.15, 0.25, 0.05, 0.06, ["origins", "implants"])
	var mazur: ScriptedCaseDef = _scripted(&"sc_11", 2, {&"faction_id": &"thr", &"given_name": "Dariusz",
			&"family_name": "Mazur", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2120, 10, 14), &"purpose": Passenger.PURPOSE_FAMILY_VISIT, &"stay_days": 10,
			&"implants": PackedStringArray(["MIL-9"])},
			[], &"sc11_mazur", {}, {&"sc11_veteran_passed": 0}, {&"sc11_veteran_refused": 0})
	mazur.extra_documents = [&"mil_waiver"]
	var ravel: ScriptedCaseDef = _scripted(&"sc_12", 6, {&"faction_id": &"hal", &"given_name": "Corentin",
			&"family_name": "Ravel", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2146, 1, 9), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité", &"implants": PackedStringArray(["OPT-14"])},
			[K.NAME_MISMATCH], &"sc12_ravel", {&"field_path": "family_name", &"document_id": &"bioscan"},
			{&"inspector_test_failed": 0, &"loyalty": -1}, {})
	ravel.slipped_item = _envelope(30, {
		&"keep": {&"inspector_bribe_taken": 0, &"suspicion": 2},
		&"deny_return": {&"inspector_test_passed": 0, &"loyalty": 1},
	})
	d.scripted_cases = [mazur, ravel]
	d.briefing_messages = [
		_msg("spk_hall", "msg_echo_sc09_doctor_passed", V_CONSORTIUM, _all([&"sc09_doctor_passed"]), &"echo09", 3),
		_msg("spk_hall", "msg_echo_sc09_doctor_refused", V_CONSORTIUM, _all([&"sc09_doctor_refused"]), &"echo09", 3),
		_msg("spk_okonkwo", "msg_okonkwo_day06", V_MENTOR, null, &"", 0),
		_family("msg_ilan_day06", _all([&"lucioles_heating_accepted"])),
		_family("msg_ilan_day06_noa"),
	]
	var bioscan: EveningEventDef = _event(&"d06_bioscan", EveningEventDef.Kind.CHOICE, 0, null, "evt_d06_bioscan")
	bioscan.text_variants = [ConditionalKey.make("evt_d06_bioscan_text_free", _all([&"sc09_doctor_passed"]))]
	var free: EveningOptionDef = _evt_option(&"free", "evt_d06_bioscan", 0, 0, {&"noa_bioscan_free": 0}, 0)
	free.condition = _all([&"sc09_doctor_passed"])
	var skip: EveningOptionDef = _evt_option(&"skip", "evt_d06_bioscan", 0, 0, {&"noa_bioscan_skipped": 0}, 2)
	skip.household = EveningOptionDef.HOUSEHOLD_NOA_SICK
	bioscan.options = [_evt_option(&"pay", "evt_d06_bioscan", 25, 0, {&"noa_bioscan_paid": 0}, 1), free, skip]
	d.evening_events = [bioscan]
	return d


# --- J7 — lundi 19.03 : DÉTENTION, le sosie luciole, l'insuline -----------

func _day7(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(7, rs, 660.0, 14, [0.35, 0.40, 0.20, 0.05],
			{K.EXPIRED_DOCUMENT: 0.08, K.MISSING_DOCUMENT: 0.05, K.PORTRAIT_MISMATCH: 0.04, K.ID_MISMATCH: 0.07,
			K.NAME_MISMATCH: 0.07, K.ORIGIN_ID_MISMATCH: 0.06, K.PURPOSE_MISMATCH: 0.07, K.WRONG_ISSUER: 0.06,
			K.BIOSCAN_UNFIT: 0.06, K.UNDECLARED_IMPLANT: 0.10, K.BANNED_IMPLANT: 0.07, K.IMPOSTOR_LOOKALIKE: 0.27},
			factions, 0.20, 0.30, 0.05, 0.06, ["origins", "implants", "symbols"])
	d.hall_announcements = {5: "hall_j7_okonkwo_citation"}
	var lev: ScriptedCaseDef = _scripted(&"sc_13", 3, {&"faction_id": &"hal", &"given_name": "Soren",
			&"family_name": "Whitmore", &"sex": Passenger.SEX_M, &"citizen_class": &"C-2",
			&"purpose": Passenger.PURPOSE_RETURN, &"employer": "Banque Aurel"},
			[K.IMPOSTOR_LOOKALIKE], &"sc13_lev", {&"trait_count": 2, &"mark_document_id": "bioscan"},
			{&"sc13_passed": 0, &"lucioles_trust": 2}, {&"sc13_turned_back": 0})
	lev.flags_on_detain = {&"sc13_detained": 0, &"loyalty": 1, &"lucioles_trust": -2}
	lev.appearance_from_case = &"sc_05"
	lev.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN}
	lev.truth_overrides = {&"given_name": "Lev", &"family_name": "Petrenko", &"faction_id": &"tyc"}
	lev.luciole_codes = PackedInt32Array([1, 4])
	var kaito: ScriptedCaseDef = _scripted(&"sc_14", 9, {&"faction_id": &"cer", &"given_name": "Kaito",
			&"family_name": "Morrow", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2155, 11, 30), &"purpose": Passenger.PURPOSE_TRADE, &"stay_days": 5,
			&"implants": PackedStringArray()},
			[K.UNDECLARED_IMPLANT], &"sc14_kaito", {&"implant": "DER-19"},
			{&"sc14_passed": 0, &"lucioles_trust": 1}, {})
	kaito.slipped_item = _envelope(25, {&"keep": {&"sc14_bribe_kept": 0, &"suspicion": 1}})
	d.scripted_cases = [lev, kaito]
	d.briefing_messages = [
		_msg("spk_okonkwo", "msg_okonkwo_day07_test_passed", V_MENTOR, _all([&"inspector_test_passed"]), &"test", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day07_test_failed", V_MENTOR,
				_any([_all([&"inspector_bribe_taken"]), _all([&"inspector_test_failed"])]), &"test", 2),
		_msg("spk_okonkwo", "msg_okonkwo_day07", V_MENTOR, null, &"", 0),
		_msg("spk_lucioles", "msg_luc_day07", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 1),
		_family("msg_ilan_day07"),
	]
	var school: EveningEventDef = _event(&"d07_school", EveningEventDef.Kind.CHOICE, 0, null, "evt_d07_school")
	school.options = [
		_evt_option(&"pay", "evt_d07_school", 10, 0, {&"noa_school_fine_paid": 0}, 0),
		_evt_option(&"ignore", "evt_d07_school", 0, 0, {&"noa_school_fine_ignored": 0, &"suspicion": 1}, 1),
	]
	var lumika: EveningEventDef = _event(&"d07_lumika", EveningEventDef.Kind.LETTER, 1, null, "")
	lumika.text_key = "evt_d07_lumika"
	lumika.flags = {&"lumika_learned": 0}
	var tag: EveningEventDef = _event(&"d07_tag", EveningEventDef.Kind.LETTER, 2, _all([&"sc13_detained"]), "evt_d07_tag")
	d.evening_events = [school, lumika, tag]
	return d


# --- J8 — mardi 20.03 : attentat, Tharsiens interdits, familles séparées ---

func _day8(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(8, rs, 660.0, 14, [0.30, 0.40, 0.22, 0.08],
			{K.EXPIRED_DOCUMENT: 0.07, K.MISSING_DOCUMENT: 0.05, K.PORTRAIT_MISMATCH: 0.04, K.ID_MISMATCH: 0.06,
			K.NAME_MISMATCH: 0.06, K.ORIGIN_ID_MISMATCH: 0.05, K.PURPOSE_MISMATCH: 0.06, K.WRONG_ISSUER: 0.05,
			K.BIOSCAN_UNFIT: 0.05, K.UNDECLARED_IMPLANT: 0.08, K.BANNED_IMPLANT: 0.06, K.IMPOSTOR_LOOKALIKE: 0.10,
			K.RELATIVE_DOCUMENTS: 0.14, K.BANNED_FACTION: 0.13},
			factions, 0.20, 0.30, 0.05, 0.07, ["origins", "implants", "symbols"])
	var idris: ScriptedCaseDef = _scripted(&"sc_15", 2, {&"faction_id": &"thr", &"given_name": "Idris",
			&"family_name": "Hadid", &"sex": Passenger.SEX_M, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2134, 7, 7), &"purpose": Passenger.PURPOSE_DIPLOMATIC,
			&"employer": "Délégation tharsienne", &"implants": PackedStringArray()},
			[], &"sc15_idris", {}, {&"sc15_idris_passed": 0}, {})
	var hana: ScriptedCaseDef = _scripted(&"sc_16", 3, {&"faction_id": &"thr", &"given_name": "Hana",
			&"family_name": "Hadid", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2137, 12, 19), &"employer": "Délégation tharsienne",
			&"implants": PackedStringArray()},
			[K.BANNED_FACTION], &"sc16_hana", {&"purpose": "family_visit"},
			{&"sc16_hana_passed": 0, &"lucioles_trust": 1}, {})
	hana.luciole_codes = PackedInt32Array([6])
	for verdict: StringName in [&"deny", &"detain"]:
		var split: CaseEffectDef = CaseEffectDef.new()
		split.verdict = verdict
		split.condition = _all([&"sc15_idris_passed"])
		split.flags = {&"sc16_family_split": 0}
		hana.extra_effects.append(split)
	# NARRATIVE §4.5 : Fatou 29 ans (tranche 18–29), Ngozi 38 ans (tranche 30–54) — R18 lit l'écart de tranche.
	var fatou: ScriptedCaseDef = _scripted(&"sc_17", 7, {&"faction_id": &"ter", &"given_name": "Fatou",
			&"family_name": "Mensah", &"sex": Passenger.SEX_F, &"citizen_class": &"C-4",
			&"birth_date": GameDate.from_ymd(2157, 6, 12), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Hydroponie Ceres-Verte", &"implants": PackedStringArray()},
			[K.RELATIVE_DOCUMENTS], &"sc17_fatou",
			{&"relative_given_name": "Ngozi", &"relative_birth": GameDate.from_ymd(2149, 2, 4)},
			{&"sc17_passed": 0}, {&"sc17_turned_back": 0})
	fatou.flags_on_detain = {&"sc17_detained": 0, &"loyalty": 1}
	d.scripted_cases = [idris, hana, fatou]
	d.briefing_messages = [
		_msg("spk_consortium", "msg_cons_day08_oath", V_CONSORTIUM, null, &"", 2),
		_msg("spk_consortium", "msg_cons_day08_veteran", V_CONSORTIUM, _all([&"sc11_veteran_passed"]), &"veteran", 3),
		_msg("spk_consortium", "msg_cons_day08_veteran_refused", V_CONSORTIUM, _all([&"sc11_veteran_refused"]), &"veteran", 3),
		_msg("spk_okonkwo", "msg_okonkwo_day08_veteran", V_MENTOR, _all([&"sc11_veteran_passed"]), &"okonkwo", 0),
		_msg("spk_okonkwo", "msg_okonkwo_day08", V_MENTOR, null, &"okonkwo", 0),
		_msg("spk_lucioles", "msg_luc_day08", V_LUCIOLES, _cond([], [&"sc13_detained"], {&"lucioles_trust": 1}), &"", 1),
		_family("msg_ilan_day08"),
	]
	var dora: EveningEventDef = _event(&"d08_dora", EveningEventDef.Kind.LETTER, 0, null, "evt_d08_dora")
	dora.flags = {&"dora_told_puits9": 0}
	var neighbor: EveningEventDef = _event(&"d08_neighbor", EveningEventDef.Kind.CHOICE, 1, null, "evt_d08_neighbor")
	neighbor.options = [
		_evt_option(&"denounce", "evt_d08_neighbor", 0, 10, {&"neighbor_denounced": 0, &"loyalty": 1}, 2),
		_evt_option(&"help", "evt_d08_neighbor", 10, 0, {&"neighbor_helped": 0, &"lucioles_trust": 1}, 1),
		_evt_option(&"ignore", "evt_d08_neighbor", 0, 0, {&"neighbor_ignored": 0}, 0),
	]
	var package: EveningEventDef = _event(&"d08_package", EveningEventDef.Kind.CHOICE, 2,
			_cond([], [&"lucioles_hostile"], {&"lucioles_trust": 1}), "evt_d08_package")
	package.options = [
		_evt_option(&"accept", "evt_d08_package", 0, 20, {&"brulants_package": 0, &"suspicion": 1}, 1),
		_evt_option(&"refuse", "evt_d08_package", 0, 0, {}, 0),
	]
	var sabotage: EveningEventDef = _event(&"d08_sabotage", EveningEventDef.Kind.LETTER, 3, _all([&"lucioles_hostile"]), "")
	sabotage.text_key = "evt_d08_sabotage"
	sabotage.line_costs = {&"heating": 12}
	var soute: EveningEventDef = _event(&"d08_soute_meds", EveningEventDef.Kind.LETTER, 4, _all([&"sc14_passed"]), "")
	soute.text_key = "evt_d08_soute_meds"
	soute.line_costs = {&"meds": 8}
	var kwame: EveningEventDef = _event(&"d08_kwame", EveningEventDef.Kind.LETTER, 5, _all([&"sc17_detained"]), "")
	kwame.text_key = "evt_d08_kwame"
	var retry: EveningEventDef = _event(&"d08_bioscan", EveningEventDef.Kind.CHOICE, 6,
			_cond([&"noa_bioscan_skipped"], [&"noa_bioscan_paid_late"]), "evt_d06_bioscan")
	retry.title_key = "evt_d08_bioscan_title"
	var retry_skip: EveningOptionDef = _evt_option(&"skip", "evt_d06_bioscan", 0, 0, {}, 1)
	retry_skip.household = EveningOptionDef.HOUSEHOLD_NOA_SICK
	retry.options = [_evt_option(&"pay", "evt_d06_bioscan", 25, 0, {&"noa_bioscan_paid_late": 0}, 0), retry_skip]
	d.evening_events = [dora, neighbor, package, sabotage, soute, kwame, retry]
	return d


# --- J9 — mercredi 21.03 : sceaux, MRZ, audit, aveu d'Ilan ----------------

func _day9(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(9, rs, 690.0, 15, [0.30, 0.40, 0.22, 0.08],
			{K.EXPIRED_DOCUMENT: 0.06, K.MISSING_DOCUMENT: 0.04, K.PORTRAIT_MISMATCH: 0.03, K.ID_MISMATCH: 0.05,
			K.NAME_MISMATCH: 0.05, K.ORIGIN_ID_MISMATCH: 0.05, K.PURPOSE_MISMATCH: 0.05, K.WRONG_ISSUER: 0.05,
			K.BIOSCAN_UNFIT: 0.05, K.UNDECLARED_IMPLANT: 0.07, K.BANNED_IMPLANT: 0.05, K.IMPOSTOR_LOOKALIKE: 0.08,
			K.RELATIVE_DOCUMENTS: 0.08, K.BANNED_FACTION: 0.08, K.INVALID_SEAL: 0.13, K.MRZ_MISMATCH: 0.08},
			factions, 0.20, 0.35, 0.05, 0.07, ["origins", "implants", "symbols", "seals"])
	var sefa: ScriptedCaseDef = _scripted(&"sc_18", 4, {&"faction_id": &"drv", &"given_name": "Sefa",
			&"family_name": "Long-Ruban", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.year_only(2163), &"purpose": Passenger.PURPOSE_TRANSIT, # « 00.00.2163 » (§4.10)
			&"implants": PackedStringArray()},
			[], &"sc18_sefa", {&"mrz_issuer": "07"}, {&"sc18_passed": 0}, {})
	sefa.luciole_codes = PackedInt32Array([2])
	var note: SlippedItemDef = SlippedItemDef.new()
	note.kind = SlippedItem.Kind.NOTE
	note.label_key = "wb_note_label"
	note.text_key = "sc18_sefa_note"
	note.extra_text_keys = [ConditionalKey.make("sc18_sefa_note_lev", _all([&"sc13_turned_back"]))]
	note.allowed = [KEEP, REPORT, RETURN]
	note.default_decision = RETURN
	note.report_bonus = 10
	note.effects = {
		&"keep": {&"sc18_note_kept": 0, &"lucioles_trust": 1},
		&"report": {&"sc18_note_reported": 0, &"ilan_exposed": 0, &"loyalty": 1, &"lucioles_trust": -2},
	}
	sefa.slipped_item = note
	var wren: ScriptedCaseDef = _scripted(&"sc_19", 9, {&"faction_id": &"drv", &"given_name": "Wren",
			&"family_name": "Basse-Marée", &"sex": Passenger.SEX_F, &"citizen_class": &"C-5",
			&"birth_date": GameDate.from_ymd(2142, 8, 30), &"purpose": Passenger.PURPOSE_TRADE,
			&"implants": PackedStringArray()},
			[K.INVALID_SEAL], &"sc19_wren", {&"document_id": &"entry_permit"},
			{&"drift_offer": 0, &"sc19_passed": 0}, {&"drift_offer": 0})
	var card: SlippedItemDef = SlippedItemDef.new()
	card.kind = SlippedItem.Kind.DOCK_CARD
	card.label_key = "wb_dock_card_label"
	card.text_key = "sc19_wren_note"
	card.allowed = [KEEP]
	card.default_decision = KEEP
	wren.slipped_item = card
	d.scripted_cases = [sefa, wren]
	d.briefing_messages = [
		_msg("spk_inspector", "msg_insp_day09", V_INSPECTION, null, &"", 0),
		_msg("spk_hall", "msg_echo_sc16_family_split", V_CONSORTIUM, _all([&"sc16_family_split"]), &"", 3),
		_msg("spk_hall", "msg_echo_sc17_detained", V_CONSORTIUM, _all([&"sc17_detained"]), &"", 3),
		_msg("spk_hall", "msg_echo_neighbor_denounced", V_CONSORTIUM, _all([&"neighbor_denounced"]), &"", 3),
		_msg("spk_okonkwo", "msg_okonkwo_day09", V_MENTOR, null, &"", 0),
		_family("msg_ilan_day09"),
	]
	var audit: EveningEventDef = _event(&"d09_audit", EveningEventDef.Kind.AUDIT, 0, null, "")
	audit.title_key = "evt_d09_audit_title"
	var ilan: EveningEventDef = _event(&"d09_ilan", EveningEventDef.Kind.CHOICE, 1, null, "evt_d09_ilan")
	ilan.flags = {&"ilan_confessed": 0}
	ilan.text_variants = [
		ConditionalKey.make("evt_d09_ilan_text_exposed", _all([&"ilan_exposed"])),
		ConditionalKey.make("evt_d09_ilan_text_note", _all([&"sc18_note_kept"])),
	]
	var denounce: EveningOptionDef = _evt_option(&"denounce", "evt_d09_ilan", 0, 20,
			{&"ilan_denounced": 0, &"loyalty": 3, &"lucioles_trust": -3}, -1)
	denounce.household = EveningOptionDef.HOUSEHOLD_ILAN_DETAINED
	ilan.options = [
		_evt_option(&"support", "evt_d09_ilan", 0, 0, {&"ilan_supported": 0, &"lucioles_trust": 1}, 1),
		_evt_option(&"forbid", "evt_d09_ilan", 0, 0, {&"ilan_forbidden": 0, &"lucioles_trust": -1}, 0),
		denounce,
	]
	var okonkwo: EveningEventDef = _event(&"d09_okonkwo", EveningEventDef.Kind.CHOICE, 2, null, "evt_d09_okonkwo")
	okonkwo.options = [
		_evt_option(&"sign", "evt_d09_okonkwo", 0, 15, {&"okonkwo_denounced": 0, &"loyalty": 2}, 2),
		_evt_option(&"refuse", "evt_d09_okonkwo", 0, 0, {&"okonkwo_shielded": 0, &"suspicion": 1}, 0),
		_evt_option(&"warn", "evt_d09_okonkwo", 0, 0,
				{&"okonkwo_warned": 0, &"suspicion": 1, &"loyalty": -1, &"lucioles_trust": 1}, 1),
	]
	var drift: EveningEventDef = _event(&"d09_drift", EveningEventDef.Kind.CHOICE, 3, _all([&"drift_offer"]), "evt_d09_drift")
	drift.options = [
		_evt_option(&"buy", "evt_d09_drift", 40, 0, {&"drift_passes_bought": 0}, 1),
		_evt_option(&"keep", "evt_d09_drift", 0, 0, {}, 0),
	]
	d.evening_events = [audit, ilan, okonkwo, drift]
	return d


# --- J10 — jeudi 22.03 : avis de recherche, Mira ; pas de soirée ----------

func _day10(rs: RuleSet, factions: Dictionary[StringName, float]) -> DayDef:
	var d: DayDef = _m7_day(10, rs, 720.0, 16, [0.25, 0.40, 0.25, 0.10],
			{K.EXPIRED_DOCUMENT: 0.05, K.MISSING_DOCUMENT: 0.04, K.PORTRAIT_MISMATCH: 0.03, K.ID_MISMATCH: 0.05,
			K.NAME_MISMATCH: 0.05, K.ORIGIN_ID_MISMATCH: 0.04, K.PURPOSE_MISMATCH: 0.05, K.WRONG_ISSUER: 0.04,
			K.BIOSCAN_UNFIT: 0.04, K.UNDECLARED_IMPLANT: 0.06, K.BANNED_IMPLANT: 0.05, K.IMPOSTOR_LOOKALIKE: 0.08,
			K.RELATIVE_DOCUMENTS: 0.07, K.BANNED_FACTION: 0.07, K.INVALID_SEAL: 0.07, K.MRZ_MISMATCH: 0.06},
			factions, 0.20, 0.35, 0.05, 0.08, ["origins", "implants", "symbols", "seals", "wanted"])
	var arkady: ScriptedCaseDef = _scripted(&"sc_20", 3, {&"faction_id": &"tyc", &"given_name": "Bastien",
			&"family_name": "Duval", &"sex": Passenger.SEX_M, &"citizen_class": &"C-3",
			&"birth_date": GameDate.from_ymd(2148, 4, 17), &"purpose": Passenger.PURPOSE_WORK,
			&"employer": "Kessler-Ashe Orbital", &"implants": PackedStringArray()},
			[K.WANTED_PERSON], &"sc20_arkady", {}, {&"sc20_passed": 0}, {&"sc20_turned_back": 0})
	arkady.flags_on_detain = {&"sc20_detained": 0, &"loyalty": 1}
	arkady.truth_overrides = {&"given_name": "Arkady", &"family_name": "Novak"}
	arkady.extra_tags = [CaseBuilder.TAG_LUCIOLE_PASSWORD]
	var philippa: ScriptedCaseDef = _scripted(&"sc_21", 6, {&"faction_id": &"hal", &"given_name": "Philippa",
			&"family_name": "Montclair", &"sex": Passenger.SEX_F, &"citizen_class": &"C-1",
			&"birth_date": GameDate.from_ymd(2129, 1, 22), &"purpose": Passenger.PURPOSE_RETURN,
			&"employer": "Bureau de Continuité", &"implants": PackedStringArray()},
			[K.MRZ_MISMATCH], &"sc21_philippa", {&"component": "given_name", &"mrz_value": "PHILIPA"},
			{&"sc21_passed": 0}, {})
	philippa.slipped_item = _envelope(50, {&"keep": {&"sc21_bribe_kept": 0, &"suspicion": 1}})
	var mira: ScriptedCaseDef = _scripted(&"sc_22", 10, {
		&"given_name": "Mira", &"family_name": "Vasquez-Orlov", &"sex": Passenger.SEX_F,
		&"birth_date": GameDate.from_ymd(2151, 11, 2), &"faction_id": &"tyc",
		&"citizen_id": "HG-4471-K2Q9", &"citizen_class": &"C-3",
		&"purpose": Passenger.PURPOSE_WORK, &"employer": "Kessler-Ashe Orbital", &"implants": PackedStringArray(),
	}, [K.WANTED_PERSON], &"sc22_mira", {}, {&"final_passed": 0, &"lucioles_trust": 1}, {&"final_denied": 0})
	mira.flags_on_detain = {&"final_detained": 0, &"loyalty": 1, &"lucioles_trust": -2}
	mira.flags_if_unprocessed = {&"final_unprocessed": 0}
	mira.appearance_from_case = &"sc_04"
	mira.appearance_overrides = {PassengerAppearance.SLOT_HEADWEAR: PassengerAppearance.VISOR_DOWN}
	mira.luciole_codes = PackedInt32Array([4, 6, 7])
	d.scripted_cases = [arkady, philippa, mira]
	d.wanted_notices = [
		_wanted(&"wanted_novak", &"sc_20", -1, "Arkady", "Novak", "wanted_novak_reason"),
		_wanted(&"wanted_vasquez", &"sc_22", -1, "", "", "wanted_vasquez_reason"),
		_wanted(&"wanted_generated", &"", 13, "", "", "wanted_generated_reason"),
	]
	d.briefing_messages = [
		_msg("spk_inspector", "msg_insp_day10_clean", V_INSPECTION, _all([&"audit_clean"]), &"audit", 1),
		_msg("spk_inspector", "msg_insp_day10_retention", V_INSPECTION, _all([&"audit_retention"]), &"audit", 1),
		_msg("spk_hall", "msg_hall_day10_okonkwo_denounced", V_CONSORTIUM, _all([&"okonkwo_denounced"]), &"okonkwo", 0),
		_msg("spk_okonkwo", "msg_okonkwo_day10_shielded", V_MENTOR, _all([&"okonkwo_shielded"]), &"okonkwo", 0),
		_msg("spk_hall", "msg_hall_day10_okonkwo_warned", V_CONSORTIUM, _all([&"okonkwo_warned"]), &"okonkwo", 0),
		_msg("spk_lucioles", "msg_luc_day10", V_LUCIOLES, _gauge(&"lucioles_trust", 2), &"", 1),
		_family("msg_ilan_day10_supported", _all([&"ilan_supported"])),
		_family("msg_ilan_day10"),
	]
	# Acte II (D-076) : soirée pivot « La Nuit des vannes » (docs/ACT2.md §1.2, §5.3).
	d.evening_events = Act2.pivot_events()
	return d


# --- Fabriques M7 -----------------------------------------------------------

func _all(flags: Array[StringName]) -> FlagCondition:
	return FlagCondition.make(flags)


func _gauge(gauge: StringName, minimum: int) -> FlagCondition:
	return FlagCondition.make([], [], {gauge: minimum})


func _cond(all_of: Array[StringName], none_of: Array[StringName], minimum: Dictionary[StringName, int] = {}) -> FlagCondition:
	return FlagCondition.make(all_of, none_of, minimum)


func _any(conditions: Array[FlagCondition]) -> FlagCondition:
	return FlagCondition.any(conditions)


func _msg(speaker: String, text: String, voice: int, condition: FlagCondition, group: StringName, priority: int) -> BriefingMessageDef:
	var m: BriefingMessageDef = BriefingMessageDef.new()
	m.speaker_key = speaker
	m.text_key = text
	m.voice = voice
	m.condition = condition
	m.group = group
	m.priority = priority
	return m


## Message narratif d'Ilan (emplacement « foyer », groupe `ilan`).
func _family(text: String, condition: FlagCondition = null) -> BriefingMessageDef:
	var m: BriefingMessageDef = _msg("spk_ilan", text, V_FAMILY, condition, &"ilan", 0)
	m.family_slot = true
	return m


## Événement : `stem` → `<stem>_title`, `<stem>_text` (vide = renseignés après).
func _event(id: StringName, kind: EveningEventDef.Kind, order: int, condition: FlagCondition, stem: String) -> EveningEventDef:
	var e: EveningEventDef = EveningEventDef.new()
	e.id = id
	e.kind = kind
	e.order = order
	e.condition = condition
	if not stem.is_empty():
		e.title_key = stem + "_title"
		e.text_key = stem + "_text"
	return e


## Option : `<stem>_opt_<id>` / `<stem>_res_<id>`.
func _evt_option(id: StringName, stem: String, cost: int, gain: int, flags: Dictionary[StringName, int], rank: int) -> EveningOptionDef:
	var o: EveningOptionDef = EveningOptionDef.new()
	o.id = id
	o.label_key = "%s_opt_%s" % [stem, id]
	o.result_key = "%s_res_%s" % [stem, id]
	o.cost = cost
	o.gain = gain
	o.flags = flags
	o.default_rank = rank
	return o


func _envelope(amount: int, effects: Dictionary[StringName, Dictionary]) -> SlippedItemDef:
	var e: SlippedItemDef = SlippedItemDef.new()
	e.kind = SlippedItem.Kind.ENVELOPE
	e.amount = amount
	e.label_key = "wb_envelope_label"
	e.allowed = [KEEP, RETURN]
	e.default_decision = RETURN
	e.effects = effects
	return e


func _wanted(id: StringName, scripted_id: StringName, index: int, given: String, family: String, reason: String) -> WantedNoticeDef:
	var w: WantedNoticeDef = WantedNoticeDef.new()
	w.id = id
	w.scripted_case_id = scripted_id
	w.at_index = index
	w.given_name = given
	w.family_name = family
	w.reason_key = reason
	return w


## QA-002 : noms jamais générés, calculés depuis les données. Par réserve :
## `reserved_names` = noms de famille distinctifs et prénoms du foyer présents
## dans la réserve ; `reserved_full_names` = « Prénom Nom » de chaque personnage
## scénarisé (identité présentée, vraie identité, parent de SC-17) et de chaque
## avis de recherche dont le nom de famille est tirable. Tri : déterministe.
func _reserve_character_names(pools: Dictionary[StringName, NamePool]) -> void:
	var full_names: Dictionary[String, bool] = {}
	# QA-022 : le nom de famille de **chaque** personnage scénarisé des deux
	# actes (identité présentée et vraie identité) et de chaque avis de
	# recherche nommé est réservé, pas seulement son nom complet.
	var character_families: Dictionary[String, bool] = {}
	for name: String in RESERVED_FAMILY_NAMES:
		character_families[name] = true
	for day: DayDef in _days:
		for scripted: ScriptedCaseDef in day.scripted_cases:
			for family_value: Variant in [scripted.passenger_overrides.get(&"family_name", ""),
					scripted.truth_overrides.get(&"family_name", "")]:
				if not str(family_value).is_empty():
					character_families[str(family_value)] = true
		for notice: WantedNoticeDef in day.wanted_notices:
			if not notice.family_name.is_empty():
				character_families[notice.family_name] = true
	var reserved_families: Array[String] = []
	reserved_families.assign(character_families.keys())
	reserved_families.sort()
	for day: DayDef in _days:
		for scripted: ScriptedCaseDef in day.scripted_cases:
			var family: String = str(scripted.passenger_overrides.get(&"family_name", ""))
			_add_full_name(full_names, scripted.passenger_overrides.get(&"given_name", ""), family)
			_add_full_name(full_names, scripted.truth_overrides.get(&"given_name", ""),
					scripted.truth_overrides.get(&"family_name", family))
			_add_full_name(full_names, scripted.injection_params.get(&"relative_given_name", ""), family)
		for notice: WantedNoticeDef in day.wanted_notices:
			_add_full_name(full_names, notice.given_name, notice.family_name)
	var sorted_full: Array[String] = []
	sorted_full.assign(full_names.keys())
	sorted_full.sort()
	for id: StringName in pools:
		var pool: NamePool = pools[id]
		var reserved: PackedStringArray = []
		for name: String in reserved_families:
			if pool.family_names.has(name):
				reserved.append(name)
		for name: String in RESERVED_HOUSEHOLD_NAMES:
			if pool.all_given_names().has(name):
				reserved.append(name)
		pool.reserved_names = reserved
		var reserved_full: PackedStringArray = []
		for full: String in sorted_full:
			var family: String = full.substr(full.find(" ") + 1)
			if pool.family_names.has(family) and not reserved.has(family):
				reserved_full.append(full)
		pool.reserved_full_names = reserved_full
		_save(pool, NAMES_DIR, "namepool_%s" % pool.id)


func _add_full_name(names: Dictionary[String, bool], given: Variant, family: Variant) -> void:
	var g: String = str(given)
	var f: String = str(family)
	if not g.is_empty() and not f.is_empty():
		names["%s %s" % [g, f]] = true


## Sauvegarde d'un jour : identifiants stables pour toutes ses sous-ressources.
func _save_day(day: DayDef) -> void:
	_days.append(day)
	for scripted: ScriptedCaseDef in day.scripted_cases:
		scripted.resource_scene_unique_id = "scripted_%s" % scripted.id
	var counter: Array[int] = [0]
	_tag_subresources(day, "d%02d" % day.day_number, counter)
	_save(day, DAYS_DIR, "day_%02d" % day.day_number)


## Parcours en profondeur (ordre des propriétés : déterministe) des
## sous-ressources embarquées ; pose `resource_scene_unique_id` s'il est vide.
func _tag_subresources(res: Resource, prefix: String, counter: Array[int]) -> void:
	for prop: Dictionary in res.get_property_list():
		var usage: int = prop["usage"]
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		var prop_name: String = prop["name"]
		var value: Variant = res.get(StringName(prop_name))
		if value is Resource:
			var sub: Resource = value
			_tag_one(sub, prefix, counter)
		elif value is Array:
			var list: Array = value
			for item: Variant in list:
				if item is Resource:
					var sub_item: Resource = item
					_tag_one(sub_item, prefix, counter)


func _tag_one(sub: Resource, prefix: String, counter: Array[int]) -> void:
	if not sub.resource_path.is_empty() and not sub.resource_path.contains("::"):
		return
	if sub.resource_scene_unique_id.is_empty():
		counter[0] += 1
		sub.resource_scene_unique_id = "%s_%s_%d" % [prefix, sub.get_class().to_lower(), counter[0]]
	_tag_subresources(sub, prefix, counter)
