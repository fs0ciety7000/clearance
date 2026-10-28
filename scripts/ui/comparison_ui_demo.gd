## Démo autonome de l'interface de comparaison (M4) — sans booth 3D.
##
## Fabrique un jour réel (`CaseBuilder`, J3 par défaut) et **simule la
## logique** par l'`EventBus` : DayController (phases, horloge, file),
## BoothDirector (arrivée, documents, départ), InspectionSession
## (`DiscrepancyChecker`, réponses d'interrogatoire) et ScoringService (verdict
## comparé à la clé). Un scénario scripté rejoue arrivée → documents → Mode
## Inspection → discordance → concordance → interrogatoire → tampon, puis la
## démo reste jouable (N : passager suivant).
##
## Arguments utilisateur (`-- --day=1 --no-script --shots=7.5,9 --shot-dir=…`) :
## jour (1–3), scénario off, captures d'écran à des instants donnés (puis
## sortie). Les captures de référence se font avec `--write-movie`.
extends Control

const DAY_SEED: int = 20_871_315
const ARRIVAL_SEC: float = 1.8
const CHECK_DELAY: float = 0.25
const ANSWER_DELAY: float = 0.6
const DEPART_SEC: float = 1.6

var data: DataCatalog = null
var day: DayDef = null
var builder: CaseBuilder = null
var generated: GeneratedCase = null
var case_index: int = -1
var remaining: float = 0.0
var phase: DayPhase.Kind = DayPhase.Kind.INTRO
var scripted: bool = true

@onready var backdrop: DemoBoothBackdrop = %Backdrop
@onready var ui: ComparisonUI = %ComparisonUI

var _timeline: Array[Array] = []
var _time: float = 0.0
## Index du cas « vitrine » (permis expiré) préparé pour le scénario.
var _showcase: GeneratedCase = null
var _shots: Array[float] = []
var _shot_dir: String = "user://"


func _ready() -> void:
	RenderingServer.set_default_clear_color(DS.BG_VOID)
	var day_number: int = 3
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--day="):
			day_number = clampi(arg.trim_prefix("--day=").to_int(), 1, 3)
		elif arg == "--no-script":
			scripted = false
		elif arg.begins_with("--shots="):
			for part: String in arg.trim_prefix("--shots=").split(","):
				_shots.append(part.to_float())
		elif arg.begins_with("--shot-dir="):
			_shot_dir = arg.trim_prefix("--shot-dir=")
	data = DataCatalog.load_from()
	day = data.get_day(day_number)
	builder = CaseBuilder.new(data, day, DAY_SEED)
	_showcase = _find_showcase()
	ui.face_rect_provider = backdrop.face_rect
	EventBus.next_case_requested.connect(_on_next_case_requested)
	EventBus.discrepancy_check_requested.connect(_on_check_requested)
	EventBus.interrogation_requested.connect(_on_interrogation_requested)
	EventBus.verdict_stamped.connect(_on_verdict_stamped)
	EventBus.documents_presented.connect(_on_documents_presented)
	_start_day.call_deferred()
	if scripted:
		_build_timeline()


func _start_day() -> void:
	remaining = day.duration_sec * 0.62
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	_set_phase(DayPhase.Kind.WAITING_CASE)
	EventBus.day_clock_ticked.emit(remaining)


func _process(delta: float) -> void:
	_time += delta
	if phase != DayPhase.Kind.INTRO and phase != DayPhase.Kind.SUMMARY:
		remaining = maxf(remaining - delta, 0.0)
		EventBus.day_clock_ticked.emit(remaining)
	while not _timeline.is_empty() and _timeline[0][0] <= _time:
		var step: Array = _timeline.pop_front()
		var action: Callable = step[1]
		action.call()
	if not _shots.is_empty() and _time >= _shots[0]:
		var at: float = _shots.pop_front()
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(_shot_dir.path_join("shot_%05.2f.png" % at))
		if _shots.is_empty():
			get_tree().quit()


# ---------------------------------------------------------------------------
# Scénario scripté (captures)
# ---------------------------------------------------------------------------

func _build_timeline() -> void:
	_at(0.6, func() -> void: ui.request_next_case())
	_at(4.4, func() -> void: ui.set_inspection_active(true))
	_at(5.0, _pick_expiry)
	_at(5.6, func() -> void: ui.pick(FieldRef.today()))
	_at(8.0, _pick_name_on.bind(&"id_card"))
	_at(8.5, _pick_name_on.bind(&"entry_permit"))
	_at(9.9, func() -> void: ui.open_question_menu())
	_at(11.2, _ask_first_unlocked)
	_at(13.0, _hold_stamp.bind(VerdictKind.Kind.DENY, true))


func _at(time: float, action: Callable) -> void:
	_timeline.append([time, action])


func _pick_expiry() -> void:
	var refs: Array[FieldRef] = generated.case.find_refs_by_truth_path(&"document.expiry_date")
	var target: FieldRef = refs[0]
	for ref: FieldRef in refs:
		var expiry: int = generated.case.get_value(ref)
		if expiry < day.game_date:
			target = ref
	ui.pick(target)


func _pick_name_on(document_id: StringName) -> void:
	for ref: FieldRef in generated.case.find_refs_by_truth_path(&"family_name"):
		if ref.document_id == document_id:
			ui.pick(ref)


