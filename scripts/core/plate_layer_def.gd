## Couche d'une planche de cinématique (M14 §3.3, §3.6, B91, D-184 ;
## ARCHITECTURE §12 ter.3) : fond peint `BG`, accessoires ou foule `MID`,
## silhouette anonyme figée `FIG`, effet procédural `FX`. La couche `HOLO`
## (`PlateLabelDef`) et la légende `CAP` sont posées par le `CinematicScreen`
## (lot D). Les figures **nommées** passent par `FigureSlotDef`.
##
## Champs « exécution » (lot D) et « rendu hors ligne » (lot C,
## `tools/build_plates.gd`) dans la même ressource (lot E : compositions).
class_name PlateLayerDef
extends Resource

const KIND_BG: StringName = &"bg"
const KIND_MID: StringName = &"mid"
const KIND_FIG: StringName = &"fig"
const KIND_FX: StringName = &"fx"
const KINDS: Array[StringName] = [KIND_BG, KIND_MID, KIND_FIG, KIND_FX]
## Ajout lot E (demande du lot C, BOOTH_SCENE §19.2, §19.8 a) : couche d'**état**
## « allumé » d'un élément du fond (PL-F9-1 : une vitre), découpée par la passe
## d'identifiants ; l'écran l'éteint (`modulate.a`) selon `PlateDef.holo_effect`.
## Le fond peint est l'état éteint. Index de l'élément : `state_index`.
const KIND_LIT: StringName = &"lit"
const STATE_KINDS: Array[StringName] = [KIND_LIT]
## Effets procéduraux (shader, figés si `reduce_motion`).
const FX_RAIN: StringName = &"rain"
const FX_SMOKE: StringName = &"smoke"
const FX_DUST: StringName = &"dust"
const FX_AIR: StringName = &"air"
const FX_FOG: StringName = &"fog"

@export var kind: StringName = KIND_BG
## Image rendue (`res://assets/cinematics/<bg|mid|fig>/<id>.png`) ; vide pour `FX`.
## Chemin (pas de `Texture2D`) : le `CinematicScreen` précharge la planche
## suivante en tâche de fond (`ResourceLoader.load_threaded_request`).
@export var texture_path: String = ""
## Rectangle dans l'espace de la planche (0..1 sur 2048×1152) ; fond : (0, 0, 1, 1).
@export var rect: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0)
## Profondeur de parallaxe : 0 = fond, 1 = couche la plus proche (décalage
## `depth × PlateDef.parallax_px`).
@export_range(0.0, 1.0) var depth: float = 0.0
## `FX` : `FX_*` et densité (0..1).
@export var fx_kind: StringName = &""
@export_range(0.0, 1.0) var fx_density: float = 0.5
## Ajout lot E (demande du lot C) : `KIND_LIT` — index de l'élément d'état
## (PL-F9-1 : 0 = vitre 01 … 11 = vitre 12), −1 sinon. L'ordre d'extinction
## est l'ordre des couches `KIND_LIT` dans `PlateDef.layers`.
@export var state_index: int = -1

@export_group("Rendu hors ligne")
## `MID` / `FIG` anonyme : graine d'apparence fixe (jamais un visage nommé),
## pose (`idle`, `present_docs`, `leave`, `sit`…) et image de la pose (s).
@export var figure_seed: int = 0
@export var pose: StringName = &""
@export var pose_frame: float = 0.0
@export var world_position: Vector3 = Vector3.ZERO
@export var facing_deg: float = 0.0
## Accessoires du décor posés pour cette couche (`cartons`, `stove`…).
@export var props: Array[StringName] = []
