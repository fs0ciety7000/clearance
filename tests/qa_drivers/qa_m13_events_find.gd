## QA M13 : graines de campagne dont le calendrier d'événements contient EV-05
## (portique hors tension, J8+) ou EV-09 (alerte des quais). Hors scène.
##   godot --headless --script res://tests/qa_drivers/qa_m13_events_find.gd
extends SceneTree
func _initialize() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var days: Dictionary[int, DayDef] = {}
	for n: int in range(1, 31):
		days[n] = data.get_day(n)
	var def: StationEventsDef = StationEventService.load_def()
	var ev09: int = 0
	for seed: int in range(1, 60):
		var plans: Dictionary[int, StationEventPlan] = StationEventService.schedule(seed, def, days)
		for n: int in plans:
			var p: StationEventPlan = plans[n]
			if p.event.id in [&"ev_05", &"ev_09"] and (p.event.id == &"ev_09" or n >= 8):
				if p.event.id == &"ev_09":
					ev09 += 1
				print("QA_EVT seed=%d J%d %s window=[%d,%d) clock=%d-%d profile=%s" % [seed, n, p.event.id, p.start_index, p.end_index,
						p.clock_from, p.clock_to, p.profile_label_key() if p.event.id == &"ev_09" else ""])
	print("QA_EVT ev_09 total sur 59 campagnes : %d" % ev09)
	quit(0)
