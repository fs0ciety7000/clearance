## Passe QA M15 « Monde » et recette 1.0 RC (docs/QA.md §18) : non-régression
## et bugs QA-081 → (`pending` tant qu'ils ne sont pas corrigés : chaque test
## décrit le comportement attendu et se met en attente avec sa référence s'il
## échoue encore). QA ne corrige pas le code de jeu.
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")
const HotLanguage := preload("res://tests/integration/test_m15_hot_language.gd")
const UI_SCENE: PackedScene = preload("res://scenes/ui/comparison_ui.tscn")

var ui: ComparisonUI = null
var session: InspectionSession = null
var ctx: RuleContext = null


func before_all() -> void:
	# Remplit la table « texte français → clé » du test de bascule à chaud.
	var probe: GutTest = HotLanguage.new()
	probe.before_all()
	probe.free()


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)


func after_each() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)


func _shift_ui(day_number: int = 8) -> void:
	ui = UI_SCENE.instantiate() as ComparisonUI
	add_child_autofree(ui)
	session = InspectionSession.new()
	add_child_autofree(session)
	session.set_process(false)
	var day: DayDef = CaseFactory.catalog().get_day(day_number)
	ctx = CaseFactory.context(day.rule_set.make_shift_copy())
	ui.rule_context_provider = func() -> RuleContext: return ctx
	EventBus.day_started.emit(day, day.rule_set.build_rulebook())
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	await wait_process_frames(2)


func _present(index: int) -> void:
	var c: Case = CaseFactory.valid_case()
	c.index = index
	c.case_id = StringName("qa15_case_%d" % index)
	session.begin(c, ctx)
	session.configure(InterrogationTiming.new(), {} as Dictionary[StringName, Variant])
	EventBus.case_presented.emit(c)
	EventBus.day_phase_changed.emit(DayPhase.Kind.ARRIVING, c.case_id)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INSPECTING, c.case_id)
	EventBus.documents_presented.emit(c.case_id)
	await wait_process_frames(2)


# ---------------------------------------------------------------------------
# Non-régression (doivent passer)
# ---------------------------------------------------------------------------

## D-224 : même graine → mêmes cas, quelle que soit la langue (CaseKey, documents,
## anomalies, cadres de déclaration). Jours 1, 8, 13, 19, 24, 27.
func test_same_seed_same_cases_in_both_languages() -> void:
	var fr: PackedStringArray = _generated_signature()
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	var en: PackedStringArray = _generated_signature()
	assert_gt(fr.size(), 50, "témoin : des cas ont bien été générés")
	assert_eq(en.size(), fr.size())
	var diffs: PackedStringArray = []
	for i: int in mini(fr.size(), en.size()):
		if fr[i] != en[i]:
			diffs.append("%s\n  ≠ %s" % [fr[i], en[i]])
	assert_eq(diffs.size(), 0, "cas différents selon la langue :\n%s" % "\n".join(diffs.slice(0, 5)))


func _generated_signature() -> PackedStringArray:
	var out: PackedStringArray = []
	var catalog: DataCatalog = CaseFactory.catalog()
	for day_number: int in [1, 8, 13, 19, 24, 27]:
		var day: DayDef = catalog.get_day(day_number)
		var builder: CaseBuilder = CaseBuilder.new(catalog, day, 4242 + day_number)
		for generated: GeneratedCase in builder.build_day():
			out.append("J%d %s frames=%s" % [day_number, CaseSerializer.to_json(generated),
					JSON.stringify(generated.case.statement_frames, "", true)])
	return out


# ---------------------------------------------------------------------------
# Bugs ouverts (pending tant qu'ils échouent)
# ---------------------------------------------------------------------------

