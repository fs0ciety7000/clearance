## Variante d'un thème de fin (M14 §2.7 : `okonkwo_warned`, `lumika_learned`,
## Dora…), choisie par condition sur les drapeaux de la partie (première vraie,
## `MusicThemeDef.variant_for`). Remplace le flux principal et, si fourni, la queue.
class_name MusicThemeVariantDef
extends Resource

@export var id: StringName = &""
@export var condition: FlagCondition = null
## Flux principal (ouverture → B) de la variante ; null = celui du thème.
@export var stream: AudioStream = null
## Queue de la variante ; null = celle du thème.
@export var tail_stream: AudioStream = null
## Section concernée (information, tests : `b` pour la plupart).
@export var section: StringName = &"b"
