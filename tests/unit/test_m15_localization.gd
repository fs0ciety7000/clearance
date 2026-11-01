## M15 (lot A, D-213 / D-214) — langue à chaud, repli français, complétude de
## `en.csv`, pseudo-localisation `en-XA`, formats (nombres, crédits, dates).
##
## Les textes de test passent par des clés **propres au test** (`m15_test_*`,
## traductions ajoutées par `Localization.register_override`) : les tests ne
## dépendent pas du contenu de `en.csv` (lot B). Les tests de complétude
## lisent les deux CSV : `STRICT_EN_COMPLETENESS` (vrai depuis la livraison
## de `en.csv`, 4 234 / 4 234 clés) rend toute clé FR absente en EN fatale ;
## à faux, le test reste *pending* avec la liste des clés manquantes.
extends GutTest

## M15 : strict depuis la livraison de en.csv (lot B) — toute clé FR doit exister en EN.
const STRICT_EN_COMPLETENESS: bool = true

var _fr: Translation = null
var _en: Translation = null


func before_all() -> void:
	_fr = Translation.new()
	_fr.locale = "fr"
	_fr.add_message(&"m15_test_title", "CONTRÔLE")
	_fr.add_message(&"m15_test_count", "%d PASSAGERS")
	_fr.add_message(&"m15_test_wrap", "Jour %s")
	_fr.add_message(&"m15_test_word", "LUNDI")
	_fr.add_message(&"m15_test_fr_only", "SEULEMENT EN FRANÇAIS")
	_fr.add_message(&"m15_test_plural", "%d dossiers")
	_fr.add_message(&"m15_test_plural_one", "%d dossier")
	_en = Translation.new()
	_en.locale = "en"
	_en.add_message(&"m15_test_title", "CHECKPOINT")
	_en.add_message(&"m15_test_count", "%d PASSENGERS")
	_en.add_message(&"m15_test_wrap", "Day %s")
	_en.add_message(&"m15_test_word", "MONDAY")
	_en.add_message(&"m15_test_plural", "%d files")
	_en.add_message(&"m15_test_plural_one", "%d file")
	Localization.register_override(_fr)
	Localization.register_override(_en)


func after_all() -> void:
	Localization.clear_overrides()


func after_each() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	Settings.clear_session_value(Settings.KEY_PSEUDO_LOC)


func _set_lang(code: String) -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, code)


# ---------------------------------------------------------------------------
# Réglage
# ---------------------------------------------------------------------------

func test_language_setting_is_a_sanitized_text_setting() -> void:
	assert_true(Settings.has_key(Settings.KEY_LANGUAGE))
	assert_true(Settings.get_default(Settings.KEY_LANGUAGE) in ["fr", "en"], "défaut = langue du système résolue")
	assert_eq(Localization.sanitize_language("en_US"), "en")
	assert_eq(Localization.sanitize_language("EN"), "en")
	assert_eq(Localization.sanitize_language("fr_CA"), "fr")
	assert_eq(Localization.sanitize_language("de"), Localization.system_language(), "langue inconnue → système")
	assert_eq(Localization.sanitize_language(3.0), Localization.system_language())
	_set_lang("en")
	assert_eq(Settings.language, "en")
	assert_eq(TranslationServer.get_locale(), "en")
	_set_lang("fr")
	assert_eq(TranslationServer.get_locale(), "fr")


func test_language_is_persisted_as_text() -> void:
	var path: String = "user://test_m15_settings/settings.cfg"
	var config: ConfigFile = ConfigFile.new()
	config.set_value(Settings.SECTION, "language", "en")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	config.save(path)
	var previous: String = Settings.settings_path
	Settings.clear_session_value(Settings.KEY_LANGUAGE) # sinon la langue de session survit (use_storage)
	Settings.use_storage(path)
	assert_eq(Settings.language, "en", "lu depuis le fichier")
	Settings.set_value(Settings.KEY_LANGUAGE, "fr")
	var reread: ConfigFile = ConfigFile.new()
	reread.load(path)
	assert_eq(reread.get_value(Settings.SECTION, "language", ""), "fr", "écrit en texte")
	Settings.use_storage(previous)
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.get_base_dir())


