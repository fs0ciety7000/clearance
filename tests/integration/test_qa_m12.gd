## Passe QA M12 « Rejouabilité » (docs/QA.md §15) — non-régression.
##
## Bugs QA-050 et suivants : chaque test appelle `pending("QA-0xx : …")` tant
## que le défaut est présent (la suite reste verte) et devient une assertion
## stricte une fois corrigé (convention §1). Les autres tests figent des
## comportements vérifiés pendant la passe : visage de SC-84b (photo du J2),
## migration d'un **vrai** profil M11 avec sa partie terminée (fixtures
## `tests/fixtures/qa_profile_v1_m11_*`, produites par la 0.11.0), écrans M12
## à la manette seule (vrais `InputEventJoypadButton`), conclusions du J31
## sans proche disparu.
## Profil et sauvegardes dans le dossier de test (`gut_pre_run.gd`), jamais
## dans `user://saves`.
extends GutTest

const DAY_SCENE: PackedScene = preload("res://scenes/main/day.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main/main.tscn")
const FIXTURES: String = "res://tests/fixtures/"
const GARDE_CODE: String = "K2Q-9TX"
## QA-050 : graine n = 156 de `balance_sim --seed=1` (`SeededRng.mix(1, 156)`) ;
## M13 (EV-09, `events_version` 2 : tirage stratifié renouvelé) : la première
## graine de la même série avec EV-08 au J19 est n = 22.
const QA050_SEED_BASE: int = 1
const QA050_SEED_INDEX: int = 22
## QA-050 : 13:02, dans la fenêtre d'EV-08 (13:00 → 14:00).
const QA050_MINUTE: int = 782

var _saved_state: Dictionary = {}


func before_each() -> void:
	Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	_saved_state = GameState.to_save_dict()
	_clear()
	DayScene.pending_garde_run = null
	DayScene.force_null_booth = true
	GardeScreen.open_on_title = false


func after_each() -> void:
	DayScene.force_null_booth = false
	DayScene.pending_garde_run = null
	GardeScreen.open_on_title = false
	_clear()
	get_tree().paused = false
	GameState.end_session()
	GameState.apply_save_dict(_saved_state)
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	InputPrompts.simulate_device(InputPrompts.Device.KEYBOARD)


func _clear() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	var root: String = SaveService.resolve_dir(SaveService.DEFAULT_DIR)
	for file: String in [ProfileService.FILE_NAME, ProfileService.V1_BACKUP_FILE]:
		SaveService.remove_with_fallbacks(root.path_join(file))


# ---------------------------------------------------------------------------
# Outils
# ---------------------------------------------------------------------------

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()


## Appui court d'un bouton de manette (événement réel).
func _pad(button: JoyButton) -> void:
	var down: InputEventJoypadButton = InputEventJoypadButton.new()
	down.button_index = button
	down.pressed = true
	down.pressure = 1.0
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var up: InputEventJoypadButton = InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(3)


func _choices(screen: ScreenBase) -> Array[StringName]:
	var choices: Array[StringName] = []
	screen.finished.connect(func(choice: StringName) -> void: choices.append(choice))
	return choices


static func _true_flags(flags: Dictionary[StringName, Variant]) -> Array[StringName]:
	var names: Array[StringName] = []
	for flag: StringName in flags:
		if FlagCondition.is_flag_true(flags, flag):
			names.append(flag)
	return names


static func _scripted_index(builder: CaseBuilder, id: StringName) -> int:
	for scripted: ScriptedCaseDef in builder.get_active_scripted_cases():
		if scripted.id == id:
			return scripted.at_index
	return -1


func _judge(scene: DayScene, correct: bool = true) -> void:
	EventBus.next_case_requested.emit()
	var dc: DayController = scene.day_controller
	var c: Case = dc.current_case
	if c == null:
		return
	EventBus.passenger_arrived.emit(c.case_id)
	var kind: VerdictKind.Kind = dc.current_key.expected_verdict
	if not correct:
		kind = VerdictKind.Kind.DENY if kind == VerdictKind.Kind.APPROVE else VerdictKind.Kind.APPROVE
	var verdict: Verdict = Verdict.new(c.case_id, kind)
	c.remove_visor()
	for violation: Violation in dc.current_key.expected_violations:
		if not violation.refs.is_empty():
			var d: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[violation.refs.size() - 1])
			d.confirmed = true
			verdict.flagged.append(d)
	verdict.questions_asked = [&"purpose"]
	EventBus.verdict_stamped.emit(verdict)
	EventBus.passenger_departed.emit(c.case_id)


func _copy_fixture(name: String, target: String) -> void:
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var text: String = FileAccess.get_file_as_string(FIXTURES + name)
	var file: FileAccess = FileAccess.open(target, FileAccess.WRITE)
	file.store_string(text)
	file.close()


# ---------------------------------------------------------------------------
# QA-050 — invariant « N° ID révoqué non détecté » (EV-08, J19)
# ---------------------------------------------------------------------------

## Le contrôle « cas propre » (`CaseBuilder._clean_ctx`) garde l'heure de
## présentation du début du jour (−1) : dans la fenêtre d'EV-08, un TRANSIT
## sans bio-scan (dispensé à la production des documents) est jugé
## « non propre », re-tiré, et le passager change. Le porteur d'une
## révocation (liste calculée au matin) n'est plus celui de la liste.
func test_qa050_ev08_revoked_carrier_keeps_its_listed_identity() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var campaign_seed: int = SeededRng.mix(QA050_SEED_BASE, QA050_SEED_INDEX)
	var schedule: Dictionary = BalanceSimulator.event_schedule(data, campaign_seed)
	assert_true(schedule.has(19), "graine %d : un événement au J19" % QA050_SEED_INDEX)
	if not schedule.has(19):
		return
	var plan: StationEventPlan = schedule[19]
	assert_eq(plan.event.id, &"ev_08", "EV-08 (fenêtre horaire) au J19")
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true}
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(19).make_shift_copy(), SeededRng.day_seed(campaign_seed, 19),
			_true_flags(flags), {}, flags)
	builder.set(&"_probing", true)
	var entry: RevokedEntry = null
	for listed: RevokedEntry in builder.ctx.revoked:
		if listed.case_index == 6:
			entry = listed
	assert_not_null(entry, "révocation liée au passager 6")
	if entry == null:
		return
	builder.ctx.ensure_shift_rules()
	builder.ctx.apply_changes(plan.changes(), plan.source())
	builder.presentation_minute = QA050_MINUTE
	builder.ctx.now_minute = QA050_MINUTE
	var generated: GeneratedCase = builder.build(6)
	var same: bool = FieldValue.equals(generated.case.passenger_presented.citizen_id, entry.citizen_id)
	assert_true(same, "QA-050 : le porteur de la révocation est celui de la liste (N° %s, liste %s)" % [
			generated.case.passenger_presented.citizen_id, entry.citizen_id])
	assert_eq(generated.invariant_errors.size(), 0, "aucun invariant violé : %s" % [generated.invariant_errors])


