## Tampon officiel de la barre d'outils (DS §7.4, UI_FLOW §3.5) : verdict
## après **maintien** de `DS.STAMP_HOLD` (0,4 s, anti-erreur) à la souris, au
## clavier (V / X / D) ou à la manette. Verrouillé (cadenas, « aucun
## document ») tant que la phase n'est pas INSPECTING.
##
## Le maintien est piloté par `begin_hold()` / `end_hold()` / `advance(delta)`
## (appelé par `_process`) : testable sans entrée réelle.
class_name StampButton
extends Control

## Maintien complet : le verdict est posé.
signal stamped(kind: VerdictKind.Kind)

const HEIGHT: float = 64.0
const WIDTH: float = 212.0

var kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE
var hint: String = ""
var locked_hint: String = ""
var locked: bool = true:
	set(value):
		locked = value
		if locked:
			_holding = false
			hold_progress = 0.0
		mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_POINTING_HAND
		queue_redraw()
## 0 → 1 pendant le maintien.
var hold_progress: float = 0.0
var hold_duration: float = DS.STAMP_HOLD
var fx_intensity: float = 1.0
## Mode compact (barre d'outils étroite, Steam Deck) : sans la ligne d'aide
## sous le libellé, largeur réduite au libellé (QA-011).
var compact: bool = false:
	set(value):
		if compact == value:
			return
		compact = value
		_update_width()
		queue_redraw()

var _holding: bool = false
var _hovered: bool = false
var _flash: float = 0.0


func setup(p_kind: VerdictKind.Kind, p_hint: String, p_locked_hint: String) -> void:
	kind = p_kind
	hint = p_hint
	locked_hint = p_locked_hint
	custom_minimum_size = Vector2(WIDTH, HEIGHT)
	focus_mode = Control.FOCUS_ALL
	tooltip_text = StampMark.label_of(kind) + " — " + hint
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Aide « maintenir … » réécrite quand le périphérique change (M11).
func set_hint(p_hint: String) -> void:
	if p_hint == hint:
		return
	hint = p_hint
	tooltip_text = StampMark.label_of(kind) + " — " + hint
	_update_width()
	queue_redraw()


## Largeur ajustée au texte (échelle du texte, plancher Steam Deck). Tout
## maintien est annulé quand l'arbre passe en pause, que la fenêtre perd le
## focus ou que le tampon est masqué : le relâchement ne serait jamais reçu
## et le verdict tomberait à la reprise (QA-005).
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		if _holding:
			end_hold()
	elif what == NOTIFICATION_THEME_CHANGED:
		_update_width()


## M15 : textes retraduits (`Localization`) — largeur et infobulle recalculées.
func on_language_changed() -> void:
	tooltip_text = StampMark.label_of(kind) + " — " + hint
	_update_width()
	queue_redraw()


func _update_width() -> void:
	if not is_inside_tree():
		return
	var font: Font = get_theme_font(&"font", &"StampLabel")
	var small: Font = get_theme_font(&"font", &"CaptionLabel")
	var caption_size: int = get_theme_font_size(&"font_size", &"CaptionLabel")
	var text_w: float = font.get_string_size(StampMark.label_of(kind), HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size(&"font_size", &"StampLabel")).x
	if not compact:
		for caption: String in [hint, locked_hint]:
			text_w = maxf(text_w, small.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x)
	var base: float = DS.SPACE_4 + DS.ICON_L + DS.SPACE_3 + text_w + DS.SPACE_4
	custom_minimum_size.x = ceilf(base) if compact else maxf(WIDTH, base)


func is_holding() -> bool:
	return _holding


func begin_hold() -> void:
	if locked:
		return
	_holding = true
	queue_redraw()


func end_hold() -> void:
	_holding = false
	hold_progress = 0.0
	queue_redraw()