# ---------------------------------------------------------------------------
# Traduction et repli
# ---------------------------------------------------------------------------

func test_english_with_french_fallback_for_a_missing_key() -> void:
	_set_lang("en")
	assert_eq(UiText.t("m15_test_title"), "CHECKPOINT")
	assert_eq(UiText.tf("m15_test_count", [3]), "3 PASSENGERS")
	assert_eq(UiText.t("m15_test_fr_only"), "SEULEMENT EN FRANÇAIS", "clé absente en anglais → français")
	assert_eq(UiText.t("m15_test_absent", "Repli du code"), "Repli du code", "clé absente partout → repli du code")
	assert_eq(UiText.plural("m15_test_plural", 1, "%d dossier", "%d dossiers"), "1 file")
	assert_eq(UiText.plural("m15_test_plural", 4, "%d dossier", "%d dossiers"), "4 files")
	_set_lang("fr")
	assert_eq(UiText.t("m15_test_title"), "CONTRÔLE")


func test_formatting_never_crashes_on_a_mismatched_translation() -> void:
	var bad: Translation = Translation.new()
	bad.locale = "en"
	bad.add_message(&"m15_test_bad", "No placeholder")
	Localization.register_override(bad)
	_set_lang("en")
	assert_eq(UiText.tf("m15_test_bad", [4], "%d bad"), "No placeholder", "motif renvoyé tel quel, sans erreur")
	TranslationServer.remove_translation(bad)


# ---------------------------------------------------------------------------
# Bascule à chaud
# ---------------------------------------------------------------------------

func test_hot_switch_retranslates_every_open_text() -> void:
	var root: VBoxContainer = VBoxContainer.new()
	add_child_autofree(root)
	var title: Label = ScreenBase.label(UiText.t("m15_test_title"))
	var upper: Label = ScreenBase.label(UiText.t("m15_test_word").to_upper())
	var count: Button = ScreenBase.button(UiText.tf("m15_test_count", [12]))
	count.tooltip_text = UiText.t("m15_test_title")
	var nested: Label = ScreenBase.label(UiText.tf("m15_test_wrap", [UiText.t("m15_test_word")]))
	var joined: Label = ScreenBase.label("%s · %s" % [UiText.t("m15_test_title"), "MARA OKONKWO"])
	var rich: RichTextLabel = RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = "[color=#ffffff]%s[/color] [b]%s[/b]" % [UiText.t("m15_test_title"), UiText.tf("m15_test_count", [2])]
	var proper: Label = ScreenBase.label("HALCYON GATE")
	var plural: Label = ScreenBase.label(UiText.plural("m15_test_plural", 1, "%d dossier", "%d dossiers"))
	for node: Control in [title, upper, count, nested, joined, rich, proper, plural]:
		root.add_child(node)
	_set_lang("en")
	assert_eq(title.text, "CHECKPOINT")
	assert_eq(upper.text, "MONDAY", "texte passé en capitales")
	assert_eq(count.text, "12 PASSENGERS", "arguments conservés")
	assert_eq(count.tooltip_text, "CHECKPOINT", "infobulle")
	assert_eq(nested.text, "Day MONDAY", "argument lui-même traduit")
	assert_eq(joined.text, "CHECKPOINT · MARA OKONKWO", "pièces séparées par « · », nom propre intact")
	assert_eq(rich.text, "[color=#ffffff]CHECKPOINT[/color] [b]2 PASSENGERS[/b]", "BBCode préservé")
	assert_eq(proper.text, "HALCYON GATE", "nom propre jamais traduit")
	assert_eq(plural.text, "1 file")
	_set_lang("fr")
	assert_eq(title.text, "CONTRÔLE", "retour au français")
	assert_eq(count.text, "12 PASSAGERS")
	assert_eq(nested.text, "Jour LUNDI")
	assert_eq(rich.text, "[color=#ffffff]CONTRÔLE[/color] [b]2 PASSAGERS[/b]")


