## AudioDirector (M6) : un événement EventBus → la bonne cue sur le bon bus ;
## limites de voix ; états musicaux ; minuterie ; barks Tessar + ducking ;
## branchement des `PassengerAudio` sur les acteurs du booth réel.
extends GutTest

const BOOTH_SCENE: PackedScene = preload("res://scenes/booth/booth.tscn")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")

var director: AudioDirector = null
var _fx_before: float = 1.0


func before_each() -> void:
	_fx_before = Settings.fx_intensity
	director = AudioDirector.new()
	director.sync_barks = true
	add_child_autofree(director)


func after_each() -> void:
	Settings.set_value(Settings.KEY_FX_INTENSITY, _fx_before, false)


func _last() -> Array:
	return director.history[-1] if not director.history.is_empty() else [&"", &""]


func _case() -> Case:
	var builder: CaseBuilder = CaseBuilder.new(Gen.data(), Gen.data().get_day(1), Gen.day_seed(0, 1))
	return builder.build(0).case


func test_verdicts_play_stamps_on_sfx() -> void:
	EventBus.verdict_stamped.emit(Verdict.new(&"c1", VerdictKind.Kind.APPROVE))
	assert_eq(_last(), [&"booth.stamp_approved", AudioBuses.SFX])
	EventBus.verdict_stamped.emit(Verdict.new(&"c1", VerdictKind.Kind.DENY))
	assert_eq(_last(), [&"booth.stamp_denied", AudioBuses.SFX])
	assert_eq(director.sfx_pool.count_cue(&"booth.stamp_denied"), 1)


func test_comparison_results_play_ui_cues() -> void:
	var d: Discrepancy = Discrepancy.new()
	d.result = Discrepancy.Result.DISCORDANT
	EventBus.discrepancy_checked.emit(d)
	assert_eq(_last(), [&"ui.discrepancy", AudioBuses.UI])
	d.result = Discrepancy.Result.CONCORDANT
	EventBus.discrepancy_checked.emit(d)
	assert_eq(_last(), [&"ui.match", AudioBuses.UI])
	EventBus.discrepancy_check_requested.emit(null, null)
	assert_eq(_last(), [&"ui.field_select_b", AudioBuses.UI])
	EventBus.inspection_mode_changed.emit(true)
	assert_eq(_last(), [&"ui.inspect_mode_on", AudioBuses.UI])


func test_citation_and_booth_flow() -> void:
	EventBus.citation_issued.emit("cit_test")
	assert_eq(_last(), [&"booth.printer_citation", AudioBuses.SFX])
	EventBus.passenger_arrived.emit(&"c1")
	assert_eq(_last(), [&"booth.intercom_on", AudioBuses.SFX])
	EventBus.passenger_departed.emit(&"c1")
	assert_eq(_last(), [&"booth.intercom_off", AudioBuses.SFX])


func test_documents_presented_slot_and_present_bark() -> void:
	var case: Case = _case()
	EventBus.case_presented.emit(case)
	assert_has(director.played_cues(), &"station.door_open")
	EventBus.documents_presented.emit(case.case_id)
	var cues: Array[StringName] = director.played_cues()
	assert_has(cues, &"booth.slot_in")
	assert_eq(cues.count(&"passenger.bark"), 2, "arrivée + présentation")
	assert_true(director.hum_player.playing, "bourdon holo tant que les documents sont ouverts")
	EventBus.case_resolved.emit(case.case_id, CaseResult.new(case.case_id))
	assert_false(director.hum_player.playing)
	assert_eq(_last(), [&"booth.holo_off", AudioBuses.SFX])


func test_bark_on_voice_bus_ducks_music_and_ambience() -> void:
	EventBus.case_presented.emit(_case())
	EventBus.interrogation_answered.emit(&"purpose", "line_purpose_work")
	assert_eq(_last(), [&"passenger.bark", AudioBuses.VOICE])
	assert_true(director.voice_2d.playing, "sans booth : voix 2D sur Voice")
	assert_eq(director.voice_2d.bus, AudioBuses.VOICE)
	director._process(0.2)
	assert_almost_eq(director.duck_db(AudioBuses.MUSIC), AudioDirector.DUCK_VOICE_MUSIC_DB, 0.01)
	assert_almost_eq(director.duck_db(AudioBuses.AMBIENCE), AudioDirector.DUCK_VOICE_AMBIENCE_DB, 0.01)
	director.voice_2d.stop()
	director._process(1.0)
	assert_almost_eq(director.duck_db(AudioBuses.MUSIC), 0.0, 0.01, "relâché")


