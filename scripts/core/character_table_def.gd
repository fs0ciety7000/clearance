## Table des personnages du Dossier (M12 §5.2) — `res://data/dossier/characters.tres`.
class_name CharacterTableDef
extends Resource

const PATH: String = "res://data/dossier/characters.tres"

@export var characters: Array[CharacterDef] = []


## Table des données, ou null si absente.
static func load_default() -> CharacterTableDef:
	if not ResourceLoader.exists(PATH):
		return null
	return load(PATH) as CharacterTableDef


## Personnage d'un cas scénarisé, ou null.
func character_of(case_id: StringName) -> CharacterDef:
	for character: CharacterDef in characters:
		if character != null and character.case_ids.has(case_id):
			return character
	return null


## Personnages dont le vrai nom est appris dans cette partie.
func known_names(flags: Dictionary[StringName, Variant], ending_seen: bool = false) -> PackedStringArray:
	var ids: PackedStringArray = []
	for character: CharacterDef in characters:
		if character != null and not character.true_name.is_empty() and character.is_name_known(flags, ending_seen):
			ids.append(String(character.id))
	return ids
