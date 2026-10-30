## Outil d'équilibrage du foyer (GDD §5.3, §5.4, §14) — headless.
##
## Simule la campagne (J1 → dernier jour des données) pour plusieurs profils de
## joueur (précision de verdict) et une politique de dépenses, sur N graines, et
## imprime par profil et par soir : revenu net, solde, postes non payés, état du
## foyer, taux de « foyer entièrement malade » et de fins anticipées.
##
## M7 : campagne J1–J10 (soirées à événements, audit, fin F1–F7) ; par profil,
## répartition des fins (et jour moyen d'une fin anticipée). `--presets=`
## liste de `SimProfile.PRESETS` (défaut : `default`, choix sans UI) ;
## `--days=N` limite la campagne aux N premiers jours.
## M8 : campagne J1–J20 (pivot du J10, quota, rations, prélèvements, Revue du
## J17, fins F1–F9 de D-078) ; profils Acte II `drift10`, `archiviste`,
## `solidaire`, `overrun`, `mercenary2` (docs/ACT2.md §6).
## M9 : campagne J1–J30 (pivot du J20, Acte III, fins F1–F10 de D-088) ;
## profils `passeur`, `temoin`, `accusateur`, `mercenary3` (docs/ACT3.md §6.5) ;
## `--climate=vanne|brulants|vitres|registre|promu|statu_quo` démarre au J21
## depuis un état synthétique de ce climat (solde selon la précision).
## M11 : `--story` joue chaque préréglage en mode Récit (D-102 : amendes à
## 0 ₵) ; équivalent à `--presets=story_<nom>` (`SimProfile.STORY_PREFIX`).
## M13 (docs/M13.md §4.3–§4.5) : `--m13=off` joue la campagne « 0.12 » (R43 →
## R47, anomalies et cas de M13, compensation de temps retirés) ;
## `--m13=compare` joue chaque graine avec et sans M13 (modèle de temps actif)
## et imprime l'écart des fins, de la file traitée, du temps par cas, des
## soldes et les achats ; `--upgrades=never|smart|eager` (politique d'achat),
## `--timed` (modèle de temps sans comparaison) ; préréglages `presse`,
## `curieux`, `zele`, `economiste`.
## M12 (docs/M12.md §6) : `--garde` joue des gardes de nuit (bots constants de
## `--profiles=`, `--decay` : bot dégressif) sur `--seeds` codes libres tirés
## de `--seed`, `--daily=N` : N graines du jour consécutives (UTC) ; médiane,
## p10, p90, directives, paliers, cas sans preuve. `--events=on|off|compare`
## (campagne) : calendrier des événements de station appliqué (B58) ;
## `compare` joue chaque graine avec et sans événements et imprime l'écart de
## répartition des fins (D-060 : ≤ 3 points) et de solde les jours
## d'événement.
##
## Usage (depuis la racine du projet) :
## `--from=K` : graines K → K + N − 1 (lots d'une même mesure).
##   godot --headless --script res://tools/balance_sim.gd -- --seeds=200 --seed=1 \
##       --profiles=0.6,0.8,0.95 --spending=reasoned|default [--set=heating=6,starting_credits=10] \
##       [--presets=default,loyal,luciole,mercenary,drift,negligent,archiviste,solidaire] [--days=30] \
##       [--climate=vanne] [--story]
## `--set` surcharge en mémoire des champs de l'`EconomyDef` (essais sans
## régénérer les données ; les valeurs retenues vont dans `build_data.gd`).
extends SceneTree

var _seeds: int = 200
var _seed: int = 1
## Finition M13 : index de la première graine (`--from=K` : graines K → K + N − 1,
## pour découper une mesure en lots de même base `--seed`).
var _from: int = 0
var _profiles: Array[float] = [0.6, 0.8, 0.95]
var _spending: BalanceSimulator.Spending = BalanceSimulator.Spending.REASONED
var _overrides: Dictionary[String, String] = {}
var _presets: Array[StringName] = [&"default"]
var _days: int = -1
## Acte III : climat d'entrée synthétique (vide : campagne depuis le J1).
var _climate: String = ""
## M11 : préréglages joués en mode Récit (`--story`).
var _story: bool = false
## M12 : gardes de nuit (`--garde`), bot dégressif (`--decay`), graines du jour (`--daily=N`).
var _garde: bool = false
var _decay: bool = false
var _daily: int = 0
## M12 : événements de station en campagne (`--events=on|off|compare`).
var _events: String = "on"
## M13 (docs/M13.md §4.5) : `--m13=on|off|compare`, `--upgrades=never|smart|eager`,
## `--timed` (modèle de temps : part de la file traitée).
var _m13: String = "on"
var _upgrades: String = ""
## Finition M13 : `--smart=marge[,dernier_soir]` (essais de la politique `smart`).
var _smart_margin: int = -1
var _smart_last_evening: int = -1
var _timed: bool = false

