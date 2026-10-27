## Écrans M5 (UI_FLOW §7, §8 ; DS §7.9) : briefing, ticket de citation, bilan
## de shift, soirée, fin, pause/options ; contenu du briefing ; complétude des
## traductions des nouvelles clés. Construction headless, sans scène de jour.
extends GutTest

const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var data: DataCatalog = null


func before_all() -> void:
	data = Gen.data()


func _sim_summary(day_number: int = 1) -> DaySummary:
	var policy: Callable = func(_c: Case, key: CaseKey, index: int) -> VerdictKind.Kind:
		return VerdictKind.Kind.APPROVE if index == 1 else key.expected_verdict
	return DaySimulator.simulate(data, day_number, Gen.day_seed(0, day_number), policy, true, true, -1, [4])


func _texts_of(node: Node) -> String:
	var parts: PackedStringArray = []
	for child: Node in node.find_children("*", "Label", true, false):
		parts.append((child as Label).text)
	return "\n".join(parts)


func test_briefing_content_day1_and_echoes() -> void:
	var d1: BriefingContent = BriefingContent.build(data.get_day(1), {}, Household.new())
	assert_eq(d1.day_number, 1)
	assert_eq(d1.get_new_entries().size(), 2, "R01, R02 NOUVEAU")
	var texts: Array[String] = []
	for message: Dictionary in d1.messages:
		texts.append(message["text"])
	assert_true(texts.has("msg_okonkwo_day01"), "tutoriel d'Okonkwo au J1")
	var flags: Dictionary[StringName, Variant] = {&"sc02_mercy": true}
	var sick: Household = Household.new()
	sick.get_member(Household.NOA).health = Household.Health.SICK
	var d2: BriefingContent = BriefingContent.build(data.get_day(2), flags, sick)
	var d2_texts: Array[String] = []
	for message: Dictionary in d2.messages:
		d2_texts.append(message["text"])
	assert_true(d2_texts.has("msg_echo_sc02_mercy"), "écho du dilemme de la veille")
	assert_true(d2_texts.has("msg_family_noa_sick"))
	assert_eq(BriefingContent.family_message_key(3, Household.new()), "msg_family_ok")


func test_briefing_announces_consortium_advance_on_day1_only() -> void:
	var advance: int = data.get_economy().starting_credits
	assert_eq(advance, 20, "D-047")
	var d1: BriefingContent = BriefingContent.build(data.get_day(1), {}, Household.new(), advance)
	assert_eq(d1.advance_credits, advance)
	var d2: BriefingContent = BriefingContent.build(data.get_day(2), {}, Household.new(), advance)
	assert_eq(d2.advance_credits, 0, "pas d'avance après le J1")
	var screen: BriefingScreen = BriefingScreen.new()
	screen.setup(d1, Household.new(), advance, data.get_day(1))
	add_child_autofree(screen)
	await wait_process_frames(2)
	var text: String = _texts_of(screen)
	assert_string_contains(text, UiText.tf(BriefingContent.MSG_ADVANCE, [advance]))
	assert_string_contains(text, "+20 ₵")
	assert_string_contains(text, UiText.tf("br_balance_advance", [ScreenBase.credits(advance)]))


func test_evening_day1_shows_consortium_advance() -> void:
	var advance: int = data.get_economy().starting_credits
	var net: int = 26
	var balance: int = advance + net
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), 1, Household.new())
	EveningService.default_selection(lines, balance)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(1), balance, net, lines, Household.new(), false, advance)
	add_child_autofree(screen)
	await wait_process_frames(2)
	var text: String = _texts_of(screen)
	assert_string_contains(text, UiText.t("ev_advance"))
	assert_string_contains(text, "+20 ₵")
	assert_false(text.contains(UiText.t("ev_morning")), "solde du matin = l'avance : une seule ligne")
	assert_string_contains(text, ScreenBase.credits(balance), "disponible = avance + net du shift")
	# Cohérence avec EveningService : le solde de départ de la soirée inclut l'avance.
	var report: EveningReport = EveningService.apply(data.get_economy(), 1, Household.new(), lines, balance, 1)
	assert_eq(report.balance_before, advance + net)
	assert_eq(report.balance_after, advance + net - EveningService.total_spent(lines))


func test_all_briefing_keys_are_translated() -> void:
	var keys: Array[String] = ["msg_echo_sc02_mercy", "msg_echo_sc02_turned_away", "msg_echo_sc03_passed",
			"msg_family_day01", "msg_family_ok", "msg_family_cold", "msg_family_hungry", "msg_family_noa_sick",
			"msg_family_sick", "msg_family_grave", "msg_family_lost", "spk_okonkwo", "spk_ilan", "spk_hall",
			"spk_treasury", BriefingContent.MSG_ADVANCE, "br_advance_line", "br_balance_advance", "ev_advance"]
	for n: int in [1, 2, 3]:
		var content: BriefingContent = BriefingContent.build(data.get_day(n), {}, Household.new())
		keys.append_array([content.directive_key, content.directive_title_key, content.slogan_key, "msg_okonkwo_day%02d" % n])
	for key: String in keys:
		assert_true(UiText.has(key), "clé traduite : %s" % key)


