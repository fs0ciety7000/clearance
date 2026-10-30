## État d'une Garde de nuit en cours (M12 §2, B57 ; ARCHITECTURE §11.5) —
## logique pure, sans nœud : pilotée par le `DayController` (mode garde) ou
## par un simulateur (`balance_sim --garde`, lot B).
##
## Après chaque verdict, `after_case(result)` renvoie un pas
## (`{points, error, over, directive, tier_changed, events_started,
## events_ended, queued}`) : `queued` = changements de règles à mettre en
## attente (`RuleContext.queue_changes` / `queue_revert`) — ils prennent effet
## au passager suivant. Erreur = toute citation (M12 §8 q. 4) ; score = +1 par
## verdict sans citation (+ `score_per_correct` pendant une inspection EV-04).
class_name GardeRun
extends RefCounted

const END_ERRORS: StringName = &"errors"
const END_QUIT: StringName = &"quit"
## Directives précalculées par lot (le plan est une fonction pure de la graine).
const PLAN_CHUNK: int = 40

var def: GardeDef = null
var events_def: StationEventsDef = null
var code: String = ""
var kind: StringName = GardeService.KIND_FREE
var run_seed: int = 0
var version: int = 1
## Date de jeu (`GameDate`) tirée de la graine.
var game_date: int = 0
## Graine du flux des passagers (`CaseBuilder`).
var queue_seed: int = 0
var notices_seed: int = 0
var score: int = 0
## Passagers traités.
var passengers: int = 0
## Erreurs : `{passenger, case_id, verdict, expected, citation, rule_id, label}`.
var errors: Array[Dictionary] = []
## Directives tirées (numéro de la dernière).
var directives: int = 0
var active_units: Array[StringName] = []
var tier_index: int = 0
var ended: bool = false
var end_reason: StringName = &""
var started_msec: int = 0
var duration_sec: int = 0
## Événements de la garde (annoncés ou en cours).
var events: Array[StationEventPlan] = []
## Passager (1-based) au début duquel tombe le prochain événement.
var next_event_passenger: int = -1

var _plan: Array[Dictionary] = []
var _events_rng: SeededRng = null
## Changements différés d'un passager (rotation : ligne barrée puis oubliée).
var _deferred: Array[Dictionary] = []


func setup(p_def: GardeDef, p_code: String, p_kind: StringName, p_events: StationEventsDef = null) -> void:
	def = p_def
	events_def = p_events
	code = p_code
	kind = p_kind
	run_seed = GardeService.seed53(code)
	version = def.version
	game_date = GardeService.game_date_for(def, run_seed)
	queue_seed = GardeService.stream_seed(run_seed, &"queue")
	notices_seed = GardeService.stream_seed(run_seed, &"notices")
	_events_rng = SeededRng.new(GardeService.stream_seed(run_seed, &"events"))
	_plan = GardeService.directive_plan(def, run_seed, PLAN_CHUNK)
	next_event_passenger = _draw_first_event()
	var tier: GardeTierDef = def.tier_for(1)
	tier_index = tier.index if tier != null else 0
	started_msec = Time.get_ticks_msec()


## Directive n (1-based) du plan : `{number, unit_id, action}` ou vide.
func plan_entry(number: int) -> Dictionary:
	while number > _plan.size() and _plan.size() % PLAN_CHUNK == 0 and not _plan.is_empty():
		var longer: Array[Dictionary] = GardeService.directive_plan(def, run_seed, _plan.size() + PLAN_CHUNK)
		if longer.size() == _plan.size():
			break
		_plan = longer
	return _plan[number - 1] if number >= 1 and number <= _plan.size() else {}


## Prochaine directive due après ce nombre de passagers traités.
func directive_due() -> bool:
	return not ended and passengers > 0 and passengers % maxi(def.directive_every, 1) == 0


## Palier courant (passager suivant).
func current_tier() -> GardeTierDef:
	return def.tier_for(passengers + 1)


## Horloge cosmétique (22:00 + 6 min par passager), minutes depuis minuit
## (peut dépasser 24:00 : l'UI affiche modulo 24 h).
func clock_minute() -> int:
	return def.clock_start_minute + passengers * def.minutes_per_passenger


## L'aube est passée (`garde_dawn`, passager 80).
func is_dawn() -> bool:
	return passengers >= def.dawn_passenger


## Points d'un verdict juste (1, ou plus pendant une inspection EV-04).
func points_for_correct(ctx: RuleContext = null) -> int:
	return 1 + (ctx.modifier(RuleChangeDef.MOD_SCORE_PER_CORRECT) if ctx != null else 0)


