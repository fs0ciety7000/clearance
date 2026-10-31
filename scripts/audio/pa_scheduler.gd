## Annonces d'ambiance de la station (M14 §4.4, VH-6, D-189 ; B85) —
## ordonnanceur **pur** (`RefCounted`, aucun nœud) nourri par l'`AudioDirector`.
##
## Règles : aucune information de jeu (les textes `pa_*` du lot E ne citent ni
## règle, ni seuil, ni document, ni passager) ; première annonce 45–75 s après
## l'ouverture du guichet, puis toutes les 90–180 s, 6 au plus par shift
## (Garde : 120–200 s, sans plafond) ; une annonce est **repoussée** de 10 s
## (3 fois au plus, puis abandonnée) si un bark est en cours ou date de moins
## de 4 s, si une annonce de jeu ou d'événement a eu lieu dans les 25 s, si le
## chrono est à moins de 30 s de la fin, ou pendant une coupure (EV-05).
## Tirage : pool pondéré selon l'acte, le jour, l'événement actif, le monde du
## J31 ou la Garde ; pas de répétition dans la journée ; pas de reprise des
## 3 dernières lignes de la veille (ordre déterministe de la veille). Tout est
## tiré de la graine (campagne, jour) : mêmes annonces à chaque rechargement.
##
## Lignes, conditions et poids : données du lot E/F (`data/audio/pa_lines.tres`,
## `PaLineTable` : pseudo-drapeaux `pa_act`, `pa_day`, `pa_event_<ev>`,
## `pa_world_<x>`, `pa_garde` ; poids 1 / 2 / 4) ; textes lus dans `fr.csv` par
## `UiText`. Une clé absente de la traduction est ignorée (`available`). Sans
## données : aucune annonce.
class_name PaScheduler
extends RefCounted

const FIRST_MIN_SEC: float = 45.0
const FIRST_MAX_SEC: float = 75.0
const GAP_MIN_SEC: float = 90.0
const GAP_MAX_SEC: float = 180.0
const GARDE_GAP_MIN_SEC: float = 120.0
const GARDE_GAP_MAX_SEC: float = 200.0
const MAX_PER_SHIFT: int = 6
const RETRY_SEC: float = 10.0
const MAX_RETRIES: int = 3
const BARK_GUARD_SEC: float = 4.0
const GAME_GUARD_SEC: float = 25.0
const END_GUARD_SEC: float = 30.0
## Lignes de la veille à ne pas reprendre.
const YESTERDAY_EXCLUDED: int = 3
## Poids : ligne générale, ligne datée (jours), ligne d'événement actif.
const WEIGHT_GENERAL: float = 1.0
const WEIGHT_DATED: float = 2.0
const WEIGHT_EVENT: float = 4.0
## Préfixe des clés.
const KEY_PREFIX: String = "pa_"

var day_number: int = 1
var garde: bool = false
## Monde du J31 (`a` … `d`), vide sinon.
var world: StringName = &""
## Clés disponibles (traduites) : `Callable(key: String) -> bool`.
var available: Callable = Callable()
## Table des annonces (`PaLineTable`, typée `Resource` : lue par méthodes).
var table: Resource = null
## Annonces jouées aujourd'hui (ordre) et clés exclues (veille).
var played: Array[String] = []
var excluded: Array[String] = []
## Secondes avant la prochaine annonce ; reports faits pour celle-ci.
var next_in: float = 0.0
var retries: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Prépare la journée : graine (campagne ou Garde), jour, mode, monde.
func setup(campaign_seed: int, p_day: int, p_garde: bool = false, p_world: StringName = &"",
		p_available: Callable = Callable(), p_table: Resource = null) -> void:
	table = p_table if p_table != null else load_table()
	day_number = p_day
	garde = p_garde
	world = p_world
	available = p_available
	played.clear()
	retries = 0
	_rng.seed = day_seed(campaign_seed, p_day, p_garde, p_world)
	excluded.clear()
	if not p_garde and p_world == &"" and p_day > 1:
		var yesterday: Array[String] = order_for(campaign_seed, p_day - 1, &"", p_available, table)
		for i: int in range(maxi(mini(yesterday.size(), MAX_PER_SHIFT) - YESTERDAY_EXCLUDED, 0),
				mini(yesterday.size(), MAX_PER_SHIFT)):
			excluded.append(yesterday[i])
	next_in = _rng.randf_range(FIRST_MIN_SEC, FIRST_MAX_SEC)


static func day_seed(campaign_seed: int, p_day: int, p_garde: bool = false, p_world: StringName = &"") -> int:
	return SeededRng.mix(SeededRng.mix(campaign_seed, SeededRng.hash_string("pa/%s/%s" % [p_garde, p_world])), p_day)


