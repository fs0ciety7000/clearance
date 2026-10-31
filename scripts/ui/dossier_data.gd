## Contenu du **Dossier de l'agent** (M12 lot C, I33 ; M12 §5 ; D-131) —
## logique pure, sans nœud, testable : lit le **profil seul**
## (`ProfileService`) et la table des personnages (`CharacterTableDef`), et
## applique les **règles anti-spoiler** (M12 §5.4) :
## 1. aucun personnage non croisé, même en silhouette ; **aucun total**
##    (« 34 / 44 », « 7 / 10 fins », « 3 / 4 mondes ») ni **indice de niveau 2**
##    avant `epilogue_unlocked` ;
## 2. nom affiché = nom appris (`known_names`) — un faux nom reste entre
##    guillemets tant que le vrai n'a pas été montré ;
## 3. présentation = première rencontre (`dos_chr_<id>`) ;
## 4. jamais le titre d'une fin non vue, ni les pastilles de variantes non vues ;
## 5. « Dernière partie » = partie **terminée** (`last_campaign`) ;
## 6. épilogues : un monde non vu reste « Un autre 11 avril », sans nom.
class_name DossierData
extends RefCounted

## Fins dans l'ordre fixe F1 → F10.
const ENDINGS: Array[StringName] = [EndingService.F1_ARRESTED, EndingService.F2_REASSIGNED, EndingService.F3_FAMILY_LOST,
	EndingService.F4_GLORY, EndingService.F5_AIR, EndingService.F6_DRIFT, EndingService.F7_REOPENS, EndingService.F8_REGISTRE,
	EndingService.F9_STRIKE, EndingService.F10_PONT]
const WORLDS: Array[String] = ["a", "b", "c", "d"]
## Jour du J31 (cas des épilogues, première rencontre).
const EPILOGUE_DAY: int = 31
## M14 (D-191) : cache des portraits du Dossier (tous les personnages tiennent).
const PORTRAIT_CACHE: int = 48

## Table cas → jour (première apparition), construite à la demande.
static var _case_days: Dictionary[StringName, int] = {}


## Vrai si le titre propose le Dossier (au moins une fin vue ou un personnage croisé).
static func has_dossier(profile: Dictionary) -> bool:
	var clean: Dictionary = ProfileService.sanitize(profile)
	return not (clean["endings_seen"] as Array).is_empty() or not (clean["characters_met"] as Array).is_empty()


## Totaux, indices de niveau 2, mondes non vus : seulement après la première
## fin de l'Acte III (D-131).
static func totals_visible(profile: Dictionary) -> bool:
	return ProfileService.sanitize(profile)["epilogue_unlocked"] == true


## Préfixe court d'une fin (`f5_air` → `f5`).
static func short_id(ending: StringName) -> String:
	return String(ending).get_slice("_", 0)


# ---------------------------------------------------------------------------
# Fins
# ---------------------------------------------------------------------------

## Cartes des dix fins (ordre fixe). Vue : `{id, seen: true, title, eyebrow,
## first_date, day, count, variants: [libellés vus], first_line}` ; non vue :
## `{id, seen: false, hint1, hint2}` (`hint2` vide avant `epilogue_unlocked`).
static func ending_cards(profile: Dictionary) -> Array[Dictionary]:
	var clean: Dictionary = ProfileService.sanitize(profile)
	var unlocked: bool = clean["epilogue_unlocked"] == true
	var cards: Array[Dictionary] = []
	for ending: StringName in ENDINGS:
		var rows: Array[Dictionary] = []
		for entry: Dictionary in clean["endings_seen"]:
			if str(entry["id"]) == String(ending):
				rows.append(entry)
		var short: String = short_id(ending)
		if rows.is_empty():
			cards.append({"id": String(ending), "short": short, "seen": false,
					"hint1": UiText.t("dos_end_hint1_%s" % short, ""),
					"hint2": UiText.t("dos_end_hint2_%s" % short, "") if unlocked else ""})
			continue
		var first: Dictionary = rows[0]
		var count: int = 0
		var act: int = 1
		var variants: PackedStringArray = []
		for row: Dictionary in rows:
			count += SaveService.as_int(row["count"])
			act = maxi(act, SaveService.as_int(row.get("act", 1)))
			if str(row["date"]) < str(first["date"]):
				first = row
			var variant: String = str(row.get("variant", ""))
			if not variant.is_empty():
				var text: String = UiText.t("dos_variant_%s" % variant, variant.to_upper())
				if not variants.has(text):
					variants.append(text)
		var line_key: String = str(first.get("first_line_key", ""))
		cards.append({
			"id": String(ending), "short": short, "seen": true,
			"title": SaveSlotCard.ending_name(String(ending), act),
			"eyebrow": UiText.t("end_eyebrow_%s" % ending, "") if UiText.has("end_eyebrow_%s" % ending) else "",
			"first_date": str(first["date"]), "day": SaveService.as_int(first["day"]), "count": count,
			"variants": variants, "first_line": UiText.t(line_key, "") if not line_key.is_empty() else "",
		})
	return cards


