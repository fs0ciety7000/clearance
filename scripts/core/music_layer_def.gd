## Couche d'un ensemble musical (M14 §2.3, B81, D-176 ; ARCHITECTURE §12 ter.2).
##
## Une couche est un flux bouclé de `MusicSetDef.bars` mesures **exactement**
## (M-06), mixé dans un `AudioStreamSynchronized` : son volume est réglé dans
## le flux (`set_sync_stream_volume`), jamais par le `volume_db` d'un lecteur
## (D-083, D-176). Données : `assets/audio/music/sets/ms_0N.tres` (lot B).
class_name MusicLayerDef
extends Resource

# Rôles (§2.3 ; MS-01 / MS-06 / MS-07 : `bed` et variantes de groupe).
const ROLE_PAD: StringName = &"pad"         # L0 nappe
const ROLE_PULSE: StringName = &"pulse"     # L1 pulsation
const ROLE_RHYTHM: StringName = &"rhythm"   # L2 rythme
const ROLE_MOTIF: StringName = &"motif"     # L3 motif (mélodie : coupée en inspection)
const ROLE_TENSION: StringName = &"tension" # L4 tension
const ROLE_BED: StringName = &"bed"         # couche commune d'un ensemble à 2–3 couches
const ROLE_VARIANT: StringName = &"variant" # couche de groupe (chaud / crise, monde A–D)

## `l0` … `l4`, `bed`, `rain`, `warm`, `crisis`, `world_a` … `world_d`, `luciole`.
@export var id: StringName = &""
@export var role: StringName = ROLE_PAD
## Flux bouclé (OGG Vorbis 32 kHz, `loop = true`) ; null tant que la
## musique n'est pas rendue (le `MusicDirector` l'ignore).
@export var stream: AudioStream = null
## Gain de la couche dans le flux (dB) quand elle est active (§2.10 : les
## gains se font dans Godot, les fichiers sont normalisés à −1 dBTP).
@export var gain_db: float = 0.0
## Niveau d'intensité (N0 → N4) à partir duquel la couche entre.
@export_range(0, 4) var enter_level: int = 0
## Niveau à partir duquel elle sort (`L3` : 4, remplacée par `L4`) ; −1 = jamais.
@export_range(-1, 4) var exit_level: int = -1
## Présente en mode « exposé » (briefing : L0 + L3, MO-1 en tête).
@export var exposed: bool = false
## Mélodie : coupée en Mode Inspection (option `music_inspection_reduce`) et
## au chrono critique (§2.5).
@export var melodic: bool = false
## Reste au « power down » (EV-05, grève du J20 : L0 seule).
@export var keeps_on_power_down: bool = false
## Groupe : vide = toujours éligible ; sinon la couche n'est active que si le
## groupe est sélectionné (`warm` / `crisis` de MS-06, `world_a`… de MS-07,
## `ending_seen` : MO-2 de MS-01 après une première fin vue).
@export var group: StringName = &""


## Active au niveau `level` (hors masques et groupes).
func is_active_at(level: int) -> bool:
	return level >= enter_level and (exit_level < 0 or level < exit_level)
