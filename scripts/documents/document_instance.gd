## Un document tendu par le passager (ARCHITECTURE §5.3).
##
## Les données propres au document (numéro, dates, émetteur, sceau) sont des
## propriétés ; les données recopiées du passager sont dans `values`
## (clé = `FieldDef.id`). `get_value()` résout les deux de façon uniforme :
## c'est la seule source de vérité de ce qui est **affiché**.
## Un champ `PORTRAIT` contient un `PortraitValue`.
class_name DocumentInstance
extends RefCounted

## Propriétés adressables par un `truth_path` `document.<nom>`.
const DOCUMENT_PROPERTIES: Array[StringName] = [
	&"serial", &"issue_date", &"expiry_date", &"issuer_id", &"seal_id", &"mrz", &"presented_at",
]

var type_def: DocumentTypeDef = null
var serial: String = ""
## Jours de jeu (`GameDate`).
var issue_date: int = 0
var expiry_date: int = 0
var issuer_id: StringName = &""
var seal_id: StringName = &""
## Bande MRZ (M7, `Mrz`) : recopie du N° ID, de l'origine et du nom ; les deux
## derniers caractères = guichet émetteur (`04`, ou `07` : code Luciole n° 2).
var mrz: String = ""
## Marques visibles au zoom (M7) : `&"luciole"` = code Luciole n° 1 (LORE §7).
var marks: Array[StringName] = []
var values: Dictionary[StringName, Variant] = {}
## Acte II — heure de présentation (minutes depuis minuit) du ticket de file
## (R29, couvre-feu) ; −1 hors ticket.
var presented_at: int = -1
## Acte II — document **d'un tiers** (SC-27 : le contrat du chat) : ni comparé
## par R07, ni lu par les règles du porteur (`Case.get_own_document`).
var third_party: bool = false
## Acte III (M1 « Retour aux quais », SC-58) — document **retiré** présenté
## quand même (bio-scan après le J23) : affiché, jamais lu par les règles ni
## comparé (comme un document d'un tiers).
var retired: bool = false


func _init(p_type_def: DocumentTypeDef = null) -> void:
	type_def = p_type_def
	if type_def != null:
		issuer_id = type_def.issuer_id
		seal_id = type_def.seal_id


static func has_document_property(property: StringName) -> bool:
	return DOCUMENT_PROPERTIES.has(property)


## Identifiant du type (`&"id_card"`) ; sert de `FieldRef.document_id`.
func get_document_id() -> StringName:
	return type_def.id if type_def != null else &""


func get_field(field_id: StringName) -> FieldDef:
	return type_def.get_field(field_id) if type_def != null else null


func has_field(field_id: StringName) -> bool:
	return get_field(field_id) != null


## Acte III : document hors des règles du porteur (tiers ou retiré).
func is_foreign() -> bool:
	return third_party or retired


## Valeur affichée d'un champ (null + erreur si le champ n'existe pas).
func get_value(field_id: StringName) -> Variant:
	var field: FieldDef = get_field(field_id)
	if field == null:
		push_error("DocumentInstance.get_value: champ « %s » absent de « %s »" % [field_id, get_document_id()])
		return null
	if field.is_document_level():
		return get(field.get_document_property())
	return values.get(field_id, null)


## Écrit la valeur d'un champ (propriété du document ou `values`).
func set_value(field_id: StringName, value: Variant) -> void:
	var field: FieldDef = get_field(field_id)
	if field == null:
		push_error("DocumentInstance.set_value: champ « %s » absent de « %s »" % [field_id, get_document_id()])
		return
	if field.is_document_level():
		set(field.get_document_property(), value)
	else:
		values[field_id] = value


## Copie profonde (les `PortraitValue` sont dupliqués) ; `type_def` est partagé.
func copy() -> DocumentInstance:
	var result: DocumentInstance = DocumentInstance.new(type_def)
	result.serial = serial
	result.issue_date = issue_date
	result.expiry_date = expiry_date
	result.issuer_id = issuer_id
	result.seal_id = seal_id
	result.mrz = mrz
	result.marks = marks.duplicate()
	result.presented_at = presented_at
	result.third_party = third_party
	result.retired = retired
	for key: StringName in values:
		var value: Variant = values[key]
		if value is PortraitValue:
			var portrait: PortraitValue = value
			result.values[key] = portrait.copy()
		elif value is PackedStringArray:
			var list: PackedStringArray = value
			result.values[key] = list.duplicate()
		else:
			result.values[key] = value
	return result