## Résultat d'un passager : score, erreurs, fin, puis (si la garde continue)
## directive, palier, événements. `ctx` : contexte du shift (modificateurs).
func after_case(result: CaseResult, ctx: RuleContext = null) -> Dictionary:
	var step: Dictionary = {"points": 0, "error": false, "over": false, "directive": {}, "tier_changed": false,
			"events_started": [], "events_ended": [], "queued": []}
	if ended or result == null:
		return step
	passengers += 1
	if result.has_citation():
		errors.append({"passenger": passengers, "case_id": String(result.case_id),
				"verdict": SlippedItem.VERDICT_NAMES[result.verdict_kind],
				"expected": SlippedItem.VERDICT_NAMES[result.expected_verdict],
				"citation": result.citation_reason_key, "rule_id": String(result.citation_rule_id),
				"label": result.passenger_label, "violations": violation_refs(result)})
		step["error"] = true
	else:
		var points: int = points_for_correct(ctx)
		score += points
		step["points"] = points
	if errors.size() >= def.max_errors:
		_finish(END_ERRORS)
		step["over"] = true
		return step
	var queued: Array[Dictionary] = []
	# Changements différés (ligne barrée oubliée un passager plus tard).
	for row: Dictionary in _deferred:
		queued.append(row)
	_deferred.clear()
	# Fin des événements dont la fenêtre est passée.
	for plan: StationEventPlan in events:
		if plan.state == StationEventPlan.State.ACTIVE and plan.end_index >= 0 and passengers >= plan.end_index:
			plan.state = StationEventPlan.State.ENDED
			queued.append({"source": plan.source(), "revert": true})
			(step["events_ended"] as Array).append(plan)
	if directive_due():
		directives += 1
		var entry: Dictionary = plan_entry(directives)
		if not entry.is_empty():
			var changes: Array[RuleChangeDef] = GardeService.directive_changes(def, entry)
			var unit_id: StringName = entry["unit_id"]
			match StringName(entry["action"]):
				GardeService.ACTION_ADD, GardeService.ACTION_RESTORE:
					if not active_units.has(unit_id):
						active_units.append(unit_id)
				GardeService.ACTION_RETIRE:
					active_units.erase(unit_id)
					var forgets: Array[RuleChangeDef] = []
					var unit: GardeUnitDef = def.get_unit(unit_id)
					if unit != null:
						for rule_id: StringName in unit.rule_ids():
							forgets.append(RuleChangeDef.forget(rule_id))
					_deferred.append({"source": StringName("garde_forget_%d" % directives), "changes": forgets})
			var source: StringName = StringName("garde_dir_%d" % directives)
			queued.append({"source": source, "changes": changes})
			step["directive"] = {"number": directives, "unit_id": unit_id, "action": entry["action"],
					"unit": def.get_unit(unit_id), "source": source}
	var tier: GardeTierDef = current_tier()
	if tier != null and tier.index != tier_index:
		tier_index = tier.index
		step["tier_changed"] = true
	# Événement : jamais en même temps qu'un autre ni juste après une directive.
	if next_event_passenger > 0 and passengers + 1 >= next_event_passenger and not _event_running() \
			and _quiet_ok(passengers):
		var plan: StationEventPlan = _draw_event()
		if plan != null:
			plan.state = StationEventPlan.State.ACTIVE
			events.append(plan)
			queued.append({"source": plan.source(), "changes": plan.changes()})
			(step["events_started"] as Array).append(plan)
		next_event_passenger = passengers + 1 + _events_rng.randi_range(def.event_gap.x, def.event_gap.y)
	step["queued"] = queued
	return step


## « Terminer la garde » (pause, confirmée) : le score compte.
func quit() -> void:
	if not ended:
		_finish(END_QUIT)


func _finish(reason: StringName) -> void:
	ended = true
	end_reason = reason
	duration_sec = maxi(floori((Time.get_ticks_msec() - started_msec) / 1000.0), 0)


## Résumé pour le profil (`ProfileService.record_garde`) et l'écran de fin.
func to_record() -> Dictionary:
	return {
		"score": score,
		"seed_code": code,
		"kind": String(kind),
		"date": GardeService.daily_date(code) if kind == GardeService.KIND_DAILY else Time.get_date_string_from_system(true),
		"played_on": Time.get_date_string_from_system(true),
		"garde_version": version,
		"duration_sec": duration_sec,
		"directives": directives,
		"palier": tier_index,
		"passengers": passengers,
		"end_reason": String(end_reason),
		"errors": errors.duplicate(true),
		"clock_minute": clock_minute(),
	}


## Références des documents en cause d'une erreur (futur écran REVOIR) :
## violations manquées (approbation fautive, refus non motivé), sinon toutes
## les violations du cas ; `[{rule_id, reason_key, refs: ["document.champ"]}]`.
static func violation_refs(result: CaseResult) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if result == null:
		return rows
	var source: Array[Violation] = result.missed_violations if not result.missed_violations.is_empty() \
			else result.expected_violations
	for violation: Violation in source:
		if violation == null:
			continue
		var refs: Array[String] = []
		for ref: FieldRef in violation.refs:
			if ref != null:
				refs.append("%s.%s" % [ref.document_id, ref.field_id])
		rows.append({"rule_id": String(violation.rule_id), "reason_key": violation.reason_key, "refs": refs})
	return rows


func _event_running() -> bool:
	for plan: StationEventPlan in events:
		if plan.state == StationEventPlan.State.ACTIVE:
			return true
	return false


## Pas d'événement dans les `event_quiet_after_directive` passagers qui suivent
## une directive (le temps de lire la règle nouvelle).
func _quiet_ok(processed: int) -> bool:
	var every: int = maxi(def.directive_every, 1)
	return processed % every >= def.event_quiet_after_directive


func _draw_first_event() -> int:
	return _events_rng.randi_range(def.first_event_range.x, def.first_event_range.y)


## Événement tiré parmi ceux permis en Garde selon les unités actives.
func _draw_event() -> StationEventPlan:
	if events_def == null:
		return null
	var candidates: Array[StationEventDef] = []
	for event: StationEventDef in events_def.events:
		if event == null or not event.garde_allowed:
			continue
		if event.garde_required_unit != &"" and not active_units.has(event.garde_required_unit):
			continue
		candidates.append(event)
	if candidates.is_empty():
		return null
	var chosen: StationEventDef = candidates[_events_rng.randi_range(0, candidates.size() - 1)]
	return StationEventService.garde_plan(chosen, passengers, GardeService.stream_seed(run_seed, &"events"))
