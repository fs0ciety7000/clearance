## M16 « En ligne » — interface et intégration au jeu (UI_FLOW §8.10, §9 ;
## ARCHITECTURE §18), sans réseau réel : l'autoload `OnlineService` reçoit un
## `FakeOnlineServer` et un dossier de compte jetable.
## Couvre : Options › Compte (sans compte, connexion par code à la manette et
## au clavier, pseudo, synchronisation, déconnexion, suppression en deux
## temps, menu pause), indicateur du titre, conflit à l'écran Charger,
## classement de la Garde (accueil, fin), « X % des agents » au Dossier (fins
## vues seulement), aucune requête pendant un shift, jeu jouable sans compte.
extends GutTest

const DayHarness := preload("res://tests/helpers/day_harness.gd")
const Gen := preload("res://tests/helpers/generation_fixtures.gd")
const GameStateScript: GDScript = preload("res://scripts/autoload/game_state.gd")
const STORE: String = "user://test_m16_ui_store"
const CAMPAIGN_SEED: int = 16_160_001

var server: FakeOnlineServer = null
var host: Control = null
var h: DayHarness = null
var _saved_state: Dictionary = {}


func before_each() -> void:
	_clear_saves()
	SaveService.remove_tree(STORE)
	server = FakeOnlineServer.new()
	OnlineService.use_transport(server, SaveService.DEFAULT_DIR, OnlineStore.new(STORE))
	OnlineService.client.retry_delays = [0.0, 0.0, 0.0]
	host = Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.theme = ThemeBuilder.build(1.0, 0)
	add_child_autofree(host)


func after_each() -> void:
	if h != null:
		h.dispose()
		h = null
	OnlineService.client.set_quiet(false)
	OnlineService.use_transport(FakeOnlineServer.new(), SaveService.DEFAULT_DIR)
	SaveService.remove_tree(STORE)
	_clear_saves()
	if not _saved_state.is_empty():
		GameState.apply_save_dict(_saved_state)
		_saved_state = {}


func _clear_saves() -> void:
	for slot: int in range(1, SaveService.SLOT_COUNT + 1):
		SaveService.delete_slot(slot)
	SaveService.remove_with_fallbacks(ProfileService.profile_path())


func _sign_in(pseudo: String = "") -> void:
	await OnlineService.client.request_code("nadia@example.org")
	await OnlineService.client.submit_code(server.last_code)
	if not pseudo.is_empty():
		await OnlineService.client.set_pseudo(pseudo)


func _panel(in_game: bool = false) -> OptionsPanel:
	var panel: OptionsPanel = OptionsPanel.new()
	panel.in_game = in_game
	host.add_child(panel)
	await wait_process_frames(2)
	return panel


# ---------------------------------------------------------------------------
# Options › Compte
# ---------------------------------------------------------------------------

func test_account_section_signed_out() -> void:
	var panel: OptionsPanel = await _panel()
	var section: AccountSection = panel.account
	assert_not_null(section)
	assert_not_null(section.sign_in_button)
	assert_eq(section.sign_in_button.focus_mode, Control.FOCUS_ALL)
	assert_gte(section.sign_in_button.size.y, float(DS.HIT_TARGET_MIN))
	assert_null(section.sync_button, "rien d'autre sans compte")
	assert_eq(server.sent, 0, "aucune requête sans compte")


func test_sign_in_dialog_by_code_with_gamepad() -> void:
	var panel: OptionsPanel = await _panel()
	var dialog: SignInDialog = panel.account.open_sign_in()
	await wait_process_frames(2)
	assert_true(dialog.is_in_group(FocusGuard.MODAL_GROUP))
	assert_eq(get_viewport().gui_get_focus_owner(), dialog.email_input, "focus initial : adresse")
	dialog.email_input.text = "pas-une-adresse"
	dialog.send_code()
	assert_eq(dialog.status_label.text, OnlineText.error_text(OnlineClient.ERR_EMAIL))
	assert_eq(server.sent, 0, "adresse refusée localement")
	dialog.email_input.text = "nadia@example.org"
	dialog.send_code()
	await wait_process_frames(2)
	assert_eq(dialog.step, SignInDialog.Step.CODE)
	assert_eq(get_viewport().gui_get_focus_owner(), dialog.code_entry, "focus : saisie du code")
	# « RENVOYER LE CODE » attend 60 s après l'envoi (ONLINE.md §2.1).
	assert_true(dialog.resend_button.disabled, "renvoi pas tout de suite")
	assert_gt(dialog.resend_wait_s(), SignInDialog.RESEND_DELAY_S - 5)
	assert_eq(dialog.resend_button.text, UiText.tf("acct_resend_wait", [dialog.resend_wait_s()], "RENVOYER DANS %d s"))
	# Manette : croix ↑ sur chaque case (case vide → 0, puis +1), → pour avancer.
	for i: int in server.last_code.length():
		var digit: int = server.last_code[i].to_int()
		for n: int in digit + 1:
			_press(&"ui_up")
		if i < server.last_code.length() - 1:
			_press(&"ui_right")
	assert_eq(dialog.code_entry.code(), server.last_code)
	var closed: Array = [false]
	dialog.closed.connect(func() -> void: closed[0] = true)
	_press(&"ui_accept")
	await wait_process_frames(3)
	assert_true(closed[0], "connecté·e : la boîte se ferme")
	assert_true(OnlineService.has_account())
	assert_not_null(panel.account.sync_button, "section du compte connecté")
	assert_not_null(panel.account.pseudo_input)
	assert_not_null(panel.account.delete_button)