## Variante générale : dans la fenêtre d'EV-08, un cas propre est le même
## passager qu'à une autre heure (aucun re-tirage dû au seul contrôle).
func test_qa050_clean_build_does_not_depend_on_the_exemption_window() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var campaign_seed: int = SeededRng.mix(QA050_SEED_BASE, QA050_SEED_INDEX)
	var plan: StationEventPlan = BalanceSimulator.event_schedule(data, campaign_seed).get(19, null)
	assert_not_null(plan, "graine 156 : un événement au J19")
	if plan == null:
		return
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true}
	var differences: PackedStringArray = []
	var ids: Dictionary = {}
	for minute: int in [700, QA050_MINUTE]:
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(19).make_shift_copy(), SeededRng.day_seed(campaign_seed, 19),
				_true_flags(flags), {}, flags)
		builder.set(&"_probing", true)
		builder.ctx.ensure_shift_rules()
		builder.ctx.apply_changes(plan.changes(), plan.source())
		builder.presentation_minute = minute
		builder.ctx.now_minute = minute
		for index: int in builder.day.passenger_count:
			if builder.get_scripted_case(index) != null:
				continue
			var generated: GeneratedCase = builder.build_clean(index)
			var key: String = "%d" % index
			if minute == 700:
				ids[key] = generated.case.passenger_presented.citizen_id
			elif str(ids.get(key, "")) != str(generated.case.passenger_presented.citizen_id):
				differences.append("%s (%s)" % [key, generated.case.passenger_presented.purpose])
	assert_eq(differences.size(), 0, "QA-050 : passagers re-tirés dans la fenêtre d'EV-08 : %s" % ", ".join(differences))


# ---------------------------------------------------------------------------
# QA-051 — SC-84b et un avis de recherche homonyme (J18, graine 7)
# ---------------------------------------------------------------------------

## Le vrai titulaire de la carte du J2 (SC-84b) doit être REFUSÉ (R30). À la
## graine 7, le passager généré visé par l'avis du jour porte exactement son
## nom : l'avis le vise aussi et l'attendu devient DÉTENTION.
func test_qa051_sc84b_is_denied_even_when_a_generated_wanted_passenger_shares_his_name() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var campaign_seed: int = 7
	var memory: Dictionary = {}
	var day2: CaseBuilder = CaseBuilder.new(data, data.get_day(2), SeededRng.day_seed(campaign_seed, 2), [], memory, {})
	var sc03: GeneratedCase = day2.build(_scripted_index(day2, &"sc_03"))
	memory["sc_03"] = CaseMemory.snapshot(2, sc03.case, VerdictKind.Kind.APPROVE)
	var flags: Dictionary[StringName, Variant] = {&"sc03_passed": true, &"act2_started": true}
	flags = CaseMemory.with_pseudo_flags(flags, memory)
	var day18: CaseBuilder = CaseBuilder.new(data, data.get_day(18), SeededRng.day_seed(campaign_seed, 18), _true_flags(flags),
			memory, flags)
	var index: int = _scripted_index(day18, &"sc_84b")
	assert_gt(index, -1, "SC-84b présent (sc03_passed)")
	if index < 0:
		return
	var generated: GeneratedCase = day18.build(index)
	var homonyms: int = 0
	for notice: WantedNotice in day18.ctx.wanted:
		if notice.given_name == generated.case.passenger_presented.given_name \
				and notice.family_name == generated.case.passenger_presented.family_name:
			homonyms += 1
	assert_eq(homonyms, 0, "QA-051 : aucun avis du jour ne porte le nom de SC-84b")
	assert_eq(generated.key.expected_verdict, VerdictKind.Kind.DENY, "QA-051 : SC-84b attendu %s" % [
			VerdictKind.Kind.keys()[generated.key.expected_verdict]])


## SC-84b porte le visage de la **photo** présentée au J2 (traits d'identité),
## pas celui du mineur ; SC-84a (refusé au J2) porte le visage du mineur.
func test_sc84_echoes_wear_the_right_face_of_day_two() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var slots: Array[StringName] = data.appearance_catalog.get_identity_slots()
	for row: Array in [[VerdictKind.Kind.APPROVE, &"sc_84b", 18], [VerdictKind.Kind.DENY, &"sc_84a", 4]]:
		var memory: Dictionary = {}
		var day2: CaseBuilder = CaseBuilder.new(data, data.get_day(2), SeededRng.day_seed(23, 2), [], memory, {})
		var sc03: GeneratedCase = day2.build(_scripted_index(day2, &"sc_03"))
		var verdict: VerdictKind.Kind = row[0]
		memory["sc_03"] = CaseMemory.snapshot(2, sc03.case, verdict)
		var flags: Dictionary[StringName, Variant] = {&"act2_started": true}
		if verdict == VerdictKind.Kind.APPROVE:
			flags[&"sc03_passed"] = true
		flags = CaseMemory.with_pseudo_flags(flags, memory)
		var day_number: int = row[2]
		var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(day_number), SeededRng.day_seed(23, day_number),
				_true_flags(flags), memory, flags)
		var index: int = _scripted_index(builder, row[1])
		assert_gt(index, -1, "%s présent" % row[1])
		if index < 0:
			continue
		var face: PassengerAppearance = builder.build(index).case.passenger_presented.appearance
		if row[1] == &"sc_84b":
			var photo: PassengerAppearance = CaseMemory.photo_appearance_of(memory["sc_03"])
			assert_not_null(photo, "photo du J2 mémorisée")
			if photo != null:
				assert_eq(FaceComparator.compare(face, photo, slots).size(), 0, "SC-84b : visage = photo du J2")
		else:
			assert_eq(FaceComparator.compare(face, sc03.key.truth.appearance, slots).size(), 0, "SC-84a : visage du mineur")


