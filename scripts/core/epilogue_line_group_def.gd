## Groupe de lignes de conclusion du J31 (M12 §1.9, ARCHITECTURE §11.4) :
## « la première vraie l'emporte » (`ConditionalKey.first_match` sur les
## drapeaux de la graine d'épilogue + ceux posés pendant le J31). Aucune ligne
## si aucune n'est vraie (`fallback_key` vide).
class_name EpilogueLineGroupDef
extends Resource

@export var id: StringName = &""
@export var lines: Array[ConditionalKey] = []
## Ligne si aucune n'est vraie (vide = aucune).
@export var fallback_key: String = ""


## Clé retenue (vide si aucune).
func pick(flags: Dictionary[StringName, Variant]) -> String:
	return ConditionalKey.first_match(lines, flags, fallback_key)
