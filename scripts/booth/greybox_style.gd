## Correspondance traits d'apparence → rendu **greybox** (BOOTH_SCENE §12.2, §14).
##
## Couleurs provisoires de la « palette monde » 3D (BOOTH_SCENE §5.1, DS-Proposal
## à valider Design System) et des traits (peaux, cheveux, yeux, tenues).
## Les tenues évitent les teintes sémantiques saturées (vert/rouge/ambre/cyan/
## magenta purs) ; le jaune Consortium est réservé au personnel.
## Remplacé en M6 par les références visuelles de l'`AppearanceCatalog`.
class_name GreyboxStyle
extends RefCounted

# --- Palette monde (BOOTH_SCENE §5.1) ----------------------------------------
const WORLD_KEY: Color = Color("#E8F1F5") # = DS.TEXT_PRIMARY
const WORLD_TEAL_DIM: Color = Color("#2B6E78")
const WORLD_ROSE_DIM: Color = Color("#7E3A5C")
const WORLD_STEEL: Color = Color("#3A4556")
const WORLD_RAIN: Color = Color("#4E5868") # = DS.TEXT_MUTED
const WORLD_FOG: Color = Color("#0E1118") # = DS.BG_PANEL
## Lueur jaune Consortium désaturée (débordement du pilier).
const WORLD_HALCYON_SPILL: Color = Color("#C9B85A")

# --- Traits ------------------------------------------------------------------
const SKINS: Dictionary[StringName, Color] = {
	&"skin_01": Color("#F0D2BC"), &"skin_02": Color("#DDB394"), &"skin_03": Color("#C49570"),
	&"skin_04": Color("#A4724F"), &"skin_05": Color("#85573A"), &"skin_06": Color("#68432F"),
	&"skin_07": Color("#472F23"),
	&"skin_08": Color("#9C9C99"), # gris de la poussière lunaire (Tycho, LORE §5.1)
}
const HAIR_COLORS: Array[Color] = [
	Color("#171516"), Color("#33241B"), Color("#54392A"), Color("#6B3322"), Color("#A28659"),
	Color("#B9B5AE"), # 6 naturelles (dont blanc/gris)
	Color("#2F5D63"), Color("#6A3A53"), Color("#4B4064"), Color("#3E5470"), # 4 teintures désaturées
]
const EYE_COLORS: Dictionary[StringName, Color] = {
	&"eyes_brown": Color("#4A2E1C"), &"eyes_hazel": Color("#6E5A2C"), &"eyes_green": Color("#3D6A46"),
	&"eyes_blue": Color("#3C6690"), &"eyes_grey": Color("#7B848B"), &"eyes_heterochromia": Color("#3C6690"),
}
## Œil droit de l'hétérochromie.
const HETEROCHROMIA_RIGHT: Color = Color("#4A2E1C")
## 12 palettes (haut, bas, accent), désaturées. Hex en chaînes : une constante
## `Array[PackedColorArray]` littérale est évaluée à des couleurs nulles (noir)
## par GDScript 4.7 — constaté en M6 ; conversion à la demande dans `palette()`.
const PALETTES: Array[Array] = [
	["#3B4252", "#23272F", "#8C7B5E"],
	["#5B4A3F", "#2C2622", "#9A9284"],
	["#2F4A4C", "#1E2526", "#7F9A92"],
	["#4C3A4F", "#221C25", "#8E7A8F"],
	["#6B6355", "#34312B", "#3E4C5E"],
	["#2E3A55", "#1A1F2C", "#A07E64"],
	["#55524C", "#2A2928", "#6E8571"],
	["#3F4F3A", "#20261D", "#9C8C6A"],
	["#5C3F3A", "#2B1F1D", "#7C8794"],
	["#38383D", "#1C1C1F", "#8A6F80"],
	["#4E5C66", "#262D33", "#B0A58F"],
	["#61574B", "#2F2A25", "#58707A"],
]
const INK: Color = Color("#121012")
const VISOR_GLASS: Color = Color("#0B0F16")
const HOLO_TATTOO: Color = Color("#3C8F99") # teal désaturé (projeté, non biométrique)