## QA-060 : sauvegarde 0.11 (la mémoire de SC-03 n'a pas `photo_appearance`,
## champ ajouté en M12) : SC-84b doit garder le visage de la photo du J2
## (recalcul déterministe de l'entrée, D-057) — repli actuel : visage du roster.
func test_qa060_sc84b_keeps_the_photo_face_with_a_0_11_memory_entry() -> void:
	var data: DataCatalog = DataCatalog.load_from()
	var slots: Array[StringName] = []
	for slot: StringName in data.appearance_catalog.get_identity_slots():
		if slot != &"age_band":
			slots.append(slot)
	var day2: CaseBuilder = CaseBuilder.new(data, data.get_day(2), SeededRng.day_seed(23, 2), [], {}, {})
	var sc03: GeneratedCase = day2.build(_scripted_index(day2, &"sc_03"))
	var entry: Dictionary = CaseMemory.snapshot(2, sc03.case, VerdictKind.Kind.APPROVE)
	var photo: PassengerAppearance = CaseMemory.photo_appearance_of(entry)
	assert_not_null(photo, "photo du J2 (0.12)")
	if photo == null:
		return
	entry.erase("photo_appearance")
	var flags: Dictionary[StringName, Variant] = {&"sc03_passed": true, &"act2_started": true}
	var memory: Dictionary = CaseMemory.resolve(data, data.get_day(18), 23, {"sc_03": entry})
	flags = CaseMemory.with_pseudo_flags(flags, memory)
	var builder: CaseBuilder = CaseBuilder.new(data, data.get_day(18), SeededRng.day_seed(23, 18), _true_flags(flags), memory, flags)
	# Sans `_probing`, l'échec du contrôle « cas propre » (r_apparent_age) serait un push_error.
	builder.set(&"_probing", true)
	var index: int = _scripted_index(builder, &"sc_84b")
	assert_gt(index, -1, "SC-84b présent")
	if index < 0:
		return
	var generated: GeneratedCase = builder.build(index)
	var differing: Array[StringName] = FaceComparator.compare(generated.case.passenger_presented.appearance, photo, slots)
	# La liste des révocations est construite au matin (hors `_probing`) : un
	# « aucun cas propre » y serait un push_error.
	var init_errors: int = 0
	for err: Variant in get_errors():
		if not err.handled and err.contains_text("aucun cas propre"):
			init_errors += 1
	assert_eq(differing.size(), 0, "QA-060 : SC-84b ressemble à la photo du J2 (%s)" % [differing])
	assert_eq(generated.clean_violation_count, 0, "QA-060 : cas propre possible")
	assert_eq(init_errors, 0, "QA-060 : aucun « aucun cas propre » au matin du J18")


# ---------------------------------------------------------------------------
# QA-052 — migration v1 → v2 d'un vrai profil M11 sans emplacement
# ---------------------------------------------------------------------------

## Profils réels de la 0.11.0 (le joueur a supprimé sa partie, ou l'outil QA
## l'a effacée) : la migration ne lit que les emplacements. `max_day_reached`
## reste 0 (Garde verrouillée après une campagne entière) et une fin de
## l'Acte III ne débloque pas `epilogue_unlocked` (totals et indices cachés).
func test_qa052_real_m11_profiles_without_slot_keep_their_progress() -> void:
	var problems: PackedStringArray = []
	for row: Array in [["qa_profile_v1_m11_f5_j30_noslot.json", 30, true], ["qa_profile_v1_m11_f3_j15_noslot.json", 15, false]]:
		_clear()
		_copy_fixture(row[0], ProfileService.profile_path())
		var profile: Dictionary = ProfileService.load_profile()
		assert_eq(SaveService.as_int(profile.get("version", 0)), ProfileService.VERSION, "%s : migré en v2" % row[0])
		assert_true(FileAccess.file_exists(SaveService.resolve_dir(SaveService.DEFAULT_DIR).path_join(ProfileService.V1_BACKUP_FILE)),
				"profile.v1.bak")
		assert_eq((profile["endings_seen"] as Array).size(), 1, "fin conservée")
		if SaveService.as_int(profile.get("max_day_reached", 0)) < SaveService.as_int(row[1]):
			problems.append("%s : max_day_reached = %s (fin au J%d)" % [row[0], profile.get("max_day_reached"), row[1]])
		if not GardeService.is_unlocked(profile):
			problems.append("%s : Garde verrouillée" % row[0])
		if row[2] and not profile.get("epilogue_unlocked", false):
			problems.append("%s : fin de l'Acte III sans epilogue_unlocked" % row[0])
	assert_eq(problems.size(), 0, "QA-052 : " + " ; ".join(problems))


## Vrai profil M11 **et** sa partie terminée (F9, J30, 0.11.0) : graine
## d'épilogue reconstruite, `day_31.json`, méta, `last_campaign` ; Charger
## propose « UN AN PLUS TARD » et le J31 ne touche pas la partie.
func test_real_m11_profile_with_its_finished_game_migrates_and_offers_the_epilogue() -> void:
	var slot_dir: String = SaveService.slot_dir(1)
	_copy_fixture("qa_profile_v1_m11_f9_j30.json", ProfileService.profile_path())
	_copy_fixture("qa_profile_v1_m11_f9_j30_slot_current.json", slot_dir.path_join("current.json"))
	_copy_fixture("qa_profile_v1_m11_f9_j30_slot_meta.json", slot_dir.path_join("meta.json"))
	var current_md5: String = FileAccess.get_md5(slot_dir.path_join("current.json"))
	var profile: Dictionary = ProfileService.load_profile()
	assert_eq(SaveService.as_int(profile["max_day_reached"]), 30)
	assert_true(profile["epilogue_unlocked"], "fin de l'Acte III : épilogue débloqué")
	assert_true((profile["epilogues"] as Dictionary).has("f9_strike:"), "graine d'épilogue au profil")
	assert_eq(str((profile["last_campaign"] as Dictionary).get("world", "")), "b", "dernière partie : monde B")
	assert_true(SaveService.has_epilogue(1), "day_31.json écrit")
	assert_true(SaveService.load_meta(1).get(SaveService.KEY_EPILOGUE_AVAILABLE, false), "méta epilogue_available")
	assert_eq(str(SaveService.load_meta(1).get("status", "")), SaveService.STATUS_ENDED, "partie toujours terminée")
	var epi: Dictionary = Campaign.epilogue_seed_for_slot(1)
	assert_eq(str(epi.get("world", "")), "b")
	assert_eq(str(epi.get("ending_key", "")), "f9")
	var main: Control = MAIN_SCENE.instantiate()
	main.set(&"change_scene", false)
	add_child_autofree(main)
	await wait_process_frames(3)
	var load_screen: LoadScreen = main.call(&"open_load")
	await wait_process_frames(2)
	assert_true(load_screen.epilogue_buttons.has(1), "Charger : JOUER « UN AN PLUS TARD »")
	assert_not_null(Campaign.start_epilogue(epi, 1))
	GameState.end_session()
	assert_eq(FileAccess.get_md5(slot_dir.path_join("current.json")), current_md5, "current.json inchangé")