## QA-083 : un texte affiché qui contient « [ » sans « ] » (infobulles des onglets
## du Rulebook « Onglet précédent ( [ · LB ) » dont la recette a été oubliée, texte
## tapé lettre à lettre…) fait boucler `Localization.retranslate_text` jusqu'au
## dépassement de pile (texte vidé en debug ; plantage natif en release, §18).
## Attendu : texte rendu tel quel, sans erreur. Sondé dans un processus séparé
## (`qa_m15_probe.gd`) : le dépassement dérègle la pile de GDScript du processus.
func test_qa083_retranslate_survives_unbalanced_bracket() -> void:
	var samples: PackedStringArray = ["Onglet précédent ( [ · LB )", "[serre son sac", "Bonjour ["]
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script",
			"res://tools/qa_boot.gd", "--", "--qa-node=res://tests/qa_drivers/qa_m15_probe.gd"]
	for text: String in samples:
		args.append("--text=" + text)
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var log_text: String = "\n".join(output)
	assert_true(log_text.contains("QA15_PROBE_DONE"), "la sonde a tourné (code %d)" % code)
	var bad: PackedStringArray = []
	for line: String in log_text.split("\n"):
		if line.begins_with("QA15_PROBE in="):
			var parts: PackedStringArray = line.trim_prefix("QA15_PROBE in=").split(" out=")
			if parts.size() == 2 and parts[0] != parts[1]:
				bad.append("%s → %s" % [parts[0], parts[1]])
	var overflow: bool = log_text.contains("Stack overflow")
	if bad.is_empty() and not overflow:
		assert_true(true, "textes à crochet isolé rendus tels quels, sans erreur")
	else:
		pending("QA-083 : retraduction d'un texte à « [ » isolé : dépassement de pile=%s, %s" % [overflow, ", ".join(bad)])


## QA-084 : bascules répétées en plein shift ; après chaque bascule, puis après le
## passager suivant, aucun texte visible du guichet ne doit être resté dans l'autre
## langue. `DocFieldView.display_label` n'est pas recomposé : l'infobulle (et le
## libellé d'un champ épinglé) d'un champ existant au moment de la bascule
## reviennent à l'ancienne langue au rafraîchissement suivant (ligne « DATE DU
## JOUR » du Rulebook à chaque passager ; champs des documents posés).
func test_qa084_documents_follow_language_across_passengers() -> void:
	await _shift_ui()
	var report: PackedStringArray = []
	for i: int in 4:
		var lang: String = Localization.LANG_EN if i % 2 == 0 else Localization.LANG_FR
		await _present(i * 2)
		Settings.set_session_value(Settings.KEY_LANGUAGE, lang)
		await wait_process_frames(2)
		report.append_array(_leftovers("après bascule %s (passager %d)" % [lang, i * 2]))
		await _present(i * 2 + 1)
		report.append_array(_leftovers("passager suivant %d en %s" % [i * 2 + 1, lang]))
	if report.is_empty():
		assert_true(true, "aucun texte dans l'autre langue")
	else:
		pending("QA-084 : %d textes revenus à l'ancienne langue, ex. %s" % [report.size(), report[0]])


func _leftovers(where: String) -> PackedStringArray:
	var out: PackedStringArray = []
	if Localization.is_english():
		for line: String in HotLanguage.french_leftovers(ui):
			out.append("%s : %s" % [where, line])
	return out


## QA-081 : en anglais, le nom d'un document écrit dans une phrase garde son sigle
## (« ID card », jamais « id card » ni « Id card ») : question « Your id card has
## expired… », détail de discordance « Id card expired: … » (aussi relayé par la
## suggestion de la borne ACV-2). `to_lower()` / `_sentence_case` cassent « ID ».
func test_qa081_english_document_names_keep_their_acronym() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	var c: Case = CaseFactory.valid_case()
	var question: String = InterrogationTopics.question_text(
			StringName("about_expired" + InterrogationTopics.DOC_SEPARATOR + "id_card"), c)
	var title: String = UiText.document_title(CaseFactory.doc_def(CaseFactory.ID_CARD))
	var detail_name: String = ComparisonUI._sentence_case(title)
	var bad: PackedStringArray = []
	if not question.contains("ID card") and not question.contains("ID Card"):
		bad.append("question « %s »" % question)
	if not detail_name.begins_with("ID"):
		bad.append("détail « %s… »" % detail_name)
	assert_eq(title, "ID Card", "témoin : titre anglais du glossaire")
	if bad.is_empty():
		assert_true(true)
	else:
		pending("QA-081 : sigle « ID » perdu dans les phrases anglaises — %s" % ", ".join(bad))


## QA-082 : les valeurs écrites en dur dans les cas scénarisés restent en français
## en anglais. Le contrat du chat Mistigri (SC-27, J12) porte « (FÉLIN) » comme
## prénom : la plaisanterie est illisible en anglais (attendu : « (FELINE) », par
## une valeur de `UiText.DATA_TEXT_KEYS` comme « SANS EMPLOYEUR »).
func test_qa082_scripted_joke_values_are_translated() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	var keys: Dictionary = UiText.DATA_TEXT_KEYS
	if keys.has("(FÉLIN)"):
		assert_ne(UiText.t(str(keys["(FÉLIN)"]), "(FÉLIN)"), "(FÉLIN)")
	else:
		pending("QA-082 : « (FÉLIN) » (contrat de travail du chat, SC-27) affiché tel quel en anglais")