func test_settings_changed_is_emitted_after_the_tree_is_retranslated() -> void:
	var label: Label = ScreenBase.label(UiText.t("m15_test_title"))
	add_child_autofree(label)
	var seen: Array[String] = []
	var listener: Callable = func(key: StringName, _value: Variant) -> void:
		if key == Settings.KEY_LANGUAGE:
			seen.append(label.text)
	EventBus.settings_changed.connect(listener)
	_set_lang("en")
	EventBus.settings_changed.disconnect(listener)
	assert_eq(seen, ["CHECKPOINT"] as Array[String], "les écrans qui recomposent voient déjà la nouvelle langue")


func test_options_panel_has_a_language_row_applied_hot() -> void:
	var panel: OptionsPanel = OptionsPanel.new()
	add_child_autofree(panel)
	await wait_process_frames(1)
	assert_eq(panel.language_buttons.size(), 2, "Français / English")
	assert_eq(panel.language_buttons["fr"].text, "FRANÇAIS", "endonyme")
	assert_eq(panel.language_buttons["en"].text, "ENGLISH", "endonyme")
	assert_true(panel.language_buttons["fr"].button_pressed, "langue active cochée")
	assert_eq(panel.first_control(), panel.language_buttons["fr"], "premier réglage : la langue active")
	var back_fr: String = panel.back_button.text
	panel.language_buttons["en"].button_pressed = true
	assert_eq(Settings.language, "en")
	assert_eq(panel.back_button.text, UiText.t("opt_back", "RETOUR"), "le panneau lui-même est retraduit")
	if UiText.t("opt_back") != back_fr:
		assert_ne(panel.back_button.text, back_fr)
	assert_eq(panel.language_buttons["en"].text, "ENGLISH", "endonyme jamais traduit")
	Settings.set_value(Settings.KEY_LANGUAGE, "fr", false)


# ---------------------------------------------------------------------------
# Complétude de en.csv (lot B)
# ---------------------------------------------------------------------------

func test_english_csv_has_the_expected_header() -> void:
	var file: FileAccess = FileAccess.open(Localization.CSV_PATHS["en"], FileAccess.READ)
	assert_not_null(file, "data/i18n/en.csv présent")
	if file != null:
		assert_eq(file.get_csv_line(), PackedStringArray(["keys", "en"]), "en-tête keys,en")


func test_every_french_key_exists_in_english() -> void:
	var missing: PackedStringArray = Localization.missing_keys("en")
	var total: int = Localization.csv_keys(Localization.CSV_PATHS["fr"]).size()
	var message: String = "%d / %d clés FR absentes de en.csv (ex. : %s)" % [missing.size(), total, ", ".join(missing.slice(0, 12))]
	if missing.is_empty():
		assert_true(true, "en.csv complet")
	elif STRICT_EN_COMPLETENESS:
		fail_test(message)
	else:
		pending("M15 — strict à l'intégration (STRICT_EN_COMPLETENESS) : " + message)


func test_english_has_no_key_unknown_in_french() -> void:
	var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
	var extra: PackedStringArray = []
	for key: String in Localization.csv_keys(Localization.CSV_PATHS["en"]):
		if not fr.has(key):
			extra.append(key)
	assert_eq(extra.size(), 0, "clés EN inconnues du FR : %s" % ", ".join(extra.slice(0, 12)))


func test_english_keeps_the_format_specifiers_of_french() -> void:
	var fr: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["fr"])
	var en: Dictionary = Localization.csv_messages(Localization.CSV_PATHS["en"])
	var bad: PackedStringArray = []
	for key: String in en:
		if fr.has(key) and Localization.format_specs(str(fr[key])) != Localization.format_specs(str(en[key])):
			bad.append(key)
	assert_eq(bad.size(), 0, "spécificateurs %%s / %%d différents : %s" % ", ".join(bad.slice(0, 12)))


