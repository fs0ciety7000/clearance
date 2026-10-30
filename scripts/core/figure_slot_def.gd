## Emplacement de figure nommée d'une planche (M14 §3.5, B90, B91, D-185 ;
## ARCHITECTURE §12 ter.3) : FG-FIGURE (Mira ou Dora au J30), FG-WREN,
## FG-FIGURE31 (figure du J31). Rempli à l'exécution par le
## `PlateFigureService` (lot C) avec le visage **vu pendant la partie**
## (`CinematicService.figure_appearance`), sinon par la silhouette.
class_name FigureSlotDef
extends Resource

## `fg_figure`, `fg_wren`, `fg_figure31`.
@export var id: StringName = &""
## Cas mémorisés candidats, première condition vraie dont la mémoire a un
## visage (`key` = `ScriptedCaseDef.id`, ex. `sc_82b` si `final3_dora`).
@export var memory_cases: Array[ConditionalKey] = []
## Pose du personnage (`passenger` : `idle`, `present_docs`, `leave`) et image.
@export var pose: StringName = &"idle"
@export var pose_frame: float = 0.0
## Cadrage (`full`, `bust`, `profile`) et éclairage préréglé du studio.
@export var framing: StringName = &"full"
@export var lighting: StringName = &"hall"
## Taille du rendu (viewport du studio).
@export var render_size: Vector2i = Vector2i(512, 768)
## Rectangle dans l'espace de la planche (0..1) et profondeur de parallaxe.
@export var rect: Rect2 = Rect2(0.4, 0.2, 0.25, 0.7)
@export_range(0.0, 1.0) var depth: float = 0.6
## Silhouette de repli (même pose), `res://assets/cinematics/fig/<id>.png`.
@export var silhouette_path: String = ""
## Planche omise si la figure n'a pas de visage mémorisé (PL-E-FIG).
@export var omit_plate_if_missing: bool = false