func test_gameplay_keys_are_translated() -> void:
	var keys: Array[String] = []
	for citation: String in ScoringService.GRAVITY:
		keys.append_array([citation, citation + "_desc"])
	for code: String in ["well", "hungry", "cold", "hungry_cold", "sick", "gravely_sick", "lost"]:
		keys.append("hh_state_" + code)
	for id: StringName in Household.MEMBER_IDS:
		keys.append_array(["hh_name_%s" % id, "hh_role_%s" % id, "hh_note_%s" % id])
	for event: String in ["hh_ev_better", "hh_ev_cured", "hh_ev_untreated", "hh_ev_worse", "hh_ev_lost", "hh_ev_hungry",
			"hh_ev_sick_hunger", "hh_ev_cold", "hh_ev_sick_cold", "hh_ev_noa_cough", "hh_ev_oxygen", "hh_ev_oxygen_grave",
			"hh_ev_rent_unpaid", "hh_ev_debt", "hh_ev_calm"]:
		keys.append(event)
	var home: Household = Household.new()
	home.get_member(Household.DORA).health = Household.Health.GRAVELY_SICK
	for line: ExpenseLine in EveningService.build_lines(data.get_economy(), 2, home):
		keys.append_array([line.label_key, line.note_key])
	for ending: String in ["demo_complete", "f2_reassigned", "f3_family_lost"]:
		keys.append_array(["end_title_" + ending, "end_text_" + ending, "end_eyebrow_" + ending])
	for flag: StringName in EndScreen.NARRATIVE_FLAGS:
		keys.append("end_trace_%s" % flag)
	var intercom_script: Script = load("res://scripts/day/okonkwo_intercom.gd")
	for key: String in intercom_script.get_script_constant_map().values().filter(
			func(v: Variant) -> bool: return v is String and String(v).begins_with("okonkwo_")):
		keys.append(key)
	for key: String in keys:
		assert_true(UiText.has(key), "clé traduite : %s" % key)


func test_briefing_screen_builds_and_closes_once() -> void:
	var screen: BriefingScreen = BriefingScreen.new()
	screen.setup(BriefingContent.build(data.get_day(1), {}, Household.new()), Household.new(), 0, data.get_day(1))
	watch_signals(screen)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.start_button)
	var text: String = _texts_of(screen)
	assert_string_contains(text, "JOUR 01")
	assert_string_contains(text, UiText.t("msg_okonkwo_day01"))
	assert_eq(screen.find_children("*", "PanelContainer", true, false).filter(
			func(n: Node) -> bool: return (n as Control).theme_type_variation == &"BadgeNew").size(), 2, "2 badges NOUVEAU")
	screen.close()
	screen.close()
	assert_signal_emit_count(screen, "closed", 1)
	assert_signal_emitted_with_parameters(screen, "finished", [&"start"])


func test_citation_ticket_states() -> void:
	var day: DayDef = data.get_day(1)
	var result: CaseResult = CaseResult.new()
	result.citation_reason_key = ScoringService.CIT_IRREGULAR_ENTRY
	ScoringService.apply_citation(result, 1, day)
	var warning: CitationTicket = CitationTicket.make(result, 1, 2, "Carte d'identité valide")
	add_child_autofree(warning)
	var warning_text: String = _texts_of(warning)
	assert_string_contains(warning_text, "AVERTISSEMENT 1/2")
	assert_string_contains(warning_text, "G04-J01-01")
	assert_string_contains(warning_text, "Règle 02")
	var fined: CaseResult = CaseResult.new()
	fined.citation_reason_key = ScoringService.CIT_UNDOCUMENTED_DENIAL
	ScoringService.apply_citation(fined, 4, day)
	var fine: CitationTicket = CitationTicket.make(fined, 1, 0, "", 2, true)
	add_child_autofree(fine)
	assert_string_contains(_texts_of(fine), "AMENDE −10 ₵")
	assert_almost_eq(fine.modulate.a, CitationTicket.ARCHIVED_ALPHA, 0.01, "archivé : 40 %")


func test_shift_summary_screen() -> void:
	var summary: DaySummary = _sim_summary()
	assert_gt(summary.get_citation_count(), 0)
	var screen: ShiftSummaryScreen = ShiftSummaryScreen.new()
	screen.setup(summary, data.get_day(1))
	watch_signals(screen)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(screen.find_children("*", "CitationTicket", true, false).size(), summary.get_citation_count())
	var text: String = _texts_of(screen)
	assert_string_contains(text, "BILAN DU SHIFT — JOUR 01")
	assert_string_contains(text, UiText.t(ScoringService.CIT_IRREGULAR_ENTRY))
	assert_string_contains(text, "Non relevé")
	screen.continue_button.pressed.emit()
	assert_signal_emitted_with_parameters(screen, "finished", [&"evening"])