# ---------------------------------------------------------------------------
# QA-053 — Garde : cache des portraits sans plafond
# ---------------------------------------------------------------------------

## En Garde, la scène n'est jamais rechargée : `PortraitService._cache` garde
## un portrait par passager (≈ 0,45 Mo chacun en headless) jusqu'à la fin.
func test_qa053_garde_portrait_cache_does_not_grow_with_the_run() -> void:
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	if scene.garde_run == null:
		pending("données de Garde absentes")
		return
	# Comme l'interface (photo de la carte, visage) : un portrait par passager présenté.
	var provider: Callable = scene.get_portrait_provider()
	var sizes: Array[int] = []
	for i: int in 30:
		EventBus.next_case_requested.emit()
		var c: Case = scene.day_controller.current_case
		if c == null:
			break
		provider.call(c.passenger_presented.appearance)
		var kind: VerdictKind.Kind = scene.day_controller.current_key.expected_verdict
		var verdict: Verdict = Verdict.new(c.case_id, kind)
		c.remove_visor()
		for violation: Violation in scene.day_controller.current_key.expected_violations:
			if not violation.refs.is_empty():
				var d: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[violation.refs.size() - 1])
				d.confirmed = true
				verdict.flagged.append(d)
		verdict.questions_asked = [&"purpose"]
		EventBus.passenger_arrived.emit(c.case_id)
		EventBus.verdict_stamped.emit(verdict)
		EventBus.passenger_departed.emit(c.case_id)
		await wait_process_frames(2)
		if scene.garde_hud != null and scene.garde_hud.card != null and is_instance_valid(scene.garde_hud.card):
			scene.garde_hud.card.dismiss()
		if i == 9 or i == 29:
			sizes.append(scene.portrait_service.cache_size())
	assert_eq(sizes.size(), 2)
	gut.p("QA-053 : portraits en cache après 10 / 30 passagers : %s" % [sizes])
	assert_true(sizes.size() == 2 and sizes[1] <= sizes[0] + 2, "QA-053 : cache borné (%s)" % [sizes])


# ---------------------------------------------------------------------------
# QA-054 — fin de garde : erreur de procédure « APPROUVÉ → APPROUVÉ »
# ---------------------------------------------------------------------------

func test_qa054_procedure_error_does_not_read_the_same_verdict_twice() -> void:
	var row: Control = GardeEndScreen.error_row({"passenger": 6, "label": "A. HSU", "verdict": "approve", "expected": "approve",
			"citation": "cit_face_not_checked", "rule_id": "r_face_uncovered"})
	add_child_autofree(row)
	await wait_process_frames(1)
	var same: String = UiText.tf("garde_end_verdicts", [GardeEndScreen.verdict_text("approve"), GardeEndScreen.verdict_text("approve")],
			"%s → %s")
	var found: bool = false
	for node: Node in row.find_children("*", "Label", true, false):
		found = found or (node as Label).text == same
	assert_false(found, "QA-054 : erreur de procédure jamais « %s »" % same)
	var verdicts: Label = row.find_child("Verdicts", true, false) as Label
	assert_not_null(verdicts, "colonne verdict")
	if verdicts != null:
		assert_eq(verdicts.text, UiText.tf("garde_end_procedure", [GardeEndScreen.verdict_text("approve")], "%s · ERREUR DE PROCÉDURE"),
				"verdict rendu + nature « procédure »")
	# Vraie citation : la nature de la faute est dite (« Visage non contrôlé »
	# + sa description), à partir de la citation du record.
	var real: Control = GardeEndScreen.error_row({"passenger": 7, "label": "B. ORTEGA", "verdict": "approve", "expected": "approve",
			"citation": ScoringService.CIT_FACE_UNCHECKED, "rule_id": "", "violations": []})
	add_child_autofree(real)
	await wait_process_frames(1)
	var nature: Label = real.find_child("Nature", true, false) as Label
	var detail: Label = real.find_child("Detail", true, false) as Label
	assert_eq(nature.text if nature != null else "", UiText.t(ScoringService.CIT_FACE_UNCHECKED, "?"), "nature de la faute")
	assert_eq(detail.text if detail != null else "", UiText.t(ScoringService.CIT_FACE_UNCHECKED + "_desc", "?"), "description de la faute")
	# Erreur de verdict : « rendu → attendu » inchangé, motifs des violations manquées.
	var wrong: Dictionary = {"passenger": 8, "verdict": "approve", "expected": "deny", "citation": ScoringService.CIT_IRREGULAR_ENTRY,
		"violations": [{"rule_id": "r_x", "reason_key": "cit_irregular_entry_desc", "refs": []}]}
	assert_eq(GardeEndScreen.verdict_line(wrong), UiText.tf("garde_end_verdicts",
			[GardeEndScreen.verdict_text("approve"), GardeEndScreen.verdict_text("deny")], "%s → %s"))
	assert_string_contains(GardeEndScreen.error_detail(wrong), UiText.t("cit_irregular_entry_desc", "?"), false)


# ---------------------------------------------------------------------------
# QA-055 — code de garde : date invalide annoncée comme « 6 caractères »
# ---------------------------------------------------------------------------

