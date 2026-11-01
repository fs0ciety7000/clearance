## Connexion **par code reçu par e-mail** (M16, D-231 ; UI_FLOW §8.10) —
## boîte modale (groupe `FocusGuard.MODAL_GROUP`, voile `DS.SCRIM`, carte
## `HoloPanel` comme `ConfirmDialog`), ouverte depuis Options › Compte.
## 1. **Adresse** : champ e-mail (contrôlé localement), « RECEVOIR UN CODE » ;
##    Steam Deck : « CLAVIER » (`steam://open/keyboard`) + rappel STEAM + X.
## 2. **Code** : `OtpCodeEntry` (6 chiffres, croix ↑ ↓ à la manette, collage),
##    « VALIDER », « RENVOYER LE CODE » (disponible 60 s après l'envoi,
##    ONLINE.md §2.1 : « RENVOYER DANS 42 s » d'ici là), « AUTRE ADRESSE ».
## Ligne d'état (icône + texte) : envoi en cours, code envoyé, erreurs
## traduites (`OnlineText.error_text`). Le réseau passe par
## `OnlineService.start_action` (la boîte n'attend rien elle-même : fermée
## pendant une requête, rien ne casse). Focus piégé dans la boîte ; Ⓑ /
## Échap : ANNULER. Émet `signed_in` (connexion réussie) puis se ferme.
class_name SignInDialog
extends Control

signal signed_in()
signal closed()

enum Step { EMAIL, CODE }

const CARD_WIDTH: float = 720.0
## Délai avant « RENVOYER LE CODE » (s, ONLINE.md §2.1 ; demandes limitées à 5 / 10 min).
const RESEND_DELAY_S: int = 60

var step: Step = Step.EMAIL
var busy: bool = false
var email_input: LineEdit = null
var code_entry: OtpCodeEntry = null
var send_button: Button = null
var verify_button: Button = null
var resend_button: Button = null
var change_button: Button = null
var cancel_button: Button = null
var keyboard_button: Button = null
var status_label: Label = null
var status_icon: UiIcon = null
var _title: Label = null
var _body: Label = null
var _email_box: VBoxContainer = null
var _code_box: VBoxContainer = null
var _done: bool = false
## Instant (ms, `Time.get_ticks_msec`) où « RENVOYER LE CODE » redevient possible.
var _resend_at_ms: int = 0
var _resend_shown_s: int = -1


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(FocusGuard.MODAL_GROUP)


func _ready() -> void:
	name = "SignInDialog"
	_build()
	OnlineService.action_finished.connect(_on_action_finished)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	show_step(Step.CODE if OnlineService.client.awaiting_code() else Step.EMAIL)


