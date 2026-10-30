## Passe QA M13 « Gameplay » (docs/QA.md §16) — tests de non-régression des
## bugs QA-063 et suivants, et vérifications de la passe sur les vraies données
## (jours, cas scénarisés, événements, sauvegardes réelles 0.12).
## Convention (QA.md §1) : un bug présent appelle `pending("QA-xxx : …")` ; le
## test passe une fois le bug corrigé (retirer alors la branche `pending`).
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const VK := VerdictKind.Kind
const K := AnomalyType.Kind

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _event(id: StringName) -> StationEventDef:
	for event: StationEventDef in StationEventService.load_def().events:
		if event != null and event.id == id:
			return event
	return null


## Premier passager généré du jour `n` qui satisfait `accept(builder, generated)`.
func _find(n: int, accept: Callable, groups: int = 60) -> Array:
	for group: int in groups:
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(31_000 + group, n))
		builder.presentation_minute = 12 * 60
		for g: GeneratedCase in builder.build_day():
			if g != null and g.scripted_id == &"" and accept.call(builder, g):
				return [builder, g]
	return []


# ---------------------------------------------------------------------------
# QA-063 — EV-05 (portique hors tension) laisse R47 en vigueur
# ---------------------------------------------------------------------------

## Pendant une coupure EV-05 au J19+, R44 est retirée (aucune fouille possible)
## mais R47 restait dans le RuleSet : approuver un Ceinturier au long séjour
## valait FOUILLE OMISE alors que le joueur ne peut pas fouiller (le seul autre
## verdict, REFUSÉ, est un REFUS INJUSTIFIÉ). Corrigé (D-172) : EV-05 suspend
## aussi R47 (ligne barrée propre au Rulebook) ; à la fin de la coupure, R47
## revient et FOUILLE OMISE s'applique de nouveau.
func test_qa063_blackout_does_not_cite_a_belt_search_that_cannot_be_done() -> void:
	var r47: ProcedureRule = data.rules[&"r_belt_search"]
	var found: Array = _find(19, func(_b: CaseBuilder, g: GeneratedCase) -> bool:
		return g.key.expected_verdict == VK.APPROVE and r47.requires_search(g.case))
	assert_false(found.is_empty(), "un Ceinturier au long séjour, en règle, au J19")
	if found.is_empty():
		return
	var g: GeneratedCase = found[1]
	var blackout: StationEventDef = _event(&"ev_05")
	assert_not_null(blackout)
	var day: DayDef = data.get_day(19).make_shift_copy()
	day.rule_set.apply_changes(blackout.changes, blackout.id)
	assert_false(day.rule_set.has_rule(&"r_search_cause"), "R44 retirée : portique hors tension")
	var verdict: Verdict = Verdict.new(g.case.case_id, VK.APPROVE)
	verdict.questions_asked = [InspectionSession.TOPIC_PURPOSE]
	assert_false(day.rule_set.has_rule(&"r_belt_search"), "R47 suspendue pendant la coupure")
	assert_eq(day.rule_set.retired_note_keys.get(&"r_belt_search", ""), "sev_blackout_rb_belt_search", "ligne du Rulebook")
	assert_ne(UiText.t("sev_blackout_rb_belt_search"), "sev_blackout_rb_belt_search", "texte présent dans fr.csv")
	var result: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, day)
	assert_ne(result.citation_reason_key, ScoringService.CIT_SEARCH_SKIPPED, "aucune FOUILLE OMISE sans portique")
	assert_true(result.correct, "approbation juste : aucune fouille n'était possible")
	var denied: CaseResult = ScoringService.score(Verdict.new(g.case.case_id, VK.DENY), g.key, g.case.case_id, g.case, day)
	assert_eq(denied.citation_reason_key, ScoringService.CIT_UNJUSTIFIED_DENIAL, "refuser un Ceinturier en règle reste injuste")
	# Ceinturier au long séjour **construit** pendant la coupure : verdict attendu
	# APPROUVÉ (aucune violation de fouille possible), aucune FOUILLE OMISE.
	var during: int = 0
	for group: int in 40:
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(19).make_shift_copy(), Gen.day_seed(33_000 + group, 19))
		builder.presentation_minute = 12 * 60
		builder.on_rules_changed(builder.ctx.apply_changes(blackout.changes, blackout.id))
		for i: int in builder.day.passenger_count:
			var built: GeneratedCase = builder.build(i)
			if built == null or built.scripted_id != &"" or not r47.applies_to(built.case):
				continue
			during += 1
			for v: Violation in built.key.expected_violations:
				assert_false(v.rule_id in [&"r_belt_search", &"r_contraband", &"r_weapons_detain"], "%s pendant la coupure" % v)
			if built.key.expected_verdict == VK.APPROVE:
				var ok: CaseResult = ScoringService.score(Verdict.new(built.case.case_id, VK.APPROVE), built.key,
						built.case.case_id, built.case, builder.day)
				assert_ne(ok.citation_reason_key, ScoringService.CIT_SEARCH_SKIPPED, "#%d pendant la coupure" % (i + 1))
	assert_gt(during, 0, "Ceinturiers au long séjour construits pendant la coupure")
	# Fin de la coupure : R47 revient, FOUILLE OMISE de nouveau.
	day.rule_set.revert_source(blackout.id)
	assert_true(day.rule_set.has_rule(&"r_belt_search"), "R47 rétablie après la coupure")
	var after: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, day)
	assert_eq(after.citation_reason_key, ScoringService.CIT_SEARCH_SKIPPED, "après la coupure : FOUILLE OMISE")


