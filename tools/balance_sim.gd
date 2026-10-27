## Outil d'équilibrage du foyer (GDD §5.3, §5.4, §14) — headless.
##
## Simule la campagne (J1 → dernier jour des données) pour plusieurs profils de
## joueur (précision de verdict) et une politique de dépenses, sur N graines, et
## imprime par profil et par soir : revenu net, solde, postes non payés, état du
## foyer, taux de « foyer entièrement malade » et de fins anticipées.
##
## Usage (depuis la racine du projet) :
##   godot --headless --script res://tools/balance_sim.gd -- --seeds=200 --seed=1 \
##       --profiles=0.6,0.8,0.95 --spending=reasoned|default [--set=heating=6,starting_credits=10]
## `--set` surcharge en mémoire des champs de l'`EconomyDef` (essais sans
## régénérer les données ; les valeurs retenues vont dans `build_data.gd`).
extends SceneTree

var _seeds: int = 200
var _seed: int = 1
var _profiles: Array[float] = [0.6, 0.8, 0.95]
var _spending: BalanceSimulator.Spending = BalanceSimulator.Spending.REASONED
var _overrides: Dictionary[String, String] = {}


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
	for accuracy: float in _profiles:
		_run_profile(data, accuracy)
	print("Durée : %d ms" % (Time.get_ticks_msec() - start))
	quit(0)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			_seeds = maxi(arg.trim_prefix("--seeds=").to_int(), 1)
		elif arg.begins_with("--seed="):
			_seed = arg.trim_prefix("--seed=").to_int()
		elif arg.begins_with("--profiles="):
			_profiles.clear()
			for part: String in arg.trim_prefix("--profiles=").split(",", false):
				_profiles.append(clampf(part.to_float(), 0.0, 1.0))
		elif arg.begins_with("--set="):
			for pair: String in arg.trim_prefix("--set=").split(",", false):
				var kv: PackedStringArray = pair.split("=")
				if kv.size() == 2:
					_overrides[kv[0].strip_edges()] = kv[1].strip_edges()
		elif arg == "--spending=default":
			_spending = BalanceSimulator.Spending.DEFAULT


func _run_profile(data: DataCatalog, accuracy: float) -> void:
	var last: int = data.get_last_day_number()
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
	for n: int in _seeds:
		var rows: Array[Dictionary] = BalanceSimulator.run_campaign(data, SeededRng.mix(_seed, n), accuracy, _spending)
		for row: Dictionary in rows:
			var i: int = int(row["day"]) - 1
			reached[i] += 1
			acc[i] += float(row["accuracy"])
			income[i] += int(row["income"])
			balance[i] += int(row["balance_after"])
			sick[i] += int(row["sick"])
			grave[i] += int(row["grave"])
			lost[i] += int(row["lost"])
			if row["all_sick"]:
				all_sick[i] += 1
			if int(row["sick"]) + int(row["grave"]) + int(row["lost"]) > 0:
				any_sick[i] += 1
			if row["ending"] != EveningReport.ENDING_NONE:
				endings[i] += 1
			var u: Dictionary = row["unpaid"]
			var any_unpaid: bool = false
			for id: StringName in BalanceSimulator.TRACKED_LINES:
				if int(u[id]) > 0:
					unpaid[i][id] += 1
					any_unpaid = true
			if any_unpaid:
				sacrificed[i] += 1
		if rows.size() == last and rows[rows.size() - 1]["ending"] == EveningReport.ENDING_NONE:
			finished += 1
	print("")
	print("== Profil %d %% ==" % roundi(accuracy * 100.0))
	print("jour | précis. | revenu | solde | ≥1 poste sacrifié | impayés % (loyer/nourr./chauff./O₂/soins) | malades | graves | perdus | ≥1 malade | foyer entièrement malade | fin anticipée (cumul)")
	var cumulative: int = 0
	for i: int in last:
		var r: int = maxi(reached[i], 1)
		cumulative += endings[i]
		var parts: PackedStringArray = []
		for id: StringName in BalanceSimulator.TRACKED_LINES:
			parts.append("%3d" % roundi(100.0 * unpaid[i][id] / r))
		print("J%d   | %5.1f %% | %6.1f | %5.1f | %5.1f %% | %s | %7.2f | %6.2f | %6.2f | %7.1f %% | %6.1f %% | %5.1f %%" % [
				i + 1, 100.0 * acc[i] / r, float(income[i]) / r, float(balance[i]) / r, 100.0 * sacrificed[i] / r, " / ".join(parts),
				float(sick[i]) / r, float(grave[i]) / r, float(lost[i]) / r, 100.0 * any_sick[i] / r,
				100.0 * all_sick[i] / r, 100.0 * cumulative / _seeds])
	print("campagnes menées au bout : %.1f %%" % (100.0 * finished / _seeds))