func test_answer_reaction_is_not_barked_twice() -> void:
	EventBus.case_presented.emit(_case())
	var before: int = director.played_cues().count(&"passenger.bark")
	EventBus.interrogation_answered.emit(&"about_mismatch:id_card", "line_about_id_number_outrage_1")
	EventBus.passenger_reaction_triggered.emit(PassengerReaction.Kind.ANGRY)
	assert_eq(director.played_cues().count(&"passenger.bark"), before + 1, "la réaction n'écrase pas la réplique")


func test_ui_signals_play_hover_toasts_and_departure_bark() -> void:
	var ui: ComparisonUI = (load("res://scenes/ui/comparison_ui.tscn") as PackedScene).instantiate() as ComparisonUI
	add_child_autofree(ui)
	director.bind_ui(ui)
	ui.hovered.emit(ui)
	assert_eq(_last(), [&"ui.hover", AudioBuses.UI])
	var hovers: int = director.played_cues().count(&"ui.hover")
	ui.hovered.emit(ui)
	ui.hovered.emit(ui)
	assert_eq(director.played_cues().count(&"ui.hover"), hovers, "survol limité en fréquence")
	ui.toast_shown.emit(ToastStack.Kind.SUCCESS)
	assert_eq(_last(), [&"ui.toast_success", AudioBuses.UI])
	ui.toast_shown.emit(ToastStack.Kind.ERROR)
	assert_eq(_last(), [&"ui.toast_error", AudioBuses.UI])
	ui.toast_shown.emit(ToastStack.Kind.INFO)
	assert_eq(_last(), [&"ui.toast_info", AudioBuses.UI])
	EventBus.case_presented.emit(_case())
	ui.departure_line_shown.emit("bark_depart_ok", UiText.t("bark_depart_ok"))
	assert_eq(_last(), [&"passenger.bark", AudioBuses.VOICE])


func test_stamp_lift_follows_the_stamp() -> void:
	assert_true(AudioCueBank.has_cue(&"booth.stamp_lift"))
	assert_not_null(AudioCueBank.stream_of(&"booth.stamp_lift"))
	EventBus.verdict_stamped.emit(Verdict.new(&"c1", VerdictKind.Kind.APPROVE))
	assert_does_not_have(director.played_cues(), &"booth.stamp_lift")
	await wait_seconds(AudioDirector.STAMP_LIFT_DELAY_SEC + 0.1)
	assert_has(director.played_cues(), &"booth.stamp_lift")


func test_ui_voice_limit() -> void:
	for i: int in 12:
		director.play_cue(&"ui.toast_info" if i % 2 == 0 else &"ui.match")
	assert_lte(director.ui_pool.active_count(), AudioDirector.UI_VOICES)
	assert_eq(director.ui_pool.count_cue(&"ui.match"), 1, "polyphonie 1 par cue")


func test_music_states_and_ambience() -> void:
	var day: DayDef = DayDef.new()
	day.day_number = 1
	day.duration_sec = 100.0
	day.passenger_count = 8
	var rulebook: Array[RulebookEntry] = []
	EventBus.day_started.emit(day, rulebook)
	for cue: StringName in AudioDirector.AMBIENCE_LOOPS:
		assert_true(director.ambience_players[cue].playing, "boucle %s" % cue)
		assert_eq(director.ambience_players[cue].bus, AudioBuses.AMBIENCE)
	# M14 : un seul lecteur de musique (MusicDirector), plus de `set_music`.
	assert_false(&"set_music" in director, "AudioDirector.set_music() retiré (D-176)")
	assert_not_null(director.music, "MusicDirector enfant")
	assert_eq(director.music.get_parent(), director)
	var players: int = 0
	for child: Node in director.get_children() + director.music.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).bus == AudioBuses.MUSIC:
			players += 1
	assert_eq(players, 1, "un seul lecteur sur le bus Music")
	if director.day_set == null:
		pending("musique M14 pas encore rendue")
		return
	assert_eq(director.day_set.id, &"ms_02", "J1 : Acte I")
	assert_eq(director.music_state, &"briefing")
	assert_eq(director.music.get_current_clip(), &"ms_02")
	assert_eq(director.music.level, MusicDirector.LEVEL_EXPOSED, "briefing « exposé »")
	EventBus.day_phase_changed.emit(DayPhase.Kind.INTRO, &"")
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	assert_eq(director.music_state, &"shift")
	assert_eq(director.music.target_level, 0, "shift : N0 à la mesure suivante")
	EventBus.day_clock_ticked.emit(10.0)
	assert_almost_eq(director.intensity.elapsed_ratio, 0.9, 0.001, "P2 : chrono")
	var d: Discrepancy = Discrepancy.new()
	d.result = Discrepancy.Result.DISCORDANT
	EventBus.discrepancy_checked.emit(d)
	assert_eq(director.intensity.discrepancies, 1, "P3 : discordance constatée")
	EventBus.quota_changed.emit(9, 10)
	assert_eq(director.intensity.quota_used, 9, "P4 : quota")
	for i: int in 40:
		director._update_intensity(0.25)
	assert_gt(director.music.target_level, 1, "la pression monte")
	assert_eq(director.music.player.volume_db, 0.0, "jamais de volume_db de lecteur animé")
	var summary: DaySummary = DaySummary.new()
	EventBus.day_ended.emit(summary)
	assert_eq(director.music_state, &"evening")
	assert_eq(director.music.get_current_clip(), &"ms_06", "bilan et soirée : MS-06")
	assert_true(director.music.groups.has(AudioDirector.GROUP_WARM) or director.music.groups.has(AudioDirector.GROUP_CRISIS))