# ---------------------------------------------------------------------------
# QA-064 — « DÉCLARATION » discordante chez un passager qui n'a pas menti
# ---------------------------------------------------------------------------

## Passager honnête (employeur dit = employeur du permis) dont le Code du
## contrat ne correspond pas à l'employeur (R25, anomalie documentaire) : la
## puce employeur ↔ Code répondait « DISCORDANCE · DÉCLARATION »
## (`disc_statement_mismatch`), le bilan la comptait comme déclaration
## contradictoire et la confrontation `about_statement` s'ouvrait, alors que
## M13 §1.6 exige qu'un honnête ne produise jamais de puce discordante.
## Corrigé : discordance **documentaire** (`disc_mismatch`), qui documente R25.
func test_qa064_honest_chip_is_never_a_statement_mismatch() -> void:
	var found: Array = []
	for n: int in [12, 14, 16, 19, 22, 25]:
		found = _find(n, func(b: CaseBuilder, g: GeneratedCase) -> bool:
			if g.key.get_violated_rule_ids().has(&"r_statements"):
				return false
			var st: Statement = g.case.get_statement(Statement.ID_EMPLOYER)
			if st == null or not st.is_comparable():
				return false
			st.given = true
			var code: FieldRef = Rule.find_ref(g.case, &"work_contract", &"employer_code")
			return code != null and DiscrepancyChecker.check(g.case, st.get_ref(), code, b.ctx).result == Discrepancy.Result.DISCORDANT, 30)
		if not found.is_empty():
			break
	assert_false(found.is_empty(), "un honnête au contrat discordant (R25)")
	if found.is_empty():
		return
	var builder: CaseBuilder = found[0]
	var g: GeneratedCase = found[1]
	var st: Statement = g.case.get_statement(Statement.ID_EMPLOYER)
	var code: FieldRef = Rule.find_ref(g.case, &"work_contract", &"employer_code")
	var d: Discrepancy = DiscrepancyChecker.check(g.case, st.get_ref(), code, builder.ctx)
	assert_ne(g.key.expected_verdict, VK.APPROVE, "le passager est en infraction (autre anomalie)")
	assert_true(ScoringService.is_documented([d], g.key.expected_violations), "la paire documente quand même le refus")
	var documented_by: Array[StringName] = []
	for v: Violation in g.key.expected_violations:
		if v.is_documented_by(d):
			documented_by.append(v.rule_id)
	assert_false(documented_by.has(&"r_statements"), "le motif reste documentaire (R25) : %s" % [documented_by])
	assert_ne(d.reason_key, Discrepancy.REASON_STATEMENT_MISMATCH, "%s ↔ Code du contrat chez un honnête" % st)
	assert_eq(d.reason_key, Discrepancy.REASON_MISMATCH, "discordance documentaire")
	assert_ne(InspectionSession.family_of(d, g.case, builder.ctx), InspectionSession.FAMILY_STATEMENT,
			"la confrontation about_statement ne s'ouvre pas")
	# Bilan : aucune déclaration contradictoire comptée ; prime de relevé non due.
	var verdict: Verdict = Verdict.new(g.case.case_id, VK.DENY)
	verdict.flagged = [d] as Array[Discrepancy]
	var result: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day,
			ScoringService.DEFAULT_DETAIN_BONUS, false, 2)
	var summary: DaySummary = DaySummary.new()
	summary.add_result(result)
	assert_eq(summary.get_statement_mismatch_count(), 0, "bilan : aucune déclaration contradictoire")
	assert_false(ScoringService.is_m13_finding_pinned(verdict.flagged, g.key.expected_violations), "pas de prime de relevé")
	# La puce face à son document de référence (Employeur du permis) concorde.
	var primary: FieldRef = StatementsConsistentRule.active_in(builder.ctx.rule_set).primary_ref(g.case, st)
	if primary != null:
		assert_eq(DiscrepancyChecker.check(g.case, st.get_ref(), primary, builder.ctx).result, Discrepancy.Result.CONCORDANT,
				"la parole concorde avec le permis")


## QA-064 (affichage) : la même paire (puce employeur d'un honnête ↔ Code du
## contrat faux) s'écrit côté **document** au bandeau (« Contrat de travail ·
## Code … : … ≠ déclaré : … »), jamais « Déclaré : … ≠ … » ; la question
## débloquée n'est pas `about_statement` ; la réplique est figée comme toute
## discordance (« FIGÉE · DISCORDANCE »).
func test_qa064_document_fault_chip_is_written_as_a_document_discrepancy() -> void:
	UiText.ensure_translations()
	var found: Array = []
	for n: int in [12, 14, 16, 19, 22, 25]:
		found = _find(n, func(b: CaseBuilder, g: GeneratedCase) -> bool:
			if g.key.get_violated_rule_ids().has(&"r_statements"):
				return false
			var st: Statement = g.case.get_statement(Statement.ID_EMPLOYER)
			if st == null or not st.is_comparable():
				return false
			st.given = true
			var code: FieldRef = Rule.find_ref(g.case, &"work_contract", &"employer_code")
			return code != null and DiscrepancyChecker.check(g.case, st.get_ref(), code, b.ctx).result == Discrepancy.Result.DISCORDANT, 30)
		if not found.is_empty():
			break
	assert_false(found.is_empty(), "un honnête au contrat discordant (R25)")
	if found.is_empty():
		return
	var builder: CaseBuilder = found[0]
	var g: GeneratedCase = found[1]
	var st: Statement = g.case.get_statement(Statement.ID_EMPLOYER)
	var code: FieldRef = Rule.find_ref(g.case, &"work_contract", &"employer_code")
	var d: Discrepancy = DiscrepancyChecker.check(g.case, st.get_ref(), code, builder.ctx)
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate() as ComparisonUI
	add_child_autofree(ui)
	await wait_process_frames(1)
	ui.current_case = g.case
	var text: String = ui.describe(d)
	var stated: String = UiText.tf("disc_statement_mismatch_detail", ["", "", ""]).get_slice(":", 0)
	assert_false(text.begins_with(stated), "bandeau côté document, pas « %s » : « %s »" % [stated, text])
	var field: FieldDef = g.case.get_field_def(code)
	assert_string_contains(text, UiText.field_label(field), "champ du document nommé")
	assert_string_contains(text, UiText.value_text(field, g.case.get_value(code)), "valeur du document")
	assert_false(text.contains("disc_"), "jamais de clé brute")
	assert_false(String(InterrogationTopics.topic_for(d)).begins_with(String(InterrogationTopics.ABOUT_STATEMENT)),
			"pas de confrontation « Ce que vous dites… »")


