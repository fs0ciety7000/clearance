## Fabrique de cas de test (M2) : cas construits à la main, sans générateur.
##
## Utilise les vraies définitions de `res://data/` (documents, règles, jours)
## pour que les tests couvrent aussi le contenu des `.tres`. Les cas produits
## sont **valides** pour tous les RuleSets J1–J3 ; chaque test applique ensuite
## sa corruption. Usage : `const CaseFactory := preload("res://tests/helpers/case_factory.gd")`.
extends RefCounted

const ID_CARD: StringName = &"id_card"
const PERMIT: StringName = &"entry_permit"
const BIOSCAN: StringName = &"bioscan"

static var _catalog: DataCatalog = null


static func catalog() -> DataCatalog:
	if _catalog == null:
		_catalog = DataCatalog.load_from()
	return _catalog


## J3 = jeudi 15.03.2187.
static func today() -> int:
	return GameDate.from_ymd(2187, 3, 15)


static func doc_def(document_id: StringName) -> DocumentTypeDef:
	return catalog().documents[document_id]


static func rule(rule_id: StringName) -> Rule:
	return catalog().rules[rule_id]


static func appearance() -> PassengerAppearance:
	var traits: Dictionary[StringName, StringName] = {
		&"silhouette": &"silhouette_02", &"face": &"face_04", &"eyes": &"eyes_07",
		&"nose_mouth": &"nose_mouth_01", &"skin": &"skin_05", &"hair": &"hair_03",
		&"headwear": &"none", &"outfit": &"outfit_miner", &"accessory": &"none",
	}
	return PassengerAppearance.new(traits, 3)


## Passagère valide (Mira Vasquez-Orlov, canon LORE) pour l'origine donnée.
static func passenger(faction_id: StringName = &"tyc") -> Passenger:
	var p: Passenger = Passenger.new()
	p.id = &"p_test"
	p.given_name = "Mira"
	p.family_name = "Vasquez-Orlov"
	p.birth_date = GameDate.from_ymd(2151, 11, 2)
	p.sex = Passenger.SEX_F
	p.faction_id = faction_id
	p.origin_sector = "Colonie Tycho"
	var prefixes: Dictionary[StringName, String] = {&"tyc": "HG-4", &"hal": "HG-1", &"ter": "HG-2"}
	p.citizen_id = prefixes.get(faction_id, "HG-4") + "471-K2Q9"
	p.citizen_class = &"C-3"
	p.purpose = Passenger.PURPOSE_WORK
	p.stay_days = 30
	p.employer = "Kessler-Ashe Orbital"
	p.health_status = Passenger.HEALTH_FIT
	p.appearance = appearance()
	return p


## Document valide rempli depuis les `truth_path` (préfigure la DocumentFactory M3).
static func document(document_id: StringName, p: Passenger, on_day: int = today()) -> DocumentInstance:
	var def: DocumentTypeDef = doc_def(document_id)
	var doc: DocumentInstance = DocumentInstance.new(def)
	for field: FieldDef in def.fields:
		if field.is_document_level():
			continue
		var value: Variant = p.get_truth(field.truth_path)
		if field.kind == FieldDef.FieldKind.PORTRAIT:
			value = PortraitValue.new(p.appearance.copy(), 7, 2)
		doc.values[field.id] = value
	match document_id:
		ID_CARD:
			doc.serial = p.citizen_id
			doc.issue_date = on_day - 400
			doc.expiry_date = on_day + 2000
		PERMIT:
			doc.serial = "PE-2187-30417"
			doc.issue_date = on_day - 5
			doc.expiry_date = on_day + 40
		BIOSCAN:
			doc.serial = "BS-88213"
			doc.issue_date = on_day - 3
			doc.expiry_date = doc.issue_date + 30
	return doc


## Cas valide avec les documents demandés.
static func valid_case(document_ids: Array[StringName] = [ID_CARD, PERMIT, BIOSCAN],
		faction_id: StringName = &"tyc", on_day: int = today()) -> Case:
	var c: Case = Case.new()
	c.case_id = &"case_test"
	c.passenger_presented = passenger(faction_id)
	for document_id: StringName in document_ids:
		c.documents.append(document(document_id, c.passenger_presented, on_day))
	return c


## Retire un document du cas.
static func remove_document(c: Case, document_id: StringName) -> void:
	var kept: Array[DocumentInstance] = []
	for doc: DocumentInstance in c.documents:
		if doc.get_document_id() != document_id:
			kept.append(doc)
	c.documents = kept


## Contexte avec toutes les origines/documents, la date et le RuleSet donnés.
static func context(rule_set: RuleSet = null, on_day: int = today()) -> RuleContext:
	var ctx: RuleContext = RuleContext.new(on_day, rule_set)
	ctx.faction_db = catalog().factions
	ctx.document_db = catalog().documents
	return ctx


## RuleSet ad hoc contenant les règles données (par id du catalogue).
static func rule_set_of(rule_ids: Array[StringName]) -> RuleSet:
	var rs: RuleSet = RuleSet.new()
	rs.id = &"rs_test"
	for rule_id: StringName in rule_ids:
		rs.rules.append(rule(rule_id))
	return rs


## Identifiants des règles violées.
static func violated_ids(violations: Array[Violation]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for v: Violation in violations:
		ids.append(v.rule_id)
	return ids