## Table des données (`data/audio/pa_lines.tres`), null si absente.
static func load_table() -> Resource:
	const PATH: String = "res://data/audio/pa_lines.tres"
	return load(PATH) if ResourceLoader.exists(PATH) else null


## Acte d'un jour de campagne (J1–J10 : 1, J11–J20 : 2, J21–J30 : 3) ; 0 au
## J31 et en Garde (pseudo-jauge `pa_act` des données).
static func act_of(p_day: int, p_garde: bool = false, p_world: StringName = &"") -> int:
	if p_garde or p_world != &"" or p_day > 30:
		return 0
	return 1 if p_day <= 10 else (2 if p_day <= 20 else 3)


## Contexte de tirage (pseudo-drapeaux de `PaLineTable.context`).
static func context_for(p_day: int, p_garde: bool, p_world: StringName, event_id: StringName) -> Dictionary[StringName, Variant]:
	var ctx: Dictionary[StringName, Variant] = {&"pa_act": act_of(p_day, p_garde, p_world), &"pa_day": 0 if p_garde else p_day}
	if event_id != &"":
		ctx[StringName("pa_event_" + String(event_id))] = true
	if p_world != &"":
		ctx[StringName("pa_world_" + String(p_world))] = true
	if p_garde:
		ctx[&"pa_garde"] = true
	return ctx


## Pool pondéré du contexte : [[clé, poids], …] (ordre des données).
static func pool_for(p_day: int, p_garde: bool, p_world: StringName, event_id: StringName,
		p_available: Callable = Callable(), p_table: Resource = null) -> Array[Array]:
	var out: Array[Array] = []
	var source: Resource = p_table if p_table != null else load_table()
	if source == null:
		return out
	var lines: Array = source.call(&"eligible", context_for(p_day, p_garde, p_world, event_id))
	for line: Variant in lines:
		var def: HallAnnouncementDef = line as HallAnnouncementDef
		if def == null:
			continue
		if p_available.is_valid() and not bool(p_available.call(def.text_key)):
			continue
		out.append([def.text_key, float(source.call(&"weight_of", def))])
	return out


## Ordre déterministe des lignes d'un jour sans événement (tirage pondéré sans
## remise) : sert à exclure les dernières lignes de la veille.
static func order_for(campaign_seed: int, p_day: int, p_world: StringName = &"",
		p_available: Callable = Callable(), p_table: Resource = null) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeededRng.mix(day_seed(campaign_seed, p_day, false, p_world), 0x0A11)
	var pool: Array[Array] = pool_for(p_day, false, p_world, &"", p_available, p_table)
	var out: Array[String] = []
	while not pool.is_empty():
		var k: int = _weighted(pool, rng)
		out.append(pool[k][0])
		pool.remove_at(k)
	return out