# ---------------------------------------------------------------------------
# QA-065 — version
# ---------------------------------------------------------------------------

func test_qa065_version_is_0_13() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if not version.begins_with("0.13"):
		pending("QA-065 : config/version = %s (M13 = 0.13)" % version)
		return
	assert_true(version.begins_with("0.13"))


# ---------------------------------------------------------------------------
# Vérifications de la passe (vraies données)
# ---------------------------------------------------------------------------

## Cas scénarisés à puces (SC-104 → SC-111) : aucune puce discordante hors du
## mensonge déclaré, quel que soit le champ comparé, sur trois campagnes.
func test_scripted_chips_are_never_discordant_outside_their_lie() -> void:
	var checked: int = 0
	for campaign: int in [3, 43, 20_871_315]:
		for n: int in [4, 8, 9, 12, 16, 19, 22, 24]:
			var day: DayDef = data.get_day(n)
			var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(campaign, n), [],
					CaseMemory.resolve(data, day, campaign, {}))
			builder.presentation_minute = 12 * 60
			for g: GeneratedCase in builder.build_day():
				if g == null or g.scripted_id == &"" or g.case.statements.is_empty():
					continue
				var lying: Array[StringName] = []
				for v: Violation in g.key.expected_violations:
					for ref: FieldRef in v.refs:
						if ref.is_statement():
							lying.append(ref.get_statement_id())
				for st: Statement in g.case.statements:
					st.given = true
					for doc: DocumentInstance in g.case.documents:
						for field: FieldDef in doc.type_def.fields:
							var ref: FieldRef = FieldRef.new(doc.get_document_id(), field.id)
							if not g.case.has_field(ref):
								continue
							checked += 1
							var d: Discrepancy = DiscrepancyChecker.check(g.case, st.get_ref(), ref, builder.ctx)
							if d.result == Discrepancy.Result.DISCORDANT:
								assert_true(lying.has(st.id), "%s J%d : %s ↔ %s" % [g.scripted_id, n, st, ref.key()])
	assert_gt(checked, 100, "puces scénarisées comparées")


## EV-05 : aucune anomalie de fouille ni indice à partir de la coupure.
func test_blackout_window_has_no_search_anomaly_nor_cue() -> void:
	var blackout: StationEventDef = _event(&"ev_05")
	var day: DayDef = data.get_day(16)
	var seen: int = 0
	for group: int in 30:
		var builder: CaseBuilder = CaseBuilder.new(data, day.make_shift_copy(), Gen.day_seed(41_000 + group, 16))
		builder.presentation_minute = 12 * 60
		var start: int = 6
		for i: int in builder.day.passenger_count:
			if i == start:
				builder.day.rule_set.apply_changes(blackout.changes, blackout.id)
			var g: GeneratedCase = builder.build(i)
			if g == null or i < start or g.scripted_id != &"":
				continue
			seen += 1
			for a: Anomaly in g.key.anomalies:
				assert_false(a.type in [K.CONTRABAND, K.CONCEALED_IMPLANT, K.CONCEALED_WEAPON], "J16 #%d : %s pendant la coupure" % [i + 1, a.type])
			assert_true(g.case.search_cues.is_empty(), "aucun indice sans portique (#%d)" % (i + 1))
	assert_gt(seen, 100)


# ---------------------------------------------------------------------------
# QA-066 — EV-09 sans aucun passager du profil dans la fenêtre
# ---------------------------------------------------------------------------

