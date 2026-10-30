## `STATEMENT_MISMATCH` (M13, docs/M13.md §1.5 ; D-142, D-149 ; B67) : une
## déclaration orale contredit un document. Variante (sujet) tirée selon
## `DayDef.statement_topic_weights`, **conditionnels** (sujets impossibles
## écartés, poids renormalisés) parmi ceux du palier actif de R43 :
## - AV-1 `purpose` : un autre motif plausible pour l'origine ;
## - AV-2 `stay` : intervalle disjoint du permis, écart ≥ max(4 j ; 40 %)
##   (`subtle` : ≥ 2 j) ; jamais en même temps qu'un `PURPOSE_MISMATCH` sur la
##   durée (le champ est réservé) ;
## - AV-3 `employer` : autre corporation du LORE (motif TRAVAIL, contrat présent) ;
## - AV-4 `origin` : « Je suis de {autre origine} » (lapsus) ;
## - AV-5 `host` : un proche du même nom de famille au lieu du répondant.
## L'injecteur choisit le mensonge et réserve le champ de référence ; la
## déclaration est posée par le `StatementGenerator` après l'injection.
## Au plus une fausse déclaration par cas, 0 ou 1 autre anomalie, jamais avec
## `WANTED_PERSON`, `REVOKED_ID` ni `CONCEALED_WEAPON`.
## Paramètres : `topic` (sujet imposé), `subtle`.
class_name StatementMismatchInjector
extends AnomalyInjector

const INCOMPATIBLE: Array[AnomalyType.Kind] = [AnomalyType.Kind.WANTED_PERSON, AnomalyType.Kind.REVOKED_ID,
		AnomalyType.Kind.CONCEALED_WEAPON]
const PERMIT_ID: StringName = &"entry_permit"
const CARD_ID: StringName = &"id_card"
const CONTRACT_ID: StringName = &"work_contract"
const ALL_PURPOSES: Array[StringName] = [Passenger.PURPOSE_WORK, Passenger.PURPOSE_FAMILY_VISIT,
		Passenger.PURPOSE_RETURN, Passenger.PURPOSE_TRADE, Passenger.PURPOSE_TRANSIT, Passenger.PURPOSE_DIPLOMATIC]
## Origines dites par un menteur AV-4 (jamais « Dérivant » : pas de vaisseau à nommer).
const LIE_ORIGINS: Array[StringName] = [&"tyc", &"hal", &"ter", &"cer", &"thr"]


func get_kind() -> AnomalyType.Kind:
	return AnomalyType.Kind.STATEMENT_MISMATCH


func inject(state: InjectionState) -> Anomaly:
	var rules: Array[Rule] = active_rules(state, StatementsConsistentRule)
	var tables: StatementTablesDef = state.get_statement_tables()
	if rules.is_empty() or tables == null or not state.statement_lie.is_empty():
		return null
	for kind: AnomalyType.Kind in state.injected:
		if INCOMPATIBLE.has(kind):
			return null
	if state.injected.size() >= 2:
		return null
	var rule: StatementsConsistentRule = rules[0]
	var forced: StringName = StringName(str(state.param(&"topic", "")))
	var candidates: Array[StringName] = []
	var weights: PackedFloat32Array = []
	var table: Dictionary[StringName, float] = state.ctx.day_def.statement_topic_weights if state.ctx.day_def != null \
			else ({} as Dictionary[StringName, float])
	for topic: StringName in rule.topics:
		if forced != &"" and topic != forced:
			continue
		var weight: float = table.get(topic, 1.0 if table.is_empty() else 0.0)
		if forced != &"":
			weight = 1.0
		if weight <= 0.0 or not _feasible(state, rule, topic):
			continue
		candidates.append(topic)
		weights.append(weight)
	if candidates.is_empty():
		return null
	var topic: StringName = candidates[maxi(state.rng.weighted_index(weights), 0)]
	if state.scripted_statements:
		# Cas scénarisé : le mensonge est écrit dans `ScriptedCaseDef.statements`.
		_reserve(state, topic)
		state.statement_lie = {"topic": topic, "statement": null}
		return make_anomaly(get_kind(), FieldRef.STATEMENT_DOCUMENT_ID, topic, null, null)
	var lie: Statement = _make_lie(state, tables, topic)
	if lie == null:
		return null
	_reserve(state, topic)
	state.statement_lie = {"topic": topic, "statement": lie}
	return make_anomaly(get_kind(), FieldRef.STATEMENT_DOCUMENT_ID, topic, _reference_value(state, topic), lie.value)


