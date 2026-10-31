## M15 (lot U) — secteurs d'origine (`FactionDef.origin_sectors`,
## `Passenger.origin_sector`) : textes **français** des données, tirés sans
## dépendre de la langue (D-224), affichés traduits **de la même façon** sur
## les documents (champ « Zone » de l'Attestation d'asile) et dans l'onglet
## Origines du Rulebook (`faction_<id>_sectors`).
extends GutTest

const CaseFactory := preload("res://tests/helpers/case_factory.gd")


func after_each() -> void:
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)


func _zone_field() -> FieldDef:
	for field: FieldDef in CaseFactory.doc_def(&"asylum").fields:
		if field.truth_path == UiText.ORIGIN_SECTOR_PATH:
			return field
	return null


## Chaque secteur a sa clé, dans les deux langues, et la ligne du Rulebook est
## exactement la suite des secteurs (mêmes mots des deux côtés).
func test_every_sector_has_a_key_matching_the_rulebook_line() -> void:
	for lang: String in [Localization.LANG_FR, Localization.LANG_EN]:
		var messages: Dictionary = Localization.csv_messages(Localization.CSV_PATHS[lang])
		for faction: FactionDef in CaseFactory.catalog().factions.values():
			var parts: PackedStringArray = []
			for i: int in faction.origin_sectors.size():
				var key: String = faction.sector_key(i)
				assert_true(messages.has(key), "%s : clé %s" % [lang, key])
				parts.append(str(messages.get(key, "")))
				if lang == Localization.LANG_FR:
					assert_eq(str(messages.get(key, "")), faction.origin_sectors[i], "FR = texte des données (%s)" % key)
			var line_key: String = "faction_%s_sectors" % faction.id
			assert_eq(" · ".join(parts), str(messages.get(line_key, "")), "%s : %s = secteurs joints" % [lang, line_key])


func test_document_zone_follows_the_language() -> void:
	var field: FieldDef = _zone_field()
	assert_not_null(field, "champ Zone de l'Attestation d'asile")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	assert_eq(UiText.value_text(field, "Anneau C — logements de service"), "ANNEAU C — LOGEMENTS DE SERVICE")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	assert_eq(UiText.value_text(field, "Anneau C — logements de service"), "RING C — SERVICE QUARTERS")
	assert_eq(UiText.value_text(field, "Cratère Tycho — dortoirs Kessler-Ashe"), "TYCHO CRATER — KESSLER-ASHE DORMITORIES")
	# Texte inconnu (donnée d'un test, cas scénarisé hors liste) : tel quel.
	assert_eq(UiText.value_text(field, "Colonie Tycho"), "COLONIE TYCHO")


## Retraduction à chaud : la valeur affichée a une recette (même mécanique que
## les autres textes traduits).
func test_document_zone_is_retranslated_hot() -> void:
	var field: FieldDef = _zone_field()
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	var shown: String = UiText.value_text(field, "Anneaux D–F")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	assert_eq(UiText.remake(shown), "RINGS D–F")


## La génération ne lit jamais la langue : même graine → mêmes secteurs.
func test_generated_sectors_do_not_depend_on_language() -> void:
	var data: DataCatalog = CaseFactory.catalog()
	var day: DayDef = data.get_day(12)
	var runs: Array[PackedStringArray] = []
	for lang: String in [Localization.LANG_FR, Localization.LANG_EN]:
		Settings.set_session_value(Settings.KEY_LANGUAGE, lang)
		var builder: CaseBuilder = CaseBuilder.new(data, day, 4242)
		var sectors: PackedStringArray = []
		for i: int in day.passenger_count:
			var generated: GeneratedCase = builder.build(i)
			if generated != null:
				sectors.append(generated.case.passenger_presented.origin_sector)
		runs.append(sectors)
	assert_eq(runs[0], runs[1])
	for sector: String in runs[0]:
		if sector.is_empty():
			continue
		var known: bool = false
		for faction: FactionDef in data.factions.values():
			known = known or faction.origin_sectors.has(sector)
		assert_true(known, "secteur des données (français) : %s" % sector)


## « SANS EMPLOYEUR » (donnée comparée telle quelle par R09) : mention traduite
## à l'affichage, jamais dans les données.
func test_no_employer_mention_is_translated_at_display_only() -> void:
	var employer: FieldDef = null
	for field: FieldDef in CaseFactory.doc_def(&"entry_permit").fields:
		if field.id == &"employer":
			employer = field
	assert_not_null(employer, "champ Employeur du permis")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_EN)
	assert_eq(UiText.value_text(employer, "SANS EMPLOYEUR"), "NO EMPLOYER")
	assert_eq(UiText.value_text(employer, "Valcourt-Hsu Logistique"), "VALCOURT-HSU LOGISTIQUE", "noms d'employeurs : tels quels (D-219)")
	Settings.set_session_value(Settings.KEY_LANGUAGE, Localization.LANG_FR)
	assert_eq(UiText.value_text(employer, "SANS EMPLOYEUR"), "SANS EMPLOYEUR")
