## Empreinte de tampon posée sur le document (DS §7.4) : double cadre
## chanfreiné, icône d'état 32 px, libellé `display` en capitales, micro-texte
## Consortium ; rotation ±4°, apparition 1,08 → 1,0 (`ease.impact`).
class_name StampMark
extends Control

const SIZE: Vector2 = Vector2(300, 112)

var kind: VerdictKind.Kind = VerdictKind.Kind.APPROVE
var caption: String = ""


static func color_of(p_kind: VerdictKind.Kind) -> Color:
	match p_kind:
		VerdictKind.Kind.DENY:
			return DS.STATE_RED
		VerdictKind.Kind.DETAIN:
			return DS.ACCENT_YELLOW
	return DS.STATE_GREEN


static func icon_of(p_kind: VerdictKind.Kind) -> UiIcon.Kind:
	match p_kind:
		VerdictKind.Kind.DENY:
			return UiIcon.Kind.DENIED
		VerdictKind.Kind.DETAIN:
			return UiIcon.Kind.DETAIN
	return UiIcon.Kind.APPROVED


static func label_of(p_kind: VerdictKind.Kind) -> String:
	match p_kind:
		VerdictKind.Kind.DENY:
			return UiText.t("stamp_deny", "REFUSÉ")
		VerdictKind.Kind.DETAIN:
			return UiText.t("stamp_detain", "DÉTENTION")
	return UiText.t("stamp_approve", "APPROUVÉ")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = SIZE * 0.5


func _draw() -> void:
	var color: Color = color_of(kind)
	var ink: Color = Color(color, 0.92)
	var outer: Rect2 = Rect2(Vector2.ZERO, size)
	var inner: Rect2 = outer.grow(-5.0)
	var fill: PackedVector2Array = _chamfer(outer, DS.CHAMFER_M)
	fill.resize(fill.size() - 1)
	draw_colored_polygon(fill, Color(DS.BG_PANEL, 0.82))
	draw_colored_polygon(fill, Color(color, 0.1))
	draw_polyline(_chamfer(outer, DS.CHAMFER_M), ink, DS.BORDER_STRONG, true)
	draw_polyline(_chamfer(inner, DS.CHAMFER_S), ink, DS.BORDER_HAIRLINE, true)
	var icon_rect: Rect2 = Rect2(Vector2(DS.SPACE_4, (size.y - DS.ICON_L) * 0.5 - DS.SPACE_2), Vector2(DS.ICON_L, DS.ICON_L))
	UiIcon.draw_icon(self, icon_of(kind), icon_rect, ink, DS.BORDER_STRONG)
	var font: Font = get_theme_font(&"font", &"DisplayLabel")
	var font_size: int = get_theme_font_size(&"font_size", &"DisplayLabel")
	var text: String = label_of(kind)
	var text_x: float = icon_rect.end.x + DS.SPACE_3
	var available: float = size.x - text_x - DS.SPACE_4
	var fitted: int = font_size
	while fitted > DS.FS_TITLE and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > available:
		fitted -= 2
	draw_string(font, Vector2(text_x, size.y * 0.5 + font.get_ascent(fitted) * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, available, fitted, ink)
	var small: Font = get_theme_font(&"font", &"DataSmall")
	var small_size: int = get_theme_font_size(&"font_size", &"CaptionLabel")
	draw_string(small, Vector2(text_x, size.y - DS.SPACE_3), caption, HORIZONTAL_ALIGNMENT_LEFT, available, small_size, Color(color, 0.8))


static func _chamfer(rect: Rect2, c: float) -> PackedVector2Array:
	return PackedVector2Array([rect.position + Vector2(c, 0), Vector2(rect.end.x, rect.position.y), rect.end - Vector2(0, c),
			rect.end - Vector2(c, 0), Vector2(rect.position.x, rect.end.y), rect.position + Vector2(0, c), rect.position + Vector2(c, 0)])
