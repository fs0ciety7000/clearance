## Tutoriel diégétique du Jour 1 (UI_FLOW §7) : Okonkwo, Guichet 03, parle à
## l'intercom aux moments clés des quatre premiers passagers, puis se tait.
## Pas de pop-up : chaque réplique est émise par `spoke(speaker_key, text_key)`
## (la scène l'affiche en toast d'intercom + sous-titre). Une réplique n'est
## dite qu'une fois. Actif seulement si `day_number == ACTIVE_DAY`.
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

var active: bool = false
var said: Array[String] = []
var _case_index: int = -1


func _ready() -> void:
	EventBus.day_started.connect(_on_day_started)
	EventBus.day_phase_changed.connect(_on_phase)
	EventBus.case_presented.connect(_on_case_presented)
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_checked.connect(_on_checked)
	EventBus.case_resolved.connect(_on_resolved)
	EventBus.citation_issued.connect(_on_citation)


func _say(text_key: String) -> void:
	if not active or said.has(text_key):
		return
	said.append(text_key)
	spoke.emit(SPEAKER, text_key)


func _on_day_started(day: DayDef, _rulebook: Array[RulebookEntry]) -> void:
	active = day != null and day.day_number == ACTIVE_DAY
	said.clear()
	_case_index = -1


func _on_phase(phase: DayPhase.Kind, _case_id: StringName) -> void:
	if phase == DayPhase.Kind.WAITING_CASE and _case_index < 0:
		_say(LINE_OPEN)


func _on_case_presented(case: Case) -> void:
	_case_index = case.index if case != null else -1


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


func _on_resolved(_case_id: StringName, _result: CaseResult) -> void:
	if _case_index == LAST_GUIDED_INDEX:
		_say(LINE_GOODBYE)


func _on_citation(_reason_key: String) -> void:
	_say(LINE_CITATION)
