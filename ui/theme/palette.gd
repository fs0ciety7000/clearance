## CLEARANCE — palette **active** des couleurs sémantiques (DESIGN_SYSTEM §2.5).
##
## Les tokens de base de `DS` sont figés par le contrat (constantes, données
## `holo_tint_token`). Les couleurs qui portent un **état** ou une **voix**
## (concordance / approbation, refus, discordance, avertissement, voix de
## l'Acte II) et deux neutres (texte secondaire, filet) sont lues ici, par
## l'UI, sous le même nom que dans `DS` : `Palette.STATE_RED` au lieu de
## `DS.STATE_RED`. Le réglage d'accessibilité « Vision des couleurs »
## (`Settings.color_vision`) remplace ces valeurs par une variante
## distinguable (`apply()`, appelé par `Settings`) ; en mode « Aucun » elles
## valent exactement les tokens de `DS`.
##
## Les variantes ont été choisies par simulation (Machado 2009, sévérité 1,0)
## et écart CIEDE2000 entre paires critiques ; contrastes WCAG mesurés : voir
## DESIGN_SYSTEM §2.5. Les formes, icônes et libellés restent le premier porteur
## du sens (DS §1.3) : la palette n'est qu'un renfort.
class_name Palette
extends RefCounted

enum Mode {
	NONE, ## palette du contrat
	PROTAN_DEUTAN, ## protanopie / deutéranopie : axe bleu ↔ jaune + clarté
	TRITAN, ## tritanopie : axe rouge ↔ vert + clarté
	HIGH_CONTRAST, ## contraste élevé : états plus clairs, neutres renforcés
}

## Couleurs remplacées par mode (les absentes gardent la valeur du contrat).
## Clés = noms des tokens `DS` ; les variantes alpha (_12/_24/_60) suivent.
const VARIANTS: Dictionary[int, Dictionary] = {
	Mode.PROTAN_DEUTAN: {
		&"STATE_GREEN": Color("#4A90F0"), # approbation / concordance → bleu
		&"STATE_RED": Color("#FF3D1F"), # refus → vermillon (sombre pour un protan : écart de clarté)
		&"ACCENT_MAGENTA": Color("#F0B0C8"), # discordance → rose pâle, très clair
		&"STATE_AMBER": Color("#FFF0A0"), # avertissement → jaune paille, très clair
		&"VOICE_COMMISSION": Color("#B0A0FF"),
		&"VOICE_BRULANTS": Color("#A88A70"),
	},
	Mode.TRITAN: {
		&"STATE_GREEN": Color("#C8FF66"), # approbation → vert-jaune
		&"STATE_RED": Color("#FF2D1A"),
		&"ACCENT_MAGENTA": Color("#C266FF"), # discordance → violet (le magenta rejoint le rouge)
		&"STATE_AMBER": Color("#E0C890"), # avertissement → sable
	},
	Mode.HIGH_CONTRAST: {
		&"STATE_RED": Color("#FF6B6B"),
		&"ACCENT_MAGENTA": Color("#FF66AE"),
		&"VOICE_BRULANTS": Color("#F08A5D"),
		&"VOICE_COMMISSION": Color("#A9B4FF"),
		&"TEXT_SECONDARY": Color("#C2CCD8"),
		&"LINE_SUBTLE": Color("#5A6780"),
	},
}

## Variantes alpha dérivées d'une couleur de base (suffixe → opacité).
const ALPHA_FAMILIES: Dictionary[StringName, Array] = {
	&"ACCENT_MAGENTA": [[&"MAGENTA_12", 0.12], [&"MAGENTA_24", 0.24], [&"MAGENTA_60", 0.60]],
	&"STATE_AMBER": [[&"AMBER_12", 0.12], [&"AMBER_24", 0.24], [&"AMBER_60", 0.60]],
	&"STATE_RED": [[&"RED_12", 0.12], [&"RED_24", 0.24], [&"RED_60", 0.60]],
	&"STATE_GREEN": [[&"GREEN_12", 0.12], [&"GREEN_24", 0.24], [&"GREEN_60", 0.60]],
	&"VOICE_COMMISSION": [[&"VOICE_COMMISSION_12", 0.12]],
	&"VOICE_BRULANTS": [[&"VOICE_BRULANTS_12", 0.12]],
}

static var mode: Mode = Mode.NONE

static var ACCENT_MAGENTA: Color = DS.ACCENT_MAGENTA
static var MAGENTA_12: Color = DS.MAGENTA_12
static var MAGENTA_24: Color = DS.MAGENTA_24
static var MAGENTA_60: Color = DS.MAGENTA_60
static var STATE_AMBER: Color = DS.STATE_AMBER
static var AMBER_12: Color = DS.AMBER_12
static var AMBER_24: Color = DS.AMBER_24
static var AMBER_60: Color = DS.AMBER_60
static var STATE_RED: Color = DS.STATE_RED
static var RED_12: Color = DS.RED_12
static var RED_24: Color = DS.RED_24
static var RED_60: Color = DS.RED_60
static var STATE_GREEN: Color = DS.STATE_GREEN
static var GREEN_12: Color = DS.GREEN_12
static var GREEN_24: Color = DS.GREEN_24
static var GREEN_60: Color = DS.GREEN_60
static var VOICE_COMMISSION: Color = DS.VOICE_COMMISSION
static var VOICE_COMMISSION_12: Color = DS.VOICE_COMMISSION_12
static var VOICE_BRULANTS: Color = DS.VOICE_BRULANTS
static var VOICE_BRULANTS_12: Color = DS.VOICE_BRULANTS_12
static var TEXT_SECONDARY: Color = DS.TEXT_SECONDARY
static var LINE_SUBTLE: Color = DS.LINE_SUBTLE

