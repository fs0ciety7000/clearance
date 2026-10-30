## Session d'inspection d'un cas (ARCHITECTURE §8) — service de jour, M4 minimal.
##
## - Mode Inspection : `discrepancy_check_requested(a, b)` →
##   `DiscrepancyChecker.check()` → `discrepancy_checked(result)` ; les
##   discordances confirmées sont mémorisées (preuves du verdict).
## - Interrogatoire minimal (`interrogation_requested(topic)`, sujets de
##   `InterrogationTopics` côté UI) : `purpose` / `stay` / `origin` (réponse
##   tirée de ce que *dit* le passager présenté), `remove_visor` (D-021),
##   `about_<raison>[:<doc>]` = confrontation à une discordance confirmée
##   (NERVOUS si elle a bien été constatée, ANGRY sinon), `confront` (générique).
##   La réplique dépend de la **famille** de la discordance (visage, N° ID, nom,
##   naissance, validité, document manquant, émetteur, origine, santé, autre ;
##   `family_of()`) : `line_about_<famille>_<n>` si elle est constatée (gêne,
##   excuse plausible ou mensonge), `line_about_<famille>_outrage_<n>` sinon
##   (indignation). Variante tirée de la graine du cas (déterministe).
## - Réactions du passager (`passenger_reaction_triggered`) : comparaison de
##   visages discordante, confrontation, verdict. Elles ne dépendent **jamais**
##   de la vérité cachée (`CaseKey`), seulement de ce que le joueur a constaté.
## - `remove_visor` : `LINE_VISOR_NONE` s'il n'y a rien à retirer, sinon la
##   réplique de retrait (`<dialogue_id>_visor` ou `LINE_VISOR_REMOVED`) — tout
##   autre `line_key` que `LINE_VISOR_NONE` signifie « visière retirée ».
## - M5 : répliques des passagers scénarisés — si le cas porte une étiquette de
##   dialogue (`ScriptedCaseDef.dialogue_id`) et que la clé
##   `<dialogue_id>_<sujet>` existe dans `fr.csv`, elle remplace la réplique
##   générique (`sc02_hurried_mother_about_expired`…). Une réplique de
##   supplication déclenche NERVOUS.
## - M7 : `about_envelope` (« Qu'est-ce que c'est que ça ? », si une enveloppe a
##   été glissée), `luciole_reply` (« La pluie ne tombe que vers le bas. »,
##   seulement si `luciole_reply_allowed` : étiquette `luciole_password` et
##   `lucioles_trust ≥ 2`, posé par le DayController ; mémorisé dans
##   `luciole_replied`) ; familles `implant`, `wanted` ; `exit_line_key()` pour
##   la dernière réplique au départ.
## Acte II : répliques conditionnelles (`Case.line_overrides`, prioritaires),
## familles `quota` (paire Compteur ↔ R23), `curfew`, `revoked`, `contract`
## (`line_about_<famille>_generic`, docs/ACT2.md §4.0, §7.2).
## M13 (ARCHITECTURE §12.5) : **déclarations** — une question porteuse de
## puces (`purpose`, `stay`, `origin`) répond par le cadre du cas
## (`Case.statement_frames`) ou la réplique scénarisée, marque ses
## déclarations obtenues (`Statement.given`) et émet `statement_given` ;
## `cargo` (« Quelque chose à déclarer ? ») ; confrontations `about_statement`,
## `about_contraband`, `about_weapon`, `about_concealed_implant` ; question de
## base ou confrontation réelle répétée → même réponse + ANGRY. **Coûts en temps** en données
## (`InterrogationTiming`, AG-01) annoncés par `inspection_busy` (indicatif :
## la logique n'ignore pas une question pendant ce temps ; l'UI se bloque).
## **Fouille** (`search`, J8+, R44 active) : motif MF-1 → MF-5 calculé et
## **figé à la demande** (`compute_search_motive`, jamais `CaseKey`),
## confirmation si aucun motif (`search_confirmation_required`), activation
## puis zones scannées après leur durée (`advance`), `search_opened`,
## `search_zone_scanned`, `search_closed` ; le verdict reçoit `search_done`,
## `search_motive`, `zones_scanned`. Le passager ne refuse jamais (D-145).
## Ne connaît pas la clé de réponse ; le DayController la garde.
class_name InspectionSession
extends Node

