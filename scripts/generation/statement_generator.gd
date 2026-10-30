## Générateur des déclarations orales (M13, docs/M13.md §1.3–§1.6, §1.11 ;
## D-143 ; B65) — pur, déterministe (graine du cas).
##
## Appelé par le `CaseBuilder` **après** l'injection, sur les documents
## finaux : chaque déclaration honnête est lue sur le champ **de référence**
## de R43 (`StatementsConsistentRule.primary_ref` : permis, carte,
## laissez-passer), donc un passager honnête ne produit jamais de
## discordance. L'injecteur `STATEMENT_MISMATCH` a seulement choisi le
## mensonge (`InjectionState.statement_lie` : sujet, valeur, fragment) ; il
## remplace ici la déclaration honnête de son sujet. Jamais de `CaseKey`.
##
## Bruit légitime (taux de `StatementTablesDef`) : durée vague (VN-1, jamais
## chez un menteur de durée), auto-correction (VN-2, même taux pour menteurs et
## honnêtes, la valeur finale fait foi), provenance (VN-3, jamais comparée),
## réponse en Tessar (VN-4), alias d'employeur (VN-5), durée arrondie à une
## formule à intervalle (VN-6), hésitation (cadre « Euh… », indépendante du
## mensonge). Les cadres de réponse (`Case.statement_frames`) ne portent
## aucune valeur : seuls les fragments en portent.
class_name StatementGenerator
extends RefCounted

const FRAME_GENERIC: StringName = &"gen"
## Cadre d'hésitation (« Euh… {motif}. ») : tiré à `hesitation_rate`.
const FRAME_HESITATION: String = "line_stmt_frame_gen_3"
const NO_EMPLOYER: String = "SANS EMPLOYEUR"
const PERMIT_ID: StringName = &"entry_permit"
const CARD_ID: StringName = &"id_card"
const DRIFT_PASS_ID: StringName = &"drift_pass"
## Sous-flux (le flux principal du cas est inchangé).
const SALT_STAY: int = 1
const SALT_PURPOSE: int = 2
const SALT_EMPLOYER: int = 3
const SALT_ORIGIN: int = 4
const SALT_FRAMES: int = 5
const SALT_CORRECTION: int = 6


## Pose `c.statements` et `c.statement_frames` (vides si R43 est inactive).
## `lie` : mensonge choisi par l'injecteur (`{}` = passager honnête) —
## `{topic, statement}` où `statement` est la déclaration fausse.
static func generate(c: Case, tables: StatementTablesDef, rule: StatementsConsistentRule, rng: SeededRng,
		lie: Dictionary = {}) -> void:
	if c == null:
		return
	c.statements.clear()
	c.statement_frames.clear()
	if tables == null or rule == null or c.passenger_presented == null:
		return
	var presented: Passenger = c.passenger_presented
	var lie_topic: StringName = StringName(str(lie.get("topic", "")))
	var lie_statement: Statement = lie.get("statement", null)

	# Motif.
	var purpose_value: StringName = StringName(str(_primary_value(c, PERMIT_ID, &"purpose", presented.purpose)))
	var purpose: Statement = Statement.make(Statement.ID_PURPOSE, purpose_value,
			purpose_key(tables, purpose_value, rng.fork(SALT_PURPOSE)))
	if lie_topic == Statement.ID_PURPOSE and lie_statement != null:
		purpose = lie_statement
	c.statements.append(purpose)

	# Durée (VN-1 vague, VN-2 auto-correction, VN-6 formule à intervalle).
	var stay_rng: SeededRng = rng.fork(SALT_STAY)
	var days: int = int(_primary_value(c, PERMIT_ID, &"stay_days", presented.stay_days))
	var stay: Statement = null
	if lie_topic == Statement.ID_STAY and lie_statement != null:
		stay = lie_statement
	elif stay_rng.chance(tables.vague_rate) and not tables.vague_keys.is_empty():
		stay = Statement.vague_answer(Statement.ID_STAY, tables.vague_keys[stay_rng.randi_range(0, tables.vague_keys.size() - 1)])
	else:
		stay = duration_statement(tables, days, stay_rng)
	var correction_rng: SeededRng = rng.fork(SALT_CORRECTION)
	if not stay.vague and correction_rng.chance(tables.correction_rate):
		_add_correction(tables, stay, correction_rng)
	c.statements.append(stay)

	# Employeur (J12+, motif TRAVAIL, VN-5 alias).
	var employer: Statement = null
	if rule.checks_topic(Statement.ID_EMPLOYER) and purpose_value == Passenger.PURPOSE_WORK:
		if lie_topic == Statement.ID_EMPLOYER and lie_statement != null:
			employer = lie_statement
		else:
			var written: String = str(_primary_value(c, PERMIT_ID, &"employer", presented.employer))
			if has_employer(written):
				employer = employer_statement(tables, tables.canonical_employer(written), rng.fork(SALT_EMPLOYER))
	if employer != null:
		c.statements.append(employer)

	# Personne visitée (J24+, VISITE FAMILIALE avec répondant).
	var host: Statement = null
	if rule.checks_topic(Statement.ID_HOST) and purpose_value == Passenger.PURPOSE_FAMILY_VISIT:
		if lie_topic == Statement.ID_HOST and lie_statement != null:
			host = lie_statement
		else:
			var sponsor_name: Variant = _primary_value(c, PERMIT_ID, Statement.PATH_SPONSOR_NAME, null)
			if sponsor_name != null and not str(sponsor_name).strip_edges().is_empty():
				host = Statement.make(Statement.ID_HOST, str(sponsor_name), tables.host_keys.get(&"friend", "stmt_host_friend"),
						[str(sponsor_name)])
	if host != null:
		c.statements.append(host)

	# Origine (J13+) et provenance (VN-3, VN-4).
	if rule.checks_topic(Statement.ID_ORIGIN):
		_add_origin(c, tables, rng.fork(SALT_ORIGIN), lie_topic == Statement.ID_ORIGIN, lie_statement)

	_pick_frames(c, tables, rng.fork(SALT_FRAMES))


