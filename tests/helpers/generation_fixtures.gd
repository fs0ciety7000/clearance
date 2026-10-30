## Fixtures des tests du générateur (M3) : catalogue de données réel, jour
## « toutes règles » pour exercer chaque injecteur, collecte de cas sur N
## graines. Usage : `const Gen := preload("res://tests/helpers/generation_fixtures.gd")`.
extends RefCounted

## Graine de campagne de référence des tests.
const BASE_SEED: int = 20_871_315
const MVP_FACTIONS: Dictionary[StringName, float] = {&"tyc": 0.45, &"hal": 0.25, &"ter": 0.30}
## M7 : les six origines (le jour « toutes règles » exerce aussi R19, THR).
const ALL_FACTIONS: Dictionary[StringName, float] = {&"tyc": 0.30, &"hal": 0.17, &"ter": 0.20, &"cer": 0.13,
		&"thr": 0.12, &"drv": 0.08}

## Acte III : règles de **contexte du shift** liées à la Main courante (R34,
## R37 : le verdict dépend des admissions précédentes, D-077). Hors du jour
## « toutes règles » (un cas isolé n'a pas de Main courante) ; testées par
## `tests/unit/test_act3_rules.gd`.
const LEDGER_RULES: Array[StringName] = [&"r_sponsor", &"r_tycho_closed"]
## M12 : règles propres à un monde de l'épilogue J31 (R38 → R42, docs/M12.md
## §1.5–§1.8), contraires aux règles de campagne qu'elles remplacent (R38 ↔ R35,
## R39 ↔ R04, R41 ↔ R13, R42 ↔ R35) : hors du jour « toutes règles », testées
## dans leurs jours (`tests/unit/test_m12_rules.gd`, `test_m12_data.gd`).
const EPILOGUE_RULE_PREFIX: String = "r_ep_"

static var _data: DataCatalog = null


static func data() -> DataCatalog:
	if _data == null:
		_data = DataCatalog.load_from()
	return _data


## Jour fictif J5 (17.03.2187) avec **toutes** les règles du catalogue et des
## poids sur tous les types injectables (M7 : six origines). `count_weights` : proba de 0..3 anomalies.
static func full_day(count_weights: Array[float] = [0.0, 1.0, 0.0, 0.0], passenger_count: int = 12) -> DayDef:
	var rs: RuleSet = RuleSet.new()
	rs.id = &"rs_test_all"
	var ids: Array[StringName] = []
	ids.assign(data().rules.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	for rule_id: StringName in ids:
		if not LEDGER_RULES.has(rule_id) and not String(rule_id).begins_with(EPILOGUE_RULE_PREFIX):
			rs.rules.append(data().rules[rule_id])
	rs.required_document_ids = rs.compute_required_document_ids()
	var day: DayDef = DayDef.new()
	day.day_number = 5
	day.game_date = GameDate.from_ymd(2187, 3, 17)
	day.rule_set = rs
	day.passenger_count = passenger_count
	day.anomaly_count_weights = PackedFloat32Array(count_weights)
	for kind: AnomalyType.Kind in InjectorRegistry.supported_kinds():
		day.anomaly_weights[kind] = 1.0
	day.faction_weights = ALL_FACTIONS.duplicate()
	day.visor_down_rate = 0.15
	day.legit_noise_rate = 0.25
	return day


## M7 : index d'un passager du roster sur lequel `kind` est injectable
## (permis requis : pas un Né-Halcyon ; origine interdite : THR), en partant de
## `start` ; −1 si aucun.
static func index_for(builder: CaseBuilder, kind: AnomalyType.Kind, start: int) -> int:
	var count: int = builder.day.passenger_count
	for offset: int in count:
		var i: int = (start + offset) % count
		var faction: StringName = builder.roster.get_entry(i).faction_id
		match kind:
			AnomalyType.Kind.PURPOSE_MISMATCH, AnomalyType.Kind.FORGED_SUMMONS, AnomalyType.Kind.STATEMENT_MISMATCH:
				if faction != &"hal":
					return i
			# Acte III (R35) : ressortissant de Tycho sous contrat de travail.
			AnomalyType.Kind.SUSPENDED_CONTRACT:
				if faction == &"tyc":
					var worker: GeneratedCase = builder.build_clean(i)
					if worker != null and worker.case.has_own_document(&"work_contract"):
						return i
			AnomalyType.Kind.BANNED_FACTION:
				if faction == &"thr":
					return i
			# Acte II : contrat de travail et permis (motif TRAVAIL) ; Dérivant.
			AnomalyType.Kind.CONTRACT_MISMATCH:
				var clean: GeneratedCase = builder.build_clean(i)
				if clean != null and clean.case.has_own_document(&"work_contract") and clean.case.has_own_document(&"entry_permit"):
					return i
			AnomalyType.Kind.UNREGISTERED_VESSEL:
				if faction == &"drv":
					return i
			_:
				return i
	return -1


static func day_seed(group: int, day_number: int) -> int:
	return SeededRng.day_seed(SeededRng.mix(BASE_SEED, group), day_number)


## Construit des jours J1–J3 complets (rotation) jusqu'à `count` cas.
## Chaque élément : `[builder, generated]`.
static func collect_mvp_cases(count: int) -> Array[Array]:
	var result: Array[Array] = []
	var group: int = 0
	while result.size() < count:
		var day: DayDef = data().get_day(1 + group % 3)
		var builder: CaseBuilder = CaseBuilder.new(data(), day, day_seed(group, day.day_number))
		for generated: GeneratedCase in builder.build_day():
			if result.size() < count:
				result.append([builder, generated])
		group += 1
	return result


## Valeur affichée d'un champ (par `truth_path`) d'un document, ou null.
static func doc_value(c: Case, document_id: StringName, truth_path: StringName) -> Variant:
	var doc: DocumentInstance = c.get_document(document_id)
	if doc == null:
		return null
	var field: FieldDef = doc.type_def.find_field_by_truth_path(truth_path)
	return doc.get_value(field.id) if field != null else null


## Photo du premier champ PORTRAIT, ou null.
static func photo(c: Case) -> PassengerAppearance:
	var refs: Array[FieldRef] = c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)
	if refs.is_empty():
		return null
	var portrait: PortraitValue = c.get_value(refs[0])
	return portrait.appearance


static func portrait_ref(c: Case) -> FieldRef:
	var refs: Array[FieldRef] = c.find_refs_by_kind(FieldDef.FieldKind.PORTRAIT)
	return refs[0] if not refs.is_empty() else null


## Les 5 premiers messages d'une liste d'échecs (lisibilité des rapports).
static func head(failures: PackedStringArray) -> String:
	return "%d échec(s) : %s" % [failures.size(), " | ".join(failures.slice(0, 5))]