func test_inspection_power_down_and_queue_murmur() -> void:
	var day: DayDef = DayDef.new()
	day.day_number = 12
	day.duration_sec = 300.0
	day.passenger_count = 8
	var rulebook: Array[RulebookEntry] = []
	EventBus.day_started.emit(day, rulebook)
	assert_eq(AudioDirector.station_bed_cue(day), &"amb.station_bed_a2", "Acte II : lit a2")
	assert_eq(director.ambience_players[&"amb.station_bed"].stream, AudioCueBank.stream_of(&"amb.station_bed_a2"))
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	var was: bool = Settings.get_bool(Settings.KEY_MUSIC_INSPECTION_REDUCE)
	Settings.set_value(Settings.KEY_MUSIC_INSPECTION_REDUCE, true, false)
	EventBus.inspection_mode_changed.emit(true)
	assert_true(director.intensity.inspection_reduce, "Inspection discrète")
	director._update_pause()
	assert_almost_eq(director.music_muffle(), AudioDirector.INSPECTION_CUTOFF_HZ, 0.1, "passe-bas 3,5 kHz")
	for i: int in 30:
		director._update_ducks(0.05)
	assert_almost_eq(director.duck_db(AudioBuses.MUSIC), AudioDirector.INSPECTION_DUCK_DB, 0.05, "−6 dB")
	EventBus.inspection_mode_changed.emit(false)
	Settings.set_value(Settings.KEY_MUSIC_INSPECTION_REDUCE, was, false)
	var plan: StationEventPlan = StationEventPlan.new()
	plan.event = StationEventDef.new()
	plan.event.id = AudioDirector.EVENT_POWER_CUT
	EventBus.station_event_started.emit(plan)
	assert_true(director.intensity.power_down, "EV-05 : power down")
	director._update_pause()
	assert_almost_eq(director.music_muffle(), AudioDirector.POWER_DOWN_CUTOFF_HZ, 0.1, "passe-bas 400 Hz")
	EventBus.station_event_ended.emit(plan)
	assert_false(director.intensity.power_down)
	var none: Array[QueueSilhouette] = []
	EventBus.queue_progressed.emit(0, 8, none)
	assert_eq(director.intensity.queue_remaining, 8, "P1 : file")
	var full: float = director.murmur_db()
	EventBus.queue_progressed.emit(7, 8, none)
	assert_eq(director.intensity.queue_remaining, 1)
	assert_almost_eq(director.murmur_db(), full + AudioDirector.MURMUR_MIN_DB, 0.01, "file vide : murmure −6 dB")


func test_ambient_announcement_is_rendered_and_subtitled() -> void:
	watch_signals(EventBus)
	var day: DayDef = DayDef.new()
	day.day_number = 3
	var rulebook: Array[RulebookEntry] = []
	EventBus.day_started.emit(day, rulebook)
	var key: String = "hall_j7_okonkwo_citation" # toute clé traduite : le texte vient de fr.csv
	director.announce_ambient(key)
	assert_signal_emitted(EventBus, "ambient_announced")
	var params: Array = get_signal_parameters(EventBus, "ambient_announced")
	assert_eq(params[0], key)
	assert_gte(float(params[1]), 2.5, "durée de sous-titre")
	assert_true(director.pa_player.playing, "voix synthétisée jouée")
	assert_eq(director.pa_player.bus, AudioBuses.AMBIENCE)
	assert_eq(director.history[-1][0], &"amb.pa_ambient")
	director.announce_ambient("pa_cle_absente_xyz")
	assert_eq(get_signal_emit_count(EventBus, "ambient_announced"), 1, "clé non traduite : rien")