## Clé de fragment d'un motif (`stmt_purpose_trade_2`).
static func purpose_key(tables: StatementTablesDef, purpose: StringName, rng: SeededRng) -> String:
	var keys: PackedStringArray = tables.purpose_keys.get(purpose, PackedStringArray())
	if keys.is_empty():
		return ""
	return keys[rng.randi_range(0, keys.size() - 1)]


## Déclaration de durée **honnête** pour `days` : exacte (≤ 10 jours, parfois
## une formule qui la contient) ou formule à intervalle (> 10 jours, VN-6) ;
## repli « %d jours ».
static func duration_statement(tables: StatementTablesDef, days: int, rng: SeededRng) -> Statement:
	var intervals: PackedStringArray = tables.interval_keys_for(days)
	var use_interval: bool = days > tables.interval_above or (not intervals.is_empty() and rng.chance(0.3))
	if use_interval and not intervals.is_empty():
		var key: String = intervals[rng.randi_range(0, intervals.size() - 1)]
		var span: Vector2i = tables.range_of(key)
		return Statement.duration(span.x, span.y, key)
	return exact_duration(tables, days)


static func exact_duration(tables: StatementTablesDef, days: int) -> Statement:
	if tables.exact_duration_keys.has(days):
		return Statement.duration(days, days, tables.exact_duration_keys[days])
	return Statement.duration(days, days, tables.exact_key, [days])


