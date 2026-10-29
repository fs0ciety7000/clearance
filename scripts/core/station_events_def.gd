## Catalogue et calendrier des événements de station (M12 §3.3–§3.5, D-129 ;
## ARCHITECTURE §11.6) — `res://data/events/station_events.tres` (lot B).
class_name StationEventsDef
extends Resource

const CLASS_A: int = 1
const CLASS_B: int = 2

## Version des événements (`events_version`, `schedule`).
@export var version: int = 1
@export var events: Array[StationEventDef] = []
## Jours éligibles → classes permises (masque `CLASS_A | CLASS_B`).
@export var eligible_days: Dictionary[int, int] = {}
## Probabilité d'un événement par jour éligible.
@export_range(0.0, 1.0) var probability: float = 0.30
## Au plus n fois chaque type par campagne.
@export var max_per_type: int = 2
## Pas d'événement le lendemain d'un événement.
@export var no_consecutive_days: bool = true
## Compensation d'un événement de classe B : avertissements gratuits en plus.
@export var class_b_free_citations: int = 1


func get_event(event_id: StringName) -> StationEventDef:
	for event: StationEventDef in events:
		if event != null and event.id == event_id:
			return event
	return null