## État synthétique du J21 par climat : drapeaux et jauges (docs/ACT3.md §1.3).
const CLIMATES: Dictionary[String, Dictionary] = {
	"vanne": {"climate_vanne": true, "lucioles_trust": 6, "loyalty": 1, "suspicion": 2, "solidarite": 2, "registre": 1},
	"brulants": {"climate_vanne": true, "vanne2_brulants": true, "lucioles_trust": 5, "loyalty": 0, "suspicion": 3,
			"solidarite": 1, "registre": 1},
	"vitres": {"climate_vitres": true, "lucioles_trust": 3, "loyalty": 1, "suspicion": 1, "solidarite": 4, "registre": 1},
	"registre": {"climate_registre": true, "lucioles_trust": 2, "loyalty": 1, "suspicion": 1, "solidarite": 2, "registre": 3,
			"verite": 1},
	"promu": {"climate_promu": true, "lucioles_trust": -4, "loyalty": 7, "suspicion": 1, "solidarite": -2, "registre": 0},
	"statu_quo": {"climate_statu_quo": true, "lucioles_trust": 1, "loyalty": 2, "suspicion": 2, "solidarite": 1, "registre": 1},
}


func _init() -> void:
	_parse_args()
	var data: DataCatalog = DataCatalog.load_from()
	if not data.errors.is_empty():
		push_error("balance_sim: données invalides %s" % [data.errors])
		quit(1)
		return
	var e: EconomyDef = data.get_economy()
	for field: String in _overrides:
		if not field in e:
			push_error("balance_sim: champ inconnu %s" % field)
			quit(1)
			return
		var current: Variant = e.get(field)
		e.set(field, _overrides[field].to_float() if current is float else _overrides[field].to_int())
	print("balance_sim : %d graine(s), base %d, dépenses %s" % [_seeds, _seed,
			BalanceSimulator.Spending.keys()[_spending]])
	print("barème : départ %d ₵, loyer %d, air %d, nourriture %d, chauffage %d, O₂ %d, soins %d/proche ; Noa froid %.2f ; privation %d soirs ; aggravation %d soirs" % [
			e.starting_credits, e.rent, e.air_tax, e.food, e.heating, e.oxygen, e.medicine_per_member,
			e.noa_cold_sick_chance, e.deprivation_sick_evenings, e.untreated_worsen_evenings])
	var start: int = Time.get_ticks_msec()
	if _garde:
		_run_garde(data)
		print("Durée : %d ms" % (Time.get_ticks_msec() - start))
		quit(0)
		return
	if _m13 == "compare":
		if _story:
			for i: int in _presets.size():
				if not String(_presets[i]).begins_with(SimProfile.STORY_PREFIX):
					_presets[i] = StringName(SimProfile.STORY_PREFIX + String(_presets[i]))
		for preset: StringName in _presets:
			for accuracy: float in _profiles:
				_compare_m13(data, accuracy, preset)
		print("Durée : %d ms" % (Time.get_ticks_msec() - start))
		quit(0)
		return
	if _events == "compare":
		for preset: StringName in _presets:
			for accuracy: float in _profiles:
				_compare_events(data, accuracy, preset)
		print("Durée : %d ms" % (Time.get_ticks_msec() - start))
		quit(0)
		return
	if _story:
		for i: int in _presets.size():
			if not String(_presets[i]).begins_with(SimProfile.STORY_PREFIX):
				_presets[i] = StringName(SimProfile.STORY_PREFIX + String(_presets[i]))
	for preset: StringName in _presets:
		for accuracy: float in _profiles:
			_run_profile(data, accuracy, preset)
	print("Durée : %d ms" % (Time.get_ticks_msec() - start))
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = maxi(arg.trim_prefix("--seeds=").to_int(), 1)
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--from="):
			_from = maxi(arg.trim_prefix("--from=").to_int(), 0)
		elif arg.begins_with("--profiles="):
			_profiles.clear()
			for part: String in arg.trim_prefix("--profiles=").split(",", false):
				_profiles.append(clampf(part.to_float(), 0.0, 1.0))
		elif arg.begins_with("--set="):
			for pair: String in arg.trim_prefix("--set=").split(",", false):
				var kv: PackedStringArray = pair.split("=")
				if kv.size() == 2:
					_overrides[kv[0].strip_edges()] = kv[1].strip_edges()
		elif arg.begins_with("--presets="):
			_presets.clear()
			for part: String in arg.trim_prefix("--presets=").split(",", false):
				_presets.append(StringName(part.strip_edges()))
		elif arg.begins_with("--days="):
			_days = arg.trim_prefix("--days=").to_int()
		elif arg.begins_with("--climate="):
			_climate = arg.trim_prefix("--climate=")
			if not CLIMATES.has(_climate):
				push_error("balance_sim: climat inconnu %s (%s)" % [_climate, ", ".join(CLIMATES.keys())])
				_climate = ""
		elif arg == "--story":
			_story = true
		elif arg == "--garde":
			_garde = true
		elif arg == "--decay":
			_decay = true
		elif arg.begins_with("--daily="):
			_daily = maxi(arg.trim_prefix("--daily=").to_int(), 0)
		elif arg.begins_with("--events="):
			_events = arg.trim_prefix("--events=")
		elif arg.begins_with("--m13="):
			_m13 = arg.trim_prefix("--m13=")
		elif arg.begins_with("--upgrades="):
			_upgrades = arg.trim_prefix("--upgrades=")
		elif arg.begins_with("--smart="):
			var smart: PackedStringArray = arg.trim_prefix("--smart=").split(",")
			_smart_margin = smart[0].to_int()
			_smart_last_evening = smart[1].to_int() if smart.size() > 1 else -1
		elif arg == "--timed":
			_timed = true
		elif arg == "--spending=default":
			_spending = BalanceSimulator.Spending.DEFAULT