func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	var release: InputEventAction = InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func test_sign_in_dialog_errors_and_cancel() -> void:
	var panel: OptionsPanel = await _panel()
	var dialog: SignInDialog = panel.account.open_sign_in()
	await wait_process_frames(1)
	dialog.email_input.text = "nadia@example.org"
	dialog.send_code()
	await wait_process_frames(1)
	dialog.code_entry.set_code("000000" if server.last_code != "000000" else "111111")
	dialog.verify_code()
	assert_eq(dialog.status_label.text, OnlineText.error_text(OnlineClient.ERR_OTP))
	assert_false(OnlineService.has_account())
	server.offline = true
	dialog.code_entry.set_code(server.last_code)
	dialog.verify_code()
	assert_eq(dialog.status_label.text, OnlineText.error_text(OnlineClient.ERR_NETWORK))
	var closed: Array = [false]
	dialog.closed.connect(func() -> void: closed[0] = true)
	_press(&"ui_cancel")
	assert_true(closed[0], "Ⓑ annule")
	await wait_process_frames(2)
	assert_false(is_instance_valid(dialog), "boîte libérée")


func test_account_actions_pseudo_sync_sign_out_delete() -> void:
	_play_slot(1, 3)
	await _sign_in()
	var panel: OptionsPanel = await _panel()
	var section: AccountSection = panel.account
	section.pseudo_input.text = "Nadia"
	section.save_pseudo()
	await wait_process_frames(2)
	assert_eq(OnlineService.display_name(), "Nadia")
	assert_eq(section.message(), UiText.t("acct_pseudo_saved"))
	section.auto_sync_button.button_pressed = false
	assert_false(OnlineService.auto_sync())
	section.auto_sync_button.button_pressed = true
	section.sync_now()
	await wait_process_frames(2)
	assert_gt(server.saves.values()[0].size(), 0, "emplacement envoyé")
	assert_gt(OnlineService.last_sync_unix_ms(), 0)
	# Suppression : deux confirmations, focus ANNULER.
	var first: ConfirmDialog = section.confirm_delete()
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), first.cancel_button)
	first.accept()
	await wait_process_frames(2)
	var second: ConfirmDialog = section.dialog as ConfirmDialog
	assert_not_null(second, "seconde confirmation")
	assert_eq(get_viewport().gui_get_focus_owner(), second.cancel_button)
	second.accept()
	await wait_process_frames(2)
	assert_false(OnlineService.has_account())
	assert_eq(server.users.size(), 0, "compte effacé du serveur")
	assert_true(SaveService.has_save(1), "données locales intactes")
	assert_not_null(section.sign_in_button)


func test_sign_out_keeps_local_data() -> void:
	_play_slot(2, 2)
	await _sign_in()
	var panel: OptionsPanel = await _panel()
	panel.account.sign_out()
	await wait_process_frames(1)
	assert_false(OnlineService.has_account())
	assert_true(SaveService.has_save(2))
	assert_not_null(panel.account.sign_in_button)


func test_pause_options_show_status_only() -> void:
	await _sign_in("Nadia")
	var panel: OptionsPanel = await _panel(true)
	assert_null(panel.account.sync_button, "rien à envoyer pendant un shift")
	assert_null(panel.account.delete_button)
	assert_not_null(panel.account.find_child("StateChip", true, false))


