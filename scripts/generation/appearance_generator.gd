## Générateur d'apparences (ARCHITECTURE §9.3, BOOTH_SCENE §12) — pur.
##
## Instance liée à un `AppearanceCatalog` (cache des poids par slot et par
## origine ; le catalogue partagé n'est jamais modifié). Tout aléa vient d'un
## `SeededRng` fourni ou dérivé de `day_seed`.
class_name AppearanceGenerator
extends RefCounted

## Sel de la graine d'origine d'un index (`mix(mix(day_seed, i), "faction")`).
const FACTION_SALT: String = "faction"

var catalog: AppearanceCatalog = null
var _slot_ids: Array[StringName] = []
## Origine → poids cumulés des options, un `PackedFloat32Array` par slot
## (ordre du catalogue) : tirage par recherche dichotomique.
var _cumulative_cache: Dictionary[StringName, Array] = {}
## Par slot (ordre du catalogue) : option id → index (signatures entières).
var _option_index: Array[Dictionary] = []


func _init(p_catalog: AppearanceCatalog) -> void:
	catalog = p_catalog
	if catalog == null:
		push_error("AppearanceGenerator: catalogue manquant")
		return
	_slot_ids = catalog.get_slot_ids()
	for slot: AppearanceSlotDef in catalog.slots:
		var table: Dictionary = {}
		for i: int in slot.options.size():
			table[slot.options[i].id] = i
		_option_index.append(table)


## Tirage pondéré d'une apparence complète pour une origine.
func generate(rng: SeededRng, faction_id: StringName) -> PassengerAppearance:
	var app: PassengerAppearance = PassengerAppearance.new()
	var cumulative: Array = _cumulative_for(faction_id)
	for i: int in catalog.slots.size():
		var slot: AppearanceSlotDef = catalog.slots[i]
		var sums: PackedFloat32Array = cumulative[i]
		var total: float = sums[sums.size() - 1] if not sums.is_empty() else 0.0
		var index: int = -1
		if total > 0.0:
			# Premier cumul > r : les options de poids nul ne sont jamais tirées.
			index = sums.bsearch(rng.randf() * total, false)
			if index >= sums.size():
				index = sums.size() - 1
				while index > 0 and sums[index] == sums[index - 1]:
					index -= 1
		app.traits[slot.id] = slot.options[index].id if index >= 0 else &""
	app.palette_id = app.get_trait(PassengerAppearance.SLOT_PALETTE)
	app.height_step = rng.randi_range(catalog.height_step_range.x, catalog.height_step_range.y)
	app.age_band = maxi(rng.weighted_index(catalog.age_band_weights), 0)
	return app


## Option tirée pour `slot`, différente de l'option actuelle de `app`
## (inchangée s'il n'existe aucune autre option tirable).
func reroll_slot(rng: SeededRng, app: PassengerAppearance, slot_id: StringName, faction_id: StringName) -> StringName:
	var slot: AppearanceSlotDef = catalog.get_slot(slot_id)
	if slot == null:
		push_error("AppearanceGenerator.reroll_slot: slot inconnu « %s »" % slot_id)
		return app.get_trait(slot_id)
	return _pick_option(rng, slot, faction_id, app.get_trait(slot_id))


## Copie de `app` dont `count` slots comparés (`identity && visible_in_portrait`)
## changent d'option. Renvoie la copie ; `changed` reçoit les slots modifiés.
func derive_identity(rng: SeededRng, app: PassengerAppearance, count: int, faction_id: StringName,
		changed: Array[StringName]) -> PassengerAppearance:
	var result: PassengerAppearance = app.copy()
	var slots: Array = rng.shuffled(catalog.get_identity_slots())
	for slot: Variant in slots:
		if changed.size() >= count:
			break
		var slot_id: StringName = slot
		var option: StringName = reroll_slot(rng, result, slot_id, faction_id)
		if option != result.get_trait(slot_id):
			result.traits[slot_id] = option
			changed.append(slot_id)
	return result


## Origine du passager `index` d'un jour, tirée depuis `day_seed` seul.
static func roster_faction(p_day_seed: int, index: int, faction_weights: Dictionary[StringName, float]) -> StringName:
	if faction_weights.is_empty():
		push_error("AppearanceGenerator.roster_faction: aucun poids d'origine")
		return &""
	var rng: SeededRng = SeededRng.new(SeededRng.mix_string(SeededRng.mix(p_day_seed, index), FACTION_SALT))
	var ids: Array = faction_weights.keys()
	var weights: PackedFloat32Array = []
	for faction_id: Variant in ids:
		weights.append(faction_weights[faction_id])
	return StringName(str(rng.weighted_pick(ids, weights)))


