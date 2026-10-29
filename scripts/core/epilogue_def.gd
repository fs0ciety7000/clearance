## Épilogue « Un an plus tard » (M12 §1, D-122 → D-125 ; ARCHITECTURE §11.4)
## — `res://data/epilogue/epilogue.tres` (lot B, `tools/build_data_m12.gd`).
##
## Lu par `EpilogueService` : liste blanche des drapeaux de la graine
## (`read_flags`), cas mémorisés emportés (`memory_case_ids`), mondes (jours
## J31), variantes de fin (ouverture, clôture), lignes communes de la carte
## de conclusion.
class_name EpilogueDef
extends Resource

## Version des données d'épilogue (graine : `epilogue_version`).
@export var version: int = 1
## Drapeaux lus par le J31 (≈ 45) : seuls ceux-ci passent dans la graine.
## Vide : tous les drapeaux de la partie (repli).
@export var read_flags: Array[StringName] = []
## Entrées `CaseMemory` emportées (`tuto_concordant`, `sc_04`, `sc_82a`, `sc_82b`).
@export var memory_case_ids: Array[StringName] = [&"tuto_concordant", &"sc_04", &"sc_82a", &"sc_82b"]
@export var worlds: Array[EpilogueWorldDef] = []
@export var endings: Array[EpilogueEndingDef] = []
@export var title_key: String = "epi_title"
## « 7 passagers · %d avertissement(s) ».
@export var tally_key: String = "epi_tally"
## Ligne de SC-90 (`epi_first_passed` / `epi_first_refused`).
@export var first_lines: Array[ConditionalKey] = []
## Lignes du foyer communes (première vraie), après les lignes de monde.
@export var home_lines: Array[ConditionalKey] = []
## Lignes au plus sur la carte (hors bilan et réplique Tessar).
@export var max_lines: int = 8


func get_world(world_id: StringName) -> EpilogueWorldDef:
	for world: EpilogueWorldDef in worlds:
		if world != null and world.id == world_id:
			return world
	return null


func get_ending(key: StringName) -> EpilogueEndingDef:
	for ending: EpilogueEndingDef in endings:
		if ending != null and ending.key == key:
			return ending
	return null