## Sujets d'interrogatoire reconnus en M4 (le Scénariste les étend en M5).
const TOPIC_REMOVE_VISOR: StringName = &"remove_visor"
const TOPIC_CONFRONT: StringName = &"confront"
const TOPIC_PURPOSE: StringName = &"purpose"
const TOPIC_STAY: StringName = &"stay"
const TOPIC_ORIGIN: StringName = &"origin"
## M7 (NARRATIVE §4.0).
const TOPIC_ABOUT_ENVELOPE: StringName = &"about_envelope"
const TOPIC_LUCIOLE_REPLY: StringName = &"luciole_reply"
const LINE_ABOUT_ENVELOPE: String = "line_about_envelope_generic"
const LINE_LUCIOLE_REPLY: String = "line_luciole_reply_generic"
const LINE_EXIT_DETAIN: String = "line_exit_detain_generic"
## M13 (ARCHITECTURE §12.5).
const TOPIC_CARGO: StringName = &"cargo"
const TOPIC_SEARCH: StringName = &"search"
const TOPIC_ABOUT_STATEMENT: StringName = &"about_statement"
const TOPIC_ABOUT_CONTRABAND: StringName = &"about_contraband"
## Questions de base (coût `question_sec`, ANGRY si répétées).
const BASE_TOPICS: Array[StringName] = [TOPIC_PURPOSE, TOPIC_STAY, TOPIC_ORIGIN, TOPIC_CARGO]
const LINE_CARGO_DEFAULT: String = "line_cargo_none_1"
const LINE_SEARCH_COMPLY_PREFIX: String = "line_search_comply_"
const LINE_SEARCH_PROTEST_PREFIX: String = "line_search_protest_"
const LINE_SEARCH_CLEAN_PREFIX: String = "line_search_clean_"
## Demandes de `search_requested` autres que les zones.
const SEARCH_CONFIRM: StringName = &"confirm"
const SEARCH_CANCEL: StringName = &"cancel"
const SEARCH_CLOSE: StringName = &"close"
## Actions de `inspection_busy`.
const BUSY_QUESTION: StringName = &"question"
const BUSY_CONFRONT: StringName = &"confront"
const BUSY_REPEAT: StringName = &"repeat"
const BUSY_SEARCH_ACTIVATION: StringName = &"search_activation"
## Zone en cours : l'action émise est `search_zone:<zone>` (`search_zone:z2`) ;
## `busy_kind()` / `busy_zone()` la décomposent.
const BUSY_SEARCH_ZONE: StringName = &"search_zone"
const BUSY_SEPARATOR: String = ":"
## Paramètre de surcharge de R44 posé par EV-09 (« fouille autorisée », MF-4).
const PARAM_SEARCH_AUTHORIZED: StringName = &"search_authorized"

## État de la fouille dans la session.
enum SearchState { IDLE, AWAITING_CONFIRM, ACTIVATING, OPEN, CLOSED }
const ABOUT_PREFIX: String = "about_"
const DOC_SEPARATOR: String = ":"
## Au-delà, la réponse « séjour » est longue.
const SHORT_STAY_DAYS: int = 7
## Répliques (clés de traduction, sous-titrées par l'UI).
const LINE_VISOR_REMOVED: String = "line_visor_removed"
const LINE_VISOR_NONE: String = "line_visor_none"
const LINE_CONFRONT_NERVOUS: String = "line_confront_nervous"
const LINE_CONFRONT_ANGRY: String = "line_confront_angry"
const LINE_GENERIC_SHRUG: String = "line_generic_shrug"
const LINE_PURPOSE_PREFIX: String = "line_purpose_"
const LINE_STAY_SHORT: String = "line_stay_short"
const LINE_STAY_LONG: String = "line_stay_long"
const LINE_ORIGIN_PREFIX: String = "line_origin_"
const LINE_ABOUT_PREFIX: String = "line_about_"
const LINE_OUTRAGE_INFIX: String = "outrage_"
## Variantes cherchées par famille (`_1` … `_MAX_VARIANTS`).
const MAX_VARIANTS: int = 6
## Familles de discordance (suffixes des répliques `line_about_<famille>_…`).
const FAMILY_FACE: String = "face"
const FAMILY_ID_NUMBER: String = "id_number"
const FAMILY_NAME: String = "name"
const FAMILY_BIRTH: String = "birth"
const FAMILY_VALIDITY: String = "validity"
const FAMILY_MISSING: String = "missing"
const FAMILY_ISSUER: String = "issuer"
const FAMILY_ORIGIN: String = "origin"
const FAMILY_HEALTH: String = "health"
const FAMILY_OTHER: String = "other"
const FAMILY_IMPLANT: String = "implant"
const FAMILY_WANTED: String = "wanted"
## Acte II.
const FAMILY_QUOTA: String = "quota"
const FAMILY_CURFEW: String = "curfew"
const FAMILY_REVOKED: String = "revoked"
const FAMILY_CONTRACT: String = "contract"
## Acte III.
const FAMILY_SPONSOR: String = "sponsor"
const FAMILY_SUMMONS: String = "summons"
const FAMILY_LOCKOUT: String = "lockout"
## M13 : déclaration contradictoire (variantes `line_about_statement_<n>` et
## `_outrage_<n>`), objet interdit, arme (`line_about_weapon_generic`),
## implant dissimulé trouvé (`line_about_concealed_implant_<n>`).
const FAMILY_STATEMENT: String = "statement"
const FAMILY_CONTRABAND: String = "contraband"
const FAMILY_WEAPON: String = "weapon"
const FAMILY_CONCEALED_IMPLANT: String = "concealed_implant"
## Familles M13 à variantes (hors `FAMILIES`, testées par le lot B avec les textes).
const M13_FAMILIES: Array[String] = [FAMILY_STATEMENT, FAMILY_CONTRABAND, FAMILY_CONCEALED_IMPLANT]
const FAMILIES: Array[String] = [FAMILY_FACE, FAMILY_ID_NUMBER, FAMILY_NAME, FAMILY_BIRTH, FAMILY_VALIDITY,
		FAMILY_MISSING, FAMILY_ISSUER, FAMILY_ORIGIN, FAMILY_HEALTH, FAMILY_OTHER]
## M7 : familles à réplique unique (`line_about_<famille>_generic`, NARRATIVE
## §7.3) ; l'indignation (non constatée) reprend la famille « autre ».
const GENERIC_FAMILIES: Array[String] = [FAMILY_IMPLANT, FAMILY_WANTED, FAMILY_QUOTA, FAMILY_CURFEW,
		FAMILY_REVOKED, FAMILY_CONTRACT, FAMILY_SPONSOR, FAMILY_SUMMONS, FAMILY_LOCKOUT, FAMILY_WEAPON]