func _run_profile(data: DataCatalog, accuracy: float, preset: StringName = &"default") -> void:
	var last: int = _days if _days >= 1 else data.get_last_day_number()
	var ending_counts: Dictionary[String, int] = {}
	var ending_days: Dictionary[String, int] = {}
	# Agrégats par jour (index 0 = J1).
	var reached: Array[int] = []
	var acc: Array[float] = []
	var income: Array[int] = []
	var balance: Array[int] = []
	var sick: Array[int] = []
	var grave: Array[int] = []
	var lost: Array[int] = []
	var all_sick: Array[int] = []
	var any_sick: Array[int] = []
	var endings: Array[int] = []
	var sacrificed: Array[int] = []
	var unpaid: Array[Dictionary] = []
	for i: int in last:
		for arr: Array in [reached, income, balance, sick, grave, lost, all_sick, any_sick, endings, sacrificed]:
			arr.append(0)
		acc.append(0.0)
		var d: Dictionary[StringName, int] = {}
		for id: StringName in BalanceSimulator.TRACKED_LINES:
			d[id] = 0
		unpaid.append(d)
	var finished: int = 0
	for n: int in range(_from, _from + _seeds):
		var rows: Array[Dictionary] = []
		if _climate.is_empty():
			var profile: SimProfile = _profile(preset, accuracy)
			profile.station_events = _events == "on"
			rows = BalanceSimulator.run_campaign(data, SeededRng.mix(_seed, n), accuracy, _spending, last, profile)
		else:
			rows = BalanceSimulator.run_campaign_from(data, SeededRng.mix(_seed, n), accuracy, _spending, last,
					SimProfile.preset(preset, accuracy), _climate_start(accuracy))
		var tail: Dictionary = rows[rows.size() - 1]
		var ending_name: String = str(tail["ending"]) if str(tail["ending"]) != "" else "—"
		ending_counts[ending_name] = ending_counts.get(ending_name, 0) + 1
		ending_days[ending_name] = ending_days.get(ending_name, 0) + SaveService.as_int(tail["day"])
		for row: Dictionary in rows:
			var i: int = SaveService.as_int(row["day"]) - 1
			reached[i] += 1
			var row_accuracy: float = row["accuracy"]
			acc[i] += row_accuracy
			income[i] += SaveService.as_int(row["income"])
			balance[i] += SaveService.as_int(row["balance_after"])
			sick[i] += SaveService.as_int(row["sick"])
			grave[i] += SaveService.as_int(row["grave"])
			lost[i] += SaveService.as_int(row["lost"])
			if row["all_sick"]:
				all_sick[i] += 1
			if SaveService.as_int(row["sick"]) + SaveService.as_int(row["grave"]) + SaveService.as_int(row["lost"]) > 0:
				any_sick[i] += 1
			if row["ending"] != EveningReport.ENDING_NONE:
				endings[i] += 1
			var u: Dictionary = row["unpaid"]
			var any_unpaid: bool = false
			for id: StringName in BalanceSimulator.TRACKED_LINES:
				if SaveService.as_int(u[id]) > 0:
					unpaid[i][id] += 1
					any_unpaid = true
			if any_unpaid:
				sacrificed[i] += 1
		if SaveService.as_int(tail["day"]) == last and (rows[rows.size() - 1]["ending"] == EveningReport.ENDING_NONE or rows[rows.size() - 1].get("final", false)):
			finished += 1
	print("")
	print("== Profil %d %% · %s ==" % [roundi(accuracy * 100.0), preset])
	print("jour | précis. | revenu | solde | ≥1 poste sacrifié | impayés % (loyer/nourr./chauff./O₂/soins) | malades | graves | perdus | ≥1 malade | foyer entièrement malade | fin anticipée (cumul)")
	var cumulative: int = 0
	for i: int in last:
		var r: int = maxi(reached[i], 1)
		cumulative += endings[i]
		var parts: PackedStringArray = []
		for id: StringName in BalanceSimulator.TRACKED_LINES:
			var missed: int = SaveService.as_int(unpaid[i][id])
			parts.append("%3d" % roundi(100.0 * missed / r))
		print("J%d   | %5.1f %% | %6.1f | %5.1f | %5.1f %% | %s | %7.2f | %6.2f | %6.2f | %7.1f %% | %6.1f %% | %5.1f %%" % [
				i + 1, 100.0 * acc[i] / r, float(income[i]) / r, float(balance[i]) / r, 100.0 * sacrificed[i] / r, " / ".join(parts),
				float(sick[i]) / r, float(grave[i]) / r, float(lost[i]) / r, 100.0 * any_sick[i] / r,
				100.0 * all_sick[i] / r, 100.0 * cumulative / _seeds])
	print("campagnes menées au bout : %.1f %%" % (100.0 * finished / _seeds))
	var names: Array[String] = []
	names.assign(ending_counts.keys())
	names.sort()
	var ending_parts: PackedStringArray = []
	for ending_name: String in names:
		ending_parts.append("%s %.1f %% (J%.1f)" % [ending_name, 100.0 * ending_counts[ending_name] / _seeds,
				float(ending_days[ending_name]) / ending_counts[ending_name]])
	print("fins : " + " · ".join(ending_parts))


