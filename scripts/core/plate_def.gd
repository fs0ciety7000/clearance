## Planche d'une cinématique de fin (M14 §3.3–§3.6, B89, B91, D-183, D-184 ;
## ARCHITECTURE §12 ter.3) — `data/cinematics/plates/pl_*.tres` (compositions :
## lot E ; rendu : lot C ; affichage : lot D).
##
## Une planche partagée (PL-F5-2, PL-F6-2…) est **une** ressource référencée
## par plusieurs `CinematicDef`. Variantes : deux planches de même place,
## départagées par `min_act` / `max_act` / `condition` (PL-F1-3 : borne jaune à
## l'Acte III) ; légendes conditionnelles par `captions` (première vraie).
class_name PlateDef
extends Resource

## Plafonds DS (§3.3) : décalage de parallaxe ≤ 12 px à 1080p, zoom ≤ 1,04.
const PARALLAX_MAX_PX: float = 12.0
const ZOOM_MAX: float = 1.04
## Légende : ≤ 70 caractères (M-16).
const CAPTION_MAX_CHARS: int = 70
## Effets holographiques scénarisés.
const HOLO_GLASS_OFF_SEQUENCE: StringName = &"glass_off_sequence" # PL-F9-1

## `pl_f1_1`, `pl_f5_2`, `pl_e_fig`…
@export var id: StringName = &""
## Actes où la planche peut paraître (rien de l'Acte III dans une fin anticipée).
@export_range(1, 3) var min_act: int = 1
@export_range(1, 3) var max_act: int = 3
## Condition sur les drapeaux (et pseudo-drapeaux `cin_*` de
## `CinematicService.context_flags`) ; null = toujours.
@export var condition: FlagCondition = null
@export var layers: Array[PlateLayerDef] = []
@export var figures: Array[FigureSlotDef] = []
@export var labels: Array[PlateLabelDef] = []
## Légende par défaut (`cin_f1_2`) et variantes (première vraie).
@export var caption_key: String = ""
@export var captions: Array[ConditionalKey] = []
## Durée imposée (s) ; 0 = durée DS `max(6 ; 2,5 + 0,06 × caractères)`.
@export var duration_sec: float = 0.0
## Parallaxe (px à 1080p, ≤ 12) et zoom final (≤ 1,04) ; sens du panoramique.
@export_range(0.0, 12.0) var parallax_px: float = PARALLAX_MAX_PX
@export_range(1.0, 1.04) var zoom_to: float = 1.02
@export var pan: Vector2 = Vector2(1.0, 0.0)
## Effet holographique scénarisé (`HOLO_*`), vide sinon.
@export var holo_effect: StringName = &""

@export_group("Rendu hors ligne")
## Décor `s1` … `s8` et sa variante (`lights_out`, `bornes`, `charte`, `seals`…).
@export var set_id: StringName = &""
@export var set_variant: StringName = &""
@export var camera_position: Vector3 = Vector3.ZERO
@export var camera_target: Vector3 = Vector3(0.0, 1.5, -3.0)
@export var fov: float = 50.0
## Éclairage préréglé (`hall`, `clinical`, `night`, `mine_lamp`…).
@export var lighting: StringName = &""
## Dominante de la fin (nom de jeton de la palette monde, jamais une couleur
## codée en dur) et réglages de peinture (`plate_paint.gdshader`).
@export var dominant: StringName = &""
@export var paint_tones: int = 8
@export var paint_radius_px: int = 4
## Instant figé des uniformes temporels (`plate_time`).
@export var plate_time: float = 0.0


## Clé de la légende pour ces drapeaux.
func caption_for(flags: Dictionary[StringName, Variant]) -> String:
	return ConditionalKey.first_match(captions, flags, caption_key)


## Vrai si la planche peut paraître à l'acte `act` avec ces drapeaux.
func is_eligible(act: int, flags: Dictionary[StringName, Variant]) -> bool:
	return act >= min_act and act <= max_act and FlagCondition.check(condition, flags)


## Toutes les clés de légende possibles (tests de données).
func all_caption_keys() -> PackedStringArray:
	var keys: PackedStringArray = []
	if not caption_key.is_empty():
		keys.append(caption_key)
	for c: ConditionalKey in captions:
		if c != null and not c.key.is_empty() and not keys.has(c.key):
			keys.append(c.key)
	return keys