## Fait avancer le maintien ; renvoie vrai si le verdict vient d'être posé.
func advance(delta: float) -> bool:
	_flash = maxf(_flash - delta / DS.DUR_SLOW, 0.0)
	if not _holding or locked:
		return false
	hold_progress = minf(hold_progress + delta / maxf(hold_duration, 0.001), 1.0)
	queue_redraw()
	if hold_progress >= 1.0:
		_holding = false
		hold_progress = 0.0
		_flash = 1.0
		stamped.emit(kind)
		return true
	return false


func _process(delta: float) -> void:
	if _holding or _flash > 0.0:
		advance(delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			begin_hold()
		else:
			end_hold()
		accept_event()
		return
	if event.is_action(&"ui_accept") and not event.is_echo():
		if event.is_pressed():
			begin_hold()
		else:
			end_hold()
		accept_event()


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	if _holding:
		end_hold()
	queue_redraw()


func _draw() -> void:
	var color: Color = StampMark.color_of(kind)
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	var bg: Color = DS.BG_PANEL
	var border: Color = color
	if locked:
		bg = DS.DISABLED_BG
		border = Palette.LINE_SUBTLE
	elif _hovered or _holding:
		bg = DS.BG_PANEL.blend(Color(color, 0.12))
	var box: StyleBoxFlat = ThemeBuilder.chamfer_box(bg, border, DS.BORDER_DEFAULT, DS.CHAMFER_M, 0)
	if not locked and (_hovered or _flash > 0.0):
		box.shadow_color = Color(color, 0.24 + 0.36 * _flash)
		box.shadow_size = DS.GLOW_1 if _flash <= 0.0 else roundi(lerpf(DS.GLOW_1, DS.GLOW_3 * clampf(fx_intensity, 0.25, 1.0), _flash))
	draw_style_box(box, rect)
	# Jauge de maintien (remplissage gauche → droite + trait bas).
	if hold_progress > 0.0:
		draw_rect(Rect2(DS.BORDER_DEFAULT, DS.BORDER_DEFAULT, (size.x - 2.0) * hold_progress, size.y - 2.0), Color(color, 0.24))
		draw_rect(Rect2(0, size.y - 3.0, size.x * hold_progress, 3.0), color)
	if has_focus():
		draw_style_box(ThemeBuilder.focus_box(DS.CHAMFER_M), rect)
	var fg: Color = color if not locked else DS.TEXT_MUTED
	var icon_rect: Rect2 = Rect2(Vector2(DS.SPACE_4, (size.y - DS.ICON_L) * 0.5), Vector2(DS.ICON_L, DS.ICON_L))
	UiIcon.draw_icon(self, StampMark.icon_of(kind), icon_rect, fg, DS.BORDER_STRONG)
	if locked:
		UiIcon.draw_icon(self, UiIcon.Kind.LOCK, Rect2(icon_rect.end - Vector2(DS.ICON_S * 0.6, DS.ICON_S * 0.7), Vector2(DS.ICON_S, DS.ICON_S)), Palette.TEXT_SECONDARY)
	var font: Font = get_theme_font(&"font", &"StampLabel")
	var font_size: int = get_theme_font_size(&"font_size", &"StampLabel")
	var x: float = icon_rect.end.x + DS.SPACE_3
	var width: float = size.x - x - DS.SPACE_3
	if compact:
		var ascent: float = font.get_ascent(font_size) - font.get_height(font_size) * 0.5
		draw_string(font, Vector2(x, size.y * 0.5 + ascent), StampMark.label_of(kind), HORIZONTAL_ALIGNMENT_LEFT, width, font_size, fg)
		return
	draw_string(font, Vector2(x, size.y * 0.5 + 1.0), StampMark.label_of(kind), HORIZONTAL_ALIGNMENT_LEFT, width, font_size, fg)
	var small: Font = get_theme_font(&"font", &"CaptionLabel")
	var small_size: int = get_theme_font_size(&"font_size", &"CaptionLabel")
	var sub: String = locked_hint if locked else hint
	draw_string(small, Vector2(x, size.y * 0.5 + small_size + DS.SPACE_2), sub, HORIZONTAL_ALIGNMENT_LEFT, width, small_size,
			Palette.TEXT_SECONDARY)