## « 7 / 10 FINS » après `epilogue_unlocked`, vide avant (anti-spoiler).
static func endings_total_text(profile: Dictionary) -> String:
	if not totals_visible(profile):
		return ""
	var seen: int = 0
	for card: Dictionary in ending_cards(profile):
		if card["seen"]:
			seen += 1
	return UiText.tf("dos_total_endings", [seen, ENDINGS.size()], "%d / %d FINS")


## Date ISO (`2026-10-29T14:32:00`) → « 29.10.2026 ».
static func short_date(iso: String) -> String:
	if iso.length() < 10:
		return iso
	var parts: PackedStringArray = iso.substr(0, 10).split("-")
	if parts.size() != 3:
		return iso
	return "%s.%s.%s" % [parts[2], parts[1], parts[0]]


# ---------------------------------------------------------------------------
# Personnes
# ---------------------------------------------------------------------------

## Jour de première apparition de chaque cas scénarisé (données des jours de
## campagne + J31 des mondes), mis en cache.
static func case_days() -> Dictionary[StringName, int]:
	if not _case_days.is_empty():
		return _case_days
	var data: DataCatalog = RulebookReference.catalog()
	if data != null:
		for number: int in data.days:
			var day: DayDef = data.days[number]
			if day == null:
				continue
			for scripted: ScriptedCaseDef in day.scripted_cases:
				if scripted != null and (not _case_days.has(scripted.id) or _case_days[scripted.id] > number):
					_case_days[scripted.id] = number
	var epi: EpilogueDef = EpilogueService.load_def()
	if epi != null:
		for world: EpilogueWorldDef in epi.worlds:
			if world == null or world.day_def == null:
				continue
			for scripted: ScriptedCaseDef in world.day_def.scripted_cases:
				if scripted != null and not _case_days.has(scripted.id):
					_case_days[scripted.id] = EPILOGUE_DAY
	return _case_days


## Personnages croisés (au moins un cas dans `characters_met`), triés par
## première apparition : `{id, name, faction, initials, first_day, act,
## encounters, blurb}`. `act_filter` 0 = tous.
static func people(profile: Dictionary, table: CharacterTableDef, act_filter: int = 0) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if table == null:
		return result
	var clean: Dictionary = ProfileService.sanitize(profile)
	var met: Array = clean["characters_met"]
	var known: Array = clean["known_names"]
	var days: Dictionary[StringName, int] = case_days()
	for character: CharacterDef in table.characters:
		if character == null:
			continue
		var encounters: int = 0
		var first_day: int = 0
		for case_id: StringName in character.case_ids:
			if met.has(String(case_id)):
				encounters += 1
				var day: int = days.get(case_id, 0)
				if day > 0 and (first_day == 0 or day < first_day):
					first_day = day
		if encounters == 0:
			continue
		var act: int = ProfileService.act_of_day(first_day) if first_day > 0 else 1
		if act_filter > 0 and act != act_filter:
			continue
		var name: String = display_name(character, known)
		result.append({
			"id": String(character.id), "name": name, "faction": String(character.faction),
			"initials": initials(name), "first_day": first_day, "act": act, "encounters": encounters,
			"blurb": UiText.t(character.blurb_key, "") if not character.blurb_key.is_empty() else "",
		})
	result.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var dx: int = x["first_day"] if int(x["first_day"]) > 0 else 999
		var dy: int = y["first_day"] if int(y["first_day"]) > 0 else 999
		return dx < dy or (dx == dy and str(x["id"]) < str(y["id"])))
	return result


## Nom appris (règle 2) : vrai nom si `known_names` le contient, sinon le nom
## d'emprunt tel que le jeu l'a montré.
static func display_name(character: CharacterDef, known: Array) -> String:
	if not character.true_name.is_empty() and known.has(String(character.id)):
		return UiText.t(character.true_name, character.true_name)
	return UiText.t(character.display_name, character.display_name)


