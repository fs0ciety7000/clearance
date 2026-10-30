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
## M14 (B92, D-191) — cas dont le visage vu à la vitre devient le portrait du
## Dossier (liste blanche ; vide = tous les `case_ids`). Exclut un sosie, un
## usurpateur, une photo d'un autre visage ; un personnage seulement entendu
## ou lu n'a aucun cas de portrait (initiales). Données : lot F.
@export var portrait_cases: Array[StringName] = []


## Vrai si le vrai nom est appris dans une partie (drapeaux, fin vue).
func is_name_known(flags: Dictionary[StringName, Variant], ending_seen: bool = false) -> bool:
	if true_name.is_empty():
		return true
	if known_on_ending and ending_seen:
		return true
	return known_name_if != null and known_name_if.evaluate(flags)


## M14 : vrai si le visage du cas `case_id` peut servir de portrait.
func allows_portrait(case_id: StringName) -> bool:
	if not case_ids.has(case_id):
		return false
	return portrait_cases.is_empty() or portrait_cases.has(case_id)
