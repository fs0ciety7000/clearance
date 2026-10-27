## Comparateur de visages (ARCHITECTURE §6) — pur.
##
## Renvoie les slots **d'identité visibles en portrait** qui diffèrent. Les
## slots changeables (coiffe, coiffure, tenue, accessoires) sont ignorés, et
## `age_band` est toléré à ±1 (bruit légitime). Au-delà, `&"age_band"` figure
## dans le résultat. Discordance ⇔ résultat non vide.
## M2 : les slots comparés sont une liste par défaut ; en M3, ils seront
## dérivés de l'`AppearanceCatalog` (`identity && visible_in_portrait`) et
## injectés via `RuleContext.identity_slots`.
class_name FaceComparator
extends RefCounted

const DEFAULT_IDENTITY_SLOTS: Array[StringName] = [&"face", &"eyes", &"nose_mouth", &"skin"]
const AGE_BAND_SLOT: StringName = &"age_band"
const AGE_BAND_TOLERANCE: int = 1


static func compare(a: PassengerAppearance, b: PassengerAppearance,
		slots: Array[StringName] = DEFAULT_IDENTITY_SLOTS) -> Array[StringName]:
	var differing: Array[StringName] = []
	if a == null or b == null:
		push_error("FaceComparator.compare: apparence manquante")
		return differing
	for slot: StringName in slots:
		if a.get_trait(slot) != b.get_trait(slot):
			differing.append(slot)
	if absi(a.age_band - b.age_band) > AGE_BAND_TOLERANCE:
		differing.append(AGE_BAND_SLOT)
	return differing