func _build() -> void:
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card: PanelContainer = ScreenBase.panel(&"HoloPanel")
	card.name = "Card"
	card.custom_minimum_size.x = CARD_WIDTH
	center.add_child(card)
	var box: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	card.add_child(box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.INFO, DS.ACCENT_CYAN, DS.ICON_M))
	head.add_child(ScreenBase.eyebrow(UiText.t("acct_signin_eyebrow", "COMPTE EN LIGNE · CONNEXION"), DS.ACCENT_CYAN))
	_title = ScreenBase.wrapped("", &"TitleLabel", DS.TEXT_PRIMARY)
	_title.name = "Title"
	box.add_child(_title)
	_body = ScreenBase.wrapped("", &"BodyLabel", DS.TEXT_PRIMARY)
	_body.name = "Body"
	box.add_child(_body)
	# Étape 1 : adresse.
	_email_box = ScreenBase.vbox(DS.SPACE_2)
	_email_box.name = "EmailStep"
	box.add_child(_email_box)
	_email_box.add_child(ScreenBase.eyebrow(UiText.t("acct_email_label", "ADRESSE E-MAIL")))
	var email_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	_email_box.add_child(email_row)
	email_input = LineEdit.new()
	email_input.name = "Email"
	email_input.placeholder_text = UiText.t("acct_email_placeholder", "agent@exemple.org")
	email_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
	email_input.custom_minimum_size = Vector2(420.0, DS.HIT_TARGET_MIN)
	email_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	email_input.max_length = 254
	email_input.focus_mode = Control.FOCUS_ALL
	email_input.text = str(OnlineService.client.store.account.get("email", ""))
	email_input.text_submitted.connect(func(_t: String) -> void: send_code())
	email_row.add_child(email_input)
	if Settings.is_steam_deck():
		keyboard_button = ScreenBase.button(UiText.t("acct_keyboard", "CLAVIER"), &"ButtonTool")
		keyboard_button.name = "Keyboard"
		keyboard_button.pressed.connect(open_keyboard)
		email_row.add_child(keyboard_button)
		_email_box.add_child(ScreenBase.wrapped(UiText.t("acct_keyboard_hint", "Steam Deck : STEAM + X ouvre aussi le clavier."), &"CaptionLabel"))
	# Étape 2 : code.
	_code_box = ScreenBase.vbox(DS.SPACE_2)
	_code_box.name = "CodeStep"
	box.add_child(_code_box)
	_code_box.add_child(ScreenBase.eyebrow(UiText.t("acct_code_label", "CODE À 6 CHIFFRES")))
	code_entry = OtpCodeEntry.make(OnlineService.client.otp_length())
	code_entry.name = "Code"
	code_entry.submitted.connect(func(_c: String) -> void: verify_code())
	_code_box.add_child(code_entry)
	var hint: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	hint.add_child(PromptGlyph.make(&"ui_up"))
	hint.add_child(PromptGlyph.make(&"ui_down"))
	hint.add_child(ScreenBase.label(UiText.t("acct_code_pad_hint", "changer le chiffre · ou taper / coller le code"), &"CaptionLabel"))
	_code_box.add_child(hint)
	# Ligne d'état.
	var status: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	status.name = "Status"
	box.add_child(status)
	status_icon = UiIcon.make(UiIcon.Kind.INFO, Palette.TEXT_SECONDARY, DS.ICON_S)
	status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.add_child(status_icon)
	status_label = ScreenBase.wrapped("", &"BodySmall", Palette.TEXT_SECONDARY)
	status_label.name = "StatusText"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_child(status_label)
	# Boutons.
	var buttons: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	box.add_child(buttons)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("dlg_cancel_hint", "annuler"), &"CaptionLabel"))
	buttons.add_child(keys)
	buttons.add_child(ScreenBase.spacer())
	cancel_button = ScreenBase.button(UiText.t("dlg_cancel", "ANNULER"), &"ButtonGhost")
	cancel_button.name = "Cancel"
	cancel_button.pressed.connect(cancel)
	buttons.add_child(cancel_button)
	change_button = ScreenBase.button(UiText.t("acct_change_email", "AUTRE ADRESSE"), &"ButtonGhost")
	change_button.name = "ChangeEmail"
	change_button.pressed.connect(func() -> void:
		OnlineService.client.cancel_code()
		show_step(Step.EMAIL))
	buttons.add_child(change_button)
	resend_button = ScreenBase.button(UiText.t("acct_resend", "RENVOYER LE CODE"), &"ButtonTool")
	resend_button.name = "Resend"
	resend_button.pressed.connect(func() -> void:
		if resend_wait_s() <= 0:
			_request(OnlineService.client.pending_email()))
	buttons.add_child(resend_button)
	send_button = ScreenBase.button(UiText.t("acct_send_code", "RECEVOIR UN CODE"), &"ButtonPrimary")
	send_button.name = "Send"
	send_button.pressed.connect(send_code)
	buttons.add_child(send_button)
	verify_button = ScreenBase.button(UiText.t("acct_verify", "VALIDER"), &"ButtonPrimary")
	verify_button.name = "Verify"
	verify_button.pressed.connect(verify_code)
	buttons.add_child(verify_button)


## Affiche une étape et pose le focus (adresse : champ ; code : saisie).
func show_step(value: Step) -> void:
	step = value
	var email_step: bool = step == Step.EMAIL
	_email_box.visible = email_step
	_code_box.visible = not email_step
	send_button.visible = email_step
	verify_button.visible = not email_step
	resend_button.visible = not email_step
	change_button.visible = not email_step
	if email_step:
		_title.text = UiText.t("acct_signin_title", "Recevoir un code par e-mail")
		_body.text = UiText.t("acct_signin_body",
				"Pas de mot de passe : un code à 6 chiffres, valable 10 minutes. Le compte est créé à la première connexion.")
		set_status("", UiIcon.Kind.INFO, Palette.TEXT_SECONDARY)
	else:
		code_entry.clear()
		_title.text = UiText.t("acct_code_title", "Saisir le code reçu")
		_body.text = UiText.tf("acct_code_body", [OnlineConfig.mask_email(OnlineService.client.pending_email())],
				"Envoyé à %s. Vérifiez aussi les indésirables.")
	_update_buttons()
	default_focus().grab_focus.call_deferred()


func default_focus() -> Control:
	return email_input if step == Step.EMAIL else code_entry


