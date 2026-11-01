## Options › **COMPTE EN LIGNE** (M16, D-231 → D-234 ; UI_FLOW §8.10) —
## section du panneau d'options (titre et pause), recomposée à chaque
## changement d'état (`OnlineService.account_changed`, `state_changed`,
## `sync_finished`).
## - **Sans compte** : à quoi sert le compte (facultatif ; sans compte, rien
##   ne quitte l'appareil), « SE CONNECTER PAR E-MAIL… » → `SignInDialog` ;
##   session expirée : message.
## - **Connecté·e** : nom affiché et adresse masquée, puce d'état (icône +
##   texte), **pseudo** (champ + ENREGISTRER), **synchronisation
##   automatique** (bascule), **SYNCHRONISER MAINTENANT** + date de la
##   dernière, **SE DÉCONNECTER** (données locales gardées), **SUPPRIMER LE
##   COMPTE ET LES DONNÉES…** (bouton d'outil ; rouge seulement dans les deux confirmations, focus ANNULER).
## - **En jeu** (menu pause, `in_game`) : état seul — rien ne part pendant un
##   shift ; les réglages du compte sont à l'écran titre.
## - Démo : même section, données de la démo synchronisées à part (famille
##   `demo`, D-215).
## Le réseau passe par `OnlineService.start_action` (résultat :
## `action_finished`) ; aucune attente dans l'interface.
class_name AccountSection
extends VBoxContainer

## Largeurs minimales (px @1080p) : champ du pseudo, bascule OUI/NON.
const PSEUDO_FIELD_WIDTH: float = 320.0
const TOGGLE_WIDTH: float = 160.0

## Menu pause (partie en cours) : état seul.
var in_game: bool = false
var sign_in_button: Button = null
var pseudo_input: LineEdit = null
var pseudo_button: Button = null
var auto_sync_button: Button = null
var sync_button: Button = null
var sign_out_button: Button = null
var delete_button: Button = null
var status_label: Label = null
var dialog: Control = null
var _content: VBoxContainer = null
var _message: String = ""
var _message_kind: UiIcon.Kind = UiIcon.Kind.INFO
var _message_color: Color = Palette.TEXT_SECONDARY


func _ready() -> void:
	name = "AccountSection"
	add_theme_constant_override("separation", DS.SPACE_3)
	add_child(ScreenBase.section(UiText.t("acct_section", "COMPTE EN LIGNE"), UiIcon.Kind.INFO, DS.ACCENT_CYAN))
	_content = ScreenBase.vbox(DS.SPACE_3)
	_content.name = "Content"
	add_child(_content)
	OnlineService.account_changed.connect(rebuild)
	OnlineService.state_changed.connect(func(_s: OnlineClient.State) -> void: rebuild())
	OnlineService.sync_finished.connect(_on_sync_finished)
	OnlineService.action_finished.connect(_on_action_finished)
	rebuild()


## Recompose la section ; le focus reste sur le même bouton s'il existe encore.
func rebuild() -> void:
	if _content == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var focused_name: String = str(focused.name) if focused != null and is_ancestor_of(focused) else ""
	for child: Node in _content.get_children():
		var item: CanvasItem = child as CanvasItem
		if item != null:
			item.visible = false
		child.queue_free()
	sign_in_button = null
	pseudo_input = null
	pseudo_button = null
	auto_sync_button = null
	sync_button = null
	sign_out_button = null
	delete_button = null
	if not OnlineService.has_account():
		_build_signed_out()
	elif in_game:
		_build_in_game()
	else:
		_build_signed_in()
	_add_message_line()
	if not focused_name.is_empty():
		var again: Control = _content.find_child(focused_name, true, false) as Control
		if again != null and again.focus_mode != Control.FOCUS_NONE and not again.is_queued_for_deletion():
			again.grab_focus.call_deferred()


func _build_signed_out() -> void:
	_content.add_child(ScreenBase.wrapped(UiText.t("acct_intro",
			"Facultatif. Sauvegardes dans le cloud (PC, Steam Deck, navigateur), classement de la Garde de nuit, statistiques des fins. Sans compte, rien ne quitte cet appareil."),
			&"CaptionLabel"))
	if DemoMode.is_demo():
		_content.add_child(ScreenBase.wrapped(UiText.t("acct_demo_note", "Démo : ses sauvegardes sont synchronisées à part de celles du jeu complet."),
				&"CaptionLabel"))
	if in_game:
		_content.add_child(ScreenBase.wrapped(UiText.t("acct_from_title", "Connexion depuis l'écran titre."), &"BodySmall"))
		return
	sign_in_button = ScreenBase.button(UiText.t("acct_sign_in", "SE CONNECTER PAR E-MAIL…"), &"ButtonTool")
	sign_in_button.name = "SignIn"
	sign_in_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sign_in_button.pressed.connect(open_sign_in)
	_content.add_child(sign_in_button)
	if OnlineService.last_error() == OnlineClient.ERR_SESSION and _message.is_empty():
		_message = OnlineText.error_text(OnlineClient.ERR_SESSION)
		_message_kind = UiIcon.Kind.WARNING
		_message_color = Palette.STATE_AMBER


