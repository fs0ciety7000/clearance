## Définition d'un champ de document (ARCHITECTURE §5.2).
##
## Sous-ressource embarquée dans le `.tres` du `DocumentTypeDef`.
## `truth_path` relie le champ à la vérité :
## - nom d'une propriété de `Passenger` (`&"family_name"`, `&"appearance"`…),
##   cf. `Passenger.TRUTH_PATHS` ;
## - ou `document.<propriété>` pour une donnée propre au document
##   (`document.serial`, `document.issue_date`, `document.expiry_date`,
##   `document.issuer_id`, `document.seal_id`), cf. `DocumentInstance`.
## Deux champs de même `truth_path` sur deux documents portent « la même
## donnée » : c'est ce que comparent `FieldsMatchRule` et `DiscrepancyChecker`.
class_name FieldDef
extends Resource

## Valeurs sérialisées en entier dans les `.tres` : on n'ajoute qu'à la fin.
## `LIST` (M7) : liste de codes (`PackedStringArray`, ex. implants déclarés).
## `TIME` (Acte II) : heure du shift en minutes depuis minuit (ticket de file,
## R29), affichée « HH:MM ».
enum FieldKind { TEXT, DATE, ID_CODE, ENUM, PORTRAIT, NUMBER, BOOL, LIST, TIME }

const DOCUMENT_PATH_PREFIX: String = "document."
const DEFAULT_DATE_FORMAT: String = "DD.MM.YYYY"

@export var id: StringName = &""
@export var label_key: String = ""
@export var kind: FieldKind = FieldKind.TEXT
@export var truth_path: StringName = &""
## Sélectionnable en mode Inspection.
@export var comparable: bool = true
@export var display_order: int = 0
## Motif d'affichage (dates : `YYYY`, `MM`, `DD`) ; vide = format par défaut.
@export var format: String = ""
## Acte III (B39) : ligne optionnelle (Répondant, Convocation du permis),
## affichée seulement quand la valeur est renseignée ; vide = absente.
@export var optional: bool = false


## Vrai si la valeur est une donnée du document (et non du passager).
func is_document_level() -> bool:
	return String(truth_path).begins_with(DOCUMENT_PATH_PREFIX)


## Nom de la propriété de `DocumentInstance` (`&"expiry_date"`), ou `&""`.
func get_document_property() -> StringName:
	if not is_document_level():
		return &""
	return StringName(String(truth_path).trim_prefix(DOCUMENT_PATH_PREFIX))


func get_date_format() -> String:
	return format if not format.is_empty() else DEFAULT_DATE_FORMAT
