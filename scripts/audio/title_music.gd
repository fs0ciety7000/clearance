## Musique de l'écran titre (M14 §2.2 MS-01, I47 ; docs/AUDIO.md §13) —
## `MusicDirector` de `main.tscn` : MS-01 (nappe, pluie tonale, MO-1 lointain)
## au premier plan (−20 LUFS), plus la couche MO-2 (`ending_seen`) une fois une
## fin vue (profil). Fondu d'entrée de 1,5 s par l'effet `Fade` ; `volume_music`
## à 0 : lecteur arrêté. Le Dossier (REVOIR, lot D) peut y jouer un thème
## (`play_theme_after_fade`). Titre → partie : `fade_out()` (1,5 s) avant le
## changement de scène (QA-075, M14 §2.6).
class_name TitleMusic
extends MusicDirector

const SET_PATH: String = "res://assets/audio/music/sets/ms_01.tres"
const GROUP_ENDING_SEEN: StringName = &"ending_seen"
const ENTER_SEC: float = 1.5

## Faux : rien n'est joué au `_ready` (tests).
@export var autostart: bool = true


func _ready() -> void:
	super()
	EventBus.settings_changed.connect(_on_settings_changed)
	if autostart:
		start()


## MS-01 depuis le début ; vrai si l'ensemble est rendu.
func start(profile: Dictionary = {}) -> bool:
	if not ResourceLoader.exists(SET_PATH):
		return false
	var set_def: MusicSetDef = load(SET_PATH) as MusicSetDef
	if set_def == null:
		return false
	configure_from_def(set_def)
	var seen: Dictionary = profile if not profile.is_empty() else ProfileService.load_profile()
	var groups_now: Array[StringName] = []
	if not ProfileService.ending_ids(seen).is_empty():
		groups_now.append(GROUP_ENDING_SEEN)
	set_groups(groups_now)
	if is_zero_approx(Settings.get_float(Settings.KEY_VOLUME_MUSIC)):
		set_suspended(true)
	play(set_def.id, 0, ENTER_SEC)
	return true


## Fondu de sortie par l'effet `Fade` (titre → partie, 1,5 s), lecteur arrêté
## à la fin ; renvoie la durée à attendre avant `change_scene_to_file` (0 sans
## musique : changer de scène tout de suite). Le nœud tourne en
## `PROCESS_MODE_ALWAYS` : le fondu avance aussi l'arbre en pause.
func fade_out(seconds: float = ENTER_SEC) -> float:
	_pending_theme = {}
	if not is_playing() or seconds <= 0.0:
		return 0.0
	fade_to(SILENT_DB, seconds, true)
	return seconds


func _on_settings_changed(key: StringName, value: Variant) -> void:
	if key == Settings.KEY_VOLUME_MUSIC:
		set_suspended(is_zero_approx(float(value)))
