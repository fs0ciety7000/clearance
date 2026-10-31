## M15 (lot A, D-213 / D-214) — langue du jeu, pseudo-localisation et formats.
##
## - **Langues** : `fr` (source, `data/i18n/fr.csv`) et `en` (`data/i18n/en.csv`,
##   mêmes clés, en-tête `keys,en`). Les deux sont importées par Godot
##   (`*.translation`, ignorés par git) et déclarées dans `project.godot`
##   (`internationalization/locale/translations`) ; `ensure_loaded()` les
##   enregistre aussi à la demande (clone neuf, outils `--script`). Clé absente
##   en anglais : repli **français** (`internationalization/locale/fallback`).
## - **Choix** : réglage `Settings.KEY_LANGUAGE` (« fr » / « en » ; défaut :
##   langue du système si `en*`, sinon `fr`) → `apply_language()` :
##   `TranslationServer.set_locale`, puis **retraduction à chaud** de tout
##   l'arbre (`retranslate_tree`) avant que `settings_changed` ne prévienne les
##   écrans qui recomposent eux-mêmes un texte (légendes de cinématique,
##   bandeau d'état, horloge…).
## - **Retraduction** : `UiText` mémorise la *recette* de chaque texte qu'il
##   produit (clé, arguments, repli) ; un texte affiché (Label, Button,
##   RichTextLabel, infobulle, onglets, items de menus, Label3D) est recomposé
##   dans la nouvelle langue. Un texte composé de plusieurs pièces (BBCode,
##   lignes, séparateurs « · » « — ») est retraduit pièce par pièce. Les noms
##   propres, le tessar, les codes et les valeurs générées ne sont jamais des
##   recettes : ils restent tels quels (D-213).
## - **Pseudo-localisation** `en-XA` (debug seulement : argument `--pseudo-loc`
##   ou réglage caché `Settings.KEY_PSEUDO_LOC`) : appliquée par `UiText` à
##   tout texte produit (traduction de la langue choisie ou repli du code) —
##   accents, allongement de +35 %, bornes `¡ … !` — sans toucher aux
##   spécificateurs `%s` / `%d`, aux balises BBCode ni aux `{jetons}`. Un texte
##   resté sans accents à l'écran est un texte **brut** (hors `UiText`).
## - **Formats** (D-214) : dates neutres `JJ.MM.AAAA` (`GameDate`), heures
##   24 h dans les deux langues (heure de station), nombres et crédits selon
##   la langue : `1 234 ₵` (espace fine insécable) en français, `₵1,234` en
##   anglais.
## Classe utilitaire : fonctions statiques uniquement. Ne dépend d'aucune scène.
class_name Localization
extends RefCounted

const LANG_FR: String = "fr"
const LANG_EN: String = "en"
## Langues proposées dans Options (ordre d'affichage).
const LANGUAGES: PackedStringArray = ["fr", "en"]
## Langue source (repli de toute clé absente).
const SOURCE_LANGUAGE: String = "fr"
## Locale de la pseudo-localisation (debug).
const PSEUDO_LOCALE: String = "en_XA"
const PSEUDO_TAG: String = "en-XA"
## Allongement de la pseudo-localisation (+35 %, D-214).
const PSEUDO_EXPANSION: float = 0.35
const PSEUDO_PREFIX: String = "¡"
const PSEUDO_SUFFIX: String = "!"
const PSEUDO_PAD: String = "·"
## Sources CSV (tests de complétude) et traductions importées.
const CSV_PATHS: Dictionary = {"fr": "res://data/i18n/fr.csv", "en": "res://data/i18n/en.csv"}
const TRANSLATION_PATHS: Dictionary = {
	"fr": "res://data/i18n/fr.fr.translation",
	"en": "res://data/i18n/en.en.translation",
}
## Espace fine insécable (séparateur de milliers français).
const NNBSP: String = " "
const MINUS: String = "−"
const CURRENCY: String = "₵"