# ---------------------------------------------------------------------------
# Pseudo-localisation en-XA
# ---------------------------------------------------------------------------

func test_pseudo_localization_expands_and_preserves_markup() -> void:
	var text: String = "Contrôle %s [b]Halcyon[/b] {name} %02d %%"
	var out: String = Localization.pseudo(text)
	assert_true(out.begins_with(Localization.PSEUDO_PREFIX) and out.ends_with(Localization.PSEUDO_SUFFIX), "bornes")
	for kept: String in ["%s", "[b]", "[/b]", "{name}", "%02d", "%%"]:
		assert_true(out.contains(kept), "préservé : %s" % kept)
	assert_eq(Localization.format_specs(out), Localization.format_specs(text), "spécificateurs intacts")
	var letters: String = "Inspection des documents"
	assert_gte(Localization.pseudo(letters).length() - 2, ceili(letters.length() * 1.3), "≈ +35 %")
	assert_false(Localization.pseudo("Inspection").contains("Inspection"), "accents")
	assert_false(Localization.pseudo("[serre son sac]").contains("serre son sac"), "didascalie entre crochets : du texte")
	assert_true(Localization.pseudo("[color=#ff0000]x[/color]").contains("[color=#ff0000]"), "balise avec valeur préservée")


func test_pseudo_setting_applies_to_translations_and_fallbacks() -> void:
	Settings.set_session_value(Settings.KEY_PSEUDO_LOC, true)
	assert_true(Localization.is_pseudo(), "debug : autorisée")
	assert_eq(TranslationServer.get_locale(), "fr", "locale inchangée : le texte produit est transformé")
	assert_eq(UiText.t("m15_test_title"), Localization.pseudo("CONTRÔLE"))
	assert_eq(UiText.t("m15_test_absent", "Repli"), Localization.pseudo("Repli"), "repli du code pseudo-localisé")
	assert_eq(UiText.tf("m15_test_count", [5]), Localization.pseudo("%d PASSAGERS") % 5)
	Settings.clear_session_value(Settings.KEY_PSEUDO_LOC)
	assert_false(Localization.is_pseudo())
	assert_eq(UiText.t("m15_test_title"), "CONTRÔLE")


# ---------------------------------------------------------------------------
# Formats
# ---------------------------------------------------------------------------

func test_numbers_and_credits_follow_the_language() -> void:
	assert_eq(Localization.number(1234567), "1 234 567", "espace fine insécable")
	assert_eq(Localization.credits(42), "42 ₵")
	assert_eq(Localization.credits(-5), "−5 ₵")
	assert_eq(Localization.credits(5, true), "+5 ₵")
	assert_eq(ScreenBase.credits(1500), "1 500 ₵")
	assert_eq(Localization.credits_tag(42), "₵ 42")
	_set_lang("en")
	assert_eq(Localization.number(1234567), "1,234,567")
	assert_eq(Localization.credits(42), "₵42")
	assert_eq(Localization.credits(-5), "−₵5")
	assert_eq(Localization.credits(1500, true), "+₵1,500")
	assert_eq(ScreenBase.credits(-12), "−₵12")
	assert_eq(Localization.credits_tag(42), "₵42")


func test_dates_and_hours_are_neutral() -> void:
	var day: int = GameDate.from_ymd(2187, 3, 19)
	var fr_date: String = UiText.date(day)
	var fr_clock: String = UiText.clock(14 * 60 + 7)
	_set_lang("en")
	assert_eq(UiText.date(day), fr_date, "JJ.MM.AAAA dans les deux langues")
	assert_eq(UiText.date(day), "19.03.2187")
	assert_eq(UiText.clock(14 * 60 + 7), fr_clock, "heure de station 24 h")
	assert_eq(Localization.clock(14 * 60 + 7), "14:07")
