## Générateur du contenu de la fouille holographique (M13, docs/M13.md
## §2.4–§2.7 ; D-146, D-147 ; B69, B73) — pur, déterministe (graine du cas).
##
## Appelé par le `CaseBuilder` après l'injection, les jours où le portique est
## en service (R44 active, J8+ ; jamais pendant une coupure EV-05) :
## 1. objets planifiés par les injecteurs (`InjectionState.search_plan` :
##    contrebande, arme, implant non déclaré) dans la zone choisie, chacun avec
##    son **indice** (invariant « porteur ⇒ indice ») ; l'anomalie reçoit la
##    référence de l'objet (`FieldRef.scan`, preuve de R45 / R46 / R15) ;
## 2. implants dissimulés du passager (déclarés : OL-10) ;
## 3. part des passagers porteurs d'un implant dissimulé **déclaré** (8 %) ;
## 4. innocents : indice de bruit (`DayDef.search_cue_noise_rate`) et son
##    **explication légitime** dans la zone de l'indice ;
## 5. fouille de base : objet légitime en Z1–Z4 (p = 0,3), 1 à 3 en Z5 ;
## 6. réponse à « Quelque chose à déclarer ? » (évasive : 5 % des innocents).
## Jamais de `CaseKey` ; la carte n'est modifiée que pour déclarer un implant
## dissimulé légitime, si son champ est libre.
class_name SearchGenerator
extends RefCounted

const PERMIT_ID: StringName = &"entry_permit"
const CARD_ID: StringName = &"id_card"
## R44 « Fouille sur motif » : portique en service.
const SEARCH_RULE_ID: StringName = &"r_search_cause"
## Part des réponses « marchandise » (motif COMMERCE ou TRAVAIL).
const GOODS_RATE: float = 0.5
const SALT_PLAN: int = 1
const SALT_IMPLANT: int = 2
const SALT_NOISE: int = 3
const SALT_BASE: int = 4
const SALT_CARGO: int = 5


## Vrai si le portique est en service (R44 active dans le RuleSet).
static func search_enabled(rule_set: RuleSet) -> bool:
	return rule_set != null and rule_set.has_rule(SEARCH_RULE_ID)


## Construit `c.search_layout`, `c.search_cues`, `c.cargo_reply` /
## `c.cargo_line_key`. `card_free` : le champ « Implants déclarés » n'a été
## touché par aucun injecteur (déclarer un implant dissimulé est permis).
static func build(c: Case, truth: Passenger, catalog: SearchCatalogDef, rng: SeededRng, plan: Array[Dictionary],
		noise_rate: float, card_free: bool, day_number: int, detain: bool = true) -> void:
	if c == null or catalog == null:
		return
	var layout: SearchLayout = SearchLayout.new()
	c.search_layout = layout
	c.search_cues.clear()
	var plan_rng: SeededRng = rng.fork(SALT_PLAN)
	var carrier: bool = false
	var carrier_evasive: bool = false
	for entry: Dictionary in plan:
		var item: SearchItem = _make_planned(entry, catalog, plan_rng)
		if item == null:
			continue
		layout.add(StringName(str(entry.get("zone", SearchLayout.ZONE_LUGGAGE))), item)
		var anomaly: Anomaly = entry.get("anomaly", null)
		if anomaly != null:
			anomaly.document_id = FieldRef.SCAN_DOCUMENT_ID
			anomaly.field_id = item.id
		var cue: StringName = StringName(str(entry.get("cue", "")))
		if cue != &"" and not c.search_cues.has(cue):
			c.search_cues.append(cue)
		carrier = true
		carrier_evasive = carrier_evasive or plan_rng.chance(catalog.evasive_carrier_share)
	# Implants dissimulés déjà portés (déclarés : OL-10).
	var planned_codes: PackedStringArray = layout.implant_codes()
	for code: String in c.passenger_presented.concealed_implants:
		if planned_codes.has(code):
			continue
		_add_implant(layout, catalog, code)
	# Implant dissimulé déclaré (bruit légitime).
	var implant_rng: SeededRng = rng.fork(SALT_IMPLANT)
	if day_number >= catalog.first_day and card_free and implant_rng.chance(catalog.declared_concealed_rate):
		var codes: PackedStringArray = catalog.civil_concealed.get(c.passenger_presented.faction_id, PackedStringArray())
		if not codes.is_empty():
			declare_concealed(c, truth, catalog, codes[implant_rng.randi_range(0, codes.size() - 1)])
	# Innocent : indice de bruit et explication légitime.
	var noise_rng: SeededRng = rng.fork(SALT_NOISE)
	if not carrier and noise_rng.chance(noise_rate):
		_add_noise_cue(c, truth, catalog, noise_rng, card_free and day_number >= catalog.first_day)
	_add_base_items(c, catalog, rng.fork(SALT_BASE))
	_draw_cargo(c, rng.fork(SALT_CARGO), carrier, carrier_evasive, catalog)


