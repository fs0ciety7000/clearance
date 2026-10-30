## Section d'un thème de fin (M14 §2.7, B81, D-182) : ouverture (carte de
## titre), A (planches 1–2), B (planches 3–4), queue (8 mesures bouclables,
## sous l'écran de fin). Les mesures sont comptées depuis le début du thème
## (`MusicThemeDef.stream`) ; la queue est un flux à part (`tail_stream`).
class_name MusicSectionDef
extends Resource

const OPENING: StringName = &"opening"
const A: StringName = &"a"
const B: StringName = &"b"
const TAIL: StringName = &"tail"

@export var id: StringName = OPENING
@export var start_bar: int = 0
@export var bars: int = 2
## Bouclable (queue).
@export var loop: bool = false
