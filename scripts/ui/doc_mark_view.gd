## Marque au coin d'un document (M7, NARRATIVE §4.9) : la luciole du code 1,
## dessinée en magenta, lisible à la loupe. **Sélectionnable en Mode
## Inspection** : `FieldRef.mark(document_id, mark_id)`, comparable à l'entrée
## du bulletin « Symboles subversifs » (`SymbolCardView`, J7+).
## Discrète : aucun cadre au repos, même en inspection (le joueur doit la
## repérer) ; survol, sélection et discordance suivent `InspectableItem`.
## Zone cliquable circulaire (ne mord pas sur le dernier champ du document).
class_name DocMarkView
extends InspectableItem

const HIT_SIZE: float = DS.SPACE_6

var mark_id: StringName = &""
## Taille du glyphe (px, échelle 1 du document).
var glyph_px: float = 5.0


func setup(document_id: StringName, p_mark_id: StringName, p_glyph_px: float) -> void:
	mark_id = p_mark_id
	glyph_px = p_glyph_px
	ref = FieldRef.mark(document_id, p_mark_id)
	comparable = true
	name = "Mark_%s" % p_mark_id
	display_label = UiText.t("doc_mark_label", "Marque au coin du document")
	tooltip_text = display_label
	custom_minimum_size = Vector2(HIT_SIZE, HIT_SIZE)
	size = custom_minimum_size


## Place la marque centrée sur `center` (repère du parent).
func center_on(center: Vector2) -> void:
	position = center - size * 0.5


func get_center() -> Vector2:
	return position + size * 0.5


func _has_point(point: Vector2) -> bool:
	return point.distance_to(size * 0.5) <= HIT_SIZE * 0.5


## États dessinés en propre (cercle, pas d'icône d'alerte qui masquerait le
## glyphe) : survol / sélection cyan, discordance magenta + pastille numérotée.
func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = HIT_SIZE * 0.5 - 1.0
	var flagged: bool = is_flagged()
	if flagged:
		draw_circle(center, radius, DS.MAGENTA_12)
		draw_arc(center, radius, 0.0, TAU, 32, DS.ACCENT_MAGENTA, DS.BORDER_STRONG, true)
	elif selected:
		draw_circle(center, radius, DS.CYAN_12)
		draw_arc(center, radius, 0.0, TAU, 32, DS.ACCENT_CYAN, DS.BORDER_STRONG, true)
	elif _hovered:
		draw_circle(center, radius, DS.CYAN_08)
		draw_arc(center, radius, 0.0, TAU, 32, DS.CYAN_40, 1.0, true)
	if pulse > 0.0:
		var glow: Color = DS.MAGENTA_60 if flagged else DS.CYAN_60
		glow.a *= pulse
		draw_arc(center, radius + DS.SPACE_1 * pulse, 0.0, TAU, 32, glow, DS.BORDER_STRONG, true)
	if has_focus():
		draw_arc(center, radius + DS.FOCUS_RING_OFFSET, 0.0, TAU, 32, DS.ACCENT_CYAN, DS.FOCUS_RING_WIDTH, true)
	SlippedItemView.draw_luciole(self, center, glyph_px, Color(DS.ACCENT_MAGENTA, 0.85))
	if flagged:
		var x: float = size.x + DS.SPACE_2
		for number: int in flag_numbers:
			draw_number_badge(self, Vector2(x, -DS.SPACE_1), number, DS.ACCENT_MAGENTA)
			x -= DS.SPACE_5
	elif selected:
		draw_letter_badge(self, Vector2(size.x + DS.SPACE_2, -DS.SPACE_1), "A", DS.ACCENT_CYAN)


## Pas de soulignement ni de cadre au repos : la marque reste discrète.
func _draw_underline(_rect: Rect2) -> void:
	pass
