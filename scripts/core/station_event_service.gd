## Événements de station (M12 §3, D-129, B58 ; ARCHITECTURE §11.6) — service
## statique pur.
##
## `schedule()` : calendrier d'une campagne, **fonction pure** de la graine de
## campagne et des données (jamais sauvegardé ; reprendre un jour redonne le
## même événement). Par jour éligible, dans l'ordre : probabilité
## `StationEventsDef.probability`, pas d'événement le lendemain d'un
## événement, chaque type au plus `max_per_type` fois, type tiré uniformément
## parmi ceux dont la classe (jour « A seulement » ou « A+B »), les bornes de
## jour et la règle prérequise sont satisfaites **et** dont la fenêtre peut se
## placer entre les cas scénarisés (`place`). Classe B : `free_citations_bonus`.
class_name StationEventService
extends RefCounted

const DEF_PATH: String = "res://data/events/station_events.tres"
## Avance de l'annonce d'une fenêtre horaire (EV-08 : annonce à 12:30 pour 13:00).
const CLOCK_ANNOUNCE_LEAD_MIN: int = 30
## Durée moyenne d'un passager (s réelles) pour placer une fenêtre en secondes.
const SECONDS_PER_PASSENGER: float = 30.0

static var _def_cache: StationEventsDef = null


## Catalogue des données (`data/events/station_events.tres`), ou null.
static func load_def() -> StationEventsDef:
	if _def_cache == null and ResourceLoader.exists(DEF_PATH):
		_def_cache = load(DEF_PATH) as StationEventsDef
	return _def_cache


## Calendrier complet : jour → plan (jours sans événement absents).
static func schedule(campaign_seed: int, def: StationEventsDef, days: Dictionary[int, DayDef]) -> Dictionary[int, StationEventPlan]:
	var result: Dictionary[int, StationEventPlan] = {}
	if def == null:
		return result
	var counts: Dictionary[StringName, int] = {}
	var last_day: int = -100
	var numbers: Array = def.eligible_days.keys()
	numbers.sort()
	for value: Variant in numbers:
		var number: int = int(value)
		var day: DayDef = days.get(number, null)
		if day == null:
			continue
		if def.no_consecutive_days and number == last_day + 1:
			continue
		var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.day_seed(campaign_seed, number),
				"station_event_v%d" % def.version))
		if not rng.chance(def.probability):
			continue
		var classes: int = def.eligible_days[number]
		var candidates: Array[StationEventDef] = []
		for event: StationEventDef in def.events:
			if event == null or counts.get(event.id, 0) >= def.max_per_type:
				continue
			if not is_allowed_on(event, day, classes):
				continue
			if place(event, day, SeededRng.new(0)) == null:
				continue
			candidates.append(event)
		if candidates.is_empty():
			continue
		var chosen: StationEventDef = candidates[rng.randi_range(0, candidates.size() - 1)]
		var plan: StationEventPlan = place(chosen, day, rng)
		if plan == null:
			continue
		if chosen.is_class_b():
			plan.free_citations_bonus = def.class_b_free_citations
		result[number] = plan
		counts[chosen.id] = counts.get(chosen.id, 0) + 1
		last_day = number
	return result


## Plan du jour `day_number` (null sans événement).
static func plan_for_day(campaign_seed: int, def: StationEventsDef, days: Dictionary[int, DayDef],
		day_number: int) -> StationEventPlan:
	return schedule(campaign_seed, def, days).get(day_number, null)


## Classe permise ce jour, bornes de jour et règle prérequise active.
static func is_allowed_on(event: StationEventDef, day: DayDef, classes: int) -> bool:
	if (classes & int(event.event_class)) == 0:
		return false
	if event.day_min > 0 and day.day_number < event.day_min:
		return false
	if event.day_max > 0 and day.day_number > event.day_max:
		return false
	if event.required_rule_id != &"" and (day.rule_set == null or not day.rule_set.has_rule(event.required_rule_id)):
		return false
	return true


## Place la fenêtre d'un événement dans le jour, sans couvrir un cas
## scénarisé (D-129, règle 3) ; null si impossible.
static func place(event: StationEventDef, day: DayDef, rng: SeededRng) -> StationEventPlan:
	var scripted: PackedInt32Array = day.scripted_indices()
	var count: int = day.passenger_count
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = event
	plan.day_number = day.day_number
	plan.list_label = event.list_label
	plan.list_size = event.list_size
	var choices: Array[int] = []
	match event.window_kind:
		StationEventDef.WindowKind.PASSENGERS:
			var length: int = maxi(event.window_passengers, 1)
			for k: int in range(1, count):
				var start: int = k + event.start_delay
				if start + length <= count and not _hits(scripted, start, start + length):
					choices.append(k)
			if choices.is_empty():
				return null
			plan.announce_after = choices[rng.randi_range(0, choices.size() - 1)]
			plan.start_index = plan.announce_after + event.start_delay
			plan.end_index = plan.start_index + length
		StationEventDef.WindowKind.REST_OF_DAY:
			var last: int = scripted[scripted.size() - 1] if not scripted.is_empty() else -1
			for k: int in range(1, count):
				var start: int = k + event.start_delay
				if start > last and count - start >= 2:
					choices.append(k)
			if choices.is_empty():
				return null
			plan.announce_after = choices[rng.randi_range(0, choices.size() - 1)]
			plan.start_index = plan.announce_after + event.start_delay
			plan.end_index = -1
		StationEventDef.WindowKind.CLOCK:
			if event.clock_from < 0 or event.clock_to <= event.clock_from:
				return null
			plan.announce_after = -1
			plan.announce_minute = maxi(event.clock_from - CLOCK_ANNOUNCE_LEAD_MIN, DayDef.SHIFT_START_MIN)
			plan.clock_from = event.clock_from
			plan.clock_to = event.clock_to
			plan.start_index = 0
			plan.end_index = -1
		StationEventDef.WindowKind.SECONDS:
			var span: int = ceili(event.window_seconds / SECONDS_PER_PASSENGER) + 1
			for k: int in range(1, count - 1):
				if not _hits(scripted, k, mini(k + span, count)):
					choices.append(k)
			if choices.is_empty():
				return null
			plan.announce_after = choices[rng.randi_range(0, choices.size() - 1)]
			plan.start_index = plan.announce_after
			plan.end_index = -1
			plan.seconds = event.window_seconds
	return plan


## Plan d'un événement de Garde annoncé après `processed` passagers
## (`garde_window_passengers` passagers, à partir du suivant).
static func garde_plan(event: StationEventDef, processed: int) -> StationEventPlan:
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = event
	plan.garde = true
	plan.announce_after = processed
	plan.start_index = processed + event.start_delay
	plan.end_index = plan.start_index + maxi(event.garde_window_passengers, 1)
	plan.list_label = event.list_label
	plan.list_size = event.list_size
	return plan


## Vrai si un index scénarisé tombe dans [from, to).
static func _hits(scripted: PackedInt32Array, from: int, to: int) -> bool:
	for index: int in scripted:
		if index >= from and index < to:
			return true
	return false
