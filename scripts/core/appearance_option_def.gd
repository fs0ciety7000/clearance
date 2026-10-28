## Option d'un slot d'apparence (ARCHITECTURE §5.2, BOOTH_SCENE §12.2).
##
## Le générateur ne lit **que** `id`, `weight`, `faction_weights` et `tags` ;
## les références visuelles sont lues par `AppearanceApplier` /
## `PortraitRenderer` (M4/M6). M3 : catalogue placeholder, références nulles.
class_name AppearanceOptionDef
extends Resource

@export var id: StringName = &""
## Poids relatif du tirage (0 = jamais tiré au hasard : visière, option imposée).
@export var weight: float = 1.0
## Multiplicateurs par origine (`FactionDef.id` → facteur ; absent = 1).
@export var faction_weights: Dictionary[StringName, float] = {}
## Étiquettes libres (ex. `"family:round_face"`).
@export var tags: PackedStringArray = []

@export_group("Visuel (M4+)")
@export var mesh: Mesh = null
@export var atlas_cell: int = -1
@export var material: Material = null
@export var portrait_layer: Texture2D = null


## Poids effectif pour une origine donnée.
func weight_for(faction_id: StringName) -> float:
	var factor: float = faction_weights.get(faction_id, 1.0)
	return weight * factor