## QA-085 : une règle suspendue par un événement de station affiche sa note par
## `RuleCardView.setup` → `UiText.t(note_key)` **sans arguments** : EV-01 (lecteur
## MRZ en panne) montre « R21 SUSPENDUE · LECTEUR HS (passagers restants : %d) »
## dans le Rulebook (FR comme EN, depuis la 0.12). Attendu : aucune note de
## règle à spécificateur non résolu.
func test_qa085_rule_notes_of_station_events_have_no_raw_specifier() -> void:
	var bad: PackedStringArray = []
	var dir: DirAccess = DirAccess.open("res://data/events")
	assert_not_null(dir)
	for file: String in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var def: StationEventDef = load("res://data/events/" + file) as StationEventDef
		if def == null:
			continue
		for change: RuleChangeDef in def.changes:
			if change.note_key.is_empty():
				continue
			for lang: String in Localization.LANGUAGES:
				Settings.set_session_value(Settings.KEY_LANGUAGE, lang)
				var note: String = UiText.t(change.note_key, "")
				if not Localization.format_specs(note).is_empty():
					bad.append("%s %s [%s] « %s »" % [def.id, change.rule_id, lang, note])
	if bad.is_empty():
		assert_true(true, "notes de règle sans spécificateur brut")
	else:
		pending("QA-085 : note de règle affichée avec « %%d » brut — %s" % "; ".join(bad))


## QA-086 : textes non retraduits à chaud (restent dans l'ancienne langue jusqu'à
## l'écran suivant). Mécanisme le plus fréquent : une clé absente rendue par son
## **repli déjà traduit** (`UiText.t(clé_variante, UiText.t(clé))`) — la recette
## garde le repli figé : notes du foyer (`hh_note_<id>_<état>` → `hh_note_<id>`),
## nom d'objet de fouille… Autres restes vus en jeu : bouton « SIGNALER AU
## CONSORTIUM +10 ₵ » de la soirée, « Le passager répond », didascalie du
## passager, réponse du journal (« Euh… », « normalement. »), notes de règles
## suspendues par la coupure (§18).
func test_qa086_household_notes_follow_hot_language_switch() -> void:
	var home: Household = Household.new()
	var bad: PackedStringArray = []
	for member: Household.Member in home.members:
		Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
		var shown: String = HouseholdView.member_note(member)
		if shown.is_empty():
			continue
		Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
		var expected: String = HouseholdView.member_note(member)
		var remade: String = Localization.retranslate_text(shown)
		if remade != expected:
			bad.append("%s : « %s » au lieu de « %s »" % [member.id, remade, expected])
	if bad.is_empty():
		assert_true(true)
	else:
		pending("QA-086 : textes figés dans l'ancienne langue après la bascule — %s" % "; ".join(bad))


## QA-089 : la démo accepte une sauvegarde au-delà du J5. `SaveService.validate`
## borne le jour par `last_day()` (30, les `DayDef` du paquet) et non par
## `DemoMode.last_day` ; `DemoMode.is_locked_day` n'est appelé nulle part. Une
## sauvegarde du jeu complet copiée dans `user://demo/saves` (même dossier
## utilisateur) ou un `current.json` retouché ouvre les jours 6–30 dans la démo
## (contenu présent dans le paquet, D-223). Attendu : refusée (ou bornée au J5).
func test_qa089_demo_refuses_a_save_beyond_day_5() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/qa_save_v6_013_j19.json"))
	assert_true(data is Dictionary, "témoin : vraie sauvegarde 0.13 du J19")
	DemoMode.force = 0
	assert_eq(SaveService.validate(data), "", "témoin : valide dans le jeu complet")
	DemoMode.force = 1
	var verdict: String = SaveService.validate(data)
	var day6: Dictionary = (data as Dictionary).duplicate(true)
	day6["current_day"] = 6
	var verdict6: String = SaveService.validate(day6)
	DemoMode.force = -1
	if not verdict.is_empty() and not verdict6.is_empty():
		assert_true(true, "démo : sauvegardes J6+ refusées")
	else:
		pending("QA-089 : la démo accepte une sauvegarde du J19 (« %s ») et du J6 (« %s »)" % [verdict, verdict6])