## Familles débloquant un sujet `about_<famille>` sans document.
const RULE_FAMILIES: Array[String] = [FAMILY_QUOTA, FAMILY_CURFEW, FAMILY_REVOKED, FAMILY_CONTRACT, FAMILY_SPONSOR,
		FAMILY_SUMMONS, FAMILY_LOCKOUT]
## M13 : familles débloquant `about_<famille>[:<doc>]` (le document filtre).
const DOC_FAMILIES: Array[String] = [FAMILY_STATEMENT, FAMILY_CONTRABAND, FAMILY_WEAPON, FAMILY_CONCEALED_IMPLANT]
## `truth_path` d'un champ → famille de réplique.
const TRUTH_PATH_FAMILIES: Dictionary[StringName, String] = {
	&"appearance": FAMILY_FACE,
	&"citizen_id": FAMILY_ID_NUMBER,
	&"document.serial": FAMILY_ID_NUMBER,
	&"family_name": FAMILY_NAME,
	&"given_name": FAMILY_NAME,
	&"birth_date": FAMILY_BIRTH,
	&"document.expiry_date": FAMILY_VALIDITY,
	&"document.issue_date": FAMILY_VALIDITY,
	&"document.issuer_id": FAMILY_ISSUER,
	&"faction_id": FAMILY_ORIGIN,
	&"health_status": FAMILY_HEALTH,
	&"implants": FAMILY_IMPLANT,
	&"document.mrz": FAMILY_ID_NUMBER,
	&"document.seal_id": FAMILY_ISSUER,
	# Acte III.
	&"sponsor_id": FAMILY_SPONSOR,
	&"summons_id": FAMILY_SUMMONS,
	# Acte II.
	&"document.presented_at": FAMILY_CURFEW,
	&"employer_code": FAMILY_CONTRACT,
	&"firmware_date": FAMILY_VALIDITY,
}

var case: Case = null
var ctx: RuleContext = null
var active: bool = false
var inspection_mode: bool = false
## Temps depuis `documents_presented` (vaut 0 avant).
var elapsed_sec: float = 0.0
var documents_presented: bool = false
var confirmed: Array[Discrepancy] = []
var questions_asked: Array[StringName] = []
## M7 : la réponse à la phrase de passe est proposée (posé par le DayController).
var luciole_reply_allowed: bool = false
## M7 : le joueur a répondu à la phrase de passe pendant ce cas.
var luciole_replied: bool = false

# --- M13 ----------------------------------------------------------------------
## Coûts en temps (posés par le DayController : `EconomyDef.get_interrogation_timing()`).
var timing: InterrogationTiming = InterrogationTiming.new()
## AG-01 Hygiaphone neuf (questions plus courtes) ; AG-03 Portique calibré PH-2.
var hygiaphone: bool = false
var calibrated_gate: bool = false
## Temps d'interface occupée restant (indicatif, `inspection_busy`).
var busy_remaining_sec: float = 0.0
var search_state: SearchState = SearchState.IDLE
## Une fouille a été engagée dans ce cas (motif présent ou confirmé).
var search_done: bool = false
## Motif figé à la première demande (`SearchLayout.MOTIVE_*`, `&""` = aucun).
var search_motive: StringName = &""
## Zones scannées (ordre du scan).
var zones_scanned: Array[StringName] = []
## La réplique de trouvaille a été dite (une fois par cas).
var search_found_said: bool = false
## Réponses des confrontations réelles déjà obtenues (sujet → réplique).
var _real_answers: Dictionary[StringName, String] = {}
var _activation_left: float = 0.0
var _zone_queue: Array[StringName] = []
var _zone_costs: Array[float] = []
var _current_zone: StringName = &""
var _zone_left: float = 0.0


func _ready() -> void:
	EventBus.documents_presented.connect(_on_documents_presented)
	EventBus.discrepancy_check_requested.connect(_on_discrepancy_check_requested)
	EventBus.interrogation_requested.connect(_on_interrogation_requested)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)
	EventBus.search_requested.connect(_on_search_requested)


## Démarre l'inspection d'un nouveau cas (appelé par le DayController).
func begin(p_case: Case, p_ctx: RuleContext) -> void:
	case = p_case
	ctx = p_ctx
	active = true
	elapsed_sec = 0.0
	documents_presented = false
	confirmed.clear()
	questions_asked.clear()
	luciole_reply_allowed = false
	luciole_replied = false
	busy_remaining_sec = 0.0
	search_state = SearchState.IDLE
	search_done = false
	search_motive = &""
	zones_scanned.clear()
	search_found_said = false
	_real_answers.clear()
	_activation_left = 0.0
	_zone_queue.clear()
	_zone_costs.clear()
	_current_zone = &""
	_zone_left = 0.0


## M13 : coûts en temps et améliorations possédées (drapeaux du matin `upg_*`).
func configure(p_timing: InterrogationTiming, flags: Dictionary[StringName, Variant]) -> void:
	timing = p_timing if p_timing != null else InterrogationTiming.new()
	hygiaphone = UpgradeDef.owns(flags, UpgradeDef.ID_HYGIAPHONE)
	calibrated_gate = UpgradeDef.owns(flags, UpgradeDef.ID_CALIBRATED_GATE)