## Initiales (2 lettres) d'un nom affiché : mots à majuscule d'abord (noms
## propres), sans guillemets ni articles ; « ? » si aucune lettre.
static func initials(name: String) -> String:
	var cleaned: String = name.replace("«", " ").replace("»", " ").replace("(", " ").replace(")", " ").replace("\"", " ")
	var capitals: String = ""
	var any: String = ""
	for word: String in cleaned.split(" ", false):
		if word.to_lower() in ["le", "la", "les", "de", "du", "des", "et", "dr", "à", "au", "aux", "en", "un", "une"]:
			continue
		var bare: String = word.trim_prefix("L'").trim_prefix("l'").trim_prefix("d'")
		var first: String = bare.left(1)
		if first.is_empty() or first.to_upper() == first.to_lower():
			continue
		if any.length() < 2:
			any += first.to_upper()
		if first == first.to_upper() and capitals.length() < 2:
			capitals += first
	if capitals.length() >= 2:
		return capitals
	if capitals.length() == 1:
		return capitals
	return any if not any.is_empty() else "?"


## « 12 / 44 PERSONNES » après `epilogue_unlocked`, vide avant.
static func people_total_text(profile: Dictionary, table: CharacterTableDef) -> String:
	if not totals_visible(profile) or table == null:
		return ""
	return UiText.tf("dos_total_people", [people(profile, table).size(), table.characters.size()], "%d / %d PERSONNES")


## Couleur d'origine (repère décoratif, toujours avec le code en texte).
static func faction_color(faction: String) -> Color:
	match faction:
		"hal":
			return DS.FACTION_HAL
		"tyc":
			return DS.FACTION_TYC
		"ter":
			return DS.FACTION_TER
		"cer":
			return DS.FACTION_CER
		"thr":
			return DS.FACTION_THR
		"drv":
			return DS.FACTION_DRV
	return DS.FACTION_NONE


## Code d'origine affiché (« TYC »), « — » si inconnue.
static func faction_code(faction: String) -> String:
	return faction.to_upper() if not faction.is_empty() else "—"


# ---------------------------------------------------------------------------
# Dernière partie, Garde, épilogues
# ---------------------------------------------------------------------------

## Dernière partie terminée (`last_campaign`) : `{title, day, date, climate,
## traces: [textes], world}` ; vide si aucune. Le monde n'est donné qu'après
## `epilogue_unlocked`.
static func last_campaign(profile: Dictionary) -> Dictionary:
	var clean: Dictionary = ProfileService.sanitize(profile)
	var last: Dictionary = clean["last_campaign"]
	if last.is_empty() or str(last.get("ending", "")).is_empty():
		return {}
	var traces: PackedStringArray = []
	for key: Variant in last.get("traces", []):
		var text: String = UiText.t(str(key), str(key).trim_prefix("end_trace_"))
		traces.append(text.replace("%d", "—"))
	var climate: String = str(last.get("climate", ""))
	var world: String = str(last.get("world", ""))
	return {
		"title": SaveSlotCard.ending_name(str(last["ending"]), SaveService.as_int(last.get("act", 1), 1)),
		"day": SaveService.as_int(last.get("day", 0)),
		"date": short_date(str(last.get("date", ""))),
		"climate": UiText.t("chapter3_climate_%s" % climate, "") if not climate.is_empty() else "",
		"traces": traces,
		"world": UiText.t("dos_world_%s" % world, "") if not world.is_empty() and totals_visible(profile) else "",
	}


## Épilogues par monde (onglet visible seulement si `epilogue_unlocked`) :
## `{world, seen, name, variants: [{key, title, first_date, count, last_line}]}` ;
## un monde non vu : `{world, seen: false, name: "Un autre 11 avril"}`.
static func epilogue_worlds(profile: Dictionary) -> Array[Dictionary]:
	var clean: Dictionary = ProfileService.sanitize(profile)
	var epilogues: Dictionary = clean["epilogues"]
	var result: Array[Dictionary] = []
	for world: String in WORLDS:
		var variants: Array[Dictionary] = []
		var keys: Array = epilogues.keys()
		keys.sort()
		for key: Variant in keys:
			var entry: Dictionary = epilogues[key]
			if str(entry.get("world", "")) != world:
				continue
			var ending: String = str(key).get_slice(":", 0)
			var lines: Array = entry.get("last_lines", []) if entry.get("last_lines") is Array else []
			var variant: String = str(key).get_slice(":", 1)
			var title: String = SaveSlotCard.ending_name(ending, 3)
			if not variant.is_empty():
				title = "%s · %s" % [title, UiText.t("dos_variant_%s" % variant, variant.to_upper())]
			variants.append({
				"key": str(key), "title": title, "first_date": short_date(str(entry.get("first_date", ""))),
				"count": SaveService.as_int(entry.get("count", 0)),
				"last_line": UiText.t(str(lines[lines.size() - 1]), "") if not lines.is_empty() else "",
			})
		if variants.is_empty():
			result.append({"world": world, "seen": false, "name": UiText.t("dos_world_unknown", "Un autre 11 avril"), "variants": variants})
		else:
			result.append({"world": world, "seen": true, "name": UiText.t("dos_world_%s" % world, world.to_upper()), "variants": variants})
	return result
