## Entrée du catalogue de fouille (M13, docs/M13.md §2.5 ; B69) : objet
## légitime OL-01 → OL-10 ou interdit CB-01 → CB-08, dans
## `data/search/search_catalog.tres` (`SearchCatalogDef`).
##
## Donnée seulement : le générateur (`SearchGenerator`) en tire des objets
## concrets (`SearchItem`, lot A) placés dans les zones Z1 → Z5 du cas.
class_name SearchItemDef
extends Resource

## `ol01` … `ol10`, `cb01` … `cb08`.
@export var id: StringName = &""
## Nature affichée (`SearchItem.Kind` : LEGIT, CONTRABAND, WEAPON, SUBVERSIVE, IMPLANT).
@export var kind: SearchItem.Kind = SearchItem.Kind.LEGIT
## Catégorie du catalogue (`oxygen`, `stimulant`, `medicine`, `data`, `seeds`,
## `blade`, `jammer`, `print`, `personal`…) : entrée de l'onglet Contrebande
## (`FieldRef.contraband_entry`) et clé de `ContrabandRule`.
@export var category: StringName = &""
## Mentions écrites en toutes lettres (`item_attr_unsealed`…), recopiées sur l'objet.
@export var attribute_keys: PackedStringArray = []
## Libellés (`item_<id>_name`, `item_<id>_desc` ; `%d` = quantité, `%s` = code d'implant).
@export var name_key: String = ""
@export var desc_key: String = ""
## Zones où l'objet peut se trouver (`z1` … `z5`).
@export var zones: PackedStringArray = []
## Quantité affichée (min, max) ; (0, 0) = sans quantité.
@export var quantity: Vector2i = Vector2i.ZERO
## Origines dont les porteurs tirent cet objet de contrebande (vide = toutes).
@export var faction_ids: Array[StringName] = []
## Objet « presque identique » de l'autre catégorie (OL-04 ↔ CB-01) : paires
## subtiles de la Garde (`subtle`).
@export var twin_id: StringName = &""
## Règle qui l'interdit (`r_contraband`, `r_weapons_detain`) ; vide si autorisé.
@export var rule_id: StringName = &""
## Motif de commerce requis (OL-07 : COMMERCE) ; vide = tous.
@export var purpose: StringName = &""


func is_forbidden() -> bool:
	return kind == SearchItem.Kind.CONTRABAND or kind == SearchItem.Kind.WEAPON


## Objet concret (`SearchItem`, lot A) tiré de cette entrée ; `quantity_value`
## (> 0) est passé en argument de la description.
func instantiate(quantity_value: int = 0) -> SearchItem:
	var item: SearchItem = SearchItem.make(id, kind, category)
	item.name_key = name_key
	item.desc_key = desc_key
	item.attribute_keys = attribute_keys.duplicate()
	if quantity_value > 0:
		item.args = [quantity_value]
	return item


func can_be_in(zone: StringName) -> bool:
	return zones.has(String(zone))