func test_qa055_invalid_daily_code_is_not_reported_as_a_length_error() -> void:
	var result: Dictionary = GardeService.normalize_code("NUIT-2026-13-40")
	assert_false(result.get("ok", true), "date impossible refusée")
	assert_ne(str(result.get("error_key", "")), GardeService.ERROR_BAD_LENGTH, "QA-055 : pas une erreur de longueur")
	assert_eq(str(result.get("error_key", "")), GardeService.ERROR_BAD_DATE, "date invalide")
	assert_eq(result.get("reason", &""), GardeService.REASON_DATE)
	# 31 février, caractère accentué : raisons propres ; code juste : accepté.
	assert_eq(str(GardeService.normalize_code("NUIT-2026-02-30").get("error_key", "")), GardeService.ERROR_BAD_DATE)
	assert_true(GardeService.normalize_code("NUIT-2028-02-29").get("ok", false), "29 février d'une année bissextile")
	assert_eq(str(GardeService.normalize_code("é2Q-9TX").get("error_key", "")), GardeService.ERROR_BAD_CHAR)
	assert_eq(str(GardeService.normalize_code("K2Q-9T").get("error_key", "")), GardeService.ERROR_BAD_LENGTH)
	assert_eq(str(GardeService.normalize_code("K2Q-9TO").get("error_key", "")), GardeService.ERROR_INVALID_CHARS)


# ---------------------------------------------------------------------------
# Comportements vérifiés (non-régression)
# ---------------------------------------------------------------------------

## Conclusions des 13 variantes : jamais une ligne qui nomme un proche mort,
## parti ou retenu (« personnage mort ou parti ⇒ absent »).
func test_conclusions_never_name_a_lost_away_or_held_relative() -> void:
	if EpilogueService.load_def() == null:
		pending("données d'épilogue absentes")
		return
	var names: Dictionary = {Household.NOA: "Noa", Household.DORA: "Dora", Household.ILAN: "Ilan"}
	var cases: Array = [
		[EndingService.F1_ARRESTED, {"deposition_arrested": true}], [EndingService.F3_FAMILY_LOST, {}], [EndingService.F4_GLORY, {}],
		[EndingService.F7_REOPENS, {}], [EndingService.F5_AIR, {"vanne2_brulants": true}], [EndingService.F5_AIR, {"climate_vanne": true}],
		[EndingService.F5_AIR, {}], [EndingService.F9_STRIKE, {}], [EndingService.F8_REGISTRE, {}], [EndingService.F10_PONT, {}],
		[EndingService.F2_REASSIGNED, {}], [EndingService.F6_DRIFT, {}], [EndingService.F6_DRIFT, {"exit3_drift": true}]]
	var problems: PackedStringArray = []
	for row: Array in cases:
		for who: StringName in names:
			for how: String in ["lost", "away", "held"]:
				var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
				var extra: Dictionary = row[1]
				for key: Variant in extra:
					flags[StringName(str(key))] = extra[key]
				var home: Household = Household.new()
				var member: Household.Member = home.get_member(who)
				match how:
					"lost":
						member.health = Household.Health.LOST
					"away":
						member.away = &"tycho"
					_:
						member.detained = true
				var epi: Dictionary = EpilogueService.make_seed(row[0], flags, home, {}, 4242, 30)
				if epi.is_empty():
					continue
				var card: Dictionary = EpilogueService.conclusion(epi, EpilogueService.morning_flags(epi), 0)
				for line: String in EpilogueScreen.conclusion_lines(card):
					if line.contains(names[who]):
						problems.append("%s, %s %s : « %s »" % [epi["ending_key"], names[who], how, line])
	var lost_first: PackedStringArray = []
	for line: String in problems:
		if line.contains(" lost "):
			lost_first.append(line)
	for line: String in problems:
		if not line.contains(" lost "):
			lost_first.append(line)
	problems = lost_first
	assert_eq(problems.size(), 0, "QA-056 : " + " | ".join(problems.slice(0, 6))
			+ (" (+%d)" % (problems.size() - 6) if problems.size() > 6 else ""))