func _identity_row() -> HBoxContainer:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	row.name = "Identity"
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	var who: Label = ScreenBase.label(UiText.tf("acct_signed_in_as", [OnlineService.display_name()], "Connecté·e : %s"), &"BodyLabel")
	who.name = "Who"
	texts.add_child(who)
	var email: String = OnlineService.masked_email()
	if not email.is_empty():
		texts.add_child(ScreenBase.label(email, &"DataSmall", Palette.TEXT_SECONDARY))
	row.add_child(state_chip())
	return row


## Puce d'état (icône + texte).
static func state_chip() -> PanelContainer:
	var info: Dictionary = OnlineStatusBadge.describe(OnlineService.state(), OnlineService.last_error(), OnlineService.is_syncing(),
			false, OnlineService.has_account(), OnlineService.display_name())
	var text: String = info["text"]
	if OnlineService.state() == OnlineClient.State.CONNECTED and not OnlineService.is_syncing():
		text = UiText.t("acct_state_online", "EN LIGNE")
	var chip: PanelContainer = ScreenBase.chip(text, info["icon"], info["color"])
	chip.name = "StateChip"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return chip


func _build_in_game() -> void:
	_content.add_child(_identity_row())
	_content.add_child(ScreenBase.wrapped(UiText.t("acct_in_game",
			"Rien n'est envoyé pendant un shift : la sauvegarde du soir part ensuite. Réglages du compte depuis l'écran titre."), &"CaptionLabel"))


func _build_signed_in() -> void:
	_content.add_child(_identity_row())
	if DemoMode.is_demo():
		_content.add_child(ScreenBase.wrapped(UiText.t("acct_demo_note", "Démo : ses sauvegardes sont synchronisées à part de celles du jeu complet."),
				&"CaptionLabel"))
	# Pseudo.
	var pseudo_box: VBoxContainer = ScreenBase.vbox(DS.SPACE_1)
	_content.add_child(pseudo_box)
	pseudo_box.add_child(ScreenBase.label(UiText.t("acct_pseudo", "Pseudo public"), &"BodyLabel"))
	pseudo_box.add_child(ScreenBase.wrapped(UiText.t("acct_pseudo_hint",
			"Affiché au classement de la Garde. 20 caractères au plus ; vide : « Agent·e #tag »."), &"CaptionLabel"))
	var pseudo_row: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	pseudo_box.add_child(pseudo_row)
	pseudo_input = LineEdit.new()
	pseudo_input.name = "Pseudo"
	pseudo_input.max_length = OnlineConfig.PSEUDO_MAX_CHARS
	pseudo_input.text = str(OnlineService.client.store.account.get("pseudo", ""))
	pseudo_input.placeholder_text = OnlineClient.display_name_of("", str(OnlineService.client.store.account.get("tag", "")))
	pseudo_input.custom_minimum_size = Vector2(PSEUDO_FIELD_WIDTH, DS.HIT_TARGET_MIN)
	pseudo_input.focus_mode = Control.FOCUS_ALL
	pseudo_input.text_submitted.connect(func(_t: String) -> void: save_pseudo())
	pseudo_row.add_child(pseudo_input)
	pseudo_button = ScreenBase.button(UiText.t("acct_pseudo_save", "ENREGISTRER"), &"ButtonTool")
	pseudo_button.name = "SavePseudo"
	pseudo_button.pressed.connect(save_pseudo)
	pseudo_row.add_child(pseudo_button)
	# Synchronisation automatique.
	var auto_row: HBoxContainer = _row(UiText.t("acct_auto_sync", "Synchronisation automatique"),
			UiText.t("acct_auto_sync_hint", "Tirage à l'écran titre, envoi après chaque soirée et à la fin d'une partie."))
	auto_sync_button = Button.new()
	auto_sync_button.name = "AutoSync"
	auto_sync_button.theme_type_variation = &"ToggleTab"
	auto_sync_button.toggle_mode = true
	auto_sync_button.focus_mode = Control.FOCUS_ALL
	auto_sync_button.custom_minimum_size = Vector2(TOGGLE_WIDTH, DS.HIT_TARGET_MIN)
	auto_sync_button.button_pressed = OnlineService.auto_sync()
	auto_sync_button.text = OptionsPanel._toggle_text(auto_sync_button.button_pressed)
	auto_sync_button.toggled.connect(func(on: bool) -> void:
		auto_sync_button.text = OptionsPanel._toggle_text(on)
		OnlineService.set_auto_sync(on))
	auto_row.add_child(auto_sync_button)
	# Synchroniser maintenant.
	var sync_row: HBoxContainer = _row(UiText.t("acct_sync_title", "Sauvegardes dans le cloud"),
			OnlineText.last_sync_text(OnlineService.last_sync_unix_ms()))
	sync_button = ScreenBase.button(UiText.t("acct_sync_now", "SYNCHRONISER MAINTENANT"), &"ButtonTool")
	sync_button.name = "SyncNow"
	sync_button.disabled = OnlineService.is_syncing()
	sync_button.pressed.connect(sync_now)
	sync_row.add_child(sync_button)
	# Déconnexion, suppression.
	var leave_row: HBoxContainer = _row(UiText.t("acct_leave", "Cet appareil"),
			UiText.t("acct_sign_out_hint", "Se déconnecter garde toutes les données sur cet appareil."))
	sign_out_button = ScreenBase.button(UiText.t("acct_sign_out", "SE DÉCONNECTER"), &"ButtonGhost")
	sign_out_button.name = "SignOut"
	sign_out_button.pressed.connect(sign_out)
	leave_row.add_child(sign_out_button)
	var delete_row: HBoxContainer = _row(UiText.t("acct_delete_title", "Supprimer le compte"),
			UiText.t("acct_delete_hint", "Efface du serveur le compte, les sauvegardes en ligne, les scores et les fins. Les données de cet appareil restent."))
	delete_button = ScreenBase.button(UiText.t("acct_delete", "SUPPRIMER LE COMPTE ET LES DONNÉES…"), &"ButtonTool")
	delete_button.name = "DeleteAccount"
	delete_button.pressed.connect(confirm_delete)
	delete_row.add_child(delete_button)