## Acte III : état synthétique du soir du J20 (climat `_climate`) : solde de
## docs/ACT3.md §6.3 selon la précision, drapeaux d'acte, jauges du climat.
func _climate_start(accuracy: float) -> Dictionary:
	var flags: Dictionary = {"act2_started": true, EndingService.FLAG_ACT3: true, "pivot3_done": true}
	var climate: Dictionary = CLIMATES[_climate]
	for key: String in climate:
		flags[key] = climate[key]
	var credits: int = 40 if accuracy < 0.7 else (200 if accuracy < 0.9 else 380)
	var processed: int = 300
	return {"day": 21, "credits": credits, "flags": flags, "household": Household.new(), "processed": processed,
			"correct": roundi(processed * accuracy)}



# ---------------------------------------------------------------------------
# M12 : Garde de nuit (`--garde`) et événements de station (`--events=compare`)
# ---------------------------------------------------------------------------

## Codes des gardes simulées : codes libres tirés de `--seed`, ou `--daily=N`
## graines du jour consécutives à partir du 29.10.2026 (UTC).
func _garde_codes() -> PackedStringArray:
	var codes: PackedStringArray = []
	if _daily > 0:
		var base: int = Time.get_unix_time_from_datetime_string("2026-10-29T12:00:00")
		for d: int in _daily:
			codes.append(GardeService.daily_code(base + d * 86400))
		return codes
	for n: int in range(_from, _from + _seeds):
		codes.append(GardeService.code_from_bits(SeededRng.mix(_seed, n)))
	return codes