## Manette seule : fin de garde (Ⓐ = REJOUER, Ⓑ = titre), carte d'ouverture
## du J31 (Ⓑ = titre), conclusion (Ⓑ tout afficher puis titre), Dossier
## (RB / LB entre les onglets, Ⓑ retour).
func test_pad_only_m12_screens() -> void:
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	# Fin de garde.
	var record: Dictionary = {"code": GARDE_CODE, "kind": "free", "score": 6, "passengers": 9, "directives": 1, "tier": 0,
		"end_reason": "errors", "errors": [], "duration_sec": 40, "clock_minute": 1374}
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B]:
		var end: GardeEndScreen = GardeEndScreen.new()
		end.setup(record, {"new_record": true})
		var choices: Array[StringName] = _choices(end)
		add_child_autofree(end)
		await wait_process_frames(3)
		assert_eq(_focus(), end.replay_button, "fin de garde : focus REJOUER")
		await _pad(button)
		var expected: StringName = &"replay" if button == JOY_BUTTON_A else &"title"
		assert_eq(choices.size(), 1, "fin de garde : un choix (bouton %d)" % button)
		if choices.size() == 1:
			assert_eq(choices[0], expected, "fin de garde : bouton %d" % button)
	# Carte d'ouverture du J31.
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F6_DRIFT, flags, Household.new(), {}, 99, 30)
	if not epi.is_empty():
		var intro: EpilogueScreen = EpilogueScreen.new()
		intro.setup_intro(epi)
		var intro_choices: Array[StringName] = _choices(intro)
		add_child_autofree(intro)
		await wait_process_frames(3)
		assert_eq(_focus(), intro.continue_button, "carte : focus CONTINUER")
		await _pad(JOY_BUTTON_B)
		assert_eq(intro_choices.size(), 1, "carte : Ⓑ ferme")
		if intro_choices.size() == 1:
			assert_eq(intro_choices[0], &"title", "carte : Ⓑ = titre")
		# Conclusion : Ⓑ tout afficher, puis Ⓑ titre.
		Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
		var conclusion: EpilogueScreen = EpilogueScreen.new()
		conclusion.setup_conclusion(EpilogueService.conclusion(epi, EpilogueService.morning_flags(epi), 2))
		var concl_choices: Array[StringName] = _choices(conclusion)
		add_child_autofree(conclusion)
		await wait_process_frames(3)
		await _pad(JOY_BUTTON_B)
		assert_true(conclusion.is_reveal_done(), "conclusion : Ⓑ révèle tout")
		assert_eq(concl_choices.size(), 0, "conclusion : premier Ⓑ ne quitte pas")
		await wait_process_frames(2)
		assert_eq(_focus(), conclusion.continue_button, "conclusion : focus RETOUR AU TITRE")
		await _pad(JOY_BUTTON_B)
		assert_eq(concl_choices.size(), 1, "conclusion : second Ⓑ ferme")
		if concl_choices.size() == 1:
			assert_eq(concl_choices[0], &"title", "conclusion : second Ⓑ = titre")
		Settings.set_session_value(Settings.KEY_REDUCE_MOTION, true)
	# Dossier : RB / LB, Ⓑ.
	var profile: Dictionary = ProfileService.empty_profile()
	profile["max_day_reached"] = 30
	profile["epilogue_unlocked"] = true
	profile["endings_seen"] = [{"id": "f9_strike", "variant": "", "act": 3, "day": 30, "date": "2026-10-29T10:00:00", "count": 1,
		"last_date": "2026-10-29T10:00:00", "first_line_key": ""}]
	profile["characters_met"] = ["sc_01"]
	ProfileService.save_profile(profile)
	var dossier: DossierScreen = DossierScreen.new()
	var dossier_choices: Array[StringName] = _choices(dossier)
	add_child_autofree(dossier)
	await wait_process_frames(3)
	var first: StringName = dossier.current_tab
	assert_true(dossier.tabs.has(DossierScreen.TAB_EPILOGUES), "onglet ÉPILOGUES après epilogue_unlocked")
	await _pad(JOY_BUTTON_RIGHT_SHOULDER)
	assert_ne(dossier.current_tab, first, "RB : onglet suivant")
	await _pad(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(dossier.current_tab, first, "LB : onglet précédent")
	await _pad(JOY_BUTTON_B)
	assert_eq(dossier_choices.size(), 1, "Dossier : Ⓑ ferme")
	if dossier_choices.size() == 1:
		assert_eq(dossier_choices[0], &"back", "Dossier : Ⓑ retour")


## Garde à la manette : COMPRIS (Ⓐ) ferme la carte de directive avant tout
## passager ; TERMINER LA GARDE joignable à la croix ↑ depuis SUIVANT, boîte
## avec focus ANNULER, croix → puis Ⓐ confirme : la garde s'arrête.
func test_pad_only_garde_directive_card_and_end_from_the_bar() -> void:
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	if scene.garde_run == null:
		pending("données de Garde absentes")
		return
	for i: int in scene.garde_run.def.directive_every:
		_judge(scene)
		await wait_process_frames(1)
	await wait_process_frames(3)
	var card: GardeDirectiveCard = scene.garde_hud.card
	assert_not_null(card, "carte de directive")
	if card == null:
		return
	assert_eq(_focus(), card.ok_button, "focus COMPRIS")
	var processed: int = scene.day_controller.summary.results.size()
	await _pad(JOY_BUTTON_A)
	assert_true(not is_instance_valid(card) or card.is_dismissed(), "Ⓐ ferme la carte")
	assert_eq(scene.day_controller.phase, DayPhase.Kind.WAITING_CASE, "aucun passager appelé par ce Ⓐ")
	var ui: ComparisonUI = scene.ui as ComparisonUI
	ui.tool_bar.next_button.grab_focus()
	await wait_process_frames(1)
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_eq(_focus(), ui.top_bar.close_button, "croix ↑ : TERMINER LA GARDE")
	await _pad(JOY_BUTTON_A)
	var dialog: ConfirmDialog = scene.end_garde_dialog
	assert_not_null(dialog, "confirmation")
	if dialog == null:
		return
	await wait_process_frames(2)
	assert_eq(_focus(), dialog.cancel_button, "focus ANNULER")
	# QA-057 : la croix doit rester dans la boîte (ANNULER ↔ TERMINER LA GARDE).
	await _pad(JOY_BUTTON_DPAD_RIGHT)
	var escaped: Control = _focus()
	assert_true(escaped != null and dialog.is_ancestor_of(escaped), "QA-057 : croix → reste dans la boîte (%s)" % [
			escaped.get_path() if escaped != null else "aucun"])
	assert_eq(_focus(), dialog.accept_button, "croix → : TERMINER LA GARDE")
	# Toutes les directions restent dans la boîte.
	for button: JoyButton in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		await _pad(button)
		var inside: Control = _focus()
		assert_true(inside != null and dialog.is_ancestor_of(inside), "croix %d : focus dans la boîte" % button)
	# Focus forcé derrière le voile (souris, autre chemin) : Ⓐ n'appelle
	# personne et le focus revient dans la boîte.
	ui.tool_bar.next_button.grab_focus()
	await wait_process_frames(1)
	await _pad(JOY_BUTTON_A)
	assert_eq(scene.day_controller.phase, DayPhase.Kind.WAITING_CASE, "Ⓐ derrière la boîte : aucun passager appelé")
	assert_false(dialog.is_done(), "la boîte reste ouverte")
	assert_true(_focus() != null and dialog.is_ancestor_of(_focus()), "focus rendu à la boîte")
	dialog.accept_button.grab_focus()
	await wait_process_frames(1)
	await _pad(JOY_BUTTON_A)
	await wait_process_frames(3)
	assert_true(scene.day_controller.garde_over, "garde terminée (score de %d enregistré)" % processed)


# ---------------------------------------------------------------------------
# QA-058 — conclusion du J31 au Deck en texte 1,5 : colonne tronquée
# ---------------------------------------------------------------------------

## 1280 × 800, texte 1,5 : les lignes occupent toute la hauteur libre (plus de
## colonne réduite à 360 px au milieu de l'écran), un repère « SUITE » dit
## qu'il reste du texte, le stick droit et la croix ↓ font défiler jusqu'en
## bas, où le repère s'efface.
func test_qa058_conclusion_scrolls_with_a_visible_hint_at_text_150() -> void:
	var flags: Dictionary[StringName, Variant] = {&"act2_started": true, &"act3_started": true}
	var epi: Dictionary = EpilogueService.make_seed(EndingService.F10_PONT, flags, Household.new(), {}, 1234, 30)
	if epi.is_empty():
		pending("données d'épilogue absentes")
		return
	InputPrompts.simulate_device(InputPrompts.Device.XBOX)
	Settings.set_session_value(Settings.KEY_TEXT_SCALE, 1.5)
	var holder: Control = Control.new()
	holder.size = Vector2(1280.0, 800.0)
	add_child_autofree(holder)
	# Conclusion d'un J31 joué jusqu'au bout (`--skip-cases=7`) : une ligne par
	# groupe du monde (vraies clés des données), comme la capture de QA-058.
	var card: Dictionary = EpilogueService.conclusion(epi, EpilogueService.morning_flags(epi), 2)
	var lines: PackedStringArray = card.get("lines", PackedStringArray())
	var world: EpilogueWorldDef = EpilogueService.load_def().get_world(StringName(str(epi.get("world", ""))))
	if world != null:
		for group: EpilogueLineGroupDef in world.line_groups:
			if group != null and not group.lines.is_empty() and not lines.has(group.lines[0].key):
				lines.insert(maxi(lines.size() - 1, 0), group.lines[0].key)
	card["lines"] = lines
	var conclusion: EpilogueScreen = EpilogueScreen.new()
	conclusion.setup_conclusion(card)
	holder.add_child(conclusion)
	await wait_process_frames(4)
	var scroll: ScrollContainer = conclusion.lines_scroll()
	var column: Control = conclusion.find_child("Column", true, false) as Control
	assert_not_null(scroll, "zone des lignes")
	assert_not_null(column, "colonne")
	if scroll == null or column == null:
		Settings.clear_session_value(Settings.KEY_TEXT_SCALE)
		return
	# La colonne descend jusqu'au pied (plus de vide au-dessus du pied).
	var page: Control = column.get_parent() as Control
	var below: float = page.get_global_rect().end.y - column.get_global_rect().end.y
	var foot_space: float = 0.0
	for child: Node in page.get_children():
		if child != column and child is Control:
			foot_space += (child as Control).size.y + page.get_theme_constant("separation")
	assert_almost_eq(below, foot_space, 2.0, "colonne sur toute la hauteur libre")
	assert_true(scroll.get_global_rect().end.y <= conclusion.continue_button.get_global_rect().position.y, "lignes au-dessus du pied")
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	gut.p("QA-058 : écran %s, colonne %s, zone %s, contenu %.0f / page %.0f, %d lignes" % [conclusion.size, column.size, scroll.size,
			bar.max_value, bar.page, conclusion.line_labels.size()])
	assert_true(bar.max_value > bar.page + 1.0, "texte 1,5 : plus long que la zone (cas de QA-058)")
	assert_true(conclusion.has_more_below(), "texte sous la zone")
	assert_eq(conclusion.more_hint.modulate.a, 1.0, "repère SUITE visible")
	assert_true(conclusion.more_hint.is_visible_in_tree(), "repère dans l'arbre visible")
	# Croix ↓ depuis le bouton du pied : défile.
	assert_true(conclusion.is_reveal_done(), "révélation immédiate (mouvement réduit)")
	conclusion.continue_button.grab_focus()
	await wait_process_frames(1)
	var before: int = scroll.scroll_vertical
	await _pad(JOY_BUTTON_DPAD_DOWN)
	assert_gt(scroll.scroll_vertical, before, "croix ↓ : les lignes défilent")
	assert_eq(_focus(), conclusion.continue_button, "le focus reste sur RETOUR AU TITRE")
	# Stick droit (`scroll_down`) jusqu'en bas : le repère s'efface.
	var tries: int = 0
	while conclusion.has_more_below() and tries < 20:
		await _pad(JOY_BUTTON_DPAD_DOWN)
		tries += 1
	await wait_process_frames(1)
	assert_false(conclusion.has_more_below(), "bas du texte atteint")
	assert_eq(conclusion.more_hint.modulate.a, 0.0, "repère effacé en bas")
	await _pad(JOY_BUTTON_DPAD_UP)
	assert_true(conclusion.has_more_below(), "croix ↑ : remonte")
	Settings.clear_session_value(Settings.KEY_TEXT_SCALE)


# ---------------------------------------------------------------------------
# QA-061 — Garde longue : règle NOUVEAU à l'écran ; pas d'erreur `_reset_pivot`
# ---------------------------------------------------------------------------

## Garde de 60 passagers en mouvement normal (arrivées animées), verdict dès
## les documents posés : aucune erreur moteur (`_reset_pivot` sur un document
## libéré, `ensure_control_visible` « Must be an ancestor ») ; après chaque
## directive appliquée, la règle surlignée est dans la zone visible du Rulebook.
func test_qa061_long_garde_scrolls_to_the_new_rule_without_engine_errors() -> void:
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	if scene.garde_run == null:
		pending("données de Garde absentes")
		return
	var ui: ComparisonUI = scene.ui as ComparisonUI
	var rulebook: RulebookPanel = ui.rulebook
	var checked: int = 0
	var long_lists: int = 0
	var missing: PackedStringArray = []
	var seen_focus: int = 0
	for i: int in 60:
		if scene.day_controller.garde_over:
			break
		EventBus.next_case_requested.emit()
		var c: Case = scene.day_controller.current_case
		if c == null:
			break
		EventBus.passenger_arrived.emit(c.case_id)
		await wait_process_frames(3) # documents posés, arrivée en cours
		if rulebook.focus_count != seen_focus:
			seen_focus = rulebook.focus_count
			var focus_id: StringName = rulebook.last_focused_rule
			var card: RuleCardView = rulebook.get_rule_card(focus_id)
			if card != null and is_instance_valid(card):
				checked += 1
				var scroll: ScrollContainer = rulebook._scroll
				if scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0:
					long_lists += 1
				var view: Rect2 = scroll.get_global_rect().grow(1.0)
				var rect: Rect2 = card.get_global_rect()
				if not (view.has_point(rect.position) and rect.position.y + minf(rect.size.y, view.size.y) <= view.end.y):
					missing.append("%s (passager %d)" % [focus_id, i + 1])
		var kind: VerdictKind.Kind = scene.day_controller.current_key.expected_verdict
		var verdict: Verdict = Verdict.new(c.case_id, kind)
		c.remove_visor()
		for violation: Violation in scene.day_controller.current_key.expected_violations:
			if not violation.refs.is_empty():
				var d: Discrepancy = Discrepancy.new(violation.refs[0], violation.refs[violation.refs.size() - 1])
				d.confirmed = true
				verdict.flagged.append(d)
		verdict.questions_asked = [&"purpose"]
		EventBus.verdict_stamped.emit(verdict)
		EventBus.passenger_departed.emit(c.case_id)
		await wait_process_frames(1)
		if scene.garde_hud != null and scene.garde_hud.card != null and is_instance_valid(scene.garde_hud.card):
			scene.garde_hud.card.dismiss()
	# Laisser finir les arrivées et sorties en cours (callbacks des tweens).
	await wait_seconds(DS.DUR_SLOW * 3.0)
	gut.p("QA-061 : %d règles surlignées vérifiées, dont %d avec liste défilante" % [checked, long_lists])
	assert_gt(checked, 0, "au moins une directive vérifiée")
	assert_eq(missing.size(), 0, "règle surlignée à l'écran : " + ", ".join(missing))


## `Workbench.clear()` pendant l'arrivée des documents : les arrivées sont
## arrêtées (tween porté par le document), aucun rappel sur un objet libéré.
func test_qa061_workbench_clear_during_arrival_kills_the_arrivals() -> void:
	Settings.clear_session_value(Settings.KEY_REDUCE_MOTION)
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	if scene.garde_run == null:
		pending("données de Garde absentes")
		return
	var ui: ComparisonUI = scene.ui as ComparisonUI
	EventBus.next_case_requested.emit()
	var c: Case = scene.day_controller.current_case
	EventBus.passenger_arrived.emit(c.case_id)
	await wait_process_frames(3)
	var workbench: Workbench = ui.workbench
	assert_gt(workbench._arrivals.size(), 0, "arrivées en cours")
	var arrivals: Array[Tween] = workbench._arrivals.duplicate()
	workbench.clear(false)
	assert_eq(workbench._arrivals.size(), 0, "arrivées oubliées")
	for tween: Tween in arrivals:
		assert_false(tween.is_valid() and tween.is_running(), "arrivée arrêtée")
	await wait_seconds(DS.DUR_SLOW * 3.0)


# ---------------------------------------------------------------------------
# QA-062 / D-138 — EV-08 en Garde : passagers, jamais « 13:00–14:00 »
# ---------------------------------------------------------------------------

static func _has_clock(text: String) -> bool:
	return RegEx.create_from_string("\\d{1,2}:\\d{2}").search(text) != null


## EV-08 annoncé en Garde (vraie scène) : annonce, bandeau et ligne ambre du
## Rulebook parlent en passagers (« pour les 5 prochains passagers »,
## « 5 PASSAGERS ») ; aucune heure de campagne.
func test_qa062_ev08_in_garde_speaks_in_passengers() -> void:
	DayScene.pending_garde_run = Campaign.start_garde(GARDE_CODE)
	var scene: DayScene = DAY_SCENE.instantiate()
	add_child_autofree(scene)
	await wait_process_frames(3)
	var events: StationEventsDef = StationEventService.load_def()
	if scene.garde_run == null or events == null:
		pending("données de Garde ou d'événements absentes")
		return
	var exemption: StationEventDef = null
	for event: StationEventDef in events.events:
		if event != null and event.key == &"exemption":
			exemption = event
	assert_not_null(exemption, "EV-08 au catalogue")
	if exemption == null:
		return
	var ui: ComparisonUI = scene.ui as ComparisonUI
	scene._show_station_event(&"exemption")
	await wait_process_frames(2)
	var window: int = maxi(exemption.garde_window_passengers, 1)
	var banner: String = ui.event_banner.get_text()
	assert_true(ui.event_banner.visible, "bandeau affiché")
	assert_false(_has_clock(banner), "bandeau sans heure : « %s »" % banner)
	assert_string_contains(banner, UiText.plural("sev_ui_remaining", window, "%d PASSAGER", "%d PASSAGERS"), false)
	assert_false(_has_clock(ui.announcement_text), "annonce sans heure : « %s »" % ui.announcement_text)
	assert_string_contains(ui.announcement_text, "passager", false)
	var notes: PackedStringArray = ui.rulebook.event_notes
	assert_eq(notes.size(), 1, "ligne ambre au Rulebook")
	for line: String in notes:
		assert_false(_has_clock(line), "Rulebook sans heure : « %s »" % line)
		assert_string_contains(line, str(window), false)
	# Un passager plus tard : un de moins.
	var plan: StationEventPlan = ui.station_events[0] if not ui.station_events.is_empty() else null
	assert_not_null(plan)
	if plan != null:
		assert_eq(StationEventBanner.passengers_left(plan, plan.start_index + 1), window - 1, "décompte en passagers")
		assert_string_contains(StationEventBanner.remaining_text(plan, plan.start_index + 1),
				str(window - 1), false)
	# La campagne garde sa plage horaire (D-138).
	var campaign_plan: StationEventPlan = StationEventPlan.new()
	campaign_plan.event = exemption
	campaign_plan.clock_from = exemption.clock_from
	campaign_plan.clock_to = exemption.clock_to
	assert_true(_has_clock(StationEventBanner.remaining_text(campaign_plan, 0)), "campagne : JUSQU'À 14:00")


## QA-055 (écran) : date impossible et caractère accentué ont leur propre
## message ; « Il faut 6 caractères » reste réservé à la longueur.
func test_qa055_garde_screen_names_the_real_reason() -> void:
	var screen: GardeScreen = GardeScreen.new()
	screen.daily_code = "NUIT-2026-10-29"
	add_child_autofree(screen)
	await wait_process_frames(2)
	var length: String = UiText.t("garde_seed_length", "?")
	screen.set_code_text("NUIT-2026-13-40")
	assert_eq(screen.status_text(), UiText.t("garde_seed_bad_date", "?"), "date invalide")
	assert_ne(screen.status_text(), length)
	assert_true(screen.play_code_button.disabled)
	screen.set_code_text("é2Q-9TX")
	assert_eq(screen.status_text(), UiText.t("garde_seed_bad_char", "?"), "caractère non admis")
	screen.set_code_text("K2Q-9T")
	assert_eq(screen.status_text(), length, "longueur")
	screen.set_code_text("NUIT-2026-10-29")
	assert_eq(screen.free_code, "NUIT-2026-10-29", "code du jour valide")
