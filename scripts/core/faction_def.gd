## Origine d'un passager (ARCHITECTURE §5.2, LORE §5) : un `.tres` par origine
## dans `res://data/factions/` (contenu : Lore Master).
##
## Le premier chiffre du bloc du N° ID encode l'origine : `id_prefix` = `"HG-4"`
## pour Tycho. La réserve de noms (`NamePool`) arrive avec le générateur (M3).
class_name FactionDef
extends Resource

@export var id: StringName = &""
@export var name_key: String = ""
## Code d'origine à 3 lettres (champ « Origine », MRZ) : `"TYC"`.
@export var code: String = ""
## Préfixe du N° ID : `"HG-"` + chiffre d'origine.
@export var id_prefix: String = ""
@export var origin_sectors: PackedStringArray = []
## Sceau / emblème (asset, M4+) ; null en M2.
@export var seal_texture: Texture2D = null


## Vrai si le N° ID est cohérent avec cette origine (règle R10, GDD §7).
func matches_citizen_id(citizen_id: String) -> bool:
	return not id_prefix.is_empty() and citizen_id.begins_with(id_prefix)


## Chiffre d'origine (4 pour `"HG-4"`), −1 si le préfixe est mal formé.
func get_id_block_digit() -> int:
	var digit: String = id_prefix.right(1)
	return digit.to_int() if digit.is_valid_int() else -1