## Termine la session au tampon : complète le verdict (preuves, questions,
## durée) et déclenche la réaction de sortie.
func end(verdict: Verdict) -> void:
	if verdict != null:
		if verdict.flagged.is_empty():
			verdict.flagged = confirmed.duplicate()
		if verdict.questions_asked.is_empty():
			verdict.questions_asked = questions_asked.duplicate()
		if verdict.elapsed_sec <= 0.0:
			verdict.elapsed_sec = elapsed_sec
		if search_done:
			verdict.search_done = true
			verdict.search_motive = search_motive
			verdict.zones_scanned = zones_scanned.duplicate()
		EventBus.passenger_reaction_triggered.emit(reaction_for_verdict(verdict.kind))
	if search_state == SearchState.ACTIVATING or search_state == SearchState.OPEN:
		_close_search(false)
	active = false


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if active and documents_presented:
		elapsed_sec += delta
	if not active:
		return
	busy_remaining_sec = maxf(busy_remaining_sec - delta, 0.0)
	_advance_search(delta)


static func reaction_for_verdict(kind: VerdictKind.Kind) -> PassengerReaction.Kind:
	match kind:
		VerdictKind.Kind.APPROVE:
			return PassengerReaction.Kind.RELIEVED
		VerdictKind.Kind.DETAIN:
			return PassengerReaction.Kind.NERVOUS
	return PassengerReaction.Kind.ANGRY


func _on_documents_presented(case_id: StringName) -> void:
	if active and case != null and case_id == case.case_id:
		documents_presented = true


func _on_inspection_mode_changed(enabled: bool) -> void:
	inspection_mode = enabled


func _on_discrepancy_check_requested(a: FieldRef, b: FieldRef) -> void:
	if not active or case == null:
		return
	var result: Discrepancy = DiscrepancyChecker.check(case, a, b, ctx)
	if result.confirmed and not _already_confirmed(result):
		confirmed.append(result)
	EventBus.discrepancy_checked.emit(result)
	# Visage ↔ photo discordant : le passager se sait observé (UI_FLOW §4.9).
	if result.confirmed and (a.is_passenger_face() or b.is_passenger_face()):
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)


func _on_interrogation_requested(topic: StringName) -> void:
	if not active or case == null or not documents_presented:
		return
	if topic == TOPIC_SEARCH:
		_request_search()
		return
	var repeated: bool = questions_asked.has(topic)
	if not repeated:
		questions_asked.append(topic)
	if repeated and BASE_TOPICS.has(topic):
		# M13 §1.10 : question répétée — même réponse, ANGRY, 2 s.
		_answer_base(topic, true)
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
		return
	match topic:
		TOPIC_REMOVE_VISOR:
			# Le cas est muté avant la réponse : le booth relit l'apparence.
			var removed: bool = case.remove_visor()
			# Passager scénarisé : sa réplique (`<dialogue_id>_visor`, ex. `sc04_mira_visor`).
			EventBus.interrogation_answered.emit(topic, scripted_line("visor", LINE_VISOR_REMOVED) if removed else LINE_VISOR_NONE)
		TOPIC_CONFRONT:
			if confirmed.is_empty():
				EventBus.interrogation_answered.emit(topic, LINE_CONFRONT_ANGRY)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
			else:
				_answer_confrontation(topic, scripted_line("confront", LINE_CONFRONT_NERVOUS))
		TOPIC_PURPOSE, TOPIC_STAY, TOPIC_ORIGIN, TOPIC_CARGO:
			_answer_base(topic, false)
		TOPIC_ABOUT_ENVELOPE:
			if case.has_envelope():
				EventBus.interrogation_answered.emit(topic, scripted_line("about_envelope", LINE_ABOUT_ENVELOPE))
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
			else:
				EventBus.interrogation_answered.emit(topic, LINE_GENERIC_SHRUG)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG)
		TOPIC_LUCIOLE_REPLY:
			if luciole_reply_allowed:
				luciole_replied = true
				EventBus.interrogation_answered.emit(topic, scripted_line("luciole_reply", LINE_LUCIOLE_REPLY))
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.RELIEVED)
			else:
				EventBus.interrogation_answered.emit(topic, LINE_GENERIC_SHRUG)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG)
		_:
			if String(topic).begins_with(ABOUT_PREFIX):
				_confront_about(topic)
				return
			else:
				EventBus.interrogation_answered.emit(topic, LINE_GENERIC_SHRUG)
				EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG)
	if topic == TOPIC_CONFRONT:
		if confirmed.is_empty():
			_busy(timing.confront_cost(hygiaphone), BUSY_CONFRONT)
	elif not BASE_TOPICS.has(topic):
		_busy(timing.other_cost(hygiaphone), BUSY_QUESTION)


## M13 : confrontation **réelle** (discordance constatée) — réplique + NERVOUS
## la première fois ; ensuite même réplique + ANGRY (question répétée, 2 s).
func _answer_confrontation(topic: StringName, line: String) -> void:
	if _real_answers.has(topic):
		EventBus.interrogation_answered.emit(topic, _real_answers[topic])
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
		_busy(timing.confront_cost(hygiaphone, true), BUSY_REPEAT)
		return
	_real_answers[topic] = line
	EventBus.interrogation_answered.emit(topic, line)
	EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)
	_busy(timing.confront_cost(hygiaphone), BUSY_CONFRONT)