## Sujet injectable sur ce cas (document de référence présent et libre).
func _feasible(state: InjectionState, rule: StatementsConsistentRule, topic: StringName) -> bool:
	var c: Case = state.case
	var permit: DocumentInstance = c.get_own_document(PERMIT_ID)
	match topic:
		Statement.ID_PURPOSE, Statement.ID_STAY:
			var path: StringName = &"purpose" if topic == Statement.ID_PURPOSE else &"stay_days"
			var field_id: StringName = field_for(c, PERMIT_ID, path)
			return permit != null and field_id != &"" and state.is_free(PERMIT_ID, field_id)
		Statement.ID_EMPLOYER:
			var employer_field: StringName = field_for(c, PERMIT_ID, &"employer")
			if permit == null or employer_field == &"" or c.get_own_document(CONTRACT_ID) == null:
				return false
			if not FieldValue.equals(permit.get_value(field_for(c, PERMIT_ID, &"purpose")), Passenger.PURPOSE_WORK):
				return false
			return state.is_free(PERMIT_ID, employer_field) and state.is_free(CONTRACT_ID, field_for(c, CONTRACT_ID, &"employer_code")) \
					and StatementGenerator.has_employer(str(permit.get_value(employer_field)))
		Statement.ID_ORIGIN:
			var faction_field: StringName = field_for(c, CARD_ID, &"faction_id")
			return c.get_own_document(CARD_ID) != null and faction_field != &"" and state.is_free(CARD_ID, faction_field)
		Statement.ID_HOST:
			var name_field: StringName = field_for(c, PERMIT_ID, Statement.PATH_SPONSOR_NAME)
			if permit == null or name_field == &"" or not state.is_free(PERMIT_ID, name_field):
				return false
			if not FieldValue.equals(permit.get_value(field_for(c, PERMIT_ID, &"purpose")), Passenger.PURPOSE_FAMILY_VISIT):
				return false
			var sponsor: Variant = permit.get_value(name_field)
			return sponsor != null and not str(sponsor).strip_edges().is_empty()
	return false