# ---------------------------------------------------------------------------
# Titre
# ---------------------------------------------------------------------------

func test_status_badge_states() -> void:
	var c: Dictionary = OnlineStatusBadge.describe(OnlineClient.State.CONNECTED, "", false, false, true, "Nadia")
	assert_true(c["visible"])
	assert_eq(c["text"], "EN LIGNE · Nadia")
	assert_eq(c["icon"], UiIcon.Kind.CHECK)
	assert_false(OnlineStatusBadge.describe(OnlineClient.State.DISCONNECTED, "", false, false, false, "")["visible"], "masqué sans compte")
	assert_true(OnlineStatusBadge.describe(OnlineClient.State.DISCONNECTED, OnlineClient.ERR_SESSION, false, false, false, "")["visible"])
	assert_eq(OnlineStatusBadge.describe(OnlineClient.State.OFFLINE, "", false, false, true, "")["icon"], UiIcon.Kind.WARNING)
	assert_eq(OnlineStatusBadge.describe(OnlineClient.State.CONNECTED, "", true, false, true, "")["text"], "SYNCHRONISATION…")
	assert_string_contains(OnlineStatusBadge.describe(OnlineClient.State.CONNECTED, "", false, true, true, "")["text"], "CHARGER")


func test_title_badge_and_pull() -> void:
	# Un autre appareil a envoyé une partie au J5 : le titre la tire.
	var other: OnlineClient = OnlineClient.new(server, OnlineStore.new("user://test_m16_ui_other/online"), "user://test_m16_ui_other")
	_play_slot(1, 4, "user://test_m16_ui_other")
	await other.request_code("nadia@example.org")
	await other.submit_code(server.last_code)
	await _sign_in("Nadia")
	SaveService.delete_slot(1)
	OnlineService.client.store.set_base(OnlineService.client.family, "slot_1", {})
	var title: Control = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	title.set(&"change_scene", false)
	host.add_child(title)
	await wait_process_frames(3)
	var badge: OnlineStatusBadge = title.get(&"online_badge")
	assert_not_null(badge)
	assert_true(badge.visible)
	assert_eq(badge.text_label.text, "EN LIGNE · Nadia")
	assert_true(SaveService.has_save(1), "partie tirée à l'écran titre")
	assert_string_contains((title.get(&"continue_button") as Button).text, "5", "CONTINUER — JOUR 5")
	SaveService.remove_tree("user://test_m16_ui_other")


# ---------------------------------------------------------------------------
# Charger : conflit
# ---------------------------------------------------------------------------

func _play_slot(slot: int, days: int, dir: String = SaveService.DEFAULT_DIR) -> void:
	var state: Node = autofree(GameStateScript.new())
	state.call(&"new_campaign", CAMPAIGN_SEED + slot, slot, &"hard")
	for i: int in days:
		state.call(&"record_day_entry", {"processed": 5, "correct": 5, "credits": 25})
		state.call(&"save_to_slot", slot, dir)


func test_load_screen_conflict_choice() -> void:
	_play_slot(1, 2)
	var older: Dictionary = SaveService.read_slot_files(1)
	_play_slot(1, 5)
	SaveService.write_conflict(1, older, {"source": "remote", "device": "Deck"}, "20261101T020000")
	var screen: LoadScreen = LoadScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var card: SaveSlotCard = screen.cards[0]
	assert_not_null(card.conflict_box)
	assert_string_contains((card.conflict_box.find_child("ConflictText", true, false) as Label).text, "Deck")
	assert_true(screen.keep_this_buttons.has(1))
	assert_true(screen.keep_other_buttons.has(1))
	assert_string_contains(screen.keep_other_buttons[1].text, "03")
	# Croix : les deux actions sont atteignables.
	for b: Button in [screen.keep_this_buttons[1], screen.keep_other_buttons[1]]:
		assert_eq(b.focus_mode, Control.FOCUS_ALL)
	screen.keep_other_buttons[1].pressed.emit()
	await wait_process_frames(2)
	assert_not_null(screen.dialog)
	assert_eq(get_viewport().gui_get_focus_owner(), screen.dialog.cancel_button, "focus ANNULER")
	screen.dialog.accept()
	await wait_process_frames(2)
	assert_eq(SaveService.as_int(SaveService.load_meta(1).get("current_day", 0)), 3, "l'autre version reprise")
	assert_false(SaveService.has_conflict(1))
	assert_null(screen.cards[0].conflict_box)


