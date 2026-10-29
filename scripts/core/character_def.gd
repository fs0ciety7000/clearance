## Personnage du Dossier de l'agent (M12 §5.2, D-131 ; ARCHITECTURE §11.8),
## dans `res://data/dossier/characters.tres` (`CharacterTableDef`, lot B).
class_name CharacterDef
extends Resource

## `chr_mira`…
@export var id: StringName = &""
## Cas regroupés (`ScriptedCaseDef.id`).
@export var case_ids: Array[StringName] = []
## Nom affiché tant que le vrai nom n'est pas appris (« Bastien Duval »,
## « L'habitué·e de l'Anneau C ») — clé ou texte.
@export var display_name: String = ""
## Vrai nom, affiché une fois appris (`known_names` du profil) ; vide = le
## nom affiché est déjà le vrai.
@export var true_name: String = ""
## Condition sur les drapeaux d'une partie : vrai nom appris.
@export var known_name_if: FlagCondition = null
## Vrai nom appris aussi dès qu'une fin est vue (Arkady).
@export var known_on_ending: bool = false
@export var faction: StringName = &""
## Ligne de présentation (`dos_chr_<id>`).
@export var blurb_key: String = ""


## Vrai si le vrai nom est appris dans une partie (drapeaux, fin vue).
func is_name_known(flags: Dictionary[StringName, Variant], ending_seen: bool = false) -> bool:
	if true_name.is_empty():
		return true
	if known_on_ending and ending_seen:
		return true
	return known_name_if != null and known_name_if.evaluate(flags)