## Objet planifié par un injecteur.
static func _make_planned(entry: Dictionary, catalog: SearchCatalogDef, rng: SeededRng) -> SearchItem:
	var code: String = str(entry.get("implant", ""))
	if not code.is_empty():
		var implant: SearchItem = SearchItem.implant(code)
		implant.unreadable = catalog.unreadable_implants.has(code)
		_implant_texts(implant, code)
		return implant
	var def: SearchItemDef = entry.get("item", null)
	if def == null:
		return null
	return def.instantiate(_quantity(def, rng))


static func _quantity(def: SearchItemDef, rng: SeededRng) -> int:
	if def.quantity.y <= 0:
		return 0
	return rng.randi_range(maxi(def.quantity.x, 1), maxi(def.quantity.y, def.quantity.x))


static func _add_implant(layout: SearchLayout, catalog: SearchCatalogDef, code: String) -> SearchItem:
	var zone: StringName = catalog.implant_zone(code)
	if zone == &"":
		zone = SearchLayout.ZONE_ARMS
	var item: SearchItem = SearchItem.implant(code)
	item.unreadable = catalog.unreadable_implants.has(code)
	_implant_texts(item, code)
	return layout.add(zone, item)


static func _implant_texts(item: SearchItem, code: String) -> void:
	item.name_key = "item_ol10_name"
	item.desc_key = "item_ol10_desc"
	item.args = [code]


## Implant dissimulé **déclaré** (OL-10) : porté (vérité et présenté), déclaré
## sur la carte (implants visibles ∪ dissimulés déclarés), placé dans sa zone.
static func declare_concealed(c: Case, truth: Passenger, catalog: SearchCatalogDef, code: String) -> SearchItem:
	if code.is_empty() or c.passenger_presented.concealed_implants.has(code) or c.passenger_presented.implants.has(code):
		return null
	c.passenger_presented.concealed_implants.append(code)
	if truth != null and not truth.concealed_implants.has(code):
		truth.concealed_implants.append(code)
	var card: DocumentInstance = c.get_own_document(CARD_ID)
	if card != null:
		var field: FieldDef = card.type_def.find_field_by_truth_path(&"implants")
		if field != null:
			var listed: PackedStringArray = ImplantsDeclaredRule.as_list(card.get_value(field.id)).duplicate()
			if not listed.has(code):
				listed.append(code)
			card.set_value(field.id, listed)
	return _add_implant(c.search_layout, catalog, code)


## Indice de bruit d'un innocent (IV-1 → IV-5) et son explication légitime
## dans la zone de l'indice ; un indice sans explication possible est écarté.
static func _add_noise_cue(c: Case, truth: Passenger, catalog: SearchCatalogDef, rng: SeededRng, may_declare: bool) -> void:
	var cues: Array[StringName] = SearchLayout.CUES.duplicate()
	while not cues.is_empty():
		var cue: StringName = cues[rng.randi_range(0, cues.size() - 1)]
		cues.erase(cue)
		var zone: StringName = SearchLayout.zone_of_cue(cue)
		var explanation: StringName = catalog.cue_explanations.get(cue, &"")
		var def: SearchItemDef = catalog.get_item(explanation)
		if def == null:
			continue
		if def.kind == SearchItem.Kind.IMPLANT:
			if not may_declare:
				continue
			var code: String = _concealable_code_for(catalog, c.passenger_presented, zone)
			if code.is_empty() or declare_concealed(c, truth, catalog, code) == null:
				continue
		else:
			if not def.can_be_in(zone):
				continue
			c.search_layout.add(zone, def.instantiate(_quantity(def, rng)))
		c.search_cues.append(cue)
		return


## Implant civil dissimulable d'une zone (codes de l'origine d'abord).
static func _concealable_code_for(catalog: SearchCatalogDef, p: Passenger, zone: StringName) -> String:
	var preferred: PackedStringArray = catalog.civil_concealed.get(p.faction_id, PackedStringArray())
	for code: String in preferred:
		if catalog.implant_zone(code) == zone and not p.implants.has(code) and not p.concealed_implants.has(code):
			return code
	for code: String in catalog.implant_zones:
		if catalog.implant_zone(code) == zone and catalog.undeclared_civil.has(code) and not p.implants.has(code) \
				and not p.concealed_implants.has(code):
			return code
	return ""