func _run_garde(data: DataCatalog) -> void:
	var codes: PackedStringArray = _garde_codes()
	var profiles: Array[SimProfile] = []
	if _decay:
		profiles.append(SimProfile.garde_decaying())
	else:
		for accuracy: float in _profiles:
			profiles.append(SimProfile.preset(&"default", accuracy))
	print("garde : %d code(s)%s" % [codes.size(), " (graines du jour)" if _daily > 0 else ""])
	for profile: SimProfile in profiles:
		var scores: Array[int] = []
		var directives: Array[int] = []
		var paliers: Dictionary[int, int] = {}
		var events: int = 0
		var insoluble: int = 0
		var passengers: int = 0
		var exercised: int = 0
		var windows: int = 0
		for i: int in codes.size():
			var r: Dictionary = BalanceSimulator.run_garde(data, codes[i], profile, i)
			scores.append(int(r["score"]))
			directives.append(int(r["directives"]))
			paliers[int(r["palier"])] = paliers.get(int(r["palier"]), 0) + 1
			events += int(r["events"])
			insoluble += int(r["violations_without_evidence"])
			passengers += int(r["passengers"])
			var ex: Dictionary = r["exercised"]
			for k: Variant in ex:
				windows += 1
				if ex[k]:
					exercised += 1
		var label: String = "dégressif" if profile.garde_decay else "%d %%" % roundi(profile.accuracy * 100.0)
		print("== Garde · bot %s ==%s" % [label, " (cible D-136 : médiane 30 à 40)" if profile.garde_decay else ""])
		print("score : médiane %.1f · moyenne %.1f · p10 %d · p90 %d · max %d" % [_percentile(scores, 0.5), _mean(scores),
				roundi(_percentile(scores, 0.1)), roundi(_percentile(scores, 0.9)), scores.max()])
		print("directives vues : médiane %.1f · ≥ 1 : %.1f %% · ≥ 4 : %.1f %%" % [_percentile(directives, 0.5),
				100.0 * _count_at_least(directives, 1) / codes.size(), 100.0 * _count_at_least(directives, 4) / codes.size()])
		print("paliers atteints : %s · événements : %.2f par garde" % [paliers, float(events) / codes.size()])
		print("passagers : %d · cas sans preuve citable : %d · directives exercées : %d / %d" % [passengers, insoluble,
				exercised, windows])


