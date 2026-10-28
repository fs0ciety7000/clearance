## Utilitaires sur les valeurs de champs : normalisation, égalité, affichage.
##
## Partagé par `FieldsMatchRule` et `DiscrepancyChecker` pour que la règle et
## l'outil d'inspection comparent exactement de la même façon (zéro faux
## positif, GDD P1). Classe utilitaire : fonctions statiques uniquement.
class_name FieldValue
extends RefCounted


## Texte : espaces de bord retirés, capitales (les documents impriment en
## capitales). Les autres types sont renvoyés tels quels.
static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value).strip_edges().to_upper()
		TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY:
			# Liste (implants) : ensemble de codes, ordre indifférent.
			var codes: PackedStringArray = []
			for item: Variant in value:
				codes.append(str(item).strip_edges().to_upper())
			codes.sort()
			return codes
	return value


## Égalité après normalisation ; types différents ⇒ faux (pas d'erreur).
## Les portraits ne se comparent pas ici (voir `FaceComparator`).
static func equals(a: Variant, b: Variant) -> bool:
	var na: Variant = normalize(a)
	var nb: Variant = normalize(b)
	if typeof(na) != typeof(nb):
		return false
	return na == nb


## Texte brut d'une valeur (dates formatées ; portrait = vide). Les codes ENUM
## et booléens sont traduits par l'UI (`tr()`), pas ici.
static func to_display(value: Variant, field: FieldDef) -> String:
	if value == null:
		return ""
	match field.kind:
		FieldDef.FieldKind.DATE:
			var days: int = value
			return GameDate.format_pattern(days, field.get_date_format())
		FieldDef.FieldKind.PORTRAIT:
			return ""
		FieldDef.FieldKind.LIST:
			var codes: PackedStringArray = normalize(value)
			return ", ".join(codes) if not codes.is_empty() else "—"
		FieldDef.FieldKind.TIME:
			var minutes: int = value
			return format_time(minutes)
	return str(value)


## « 15:59 » (minutes depuis minuit, Acte II : ticket de file).
static func format_time(minutes: int) -> String:
	var m: int = posmod(minutes, 24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]