## QA-093 : mise à jour 0.14 → 0.15. Un `settings.cfg` écrit par la 0.14 n'a pas
## de clé `language` : la langue devient celle du système. Un joueur français
## dont le système est en anglais (Steam Deck : `en_US` par défaut) bascule en
## anglais à la mise à jour, sans l'avoir demandé. Attendu (proposition) : un
## `settings.cfg` antérieur sans langue garde le français, langue de ses parties.
## Mesurable seulement quand la langue du système est l'anglais.
func test_qa093_upgraded_0_14_settings_keep_french() -> void:
	var dir: String = "user://test_qa_m15"
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("settings_014.cfg")
	var cfg: ConfigFile = ConfigFile.new()
	for key: String in ["volume_master", "volume_music", "text_scale", "subtitles", "holo_flicker", "tutorial_j1",
			"music_inspection_reduce", "music_dynamics", "cinematic_advance"]:
		cfg.set_value("settings", key, 1.0 if key.begins_with("volume") or key == "text_scale" else true)
	cfg.save(path)
	var previous: String = Settings.settings_path
	Settings.clear_session_value(Settings.KEY_LANGUAGE)
	Settings.use_storage(path)
	var lang: String = Settings.language
	Settings.use_storage(previous)
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if Localization.system_language() != Localization.LANG_EN:
		pass_test("système en français : non mesurable ici")
	elif lang == Localization.LANG_FR:
		assert_eq(lang, Localization.LANG_FR)
	else:
		pending("QA-093 : réglages 0.14 sans langue → « %s » (langue du système) à la mise à jour" % lang)


## QA-094 : rapport « LA NUIT AU BLOC PÉTREL » — une lettre à valeur (prélèvement
## du J11 « 30 % de votre épargne… : %d ₵ », du J25 « 20 %… pour l'air de
## Tycho ») est relayée par `EveningService` (`report.add_event(event.text_key)`)
## sans ses `text_args` ; `EveningScreen._event_row` ne substitue que `%s` :
## « %d » brut à l'écran (vu en campagne réelle, J25, FR comme EN).
func test_qa094_night_report_rows_have_no_raw_specifier() -> void:
	var bad: PackedStringArray = []
	for key: String in ["evt_d11_levy_text", "evt_d25_levy_text"]:
		for lang: String in Localization.LANGUAGES:
			Settings.set_session_value(Settings.KEY_LANGUAGE, lang)
			var screen: EveningScreen = EveningScreen.new()
			var row: Control = screen.call(&"_event_row", {"key": key, "member": &"", "tone": EveningReport.Tone.INFO})
			var texts: PackedStringArray = []
			for node: Node in row.find_children("*", "Label", true, false):
				texts.append((node as Label).text)
			var shown: String = " ".join(texts)
			if not Localization.format_specs(shown).is_empty():
				bad.append("%s [%s] « %s »" % [key, lang, shown.left(80)])
			row.free()
			screen.free()
	if bad.is_empty():
		assert_true(true)
	else:
		pending("QA-094 : « %%d » brut dans le rapport de la nuit — %s" % "; ".join(bad))


## QA-087 : répliques anglaises affichées entre guillemets droits (`ui_quoted`
## → "…") qui contiennent elles-mêmes des guillemets droits doubles : « "Thank
## you. You said "next", last time." » (65 répliques). Attendu (guide de style
## à compléter) : guillemets simples à l'intérieur (‘next’ / 'next').
func test_qa087_english_dialogue_has_no_nested_double_quotes() -> void:
	var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
	var re: RegEx = RegEx.create_from_string("^(sc|line|bark|react|ans|okonkwo|sato|j31|cue)")
	var nested: PackedStringArray = []
	for key: String in en:
		if re.search(key) != null and str(en[key]).contains("\""):
			nested.append(key)
	if nested.is_empty():
		assert_true(true)
	else:
		pending("QA-087 : %d répliques à guillemets doubles imbriqués, ex. %s" % [nested.size(), ", ".join(nested.slice(0, 4))])


## QA-088 : version non montée pour la 0.15 / 1.0 RC : `config/version` vaut
## encore « 0.14.0 » (archives `CLEARANCE-0.14.0-*`, « Démo · v0.14.0 » au titre,
## `game_version` des sauvegardes) alors que le site annonce la 0.15.0 ; pas de
## section 0.15 dans `CHANGELOG.md` (même schéma que QA-065 / QA-072).
func test_qa088_version_bumped_for_m15() -> void:
	var version: String = str(ProjectSettings.get_setting("application/config/version", ""))
	var changelog: String = FileAccess.get_file_as_string("res://CHANGELOG.md")
	if version != "0.14.0" and changelog.contains("## " + version):
		assert_true(true)
	else:
		pending("QA-088 : version « %s », section CHANGELOG « ## %s » %s" % [version, version,
				"présente" if changelog.contains("## " + version) else "absente"])