## Noms des couleurs dynamiques (dans l'ordre de déclaration).
const NAMES: Array[StringName] = [&"ACCENT_MAGENTA", &"MAGENTA_12", &"MAGENTA_24", &"MAGENTA_60", &"STATE_AMBER",
	&"AMBER_12", &"AMBER_24", &"AMBER_60", &"STATE_RED", &"RED_12", &"RED_24", &"RED_60", &"STATE_GREEN", &"GREEN_12",
	&"GREEN_24", &"GREEN_60", &"VOICE_COMMISSION", &"VOICE_COMMISSION_12", &"VOICE_BRULANTS", &"VOICE_BRULANTS_12",
	&"TEXT_SECONDARY", &"LINE_SUBTLE"]

const TOKENS: GDScript = preload("res://ui/theme/tokens.gd")


## Applique le mode `p_mode` (hors bornes : « Aucun »). Idempotent.
static func apply(p_mode: int) -> void:
	mode = p_mode as Mode if p_mode >= Mode.NONE and p_mode <= Mode.HIGH_CONTRAST else Mode.NONE
	var base: Dictionary = TOKENS.get_script_constant_map()
	var variant: Dictionary = VARIANTS.get(mode, {})
	for token: StringName in NAMES:
		_assign(token, base[String(token)])
	for token: StringName in variant:
		var color: Color = variant[token]
		_assign(token, color)
		for pair: Array in ALPHA_FAMILIES.get(token, []):
			var alpha: float = pair[1]
			_assign(pair[0], Color(color, alpha))


## Couleur d'un token nommé (`holo_tint_token` des documents, données) :
## valeur active si le token est dynamique, sinon constante de `DS`, sinon cyan.
static func token(name: StringName) -> Color:
	if NAMES.has(name):
		return get_color(name)
	var value: Variant = TOKENS.get_script_constant_map().get(String(name))
	return value if value is Color else DS.ACCENT_CYAN


## Valeur active d'un token dynamique.
static func get_color(name: StringName) -> Color:
	match name:
		&"ACCENT_MAGENTA": return ACCENT_MAGENTA
		&"MAGENTA_12": return MAGENTA_12
		&"MAGENTA_24": return MAGENTA_24
		&"MAGENTA_60": return MAGENTA_60
		&"STATE_AMBER": return STATE_AMBER
		&"AMBER_12": return AMBER_12
		&"AMBER_24": return AMBER_24
		&"AMBER_60": return AMBER_60
		&"STATE_RED": return STATE_RED
		&"RED_12": return RED_12
		&"RED_24": return RED_24
		&"RED_60": return RED_60
		&"STATE_GREEN": return STATE_GREEN
		&"GREEN_12": return GREEN_12
		&"GREEN_24": return GREEN_24
		&"GREEN_60": return GREEN_60
		&"VOICE_COMMISSION": return VOICE_COMMISSION
		&"VOICE_COMMISSION_12": return VOICE_COMMISSION_12
		&"VOICE_BRULANTS": return VOICE_BRULANTS
		&"VOICE_BRULANTS_12": return VOICE_BRULANTS_12
		&"TEXT_SECONDARY": return TEXT_SECONDARY
		&"LINE_SUBTLE": return LINE_SUBTLE
	return DS.ACCENT_CYAN


static func _assign(name: StringName, color: Color) -> void:
	match name:
		&"ACCENT_MAGENTA": ACCENT_MAGENTA = color
		&"MAGENTA_12": MAGENTA_12 = color
		&"MAGENTA_24": MAGENTA_24 = color
		&"MAGENTA_60": MAGENTA_60 = color
		&"STATE_AMBER": STATE_AMBER = color
		&"AMBER_12": AMBER_12 = color
		&"AMBER_24": AMBER_24 = color
		&"AMBER_60": AMBER_60 = color
		&"STATE_RED": STATE_RED = color
		&"RED_12": RED_12 = color
		&"RED_24": RED_24 = color
		&"RED_60": RED_60 = color
		&"STATE_GREEN": STATE_GREEN = color
		&"GREEN_12": GREEN_12 = color
		&"GREEN_24": GREEN_24 = color
		&"GREEN_60": GREEN_60 = color
		&"VOICE_COMMISSION": VOICE_COMMISSION = color
		&"VOICE_COMMISSION_12": VOICE_COMMISSION_12 = color
		&"VOICE_BRULANTS": VOICE_BRULANTS = color
		&"VOICE_BRULANTS_12": VOICE_BRULANTS_12 = color
		&"TEXT_SECONDARY": TEXT_SECONDARY = color
		&"LINE_SUBTLE": LINE_SUBTLE = color
