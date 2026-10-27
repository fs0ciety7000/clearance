## Valeur d'un champ `PORTRAIT` (ARCHITECTURE §5.3, D-012/D-018).
##
## La photo référence une `PassengerAppearance` (la personne *sur la photo*) ;
## elle est rendue par `PortraitRenderer` (M4) depuis la même structure que
## l'acteur 3D. En headless, la comparaison se fait sur les traits.
class_name PortraitValue
extends RefCounted

var appearance: PassengerAppearance = null
## Cadrage, éclairage, grain (cosmétique).
var photo_seed: int = 0
## Photo plus ancienne que l'émission = bruit légitime (1–8 ans).
var years_before_issue: int = 0


func _init(p_appearance: PassengerAppearance = null, p_photo_seed: int = 0, p_years_before_issue: int = 0) -> void:
	appearance = p_appearance
	photo_seed = p_photo_seed
	years_before_issue = p_years_before_issue


func copy() -> PortraitValue:
	var app: PassengerAppearance = appearance.copy() if appearance != null else null
	return PortraitValue.new(app, photo_seed, years_before_issue)
