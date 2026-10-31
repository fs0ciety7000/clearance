## Annonce du haut-parleur du Hall (Acte II, B35 ; docs/ACT2.md §5.2) —
## données de `DayDef.announcements`, en complément de `hall_announcements`
## (annonces inconditionnelles après le n-ième cas).
##
## Déclencheur : après le `after_case`-ième cas traité, **ou** à l'heure du
## shift `at_minute` (minutes depuis minuit, ex. 960 = 16:00, couvre-feu du
## J16). `condition` : drapeaux narratifs du moment (null = toujours).
## `ends_shift` : le shift s'arrête après l'annonce (grève du J20, F9) ; les
## passagers restants ne sont pas traités.
class_name HallAnnouncementDef
extends Resource

@export var text_key: String = ""
@export var after_case: int = -1
@export var at_minute: int = -1
@export var condition: FlagCondition = null
@export var ends_shift: bool = false
## M14 (§2.5, B83) — effet sur la musique (`MusicDirector`, lot B) :
## `MUSIC_DROP` (L0 seule, −6 dB, 4 mesures), `MUSIC_SILENCE` (power down),
## `MUSIC_SWELL` (+1 niveau et MO-1 entier) ; vide = aucun. Données : lot F.
@export var music_action: StringName = &""

const MUSIC_DROP: StringName = &"drop"
const MUSIC_SILENCE: StringName = &"silence"
const MUSIC_SWELL: StringName = &"swell"
const MUSIC_ACTIONS: Array[StringName] = [MUSIC_DROP, MUSIC_SILENCE, MUSIC_SWELL]
