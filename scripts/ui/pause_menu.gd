## Menu pause (UI_FLOW §3.5, §8 ; non diégétique, DS §1.5).
##
## S'ouvre par Échap **quand l'interface n'a rien à annuler** (`ComparisonUI`
## laisse alors passer l'événement, D-040 / UI_FLOW §3.5), F10 ou Menu/Start
## de la manette : arbre en pause (l'horloge du shift et le booth sont gelés),
## plan de travail flouté. Entrées : REPRENDRE · OPTIONS (`OptionsPanel`) ·
## QUITTER VERS LE TITRE (second appui de confirmation : la progression du jour
## en cours est perdue, la sauvegarde du matin reste). Échap / Ⓑ : retour /
## reprendre.
## M11 lot C : Options > Partie « PASSER EN MODE DUR » (partie en Récit) →
## `ConfirmDialog` (focus ANNULER, irréversible) → `GameState.set_difficulty`.
## M12 (lot C) : en Garde de nuit (`garde_mode`), « TERMINER LA GARDE » en deux
## temps (le score est enregistré) → `end_garde_requested` ; quitter vers le
## titre perd la garde (rien n'est enregistré).
## M13 (lot C, I38) : améliorations du guichet possédées rappelées (nom +
## effet), en campagne seulement (`refresh_upgrades`).
class_name PauseMenu
extends Control

signal quit_to_title_requested()
## M12 : « Terminer la garde » confirmé (second appui).
signal end_garde_requested()

const BLUR_SHADER: Shader = preload("res://assets/shaders/ui_backdrop_blur.gdshader")
const PANEL_WIDTH: float = 560.0
const OPTIONS_WIDTH: float = 880.0

var is_open: bool = false
## Désactivé pendant les écrans qui ne doivent pas être mis en pause.
var enabled: bool = true
var resume_button: Button = null
var options: OptionsPanel = null
## Confirmation « Passer en mode Dur » ouverte (null sinon).
var hard_dialog: ConfirmDialog = null
## M12 : session Garde de nuit (bouton « TERMINER LA GARDE »).
var garde_mode: bool = false:
	set(value):
		garde_mode = value
		if end_garde_button != null:
			end_garde_button.visible = value
var end_garde_button: Button = null
var _end_garde_armed: bool = false

