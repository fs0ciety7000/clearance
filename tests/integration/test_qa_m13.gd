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
## mais R47 reste dans le RuleSet : approuver un Ceinturier au long séjour vaut
## FOUILLE OMISE alors que le joueur ne peut pas fouiller (le seul autre verdict,
## REFUSÉ, est un REFUS INJUSTIFIÉ).
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
	var result: CaseResult = ScoringService.score(verdict, g.key, g.case.case_id, g.case, day)
	if result.citation_reason_key == ScoringService.CIT_SEARCH_SKIPPED:
		pending("QA-063 : FOUILLE OMISE citée pendant la coupure EV-05 (R47 reste active sans portique)")
		return
	assert_true(result.correct, "approbation juste : aucune fouille n'était possible")


# ---------------------------------------------------------------------------
# QA-064 — « DÉCLARATION » discordante chez un passager qui n'a pas menti
# ---------------------------------------------------------------------------

## Passager honnête (employeur dit = employeur du permis) dont le Code du
## contrat ne correspond pas à l'employeur (R25, anomalie documentaire) : la
## puce employeur ↔ Code répond « DISCORDANCE · DÉCLARATION »
## (`disc_statement_mismatch`), le bilan la compte comme déclaration
## contradictoire et la confrontation `about_statement` s'ouvre, alors que
## M13 §1.6 exige qu'un honnête ne produise jamais de puce discordante.
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
	if found.is_empty():
		pass_test("aucun honnête au contrat discordant trouvé (rien à signaler)")
		return
	var builder: CaseBuilder = found[0]
	var g: GeneratedCase = found[1]
	var st: Statement = g.case.get_statement(Statement.ID_EMPLOYER)
	var code: FieldRef = Rule.find_ref(g.case, &"work_contract", &"employer_code")
	var d: Discrepancy = DiscrepancyChecker.check(g.case, st.get_ref(), code, builder.ctx)
	assert_ne(g.key.expected_verdict, VK.APPROVE, "le passager est en infraction (autre anomalie)")
	assert_true(ScoringService.is_documented([d], g.key.expected_violations), "la paire documente quand même le refus")
	if d.reason_key == Discrepancy.REASON_STATEMENT_MISMATCH:
		pending("QA-064 : %s ↔ Code du contrat = DISCORDANCE « déclaration » chez un honnête (%s)" % [st, g.key.get_violated_rule_ids()])
		return
	assert_ne(d.reason_key, Discrepancy.REASON_STATEMENT_MISMATCH)


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
## §2.10). Avec un profil d'origine (Tycho, Cérès), les porteurs sont pris
## parmi les passagers du roster **déjà de cette origine** : si aucun ne l'est
## dans la fenêtre, l'alerte est annoncée et reste sans objet (vraie scène :
## graine 14, J8, profil Cérès, fenêtre #10–#14 : Tycho, Tharsis, Tycho,
## Tharsis, Tycho). Mesure sur 300 campagnes réelles.
func test_qa066_every_contraband_alert_has_a_carrier_of_its_profile() -> void:
	var days: Dictionary[int, DayDef] = {}
	for n: int in range(1, 31):
		days[n] = data.get_day(n)
	var def: StationEventsDef = StationEventService.load_def()
	var plans: int = 0
	var empty: PackedStringArray = []
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
			builder.on_rules_changed(builder.ctx.apply_changes(plan.changes(), plan.event.id))
			var carriers: int = 0
			for index: int in builder._forced:
				if StringName(str(builder._forced[index].get("rule_id", ""))) == &"r_search_cause":
					carriers += 1
			if carriers == 0:
				empty.append("graine %d J%d %s" % [campaign, n, plan.profile_label_key()])
	assert_gt(plans, 50, "alertes mesurées")
	gut.p("QA-066 : %d alertes sur %d sans porteur du profil (%s)" % [empty.size(), plans, Gen.head(empty)])
	if not empty.is_empty():
		pending("QA-066 : %d / %d alertes EV-09 sans aucun porteur du profil dans la fenêtre" % [empty.size(), plans])
		return
	assert_eq(empty.size(), 0)


# ---------------------------------------------------------------------------
# QA-067 — prime de relevé versée sans trouvaille de M13
# ---------------------------------------------------------------------------

## D-169 / M13 §4.4 : la prime de relevé (2 ₵) récompense un refus fondé sur
## une **puce épinglée** ou un **objet révélé**. `ScoringService.is_m13_finding`
## ne lit que les violations attendues : un menteur (AV) qui porte aussi une
## autre anomalie, refusé sur cette autre anomalie sans qu'aucune question ne
## soit posée, rapporte quand même la prime.
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
	if result.wage > ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day).wage:
		pending("QA-067 : prime de relevé versée sans puce épinglée ni objet révélé (%s, documenté par %s)" % [
				g.key.get_violated_rule_ids(), other.rule_id])
		return
	assert_eq(result.wage, ScoringService.score(verdict, g.key, g.case.case_id, g.case, builder.day).wage)


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
	if not bad.is_empty():
		pending("QA-068 : %d / %d répliques composées mal tournées : %s" % [bad.size(), seen.size(), Gen.head(bad)])
		return
	assert_eq(bad.size(), 0)


# ---------------------------------------------------------------------------
# QA-069 — messages d'offre et de confiscation jamais affichés
# ---------------------------------------------------------------------------

## M13 §3.3 / §3.5 : AG-04, AG-05 (hors catalogue) et AG-06 « arrivent par un
## message du soir » (`msg_soute_drawer`, `msg_okonkwo_book`,
## `msg_vh_monitor`, portés par `UpgradeDef.offer_message_key`) ; la
## confiscation du tiroir est suivie de `msg_okonkwo_drawer_found`. Aucun
## script ne lit `offer_message_key` ni ne pose `msg_okonkwo_drawer_found`
## (relecture des sources et des données) : ces textes ne s'affichent jamais.
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
	if readers.is_empty() or drawer_msg.is_empty():
		pending("QA-069 : messages d'offre (lecteurs de offer_message_key : %d) et de confiscation (%d) jamais affichés" % [
				readers.size(), drawer_msg.size()])
		return
	assert_false(readers.is_empty())


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
## doit suivre une puce comme élément séparable du flux.
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
		for k: int in range(1, children.size()):
			var label: Label = children[k] as Label
			if children[k - 1] is StatementChipView and label != null \
					and RegEx.create_from_string("^[,.;:…?!»]").search(label.text) != null:
				separable.append("%s : « %s »" % [frame_key, label.text])
	if not separable.is_empty():
		pending("QA-070 : ponctuation séparable de sa puce dans le journal (%s)" % Gen.head(separable))
		return
	assert_eq(separable.size(), 0)


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