## Campagne avec et sans événements de station sur les mêmes graines :
## répartition des fins, écart par fin (D-060 : ≤ 3 points), nombre
## d'événements par campagne, écart de solde les jours d'événement.
func _compare_events(data: DataCatalog, accuracy: float, preset: StringName) -> void:
	var last: int = _days if _days >= 1 else data.get_last_day_number()
	var with_events: Dictionary[String, int] = {}
	var without: Dictionary[String, int] = {}
	var per_campaign: Array[int] = []
	var delta_sum: float = 0.0
	var delta_days: int = 0
	var types: Dictionary[String, int] = {}
	for n: int in range(_from, _from + _seeds):
		var campaign_seed: int = SeededRng.mix(_seed, n)
		var plain_profile: SimProfile = SimProfile.preset(preset, accuracy)
		var rows_plain: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, accuracy, _spending, last,
				plain_profile)
		var event_profile: SimProfile = SimProfile.preset(preset, accuracy)
		event_profile.station_events = true
		var rows_events: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, accuracy, _spending, last,
				event_profile)
		var a: String = str(rows_plain[rows_plain.size() - 1]["ending"])
		var b: String = str(rows_events[rows_events.size() - 1]["ending"])
		without[a] = without.get(a, 0) + 1
		with_events[b] = with_events.get(b, 0) + 1
		var schedule: Dictionary = BalanceSimulator.event_schedule(data, campaign_seed)
		per_campaign.append(schedule.size())
		for day_number: Variant in schedule:
			var plan: StationEventPlan = schedule[day_number]
			types[String(plan.event.id)] = types.get(String(plan.event.id), 0) + 1
			for row: Dictionary in rows_events:
				if int(row["day"]) == int(day_number):
					for plain_row: Dictionary in rows_plain:
						if int(plain_row["day"]) == int(day_number):
							delta_sum += float(int(row["income"]) - int(plain_row["income"]))
							delta_days += 1
	print("")
	print("== Événements · profil %d %% · %s ==" % [roundi(accuracy * 100.0), preset])
	var names: Array[String] = []
	for key: String in with_events:
		if not names.has(key):
			names.append(key)
	for key: String in without:
		if not names.has(key):
			names.append(key)
	names.sort()
	var worst: float = 0.0
	var parts: PackedStringArray = []
	for ending_name: String in names:
		var p_with: float = 100.0 * with_events.get(ending_name, 0) / _seeds
		var p_without: float = 100.0 * without.get(ending_name, 0) / _seeds
		worst = maxf(worst, absf(p_with - p_without))
		parts.append("%s %.1f → %.1f" % [ending_name if ending_name != "" else "—", p_without, p_with])
	print("fins (sans → avec) : " + " · ".join(parts))
	print("écart maximal : %.1f point(s) (D-060 : ≤ 3)" % worst)
	var in_range: int = 0
	for count: int in per_campaign:
		if count >= 3 and count <= 6:
			in_range += 1
	print("événements par campagne : moyenne %.2f · 3 à 6 : %.1f %% · types %s" % [_mean(per_campaign),
			100.0 * in_range / maxi(per_campaign.size(), 1), types])
	print("revenu un jour d'événement : écart moyen %.2f ₵ (sur %d jours)" % [delta_sum / maxi(delta_days, 1), delta_days])


# ---------------------------------------------------------------------------
# M13 : `--m13=compare` (docs/M13.md §4.3–§4.5, D-151)
# ---------------------------------------------------------------------------

## Profil d'un préréglage avec les options M13 de la ligne de commande.
func _profile(preset: StringName, accuracy: float, m13: bool = true) -> SimProfile:
	var profile: SimProfile = SimProfile.preset(preset, accuracy)
	profile.m13 = m13 and _m13 != "off"
	profile.timed = _timed or _m13 == "compare"
	if not _upgrades.is_empty():
		profile.upgrade_policy = StringName(_upgrades)
	profile.smart_margin = _smart_margin
	profile.smart_last_evening = _smart_last_evening
	return profile


