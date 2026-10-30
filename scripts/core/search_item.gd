## Objet révélé par la fouille holographique (M13, D-140, D-145 ; ARCHITECTURE §12.3).
##
## Instance d'une entrée du catalogue `data/search/items.tres` (lot B : OL-01 →
## OL-10, CB-01 → CB-08) placée dans une zone du `SearchLayout`. Comparable en
## Mode Inspection une fois révélée : `FieldRef.scan(zone, index)` =
## `(__scan__, "<zone>:<index>")` (objet ↔ R45 / R46 / onglet Contrebande ;
## implant trouvé ↔ « Implants déclarés » ; imprimé ↔ bulletin des symboles).
##
## `kind` décrit l'objet **tel qu'il est affiché** (catégorie du catalogue) : le
## verdict reste celui des règles (R45, R46, R15, R16) et l'UI n'affiche jamais
## `kind` comme une conclusion (D-005).
class_name SearchItem
extends RefCounted

enum Kind {
	LEGIT = 0, ## Objet légitime (OL-01 → OL-09).
	CONTRABAND = 1, ## Objet interdit (CB-01 → CB-05, R45 : refus).
	WEAPON = 2, ## Arme (CB-06, CB-07, R46 : détention).
	SUBVERSIVE = 3, ## Imprimé à la luciole (CB-08 : signalement par le bulletin ; catalogue `PRINT`).
	IMPLANT = 4, ## Implant dissimulé (déclaré : OL-10 ; sinon R15 / R16).
}

## Identifiant d'instance (`"z5:0"`), égal au champ de `FieldRef.scan`.
var id: StringName = &""
## Entrée du catalogue (`cb01`, `ol04`…).
var item_id: StringName = &""
## Catégorie du catalogue (`oxygen`, `stimulant`, `medicine`, `data`, `seeds`,
## `blade`, `jammer`, `print`, `personal`…), lue par `ContrabandRule` (lot B).
var category: StringName = &""
var kind: Kind = Kind.LEGIT
## Zone (`SearchLayout.ZONE_*`) et rang dans la zone (posés par `SearchLayout.add`).
var zone: StringName = &""
var index: int = 0
## Textes : nom, ligne de description (`item_<id>_{name,desc}`), arguments
## (quantité…), mentions écrites en toutes lettres (`item_attr_unsealed`…).
var name_key: String = ""
var desc_key: String = ""
var args: Array = []
var attribute_keys: PackedStringArray = []
## Implant (`KIN-11`, `MIL-15`, `DER-19`…), vide sinon.
var implant_code: String = ""
## Contenu non lisible (blindage d'un `DER-19`, `line_scan_unreadable`).
var unreadable: bool = false
## Zone scannée dans la session : l'objet est visible et comparable.
var revealed: bool = false


static func make(p_item_id: StringName, p_kind: Kind, p_category: StringName = &"") -> SearchItem:
	var item: SearchItem = SearchItem.new()
	item.item_id = p_item_id
	item.kind = p_kind
	item.category = p_category
	item.name_key = "item_%s_name" % p_item_id
	item.desc_key = "item_%s_desc" % p_item_id
	return item


static func implant(code: String, p_item_id: StringName = &"ol10") -> SearchItem:
	var item: SearchItem = make(p_item_id, Kind.IMPLANT, &"implant")
	item.implant_code = code
	return item


func get_ref() -> FieldRef:
	return FieldRef.scan(zone, index)


func is_implant() -> bool:
	return kind == Kind.IMPLANT


## Objet interdit par R45 ou R46 (CB-01 → CB-07). L'imprimé (CB-08) n'en est pas un.
func is_forbidden() -> bool:
	return kind == Kind.CONTRABAND or kind == Kind.WEAPON


func copy() -> SearchItem:
	var item: SearchItem = SearchItem.new()
	item.id = id
	item.item_id = item_id
	item.category = category
	item.kind = kind
	item.zone = zone
	item.index = index
	item.name_key = name_key
	item.desc_key = desc_key
	item.args = args.duplicate()
	item.attribute_keys = attribute_keys.duplicate()
	item.implant_code = implant_code
	item.unreadable = unreadable
	item.revealed = revealed
	return item


func serialize() -> Dictionary:
	return {
		"id": String(id), "item_id": String(item_id), "category": String(category), "kind": Kind.find_key(kind),
		"zone": String(zone), "index": index, "args": args.map(func(arg: Variant) -> String: return str(arg)),
		"attributes": Array(attribute_keys), "implant": implant_code, "unreadable": unreadable,
	}


func _to_string() -> String:
	return "SearchItem(%s %s)" % [id, item_id]
