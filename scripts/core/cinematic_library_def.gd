## Table des cinématiques (M14 §3.4, B91 ; ARCHITECTURE §12 ter.3) —
## `res://data/cinematics/cinematics.tres` (lot E).
class_name CinematicLibraryDef
extends Resource

const PATH: String = "res://data/cinematics/cinematics.tres"

@export var version: int = 1
@export var cinematics: Array[CinematicDef] = []

## Table des données, ou null si absente.
static func load_default() -> CinematicLibraryDef:
	if not ResourceLoader.exists(PATH):
		return null
	return load(PATH) as CinematicLibraryDef # cache de `ResourceLoader`


func get_cinematic(cinematic_id: StringName) -> CinematicDef:
	for c: CinematicDef in cinematics:
		if c != null and c.id == cinematic_id:
			return c
	return null