## Fouille de base : objets légitimes (jamais un implant, jamais une marchandise
## hors motif COMMERCE).
static func _add_base_items(c: Case, catalog: SearchCatalogDef, rng: SeededRng) -> void:
	var purpose: StringName = c.passenger_presented.purpose
	for zone: StringName in SearchLayout.ZONES:
		var count: int = 0
		if zone == SearchLayout.ZONE_LUGGAGE:
			count = rng.randi_range(catalog.baggage_items.x, catalog.baggage_items.y)
		elif rng.chance(catalog.body_item_rate):
			count = 1
		var pool: Array[SearchItemDef] = []
		for def: SearchItemDef in catalog.items_for(SearchItem.Kind.LEGIT, zone):
			if def.purpose == &"" or def.purpose == purpose:
				pool.append(def)
		for n: int in count:
			if pool.is_empty():
				break
			var def: SearchItemDef = pool[rng.randi_range(0, pool.size() - 1)]
			c.search_layout.add(zone, def.instantiate(_quantity(def, rng)))


## Réponse à « Quelque chose à déclarer ? » : évasive (IV-6) chez 5 % des
## innocents et 70 % des porteurs dont c'est l'indice principal.
static func _draw_cargo(c: Case, rng: SeededRng, carrier: bool, carrier_evasive: bool, catalog: SearchCatalogDef) -> void:
	var evasive: bool = rng.chance(catalog.evasive_carrier_rate) if carrier and carrier_evasive \
			else (not carrier and rng.chance(catalog.evasive_innocent_rate))
	if evasive:
		c.cargo_reply = Case.CARGO_EVASIVE
		c.cargo_line_key = "line_cargo_evasive_%d" % rng.randi_range(1, 5)
		return
	var purpose: StringName = c.passenger_presented.purpose
	if (purpose == Passenger.PURPOSE_TRADE or purpose == Passenger.PURPOSE_WORK) and rng.chance(GOODS_RATE):
		c.cargo_reply = Case.CARGO_GOODS
		c.cargo_line_key = "line_cargo_goods_%d" % (rng.randi_range(1, 2) if purpose == Passenger.PURPOSE_TRADE else 3)
		return
	c.cargo_reply = Case.CARGO_NONE
	var medicine: bool = false
	for item: SearchItem in c.search_layout.items:
		medicine = medicine or item.item_id == &"ol03"
	c.cargo_line_key = "line_cargo_none_%d" % (4 if medicine and rng.chance(0.5) else rng.randi_range(1, 3))


## Contenu imposé d'un cas scénarisé (`ScriptedCaseDef.search_items`).
static func build_scripted(c: Case, truth: Passenger, catalog: SearchCatalogDef, scripted: ScriptedCaseDef,
		rng: SeededRng, plan: Array[Dictionary], day_number: int) -> void:
	if scripted.search_items.is_empty():
		# Fouille générée sans indice (M13 §2.10) : objets légitimes seulement,
		# plus les objets planifiés par une anomalie imposée.
		build(c, truth, catalog, rng, plan, 0.0, false, day_number)
		if plan.is_empty():
			c.search_cues.clear()
	else:
		c.search_layout = SearchLayout.new()
		c.search_cues.clear()
		var anomalies: Array[Anomaly] = []
		for entry: Dictionary in plan:
			var anomaly: Anomaly = entry.get("anomaly", null)
			if anomaly != null:
				anomalies.append(anomaly)
		for spec: Dictionary in scripted.search_items:
			var zone: StringName = StringName(str(spec.get("zone", SearchLayout.ZONE_LUGGAGE)))
			var code: String = str(spec.get("implant", ""))
			var item: SearchItem = null
			if not code.is_empty() and bool(spec.get("declared", false)):
				# Implant dissimulé déclaré (OL-10) : la carte le liste.
				declare_concealed(c, truth, catalog, code)
				continue
			if not code.is_empty():
				if not c.passenger_presented.concealed_implants.has(code):
					c.passenger_presented.concealed_implants.append(code)
				if truth != null and not truth.concealed_implants.has(code):
					truth.concealed_implants.append(code)
				item = SearchItem.implant(code)
				item.unreadable = catalog.unreadable_implants.has(code)
				_implant_texts(item, code)
			else:
				var def: SearchItemDef = catalog.get_item(StringName(str(spec.get("item", ""))))
				if def == null:
					push_error("SearchGenerator: objet inconnu %s (%s)" % [spec, scripted.id])
					continue
				item = def.instantiate(int(spec.get("qty", 0)))
			c.search_layout.add(zone, item)
			for anomaly: Anomaly in anomalies:
				if anomaly.field_id == &"" and (item.is_forbidden() or (item.is_implant() and anomaly.type == AnomalyType.Kind.CONCEALED_IMPLANT)):
					anomaly.document_id = FieldRef.SCAN_DOCUMENT_ID
					anomaly.field_id = item.id
		_draw_cargo(c, rng.fork(SALT_CARGO), false, false, catalog)
	for cue: StringName in scripted.search_cues:
		if not c.search_cues.has(cue):
			c.search_cues.append(cue)
	if scripted.cargo_reply != &"":
		c.cargo_reply = scripted.cargo_reply
		c.cargo_line_key = "%s_cargo" % scripted.dialogue_id