func _ask_first_unlocked() -> void:
	var topics: Array[StringName] = ui.available_topics()
	if not topics.is_empty():
		ui.ask(topics[0])


func _hold_stamp(kind: VerdictKind.Kind, pressed: bool) -> void:
	var button: StampButton = ui.get_stamp_button(kind)
	if pressed:
		button.begin_hold()
	else:
		button.end_hold()


## Cas d'au plus 11 passagers dont le permis d'entrée est expiré (Tycho de
## préférence) : l'exemple de la maquette.
func _find_showcase() -> GeneratedCase:
	var fallback: GeneratedCase = null
	for index: int in day.passenger_count:
		var candidate: GeneratedCase = builder.build_with(index, [AnomalyType.Kind.EXPIRED_DOCUMENT])
		if candidate == null or candidate.visor_down:
			continue
		var c: Case = candidate.case
		var permit: DocumentInstance = c.get_document(&"entry_permit")
		var expired_doc: StringName = &""
		for doc: DocumentInstance in c.documents:
			if doc.expiry_date < day.game_date:
				expired_doc = doc.get_document_id()
		if expired_doc == &"":
			continue
		if fallback == null:
			fallback = candidate
		if permit != null and expired_doc == &"entry_permit" and c.passenger_presented.faction_id == &"tyc":
			return candidate
	return fallback


# ---------------------------------------------------------------------------
# Simulation : DayController / BoothDirector / InspectionSession / Scoring
# ---------------------------------------------------------------------------

func _set_phase(p_phase: DayPhase.Kind) -> void:
	phase = p_phase
	EventBus.day_phase_changed.emit(p_phase, generated.case.case_id if generated != null else &"")


func _on_next_case_requested() -> void:
	if phase != DayPhase.Kind.WAITING_CASE:
		return
	case_index += 1
	if case_index >= day.passenger_count:
		_set_phase(DayPhase.Kind.SUMMARY)
		return
	generated = _showcase if case_index == 0 and _showcase != null else builder.build(case_index)
	EventBus.case_presented.emit(generated.case)
	_set_phase(DayPhase.Kind.ARRIVING)
	var walk: float = ARRIVAL_SEC * (0.3 if Settings.reduce_motion else 1.0)
	backdrop.walk_in(generated.case.passenger_presented.appearance, walk)
	var case_id: StringName = generated.case.case_id
	get_tree().create_timer(walk).timeout.connect(_on_arrived.bind(case_id))


func _on_arrived(case_id: StringName) -> void:
	if generated == null or generated.case.case_id != case_id:
		return
	EventBus.passenger_arrived.emit(case_id)
	_set_phase(DayPhase.Kind.INSPECTING)
	get_tree().create_timer(0.3).timeout.connect(_present_documents.bind(case_id))


func _present_documents(case_id: StringName) -> void:
	backdrop.flash_slot()
	EventBus.documents_presented.emit(case_id)


func _on_documents_presented(_case_id: StringName) -> void:
	pass


func _on_check_requested(a: FieldRef, b: FieldRef) -> void:
	var result: Discrepancy = DiscrepancyChecker.check(generated.case, a, b, builder.ctx)
	get_tree().create_timer(CHECK_DELAY).timeout.connect(EventBus.discrepancy_checked.emit.bind(result))


func _on_interrogation_requested(topic: StringName) -> void:
	var base: String = String(topic).get_slice(InterrogationTopics.DOC_SEPARATOR, 0)
	get_tree().create_timer(ANSWER_DELAY).timeout.connect(_answer.bind(topic, "ans_" + base))


func _answer(topic: StringName, line_key: String) -> void:
	if topic == InterrogationTopics.REMOVE_VISOR:
		generated.case.remove_visor()
		backdrop.actor.appearance = generated.case.passenger_presented.appearance
	EventBus.interrogation_answered.emit(topic, line_key)
	if InterrogationTopics.is_unlocked_topic(topic):
		get_tree().create_timer(1.6).timeout.connect(EventBus.passenger_reaction_triggered.emit.bind(PassengerReaction.Kind.NERVOUS))


func _on_verdict_stamped(verdict: Verdict) -> void:
	_set_phase(DayPhase.Kind.RESOLVING)
	var result: CaseResult = CaseResult.new(verdict.case_id)
	result.verdict = verdict
	result.verdict_kind = verdict.kind
	result.expected_verdict = generated.key.expected_verdict
	result.correct = verdict.kind == generated.key.expected_verdict
	result.credits_delta = day.credit_per_correct if result.correct else 0
	var case_id: StringName = verdict.case_id
	get_tree().create_timer(0.5).timeout.connect(_resolve.bind(case_id, result))


func _resolve(case_id: StringName, result: CaseResult) -> void:
	EventBus.case_resolved.emit(case_id, result)
	if result.credits_delta != 0:
		GameState.add_credits(result.credits_delta)
	_set_phase(DayPhase.Kind.DEPARTING)
	backdrop.flash_slot()
	backdrop.walk_out(result.verdict_kind == VerdictKind.Kind.APPROVE, DEPART_SEC)
	get_tree().create_timer(DEPART_SEC).timeout.connect(_departed.bind(case_id))


func _departed(case_id: StringName) -> void:
	EventBus.passenger_departed.emit(case_id)
	_set_phase(DayPhase.Kind.WAITING_CASE)