static func skin_color(app: PassengerAppearance) -> Color:
	return SKINS.get(app.get_trait(&"skin"), SKINS[&"skin_03"])


## `hair_<coupe>_cNN` → (coupe, couleur) ; tranche âgée : grisonnement.
static func hair_cut(app: PassengerAppearance) -> StringName:
	var parts: PackedStringArray = String(app.get_trait(PassengerAppearance.SLOT_HAIR)).split("_")
	return StringName(parts[1]) if parts.size() >= 3 else &"short"


static func hair_color(app: PassengerAppearance) -> Color:
	var parts: PackedStringArray = String(app.get_trait(PassengerAppearance.SLOT_HAIR)).split("_")
	var index: int = clampi(parts[2].trim_prefix("c").to_int() - 1, 0, HAIR_COLORS.size() - 1) if parts.size() >= 3 else 0
	var color: Color = HAIR_COLORS[index]
	return color.lerp(Color("#A9A7A3"), 0.55) if app.age_band >= 2 else color


static func eye_colors(app: PassengerAppearance) -> PackedColorArray:
	var eyes: StringName = app.get_trait(&"eyes")
	var left: Color = EYE_COLORS.get(eyes, EYE_COLORS[&"eyes_brown"])
	var right: Color = HETEROCHROMIA_RIGHT if eyes == &"eyes_heterochromia" else left
	return PackedColorArray([left, right])


static func palette(app: PassengerAppearance) -> PackedColorArray:
	var id: String = String(app.palette_id if app.palette_id != &"" else app.get_trait(PassengerAppearance.SLOT_PALETTE))
	var index: int = clampi(id.trim_prefix("palette_").to_int() - 1, 0, PALETTES.size() - 1)
	var colors: PackedColorArray = []
	for hex: String in PALETTES[index]:
		colors.append(Color(hex))
	return colors


## `face_<forme>_eN` → forme (round, square, oval, angular).
static func face_shape(app: PassengerAppearance) -> StringName:
	var parts: PackedStringArray = String(app.get_trait(&"face")).split("_")
	return StringName(parts[1]) if parts.size() >= 3 else &"oval"


static func ear_variant(app: PassengerAppearance) -> int:
	var parts: PackedStringArray = String(app.get_trait(&"face")).split("_")
	return clampi(parts[2].trim_prefix("e").to_int(), 1, 3) if parts.size() >= 3 else 1


## `nose_mouth_nN_lM` → (nez 1–3, lèvres 1–2).
static func nose_variant(app: PassengerAppearance) -> int:
	var parts: PackedStringArray = String(app.get_trait(&"nose_mouth")).split("_")
	return clampi(parts[2].trim_prefix("n").to_int(), 1, 3) if parts.size() >= 4 else 2


static func lip_variant(app: PassengerAppearance) -> int:
	var parts: PackedStringArray = String(app.get_trait(&"nose_mouth")).split("_")
	return clampi(parts[3].trim_prefix("l").to_int(), 1, 2) if parts.size() >= 4 else 1


static func outfit_index(app: PassengerAppearance) -> int:
	return clampi(String(app.get_trait(&"outfit")).trim_prefix("outfit_").to_int() - 1, 0, 7)


## Échelles du torse (largeur, hauteur, profondeur) par silhouette.
static func silhouette_scale(app: PassengerAppearance) -> Vector3:
	match app.get_trait(&"silhouette"):
		&"silhouette_s1_stocky":
			return Vector3(1.22, 0.97, 1.18)
		&"silhouette_s2_slender":
			return Vector3(0.84, 1.04, 0.88)
		&"silhouette_s4_slight":
			return Vector3(0.88, 0.95, 0.9)
	return Vector3.ONE


## ±3 % d'échelle par pas de taille (BOOTH_SCENE §12.2).
static func height_scale(app: PassengerAppearance) -> float:
	return 1.0 + 0.03 * app.height_step