## Roster du jour (§9.3) : les cas scénarisés actifs sont posés d'abord
## (origine et traits imposés), puis chaque index dans l'ordre. Un candidat est
## rejeté s'il est à moins de `min_distance` slots d'une entrée déjà posée dans
## la fenêtre `window_size` ; après `max_attempts`, repli sur le plus éloigné.
func build_day_roster(p_day_seed: int, count: int, scripted: Array[ScriptedCaseDef],
		faction_weights: Dictionary[StringName, float], today: int) -> AppearanceRoster:
	var roster: AppearanceRoster = AppearanceRoster.new()
	roster.day_seed = p_day_seed
	roster.entries.resize(count)
	var signatures: Array[PackedInt32Array] = []
	signatures.resize(count)
	var by_index: Dictionary[int, ScriptedCaseDef] = {}
	for s: ScriptedCaseDef in scripted:
		if s != null and s.at_index >= 0 and s.at_index < count:
			by_index[s.at_index] = s
	var order: Array[int] = []
	order.assign(by_index.keys())
	order.sort()
	for i: int in count:
		if not by_index.has(i):
			order.append(i)
	for i: int in order:
		var scripted_case: ScriptedCaseDef = by_index.get(i, null)
		roster.entries[i] = _draw_entry(roster, signatures, i, scripted_case, faction_weights, today)
	return roster


## Signature entière d'une apparence (index d'option par slot, −1 si inconnue) :
## la distance entre signatures est celle de `PassengerAppearance.distance()`
## sur tous les slots du catalogue, en beaucoup plus rapide.
func signature_of(app: PassengerAppearance) -> PackedInt32Array:
	var sig: PackedInt32Array = []
	sig.resize(_slot_ids.size())
	for i: int in _slot_ids.size():
		var option_index: int = _option_index[i].get(app.traits.get(_slot_ids[i], &""), -1)
		sig[i] = option_index
	return sig


func _draw_entry(roster: AppearanceRoster, signatures: Array[PackedInt32Array], index: int, scripted: ScriptedCaseDef,
		faction_weights: Dictionary[StringName, float], today: int) -> AppearanceRoster.Entry:
	var entry: AppearanceRoster.Entry = AppearanceRoster.Entry.new()
	entry.index = index
	entry.faction_id = roster_faction(roster.day_seed, index, faction_weights)
	var age_override: int = -1
	if scripted != null:
		entry.scripted_id = scripted.id
		var faction: Variant = scripted.passenger_overrides.get(&"faction_id", null)
		if faction != null:
			entry.faction_id = StringName(str(faction))
		var birth: Variant = scripted.passenger_overrides.get(&"birth_date", null)
		if birth is int:
			var birth_date: int = birth
			age_override = PassengerGenerator.age_band_for_age(GameDate.age_on(birth_date, today))
	var best: PassengerAppearance = null
	var best_signature: PackedInt32Array = []
	var best_seed: int = 0
	var best_distance: int = -2
	for attempt: int in maxi(catalog.max_attempts, 1):
		var sub_seed: int = SeededRng.mix3(roster.day_seed, index, attempt)
		var candidate: PassengerAppearance = generate(SeededRng.new(sub_seed), entry.faction_id)
		if scripted != null:
			candidate = candidate.derive(scripted.appearance_overrides)
			candidate.palette_id = candidate.get_trait(PassengerAppearance.SLOT_PALETTE)
		if age_override >= 0:
			candidate.age_band = age_override
		var signature: PackedInt32Array = signature_of(candidate)
		var distance: int = _min_window_distance(signatures, index, signature)
		if distance > best_distance:
			best = candidate
			best_signature = signature
			best_seed = sub_seed
			best_distance = distance
		if distance < 0 or distance >= catalog.min_distance:
			break
	entry.appearance = best
	signatures[index] = best_signature
	entry.appearance_seed = best_seed
	entry.min_neighbor_distance = best_distance
	entry.fallback = best_distance >= 0 and best_distance < catalog.min_distance
	return entry


## Distance minimale (tous slots) aux entrées déjà posées dans la fenêtre ; −1 si aucune.
func _min_window_distance(signatures: Array[PackedInt32Array], index: int, sig: PackedInt32Array) -> int:
	var result: int = -1
	var lo: int = maxi(index - catalog.window_size, 0)
	var hi: int = mini(index + catalog.window_size, signatures.size() - 1)
	var width: int = sig.size()
	for j: int in range(lo, hi + 1):
		var other: PackedInt32Array = signatures[j]
		if j == index or other.is_empty():
			continue
		var d: int = 0
		for k: int in width:
			if sig[k] != other[k]:
				d += 1
		if result < 0 or d < result:
			result = d
	return result


func _pick_option(rng: SeededRng, slot: AppearanceSlotDef, faction_id: StringName, exclude: StringName) -> StringName:
	var weights: PackedFloat32Array = []
	for option: AppearanceOptionDef in slot.options:
		weights.append(0.0 if option.id == exclude else option.weight_for(faction_id))
	var index: int = rng.weighted_index(weights)
	if index < 0:
		return exclude
	return slot.options[index].id


func _cumulative_for(faction_id: StringName) -> Array:
	if _cumulative_cache.has(faction_id):
		return _cumulative_cache[faction_id]
	var result: Array = []
	for slot: AppearanceSlotDef in catalog.slots:
		var sums: PackedFloat32Array = []
		var acc: float = 0.0
		for option: AppearanceOptionDef in slot.options:
			acc += maxf(option.weight_for(faction_id), 0.0)
			sums.append(acc)
		result.append(sums)
	_cumulative_cache[faction_id] = result
	return result