## Accents de la pseudo-localisation : uniquement des glyphes présents dans
## les trois polices OFL (test `test_m15_fonts`).
const PSEUDO_ACCENTS: Dictionary = {
	"a": "á", "b": "ƀ", "c": "ç", "d": "đ", "e": "é", "g": "ğ", "h": "ĥ", "i": "í", "j": "ĵ", "k": "ķ", "l": "ľ",
	"n": "ñ", "o": "ö", "r": "ŕ", "s": "š", "t": "ţ", "u": "ü", "w": "ŵ", "y": "ý", "z": "ž",
	"A": "Á", "C": "Ç", "D": "Đ", "E": "É", "G": "Ğ", "H": "Ĥ", "I": "Í", "J": "Ĵ", "K": "Ķ", "L": "Ľ",
	"N": "Ñ", "O": "Ö", "R": "Ŕ", "S": "Š", "T": "Ţ", "U": "Ü", "W": "Ŵ", "Y": "Ý", "Z": "Ž",
}

## Textes gardés dans des propriétés propres à un composant et dessinés par
## `_draw` (tampons, libellé du visage, marques) : retraduits comme les autres.
const CUSTOM_TEXT_PROPERTIES: Array[StringName] = [&"caption", &"hint", &"locked_hint", &"face_label"]
## Contrat : un nœud qui expose `on_language_changed()` est rappelé après la
## retraduction de ses textes (largeurs recalculées, texte recomposé).
const LANGUAGE_HOOK: StringName = &"on_language_changed"

static var _loaded: bool = false
static var _pseudo: bool = false
static var _language: String = ""
## Traductions ajoutées à la demande (tests : `register_override`).
static var _overrides: Array[Translation] = []
static var _bbcode_regex: RegEx = null
static var _spec_regex: RegEx = null


# ---------------------------------------------------------------------------
# Chargement et choix de la langue
# ---------------------------------------------------------------------------

## Enregistre les traductions FR et EN importées (idempotent). Une langue sans
## fichier importé est ignorée : ses clés retombent sur le français.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for lang: String in LANGUAGES:
		var path: String = TRANSLATION_PATHS[lang]
		if not ResourceLoader.exists(path):
			if lang == SOURCE_LANGUAGE:
				push_warning("Localization: traduction absente (%s) — lancer `godot --headless --import`." % path)
			continue
		var translation: Translation = load(path) as Translation
		if translation != null:
			TranslationServer.add_translation(translation)


## Langue du système : `en` si la locale de l'OS commence par « en », sinon `fr`.
static func system_language() -> String:
	return LANG_EN if OS.get_locale_language().to_lower().begins_with("en") else LANG_FR


## Code valide (`fr` / `en`) ; tout autre texte → langue du système.
static func sanitize_language(value: Variant) -> String:
	var code: String = str(value).strip_edges().to_lower() if value is String or value is StringName else ""
	if code.begins_with("en"):
		return LANG_EN
	if code.begins_with("fr"):
		return LANG_FR
	return system_language()


## Langue courante (`fr` / `en`).
static func language() -> String:
	return _language if not _language.is_empty() else SOURCE_LANGUAGE


static func is_english() -> bool:
	return language() == LANG_EN


static func is_pseudo() -> bool:
	return _pseudo


## Locale effective du `TranslationServer` : la langue choisie (la
## pseudo-localisation s'applique au texte produit par `UiText`, pas à la
## locale : les traductions importées sont compressées et ne listent pas leurs
## messages).
static func locale_for(code: String, _pseudo_on: bool) -> String:
	return code


## Applique la langue (et la pseudo-localisation, debug) puis retraduit tout
## l'arbre courant. Renvoie vrai si la locale a changé.
static func apply_language(code: String, pseudo: bool = _pseudo) -> bool:
	ensure_loaded()
	var lang: String = sanitize_language(code)
	var use_pseudo: bool = pseudo and pseudo_allowed()
	var changed: bool = lang != _language or use_pseudo != _pseudo
	_language = lang
	_pseudo = use_pseudo
	var locale: String = locale_for(lang, _pseudo)
	if TranslationServer.get_locale() != locale:
		TranslationServer.set_locale(locale)
		changed = true
	if changed:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			retranslate_tree(tree.root)
	return changed