func _compare_m13(data: DataCatalog, accuracy: float, preset: StringName) -> void:
	var last: int = _days if _days >= 1 else data.get_last_day_number()
	var endings: Array[Dictionary] = [{}, {}]
	var share: Array[Array] = [[], []]
	var seconds: Array[float] = [0.0, 0.0]
	var processed: Array[int] = [0, 0]
	var balances: Array[Dictionary] = [{}, {}]
	var reached: Array[Dictionary] = [{}, {}]
	var sacrificed: Array[int] = [0, 0]
	var evenings: Array[int] = [0, 0]
	var bought: Dictionary[String, int] = {}
	var citations: Array[Dictionary] = [{}, {}]
	var searches: float = 0.0
	var unwarranted: float = 0.0
	var lies: float = 0.0
	var lies_seen: float = 0.0
	var asked: float = 0.0
	var day_count: int = 0
	var early_day_sum: Array[int] = [0, 0]
	var early_count: Array[int] = [0, 0]
	for i: int in last:
		share[0].append(0.0)
		share[1].append(0.0)
	for n: int in range(_from, _from + _seeds):
		var campaign_seed: int = SeededRng.mix(_seed, n)
		for arm: int in 2:
			var profile: SimProfile = _profile(preset, accuracy, arm == 1)
			profile.station_events = _events != "off"
			var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, campaign_seed, accuracy, _spending, last, profile)
			var tail: Dictionary = rows[rows.size() - 1]
			var ending: String = str(tail["ending"]) if str(tail["ending"]) != "" else "—"
			if ending == String(EndingService.F1_ARRESTED):
				# Cause de l'arrestation : audit du J9, Revue du J17, Déposition du J29, double jeu.
				var tail_flags: Dictionary = tail.get("flags", {})
				var cause: String = "jeu"
				for flag: StringName in [EndingService.FLAG_AUDIT_ARRESTED, EndingService.FLAG_REVIEW_ARRESTED,
						EndingService.FLAG_DEPOSITION_ARRESTED]:
					if tail_flags.has(flag):
						cause = String(flag)
				ending = "%s(%s)" % [ending, cause]
			endings[arm][ending] = int(endings[arm].get(ending, 0)) + 1
			if int(tail["day"]) < last and not tail.get("final", false):
				early_day_sum[arm] += int(tail["day"])
				early_count[arm] += 1
			var seen_upgrades: Dictionary[String, bool] = {}
			for row: Dictionary in rows:
				var day_index: int = int(row["day"]) - 1
				share[arm][day_index] += float(row.get("processed_share", 1.0))
				reached[arm][-(day_index + 1)] = int(reached[arm].get(-(day_index + 1), 0)) + 1
				seconds[arm] += float(row.get("m13_seconds", 0.0))
				processed[arm] += int(row.get("processed", 0))
				for checkpoint: int in [10, 20, 29]:
					if int(row["day"]) == checkpoint:
						balances[arm][checkpoint] = int(balances[arm].get(checkpoint, 0)) + int(row["balance_after"])
						reached[arm][checkpoint] = int(reached[arm].get(checkpoint, 0)) + 1
				var unpaid: Dictionary = row.get("unpaid", {})
				var any_unpaid: bool = false
				for id: Variant in unpaid:
					any_unpaid = any_unpaid or int(unpaid[id]) > 0
				if row.has("unpaid"):
					evenings[arm] += 1
					sacrificed[arm] += 1 if any_unpaid else 0
				var keys: Dictionary = row.get("citation_keys", {})
				for key: Variant in keys:
					citations[arm][str(key)] = int(citations[arm].get(str(key), 0)) + int(keys[key])
				if arm == 1:
					for upgrade: Variant in row.get("upgrades", []):
						seen_upgrades[str(upgrade)] = true
					searches += float(row.get("m13_searches", 0.0))
					unwarranted += float(row.get("m13_unwarranted", 0.0))
					lies += float(row.get("m13_lies", 0.0))
					lies_seen += float(row.get("m13_lies_seen", 0.0))
					asked += float(row.get("m13_asked", 0.0))
					day_count += 1
			for upgrade: String in seen_upgrades:
				bought[upgrade] = bought.get(upgrade, 0) + 1
	print("")
	print("== M13 · profil %d %% · %s (0.12 → 0.13, %d graines) ==" % [roundi(accuracy * 100.0), preset, _seeds])
	var names: Array[String] = []
	for arm: int in 2:
		for key: Variant in endings[arm]:
			if not names.has(str(key)):
				names.append(str(key))
	names.sort()
	var worst: float = 0.0
	var parts: PackedStringArray = []
	for ending_name: String in names:
		var before: float = 100.0 * int(endings[0].get(ending_name, 0)) / _seeds
		var after: float = 100.0 * int(endings[1].get(ending_name, 0)) / _seeds
		worst = maxf(worst, absf(after - before))
		parts.append("%s %.1f → %.1f" % [ending_name, before, after])
	print("fins : " + " · ".join(parts))
	print("écart maximal : %.1f point(s) (D-151 : ≤ 3)" % worst)
	var worst_share: float = 0.0
	var worst_day: int = 0
	var share_parts: PackedStringArray = []
	for i: int in last:
		var a: float = share[0][i] / maxi(int(reached[0].get(-(i + 1), 0)), 1)
		var b: float = share[1][i] / maxi(int(reached[1].get(-(i + 1), 0)), 1)
		if b - a < worst_share:
			worst_share = b - a
			worst_day = i + 1
		if i + 1 in [4, 5, 8, 9, 12, 13, 19, 24]:
			share_parts.append("J%d %.1f → %.1f" % [i + 1, 100.0 * a, 100.0 * b])
	print("file traitée (moyenne des jours joués, %%) : %s · pire écart %.1f point(s) au J%d (cible ≥ −3)" % [
			" · ".join(share_parts), 100.0 * worst_share, worst_day])
	print("temps par cas : %.1f s → %.1f s" % [seconds[0] / maxi(processed[0], 1), seconds[1] / maxi(processed[1], 1)])
	var balance_parts: PackedStringArray = []
	for checkpoint: int in [10, 20, 29]:
		var a_bal: float = float(balances[0].get(checkpoint, 0)) / maxi(int(reached[0].get(checkpoint, 0)), 1)
		var b_bal: float = float(balances[1].get(checkpoint, 0)) / maxi(int(reached[1].get(checkpoint, 0)), 1)
		balance_parts.append("J%d %.1f → %.1f (%+.1f)" % [checkpoint, a_bal, b_bal, b_bal - a_bal])
	print("solde du soir : " + " · ".join(balance_parts))
	print("soirs avec ≥ 1 poste sacrifié : %.1f %% → %.1f %%" % [100.0 * sacrificed[0] / maxi(evenings[0], 1),
			100.0 * sacrificed[1] / maxi(evenings[1], 1)])
	print("fin anticipée, jour moyen : %.1f → %.1f" % [float(early_day_sum[0]) / maxi(early_count[0], 1),
			float(early_day_sum[1]) / maxi(early_count[1], 1)])
	var buy_parts: PackedStringArray = []
	for upgrade_id: String in ["ag01", "ag02", "ag03", "ag04", "ag05", "ag06"]:
		buy_parts.append("%s %.0f %%" % [upgrade_id, 100.0 * bought.get(upgrade_id, 0) / _seeds])
	print("achats (part des campagnes) : " + " · ".join(buy_parts))
	print("par jour joué (0.13) : questions %.1f · fouilles %.2f (sans motif %.2f) · fausses déclarations %.2f, relevées %.0f %%" % [
			asked / maxi(day_count, 1), searches / maxi(day_count, 1), unwarranted / maxi(day_count, 1),
			lies / maxi(day_count, 1), 100.0 * lies_seen / maxf(lies, 1.0)])
	var citation_parts: PackedStringArray = []
	for key: String in ["cit_irregular_entry", "cit_undocumented_denial", "cit_unwarranted_search", "cit_search_skipped",
			"cit_interview_skipped"]:
		citation_parts.append("%s %d → %d" % [key, int(citations[0].get(key, 0)), int(citations[1].get(key, 0))])
	print("citations (total) : " + " · ".join(citation_parts))
	# Ligne brute (comptes) pour agréger des lots `--from` (finition M13).
	print("M13RAW " + JSON.stringify({"preset": String(preset), "accuracy": accuracy, "from": _from, "seeds": _seeds,
			"endings": endings, "bought": bought, "balances": balances, "reached": [reached[0].get(10, 0),
			reached[0].get(20, 0), reached[0].get(29, 0), reached[1].get(10, 0), reached[1].get(20, 0), reached[1].get(29, 0)],
			"sacrificed": sacrificed, "evenings": evenings, "share": share,
			"days_reached": [_reached_days(reached[0], last), _reached_days(reached[1], last)]}))


## Nombre de campagnes ayant joué chaque jour (clés négatives de `reached`).
static func _reached_days(reached: Dictionary, last: int) -> Array[int]:
	var result: Array[int] = []
	for i: int in last:
		result.append(int(reached.get(-(i + 1), 0)))
	return result


static func _percentile(values: Array[int], q: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var pos: float = q * (sorted.size() - 1)
	var lo: int = floori(pos)
	var hi: int = mini(lo + 1, sorted.size() - 1)
	return lerpf(float(sorted[lo]), float(sorted[hi]), pos - lo)


static func _mean(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for v: int in values:
		total += v
	return float(total) / values.size()


static func _count_at_least(values: Array[int], minimum: int) -> int:
	var count: int = 0
	for v: int in values:
		if v >= minimum:
			count += 1
	return count