## EV-09 (« fouille autorisée des ressortissants de X pour les cinq prochains
## passagers ») doit placer 1 ou 2 porteurs du profil dans sa fenêtre (M13
## §2.10). Avec un profil d'origine (Tycho, Cérès), les porteurs étaient pris
## parmi les passagers du roster **déjà de cette origine** : si aucun ne l'était
## dans la fenêtre, l'alerte était annoncée et restait sans objet (vraie scène :
## graine 14, J8, profil Cérès, fenêtre #10–#14 : Tycho, Tharsis, Tycho,
## Tharsis, Tycho). Corrigé : l'origine du profil est alors imposée à 1 ou 2
## passagers libres de la fenêtre. Mesure sur 300 campagnes réelles : chaque
## porteur imposé est construit, du profil, porteur de contrebande.
func test_qa066_every_contraband_alert_has_a_carrier_of_its_profile() -> void:
	var days: Dictionary[int, DayDef] = {}
	for n: int in range(1, 31):
		days[n] = data.get_day(n)
	var def: StationEventsDef = StationEventService.load_def()
	var plans: int = 0
	var empty: PackedStringArray = []
	var wrong: PackedStringArray = []
	for campaign: int in range(1, 301):
		var schedule: Dictionary[int, StationEventPlan] = StationEventService.schedule(campaign, def, days)
		for n: int in schedule:
			var plan: StationEventPlan = schedule[n]
			if plan.event.id != &"ev_09":
				continue
			plans += 1
			var builder: CaseBuilder = CaseBuilder.new(data, days[n].make_shift_copy(), SeededRng.day_seed(campaign, n))
			builder.presentation_minute = 12 * 60
			for i: int in plan.start_index:
				builder.build(i)
			# Comme le DayController à l'annonce (QA-066) : profil qui vise quelqu'un.
			builder.fit_alert_profile(plan)
			builder.on_rules_changed(builder.ctx.apply_changes(plan.changes(), plan.event.id))
			var carriers: int = 0
			var profile: Dictionary = plan.profile()
			for index: int in builder._forced:
				if StringName(str(builder._forced[index].get("rule_id", ""))) != &"r_search_cause":
					continue
				carriers += 1
				if index < plan.start_index or index >= plan.start_index + CaseBuilder.ALERT_WINDOW:
					wrong.append("graine %d J%d #%d hors fenêtre" % [campaign, n, index + 1])
					continue
				var built: GeneratedCase = builder.build(index)
				var presented: Passenger = built.case.passenger_presented
				var factions: Array = profile.get("faction_ids", [])
				var purposes: Array = profile.get("purposes", [])
				var fits: bool = (factions.is_empty() or factions.has(presented.faction_id)) \
						and (purposes.is_empty() or purposes.has(presented.purpose))
				var carries: bool = false
				for a: Anomaly in built.key.anomalies:
					carries = carries or a.type == K.CONTRABAND
				if not fits or not carries or not built.invariant_errors.is_empty():
					wrong.append("graine %d J%d #%d %s/%s contrebande=%s" % [campaign, n, index + 1, presented.faction_id,
							presented.purpose, carries])
			if carriers == 0:
				empty.append("graine %d J%d %s" % [campaign, n, plan.profile_label_key()])
	assert_gt(plans, 50, "alertes mesurées")
	gut.p("QA-066 : %d alertes sur %d sans porteur du profil (%s)" % [empty.size(), plans, Gen.head(empty)])
	assert_eq(empty.size(), 0, "alertes EV-09 sans porteur du profil : %s" % Gen.head(empty))
	assert_eq(wrong.size(), 0, "porteurs hors profil : %s" % Gen.head(wrong))


# ---------------------------------------------------------------------------
# QA-067 — prime de relevé versée sans trouvaille de M13
# ---------------------------------------------------------------------------

## D-169 / M13 §4.4 : la prime de relevé (2 ₵) récompense un refus fondé sur
## une **puce épinglée** ou un **objet révélé**. `ScoringService.is_m13_finding`
## ne lisait que les violations attendues : un menteur (AV) qui porte aussi une
## autre anomalie, refusé sur cette autre anomalie sans qu'aucune question ne
## soit posée, rapportait quand même la prime. Corrigé
## (`is_m13_finding_pinned`) : seule la trouvaille épinglée la rapporte.
func test_qa067_finding_bonus_needs_the_m13_finding_itself() -> void:
	var found: Array = []
	for n: int in [4, 5, 6, 9, 10, 12, 13, 14]:
		found = _find(n, func(_b: CaseBuilder, g: GeneratedCase) -> bool:
			if g.key.expected_verdict != VK.DENY or g.key.expected_violations.size() < 2:
				return false
			var has_lie: bool = false
			var has_other: bool = false
			for v: Violation in g.key.expected_violations:
				var m13: bool = ScoringService.is_m13_finding([v] as Array[Violation])
				has_lie = has_lie or m13
				has_other = has_other or (not m13 and v.refs.size() >= 2)
			return has_lie and has_other, 40)
		if not found.is_empty():
			break
	assert_false(found.is_empty(), "un menteur qui porte aussi une autre anomalie")
	if found.is_empty():
		return
	var builder: CaseBuilder = found[0]
	var g: GeneratedCase = found[1]
	var other: Violation = null
	for v: Violation in g.key.expected_violations:
		if not ScoringService.is_m13_finding([v] as Array[Violation]) and v.refs.size() >= 2:
			other = v
	# Refus documenté par l'autre anomalie (la vraie paire discordante), aucune question.
	var pinned: Discrepancy = null
	for i: int in other.refs.size():
		for j: int in range(i + 1, other.refs.size()):
			var d: Discrepancy = DiscrepancyChecker.check(g.case, other.refs[i], other.refs[j], builder.ctx)
			if pinned == null and d.confirmed:
				pinned = d
	assert_not_null(pinned, "l'autre violation s'épingle : %s" % other)
	if pinned == null:
		return
	var verdict: Verdict = Verdict.new(g.case.case_id, VK.DENY)
	verdict.flagged = [pinned] as Array[Discrepancy]
	var result: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day,
			ScoringService.DEFAULT_DETAIN_BONUS, false, 2)
	assert_true(result.correct, "refus juste et documenté")
	assert_eq(result.wage, ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day).wage,
			"pas de prime sans la trouvaille de M13 (%s, documenté par %s)" % [g.key.get_violated_rule_ids(), other.rule_id])
	# La trouvaille elle-même, épinglée (puce obtenue ou objet révélé), la rapporte.
	var lie: Violation = null
	for v: Violation in g.key.expected_violations:
		if ScoringService.is_m13_finding([v] as Array[Violation]):
			lie = v
	DaySimulator.obtain(g.case, lie.refs[0])
	DaySimulator.obtain(g.case, lie.refs[1])
	var finding: Discrepancy = DiscrepancyChecker.check(g.case, lie.refs[0], lie.refs[1], builder.ctx)
	assert_true(finding.confirmed, "la trouvaille s'épingle : %s" % lie)
	verdict.flagged = [pinned, finding] as Array[Discrepancy]
	var paid: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day,
			ScoringService.DEFAULT_DETAIN_BONUS, false, 2)
	assert_eq(paid.wage, result.wage + 2, "trouvaille épinglée : prime de relevé")