func test_load_screen_keep_this_discards_the_copy() -> void:
	_play_slot(2, 2)
	SaveService.write_conflict(2, SaveService.read_slot_files(2), {"source": "local"}, "20261101T030000")
	var screen: LoadScreen = LoadScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(2)
	screen.keep_this_buttons[2].pressed.emit()
	await wait_process_frames(1)
	screen.dialog.accept()
	await wait_process_frames(1)
	assert_false(SaveService.has_conflict(2))
	assert_true(SaveService.has_save(2))


# ---------------------------------------------------------------------------
# Garde, Dossier
# ---------------------------------------------------------------------------

func test_garde_leaderboard_without_account() -> void:
	var screen: GardeScreen = GardeScreen.new()
	screen.profile = {"max_day_reached": 3}
	add_child_autofree(screen)
	await wait_process_frames(2)
	assert_not_null(screen.leaderboard)
	assert_eq(screen.leaderboard.note_text(), UiText.t("lb_no_account"))
	assert_eq(server.sent, 0)


func test_garde_leaderboard_top10_and_my_rank() -> void:
	var login: Dictionary = server.seed_demo(GardeService.today_code(), GardeScreen.current_version())
	OnlineService.client.store.set_session(str(login["token"]), login["record"], "nadia.demo@example.org")
	var screen: GardeScreen = GardeScreen.new()
	screen.profile = {"max_day_reached": 3}
	add_child_autofree(screen)
	await wait_process_frames(2)
	var rows: Array[Dictionary] = screen.leaderboard.shown_entries()
	assert_eq(rows.size(), 10, "top 10")
	assert_eq(int(rows[0]["rank"]), 1)
	var mine: Array = rows.filter(func(r: Dictionary) -> bool: return r["is_me"])
	assert_eq(mine.size(), 1, "ligne du joueur marquée")
	assert_eq(str(mine[0]["name"]), "Nadia")
	assert_string_contains(screen.leaderboard.note_text(), "/ 15")
	# Hors ligne : le dernier classement connu reste affiché.
	server.offline = true
	screen.leaderboard.refresh()
	await wait_process_frames(1)
	assert_eq(screen.leaderboard.shown_entries().size(), 10)
	assert_string_contains(screen.leaderboard.note_text(), UiText.t("lb_offline_cached"))


func test_garde_end_submits_score_and_shows_rank() -> void:
	await _sign_in("Nadia")
	var record: Dictionary = {"score": 40, "seed_code": GardeService.today_code(), "kind": "daily", "date": "", "played_on": "2026-11-01",
			"garde_version": GardeScreen.current_version(), "duration_sec": 900, "directives": 5, "palier": 1, "passengers": 30,
			"end_reason": "errors", "errors": [{}, {}, {}], "clock_minute": 200}
	var end: GardeEndScreen = GardeEndScreen.new()
	end.setup(record, {"first_try": true})
	add_child_autofree(end)
	await wait_process_frames(2)
	assert_eq(server.scores.size(), 1, "score envoyé au classement")
	assert_true((server.scores.values()[0] as Dictionary)["first_try"])
	assert_not_null(end.leaderboard)
	assert_eq(end.leaderboard.shown_entries().size(), 1)
	assert_string_contains(end.leaderboard.note_text(), "1 / 1")
	assert_eq(get_viewport().gui_get_focus_owner(), end.replay_button, "focus inchangé : REJOUER")


func test_dossier_percent_only_for_seen_endings() -> void:
	var login: Dictionary = server.seed_demo(GardeService.today_code(), GardeScreen.current_version())
	OnlineService.client.store.set_session(str(login["token"]), login["record"], "nadia.demo@example.org")
	var profile: Dictionary = ProfileService.empty_profile()
	profile["endings_seen"] = [{"id": "f5_air", "variant": "", "act": 3, "day": 30, "date": "2026-10-26T22:41:00", "count": 1,
		"last_date": "2026-10-26T22:41:00", "first_line_key": ""}]
	profile["max_day_reached"] = 30
	ProfileService.save_profile(profile)
	var screen: DossierScreen = DossierScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(2)
	var seen: HBoxContainer = screen.percent_rows.get("f5_air", null)
	assert_not_null(seen)
	assert_true(seen.visible)
	assert_string_contains((seen.get_child(1) as Label).text, "des agents")
	assert_eq(screen.percent_rows.size(), 1, "aucune ligne sur une fin non vue")
	assert_eq(server.log[server.log.size() - 1], "GET /api/clearance/endings")
	var asked: String = ""
	for line: String in server.log:
		if line == "GET /api/clearance/endings":
			asked = line
	assert_false(asked.is_empty())