## La pseudo-localisation n'existe qu'en debug (éditeur, `godot` en ligne de
## commande, export *debug* ou fonctionnalité `debug_args`).
static func pseudo_allowed() -> bool:
	return OS.is_debug_build() or OS.has_feature("debug_args")


## Tests : ajoute une traduction (retirée par `clear_overrides`).
static func register_override(translation: Translation) -> void:
	ensure_loaded()
	TranslationServer.add_translation(translation)
	_overrides.append(translation)


static func clear_overrides() -> void:
	for translation: Translation in _overrides:
		TranslationServer.remove_translation(translation)
	_overrides.clear()


## Traduction importée d'une langue (null si absente).
static func imported_translation(lang: String) -> Translation:
	var path: String = TRANSLATION_PATHS.get(lang, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Translation


# ---------------------------------------------------------------------------
# Complétude (tests, outils)
# ---------------------------------------------------------------------------

## Clés d'un CSV de traduction (première colonne, en-tête exclu), dans l'ordre.
static func csv_keys(path: String) -> PackedStringArray:
	var keys: PackedStringArray = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	var header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if header:
			header = false
			continue
		if row.size() == 0 or row[0].strip_edges().is_empty():
			continue
		keys.append(row[0])
	return keys


## Valeurs d'un CSV (clé → texte de la 2ᵉ colonne).
static func csv_messages(path: String) -> Dictionary:
	var out: Dictionary = {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var header: bool = true
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if header:
			header = false
			continue
		if row.size() < 2 or row[0].strip_edges().is_empty():
			continue
		out[row[0]] = row[1]
	return out


## Clés françaises absentes (ou vides) du CSV anglais, dans l'ordre de `fr.csv`.
static func missing_keys(lang: String = LANG_EN) -> PackedStringArray:
	var target: Dictionary = csv_messages(CSV_PATHS.get(lang, ""))
	var missing: PackedStringArray = []
	for key: String in csv_keys(CSV_PATHS[SOURCE_LANGUAGE]):
		if str(target.get(key, "")).strip_edges().is_empty():
			missing.append(key)
	return missing


## Spécificateurs de format d'un texte (`%s`, `%d`, `%02d`… ; `%%` exclu), dans l'ordre.
static func format_specs(text: String) -> PackedStringArray:
	if _spec_regex == null:
		_spec_regex = RegEx.create_from_string("%(?:%|[-+0]*\\d*(?:\\.\\d+)?[sdifxXcov])")
	var specs: PackedStringArray = []
	for m: RegExMatch in _spec_regex.search_all(text):
		var spec: String = m.get_string()
		if spec != "%%":
			specs.append(spec.right(1))
	return specs


# ---------------------------------------------------------------------------
# Pseudo-localisation
# ---------------------------------------------------------------------------

## Texte pseudo-localisé : accents, allongement de +35 %, bornes `¡ … !`.
## Spécificateurs `%…`, balises `[…]`, jetons `{…}` et retours à la ligne
## préservés. Pure.
static func pseudo(text: String) -> String:
	if text.is_empty():
		return text
	var out: String = ""
	var letters: int = 0
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var c: String = text[i]
		if c == "%" and i + 1 < n:
			var j: int = i + 1
			while j < n and "-+0.123456789".contains(text[j]):
				j += 1
			if j < n:
				out += text.substr(i, j - i + 1)
				i = j + 1
				continue
		if c == "[" or c == "{":
			var close: String = "]" if c == "[" else "}"
			var end: int = text.find(close, i)
			# Balise BBCode (`[b]`, `[/color]`, `[color=#fff]`) ou jeton `{x}` :
			# préservés ; une didascalie « [serre son sac] » est du texte.
			if end > i and (c == "{" or _is_bbcode_tag(text.substr(i + 1, end - i - 1))):
				out += text.substr(i, end - i + 1)
				i = end + 1
				continue
		out += PSEUDO_ACCENTS.get(c, c)
		if c.to_upper() != c.to_lower():
			letters += 1
		i += 1
	var pad: int = ceili(letters * PSEUDO_EXPANSION)
	return PSEUDO_PREFIX + out + PSEUDO_PAD.repeat(pad) + PSEUDO_SUFFIX


static func _is_bbcode_tag(inner: String) -> bool:
	if inner.is_empty() or inner.contains(" ") and not inner.contains("="):
		return false
	var name: String = inner.trim_prefix("/").get_slice("=", 0).get_slice(" ", 0)
	return not name.is_empty() and name.is_valid_ascii_identifier() and name == name.to_lower()


# ---------------------------------------------------------------------------
# Retraduction à chaud
# ---------------------------------------------------------------------------

## Retraduit tous les textes affichés sous `root` (après `set_locale`), puis
## redemande le dessin des tracés. Renvoie le nombre de textes changés.
static func retranslate_tree(root: Node) -> int:
	var count: int = _retranslate_node(root)
	return count


static func _retranslate_node(node: Node) -> int:
	var count: int = 0
	if node is Control or node is Label3D or node is Window:
		count += _retranslate_props(node)
		for property: StringName in CUSTOM_TEXT_PROPERTIES:
			var value: Variant = node.get(property)
			if value is String:
				count += _set_if_changed(node, property, value)
	if node.has_method(LANGUAGE_HOOK):
		node.call(LANGUAGE_HOOK)
	if node is CanvasItem:
		var item: CanvasItem = node
		item.queue_redraw()
	for child: Node in node.get_children(true):
		count += _retranslate_node(child)
	return count


static func _retranslate_props(node: Node) -> int:
	var count: int = 0
	if node is RichTextLabel:
		var rich: RichTextLabel = node
		if not rich.text.is_empty():
			count += _set_if_changed(rich, &"text", rich.text)
	elif node is Label or node is Button or node is Label3D or node is LinkButton:
		count += _set_if_changed(node, &"text", str(node.get(&"text")))
	if node is LineEdit:
		var line: LineEdit = node
		count += _set_if_changed(line, &"placeholder_text", line.placeholder_text)
	elif node is TextEdit:
		var edit: TextEdit = node
		count += _set_if_changed(edit, &"placeholder_text", edit.placeholder_text)
	if node is Window:
		var window: Window = node
		count += _set_if_changed(window, &"title", window.title)
	if node is Control:
		var control: Control = node
		count += _set_if_changed(control, &"tooltip_text", control.tooltip_text)
	if node is TabContainer:
		var tabs: TabContainer = node
		for i: int in tabs.get_tab_count():
			var title: String = tabs.get_tab_title(i)
			var new_title: String = retranslate_text(title)
			if new_title != title:
				tabs.set_tab_title(i, new_title)
				count += 1
	elif node is TabBar:
		var bar: TabBar = node
		for i: int in bar.tab_count:
			var title_b: String = bar.get_tab_title(i)
			var new_b: String = retranslate_text(title_b)
			if new_b != title_b:
				bar.set_tab_title(i, new_b)
				count += 1
	if node is OptionButton:
		var opt: OptionButton = node
		for i: int in opt.item_count:
			var item: String = opt.get_item_text(i)
			var new_item: String = retranslate_text(item)
			if new_item != item:
				opt.set_item_text(i, new_item)
				count += 1
	elif node is PopupMenu:
		var menu: PopupMenu = node
		for i: int in menu.item_count:
			var entry: String = menu.get_item_text(i)
			var new_entry: String = retranslate_text(entry)
			if new_entry != entry:
				menu.set_item_text(i, new_entry)
				count += 1
	elif node is ItemList:
		var list: ItemList = node
		for i: int in list.item_count:
			var row: String = list.get_item_text(i)
			var new_row: String = retranslate_text(row)
			if new_row != row:
				list.set_item_text(i, new_row)
				count += 1
	return count


static func _set_if_changed(node: Object, property: StringName, text: String) -> int:
	if text.is_empty():
		return 0
	var new_text: String = retranslate_text(text)
	if new_text == text:
		return 0
	node.set(property, new_text)
	return 1


## Texte recomposé dans la langue courante, ou `text` inchangé s'il n'est pas
## issu de `UiText` (nom propre, code, valeur générée). Les textes composés
## sont retraduits pièce par pièce : segments hors balises BBCode, lignes,
## puis pièces séparées par « · », « — » ou « – ».
static func retranslate_text(text: String) -> String:
	if text.is_empty():
		return text
	var direct: Variant = UiText.remake(text)
	if direct is String:
		return direct
	if text.contains("["):
		return _retranslate_bbcode(text)
	if text.contains("\n"):
		return _retranslate_joined(text, "\n")
	for sep: String in [" · ", " — ", " – ", " › "]:
		if text.contains(sep):
			return _retranslate_joined(text, sep)
	return text


static func _retranslate_joined(text: String, sep: String) -> String:
	var parts: PackedStringArray = text.split(sep)
	var changed: bool = false
	for i: int in parts.size():
		var piece: String = retranslate_text(parts[i])
		if piece != parts[i]:
			parts[i] = piece
			changed = true
	return sep.join(parts) if changed else text


static func _retranslate_bbcode(text: String) -> String:
	if _bbcode_regex == null:
		_bbcode_regex = RegEx.create_from_string("\\[[^\\[\\]]*\\]")
	var out: String = ""
	var last: int = 0
	var changed: bool = false
	for m: RegExMatch in _bbcode_regex.search_all(text):
		var run: String = text.substr(last, m.get_start() - last)
		var new_run: String = _retranslate_run(run)
		changed = changed or new_run != run
		out += new_run + m.get_string()
		last = m.get_end()
	var tail: String = text.substr(last)
	var new_tail: String = _retranslate_run(tail)
	changed = changed or new_tail != tail
	out += new_tail
	return out if changed else text


## Segment de texte entre deux balises : espaces de bord conservés.
static func _retranslate_run(run: String) -> String:
	var core: String = run.strip_edges()
	if core.is_empty():
		return run
	var new_core: String = retranslate_text(core)
	if new_core == core:
		return run
	var start: int = run.find(core)
	return run.left(start) + new_core + run.substr(start + core.length())


# ---------------------------------------------------------------------------
# Formats (D-214)
# ---------------------------------------------------------------------------

## Entier avec séparateur de milliers de la langue : « 12 345 » / « 12,345 ».
static func number(value: int) -> String:
	var digits: String = str(absi(value))
	var sep: String = "," if is_english() else NNBSP
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = sep + out
	return (MINUS + out) if value < 0 else out


## Montant en crédits : « 42 ₵ », « −5 ₵ », « +5 ₵ » (français) ; « ₵42 »,
## « −₵5 », « +₵5 » (anglais). Signe « + » forcé si `signed` et positif.
static func credits(amount: int, signed: bool = false) -> String:
	var sign: String = MINUS if amount < 0 else ("+" if signed and amount > 0 else "")
	var body: String = number(absi(amount))
	if is_english():
		return sign + CURRENCY + body
	return sign + body + " " + CURRENCY


## M15 (lot U) : pourcentage — « 69 % » (français, espace) ; « 69% »
## (anglais, collé).
static func percent(value: int) -> String:
	return ("%d%%" % value) if is_english() else ("%d %%" % value)


## Solde compact des barres (« ₵ 42 » en français, « ₵42 » en anglais).
static func credits_tag(amount: int) -> String:
	if is_english():
		return (MINUS if amount < 0 else "") + CURRENCY + number(absi(amount))
	return CURRENCY + " " + (MINUS if amount < 0 else "") + number(absi(amount))


## Heure de station 24 h (« 14:37 ») : identique dans les deux langues.
static func clock(minutes: int) -> String:
	@warning_ignore("integer_division")
	var hours: int = minutes / 60
	return "%02d:%02d" % [hours, posmod(minutes, 60)]


## Date neutre « JJ.MM.AAAA » (D-214).
static func date(days: int) -> String:
	return GameDate.format(days)