var _menu_box: VBoxContainer = null
var _panel: PanelContainer = null
var _quit_button: Button = null
var _quit_armed: bool = false
## M13 : améliorations possédées (masqué s'il n'y en a pas).
var upgrades_box: VBoxContainer = null
var _applied_min_px: int = -1


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	_apply_theme()
	EventBus.settings_changed.connect(func(key: StringName, _v: Variant) -> void:
		if key == Settings.KEY_TEXT_SCALE or key == Settings.KEY_COLOR_VISION:
			_apply_theme())
	InputPrompts.ensure(get_tree())
	var blur: ColorRect = ColorRect.new()
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = BLUR_SHADER
	blur.material = mat
	add_child(blur)
	var scrim: ColorRect = ColorRect.new()
	scrim.color = DS.SCRIM
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"SystemPanel"
	_panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(_panel)
	var stack: VBoxContainer = ScreenBase.vbox(DS.SPACE_4)
	_panel.add_child(stack)
	_menu_box = ScreenBase.vbox(DS.SPACE_3)
	stack.add_child(_menu_box)
	var head: HBoxContainer = ScreenBase.hbox(DS.SPACE_3)
	_menu_box.add_child(head)
	head.add_child(ScreenBase.label(UiText.t("pause_title", "PAUSE"), &"DisplayLabel"))
	head.add_child(ScreenBase.spacer())
	# Glyphes qui suivent le périphérique (Échap / F10 au clavier, B / Menu à la manette).
	var keys: HBoxContainer = ScreenBase.hbox(DS.SPACE_1)
	keys.name = "PauseKeys"
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	keys.add_child(PromptGlyph.make(&"cancel"))
	keys.add_child(PromptGlyph.make(&"pause"))
	head.add_child(keys)
	_menu_box.add_child(ScreenBase.wrapped(UiText.t("pause_hint", "Le shift est suspendu : l'horloge et la file sont arrêtées."), &"BodySmall"))
	upgrades_box = ScreenBase.vbox(DS.SPACE_1)
	upgrades_box.name = "Upgrades"
	upgrades_box.visible = false
	_menu_box.add_child(upgrades_box)
	_menu_box.add_child(ScreenBase.rule_line())
	resume_button = ScreenBase.button(UiText.t("pause_resume", "REPRENDRE"), &"ButtonPrimary")
	resume_button.pressed.connect(close)
	_menu_box.add_child(resume_button)
	var options_button: Button = ScreenBase.button(UiText.t("pause_options", "OPTIONS"))
	options_button.pressed.connect(show_options)
	_menu_box.add_child(options_button)
	end_garde_button = ScreenBase.button(UiText.t("garde_end_button", "TERMINER LA GARDE"))
	end_garde_button.name = "EndGarde"
	end_garde_button.visible = garde_mode
	end_garde_button.pressed.connect(_on_end_garde_pressed)
	end_garde_button.focus_exited.connect(_disarm_end_garde)
	_menu_box.add_child(end_garde_button)
	_quit_button = ScreenBase.button(UiText.t("pause_quit", "QUITTER VERS LE TITRE"))
	_quit_button.pressed.connect(_on_quit_pressed)
	_menu_box.add_child(_quit_button)
	options = OptionsPanel.new()
	options.in_game = true
	options.visible = false
	options.back_requested.connect(show_menu)
	options.hard_mode_requested.connect(request_hard_mode)
	stack.add_child(options)
	# Manette : une direction sans focus le rend à « REPRENDRE » (ou au premier
	# réglage), le stick droit fait défiler les options (M11).
	FocusGuard.attach(self, func() -> Control: return options.first_control() if options.visible else resume_button)


func _apply_theme() -> void:
	var min_px: int = ThemeBuilder.min_px_for(get_viewport().get_final_transform().get_scale().x) if is_inside_tree() else 0
	_applied_min_px = min_px
	theme = ThemeBuilder.build(Settings.text_scale, min_px)


func open() -> void:
	if is_open or not enabled:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	refresh_upgrades()
	show_menu()


func close() -> void:
	if not is_open:
		return
	if hard_dialog != null:
		hard_dialog.cancel()
	is_open = false
	visible = false
	Settings.save_settings()
	get_tree().paused = false


func show_options() -> void:
	_menu_box.visible = false
	options.refresh_game_section()
	options.visible = true
	_panel.custom_minimum_size.x = OPTIONS_WIDTH
	options.focus_first.call_deferred()


func show_menu() -> void:
	options.visible = false
	_menu_box.visible = true
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_quit_armed = false
	_quit_button.text = UiText.t("pause_quit_garde", "QUITTER VERS LE TITRE (GARDE PERDUE)") if garde_mode \
			else UiText.t("pause_quit", "QUITTER VERS LE TITRE")
	_quit_button.theme_type_variation = &"ButtonTool"
	_disarm_end_garde()
	resume_button.grab_focus.call_deferred()


## M13 : liste des améliorations possédées (campagne ; jamais en Garde).
func refresh_upgrades() -> void:
	if upgrades_box == null:
		return
	for child: Node in upgrades_box.get_children():
		upgrades_box.remove_child(child)
		child.queue_free()
	var owned: Array[StringName] = [] as Array[StringName]
	if not garde_mode and GameState.session_mode == GameState.SESSION_CAMPAIGN:
		owned = GameState.owned_upgrades(ComparisonUI.UPGRADE_IDS)
	upgrades_box.visible = not owned.is_empty()
	if owned.is_empty():
		return
	upgrades_box.add_child(ScreenBase.eyebrow(UiText.t("pause_upgrades", "GUICHET 04 · AMÉLIORATIONS"), DS.ACCENT_YELLOW))
	for upgrade_id: StringName in owned:
		var row: HBoxContainer = ScreenBase.hbox(DS.SPACE_2)
		row.name = "Upgrade_%s" % upgrade_id
		row.add_child(UiIcon.make(UiIcon.Kind.TOOL, Palette.TEXT_SECONDARY, DS.ICON_S))
		var text: Label = ScreenBase.wrapped("%s — %s" % [UiText.t("upg_%s_name" % upgrade_id, String(upgrade_id)),
				UiText.t("upg_%s_desc" % upgrade_id, "")], &"BodySmall")
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		upgrades_box.add_child(row)


