## Garde de nuit « Endurance » (M12 §2, D-126 → D-128 ; ARCHITECTURE §11.5) —
## `res://data/garde/garde.tres` (lot B).
class_name GardeDef
extends Resource

## Version de la Garde (`garde_version`) : incrémentée à chaque changement du
## pool, des paliers ou du générateur ; records comparés à version égale.
@export var version: int = 1
## Gabarit du shift (`DayDef.mode = garde`, `untimed`, `economy_disabled`,
## `detain_enabled` faux (U11 l'ouvre), `faction_weights` TYC .25…, RuleSet du
## socle R01, R02, R03, R07, `passenger_count` = file maximale).
@export var day_template: DayDef = null
## Pool des unités (U01 → U20).
@export var units: Array[GardeUnitDef] = []
## Paliers, croissants (`from_passenger`).
@export var tiers: Array[GardeTierDef] = []
## Une directive tous les n passagers traités.
@export var directive_every: int = 5
## Erreurs (citations) avant la fin de garde.
@export var max_errors: int = 3
## Directive (1-based) à partir de laquelle chaque tier d'unité peut sortir :
## `[1, 4, 9]` = tier 1 dès la 1ʳᵉ, tier 2 dès la 4ᵉ, tier 3 dès la 9ᵉ.
@export var tier_unlock_directive: PackedInt32Array = PackedInt32Array([1, 4, 9])
## Date de jeu tirée de la graine (`GameDate`), bornes incluses (01.05 → 30.11.2187).
@export var date_min: int = 0
@export var date_max: int = 0
## Horloge cosmétique : début (22:00), minutes par passager, aube (passager 80).
@export var clock_start_minute: int = 22 * 60
@export var minutes_per_passenger: int = 6
@export var dawn_passenger: int = 80
## Événements : premier entre ces passagers (1-based, inclus), puis écart tiré
## dans `event_gap` ; jamais dans les `event_quiet_after_directive` passagers
## qui suivent une directive.
@export var first_event_range: Vector2i = Vector2i(16, 20)
@export var event_gap: Vector2i = Vector2i(12, 18)
@export var event_quiet_after_directive: int = 2
## Motif de la ligne barrée d'une unité retirée en rotation (palier 4).
@export var rotation_note_key: String = "rb_retired_quais"


func get_unit(unit_id: StringName) -> GardeUnitDef:
	for unit: GardeUnitDef in units:
		if unit != null and unit.id == unit_id:
			return unit
	return null


## Palier du passager `passenger` (1-based) ; null sans palier.
func tier_for(passenger: int) -> GardeTierDef:
	var found: GardeTierDef = null
	for tier: GardeTierDef in tiers:
		if tier != null and tier.from_passenger <= passenger:
			if found == null or tier.from_passenger >= found.from_passenger:
				found = tier
	return found