# ---------------------------------------------------------------------------
# QA-068 — répliques composées : grammaire et cohérence
# ---------------------------------------------------------------------------

## Réponses réellement générées (cadre + puces, J4 → J30) : aucune tournure
## agrammaticale (« pour je ne sais pas encore », « pour ça dépend du
## travail »), aucune réponse vague suivie d'une affirmation précise (« Quelques
## jours. Pas un jour de plus. », « … C'est ce qu'on m'a accordé. »), aucun
## « Mais » qui oppose une provenance à la même origine (« J'arrive de Tycho.
## Mais je suis de Tycho, oui. »), aucun employeur « chez le Bureau ».
func test_qa068_composed_answers_read_well() -> void:
	UiText.ensure_translations()
	var tr_fn: Callable = func(k: String) -> String: return UiText.t(k)
	var bad: PackedStringArray = []
	var seen: Dictionary[String, bool] = {}
	var rx: RegEx = RegEx.create_from_string(
			"pour (je|ça) |^(Quelques jours|Le temps du contrat|Je ne sais pas encore|Aussi longtemps qu'on voudra de moi|Ça dépend du travail)\\. (C'est ce qu'on m'a accordé|Pas un jour de plus)|J'arrive de (\\S+( \\S+)?)\\. Mais je suis de \\1,|chez le Bureau|Le temps du contrat, le temps du chantier")
	for group: int in 200:
		var n: int = 4 + group % 27
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(n), Gen.day_seed(52_000 + group, n))
		builder.presentation_minute = 12 * 60
		for g: GeneratedCase in builder.build_day():
			if g == null or g.case.statements.is_empty():
				continue
			for q: StringName in g.case.statement_frames:
				var line: String = Statement.compose(UiText.t(g.case.statement_frames[q]), g.case.statements_for_question(q), tr_fn)
				if seen.has(line):
					continue
				seen[line] = true
				if rx.search(line) != null:
					bad.append(line)
	assert_gt(seen.size(), 500, "répliques composées relues")
	assert_eq(bad.size(), 0, "%d / %d répliques composées mal tournées : %s" % [bad.size(), seen.size(), Gen.head(bad)])


# ---------------------------------------------------------------------------
# QA-069 — messages d'offre et de confiscation jamais affichés
# ---------------------------------------------------------------------------