## Question de base : réplique (scénarisée, cadre de déclarations, ou
## générique), puces obtenues (`statement_given`), coût en temps.
func _answer_base(topic: StringName, repeated: bool) -> void:
	var line: String = ""
	match topic:
		TOPIC_PURPOSE:
			line = LINE_PURPOSE_PREFIX + String(case.passenger_presented.purpose)
		TOPIC_STAY:
			var short: bool = case.passenger_presented.stay_days <= SHORT_STAY_DAYS
			line = LINE_STAY_SHORT if short else LINE_STAY_LONG
		TOPIC_ORIGIN:
			line = LINE_ORIGIN_PREFIX + String(case.passenger_presented.faction_id)
		TOPIC_CARGO:
			line = case.cargo_line_key if not case.cargo_line_key.is_empty() else LINE_CARGO_DEFAULT
	var given: Array[Statement] = case.statements_for_question(topic)
	if not given.is_empty() and case.statement_frames.has(topic):
		line = case.statement_frames[topic]
	EventBus.interrogation_answered.emit(topic, scripted_line(String(topic), line))
	var corrected: bool = false
	for statement: Statement in given:
		statement.given = true
		corrected = corrected or statement.is_corrected()
	if not given.is_empty():
		EventBus.statement_given.emit(case.case_id, given)
	_busy(timing.question_cost(hygiaphone, repeated, corrected), BUSY_REPEAT if repeated else BUSY_QUESTION)


## Annonce une interface occupée (`inspection_busy`, indicatif).
## Action `inspection_busy` d'une zone scannée : `search_zone:<zone>`.
static func busy_zone_action(zone: StringName) -> StringName:
	return StringName("%s%s%s" % [BUSY_SEARCH_ZONE, BUSY_SEPARATOR, zone])


## Type d'une action `inspection_busy` (`search_zone:z2` → `search_zone`).
static func busy_kind(action: StringName) -> StringName:
	return StringName(String(action).get_slice(BUSY_SEPARATOR, 0))


## Zone d'une action `search_zone:<zone>`, `&""` sinon.
static func busy_zone(action: StringName) -> StringName:
	var text: String = String(action)
	return StringName(text.get_slice(BUSY_SEPARATOR, 1)) if text.contains(BUSY_SEPARATOR) else &""


func _busy(duration: float, action: StringName) -> void:
	if duration <= 0.0 or case == null:
		return
	busy_remaining_sec = maxf(busy_remaining_sec, duration)
	EventBus.inspection_busy.emit(case.case_id, duration, action)


# --- Fouille (M13, B70) ---------------------------------------------------------

## Vrai si la fouille est disponible pour ce passager : R44 (procédure
## `search_cause`) active dans le RuleSet du shift (J8+ ; retirée par EV-05).
func search_available() -> bool:
	return _search_rule() != null


func _search_rule() -> ProcedureRule:
	if ctx == null or ctx.rule_set == null:
		return null
	for rule: Rule in ctx.rule_set.rules:
		var procedure: ProcedureRule = rule as ProcedureRule
		if procedure != null and procedure.procedure_id == ProcedureRule.PROCEDURE_SEARCH_CAUSE:
			return procedure
	return null


## Motif de fouille **visible** à cet instant (MF-1 → MF-5, premier trouvé),
## `&""` sans motif. Ne lit jamais `CaseKey` : discordances confirmées de la
## session, indices du cas, réponse évasive obtenue, directive (EV-09 :
## surcharge `search_authorized` de R44 ; briefing : `DayDef`), R47.
func compute_search_motive() -> StringName:
	if case == null:
		return SearchLayout.MOTIVE_NONE
	return search_motive_for(case, ctx, confirmed, questions_asked)


static func search_motive_for(p_case: Case, p_ctx: RuleContext, p_confirmed: Array[Discrepancy],
		asked: Array[StringName]) -> StringName:
	if p_case == null:
		return SearchLayout.MOTIVE_NONE
	for d: Discrepancy in p_confirmed:
		if d != null and d.confirmed:
			return SearchLayout.MOTIVE_DISCORD
	if not p_case.search_cues.is_empty():
		return SearchLayout.MOTIVE_CUE
	if asked.has(TOPIC_CARGO) and p_case.cargo_reply == Case.CARGO_EVASIVE:
		return SearchLayout.MOTIVE_EVASIVE
	if p_ctx != null and p_ctx.rule_set != null:
		for rule: Rule in p_ctx.rule_set.rules:
			var procedure: ProcedureRule = rule as ProcedureRule
			if procedure == null:
				continue
			if procedure.procedure_id == ProcedureRule.PROCEDURE_SEARCH_CAUSE \
					and p_ctx.param(procedure.id, PARAM_SEARCH_AUTHORIZED, false, p_case) == true:
				return SearchLayout.MOTIVE_DIRECTIVE
		if p_ctx.day_def != null and p_ctx.day_def.search_directive_covers(p_case):
			return SearchLayout.MOTIVE_DIRECTIVE
		for rule: Rule in p_ctx.rule_set.rules:
			var procedure: ProcedureRule = rule as ProcedureRule
			if procedure != null and procedure.requires_search(p_case):
				return SearchLayout.MOTIVE_MANDATORY
	return SearchLayout.MOTIVE_NONE


