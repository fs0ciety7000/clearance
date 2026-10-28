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
	day.duration_sec = 100.0
	var rulebook: Array[RulebookEntry] = []
	EventBus.day_started.emit(day, rulebook)
	assert_eq(director.music_cue, &"mus.briefing")
	for cue: StringName in AudioDirector.AMBIENCE_LOOPS:
		assert_true(director.ambience_players[cue].playing, "boucle %s" % cue)
		assert_eq(director.ambience_players[cue].bus, AudioBuses.AMBIENCE)
	EventBus.day_phase_changed.emit(DayPhase.Kind.INTRO, &"")
	EventBus.day_phase_changed.emit(DayPhase.Kind.WAITING_CASE, &"")
	assert_eq(director.music_cue, &"mus.shift_calm")
	EventBus.day_clock_ticked.emit(30.0)
	assert_eq(director.music_cue, &"mus.shift_calm", "au-dessus de 25 %")
	EventBus.day_clock_ticked.emit(24.0)
	assert_eq(director.music_cue, &"mus.shift_tension")
	assert_eq(director.music_players[director._music_index].bus, AudioBuses.MUSIC)
	var summary: DaySummary = DaySummary.new()
	EventBus.day_ended.emit(summary)
	assert_true(director.music_cue == &"mus.debrief" or director.music_cue == &"mus.debrief_minor")


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