## M13 §3.3 / §3.5 : AG-04, AG-05 (hors catalogue) et AG-06 « arrivent par un
## message du soir » (`msg_soute_drawer`, `msg_okonkwo_book`,
## `msg_vh_monitor`, portés par `UpgradeDef.offer_message_key`) ; la
## confiscation du tiroir est suivie de `msg_okonkwo_drawer_found`. Aucun
## script ne lisait `offer_message_key` ni ne posait `msg_okonkwo_drawer_found`
## (relecture des sources et des données). Corrigé : lettres d'offre du soir
## (`EveningService.offer_events`, une fois) et message après la confiscation
## (`EveningReport`), vérifiés sur la logique du soir.
func test_qa069_offer_and_drawer_messages_are_wired() -> void:
	var readers: PackedStringArray = []
	var drawer_msg: PackedStringArray = []
	var dirs: Array[String] = ["res://scripts"]
	while not dirs.is_empty():
		var dir_path: String = dirs.pop_back()
		var dir: DirAccess = DirAccess.open(dir_path)
		if dir == null:
			continue
		for sub: String in dir.get_directories():
			dirs.append(dir_path.path_join(sub))
		for file: String in dir.get_files():
			if not file.ends_with(".gd"):
				continue
			var path: String = dir_path.path_join(file)
			var text: String = FileAccess.get_file_as_string(path)
			if text.contains("offer_message_key") and not path.ends_with("upgrade_def.gd"):
				readers.append(path)
			if text.contains("msg_okonkwo_drawer_found"):
				drawer_msg.append(path)
	for day_n: int in range(1, 31):
		var day_path: String = "res://data/days/day_%02d.tres" % day_n
		if FileAccess.file_exists(day_path) and FileAccess.get_file_as_string(day_path).contains("msg_okonkwo_drawer_found"):
			drawer_msg.append(day_path)
	assert_ne(UiText.t("msg_okonkwo_book"), "msg_okonkwo_book", "texte présent dans fr.csv")
	assert_false(readers.is_empty(), "lecteurs de offer_message_key")
	assert_false(drawer_msg.is_empty(), "msg_okonkwo_drawer_found posé")
	var economy: EconomyDef = data.get_economy()
	# AG-05 : soir du J6 (Okonkwo présent), une seule fois ; AG-04 : après une enveloppe.
	var flags: Dictionary[StringName, Variant] = {&"bribe_seen": true}
	var keys: Array[String] = []
	for message: Dictionary in EveningService.offer_messages(economy, 6, flags):
		keys.append(str(message["text"]))
		assert_ne(UiText.t(str(message["speaker"])), str(message["speaker"]), "locuteur de %s" % message["text"])
	assert_true(keys.has("msg_okonkwo_book"), "AG-05 au soir du J6 : %s" % [keys])
	assert_true(keys.has("msg_soute_drawer"), "AG-04 (enveloppe vue) : %s" % [keys])
	var events: Array[EveningEvent] = EveningService.build_events([] as Array[EveningEventDef], flags, economy, 6)
	assert_eq(events.size(), keys.size(), "une lettre « CE SOIR » par offre")
	var report: EveningReport = EveningService.apply(economy, 6, Household.new(), [] as Array[ExpenseLine], 100, 1,
			events, {}, flags)
	for event: EveningEvent in events:
		assert_true(event.is_offer() and event.kind == EveningEventDef.Kind.LETTER, String(event.id))
		assert_true(report.event_texts.has(event.text_key), "%s remis au soir" % event.text_key)
	CaseConsequences.merge_into(flags, report.flag_changes)
	assert_eq(EveningService.offer_messages(economy, 7, flags).size(), 0, "message remis une seule fois")
	assert_eq(EveningService.offer_messages(economy, 5, {} as Dictionary[StringName, Variant]).size(), 0, "rien sans offre")
	var monitor: Array[String] = []
	for message: Dictionary in EveningService.offer_messages(economy, 11, flags):
		monitor.append(str(message["text"]))
	assert_eq(monitor, ["msg_vh_monitor"] as Array[String], "AG-06 au soir du J11")
	# Confiscation du tiroir à l'audit du J9 : message d'Okonkwo.
	var owner: Dictionary[StringName, Variant] = {&"upg_ag04": true}
	var audit: Dictionary = {}
	for traces: int in range(0, 8):
		owner[&"suspicion"] = traces
		audit = EndingService.audit_outcome(owner, economy)
		if bool(audit.get("drawer_found", false)):
			break
	assert_true(bool(audit.get("drawer_found", false)), "tiroir trouvé à l'audit")
	assert_eq(str(audit.get("drawer_message_key", "")), "msg_okonkwo_drawer_found")
	var audit_def: EveningEventDef = EveningEventDef.new()
	audit_def.id = &"qa069_audit"
	audit_def.kind = EveningEventDef.Kind.AUDIT
	var audit_event: EveningEvent = EveningEvent.new()
	audit_event.def = audit_def
	audit_event.id = audit_def.id
	audit_event.kind = audit_def.kind
	audit_event.audit = audit
	var audited: EveningReport = EveningService.apply(economy, 9, Household.new(), [] as Array[ExpenseLine], 100, 1,
			[audit_event] as Array[EveningEvent], {}, owner)
	assert_true(audited.event_texts.has("msg_okonkwo_drawer_found"), "message d'Okonkwo après la confiscation")
	assert_true(audited.has_event("msg_okonkwo_drawer_found"))


## QA-069 (affichage) : au soir du J6, la lettre d'offre du Recueil (AG-05)
## s'affiche dans « CE SOIR » — signée Okonkwo (icône et nom, pas la couleur
## seule), nom de l'amélioration, message, renvoi à l'Économat — et « VOIR
## L'OFFRE » (Ⓐ / Entrée) amène le focus à la ligne de l'Économat. La
## confiscation du tiroir est suivie du mot d'Okonkwo, signé, à l'audit et
## au rapport de la nuit.
func test_qa069_offer_letter_and_drawer_message_are_shown() -> void:
	UiText.ensure_translations()
	var day_number: int = 6
	var economy: EconomyDef = data.get_economy()
	var flags: Dictionary[StringName, Variant] = {}
	var home: Household = Household.new()
	var lines: Array[ExpenseLine] = EveningService.build_lines(economy, day_number, home, flags, 200)
	EveningService.default_selection(lines, 200)
	lines.append_array(EveningService.shop_lines(economy, day_number, flags))
	var events: Array[EveningEvent] = EveningService.build_events(data.get_day(day_number).evening_events, flags, economy, day_number)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(day_number), 200, 20, lines, home, false)
	screen.shop_flags = flags
	screen.set_events(events)
	add_child_autofree(screen)
	await wait_process_frames(2)
	var step: int = -1
	for i: int in screen.events.size():
		if screen.offer_upgrade(screen.events[i]) != null and screen.offer_upgrade(screen.events[i]).id == &"ag05":
			step = i
	assert_gte(step, 0, "lettre d'offre du Recueil parmi les événements du soir J6")
	if step < 0:
		return
	screen.show_step(step)
	await wait_process_frames(1)
	var card: Node = screen.find_child("EventCard", true, false)
	assert_not_null(card)
	var speaker: Node = card.find_child("Speaker", true, false)
	assert_not_null(speaker, "locuteur nommé")
	var texts: PackedStringArray = []
	for label: Label in card.find_children("*", "Label", true, false):
		texts.append(label.text)
	var all: String = " | ".join(texts)
	assert_string_contains(all, UiText.t("spk_okonkwo"), "signé Okonkwo")
	assert_string_contains(all, UiText.t("msg_okonkwo_book"), "message d'Okonkwo")
	assert_string_contains(all, UiText.t("upg_ag05_name"), "nom de l'amélioration")
	assert_false(all.contains("msg_okonkwo_book"), "jamais de clé brute")
	var go: Button = card.find_child("OfferGoto", true, false) as Button
	assert_not_null(go, "« VOIR L'OFFRE »")
	if go != null:
		assert_ne(go.focus_mode, Control.FOCUS_NONE, "atteignable au clavier / à la manette")
		go.pressed.emit()
		await wait_process_frames(1)
		assert_eq(get_viewport().gui_get_focus_owner(), screen.shop.get_row(&"ag05"), "focus sur la ligne de l'Économat")
	# Confiscation du tiroir : le mot d'Okonkwo, signé, au rapport de la nuit.
	var report: EveningReport = EveningReport.new()
	report.household = home
	report.add_event("msg_okonkwo_drawer_found", EveningReport.Tone.WARNING)
	screen.show_report(report, EveningReport.ENDING_NONE)
	await wait_process_frames(1)
	var signed: Node = screen.find_child("Signed_msg_okonkwo_drawer_found", true, false)
	assert_not_null(signed, "message signé au rapport")
	if signed != null:
		assert_not_null(signed.find_child("Speaker", true, false), "locuteur nommé au rapport")