func _request_search() -> void:
	if not search_available():
		EventBus.interrogation_answered.emit(TOPIC_SEARCH, LINE_GENERIC_SHRUG)
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.SHRUG)
		return
	match search_state:
		SearchState.ACTIVATING, SearchState.OPEN, SearchState.AWAITING_CONFIRM:
			return
		SearchState.CLOSED:
			# Réouverture : même motif, nouvelle activation.
			_open_search(false)
			return
	search_motive = compute_search_motive()
	if search_motive == SearchLayout.MOTIVE_NONE:
		search_state = SearchState.AWAITING_CONFIRM
		EventBus.search_confirmation_required.emit(case.case_id)
		return
	_open_search(true)


func _open_search(first: bool) -> void:
	search_done = true
	search_state = SearchState.ACTIVATING
	_activation_left = timing.activation_cost(calibrated_gate)
	if first:
		EventBus.interrogation_answered.emit(TOPIC_SEARCH, scripted_line("search", _search_open_line()))
	EventBus.search_opened.emit(case.case_id, search_motive)
	_busy(_activation_left, BUSY_SEARCH_ACTIVATION)
	if _activation_left <= 0.0:
		search_state = SearchState.OPEN


func _on_search_requested(request: StringName) -> void:
	if not active or case == null or not documents_presented:
		return
	match request:
		SEARCH_CONFIRM:
			if search_state == SearchState.AWAITING_CONFIRM:
				_open_search(true)
		SEARCH_CANCEL:
			if search_state == SearchState.AWAITING_CONFIRM:
				search_state = SearchState.IDLE
				search_motive = SearchLayout.MOTIVE_NONE
		SEARCH_CLOSE:
			if search_state == SearchState.ACTIVATING or search_state == SearchState.OPEN:
				_close_search(true)
		SearchLayout.ZONE_ALL:
			if search_state == SearchState.ACTIVATING or search_state == SearchState.OPEN:
				for zone: StringName in SearchLayout.ZONES:
					_queue_zone(zone, timing.zone_cost_in_full_scan(calibrated_gate))
		_:
			if SearchLayout.ZONES.has(request) and (search_state == SearchState.ACTIVATING or search_state == SearchState.OPEN):
				_queue_zone(request, timing.zone_cost(calibrated_gate))


func _queue_zone(zone: StringName, cost: float) -> void:
	if zones_scanned.has(zone) or _zone_queue.has(zone) or _current_zone == zone:
		return
	_zone_queue.append(zone)
	_zone_costs.append(cost)


## Avance la fouille : activation, puis zones en file, chacune après sa durée.
func _advance_search(delta: float) -> void:
	var left: float = delta
	if search_state == SearchState.ACTIVATING:
		_activation_left -= left
		if _activation_left > 0.0:
			return
		left = -_activation_left
		_activation_left = 0.0
		search_state = SearchState.OPEN
	if search_state != SearchState.OPEN:
		return
	while true:
		if _current_zone == &"":
			if _zone_queue.is_empty():
				return
			_current_zone = _zone_queue.pop_front()
			_zone_left = _zone_costs.pop_front()
			_busy(_zone_left, busy_zone_action(_current_zone))
		if _zone_left > left:
			_zone_left -= left
			return
		left -= _zone_left
		_finish_zone()


func _finish_zone() -> void:
	var zone: StringName = _current_zone
	_current_zone = &""
	_zone_left = 0.0
	var found: Array[SearchItem] = []
	if case.search_layout != null:
		found = case.search_layout.scan(zone)
	if not zones_scanned.has(zone):
		zones_scanned.append(zone)
	EventBus.search_zone_scanned.emit(case.case_id, zone, found)
	if not search_found_said and case.search_found_forbidden():
		search_found_said = true
		var line: String = scripted_line("search_found", "")
		if not line.is_empty():
			EventBus.interrogation_answered.emit(TOPIC_SEARCH, line)
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.NERVOUS)


## Referme la silhouette. `speak` : réplique de fin d'une fouille sans
## trouvaille interdite (`<dialogue_id>_search_clean` ou `line_search_clean_<n>`).
func _close_search(speak: bool) -> void:
	_zone_queue.clear()
	_zone_costs.clear()
	_current_zone = &""
	_zone_left = 0.0
	_activation_left = 0.0
	search_state = SearchState.CLOSED
	if speak and not zones_scanned.is_empty() and not case.search_found_forbidden():
		var line: String = scripted_line("search_clean", _variant_line(LINE_SEARCH_CLEAN_PREFIX, "clean"))
		if not line.is_empty():
			EventBus.interrogation_answered.emit(TOPIC_SEARCH, line)
	EventBus.search_closed.emit(case.case_id)


## Réplique d'entrée au portique : coopérative ou protestataire, tirée de la
## graine du cas (jamais de la vérité).
func _search_open_line() -> String:
	var keys: Array[String] = []
	for prefix: String in [LINE_SEARCH_COMPLY_PREFIX, LINE_SEARCH_PROTEST_PREFIX]:
		var n: int = 1
		while n <= MAX_VARIANTS and UiText.has(prefix + str(n)):
			keys.append(prefix + str(n))
			n += 1
	if keys.is_empty():
		return LINE_SEARCH_COMPLY_PREFIX + "1"
	return keys[posmod(hash("%d|search" % case.case_seed), keys.size())]


func _variant_line(prefix: String, salt: String) -> String:
	var count: int = 0
	while count < MAX_VARIANTS and UiText.has(prefix + str(count + 1)):
		count += 1
	if count == 0:
		return ""
	return prefix + str(posmod(hash("%d|%s" % [case.case_seed, salt]), count) + 1)


