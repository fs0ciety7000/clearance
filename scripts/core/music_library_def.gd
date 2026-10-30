## Bibliothèque musicale (M14 §2.2, §2.7, B81, D-176 → D-182 ; ARCHITECTURE
## §12 ter.2) — `res://assets/audio/music/music_library.tres` (lot B).
##
## Sélection **pure** de l'ensemble d'un contexte (jour, mode) et du thème
## d'une fin ou d'un monde. Lue par le `MusicDirector` (lot B) ; jamais par la
## logique de jeu.
class_name MusicLibraryDef
extends Resource

const PATH: String = "res://assets/audio/music/music_library.tres"

const SET_TITLE: StringName = &"ms_01"
const SET_ACT1: StringName = &"ms_02"
const SET_ACT2: StringName = &"ms_03"
const SET_ACT3: StringName = &"ms_04"
const SET_GARDE: StringName = &"ms_05"
const SET_EVENING: StringName = &"ms_06"
const SET_EPILOGUE: StringName = &"ms_07"
## Groupes de couches (MS-06, MS-07, MS-01).
const GROUP_WARM: StringName = &"warm"
const GROUP_CRISIS: StringName = &"crisis"
const GROUP_ENDING_SEEN: StringName = &"ending_seen"
const GROUP_WORLD_PREFIX: String = "world_"
## Plafond Récit et J31 (D-178).
const STORY_MAX_LEVEL: int = 2
## Niveau figé de l'option « Musique : Stable » (D-181).
const STABLE_LEVEL: int = 1

@export var sets: Array[MusicSetDef] = []
@export var themes: Array[MusicThemeDef] = []

## Bibliothèque des données, ou null tant que la musique n'est pas rendue.
static func load_default() -> MusicLibraryDef:
	if not ResourceLoader.exists(PATH):
		return null
	return load(PATH) as MusicLibraryDef # cache de `ResourceLoader`


## Ensemble d'un jour joué : Garde MS-05, J31 MS-07, sinon l'acte du jour
## (J1–J10 MS-02, J11–J20 MS-03, J21–J30 MS-04).
static func set_id_for_day(day_number: int, mode: StringName = DayDef.MODE_CAMPAIGN) -> StringName:
	if mode == DayDef.MODE_GARDE:
		return SET_GARDE
	if mode == DayDef.MODE_EPILOGUE or day_number > 30:
		return SET_EPILOGUE
	if day_number <= 10:
		return SET_ACT1
	return SET_ACT2 if day_number <= 20 else SET_ACT3


## Groupe de couche d'un monde du J31 (`world_a`…).
static func world_group(world: StringName) -> StringName:
	return StringName(GROUP_WORLD_PREFIX + String(world))


## Plafond de niveau d'un jour : N2 en Récit et au J31, sinon N4.
static func max_level_for(day_number: int, story_mode: bool) -> int:
	return STORY_MAX_LEVEL if story_mode or day_number > 30 else MusicSetDef.LEVEL_MAX


func get_set(set_id: StringName) -> MusicSetDef:
	for s: MusicSetDef in sets:
		if s != null and s.id == set_id:
			return s
	return null


func get_theme(theme_id: StringName) -> MusicThemeDef:
	for t: MusicThemeDef in themes:
		if t != null and t.id == theme_id:
			return t
	return null


## Thème d'une fin : d'abord un thème qui nomme la variante, sinon un thème
## sans variante ; null si aucun (fins des actes I–II simulées, démo).
func theme_for_ending(ending: StringName, variant: StringName) -> MusicThemeDef:
	var generic: MusicThemeDef = null
	for t: MusicThemeDef in themes:
		if t == null or not t.matches_ending(ending, variant):
			continue
		if not t.ending_variants.is_empty():
			return t
		if generic == null:
			generic = t
	return generic


## Thème d'un monde du J31 (`a` … `d`), null si absent.
func theme_for_world(world: StringName) -> MusicThemeDef:
	for t: MusicThemeDef in themes:
		if t != null and t.worlds.has(world):
			return t
	return null