## Récit → Dur (D-102) : confirmation, puis `GameState.set_difficulty(&"hard")`.
func request_hard_mode() -> void:
	if hard_dialog != null or not GameState.is_story_mode():
		return
	hard_dialog = ConfirmDialog.make(UiText.t("hard_eyebrow", "MODE DE JEU"),
			UiText.t("hard_title", "Passer en mode Dur ?"),
			UiText.t("hard_body", "Le chrono et les amendes s'appliquent dès maintenant, jusqu'à la fin de cette partie. Impossible de revenir en mode Récit."),
			UiText.t("hard_accept", "PASSER EN DUR"))
	hard_dialog.name = "HardModeDialog"
	hard_dialog.confirmed.connect(func() -> void:
		hard_dialog = null
		GameState.set_difficulty(GameState.DIFFICULTY_HARD)
		options.refresh_game_section()
		options.focus_first.call_deferred())
	hard_dialog.cancelled.connect(func() -> void:
		hard_dialog = null
		if options.hard_mode_button != null and options.hard_mode_button.is_visible_in_tree():
			options.hard_mode_button.grab_focus.call_deferred())
	add_child(hard_dialog)


## M12 : premier appui — « CONFIRMER : LE SCORE SERA ENREGISTRÉ » ; second :
## la garde se termine (`end_garde_requested`), pause fermée.
func _on_end_garde_pressed() -> void:
	if not _end_garde_armed:
		_end_garde_armed = true
		end_garde_button.text = UiText.t("garde_end_confirm", "CONFIRMER : LE SCORE SERA ENREGISTRÉ")
		end_garde_button.theme_type_variation = &"ButtonPrimary"
		return
	_disarm_end_garde()
	close()
	end_garde_requested.emit()


func _disarm_end_garde() -> void:
	_end_garde_armed = false
	if end_garde_button != null:
		end_garde_button.text = UiText.t("garde_end_button", "TERMINER LA GARDE")
		end_garde_button.theme_type_variation = &"ButtonTool"


## Premier appui : demande confirmation ; second : retour au titre.
func _on_quit_pressed() -> void:
	if not _quit_armed:
		_quit_armed = true
		_quit_button.text = UiText.t("pause_quit_confirm", "CONFIRMER : LE SHIFT EN COURS SERA PERDU")
		_quit_button.theme_type_variation = &"ButtonDanger"
		return
	close()
	quit_to_title_requested.emit()


## Échap / Ⓑ (`cancel`), F10 / Menu (`pause`, M11 : action de `project.godot`).
static func is_pause_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"cancel", false, true) or event.is_action_pressed(&"pause", false, true):
		return true
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F10:
		return true
	var pad: InputEventJoypadButton = event as InputEventJoypadButton
	return pad != null and pad.pressed and pad.button_index == JOY_BUTTON_START


func _unhandled_input(event: InputEvent) -> void:
	if is_open or not enabled or FocusGuard.modal_over(self):
		# QA-057 : pas de pause par-dessus une boîte modale ouverte (elle se ferme d'abord).
		return
	if is_pause_event(event):
		open()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_open or hard_dialog != null:
		return
	if is_pause_event(event):
		if options.visible:
			show_menu()
		else:
			close()
		get_viewport().set_input_as_handled()