## `about_<raison>[:<doc>]` : confrontation à une discordance précise. Réelle
## (constatée dans cette session) → réplique de sa famille + NERVOUS ; sinon
## indignation + ANGRY. Un passager scénarisé garde sa réplique dédiée.
func _confront_about(topic: StringName) -> void:
	var body: String = String(topic).trim_prefix(ABOUT_PREFIX)
	var reason: String = body.get_slice(DOC_SEPARATOR, 0)
	var doc: StringName = StringName(body.get_slice(DOC_SEPARATOR, 1)) if body.contains(DOC_SEPARATOR) else &""
	var found: Discrepancy = find_confirmed(reason, doc)
	if found != null:
		var family: String = family_of(found, case, ctx)
		var line: String = scripted_line("about_" + reason, "")
		if line.is_empty() and (GENERIC_FAMILIES.has(family) or DOC_FAMILIES.has(family)):
			# Acte II : réplique dédiée par famille (`sc25_elena_about_quota`…) ;
			# M13 : `sc104_strand_about_statement`, `sc106_zuri_about_contraband`.
			line = scripted_line("about_" + family, "")
		_answer_confrontation(topic, line if not line.is_empty() else about_line(family, true))
	else:
		EventBus.interrogation_answered.emit(topic, about_line(family_of_reason(reason), false))
		EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
		_busy(timing.confront_cost(hygiaphone), BUSY_CONFRONT)


## Réplique d'une famille de discordance : `line_about_<famille>_<n>` (réelle)
## ou `line_about_<famille>_outrage_<n>` (non constatée) ; variante choisie par
## la graine du cas. Repli : famille « autre », puis réplique générique.
func about_line(family: String, real: bool) -> String:
	if GENERIC_FAMILIES.has(family):
		if real and UiText.has("%s%s_generic" % [LINE_ABOUT_PREFIX, family]):
			return "%s%s_generic" % [LINE_ABOUT_PREFIX, family]
		family = FAMILY_OTHER
	for fam: String in [family, FAMILY_OTHER]:
		var stem: String = about_stem(fam, real)
		var count: int = 0
		while count < MAX_VARIANTS and UiText.has(stem + str(count + 1)):
			count += 1
		if count > 0:
			var case_seed: int = case.case_seed if case != null else 0
			return stem + str(posmod(hash("%d|%s" % [case_seed, fam]), count) + 1)
	return LINE_CONFRONT_NERVOUS if real else LINE_CONFRONT_ANGRY


static func about_stem(family: String, real: bool) -> String:
	return LINE_ABOUT_PREFIX + family + "_" + ("" if real else LINE_OUTRAGE_INFIX)


## Famille d'une discordance constatée (visible seulement : jamais `CaseKey`).
static func family_of(d: Discrepancy, p_case: Case, p_ctx: RuleContext) -> String:
	if d == null:
		return FAMILY_OTHER
	var reason: String = d.reason_key.trim_prefix("disc_")
	match reason:
		"face_mismatch":
			return FAMILY_FACE
		"expired":
			return FAMILY_VALIDITY
		"implant_mismatch":
			# M13 : implant trouvé à la fouille (objet du portique).
			if (d.a != null and d.a.is_scan()) or (d.b != null and d.b.is_scan()):
				return FAMILY_CONCEALED_IMPLANT
			return FAMILY_IMPLANT
		"wanted_match":
			return FAMILY_WANTED
		"revoked_match":
			return FAMILY_REVOKED
		"age_mismatch":
			return FAMILY_BIRTH
		"mrz_mismatch":
			return FAMILY_ID_NUMBER
		"statement_mismatch":
			return FAMILY_STATEMENT
		"contraband":
			return FAMILY_CONTRABAND
		"weapon":
			return FAMILY_WEAPON
		"rule_violated":
			var rule_ref: FieldRef = d.a if d.a != null and d.a.is_rule() else d.b
			var other: FieldRef = d.b if rule_ref == d.a else d.a
			var rule: Rule = p_ctx.find_active_rule(rule_ref.field_id) if p_ctx != null and rule_ref != null else null
			if rule is AirQuotaRule:
				return FAMILY_QUOTA
			if rule is CurfewRule:
				return FAMILY_CURFEW
			if rule is RevokedIdRule:
				return FAMILY_REVOKED
			if rule is ContractConsistentRule:
				return FAMILY_CONTRACT
			if rule is SponsorRule:
				return FAMILY_SPONSOR
			if rule is SummonsRule:
				return FAMILY_SUMMONS
			if rule is ContractSuspendedRule:
				return FAMILY_LOCKOUT
			if rule is DriftPassRule and other != null and not other.is_rule():
				var drift_field: FieldDef = p_case.get_field_def(other) if p_case != null else null
				if drift_field != null and drift_field.truth_path == DriftPassRule.VESSEL_PATH:
					return FAMILY_OTHER
			# M13 (lot B) : familles nouvelles, lues par nom de classe.
			match _rule_class(rule):
				&"StatementsConsistentRule":
					return FAMILY_STATEMENT
				&"ContrabandRule":
					return FAMILY_WEAPON if rule.severity >= 3 else FAMILY_CONTRABAND
			if (other != null and other.is_statement()):
				return FAMILY_STATEMENT
			if rule is RequireDocumentRule:
				return FAMILY_MISSING
			if rule is IssuerAllowedRule:
				return FAMILY_ISSUER
			if rule is OriginIdBlockRule:
				return FAMILY_ORIGIN
			if rule is DocumentNotExpiredRule:
				return FAMILY_VALIDITY
			if rule is PortraitMatchRule or rule is ApparentAgeRule:
				return FAMILY_FACE
			if rule is ImplantsDeclaredRule or rule is BannedImplantsRule:
				return FAMILY_IMPLANT
			if rule is WantedRule:
				return FAMILY_WANTED
			if rule is FactionBannedRule:
				return FAMILY_ORIGIN
			if rule is FieldValueAllowedRule:
				var allowed: FieldValueAllowedRule = rule as FieldValueAllowedRule
				return family_of_truth_path(allowed.truth_path)
			return _family_of_ref(other, p_case)
	# Deux champs de documents (`mismatch`) : la donnée comparée.
	var family: String = _family_of_ref(d.a, p_case)
	return family if family != FAMILY_OTHER else _family_of_ref(d.b, p_case)