# ---------------------------------------------------------------------------
# QA-070 — journal : ponctuation en début de ligne
# ---------------------------------------------------------------------------

## Vraie capture Deck, texte 1,5 (`m13_qa_journal_deck_text150.png`) :
## « Euh… » Je ne fais que passer. » Deux jours » puis, à la ligne,
## « , normalement. ». `DialogueJournal._add_words` crée un `Label` par mot :
## la ponctuation qui suit une puce est un enfant **à part** du
## `HFlowContainer`, que le flux peut renvoyer seul en tête de ligne (le
## commentaire « une ponctuation collée à une puce le reste » ne tient pas).
## Contrôle structurel (indépendant de la largeur) : aucune ponctuation ne
## doit suivre une puce comme élément séparable du flux. Corrigé : la
## ponctuation est posée dans un groupe insécable avec sa puce (`ChipGroup`),
## puce sans marge droite (`tight_end`).
func test_qa070_punctuation_never_starts_a_journal_line() -> void:
	UiText.ensure_translations()
	var journal: DialogueJournal = DialogueJournal.new()
	add_child_autofree(journal)
	await wait_process_frames(1)
	var stmts: Array[Statement] = [Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_TRANSIT, "stmt_purpose_transit_1"),
			Statement.duration(2, 2, "stmt_dur_d2")] as Array[Statement]
	var separable: PackedStringArray = []
	for frame_key: String in ["line_stmt_frame_gen_2", "line_stmt_frame_gen_3", "line_stmt_frame_cer_2", "line_stmt_frame_tyc_1"]:
		var entry: Dictionary = journal.add_statement_line(UiText.t(frame_key), stmts)
		var flow: HFlowContainer = null
		for child: Node in (entry["node"] as Node).get_children():
			if child is HFlowContainer:
				flow = child
		var children: Array[Node] = flow.get_children()
		var punct: RegEx = RegEx.create_from_string("^[\\s\u00a0]*[,.;:…?!»]")
		for k: int in range(1, children.size()):
			var label: Label = children[k] as Label
			if children[k - 1] is StatementChipView and label != null and punct.search(label.text) != null:
				separable.append("%s : « %s »" % [frame_key, label.text])
		# Correction : la ponctuation est dans le groupe insécable de sa puce,
		# sans espace avant (« passer. », jamais « passer . »).
		var glued: int = 0
		for chip: StatementChipView in entry["chips"]:
			var group: Node = chip.get_parent()
			if group == flow:
				continue
			assert_true(group is BoxContainer, "%s : puce et ponctuation dans un groupe insécable" % frame_key)
			var mark: Label = group.get_child(chip.get_index() + 1) as Label
			assert_not_null(mark, "%s : ponctuation juste après la puce" % frame_key)
			if mark != null:
				assert_not_null(punct.search(mark.text), "%s : « %s »" % [frame_key, mark.text])
				assert_false(mark.text.begins_with(" "), "%s : pas d'espace avant « %s »" % [frame_key, mark.text])
			assert_true(chip.tight_end, "%s : pas de marge entre la puce et sa ponctuation" % frame_key)
			glued += 1
		assert_gt(glued, 0, "%s : au moins une ponctuation collée à sa puce" % frame_key)
	assert_eq(separable.size(), 0, "ponctuation séparable de sa puce : %s" % Gen.head(separable))


# ---------------------------------------------------------------------------
# QA-071 — Rulebook au Deck, texte 1,5 : onglet « Contrebande · NOUV. »
# ---------------------------------------------------------------------------

