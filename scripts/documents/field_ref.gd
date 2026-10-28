## Pointeur vers un champ affiché (ARCHITECTURE §5.3) : `(document_id, field_id)`.
##
## Pseudo-documents réservés (sélectionnables en mode Inspection, GDD §4.1) :
## - `passenger_face()` = `(__passenger__, face)` : le visage de l'acteur 3D ;
## - `today()` = `(__rulebook__, __today__)` : la date du jour du Rulebook ;
## - `rulebook_rule(rule_id)` = `(__rulebook__, <rule_id>)` : une règle du Rulebook ;
## - `wanted(notice_id)` = `(__wanted__, <notice_id>)` : une entrée de l'avis de recherche (M7) ;
## - `symbol(symbol_id)` = `(__symbols__, <symbol_id>)` : une entrée du bulletin
##   « Symboles subversifs » (onglet du Rulebook, J7+ : `luciole`) ;
## - `mark(document_id, mark_id)` = `(<document_id>, mark:<mark_id>)` : une marque
##   au coin d'un document (`DocumentInstance.marks`, ex. la luciole du code 1).
##   Paire marque ↔ symbole = preuve d'un signalement (NARRATIVE §4.9).
## GDScript n'admet pas de constante objet : `FieldRef.PASSENGER_FACE` du
## document d'architecture devient la fabrique `FieldRef.passenger_face()`.
class_name FieldRef
extends RefCounted

const PASSENGER_DOCUMENT_ID: StringName = &"__passenger__"
const FACE_FIELD_ID: StringName = &"face"
const RULEBOOK_DOCUMENT_ID: StringName = &"__rulebook__"
const TODAY_FIELD_ID: StringName = &"__today__"
## Avis de recherche du jour (M7, R22) : `(__wanted__, <notice_id>)`.
const WANTED_DOCUMENT_ID: StringName = &"__wanted__"
## Bulletin « Symboles subversifs » (M7, J7+) : `(__symbols__, <symbol_id>)`.
const SYMBOLS_DOCUMENT_ID: StringName = &"__symbols__"
## Préfixe du champ d'une marque de document : `mark:<mark_id>`.
const MARK_PREFIX: String = "mark:"

var document_id: StringName = &""
var field_id: StringName = &""


func _init(p_document_id: StringName = &"", p_field_id: StringName = &"") -> void:
	document_id = p_document_id
	field_id = p_field_id


static func passenger_face() -> FieldRef:
	return FieldRef.new(PASSENGER_DOCUMENT_ID, FACE_FIELD_ID)


static func today() -> FieldRef:
	return FieldRef.new(RULEBOOK_DOCUMENT_ID, TODAY_FIELD_ID)


static func rulebook_rule(rule_id: StringName) -> FieldRef:
	return FieldRef.new(RULEBOOK_DOCUMENT_ID, rule_id)


## Entrée de l'avis de recherche du jour (M7, onglet « Avis de recherche »).
static func wanted(notice_id: StringName) -> FieldRef:
	return FieldRef.new(WANTED_DOCUMENT_ID, notice_id)


## Entrée du bulletin « Symboles subversifs » (`symbol_id` = id de marque, ex. `luciole`).
static func symbol(symbol_id: StringName) -> FieldRef:
	return FieldRef.new(SYMBOLS_DOCUMENT_ID, symbol_id)


## Marque `mark_id` au coin du document `document_id`.
static func mark(p_document_id: StringName, mark_id: StringName) -> FieldRef:
	return FieldRef.new(p_document_id, StringName(MARK_PREFIX + String(mark_id)))


func is_symbol() -> bool:
	return document_id == SYMBOLS_DOCUMENT_ID


func is_mark() -> bool:
	return String(field_id).begins_with(MARK_PREFIX) and not is_symbol()


## Identifiant de la marque (`luciole`), vide si ce n'est pas une marque.
func get_mark_id() -> StringName:
	return StringName(String(field_id).trim_prefix(MARK_PREFIX)) if is_mark() else &""


func is_wanted() -> bool:
	return document_id == WANTED_DOCUMENT_ID


func is_passenger_face() -> bool:
	return document_id == PASSENGER_DOCUMENT_ID and field_id == FACE_FIELD_ID


func is_today() -> bool:
	return document_id == RULEBOOK_DOCUMENT_ID and field_id == TODAY_FIELD_ID


## Vrai pour une règle du Rulebook (hors date du jour).
func is_rule() -> bool:
	return document_id == RULEBOOK_DOCUMENT_ID and field_id != TODAY_FIELD_ID


## Vrai pour un champ d'un vrai document du passager.
func is_document_field() -> bool:
	return document_id != PASSENGER_DOCUMENT_ID and document_id != RULEBOOK_DOCUMENT_ID \
			and document_id != WANTED_DOCUMENT_ID and document_id != &""


func equals(other: FieldRef) -> bool:
	return other != null and document_id == other.document_id and field_id == other.field_id


## Clé texte stable (`"id_card/family_name"`) pour les ensembles et les logs.
func key() -> String:
	return "%s/%s" % [document_id, field_id]


func _to_string() -> String:
	return "FieldRef(%s)" % key()