## Déclaration de durée **fausse** (AV-2) : intervalle disjoint de `days` avec
## un écart ≥ max(`lie_gap_min` ; `lie_gap_ratio` × durée) (`subtle` : ≥
## `lie_gap_subtle`). Null si aucune formule ne convient.
static func lie_duration(tables: StatementTablesDef, days: int, rng: SeededRng, subtle: bool = false) -> Statement:
	var gap: int = tables.lie_gap_subtle if subtle else maxi(tables.lie_gap_min, ceili(tables.lie_gap_ratio * days))
	var candidates: Array[Statement] = []
	for i: int in tables.duration_keys.size():
		var span: Vector2i = tables.duration_ranges[i]
		if span.y <= days - gap or span.x >= days + gap:
			candidates.append(Statement.duration(span.x, span.y, tables.duration_keys[i]))
	for n: int in tables.exact_duration_keys:
		if absi(n - days) >= gap:
			candidates.append(Statement.duration(n, n, tables.exact_duration_keys[n]))
	if subtle:
		for n: int in [days - gap, days + gap]:
			if n >= 1 and n <= tables.exact_max and not tables.exact_duration_keys.has(n):
				candidates.append(Statement.duration(n, n, tables.exact_key, [n]))
	if candidates.is_empty():
		return null
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## Employeur dit : nom canonique ou alias reconnu (VN-5) ; la valeur est
## toujours le nom canonique.
static func employer_statement(tables: StatementTablesDef, canonical: String, rng: SeededRng) -> Statement:
	var said: String = canonical
	var aliases: PackedStringArray = tables.aliases_of(canonical)
	if not aliases.is_empty() and rng.chance(tables.alias_rate):
		said = aliases[rng.randi_range(0, aliases.size() - 1)]
	return Statement.make(Statement.ID_EMPLOYER, canonical, tables.employer_key, [said])


## Vrai si le texte d'employeur désigne un employeur (ni vide ni « SANS EMPLOYEUR »).
static func has_employer(text: String) -> bool:
	var clean: String = text.strip_edges()
	return not clean.is_empty() and clean.to_upper() != NO_EMPLOYER


static func _add_correction(tables: StatementTablesDef, stay: Statement, rng: SeededRng) -> void:
	var options: PackedStringArray = []
	var final_span: Vector2i = stay.value
	for i: int in tables.duration_keys.size():
		if tables.duration_keys[i] != stay.phrase_key and tables.duration_ranges[i] != final_span:
			options.append(tables.duration_keys[i])
	if options.is_empty():
		return
	stay.corrected_from = options[rng.randi_range(0, options.size() - 1)]
	stay.corrected_args = []


static func _add_origin(c: Case, tables: StatementTablesDef, rng: SeededRng, lying: bool, lie_statement: Statement) -> void:
	var presented: Passenger = c.passenger_presented
	var faction: StringName = StringName(str(_primary_value(c, CARD_ID, &"faction_id", presented.faction_id)))
	if lying and lie_statement != null:
		c.statements.append(lie_statement)
	elif rng.chance(tables.tessar_rates.get(faction, 0.0)):
		# VN-4 : réponse en Tessar, provenance seule.
		var tessar: Statement = Statement.make(Statement.ID_PROVENANCE, null, tables.provenance_tessar_key)
		tessar.truth_path = &""
		c.statements.append(tessar)
		return
	else:
		var vessel: Variant = _primary_value(c, DRIFT_PASS_ID, &"vessel", null)
		if faction == &"drv" and vessel != null and not str(vessel).is_empty():
			var drifter: Statement = Statement.make(Statement.ID_ORIGIN, str(vessel), tables.origin_keys.get(&"drv", ""),
					[str(vessel)])
			drifter.truth_path = Statement.PATH_VESSEL
			c.statements.append(drifter)
		elif tables.origin_keys.has(faction) and faction != &"drv":
			c.statements.append(Statement.make(Statement.ID_ORIGIN, faction, tables.origin_keys[faction]))
	if rng.chance(tables.provenance_rate):
		c.statements.append(provenance_statement(tables, rng))


## Provenance (« J'arrive de… », VN-3) : jamais comparée.
static func provenance_statement(tables: StatementTablesDef, rng: SeededRng) -> Statement:
	var statement: Statement = null
	if tables.provenance_places.is_empty() or rng.chance(0.4):
		statement = Statement.make(Statement.ID_PROVENANCE, null, tables.provenance_shuttle_key)
	else:
		var place: String = tables.provenance_places[rng.randi_range(0, tables.provenance_places.size() - 1)]
		statement = Statement.make(Statement.ID_PROVENANCE, null, tables.provenance_place_key, [place])
	statement.truth_path = &""
	return statement