func test_evening_screen_toggles_and_report() -> void:
	var home: Household = Household.new()
	home.get_member(Household.NOA).health = Household.Health.SICK
	var lines: Array[ExpenseLine] = EveningService.build_lines(data.get_economy(), 2, home)
	EveningService.default_selection(lines, 30)
	var screen: EveningScreen = EveningScreen.new()
	screen.setup(data.get_day(2), 30, 30, lines, home, true)
	watch_signals(screen)
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_eq(EveningService.total_spent(lines), 30, "présélection : loyer + taxe + nourriture")
	assert_false(screen.set_line_paid(&"heating", true), "chauffage : fonds insuffisants")
	assert_true(screen.set_line_paid(&"food", false))
	assert_true(screen.set_line_paid(&"heating", true), "nourriture décochée → chauffage payable")
	assert_false(screen.set_line_paid(&"air_tax", false) and false)
	assert_true(lines[1].paid, "taxe d'air toujours payée")
	screen.confirm()
	assert_signal_emitted(screen, "luciole_decided", "le mot non tranché est brûlé")
	assert_signal_emitted(screen, "confirmed")
	var report: EveningReport = EveningService.apply(data.get_economy(), 2, home, lines, 30, 1)
	screen.show_report(report, &"")
	assert_not_null(screen.get_report_button())
	screen.get_report_button().pressed.emit()
	assert_signal_emitted_with_parameters(screen, "finished", [&"next"])


func test_end_screens_build() -> void:
	for ending: StringName in [Campaign.ENDING_DEMO_COMPLETE, EveningReport.ENDING_REASSIGNED, EveningReport.ENDING_FAMILY_LOST]:
		var screen: EndScreen = EndScreen.new()
		var history: Array[Dictionary] = [{"day": 1, "processed": 8, "planned": 8, "correct": 7, "citations": 1,
				"wage": 35, "fines": 0, "spent": 38, "balance": -3}]
		var flags: Dictionary[StringName, Variant] = {&"met_mira": true}
		screen.setup(ending, history, Household.new(), -3, flags, 0.875)
		add_child_autofree(screen)
		await wait_process_frames(1)
		var text: String = _texts_of(screen)
		assert_string_contains(text, UiText.t("end_title_%s" % ending))
		assert_string_contains(text, "88 %")
		assert_string_contains(text, UiText.t("end_trace_met_mira"))


func test_pause_menu_pauses_and_escape_toggles() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"cancel"
	escape.pressed = true
	pause._unhandled_input(escape)
	assert_true(pause.is_open, "Échap non consommé par l'UI → pause")
	assert_true(get_tree().paused)
	pause.show_options()
	assert_true(pause.options.visible)
	pause._input(escape)
	assert_false(pause.options.visible, "Échap : retour au menu")
	assert_true(pause.is_open)
	pause._input(escape)
	assert_false(pause.is_open, "Échap : reprendre")
	assert_false(get_tree().paused)
	var f10: InputEventKey = InputEventKey.new()
	f10.keycode = KEY_F10
	f10.pressed = true
	assert_true(PauseMenu.is_pause_event(f10))
	pause.enabled = false
	pause._unhandled_input(escape)
	assert_false(pause.is_open)


func test_pause_quit_needs_confirmation() -> void:
	var pause: PauseMenu = PauseMenu.new()
	add_child_autofree(pause)
	await wait_process_frames(1)
	watch_signals(pause)
	pause.open()
	pause._on_quit_pressed()
	assert_signal_not_emitted(pause, "quit_to_title_requested", "premier appui : confirmation")
	pause._on_quit_pressed()
	assert_signal_emitted(pause, "quit_to_title_requested")
	assert_false(get_tree().paused)


func test_options_panel_drives_settings() -> void:
	var before: float = Settings.text_scale
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	var slider: HSlider = panel.controls[Settings.KEY_TEXT_SCALE] as HSlider
	assert_not_null(slider)
	slider.value = 1.2
	assert_almost_eq(Settings.text_scale, 1.2, 0.001)
	for key: StringName in [Settings.KEY_REDUCE_MOTION, Settings.KEY_SUBTITLES, Settings.KEY_CLOCK_SLOW_ACCESSIBILITY,
			Settings.KEY_FX_INTENSITY, Settings.KEY_AUDIO_MONO] + OptionsPanel.VOLUME_KEYS:
		assert_true(panel.controls.has(key), "réglage %s présent" % key)
	Settings.set_value(Settings.KEY_TEXT_SCALE, before, false)


func test_options_mono_toggle_drives_setting() -> void:
	var before: bool = Settings.get_bool(Settings.KEY_AUDIO_MONO)
	Settings.set_value(Settings.KEY_AUDIO_MONO, false, false)
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	var toggle: Button = panel.controls[Settings.KEY_AUDIO_MONO] as Button
	assert_false(toggle.button_pressed)
	toggle.button_pressed = true
	assert_true(Settings.get_bool(Settings.KEY_AUDIO_MONO), "Son mono activé")
	assert_true(UiText.has("opt_audio_mono") and UiText.has("opt_audio_mono_hint"))
	Settings.set_value(Settings.KEY_AUDIO_MONO, before, false)
