## Tutoriel diégétique du Jour 1 (UI_FLOW §7) : Okonkwo, Guichet 03, parle à
## l'intercom aux moments clés des quatre premiers passagers, puis se tait.
## Pas de pop-up : chaque réplique est émise par `spoke(speaker_key, text_key)`
## (la scène l'affiche en toast d'intercom + sous-titre). Une réplique n'est
## dite qu'une fois. Actif seulement si `day_number == ACTIVE_DAY`.
## M13 (B68, ARCHITECTURE §12.7) : en plus, répliques **pilotées par les
## données** (`DayDef.intercom_lines`, `IntercomLineDef` : locuteur, clé,
## déclencheur, condition sur les drapeaux) pour tout jour : Okonkwo au J4 et
## au J8, Sato au J12… Conditions évaluées sur les drapeaux du matin
## (`GameState`, ou `flags` fournis si `use_game_state` est faux).
class_name OkonkwoIntercom
extends Node

signal spoke(speaker_key: String, text_key: String)

const ACTIVE_DAY: int = 1
const SPEAKER: String = "spk_okonkwo"
const LINE_OPEN: String = "okonkwo_j1_open"
const LINE_INSPECT: String = "okonkwo_j1_inspect"
const LINE_EXPIRY: String = "okonkwo_j1_expiry"
const LINE_DISCORDANCE: String = "okonkwo_j1_discordance"
const LINE_CONCORDANT: String = "okonkwo_j1_concordant"
const LINE_ALONE: String = "okonkwo_j1_alone"
const LINE_CITATION: String = "okonkwo_j1_citation"
const LINE_GOODBYE: String = "okonkwo_j1_goodbye"
## Index du dernier passager accompagné (passager 4 = premier refus autonome).
const LAST_GUIDED_INDEX: int = 3
## Raison du comparateur pour une puce vague (lot B, `Discrepancy`).
const REASON_STATEMENT_VAGUE: String = "disc_statement_vague"

var active: bool = false
var said: Array[String] = []
var _case_index: int = -1
## M13 : répliques de données du jour, et drapeaux pour leurs conditions.
var lines: Array[IntercomLineDef] = []
var flags: Dictionary[StringName, Variant] = {}
## Relit les drapeaux du `GameState` au début du shift (faux : `flags` fournis).
var use_game_state: bool = true
var _case: Case = null
var _data_said: Array[String] = []


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_phase)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_checked.connect(_on_checked)
	EventBus.case_resolved.connect(_on_resolved)
	EventBus.citation_issued.connect(_on_citation)
	EventBus.statement_given.connect(_on_statement_given)
	EventBus.search_opened.connect(_on_search_opened)
	EventBus.search_closed.connect(_on_search_closed)


func _say(text_key: String) -> void:
	if not active or said.has(text_key):
		return
	said.append(text_key)
	spoke.emit(SPEAKER, text_key)


func _on_day_started(day: DayDef, _rulebook: Array[RulebookEntry]) -> void:
	active = day != null and day.day_number == ACTIVE_DAY
	said.clear()
	_case_index = -1
	lines = day.intercom_lines.duplicate() if day != null else [] as Array[IntercomLineDef]
	_data_said.clear()
	_case = null
	if use_game_state:
		flags = GameState.narrative_flags.duplicate()


func _on_phase(phase: DayPhase.Kind, _case_id: StringName) -> void:
	if phase == DayPhase.Kind.WAITING_CASE and _case_index < 0:
		_say(LINE_OPEN)
		fire(IntercomLineDef.TRIGGER_SHIFT_OPEN)


func _on_case_presented(case: Case) -> void:
	_case_index = case.index if case != null else -1
	_case = case


## M13 : déclenche les répliques de données qui répondent à l'événement
## (`IntercomLineDef.matches`, condition, une fois par shift si `once`).
## Renvoie le nombre de répliques dites.
func fire(trigger: StringName, arg: StringName = &"") -> int:
	var count: int = 0
	for line: IntercomLineDef in lines:
		if line == null or not line.matches(trigger, arg):
			continue
		if line.once and _data_said.has(line.text_key):
			continue
		if not FlagCondition.check(line.condition, flags):
			continue
		_data_said.append(line.text_key)
		spoke.emit(line.speaker_key, line.text_key)
		count += 1
	return count


func _on_statement_given(_case_id: StringName, statements: Array[Statement]) -> void:
	for statement: Statement in statements:
		if statement != null:
			fire(IntercomLineDef.TRIGGER_STATEMENT_GIVEN, statement.id)


func _on_search_opened(_case_id: StringName, motive: StringName) -> void:
	fire(IntercomLineDef.TRIGGER_SEARCH_OPENED, motive if motive != &"" else IntercomLineDef.ARG_NO_MOTIVE)


func _on_search_closed(_case_id: StringName) -> void:
	if _case == null or _case.search_layout == null or _case.search_layout.scanned_zones.is_empty():
		return
	if _case.search_found_forbidden():
		fire(IntercomLineDef.TRIGGER_SEARCH_FOUND)
	else:
		fire(IntercomLineDef.TRIGGER_SEARCH_CLEAN)


func _on_documents_presented(_case_id: StringName) -> void:
	match _case_index:
		0:
			_say(LINE_INSPECT)
		1:
			_say(LINE_EXPIRY)
		2:
			_say(LINE_CONCORDANT)
		3:
			_say(LINE_ALONE)


func _on_checked(result: Discrepancy) -> void:
	if result != null and result.confirmed and _case_index <= LAST_GUIDED_INDEX:
		_say(LINE_DISCORDANCE)
	if result == null:
		return
	var on_statement: bool = (result.a != null and result.a.is_statement()) or (result.b != null and result.b.is_statement())
	if not on_statement:
		return
	if result.confirmed:
		fire(IntercomLineDef.TRIGGER_STATEMENT_PINNED)
	elif result.reason_key == REASON_STATEMENT_VAGUE:
		fire(IntercomLineDef.TRIGGER_STATEMENT_VAGUE)


func _on_resolved(_case_id: StringName, result: CaseResult) -> void:
	if _case_index == LAST_GUIDED_INDEX:
		_say(LINE_GOODBYE)
	if result != null and result.scripted_id != &"":
		var verdict: String = SlippedItem.VERDICT_NAMES[result.verdict_kind]
		fire(IntercomLineDef.TRIGGER_CASE_RESOLVED, StringName("%s:%s" % [result.scripted_id, verdict]))


func _on_citation(reason_key: String) -> void:
	_say(LINE_CITATION)
	fire(IntercomLineDef.TRIGGER_CITATION, StringName(reason_key))