## Cadres de réponse par question (`purpose`, `stay`, `origin`) : un cadre
## n'est retenu que si la réplique remplie tient en `max_line_length`.
static func _pick_frames(c: Case, tables: StatementTablesDef, rng: SeededRng) -> void:
	var faction: StringName = c.passenger_presented.faction_id
	var stay: Statement = c.get_statement(Statement.ID_STAY)
	var purpose_parts: Array[Statement] = []
	for statement: Statement in c.statements:
		if Statement.ids_for_question(Statement.QUESTION_PURPOSE).has(statement.id):
			purpose_parts.append(statement)
	var hesitates: bool = rng.chance(tables.hesitation_rate)
	var pools: Array[PackedStringArray] = []
	if stay != null and stay.is_corrected():
		pools.append(tables.correction_frames)
	elif c.get_statement(Statement.ID_EMPLOYER) != null:
		pools.append(tables.work_frames)
	elif c.get_statement(Statement.ID_HOST) != null:
		pools.append(tables.visit_frames)
	elif hesitates:
		pools.append(PackedStringArray([FRAME_HESITATION]))
	else:
		var own: PackedStringArray = tables.frames.get(faction, PackedStringArray())
		var generic: PackedStringArray = tables.frames.get(FRAME_GENERIC, PackedStringArray())
		var first: PackedStringArray = generic if own.is_empty() or rng.chance(tables.generic_frame_rate) else own
		pools.append(_without(first, FRAME_HESITATION))
		pools.append(_without(generic, FRAME_HESITATION))
	pools.append(PackedStringArray(["line_stmt_frame_gen_1"]))
	var frame: String = _pick_fitting(tables, pools, purpose_parts, rng)
	if not frame.is_empty():
		c.statement_frames[Statement.QUESTION_PURPOSE] = frame
	if stay != null:
		var stay_frame: String = _pick_fitting(tables, [tables.stay_frames], [stay], rng)
		if not stay_frame.is_empty():
			c.statement_frames[Statement.QUESTION_STAY] = stay_frame
	var origin: Statement = c.get_statement(Statement.ID_ORIGIN)
	var provenance: Statement = c.get_statement(Statement.ID_PROVENANCE)
	var origin_parts: Array[Statement] = []
	for statement: Statement in [origin, provenance]:
		if statement != null:
			origin_parts.append(statement)
	var origin_pool: PackedStringArray = []
	if origin == null and provenance != null:
		origin_pool = tables.origin_frames_tessar
	elif origin != null and origin.truth_path == Statement.PATH_VESSEL:
		origin_pool = tables.origin_frames_drv
	elif origin != null and provenance != null:
		origin_pool = tables.origin_frames
	elif origin != null:
		origin_pool = tables.origin_frames_plain
	if not origin_pool.is_empty():
		var origin_frame: String = _pick_fitting(tables, [origin_pool], origin_parts, rng)
		if not origin_frame.is_empty():
			c.statement_frames[Statement.QUESTION_ORIGIN] = origin_frame


## Premier cadre (tiré dans l'ordre des réserves) dont la réplique tient ;
## repli : le plus court de la dernière réserve.
static func _pick_fitting(tables: StatementTablesDef, pools: Array, parts: Array[Statement], rng: SeededRng) -> String:
	var fallback: String = ""
	for raw: Variant in pools:
		var pool: PackedStringArray = raw
		var fitting: PackedStringArray = []
		for key: String in pool:
			var length: int = tables.filled_length(key, parts)
			if length <= tables.max_line_length:
				fitting.append(key)
			if fallback.is_empty():
				fallback = key
		if not fitting.is_empty():
			return _pick(fitting, rng)
	return fallback


static func _without(keys: PackedStringArray, excluded: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for key: String in keys:
		if key != excluded:
			result.append(key)
	return result


static func _pick(keys: PackedStringArray, rng: SeededRng) -> String:
	if keys.is_empty():
		return ""
	return keys[rng.randi_range(0, keys.size() - 1)]


## Valeur du champ de référence (`document_id`, `truth_path`) des documents du
## porteur, sinon `fallback` (passager présenté).
static func _primary_value(c: Case, document_id: StringName, path: StringName, fallback: Variant) -> Variant:
	var doc: DocumentInstance = c.get_own_document(document_id)
	if doc == null:
		return fallback
	var field: FieldDef = doc.type_def.find_field_by_truth_path(path)
	if field == null:
		return fallback
	var value: Variant = doc.get_value(field.id)
	return value if value != null else fallback
