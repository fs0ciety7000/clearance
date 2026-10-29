## Boîte de confirmation modale (M11 lot C, UI_FLOW §9.4 règle 3) : voile
## `DS.SCRIM`, carte centrée (icône + sur-titre + titre + texte), deux
## boutons. Le focus part sur **ANNULER** et tourne entre les deux boutons,
## jamais vers ce qui est derrière le voile ; Échap / Ⓑ (`cancel`,
## `ui_cancel`) annule. Fonctionne pendant la pause (menu pause).
## Utilisée par « Nouvelle partie » (écrasement), « Charger » (reprise d'un
## jour passé), Pause > Options (passage Récit → Dur) et « Terminer la garde »
## (barre du guichet, QA-057). Membre de `FocusGuard.MODAL_GROUP` : le
## `FocusGuard` et les commandes du guichet se taisent tant qu'elle est ouverte.
class_name ConfirmDialog
extends Control

signal confirmed()
signal cancelled()

const CARD_WIDTH: float = 680.0

var cancel_button: Button = null
var accept_button: Button = null
var _done: bool = false


## `danger` : bouton de confirmation rouge (`ButtonDanger`, action
## irréversible) ; sinon `ButtonPrimary`.
static func make(eyebrow_text: String, title: String, body: String, accept_text: String, cancel_text: String = "",
		danger: bool = true) -> ConfirmDialog:
	var dialog: ConfirmDialog = ConfirmDialog.new()
	dialog._build(eyebrow_text, title, body, accept_text,
			cancel_text if not cancel_text.is_empty() else UiText.t("dlg_cancel", "ANNULER"), danger)
	return dialog


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(FocusGuard.MODAL_GROUP)


func _ready() -> void:
	if cancel_button != null:
		cancel_button.grab_focus.call_deferred()


func _build(eyebrow_text: String, title: String, body: String, accept_text: String, cancel_text: String, danger: bool) -> void:
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
	var accent: Color = Palette.STATE_AMBER if danger else Palette.TEXT_SECONDARY
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
	box.add_child(head)
	head.add_child(UiIcon.make(UiIcon.Kind.WARNING if danger else UiIcon.Kind.INFO, accent, DS.ICON_M))
	head.add_child(ScreenBase.eyebrow(eyebrow_text, accent))
	var title_label: Label = ScreenBase.wrapped(title, &"TitleLabel", DS.TEXT_PRIMARY)
	title_label.name = "Title"
	box.add_child(title_label)
	if not body.is_empty():
		var body_label: Label = ScreenBase.wrapped(body, &"BodyLabel", DS.TEXT_PRIMARY)
		body_label.name = "Body"
		box.add_child(body_label)
	var buttons: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	box.add_child(buttons)
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(ScreenBase.label(UiText.t("dlg_cancel_hint", "annuler"), &"CaptionLabel"))
	buttons.add_child(keys)
	buttons.add_child(ScreenBase.spacer())
	cancel_button = ScreenBase.button(cancel_text, &"ButtonGhost")
	cancel_button.name = "Cancel"
	cancel_button.pressed.connect(cancel)
	buttons.add_child(cancel_button)
	accept_button = ScreenBase.button(accept_text, &"ButtonDanger" if danger else &"ButtonPrimary")
	accept_button.name = "Accept"
	accept_button.pressed.connect(accept)
	buttons.add_child(accept_button)
	EveningScreen._trap_focus(cancel_button, accept_button)
	EveningScreen._trap_focus(accept_button, cancel_button)


func accept() -> void:
	if _done:
		return
	_done = true
	remove_from_group(FocusGuard.MODAL_GROUP)
	confirmed.emit()
	queue_free()


func cancel() -> void:
	if _done:
		return
	_done = true
	remove_from_group(FocusGuard.MODAL_GROUP)
	cancelled.emit()
	queue_free()


func is_done() -> bool:
	return _done


## Échap / Ⓑ : annule ; l'événement ne va pas plus loin (menu pause, écran).
func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"ui_cancel", false, true):
		cancel()
		get_viewport().set_input_as_handled()
