## M15 (lot A) — robustesse des composants partagés à l'allongement des textes
## (anglais, pseudo-localisation +35 %, texte 150 %) : le texte d'appoint d'un
## en-tête de section (`ScreenBase.section`, `SideLabel`) n'élargit jamais
## l'écran — tronqué avec infobulle quand la place manque, entier sinon.
extends GutTest

const ROW_WIDTH: float = 520.0


func _section_in_box(side: String) -> Array:
	var holder: Control = Control.new()
	holder.theme = ThemeBuilder.build(1.0)
	add_child_autofree(holder)
	var box: VBoxContainer = VBoxContainer.new()
	box.size = Vector2(ROW_WIDTH, 200.0)
	holder.add_child(box)
	var row: Container = ScreenBase.section("ÉCONOMAT DU HALL", UiIcon.Kind.TOOL, DS.ACCENT_YELLOW, side)
	box.add_child(row)
	return [box, row]


func _side_of(row: Container) -> Label:
	return row.get_child(row.get_child_count() - 1) as Label


func test_short_side_text_is_shown_whole() -> void:
	var parts: Array = _section_in_box("Un achat par soir.")
	await wait_process_frames(4)
	var box: VBoxContainer = parts[0]
	var side: Label = _side_of(parts[1])
	assert_eq(box.size.x, ROW_WIDTH, "largeur inchangée")
	var font: Font = side.get_theme_font(&"font")
	var full: float = font.get_string_size(side.text, HORIZONTAL_ALIGNMENT_LEFT, -1, side.get_theme_font_size(&"font_size")).x
	assert_gte(side.size.x + 1.0, full, "texte entier : %s ≥ %s" % [side.size.x, full])
	assert_eq(side.tooltip_text, "", "pas d'infobulle quand tout tient")


func test_long_side_text_never_widens_the_row() -> void:
	var long: String = Localization.pseudo("One purchase per evening. The Commissary gives no credit, ever, to anyone.")
	var parts: Array = _section_in_box(long)
	await wait_process_frames(4)
	var box: VBoxContainer = parts[0]
	var row: Container = parts[1]
	var side: Label = _side_of(row)
	assert_eq(box.size.x, ROW_WIDTH, "la colonne ne s'élargit pas")
	assert_lte(row.size.x, ROW_WIDTH)
	assert_gt(side.size.x, DS.SPACE_8, "le texte reste visible (tronqué)")
	assert_eq(side.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_eq(side.tooltip_text, long, "texte complet en infobulle")


func test_side_text_of_a_content_sized_row_is_whole() -> void:
	var holder: Control = Control.new()
	holder.theme = ThemeBuilder.build(1.0)
	add_child_autofree(holder)
	var row: Container = ScreenBase.section("TITRE", UiIcon.Kind.TOOL, DS.ACCENT_YELLOW, "Texte d'appoint assez long")
	holder.add_child(row)
	await wait_process_frames(4)
	var side: Label = _side_of(row)
	var font: Font = side.get_theme_font(&"font")
	var full: float = font.get_string_size(side.text, HORIZONTAL_ALIGNMENT_LEFT, -1, side.get_theme_font_size(&"font_size")).x
	assert_gte(side.size.x + 1.0, full, "rangée libre : texte entier")
