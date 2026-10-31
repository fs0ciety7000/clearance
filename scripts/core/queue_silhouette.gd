## Silhouette d'un vrai passager à venir dans la file du Hall (M14 VH-1, B86,
## D-187 ; ARCHITECTURE §12 ter.4).
##
## **Aucune information de jeu** : seuls la teinte de la tenue (index de
## palette), la forme de la coiffe (tête nue, capuche, casquette) et le pas de
## taille sont exposés. Ni visage, ni accessoire, ni implant, ni bagage, ni
## anomalie, ni document, ni origine, ni verdict. La source est l'entrée du
## roster d'apparences du jour (`AppearanceRoster`, calculé au matin depuis la
## seule graine du jour, **avant** toute injection d'anomalie) : une silhouette
## ne dépend jamais de `CaseKey`.
##
## Une visière baissée et une capuche donnent la même forme (`hood`) : la
## silhouette ne trahit pas un visage masqué avant la vitre.
##
## Émise par le `DayController` (lot F) dans `EventBus.queue_progressed`, lue
## par `QueueImpostors` (lot C, teinte : `GreyboxStyle.PALETTES[palette_index][0]`
## désaturée et mêlée au remplissage sombre), l'`AudioDirector` (murmure ∝
## file, lot B) et la musique (P1, lot B).
class_name QueueSilhouette
extends RefCounted

## Formes de coiffe (un maillage chacune, `imp_silhouette_<forme>.res`, lot C).
const SHAPE_BARE: StringName = &"bare"
const SHAPE_HOOD: StringName = &"hood"
const SHAPE_CAP: StringName = &"cap"
const SHAPES: Array[StringName] = [SHAPE_BARE, SHAPE_HOOD, SHAPE_CAP]
## Coiffe (`PassengerAppearance.SLOT_HEADWEAR`) → forme. Toute autre coiffe
## (dont `none`, `beanie`) : tête nue.
const SHAPE_OF_HEADWEAR: Dictionary[StringName, StringName] = {
	&"hood": SHAPE_HOOD,
	&"visor_down": SHAPE_HOOD,
	&"visor_up": SHAPE_HOOD,
	&"cap": SHAPE_CAP,
}
## Nombre de palettes de tenue (`GreyboxStyle.PALETTES`, 12).
const PALETTE_COUNT: int = 12
## Taille des listes `upcoming` : tête de file + 6 places + 3 de débordement
## (EV-06, VH-3).
const MAX_UPCOMING: int = 10
## Seuls champs publics (contrôlé par `tests/unit/test_m14_queue.gd`).
const FIELDS: PackedStringArray = ["index", "palette_index", "shape", "height_step"]

## Index du passager dans la journée (ordre de passage).
var index: int = 0
## Palette de la tenue, 0 → `PALETTE_COUNT − 1` (couleur principale = teinte).
var palette_index: int = 0
## `SHAPE_BARE`, `SHAPE_HOOD` ou `SHAPE_CAP`.
var shape: StringName = SHAPE_BARE
## Taille quantifiée −2 → +2 (`PassengerAppearance.height_step`).
var height_step: int = 0


static func make(p_index: int, p_palette_index: int, p_shape: StringName, p_height_step: int) -> QueueSilhouette:
	var s: QueueSilhouette = QueueSilhouette.new()
	s.index = p_index
	s.palette_index = clampi(p_palette_index, 0, PALETTE_COUNT - 1)
	s.shape = p_shape if SHAPES.has(p_shape) else SHAPE_BARE
	s.height_step = clampi(p_height_step, -2, 2)
	return s


## Silhouette d'une apparence (null → silhouette neutre).
static func from_appearance(p_index: int, app: PassengerAppearance) -> QueueSilhouette:
	if app == null:
		return make(p_index, 0, SHAPE_BARE, 0)
	return make(p_index, palette_index_of(app), shape_of(app), app.height_step)


## Forme de coiffe d'une apparence.
static func shape_of(app: PassengerAppearance) -> StringName:
	if app == null:
		return SHAPE_BARE
	return SHAPE_OF_HEADWEAR.get(app.get_trait(PassengerAppearance.SLOT_HEADWEAR), SHAPE_BARE)


## Index de palette (`palette_07` → 6), comme `GreyboxStyle.palette()`.
static func palette_index_of(app: PassengerAppearance) -> int:
	var id: String = String(app.palette_id if app.palette_id != &"" else app.get_trait(PassengerAppearance.SLOT_PALETTE))
	return clampi(id.trim_prefix("palette_").to_int() - 1, 0, PALETTE_COUNT - 1)


## Passagers à venir à partir de l'index `next_index` (le prochain appelé à la
## vitre, ou celui qui y est déjà), au plus `limit`, sans dépasser `total`
## (`total < 0` : Garde, file sans fin, bornée par le roster). Le roster est lu,
## jamais modifié (l'étendre reste l'affaire du `CaseBuilder`).
static func upcoming(roster: AppearanceRoster, next_index: int, total: int, limit: int = MAX_UPCOMING) -> Array[QueueSilhouette]:
	var result: Array[QueueSilhouette] = []
	if roster == null:
		return result
	var end: int = roster.size() if total < 0 else mini(total, roster.size())
	var first: int = maxi(next_index, 0)
	for i: int in range(first, mini(end, first + maxi(limit, 0))):
		var entry: AppearanceRoster.Entry = roster.entries[i]
		result.append(from_appearance(i, entry.appearance if entry != null else null))
	return result


## Nombre de silhouettes visibles dans le zigzag (VH-2) : `min(restants − 1,
## places)`, la tête de file étant à la vitre (`restants` = passagers non
## traités, celui de la vitre compris).
static func visible_count(processed: int, total: int, places: int) -> int:
	if total < 0:
		return maxi(places, 0)
	return clampi(total - processed - 1, 0, maxi(places, 0))


func serialize() -> Dictionary:
	return {"index": index, "palette_index": palette_index, "shape": String(shape), "height_step": height_step}


func equals(other: QueueSilhouette) -> bool:
	return other != null and serialize() == other.serialize()