func _make_lie(state: InjectionState, tables: StatementTablesDef, topic: StringName) -> Statement:
	var c: Case = state.case
	var permit: DocumentInstance = c.get_own_document(PERMIT_ID)
	match topic:
		Statement.ID_PURPOSE:
			var actual: StringName = StringName(str(permit.get_value(field_for(c, PERMIT_ID, &"purpose"))))
			var options: Array[StringName] = []
			for purpose: Variant in tables.lie_purposes.get(c.passenger_presented.faction_id, PackedStringArray()):
				if StringName(str(purpose)) != actual:
					options.append(StringName(str(purpose)))
			if options.is_empty():
				for purpose: StringName in ALL_PURPOSES:
					if purpose != actual and tables.purpose_keys.has(purpose):
						options.append(purpose)
			if options.is_empty():
				return null
			var said: StringName = options[state.rng.randi_range(0, options.size() - 1)]
			return Statement.make(Statement.ID_PURPOSE, said, StatementGenerator.purpose_key(tables, said, state.rng))
		Statement.ID_STAY:
			var days: int = int(permit.get_value(field_for(c, PERMIT_ID, &"stay_days")))
			return StatementGenerator.lie_duration(tables, days, state.rng, state.param_bool(CaseBuilder.SUBTLE_PARAM, false))
		Statement.ID_EMPLOYER:
			var actual_employer: String = tables.canonical_employer(str(permit.get_value(field_for(c, PERMIT_ID, &"employer"))))
			var others: PackedStringArray = []
			for corp: String in tables.lore_employers:
				if Statement.normalize_text(corp) != Statement.normalize_text(actual_employer):
					others.append(corp)
			if others.is_empty():
				return null
			var said_corp: String = others[state.rng.randi_range(0, others.size() - 1)]
			return StatementGenerator.employer_statement(tables, said_corp, state.rng)
		Statement.ID_ORIGIN:
			var card_faction: StringName = StringName(str(c.get_document(CARD_ID).get_value(field_for(c, CARD_ID, &"faction_id"))))
			var origins: Array[StringName] = []
			for faction: StringName in LIE_ORIGINS:
				if faction != card_faction and tables.origin_keys.has(faction):
					origins.append(faction)
			if origins.is_empty():
				return null
			var said_origin: StringName = origins[state.rng.randi_range(0, origins.size() - 1)]
			return Statement.make(Statement.ID_ORIGIN, said_origin, tables.origin_keys[said_origin])
		Statement.ID_HOST:
			var sponsor: String = str(permit.get_value(field_for(c, PERMIT_ID, Statement.PATH_SPONSOR_NAME)))
			var family: String = c.passenger_presented.family_name
			var relations: PackedStringArray = tables.family_relations
			if relations.is_empty() or family.is_empty():
				return null
			var relation: StringName = StringName(relations[state.rng.randi_range(0, relations.size() - 1)])
			var given: String = _relative_given_name(state, relation)
			var said_name: String = "%s %s" % [given, family]
			if Statement.normalize_text(said_name) == Statement.normalize_text(sponsor):
				return null
			return Statement.make(Statement.ID_HOST, said_name, tables.host_keys.get(relation, "stmt_host_friend"), [said_name])
	return null


## Prénom d'un proche (réserve de l'origine du passager, sexe de la relation).
func _relative_given_name(state: InjectionState, relation: StringName) -> String:
	var faction: FactionDef = state.get_faction(state.case.passenger_presented.faction_id)
	var sex: StringName = Passenger.SEX_F if relation in [&"sister", &"daughter", &"mother"] else Passenger.SEX_M
	if faction != null and faction.name_pool != null:
		return faction.name_pool.pick_given_name(state.rng, sex)
	return "Ana" if sex == Passenger.SEX_F else "Tomás"


## Réserve le champ de référence (aucun autre injecteur ne le modifie : la
## contradiction reste lisible et un menteur AV-2 n'a pas de `PURPOSE_MISMATCH`
## sur la durée).
func _reserve(state: InjectionState, topic: StringName) -> void:
	var c: Case = state.case
	match topic:
		Statement.ID_PURPOSE:
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, &"purpose"))
		Statement.ID_STAY:
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, &"stay_days"))
		Statement.ID_EMPLOYER:
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, &"employer"))
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, &"purpose"))
			if c.get_own_document(CONTRACT_ID) != null:
				state.mark(CONTRACT_ID, field_for(c, CONTRACT_ID, &"employer_code"))
		Statement.ID_ORIGIN:
			state.mark(CARD_ID, field_for(c, CARD_ID, &"faction_id"))
		Statement.ID_HOST:
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, Statement.PATH_SPONSOR_NAME))
			state.mark(PERMIT_ID, field_for(c, PERMIT_ID, &"purpose"))


func _reference_value(state: InjectionState, topic: StringName) -> Variant:
	var c: Case = state.case
	match topic:
		Statement.ID_ORIGIN:
			return c.get_document(CARD_ID).get_value(field_for(c, CARD_ID, &"faction_id"))
		Statement.ID_PURPOSE:
			return c.get_document(PERMIT_ID).get_value(field_for(c, PERMIT_ID, &"purpose"))
		Statement.ID_STAY:
			return c.get_document(PERMIT_ID).get_value(field_for(c, PERMIT_ID, &"stay_days"))
		Statement.ID_EMPLOYER:
			return c.get_document(PERMIT_ID).get_value(field_for(c, PERMIT_ID, &"employer"))
		Statement.ID_HOST:
			return c.get_document(PERMIT_ID).get_value(field_for(c, PERMIT_ID, Statement.PATH_SPONSOR_NAME))
	return null
