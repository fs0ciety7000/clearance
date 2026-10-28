## Type de document (ARCHITECTURE §5.2) : un `.tres` par type dans
## `res://data/documents/` (`doc_id_card.tres`…).
##
## Définition **en lecture seule** au runtime (partagée entre tous les cas).
class_name DocumentTypeDef
extends Resource

@export var id: StringName = &""
@export var title_key: String = ""
@export var fields: Array[FieldDef] = []
## Origines pour lesquelles ce document est émis (vide = toutes).
@export var issuer_faction_ids: Array[StringName] = []
## Durée de validité min/max en jours (émission → expiration).
@export var validity_days: Vector2i = Vector2i(30, 365)
## Vue 2D du document (M4) ; null en M2.
@export var view_scene: PackedScene = null
## Nom d'une constante de `DS` (jamais une couleur en dur).
@export var holo_tint_token: StringName = &""
## Émetteur légitime (`&"bureau_continuite"`…), recopié dans `DocumentInstance.issuer_id`.
@export var issuer_id: StringName = &""
## Sceau légitime (`&"seal_solar_hexagon"`…), recopié dans `DocumentInstance.seal_id`.
@export var seal_id: StringName = &""
## Format du numéro (`#` chiffre, `X` alphanumérique, `YYYY` année d'émission).
@export var serial_pattern: String = ""


func get_field(field_id: StringName) -> FieldDef:
	for field: FieldDef in fields:
		if field != null and field.id == field_id:
			return field
	return null


func has_field(field_id: StringName) -> bool:
	return get_field(field_id) != null


## Premier champ portant ce `truth_path`, ou null.
func find_field_by_truth_path(path: StringName) -> FieldDef:
	for field: FieldDef in fields:
		if field != null and field.truth_path == path:
			return field
	return null


## Champs triés par `display_order` (copie).
func get_sorted_fields() -> Array[FieldDef]:
	var sorted: Array[FieldDef] = fields.duplicate()
	sorted.sort_custom(func(a: FieldDef, b: FieldDef) -> bool: return a.display_order < b.display_order)
	return sorted
