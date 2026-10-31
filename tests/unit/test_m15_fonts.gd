## M15 (lot A) — couverture des glyphes des polices OFL (Inter, Chakra Petch,
## JetBrains Mono) pour tout le texte français, anglais et pseudo-localisé,
## avec la chaîne de repli du thème (`ThemeBuilder` : Inter derrière Chakra
## Petch et JetBrains Mono). Exceptions documentées : `▾` (remplacé par `▼`
## au Rulebook) et les symboles décoratifs que le code dessine en icône.
extends GutTest

## Caractères jamais rendus par les polices (remplacés ou dessinés autrement).
const IGNORED: String = "▾\n\r\t"


static func _chars_of(text: String, into: Dictionary) -> void:
	for i: int in text.length():
		var c: String = text[i]
		if c.unicode_at(0) > 32 and not IGNORED.contains(c):
			into[c] = true


func _required_chars() -> Dictionary:
	var chars: Dictionary = {}
	for lang: String in Localization.LANGUAGES:
		var messages: Dictionary = Localization.csv_messages(Localization.CSV_PATHS[lang])
		for key: String in messages:
			_chars_of(str(messages[key]), chars)
	for accented: String in Localization.PSEUDO_ACCENTS.values():
		chars[accented] = true
	for extra: String in [Localization.PSEUDO_PREFIX, Localization.PSEUDO_SUFFIX, Localization.PSEUDO_PAD,
			Localization.NNBSP, Localization.MINUS, Localization.CURRENCY, "✓", "▼"]:
		_chars_of(extra, chars)
	return chars


func test_every_theme_font_covers_french_english_and_pseudo_text() -> void:
	var theme: Theme = ThemeBuilder.build(1.0)
	var fonts: Dictionary = {}
	for type_name: StringName in theme.get_font_type_list():
		for font_name: StringName in theme.get_font_list(type_name):
			var font: Font = theme.get_font(font_name, type_name)
			if font != null:
				fonts[font] = "%s/%s" % [type_name, font_name]
	if theme.default_font != null:
		fonts[theme.default_font] = "default"
	assert_gt(fonts.size(), 3, "polices du thème")
	var chars: Dictionary = _required_chars()
	assert_gt(chars.size(), 60, "jeu de caractères FR + EN + pseudo-loc")
	var missing: PackedStringArray = []
	for font: Font in fonts:
		var absent: String = ""
		for c: String in chars:
			if not font.has_char(c.unicode_at(0)):
				absent += c
		if not absent.is_empty():
			missing.append("%s : %s" % [fonts[font], absent])
	assert_eq(missing.size(), 0, "glyphes absents :\n%s" % "\n".join(missing))


func test_pseudo_accents_are_in_the_ui_font_itself() -> void:
	var inter: FontFile = load(DS.FONT_UI_PATH) as FontFile
	for accented: String in Localization.PSEUDO_ACCENTS.values():
		assert_true(inter.has_char(accented.unicode_at(0)), "Inter : %s" % accented)
