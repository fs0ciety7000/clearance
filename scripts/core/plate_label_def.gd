## Texte posé à l'exécution sur la couche holographique d'une planche (M14
## §3.1 règle 6, B91, D-184) : jamais cuit dans l'image, police DS, traduisible.
class_name PlateLabelDef
extends Resource

## Clé i18n (`fr.csv`), ou texte littéral non traduisible (« 27-B », horloge).
@export var text_key: String = ""
## Rectangle dans l'espace de la planche (0..1).
@export var rect: Rect2 = Rect2(0.4, 0.4, 0.2, 0.1)
## Style DS du `CinematicScreen` (lot D) : `holo_display`, `holo_small`, `clock`.
@export var style: StringName = &"holo_small"
## Ajout lot E (demande du lot C, BOOTH_SCENE §19.2) : vrai si `text_key` est
## un **texte littéral** affiché tel quel (numéro de vitre « 04 », « 27-B »,
## horloge « 14:00 ») et non une clé de `fr.csv`.
@export var literal: bool = false


## Texte à afficher : `text_key` tel quel si `literal`, sinon `translate(text_key)`.
func display_text(translate: Callable) -> String:
	return text_key if literal else str(translate.call(text_key))