# ---------------------------------------------------------------------------
# Jeu : silence pendant un shift, jouable sans compte
# ---------------------------------------------------------------------------

func _play_day(data: DataCatalog) -> DaySummary:
	if h != null:
		h.dispose()
	h = DayHarness.new()
	h.setup(self, SilentBooth.new(), GameState.current_day, 0, GameState.get_day_seed(), GameState.get_true_flags())
	var dc: DayController = h.controller
	dc.close_intro()
	var guard: int = 0
	while dc.phase != DayPhase.Kind.SUMMARY and guard < 64:
		guard += 1
		EventBus.next_case_requested.emit()
		dc.advance(dc.arrive_timeout_sec + 0.1)
		dc.advance(dc.present_timeout_sec + 0.1)
		h.stamp(dc.current_key.expected_verdict)
		dc.advance(dc.depart_timeout_sec + 0.1)
	assert_eq(h.summaries.size(), 1)
	return h.summaries[0]


func _evening(data: DataCatalog, summary: DaySummary) -> void:
	var lines: Array[ExpenseLine] = Campaign.prepare_evening(data)
	var report: EveningReport = Campaign.preview_evening(data, lines)
	Campaign.close_evening(data, summary, report, 1, SaveService.DEFAULT_DIR)


func test_no_request_during_a_shift() -> void:
	_saved_state = GameState.to_save_dict()
	await _sign_in("Nadia")
	var data: DataCatalog = Gen.data()
	Campaign.new_game(data, CAMPAIGN_SEED, 1)
	var counts: Dictionary = {"during": 0}
	server.probe = func(_req: OnlineRequest) -> void:
		var shift_running: bool = h != null and h.controller != null and h.controller.phase != DayPhase.Kind.SUMMARY
		if OnlineService.is_quiet() or (counts.has("start") and shift_running):
			counts["during"] = int(counts["during"]) + 1
	var on_start: Callable = func(_d: DayDef, _r: Array[RulebookEntry]) -> void:
		counts["start"] = server.sent
		counts["quiet"] = OnlineService.is_quiet()
		# Pendant le shift : tout ce qui pourrait partir attend.
		OnlineService.sync_now()
		OnlineService.submit_garde({"seed_code": "NUIT-2026-11-01", "score": 10, "passengers": 10, "duration_sec": 100, "errors": []}, false)
		EventBus.save_slots_changed.emit()
		EventBus.profile_changed.emit()
	EventBus.day_started.connect(on_start)
	var summary: DaySummary = await _play_day(data)
	EventBus.day_started.disconnect(on_start)
	# Fin du shift (`day_ended` : le silence est levé dans le même signal).
	counts["end"] = server.sent
	await wait_process_frames(2)
	assert_true(counts.has("start"))
	assert_true(counts["quiet"], "silence dès le début du shift")
	assert_false(OnlineService.is_quiet(), "silence levé à la fin du shift")
	assert_eq(counts["during"], 0, "aucune requête pendant le shift")
	assert_true(OnlineService.client.pending_outbox or server.scores.size() == 1, "score en file puis envoyé")
	assert_gt(server.sent, counts["start"], "ce qui attendait part après le shift")
	var before_evening: int = server.sent
	_evening(data, summary)
	await wait_process_frames(2)
	assert_gt(server.sent, before_evening, "sauvegarde du soir envoyée")
	var kinds: Array = []
	for row: Variant in server.saves.values()[0].values():
		kinds.append(str((row as Dictionary)["kind"]))
	assert_true(kinds.has("meta") and kinds.has("current") and kinds.has("snapshot"))


func test_full_game_playable_without_account() -> void:
	_saved_state = GameState.to_save_dict()
	var data: DataCatalog = Gen.data()
	Campaign.new_game(data, CAMPAIGN_SEED, 1)
	for day: int in [1, 2]:
		var summary: DaySummary = await _play_day(data)
		_evening(data, summary)
		await wait_process_frames(1)
	assert_eq(GameState.current_day, 3)
	assert_true(SaveService.has_save(1))
	assert_eq(server.sent, 0, "sans compte : aucune requête")
	assert_false(DirAccess.dir_exists_absolute(STORE), "aucun fichier du client en ligne")
	assert_eq(OnlineService.state(), OnlineClient.State.DISCONNECTED)
