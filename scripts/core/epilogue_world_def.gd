## Monde de l'épilogue J31 (M12 §1.3, D-124 ; ARCHITECTURE §11.4) : A
## Continuité, B Air commun, C Mémoire, D Autre côté.
class_name EpilogueWorldDef
extends Resource

@export var id: StringName = &""
## Jour du monde (`DayDef.mode = epilogue`, `epilogue_world = id`,
## `day_number = 31`, `passenger_count = 7`, `economy_disabled`, `untimed`).
@export var day_def: DayDef = null
## Surtitre de la carte de conclusion (`epi_eyebrow_a`…).
@export var eyebrow_key: String = ""
## Nom du monde au Dossier (`dos_world_a`…).
@export var name_key: String = ""
## Lignes de monde, un groupe par cas du J31, dans l'ordre (§1.9).
@export var line_groups: Array[EpilogueLineGroupDef] = []
## Réplique Tessar de la figure approuvée (première vraie), fin de la carte.
@export var farewell_lines: Array[ConditionalKey] = []