## Vraie capture Deck, texte 1,5 (`m13_qa_contraband_deck_text150.png`) : au
## J8, l'onglet « Contrebande ·NOUV. » (10 / 10), plus large que la rangée
## d'onglets, était aligné sur son bord droit et coupé à gauche sous
## l'invite « [ » (le « C » disparaissait). Chaque onglet courant doit tenir
## **entier** dans la rangée visible, commencer par le début de son titre et
## garder son repère « NOUV. » (texte, pas seulement l'ambre).
func test_qa071_contraband_tab_is_never_cut_on_deck_at_text_150() -> void:
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	# Deck : fenêtre 1280×800 → vue logique 1920×1200, plancher de texte.
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1920, 1200)
	vp.disable_3d = true
	add_child_autofree(vp)
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate() as ComparisonUI
	vp.add_child(ui)
	var day: DayDef = data.get_day(8)
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	ui.emulate_screen_scale(1280.0 / 1920.0)
	await wait_process_frames(3)
	var rulebook: RulebookPanel = ui.rulebook
	assert_true(rulebook.visible_reference_tabs().has(RulebookReference.TAB_CONTRABAND), "onglet Contrebande au J8")
	var strip: ScrollContainer = rulebook.find_child("Tabs", true, false) as ScrollContainer
	assert_not_null(strip, "rangée d'onglets")
	var title: String = RulebookReference.tab_title(RulebookReference.TAB_CONTRABAND)
	var new_mark: String = UiText.t("rb_tab_new", "NEW")
	assert_true(rulebook.show_reference_tab(RulebookReference.TAB_CONTRABAND))
	await wait_process_frames(3)
	var tab: Button = rulebook.find_child("Tab_%s" % RulebookReference.TAB_CONTRABAND, true, false) as Button
	assert_not_null(tab, "bouton de l'onglet Contrebande")
	var view: Rect2 = strip.get_global_rect().grow(1.0)
	assert_true(view.encloses(tab.get_global_rect()), "onglet entier dans la rangée : %s dans %s" % [tab.get_global_rect(), view])
	assert_true(tab.text.begins_with(title.substr(0, 1)), "début du titre visible : « %s »" % tab.text)
	assert_true(tab.text.contains(new_mark), "repère « %s » gardé : « %s »" % [new_mark, tab.text])
	assert_true(tab.tooltip_text.contains(title), "titre complet en infobulle : « %s »" % tab.tooltip_text)
	# Tous les onglets, l'un après l'autre (`]`), entiers quand ils sont courants.
	for i: int in 12:
		rulebook.cycle_tab(1)
		await wait_process_frames(3)
		# La rangée change de largeur avec le compteur « n / N ▾ ».
		view = strip.get_global_rect().grow(1.0)
		for button: Button in rulebook.find_children("*", "Button", true, false):
			if button.get_parent() != null and button.get_parent().get_parent() == strip and button.button_pressed:
				assert_true(view.encloses(button.get_global_rect()), "onglet courant « %s » entier : %s dans %s (défilement %d)" % [
						button.text, button.get_global_rect(), view, strip.scroll_horizontal])
	Settings.clear_session_value(Settings.KEY_TEXT_SCALE)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


# ---------------------------------------------------------------------------
# Sauvegardes réelles 0.12.0 (v6) reprises en 0.13
# ---------------------------------------------------------------------------

## Sauvegardes écrites par la 0.12.0 (`git archive f6d5f35`, campagne réelle
## graine 5) : avant le J4, avant le J8, après le J8. Elles se relisent sans
## migration (v6 inchangée, M13 §6.5), sans amélioration possédée, et le jour
## repris construit ses passagers M13 (déclarations dès le J4, fouille dès le J8).
func test_real_0_12_saves_resume_with_m13() -> void:
	var saved: Dictionary = GameState.to_save_dict()
	for spec: Array in [["qa_save_v6_012_j03.json", 3], ["qa_save_v6_012_j07.json", 7], ["qa_save_v6_012_j09.json", 9]]:
		var text: String = FileAccess.get_file_as_string("res://tests/fixtures/" + spec[0])
		var raw: Variant = JSON.parse_string(text)
		assert_true(raw is Dictionary, spec[0])
		var dict: Dictionary = raw
		assert_eq(int(dict.get("version", 0)), 6, "%s : sauvegarde v6" % spec[0])
		assert_eq(str(dict.get("game_version", "")), "0.12.0", "%s : écrite par la 0.12.0" % spec[0])
		assert_eq(SaveService.validate(SaveService.migrate(dict)), "", "%s : valide en 0.13" % spec[0])
		GameState.apply_save_dict(dict)
		assert_eq(GameState.current_day, spec[1], spec[0])
		for id: StringName in [&"ag01", &"ag02", &"ag03", &"ag04", &"ag05", &"ag06"]:
			assert_false(GameState.has_upgrade(id), "%s : %s non possédée" % [spec[0], id])
		var round_trip: Dictionary = GameState.to_save_dict()
		assert_eq(round_trip["narrative_flags"].size(), (dict["narrative_flags"] as Dictionary).size(), "%s : drapeaux relus" % spec[0])
		# Jour suivant construit avec la mémoire et les drapeaux de la partie 0.12.
		var n: int = maxi(GameState.current_day, 4)
		var day: DayDef = data.get_day(n)
		var builder: CaseBuilder = CaseBuilder.new(data, day, SeededRng.day_seed(GameState.campaign_seed, n), [],
				CaseMemory.resolve(data, day, GameState.campaign_seed, GameState.case_memory), GameState.narrative_flags)
		builder.presentation_minute = 12 * 60
		var with_statements: int = 0
		var with_layout: int = 0
		for g: GeneratedCase in builder.build_day():
			assert_eq(g.invariant_errors, PackedStringArray(), "%s J%d %s" % [spec[0], n, g.case.case_id])
			with_statements += 1 if not g.case.statements.is_empty() else 0
			with_layout += 1 if g.case.search_layout != null else 0
		assert_gt(with_statements, 0, "%s : déclarations au J%d" % [spec[0], n])
		if n >= 8:
			assert_gt(with_layout, 0, "%s : fouille au J%d" % [spec[0], n])
	GameState.apply_save_dict(saved)
