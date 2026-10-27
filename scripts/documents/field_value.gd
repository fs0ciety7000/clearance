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
	return str(value)