func _row(caption: String, hint: String) -> HBoxContainer:
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_4)
	row.custom_minimum_size.y = DS.HIT_TARGET_MIN
	var texts: VBoxContainer = ScreenBase.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(texts)
	texts.add_child(ScreenBase.label(caption, &"BodyLabel"))
	if not hint.is_empty():
		texts.add_child(ScreenBase.wrapped(hint, &"CaptionLabel"))
	_content.add_child(row)
	return row


func _add_message_line() -> void:
	if _message.is_empty():
		return
	var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	row.name = "Message"
	var icon: UiIcon = UiIcon.make(_message_kind, _message_color, DS.ICON_S)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	status_label = ScreenBase.wrapped(_message, &"BodySmall", _message_color)
	status_label.name = "MessageText"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(status_label)
	_content.add_child(row)


## Message (icône + texte) sous la section, gardé jusqu'au prochain.
func set_message(text: String, kind: UiIcon.Kind = UiIcon.Kind.INFO, color: Color = Palette.TEXT_SECONDARY) -> void:
	_message = text
	_message_kind = kind
	_message_color = color
	rebuild()


func message() -> String:
	return _message


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Boîte de connexion par code (par-dessus l'écran qui porte les Options).
func open_sign_in() -> SignInDialog:
	var sign_in: SignInDialog = SignInDialog.new()
	_attach_dialog(sign_in)
	sign_in.signed_in.connect(func() -> void:
		set_message(UiText.t("acct_signed_in_ok", "Connecté·e. Synchronisation en cours."), UiIcon.Kind.APPROVED, Palette.STATE_GREEN))
	sign_in.closed.connect(func() -> void:
		dialog = null
		var target: Control = sync_button if sync_button != null else sign_in_button
		if target != null and is_instance_valid(target):
			target.grab_focus.call_deferred())
	return sign_in


func _attach_dialog(node: Control) -> void:
	dialog = node
	# Hôte : le plus haut `Control` qui porte cette section (titre, écran).
	var host: Control = self
	while host.get_parent() is Control:
		host = host.get_parent() as Control
	var themed: Control = _themed_ancestor()
	if themed != null:
		node.theme = themed.theme
	host.add_child(node)


func _themed_ancestor() -> Control:
	var node: Node = self
	while node != null:
		var c: Control = node as Control
		if c != null and c.theme != null:
			return c
		node = node.get_parent()
	return null


func save_pseudo() -> void:
	if pseudo_input == null:
		return
	var text: String = pseudo_input.text
	if not OnlineConfig.is_valid_pseudo(text):
		set_message(OnlineText.error_text(OnlineClient.ERR_PSEUDO), UiIcon.Kind.DENIED, Palette.STATE_RED)
		return
	set_message(UiText.t("acct_pseudo_saving", "Enregistrement du pseudo…"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
	OnlineService.start_action(OnlineService.ACTION_SET_PSEUDO, text)


func sync_now() -> void:
	if OnlineService.is_syncing():
		return
	set_message(UiText.t("online_state_syncing", "SYNCHRONISATION…"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
	OnlineService.start_action(OnlineService.ACTION_SYNC_NOW)


func sign_out() -> void:
	OnlineService.sign_out()
	set_message(UiText.t("acct_signed_out", "Déconnecté·e. Les données restent sur cet appareil."), UiIcon.Kind.INFO, Palette.TEXT_SECONDARY)
	if sign_in_button != null:
		sign_in_button.grab_focus.call_deferred()


## Suppression du compte : deux confirmations (focus ANNULER), puis l'action.
func confirm_delete() -> ConfirmDialog:
	var first: ConfirmDialog = ConfirmDialog.make(UiText.t("acct_delete_eyebrow", "COMPTE EN LIGNE · SUPPRESSION"),
			UiText.t("acct_delete_q1", "Supprimer le compte et toutes ses données en ligne ?"),
			UiText.t("acct_delete_b1", "Sauvegardes dans le cloud, scores de Garde et fins enregistrées seront effacés du serveur. Les parties de cet appareil restent."),
			UiText.t("acct_delete_continue", "CONTINUER…"))
	first.name = "DeleteDialog1"
	first.confirmed.connect(func() -> void:
		var second: ConfirmDialog = ConfirmDialog.make(UiText.t("acct_delete_eyebrow", "COMPTE EN LIGNE · SUPPRESSION"),
				UiText.t("acct_delete_q2", "Suppression définitive ?"),
				UiText.t("acct_delete_b2", "Impossible à annuler. Un nouveau compte repartira de zéro."),
				UiText.t("acct_delete_final", "SUPPRIMER DÉFINITIVEMENT"))
		second.name = "DeleteDialog2"
		second.confirmed.connect(func() -> void:
			dialog = null
			set_message(UiText.t("acct_deleting", "Suppression en cours…"), UiIcon.Kind.DIAMOND, DS.ACCENT_CYAN)
			OnlineService.start_action(OnlineService.ACTION_DELETE_ACCOUNT))
		second.cancelled.connect(_after_dialog)
		_attach_dialog(second))
	first.cancelled.connect(_after_dialog)
	_attach_dialog(first)
	return first


func _after_dialog() -> void:
	dialog = null
	if delete_button != null and is_instance_valid(delete_button):
		delete_button.grab_focus.call_deferred()


func _on_sync_finished(report: Dictionary) -> void:
	if not is_inside_tree():
		return
	var conflicts: Array = report.get("conflicts", []) if report.get("conflicts") is Array else []
	var errors: Array = report.get("errors", []) if report.get("errors") is Array else []
	if not conflicts.is_empty():
		set_message(UiText.t("acct_sync_conflict", "Deux versions d'une partie : choisissez laquelle garder dans Charger."),
				UiIcon.Kind.WARNING, Palette.STATE_AMBER)
	elif not errors.is_empty():
		set_message(OnlineText.error_text(str(errors[0])), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
	elif report.get("ok", false):
		set_message(UiText.t("acct_sync_ok", "Sauvegardes synchronisées."), UiIcon.Kind.APPROVED, Palette.STATE_GREEN)
	else:
		rebuild()


func _on_action_finished(action: StringName, result: Dictionary) -> void:
	if not is_inside_tree():
		return
	var ok: bool = result.get("ok", false)
	var error: String = str(result.get("error", ""))
	match action:
		OnlineService.ACTION_SET_PSEUDO:
			if ok:
				set_message(UiText.t("acct_pseudo_saved", "Pseudo enregistré."), UiIcon.Kind.APPROVED, Palette.STATE_GREEN)
			else:
				set_message(OnlineText.error_text(error), UiIcon.Kind.DENIED, Palette.STATE_RED)
		OnlineService.ACTION_DELETE_ACCOUNT:
			if ok:
				set_message(UiText.t("acct_deleted", "Compte et données en ligne supprimés. Les données de cet appareil restent."),
						UiIcon.Kind.APPROVED, Palette.STATE_GREEN)
				if sign_in_button != null:
					sign_in_button.grab_focus.call_deferred()
			else:
				set_message(OnlineText.error_text(error), UiIcon.Kind.DENIED, Palette.STATE_RED)
		OnlineService.ACTION_SYNC_NOW:
			if not ok and not error.is_empty() and error != "busy":
				set_message(OnlineText.error_text(error), UiIcon.Kind.WARNING, Palette.STATE_AMBER)
