## Bande MRZ de la carte d'identité (M7, GDD §4.1, §6 `MRZ_MISMATCH`, LORE §5)
## — fonctions statiques pures.
##
## Format CLEARANCE (simplification lisible du canon LORE
## `HG4471K2Q9<TYC…<<<<<<04`) :
## `<N° ID sans tirets><<CODE><<NOM><<<PRÉNOMS><<<GG>`, ex.
## `HG4471K2Q9<TYC<VASQUEZ<ORLOV<<MIRA<<04`. Lettres en capitales sans
## accents ; tirets, espaces et apostrophes → `<`. `GG` = guichet émetteur
## (`04` ; `07` = code Luciole n° 2). **Les deux derniers caractères ne sont
## jamais comparés** (GDD §4.1) : seuls N° ID, origine, nom et prénoms le sont.
class_name Mrz
extends RefCounted

const FILLER: String = "<"
const SEPARATOR: String = "<<"
const DEFAULT_ISSUER: String = "04"
const LUCIOLE_ISSUER: String = "07"
## Composantes comparables (`truth_path` du champ de la carte correspondant).
const COMPONENT_ID: StringName = &"citizen_id"
const COMPONENT_ORIGIN: StringName = &"faction_id"
const COMPONENT_FAMILY: StringName = &"family_name"
const COMPONENT_GIVEN: StringName = &"given_name"
const COMPONENTS: Array[StringName] = [COMPONENT_ID, COMPONENT_ORIGIN, COMPONENT_FAMILY, COMPONENT_GIVEN]
## Translittération des lettres accentuées (noms LORE : Sörensen, Kovač…).
const ACCENTS: Dictionary[String, String] = {
	"À": "A", "Á": "A", "Â": "A", "Ã": "A", "Ä": "A", "Å": "A", "Ç": "C", "Č": "C", "Ć": "C",
	"È": "E", "É": "E", "Ê": "E", "Ë": "E", "Ì": "I", "Í": "I", "Î": "I", "Ï": "I", "Ñ": "N",
	"Ò": "O", "Ó": "O", "Ô": "O", "Õ": "O", "Ö": "O", "Ø": "O", "Š": "S", "Ù": "U", "Ú": "U",
	"Û": "U", "Ü": "U", "Ý": "Y", "Ž": "Z", "Ł": "L", "Đ": "D",
}


## Texte MRZ d'un nom : capitales, sans accents, séparateurs → `<`.
static func clean(text: String) -> String:
	var upper: String = text.strip_edges().to_upper()
	var result: String = ""
	for i: int in upper.length():
		var c: String = upper[i]
		c = ACCENTS.get(c, c)
		var code: int = c.unicode_at(0)
		var alnum: bool = (code >= 65 and code <= 90) or (code >= 48 and code <= 57)
		result += c if alnum else FILLER
	return result


## Bande complète.
static func compose(citizen_id: String, origin_code: String, family_name: String, given_name: String,
		issuer: String = DEFAULT_ISSUER) -> String:
	return "%s%s%s%s%s%s%s%s%s" % [citizen_id.replace("-", ""), FILLER, origin_code.to_upper(), FILLER,
			clean(family_name), SEPARATOR, clean(given_name), SEPARATOR, issuer]


## Composantes d'une bande : `{citizen_id, faction_id (code), family_name,
## given_name, issuer}` (textes MRZ). Vide si la bande est mal formée.
static func parse(mrz: String) -> Dictionary[StringName, String]:
	var result: Dictionary[StringName, String] = {}
	var parts: PackedStringArray = mrz.split(SEPARATOR)
	if parts.size() < 3:
		return result
	var head: PackedStringArray = parts[0].split(FILLER)
	if head.size() < 3:
		return result
	result[COMPONENT_ID] = head[0]
	result[COMPONENT_ORIGIN] = head[1]
	result[COMPONENT_FAMILY] = FILLER.join(head.slice(2))
	result[COMPONENT_GIVEN] = parts[1]
	result[&"issuer"] = parts[parts.size() - 1]
	return result


## Guichet émetteur (deux derniers caractères), `DEFAULT_ISSUER` si absent.
static func issuer_of(mrz: String) -> String:
	return mrz.right(2) if mrz.length() >= 2 else DEFAULT_ISSUER


## Valeur MRZ attendue pour une composante, à partir de la valeur affichée du
## champ de la carte (`origin_code` : code à 3 lettres de l'origine).
static func expected_component(component: StringName, card_value: Variant, origin_code: String = "") -> String:
	match component:
		COMPONENT_ID:
			return str(card_value).replace("-", "")
		COMPONENT_ORIGIN:
			return origin_code.to_upper()
	return clean(str(card_value))


## Vrai si la composante de la bande recopie fidèlement la valeur de la carte.
static func component_matches(mrz: String, component: StringName, card_value: Variant, origin_code: String = "") -> bool:
	var parsed: Dictionary[StringName, String] = parse(mrz)
	if parsed.is_empty():
		return false
	return parsed.get(component, "") == expected_component(component, card_value, origin_code)


## Remplace une composante d'une bande (injecteur `MRZ_MISMATCH`), émetteur conservé.
static func with_component(mrz: String, component: StringName, value: String) -> String:
	var parsed: Dictionary[StringName, String] = parse(mrz)
	if parsed.is_empty():
		return mrz
	parsed[component] = value
	return "%s%s%s%s%s%s%s%s%s" % [parsed[COMPONENT_ID], FILLER, parsed[COMPONENT_ORIGIN], FILLER,
			parsed[COMPONENT_FAMILY], SEPARATOR, parsed[COMPONENT_GIVEN], SEPARATOR, parsed[&"issuer"]]


## Bande d'un document d'après ses champs affichés (la carte d'identité) ;
## `factions` donne le code d'origine. L'émetteur actuel est conservé.
static func compose_for(doc: DocumentInstance, factions: Dictionary[StringName, FactionDef]) -> String:
	var values: Dictionary[StringName, String] = {}
	for component: StringName in COMPONENTS:
		var field: FieldDef = doc.type_def.find_field_by_truth_path(component)
		values[component] = str(doc.get_value(field.id)) if field != null else ""
	var faction: FactionDef = factions.get(StringName(values[COMPONENT_ORIGIN]), null)
	var code: String = faction.code if faction != null else values[COMPONENT_ORIGIN].to_upper()
	var issuer: String = issuer_of(doc.mrz) if not doc.mrz.is_empty() else DEFAULT_ISSUER
	return compose(values[COMPONENT_ID], code, values[COMPONENT_FAMILY], values[COMPONENT_GIVEN], issuer)
