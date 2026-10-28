## Apparences des passagers d'un jour (ARCHITECTURE §9.3), produites par
## `AppearanceGenerator.build_day_roster()`.
##
## Dépend **uniquement** de `day_seed` et des données (catalogue, cas
## scénarisés, poids des origines) : reconstructible, jamais sauvegardé.
## L'entrée `i` porte aussi l'origine du passager `i` (une seule source,
## relue par `PassengerGenerator`).
class_name AppearanceRoster
extends RefCounted


## Une entrée du roster.
class Entry:
	extends RefCounted
	var index: int = 0
	var appearance: PassengerAppearance = null
	## Graine du tirage retenu (`mix3(day_seed, index, attempt)`), traçabilité.
	var appearance_seed: int = 0
	var faction_id: StringName = &""
	## Vrai si aucun essai n'a respecté `min_distance` (repli : candidat le plus éloigné).
	var fallback: bool = false
	## Cas scénarisé à cet index (`ScriptedCaseDef.id`), vide sinon.
	var scripted_id: StringName = &""
	## Distance minimale aux voisins de la fenêtre au moment du tirage (−1 si aucun voisin).
	var min_neighbor_distance: int = -1

	func serialize() -> Dictionary:
		return {
			"index": index,
			"appearance": appearance.serialize() if appearance != null else {},
			"appearance_seed": appearance_seed,
			"faction_id": String(faction_id),
			"fallback": fallback,
			"scripted_id": String(scripted_id),
		}


var day_seed: int = 0
var entries: Array[Entry] = []


func size() -> int:
	return entries.size()


func get_entry(index: int) -> Entry:
	if index < 0 or index >= entries.size():
		push_error("AppearanceRoster: index %d hors roster (%d)" % [index, entries.size()])
		return null
	return entries[index]


func get_fallback_count() -> int:
	var count: int = 0
	for entry: Entry in entries:
		if entry.fallback:
			count += 1
	return count


func serialize() -> Array:
	var result: Array = []
	for entry: Entry in entries:
		result.append(entry.serialize())
	return result
