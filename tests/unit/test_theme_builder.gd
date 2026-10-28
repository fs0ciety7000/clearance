## Tests ThemeBuilder : le thème se construit sans police et expose les variations clés.
extends GutTest


func test_build_returns_theme_with_variations() -> void:
	var theme: Theme = ThemeBuilder.build()
	assert_not_null(theme)
	for variation: StringName in [&"HoloPanel", &"DocFieldLabel", &"DocFieldValue", &"ButtonPrimary", &"ButtonDanger"]:
		assert_true(theme.is_type_variation(variation, theme.get_type_variation_base(variation)), "variation %s" % variation)
	assert_eq(theme.get_type_variation_base(&"ButtonPrimary"), &"Button")
	assert_eq(theme.get_type_variation_base(&"HoloPanel"), &"PanelContainer")
	assert_eq(theme.default_font_size, DS.FS_BODY)


func test_chamfer_styleboxes() -> void:
	var theme: Theme = ThemeBuilder.build()
	var box: StyleBoxFlat = theme.get_stylebox(&"panel", &"HoloPanel") as StyleBoxFlat
	assert_not_null(box)
	assert_eq(box.corner_detail, DS.CORNER_DETAIL_CHAMFER)
	assert_eq(box.corner_radius_top_left, DS.CHAMFER_L)
	assert_eq(box.corner_radius_bottom_right, DS.CHAMFER_L)
	assert_eq(box.corner_radius_top_right, 0, "signature « ticket » : coin vif")
	var primary: StyleBoxFlat = theme.get_stylebox(&"normal", &"ButtonPrimary") as StyleBoxFlat
	assert_eq(primary.bg_color, DS.ACCENT_YELLOW)
	assert_eq(theme.get_color(&"font_color", &"ButtonPrimary"), DS.TEXT_ON_ACCENT)


func test_tokens_parse_hex_colors() -> void:
	assert_eq(DS.BG_VOID, Color8(0x07, 0x08, 0x0C))
	assert_almost_eq(DS.CYAN_40.a, 0x66 / 255.0, 0.001)