func set_status(text: String, kind: UiIcon.Kind, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override(&"font_color", color)
	status_icon.kind = kind
	status_icon.color = color
	status_label.get_parent().visible = not text.is_empty()


func _update_buttons() -> void:
	for b: Button in [send_button, verify_button, resend_button, change_button]:
		b.disabled = busy
		b.focus_mode = Control.FOCUS_NONE if busy else Control.FOCUS_ALL
	email_input.editable = not busy
	_update_resend()


## Secondes avant « RENVOYER LE CODE » (0 : possible).
func resend_wait_s() -> int:
	return maxi(0, ceili(float(_resend_at_ms - Time.get_ticks_msec()) / 1000.0))


## « RENVOYER DANS 42 s » (désactivé) puis « RENVOYER LE CODE ».
func _update_resend() -> void:
	if resend_button == null:
		return
	var wait: int = resend_wait_s()
	if wait == _resend_shown_s and resend_button.disabled == (busy or wait > 0):
		return
	_resend_shown_s = wait
	resend_button.text = UiText.tf("acct_resend_wait", [wait], "RENVOYER DANS %d s") if wait > 0 \
			else UiText.t("acct_resend", "RENVOYER LE CODE")
	resend_button.disabled = busy or wait > 0
	resend_button.focus_mode = Control.FOCUS_NONE if resend_button.disabled else Control.FOCUS_ALL


func _process(_delta: float) -> void:
	if step == Step.CODE and resend_button != null and resend_wait_s() != _resend_shown_s:
		_update_resend()


## Étape 1 : adresse contrôlée localement, puis demande du code.
func send_code() -> void:
	if busy or step != Step.EMAIL:
		return
	var email: String = email_input.text.strip_edges()
	if not OnlineConfig.is_valid_email(email):
		set_status(OnlineText.error_text(OnlineClient.ERR_EMAIL), UiIcon.Kind.DENIED, Palette.STATE_RED)
		email_input.grab_focus()
		return
	_request(email)


func _request(email: String) -> void:
	_set_busy(true, UiText.t("acct_sending", "Envoi du code…"))
	OnlineService.start_action(OnlineService.ACTION_REQUEST_CODE, email)


## Étape 2 : code complet, échange contre le jeton.
func verify_code() -> void:
	if busy or step != Step.CODE:
		return
	if not code_entry.is_complete():
		set_status(UiText.tf("acct_code_incomplete", [code_entry.length], "Le code a %d chiffres."), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
		code_entry.grab_focus()
		return
	_set_busy(true, UiText.t("acct_verifying", "Vérification…"))
	OnlineService.start_action(OnlineService.ACTION_SUBMIT_CODE, code_entry.code())


func _set_busy(value: bool, text: String = "") -> void:
	busy = value
	if value:
		set_status(text, UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
	_update_buttons()


func _on_action_finished(action: StringName, result: Dictionary) -> void:
	if _done or not is_inside_tree():
		return
	if action != OnlineService.ACTION_REQUEST_CODE and action != OnlineService.ACTION_SUBMIT_CODE:
		return
	busy = false
	_update_buttons()
	var ok: bool = result.get("ok", false)
	var error: String = str(result.get("error", ""))
	if action == OnlineService.ACTION_REQUEST_CODE:
		if ok:
			_resend_at_ms = Time.get_ticks_msec() + RESEND_DELAY_S * 1000
			show_step(Step.CODE)
			set_status(UiText.t("acct_code_sent", "Code envoyé. Il reste valable 10 minutes."), UiIcon.Kind.APPROVED, Palette.STATE_GREEN)
		else:
			set_status(OnlineText.error_text(error), UiIcon.Kind.DENIED, Palette.STATE_RED)
			default_focus().grab_focus.call_deferred()
		return
	if ok:
		_done = true
		remove_from_group(FocusGuard.MODAL_GROUP)
		signed_in.emit()
		closed.emit()
		queue_free()
		return
	if error == OnlineClient.ERR_OTP_LOCKED:
		show_step(Step.EMAIL)
	set_status(OnlineText.error_text(error), UiIcon.Kind.DENIED, Palette.STATE_RED)
	if step == Step.CODE:
		code_entry.clear()
		code_entry.grab_focus.call_deferred()


## Steam Deck : clavier de Steam (mode jeu), puis focus sur le champ.
func open_keyboard() -> void:
	email_input.grab_focus()
	OS.shell_open("steam://open/keyboard")


func cancel() -> void:
	if _done:
		return
	_done = true
	remove_from_group(FocusGuard.MODAL_GROUP)
	closed.emit()
	queue_free()


func is_done() -> bool:
	return _done


## Focus piégé : un focus parti derrière le voile revient dans la boîte.
func _on_focus_changed(control: Control) -> void:
	if _done or control == null or not is_inside_tree():
		return
	if not is_ancestor_of(control):
		default_focus().grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		# Échap dans le champ d'adresse ne fait qu'annuler la boîte (pas la saisie).
		cancel()
		get_viewport().set_input_as_handled()
