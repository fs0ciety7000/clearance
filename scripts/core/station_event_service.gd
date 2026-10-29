## Événements de station (M12 §3, D-129, B58 ; ARCHITECTURE §11.6) — service
## statique pur.
##
## `schedule()` : calendrier d'une campagne, **fonction pure** de la graine de
## campagne et des données (jamais sauvegardé ; reprendre un jour redonne le
## même événement). **Stratifié** (D-136) : un nombre cible d'événements est
## tiré entre `StationEventsDef.min_per_campaign` et `max_per_campaign`
## (uniforme : 3 à 6, moyenne 4,5) ; les jours éligibles présents sont coupés
## en autant de strates consécutives et un jour est tiré dans chaque strate ;
## une strate sans jour possible est rattrapée sur les jours restants. Un jour
## n'est retenu que si : pas le lendemain ni la veille d'un événement
## (`no_consecutive_days`), et au moins un type y est possible — au plus
## `max_per_type` fois, classe (jour « A seulement » ou « A+B »), bornes de
## jour, règle prérequise active, fenêtre plaçable entre les cas scénarisés
## (`place`). Le type est tiré uniformément parmi les possibles, avec la
## graine du jour (salée `station_event_v<version>`). Classe B :
## `free_citations_bonus`.
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
	var numbers: Array[int] = []
	for value: Variant in def.eligible_days.keys():
		if days.get(int(value), null) != null:
			numbers.append(int(value))
	numbers.sort()
	if numbers.is_empty():
		return result
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(campaign_seed, "station_event_count_v%d" % def.version))
	var target: int = target_count(def, rng, numbers.size())
	var counts: Dictionary[StringName, int] = {}
	var missed: int = 0
	for stratum: Array[int] in strata(numbers, target):
		var placed: bool = false
		for value: Variant in rng.shuffled(stratum):
			if _try_day(int(value), campaign_seed, def, days, counts, result):
				placed = true
				break
		if not placed:
			missed += 1
	if missed > 0:
		# Rattrapage : jours restants, dans un ordre tiré.
		var rest: Array = []
		for number: int in numbers:
			if not result.has(number):
				rest.append(number)
		for value: Variant in rng.shuffled(rest):
			if missed == 0:
				break
			if _try_day(int(value), campaign_seed, def, days, counts, result):
				missed -= 1
	var ordered: Dictionary[int, StationEventPlan] = {}
	var keys: Array = result.keys()
	keys.sort()
	for value: Variant in keys:
		ordered[int(value)] = result[int(value)]
	return ordered


## Nombre cible d'événements (D-136) : uniforme entre `min_per_campaign` et
## `max_per_campaign`, borné par les jours disponibles (un sur deux au plus
## sans jours consécutifs).
static func target_count(def: StationEventsDef, rng: SeededRng, available: int) -> int:
	var low: int = maxi(def.min_per_campaign, 0)
	var high: int = maxi(def.max_per_campaign, low)
	var cap: int = (available + 1) / 2 if def.no_consecutive_days else available
	return mini(rng.randi_range(low, high), cap)


## `numbers` (croissants) coupés en `count` strates consécutives de tailles
## égales à un jour près.
static func strata(numbers: Array[int], count: int) -> Array[Array]:
	var result: Array[Array] = []
	var size: int = numbers.size()
	if count <= 0 or size == 0:
		return result
	count = mini(count, size)
	for k: int in count:
		var stratum: Array[int] = []
		for i: int in range(k * size / count, (k + 1) * size / count):
			stratum.append(numbers[i])
		result.append(stratum)
	return result


## Tente un événement le jour `number` (contraintes de `schedule`) ; vrai si posé.
static func _try_day(number: int, campaign_seed: int, def: StationEventsDef, days: Dictionary[int, DayDef],
		counts: Dictionary[StringName, int], result: Dictionary[int, StationEventPlan]) -> bool:
	if result.has(number):
		return false
	if def.no_consecutive_days and (result.has(number - 1) or result.has(number + 1)):
		return false
	var day: DayDef = days.get(number, null)
	if day == null:
		return false
	var classes: int = def.eligible_days.get(number, 0)
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
		return false
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.day_seed(campaign_seed, number),
			"station_event_v%d" % def.version))
	var chosen: StationEventDef = candidates[rng.randi_range(0, candidates.size() - 1)]
	var plan: StationEventPlan = place(chosen, day, rng)
	if plan == null:
		return false
	if chosen.is_class_b():
		plan.free_citations_bonus = def.class_b_free_citations
	result[number] = plan
	counts[chosen.id] = counts.get(chosen.id, 0) + 1
	return true


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