static func _weighted(pool: Array[Array], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for entry: Array in pool:
		total += float(entry[1])
	var roll: float = rng.randf() * total
	for k: int in pool.size():
		roll -= float(pool[k][1])
		if roll < 0.0:
			return k
	return pool.size() - 1


## Avance de `dt` secondes de shift ; renvoie la clé à annoncer maintenant,
## ou "" (rien, report, abandon). `ctx` : `bark_active`, `since_bark` (s),
## `since_game_announce` (s), `remaining_sec` (INF sans chrono),
## `power_down`, `event_id`.
func tick(dt: float, ctx: Dictionary) -> String:
	if not garde and played.size() >= MAX_PER_SHIFT:
		return ""
	next_in -= dt
	if next_in > 0.0:
		return ""
	if blocked(ctx):
		if retries >= MAX_RETRIES:
			retries = 0
			next_in = _gap() # abandonnée : la suivante plus tard
		else:
			retries += 1
			next_in = RETRY_SEC
		return ""
	var key: String = pick(StringName(str(ctx.get("event_id", ""))))
	retries = 0
	next_in = _gap()
	if not key.is_empty():
		played.append(key)
	return key


## Vrai si une exclusion de M14 §4.4 s'applique maintenant.
static func blocked(ctx: Dictionary) -> bool:
	if bool(ctx.get("bark_active", false)) or float(ctx.get("since_bark", INF)) < BARK_GUARD_SEC:
		return true
	if float(ctx.get("since_game_announce", INF)) < GAME_GUARD_SEC:
		return true
	if float(ctx.get("remaining_sec", INF)) < END_GUARD_SEC:
		return true
	return bool(ctx.get("power_down", false))


## Ligne tirée (pondérée, sans répétition, hors exclusions de la veille).
func pick(event_id: StringName = &"") -> String:
	var pool: Array[Array] = []
	for entry: Array in pool_for(day_number, garde, world, event_id, available, table):
		var key: String = entry[0]
		if played.has(key) or excluded.has(key):
			continue
		pool.append(entry)
	if pool.is_empty() and garde and not played.is_empty():
		# Garde (sans plafond) : le pool épuisé repart, sans reprendre la dernière.
		var last: String = played[-1]
		played.clear()
		for entry: Array in pool_for(day_number, garde, world, event_id, available, table):
			if entry[0] != last:
				pool.append(entry)
	if pool.is_empty():
		return ""
	return pool[_weighted(pool, _rng)][0]


func _gap() -> float:
	return _rng.randf_range(GARDE_GAP_MIN_SEC, GARDE_GAP_MAX_SEC) if garde else _rng.randf_range(GAP_MIN_SEC, GAP_MAX_SEC)


## Durée du sous-titre : `max(audio + 0,8 s ; 0,06 s × caractères ; 2,5 s)`.
static func subtitle_seconds(audio_sec: float, text: String) -> float:
	return maxf(maxf(audio_sec + 0.8, 0.06 * text.length()), 2.5)


# ---------------------------------------------------------------------------
# Rendu (fonction pure, appelée dans un thread de travail : QA-030)
# ---------------------------------------------------------------------------

const RATE: int = 16000
## Notes des jingles (Hz) : MO-1 (mi–do–sol), MO-1 adouci (monde B), MO-2
## (les trois tapes et le point, monde D).
const MO1_HZ: Array[float] = [659.26, 523.25, 783.99]
const MO1_MAJOR_HZ: Array[float] = [1108.73, 880.0, 1318.51]
const MO2_HZ: Array[float] = [440.0, 440.0, 440.0, 659.26]


## Jingle d'une annonce (mono, `RATE`) : MO-1 à la cloche ; monde B : MO-1
## adouci (sinus, majeur) ; monde A : MO-1 puis un bip de borne ; monde D :
## MO-2 au pincé (les trois tapes).
static func jingle(p_world: StringName) -> PackedFloat32Array:
	var beat: float = 0.3
	var out: PackedFloat32Array = AudioDsp.silence(AudioDsp.samples(1.6, RATE))
	if p_world == &"d":
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 0xD5
		for i: int in MO2_HZ.size():
			var at: float = [0.0, 0.15, 0.3, 0.52][i]
			var n: PackedFloat32Array = AudioDsp.karplus(AudioDsp.samples(0.6, RATE), MO2_HZ[i], RATE, rng, 0.006, 0.45)
			out = AudioDsp.mix_into(out, n, AudioDsp.samples(at, RATE), 0.5)
		return out
	var notes: Array[float] = MO1_MAJOR_HZ if p_world == &"b" else MO1_HZ
	for i: int in notes.size():
		var n: PackedFloat32Array
		if p_world == &"b":
			n = AudioDsp.sine(AudioDsp.samples(0.9, RATE), notes[i], RATE)
			n = AudioDsp.mul(n, AudioDsp.env_ad(n.size(), 0.01, 0.35, RATE))
		else:
			n = AudioDsp.fm2(AudioDsp.samples(0.9, RATE), notes[i], 3.5, 1.0, 0.2, RATE)
			n = AudioDsp.mul(n, AudioDsp.env_ad(n.size(), 0.002, 0.4, RATE))
		out = AudioDsp.mix_into(out, n, AudioDsp.samples(beat * i, RATE), 0.35)
	if p_world == &"a":
		var beep: PackedFloat32Array = AudioDsp.blep_pulse(AudioDsp.samples(0.12, RATE), 1760.0, RATE, 0.5)
		beep = AudioDsp.fade(beep, 0.003, 0.02, RATE)
		out = AudioDsp.mix_into(out, beep, AudioDsp.samples(1.1, RATE), 0.12)
	return out


## Annonce complète (mono, `RATE`) : jingle, puis la voix Tessar en haut-parleur
## (passe-bande 1,5 kHz, saturation, espace « Hall »).
static func render(phrase: String, profile: TessarVoice.Profile, p_world: StringName) -> PackedFloat32Array:
	var voice: PackedFloat32Array = TessarVoice.synthesize(phrase, profile, TessarVoice.MOOD_PA)
	voice = AudioDsp.filter(voice, AudioDsp.Filter.BANDPASS, 1500.0, 0.6, RATE)
	voice = AudioDsp.saturate(voice, 2.0)
	var buf: PackedFloat32Array = jingle(p_world)
	buf = AudioDsp.mix_into(buf, voice, AudioDsp.samples(1.3, RATE), 0.8)
	buf = AudioDsp.space(buf, RATE, 0.5, 2.2)
	var peak: float = AudioDsp.peak(buf)
	return AudioDsp.gain(buf, 0.7 / peak) if peak > 0.0 else buf