func test_timer_warning_once_and_critical_ticks_per_second() -> void:
	EventBus.day_clock_ticked.emit(59.5)
	EventBus.day_clock_ticked.emit(58.0)
	assert_eq(director.played_cues().count(&"ui.timer_warning"), 1)
	EventBus.day_clock_ticked.emit(14.6)
	EventBus.day_clock_ticked.emit(14.2)
	EventBus.day_clock_ticked.emit(13.9)
	assert_eq(director.played_cues().count(&"ui.timer_critical_tick"), 2, "un tick par seconde")
	Settings.set_value(Settings.KEY_FX_INTENSITY, 0.0, false)
	EventBus.day_clock_ticked.emit(12.5)
	assert_eq(director.played_cues().count(&"ui.timer_critical_tick"), 2, "réduire les effets : visuel seul")


func test_new_rule_chime_is_delayed_consortium_carillon() -> void:
	var day: DayDef = DayDef.new()
	var entry: RulebookEntry = RulebookEntry.new()
	entry.is_new = true
	var rulebook: Array[RulebookEntry] = [entry]
	EventBus.day_started.emit(day, rulebook)
	assert_does_not_have(director.played_cues(), &"ui.rule_new")
	await wait_seconds(AudioDirector.RULE_CHIME_DELAY_SEC + 0.2)
	assert_has(director.played_cues(), &"ui.rule_new")


func test_attaches_passenger_audio_to_booth_actors() -> void:
	var booth: BoothDirector = BOOTH_SCENE.instantiate()
	add_child_autofree(booth)
	var d: AudioDirector = AudioDirector.new()
	d.booth = booth
	d.sync_barks = true
	add_child_autofree(d)
	assert_eq(d.passenger_audio.size(), BoothDirector.POOL_SIZE)
	assert_true(d.listener != null and d.listener.is_current(), "écoute 3D côté agent")
	assert_true(booth.get_viewport().audio_listener_enable_3d)
	var actor: PassengerActor = booth.actors[0]
	var pa: PassengerAudio = d.passenger_audio[actor]
	assert_eq(pa.get_parent(), actor, "émetteurs portés par l'acteur")
	assert_eq(pa.voice.bus, AudioBuses.VOICE)
	assert_eq(pa.foot.bus, AudioBuses.SFX_WORLD)
	actor.visible = true
	actor.anim_event.emit(&"footstep_l")
	assert_eq(pa.history[-1], [&"passenger.step", AudioBuses.SFX_WORLD])
	actor.anim_event.emit(&"documents_slot")
	assert_eq(pa.history[-1], [&"passenger.paper_rustle", AudioBuses.SFX])
	Settings.set_value(Settings.KEY_AUDIO_MONO, true, false)
	assert_eq(pa.voice.panning_strength, 0.0, "mono : pas de panoramique 3D")
	Settings.set_value(Settings.KEY_AUDIO_MONO, false, false)
	assert_gt(pa.voice.panning_strength, 0.0)


## QA-012 : booth libéré après le branchement (`--no-booth`) : plus de
## SCRIPT ERROR à chaque image, les émetteurs morts sont purgés.
func test_freed_booth_actors_are_purged_without_error() -> void:
	var booth: BoothDirector = BOOTH_SCENE.instantiate()
	add_child(booth)
	var d: AudioDirector = AudioDirector.new()
	d.booth = booth
	add_child_autofree(d)
	assert_eq(d.passenger_audio.size(), BoothDirector.POOL_SIZE)
	booth.free()
	assert_false(d.is_voice_active())
	assert_eq(d.passenger_audio.size(), 0, "émetteurs libérés purgés")
	assert_eq(d.live_passenger_audio().size(), 0)
	await wait_process_frames(2)
	assert_false(d.is_voice_active())


## Finition M13 : une réponse à cadre de déclarations est prononcée composée
## (`Statement.compose`), jamais avec ses emplacements `{motif}` bruts.
func test_statement_frame_is_spoken_composed() -> void:
	var c: Case = Case.new()
	c.statements = [Statement.make(Statement.ID_PURPOSE, Passenger.PURPOSE_TRADE, "stmt_purpose_trade_1"),
			Statement.duration(5, 5, "stmt_dur_d5")] as Array[Statement]
	var text: String = AudioDirector.answer_text(c, "line_stmt_frame_gen_2")
	assert_false(text.contains("{"), text)
	assert_eq(text, "Le commerce, pour cinq jours. C'est écrit sur le permis.")
	assert_eq(AudioDirector.answer_text(null, "line_stmt_frame_gen_2"), UiText.t("line_stmt_frame_gen_2"), "sans cas : texte tel quel")
	assert_eq(AudioDirector.answer_text(c, "line_generic_shrug"), UiText.t("line_generic_shrug"), "réplique ordinaire inchangée")