## Famille déductible du seul sujet (discordance non constatée).
static func family_of_reason(reason: String) -> String:
	match reason:
		"face_mismatch":
			return FAMILY_FACE
		"expired":
			return FAMILY_VALIDITY
		"implant", "implant_mismatch":
			return FAMILY_IMPLANT
		"wanted", "wanted_match":
			return FAMILY_WANTED
		"quota":
			return FAMILY_QUOTA
		"curfew":
			return FAMILY_CURFEW
		"revoked", "revoked_match":
			return FAMILY_REVOKED
		"contract":
			return FAMILY_CONTRACT
		"sponsor":
			return FAMILY_SPONSOR
		"summons":
			return FAMILY_SUMMONS
		"lockout":
			return FAMILY_LOCKOUT
		"statement", "statement_mismatch":
			return FAMILY_STATEMENT
		"contraband":
			return FAMILY_CONTRABAND
		"weapon":
			return FAMILY_WEAPON
		"concealed_implant":
			return FAMILY_CONCEALED_IMPLANT
	return FAMILY_OTHER


## Dernière réplique au départ (M7, NARRATIVE §4.0 `_exit_*`) :
## `<dialogue_id>_exit_<approve|deny|detain>` si elle existe, réplique générique
## pour une détention, vide sinon.
static func exit_line_key(p_case: Case, kind: VerdictKind.Kind) -> String:
	if p_case == null:
		return ""
	var suffix: String = "exit_" + SlippedItem.VERDICT_NAMES[kind]
	return p_case.scripted_key(suffix, LINE_EXIT_DETAIN if kind == VerdictKind.Kind.DETAIN else "", UiText.has)


static func family_of_truth_path(path: StringName) -> String:
	return TRUTH_PATH_FAMILIES.get(path, FAMILY_OTHER)


static func _family_of_ref(ref: FieldRef, p_case: Case) -> String:
	if ref == null:
		return FAMILY_OTHER
	if ref.is_passenger_face():
		return FAMILY_FACE
	var field: FieldDef = p_case.get_field_def(ref) if p_case != null else null
	if field == null:
		return FAMILY_OTHER
	if field.kind == FieldDef.FieldKind.PORTRAIT:
		return FAMILY_FACE
	return family_of_truth_path(field.truth_path)


## Réplique dédiée du passager scénarisé (`<dialogue_id>_<suffixe>`) si elle
## existe, sinon `fallback`.
func scripted_line(suffix: String, fallback: String) -> String:
	if case == null:
		return fallback
	return case.scripted_key(suffix, fallback, UiText.has)


## Vrai si une discordance confirmée a cette raison (`expired`, `mismatch`…)
## et touche le document `doc` (si précisé).
func has_confirmed(reason: String, doc: StringName = &"") -> bool:
	return find_confirmed(reason, doc) != null


## Première discordance confirmée de cette raison touchant `doc` (null sinon).
func find_confirmed(reason: String, doc: StringName = &"") -> Discrepancy:
	for d: Discrepancy in confirmed:
		if d.reason_key.trim_prefix("disc_") != reason:
			continue
		if doc == &"" or (d.a != null and d.a.document_id == doc) or (d.b != null and d.b.document_id == doc):
			return d
	# Acte II : sujets par famille (`about_quota`, `about_curfew`, `about_revoked`,
	# `about_contract`) débloqués par une discordance de cette famille.
	if RULE_FAMILIES.has(reason):
		for d: Discrepancy in confirmed:
			if family_of(d, case, ctx) == reason:
				return d
	# M13 : `about_statement[:<doc>]`, `about_contraband`, `about_weapon`,
	# `about_concealed_implant` (le document, s'il est donné, filtre).
	if DOC_FAMILIES.has(reason):
		for d: Discrepancy in confirmed:
			if family_of(d, case, ctx) != reason:
				continue
			if doc == &"" or (d.a != null and d.a.document_id == doc) or (d.b != null and d.b.document_id == doc):
				return d
	return null


## Nom de classe global du script d'une règle (familles du lot B citées sans
## dépendance de compilation).
static func _rule_class(rule: Rule) -> StringName:
	var script: Script = rule.get_script() as Script if rule != null else null
	return script.get_global_name() if script != null else &""


func _already_confirmed(result: Discrepancy) -> bool:
	for known: Discrepancy in confirmed:
		if (known.a.equals(result.a) and known.b.equals(result.b)) or (known.a.equals(result.b) and known.b.equals(result.a)):
			return true
	return false
