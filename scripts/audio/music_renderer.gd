## Rendu hors ligne d'une partition musicale (M14, B79/B80 ; docs/AUDIO.md
## §13.4, docs/M14.md §2.8) : séquenceur, instruments paramétrés et mixage
## par couche, sur les briques pures d'`AudioDsp`.
##
## Partition = `Dictionary` lu d'un JSON d'`art_src/music/` (format :
## docs/AUDIO.md §13.4). Déterministe : graines dérivées de `seed`, de l'id de
## la couche, de la piste et de l'index de la note ; aucun ordre de
## dictionnaire non trié n'influe sur le résultat (les pistes et événements
## sont des tableaux).
##
## Une couche (`render_stem`) est rendue sur `bars + tail_bars` mesures puis
## la queue (réverbération, relâchements) est **repliée** sur le début : le
## fichier fait exactement `bars × bar_samples` échantillons et boucle sans
## clic. La même réverbération (linéaire) est appliquée à chaque couche : la
## somme des couches = le mixage complet.
class_name MusicRenderer
extends RefCounted

const NOTE_NAMES: Dictionary[String, int] = {
	"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
	"G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11,
}
const STEPS_PER_BEAT: int = 4

var score: Dictionary = {}
var id: String = ""
var rate: int = 32000
var tempo: float = 80.0
var beats_per_bar: int = 4
var bars: int = 16
var tail_bars: int = 2
var seed: int = 0
## Échantillons par mesure et par double croche (entiers exacts).
var bar_n: int = 0
var step_n: int = 0
## Erreurs de partition (vide = valide).
var errors: PackedStringArray = []
## Variante rendue (thèmes, docs/AUDIO.md §13.4) : une piste marquée
## `"variant": "x"` (ou une liste) ne sonne que dans la variante `x` ; une
## piste marquée `"not_variant": ["x"]` est retirée de la variante `x`.
## Vide = le thème de base.
var variant: String = ""

var _chords: Array = []
var _motifs: Dictionary = {}
var _instruments: Dictionary = {}


func _init(score_dict: Dictionary) -> void:
	score = score_dict
	id = str(score.get("id", ""))
	rate = int(score.get("sample_rate", 32000))
	tempo = float(score.get("tempo", 80.0))
	beats_per_bar = int(score.get("beats_per_bar", 4))
	bars = int(score.get("bars", 16))
	tail_bars = int(score.get("tail_bars", 2))
	seed = int(score.get("seed", 1))
	_chords = score.get("chords", [])
	_motifs = score.get("motifs", {})
	_instruments = score.get("instruments", {})
	var step_exact: float = rate * 60.0 / tempo / STEPS_PER_BEAT
	step_n = roundi(step_exact)
	bar_n = step_n * STEPS_PER_BEAT * beats_per_bar
	if absf(step_exact - step_n) > 0.0001:
		errors.append("%s : une double croche à %.1f BPM ne tombe pas sur un nombre entier d'échantillons à %d Hz" % [
			id, tempo, rate])
	if id.is_empty():
		errors.append("partition sans id")


## Échantillons exacts d'une mesure (0 si le tempo ne tombe pas juste).
static func exact_bar_samples(bpm: float, beats: int, sample_rate: int) -> int:
	var step: float = sample_rate * 60.0 / bpm / STEPS_PER_BEAT
	if absf(step - roundf(step)) > 0.0001:
		return 0
	return roundi(step) * STEPS_PER_BEAT * beats


## Ids des couches (ordre de la partition).
func stem_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for stem: Dictionary in score.get("stems", []):
		out.append(str(stem.get("id", "")))
	return out


## Note (« A2 », « F#3 », « Eb5 ») → numéro MIDI ; −1 si illisible.
static func note_to_midi(note: String) -> int:
	var n: String = note.strip_edges()
	if n.length() < 2:
		return -1
	var name: String = n.substr(0, 2) if n.length() >= 3 and (n[1] == "#" or n[1] == "b") else n.substr(0, 1)
	if not NOTE_NAMES.has(name):
		return -1
	var octave_text: String = n.substr(name.length())
	if not octave_text.is_valid_int():
		return -1
	return NOTE_NAMES[name] + (octave_text.to_int() + 1) * 12


static func midi_to_hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## Accord actif à la mesure `bar` (liste MIDI ; boucle sur `bars`).
func chord_at(bar: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var b: int = posmod(bar, maxi(bars, 1))
	for chord: Dictionary in _chords:
		var start: int = int(chord.get("bar", 0))
		var length: int = int(chord.get("bars", 1))
		if b >= start and b < start + length:
			for note: String in chord.get("notes", []):
				out.append(note_to_midi(note))
			return out
	return out


## Liste à plat des notes d'une piste : [début (éch.), durée (éch.), midi,
## vélocité, panoramique], dans l'ordre (déterministe).
func track_notes(stem_id: String, track_index: int, track: Dictionary, from_bar: int, to_bar: int) -> Array[PackedFloat32Array]:
	var out: Array[PackedFloat32Array] = []
	var rng: RandomNumberGenerator = _rng(stem_id + "/notes", track_index)
	var human: float = float(track.get("humanize_ms", 0.0)) * 0.001 * rate
	var pan: float = float(track.get("pan", 0.0))
	# 1. Accords (nappes) : chaque accord de la partition, tenu `len` mesures.
	if track.has("chords"):
		var spec: Dictionary = track["chords"]
		var octave: int = int(spec.get("octave", 0))
		var vel: float = float(spec.get("vel", 1.0))
		var only: Array = spec.get("only", [])
		var c_from: int = int(spec.get("from_bar", 0))
		var c_to: int = int(spec.get("to_bar", 1 << 20))
		for chord: Dictionary in _chords:
			var start_bar: int = int(chord.get("bar", 0))
			if start_bar < c_from or start_bar >= c_to:
				continue
			var length_bars: int = int(chord.get("bars", 1))
			for rep: int in _repeats(start_bar, from_bar, to_bar):
				var at_bar: int = start_bar + rep * bars
				var notes: Array = chord.get("notes", [])
				for k: int in notes.size():
					# JSON : les indices de `only` sont des flottants (0.0 ≠ 0 pour `has`).
					if not only.is_empty() and not (only.has(k) or only.has(float(k))):
						continue
					var midi: int = note_to_midi(str(notes[k])) + 12 * octave
					out.append(PackedFloat32Array([(at_bar - from_bar) * bar_n, length_bars * bar_n, midi, vel, pan]))
	# 2. Motif répété (`pattern`) : pas relatifs à la mesure, notes « chord:k ».
	for pattern: Dictionary in _as_list(track.get("pattern", null)):
		var p_bars: int = maxi(int(pattern.get("bars", 1)), 1)
		var p_from: int = int(pattern.get("from_bar", 0))
		var p_to: int = int(pattern.get("to_bar", bars))
		var bar: int = p_from
		while bar < p_to:
			for ev: Dictionary in pattern.get("steps", []):
				_append_event(out, ev, bar, from_bar, to_bar, rng, human, pan)
			bar += p_bars
	# 3. Événements explicites (dont placements de motifs MO-n).
	for ev: Dictionary in track.get("events", []):
		if ev.has("motif"):
			var motif: Array = _motifs.get(str(ev["motif"]), [])
			var base_step: int = int(ev.get("step", 0))
			var stretch: float = float(ev.get("stretch", 1.0))
			var transpose: int = int(ev.get("transpose", 0))
			for m: Dictionary in motif:
				var e: Dictionary = m.duplicate()
				e["step"] = base_step + roundi(float(m.get("step", 0)) * stretch)
				e["len"] = maxf(float(m.get("len", 1)) * stretch, 1.0)
				e["transpose"] = transpose + int(m.get("transpose", 0))
				if ev.has("vel"):
					e["vel"] = float(ev["vel"]) * float(m.get("vel", 1.0))
				_append_event(out, e, int(ev.get("bar", 0)), from_bar, to_bar, rng, 0.0, pan)
		else:
			_append_event(out, ev, int(ev.get("bar", 0)), from_bar, to_bar, rng, human, pan)
	return out


func _append_event(out: Array[PackedFloat32Array], ev: Dictionary, bar: int, from_bar: int, to_bar: int,
		rng: RandomNumberGenerator, human: float, pan: float) -> void:
	# Le tirage de probabilité et l'humanisation consomment toujours le RNG
	# (même ordre de tirages quelle que soit la fenêtre rendue).
	var roll: float = rng.randf()
	var jitter: float = rng.randf_range(-human, human) if human > 0.0 else 0.0
	if bar < from_bar or bar >= to_bar:
		return
	if roll >= float(ev.get("prob", 1.0)):
		return
	var start: float = (bar - from_bar) * bar_n + float(ev.get("step", 0)) * step_n + jitter
	var length: float = float(ev.get("len", 1)) * step_n
	var vel: float = float(ev.get("vel", 1.0))
	var ev_pan: float = float(ev.get("pan", pan))
	var transpose: int = int(ev.get("transpose", 0)) + 12 * int(ev.get("oct", 0))
	var notes: Array = ev.get("notes", [ev.get("note", "A4")])
	for note: Variant in notes:
		var midi: int = _resolve_note(str(note), bar)
		if midi < 0:
			continue
		out.append(PackedFloat32Array([start, length, midi + transpose, vel, ev_pan]))


func _resolve_note(text: String, bar: int) -> int:
	if text.begins_with("chord:"):
		var chord: PackedInt32Array = chord_at(bar)
		if chord.is_empty():
			return -1
		var k: int = text.trim_prefix("chord:").to_int()
		return chord[posmod(k, chord.size())] + 12 * floori(float(k) / chord.size())
	if text == "rest":
		return -1
	if text == "bass":
		var b: int = posmod(bar, maxi(bars, 1))
		for chord: Dictionary in _chords:
			var start: int = int(chord.get("bar", 0))
			if b >= start and b < start + int(chord.get("bars", 1)):
				return note_to_midi(str(chord.get("bass", "")))
		return -1
	return note_to_midi(text)


func _repeats(start_bar: int, from_bar: int, to_bar: int) -> Array[int]:
	# Une nappe de la boucle peut aussi sonner au tour suivant (queue).
	var out: Array[int] = []
	for rep: int in 2:
		var at: int = start_bar + rep * bars
		if at >= from_bar and at < to_bar:
			out.append(rep)
	return out


static func _as_list(value: Variant) -> Array:
	if value == null:
		return []
	if value is Array:
		return value
	return [value]


# ---------------------------------------------------------------------------
# Rendu d'une couche
# ---------------------------------------------------------------------------

## Couche `stem_id` rendue sur les mesures [`from_bar`, `from_bar + length`) :
## `loop` → repli de `tail_bars` mesures de queue sur le début (longueur
## exacte), sinon la fenêtre seule (queues coupées : utilisée pour un thème
## rendu d'un seul tenant). Renvoie [gauche, droite] non normalisés.
func render_stem(stem_id: String, from_bar: int = 0, length_bars: int = -1, loop: bool = true) -> Array[PackedFloat32Array]:
	var length: int = (bars if length_bars < 0 else length_bars) * bar_n
	var tail: int = tail_bars * bar_n
	var total: int = length + tail
	var stem: Dictionary = {}
	for s: Dictionary in score.get("stems", []):
		if str(s.get("id", "")) == stem_id:
			stem = s
	var dry_l: PackedFloat32Array = AudioDsp.silence(total)
	var dry_r: PackedFloat32Array = AudioDsp.silence(total)
	var send_l: PackedFloat32Array = AudioDsp.silence(total)
	var send_r: PackedFloat32Array = AudioDsp.silence(total)
	var to_bar: int = from_bar + (bars if length_bars < 0 else length_bars)
	var tracks: Array = stem.get("tracks", [])
	for t: int in tracks.size():
		var track: Dictionary = tracks[t]
		if not track_in_variant(track, variant):
			continue
		var lr: Array[PackedFloat32Array] = _render_track(stem_id, t, track, from_bar, to_bar, total)
		var g: float = db_to_linear(float(track.get("gain_db", 0.0)))
		var send: float = float(track.get("send", 0.0))
		var tl: PackedFloat32Array = lr[0]
		var tr: PackedFloat32Array = lr[1]
		for i: int in total:
			var l: float = tl[i] * g
			var r: float = tr[i] * g
			dry_l[i] += l
			dry_r[i] += r
			send_l[i] += l * send
			send_r[i] += r * send
	var mix: Dictionary = score.get("mix", {})
	var rev: Dictionary = mix.get("reverb", {})
	if not rev.is_empty():
		var wet: Array[PackedFloat32Array] = AudioDsp.fdn_reverb(send_l, send_r, rate, float(rev.get("rt60", 2.5)),
				float(rev.get("size", 1.0)), float(rev.get("damp_hz", 5000.0)), float(rev.get("predelay", 0.02)))
		var wl: PackedFloat32Array = wet[0]
		var wr: PackedFloat32Array = wet[1]
		for i: int in total:
			dry_l[i] += wl[i]
			dry_r[i] += wr[i]
	var out: Array[PackedFloat32Array] = [dry_l, dry_r]
	for eq: Dictionary in _eq_for(stem):
		for ch: int in 2:
			out[ch] = AudioDsp.eq_peak(out[ch], float(eq.get("freq", 2000.0)), float(eq.get("q", 0.7)),
					float(eq.get("gain_db", 0.0)), rate)
	out = AudioDsp.ms_width(out[0], out[1], float(stem.get("width", mix.get("width", 1.0))))
	for ch: int in 2:
		out[ch] = AudioDsp.dc_block(out[ch], rate)
	return [_fold(out[0], length, tail, loop), _fold(out[1], length, tail, loop)]


## Vrai si la piste sonne dans la variante `v` (vide = thème de base).
static func track_in_variant(track: Dictionary, v: String) -> bool:
	if track.has("variant"):
		var only: Array = _as_list(track["variant"])
		if not only.has(v):
			return false
	if track.has("not_variant") and _as_list(track["not_variant"]).has(v):
		return false
	return true


func _eq_for(stem: Dictionary) -> Array:
	if stem.has("eq"):
		return stem["eq"]
	var mix: Dictionary = score.get("mix", {})
	return mix.get("eq", [])


static func _fold(buf: PackedFloat32Array, length: int, tail: int, loop: bool) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf.slice(0, length)
	if loop:
		var m: int = mini(tail, buf.size() - length)
		for k: int in m:
			out[k % length] += buf[length + k]
	return out


## Une note avancée avant le début de la fenêtre par l'humanisation est
## calée sur le premier échantillon : une attaque à cheval sur la jointure
## d'une boucle serait codée de part et d'autre de la fin et du début du
## fichier Vorbis (effets de bord du codec → clic mesuré par M-05).
func _render_track(stem_id: String, t: int, track: Dictionary, from_bar: int, to_bar: int,
		total: int) -> Array[PackedFloat32Array]:
	var left: PackedFloat32Array = AudioDsp.silence(total)
	var right: PackedFloat32Array = AudioDsp.silence(total)
	var inst_name: String = str(track.get("instrument", ""))
	var inst: Dictionary = _instruments.get(inst_name, {})
	if inst.is_empty():
		errors.append("%s/%s : instrument inconnu « %s »" % [id, stem_id, inst_name])
		return [left, right]
	var notes: Array[PackedFloat32Array] = track_notes(stem_id, t, track, from_bar, to_bar)
	var rng: RandomNumberGenerator = _rng(stem_id + "/voices", t)
	for k: int in notes.size():
		var note: PackedFloat32Array = notes[k]
		var start: int = roundi(note[0])
		start = maxi(start, 0)
		if start >= total:
			continue
		var voice: Array[PackedFloat32Array] = render_voice(inst, midi_to_hz(note[2]), roundi(note[1]), rng)
		var vel: float = note[3]
		var pan: float = clampf(note[4], -1.0, 1.0)
		var gl: float = vel * cos((pan + 1.0) * PI * 0.25) * sqrt(2.0)
		var gr: float = vel * sin((pan + 1.0) * PI * 0.25) * sqrt(2.0)
		var vl: PackedFloat32Array = voice[0]
		var vr: PackedFloat32Array = voice[1]
		var m: int = mini(vl.size(), total - start)
		for i: int in m:
			left[start + i] += vl[i] * gl
			right[start + i] += vr[i] * gr
	var auto: Dictionary = track.get("automation", {})
	if auto.has("cutoff"):
		var curve: PackedFloat32Array = _curve(auto["cutoff"], from_bar, total)
		var q: float = float(auto.get("q", 0.7))
		left = AudioDsp.svf(left, AudioDsp.Svf.LOWPASS, curve, q, rate)
		right = AudioDsp.svf(right, AudioDsp.Svf.LOWPASS, curve, q, rate)
	if auto.has("gain_db"):
		var gains: PackedFloat32Array = _curve(auto["gain_db"], from_bar, total)
		for i: int in total:
			var g: float = db_to_linear(gains[i / AudioDsp.BLOCK])
			left[i] *= g
			right[i] *= g
	if track.has("bitcrush"):
		var bc: Dictionary = track["bitcrush"]
		left = AudioDsp.bitcrush(left, int(bc.get("bits", 10)), int(bc.get("hold", 1)))
		right = AudioDsp.bitcrush(right, int(bc.get("bits", 10)), int(bc.get("hold", 1)))
	return [left, right]


## Courbe par bloc depuis des points [mesure, valeur] (mesures absolues).
func _curve(points: Array, from_bar: int, total: int) -> PackedFloat32Array:
	var at: PackedInt32Array = PackedInt32Array()
	var values: PackedFloat32Array = PackedFloat32Array()
	for p: Array in points:
		at.append(roundi((float(p[0]) - from_bar) * bar_n))
		values.append(float(p[1]))
	return AudioDsp.block_curve(total, at, values)


# ---------------------------------------------------------------------------
# Instruments
# ---------------------------------------------------------------------------

## Une note de l'instrument `inst` : [gauche, droite] (mêmes tableaux pour un
## instrument mono). `dur` = durée tenue (échantillons) ; la queue
## (relâchement, résonance) s'y ajoute.
func render_voice(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> Array[PackedFloat32Array]:
	var kind: String = str(inst.get("type", "pad"))
	match kind:
		"pad":
			return _pad(inst, hz, dur, rng)
		"choir":
			return _choir(inst, hz, dur, rng)
	var mono: PackedFloat32Array
	match kind:
		"bass":
			mono = _bass(inst, hz, dur)
		"bell":
			mono = _bell(inst, hz, dur)
		"pluck":
			mono = _pluck(inst, hz, dur, rng)
		"musicbox":
			mono = _musicbox(inst, hz, dur)
		"arp":
			mono = _arp(inst, hz, dur, rng)
		"tick", "brush":
			mono = _noise_hit(inst, dur, rng)
		"noise_swell":
			mono = _noise_swell(inst, dur, rng)
		"neon":
			mono = _neon(inst, hz, dur, rng)
		"tone":
			mono = _tone(inst, hz, dur, rng)
		_:
			errors.append("%s : type d'instrument inconnu « %s »" % [id, kind])
			mono = AudioDsp.silence(dur)
	return [mono, mono]


func _sec(inst: Dictionary, key: String, fallback: float) -> float:
	return float(inst.get(key, fallback))


func _adsr(inst: Dictionary, n: int, dur: int) -> PackedFloat32Array:
	return AudioDsp.env_adsr(n, _sec(inst, "attack", 0.01), _sec(inst, "decay", 0.2), _sec(inst, "sustain", 0.8),
			_sec(inst, "release", 0.3), float(dur) / rate, rate)


func _apply_env(buf: PackedFloat32Array, env: PackedFloat32Array) -> PackedFloat32Array:
	for i: int in buf.size():
		buf[i] *= env[i]
	return buf


## Nappe : `voices` dents de scie polyBLEP désaccordées par côté, passe-bas.
func _pad(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> Array[PackedFloat32Array]:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 1.5), rate)
	var voices: int = int(inst.get("voices", 2))
	var spread: float = float(inst.get("detune_cents", 8.0))
	var env: PackedFloat32Array = _adsr(inst, n, dur)
	var cutoff: PackedFloat32Array = PackedFloat32Array([float(inst.get("cutoff", 900.0))])
	var out: Array[PackedFloat32Array] = []
	for side: int in 2:
		var acc: PackedFloat32Array = AudioDsp.silence(n)
		for v: int in voices:
			var cents: float = spread * (float(v) / maxf(voices - 1, 1) * 2.0 - 1.0) if voices > 1 else 0.0
			cents += spread * 0.35 * (1.0 if side == 0 else -1.0)
			var osc: PackedFloat32Array = AudioDsp.blep_saw(n, hz * pow(2.0, cents / 1200.0), rate, rng.randf(),
					float(inst.get("vib_hz", 0.0)) * (1.0 + 0.07 * v), float(inst.get("vib_depth", 0.0)))
			for i: int in n:
				acc[i] += osc[i]
		acc = AudioDsp.svf(acc, AudioDsp.Svf.LOWPASS, cutoff, float(inst.get("q", 0.7)), rate)
		var g: float = float(inst.get("level", 0.3)) / sqrt(float(voices))
		for i: int in n:
			acc[i] *= env[i] * g
		out.append(acc)
	return out


## Chœur synthétique : dents de scie désaccordées avec vibrato, trois
## formants (passe-bande) d'une voyelle, souffle.
func _choir(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> Array[PackedFloat32Array]:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 2.5), rate)
	var voices: int = int(inst.get("voices", 3))
	var spread: float = float(inst.get("detune_cents", 12.0))
	var env: PackedFloat32Array = _adsr(inst, n, dur)
	var formants: Array = inst.get("formants", [[700.0, 6.0, 1.0], [1100.0, 8.0, 0.5], [2600.0, 10.0, 0.18]])
	var breath: float = float(inst.get("breath", 0.02))
	var out: Array[PackedFloat32Array] = []
	for side: int in 2:
		var acc: PackedFloat32Array = AudioDsp.silence(n)
		for v: int in voices:
			var cents: float = rng.randf_range(-spread, spread)
			var vib: float = float(inst.get("vib_hz", 5.0)) * rng.randf_range(0.85, 1.15)
			var osc: PackedFloat32Array = AudioDsp.blep_saw(n, hz * pow(2.0, cents / 1200.0), rate, rng.randf(), vib,
					float(inst.get("vib_depth", 0.004)))
			for i: int in n:
				acc[i] += osc[i]
		if breath > 0.0:
			var noise: PackedFloat32Array = AudioDsp.white(n, rng)
			for i: int in n:
				acc[i] += noise[i] * breath * voices
		var shaped: PackedFloat32Array = AudioDsp.silence(n)
		for f: Array in formants:
			var band: PackedFloat32Array = AudioDsp.svf(acc, AudioDsp.Svf.BANDPASS,
					PackedFloat32Array([float(f[0]) * float(inst.get("formant_shift", 1.0))]), float(f[1]), rate)
			var fg: float = float(f[2])
			for i: int in n:
				shaped[i] += band[i] * fg
		var g: float = float(inst.get("level", 0.3)) / sqrt(float(voices))
		for i: int in n:
			shaped[i] *= env[i] * g
		out.append(shaped)
	return out


## Basse : dent de scie + sous-sinus, passe-bas à enveloppe de filtre.
func _bass(inst: Dictionary, hz: float, dur: int) -> PackedFloat32Array:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 0.1), rate)
	var buf: PackedFloat32Array = AudioDsp.blep_saw(n, hz, rate)
	var sub: PackedFloat32Array = AudioDsp.sine(n, hz, rate)
	var sub_g: float = float(inst.get("sub", 0.6))
	for i: int in n:
		buf[i] = buf[i] * 0.6 + sub[i] * sub_g
	var c0: float = float(inst.get("cutoff_peak", 600.0))
	var c1: float = float(inst.get("cutoff", 250.0))
	var tau: float = _sec(inst, "filter_decay", 0.08) * rate
	var blocks: int = ceili(float(n) / AudioDsp.BLOCK)
	var curve: PackedFloat32Array = AudioDsp.silence(blocks)
	for b: int in blocks:
		curve[b] = c1 + (c0 - c1) * exp(-b * AudioDsp.BLOCK / maxf(tau, 1.0))
	buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, curve, float(inst.get("q", 0.9)), rate)
	return _apply_env(AudioDsp.gain(buf, float(inst.get("level", 0.5))), _adsr(inst, n, dur))


## Cloche FM à 2 opérateurs (MO-1).
func _bell(inst: Dictionary, hz: float, dur: int) -> PackedFloat32Array:
	var n: int = maxi(dur, AudioDsp.samples(_sec(inst, "length", 3.0), rate))
	var buf: PackedFloat32Array = AudioDsp.fm2(n, hz, float(inst.get("ratio", 3.5)), float(inst.get("index", 2.5)),
			_sec(inst, "index_decay", 0.35), rate)
	var env: PackedFloat32Array = AudioDsp.env_ad(n, _sec(inst, "attack", 0.002), _sec(inst, "decay", 1.1), rate)
	buf = _apply_env(buf, env)
	buf = AudioDsp.fade(buf, 0.0, 0.05, rate)
	return AudioDsp.gain(buf, float(inst.get("level", 0.3)))


## Pincé Karplus-Strong (MO-2, « rouille et thé »), bande radio optionnelle.
func _pluck(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = maxi(dur, AudioDsp.samples(_sec(inst, "length", 1.5), rate))
	var buf: PackedFloat32Array = AudioDsp.karplus(n, hz, rate, rng, float(inst.get("damping", 0.004)),
			float(inst.get("brightness", 0.5)))
	if inst.has("band"):
		var band: Array = inst["band"]
		buf = AudioDsp.svf(buf, AudioDsp.Svf.HIGHPASS, PackedFloat32Array([float(band[0])]), 0.7, rate)
		buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, PackedFloat32Array([float(band[1])]), 0.7, rate)
	if inst.has("bits"):
		buf = AudioDsp.bitcrush(buf, int(inst["bits"]), int(inst.get("hold", 1)))
	buf = AudioDsp.fade(buf, 0.001, 0.08, rate)
	return AudioDsp.gain(buf, float(inst.get("level", 0.4)))


## Boîte à musique (MO-3) : sinus + partiel, attaque sèche.
func _musicbox(inst: Dictionary, hz: float, dur: int) -> PackedFloat32Array:
	var n: int = maxi(dur, AudioDsp.samples(_sec(inst, "length", 2.0), rate))
	var buf: PackedFloat32Array = AudioDsp.sine(n, hz, rate)
	var partial: PackedFloat32Array = AudioDsp.sine(n, hz * float(inst.get("partial", 3.0)), rate)
	var env: PackedFloat32Array = AudioDsp.env_ad(n, 0.002, _sec(inst, "decay", 0.9), rate)
	var env2: PackedFloat32Array = AudioDsp.env_ad(n, 0.001, _sec(inst, "decay", 0.9) * 0.3, rate)
	for i: int in n:
		buf[i] = buf[i] * env[i] + partial[i] * env2[i] * 0.35
	return AudioDsp.gain(AudioDsp.fade(buf, 0.0, 0.05, rate), float(inst.get("level", 0.3)))


## Arpège : impulsion PWM filtrée, enveloppe courte.
func _arp(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 0.2), rate)
	var buf: PackedFloat32Array = AudioDsp.blep_pulse(n, hz, rate, float(inst.get("width", 0.3)), rng.randf())
	buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, PackedFloat32Array([float(inst.get("cutoff", 1800.0))]), 0.8, rate)
	return _apply_env(AudioDsp.gain(buf, float(inst.get("level", 0.25))), _adsr(inst, n, dur))


## Cliquetis / balai : bruit filtré (passe-haut ≥ 6 kHz ou passe-bande).
func _noise_hit(inst: Dictionary, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = maxi(dur, AudioDsp.samples(_sec(inst, "length", 0.08), rate))
	var buf: PackedFloat32Array = AudioDsp.white(n, rng)
	var mode: AudioDsp.Svf = AudioDsp.Svf.BANDPASS if str(inst.get("type", "")) == "brush" else AudioDsp.Svf.HIGHPASS
	buf = AudioDsp.svf(buf, mode, PackedFloat32Array([float(inst.get("cutoff", 7000.0))]), float(inst.get("q", 0.7)), rate)
	var env: PackedFloat32Array = AudioDsp.env_ad(n, _sec(inst, "attack", 0.001), _sec(inst, "decay", 0.015), rate)
	return AudioDsp.gain(_apply_env(buf, env), float(inst.get("level", 0.2)))


## Montée de bruit rose dont le filtre s'ouvre sur toute la note (L4).
func _noise_swell(inst: Dictionary, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 0.5), rate)
	var buf: PackedFloat32Array = AudioDsp.pink(n, rng)
	var blocks: int = ceili(float(n) / AudioDsp.BLOCK)
	var curve: PackedFloat32Array = AudioDsp.silence(blocks)
	var c0: float = float(inst.get("cutoff_start", 300.0))
	var c1: float = float(inst.get("cutoff_end", 3000.0))
	for b: int in blocks:
		var t: float = clampf(float(b * AudioDsp.BLOCK) / maxf(dur, 1), 0.0, 1.0)
		curve[b] = c0 * pow(c1 / c0, t)
	buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, curve, float(inst.get("q", 1.2)), rate)
	var env: PackedFloat32Array = _adsr(inst, n, dur)
	var shape: float = float(inst.get("swell", 1.0))
	for i: int in n:
		var t: float = clampf(float(i) / maxf(dur, 1), 0.0, 1.0)
		buf[i] *= env[i] * lerpf(1.0, t, shape)
	return AudioDsp.gain(buf, float(inst.get("level", 0.3)))


## Bourdonnement de néon (TH-F9) : impulsion étroite + harmoniques, hauteur
## qui glisse vers `glide` × f, papillotement seedé, extinction en fin de note.
func _neon(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dur
	var buf: PackedFloat32Array = AudioDsp.silence(n)
	var glide: float = float(inst.get("glide", 0.5))
	var width: float = float(inst.get("width", 0.12))
	var t: float = 0.0
	var flick: float = 1.0
	var flick_target: float = 1.0
	var flick_every: int = AudioDsp.samples(0.045, rate)
	for i: int in n:
		var u: float = float(i) / maxf(n - 1, 1)
		var f: float = hz * pow(glide, u * u)
		var dt: float = f / rate
		var v: float = (1.0 if t < width else -1.0)
		v += AudioDsp._poly_blep(t, dt)
		v -= AudioDsp._poly_blep(fposmod(t - width + 1.0, 1.0), dt)
		v += sin(TAU * t) * 1.5
		t += dt
		if t >= 1.0:
			t -= 1.0
		if i % flick_every == 0:
			var dip: float = float(inst.get("flicker", 0.3)) * (0.3 + u)
			flick_target = 1.0 - (dip if rng.randf() < 0.25 + 0.5 * u else 0.0)
		flick += (flick_target - flick) * 0.01
		var fade_out: float = 1.0 - smoothstep(0.55, 1.0, u)
		buf[i] = v * flick * fade_out
	buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, PackedFloat32Array([float(inst.get("cutoff", 2500.0))]), 0.7, rate)
	buf = AudioDsp.svf(buf, AudioDsp.Svf.HIGHPASS, PackedFloat32Array([60.0]), 0.7, rate)
	buf = AudioDsp.fade(buf, _sec(inst, "attack", 0.3), 0.05, rate)
	return AudioDsp.gain(buf, float(inst.get("level", 0.2)))


## Son tenu simple (sinus, triangle, dent de scie, bruit d'air ou souffle aigu), ADSR.
func _tone(inst: Dictionary, hz: float, dur: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n: int = dur + AudioDsp.samples(_sec(inst, "release", 0.5), rate)
	var buf: PackedFloat32Array
	match str(inst.get("wave", "sine")):
		"triangle":
			buf = AudioDsp.triangle(n, hz, rate, rng.randf())
		"air":
			buf = AudioDsp.svf(AudioDsp.pink(n, rng), AudioDsp.Svf.LOWPASS,
					PackedFloat32Array([float(inst.get("cutoff", 1500.0))]), 0.7, rate)
		"hiss":
			buf = AudioDsp.svf(AudioDsp.white(n, rng), AudioDsp.Svf.HIGHPASS,
					PackedFloat32Array([float(inst.get("cutoff", 6500.0))]), 0.7, rate)
		"saw":
			buf = AudioDsp.svf(AudioDsp.blep_saw(n, hz, rate, rng.randf()), AudioDsp.Svf.LOWPASS,
					PackedFloat32Array([float(inst.get("cutoff", 1500.0))]), 0.7, rate)
		"square":
			# Bip de borne (monde A) : impulsion à bande limitée, filtrée.
			buf = AudioDsp.svf(AudioDsp.blep_pulse(n, hz, rate, float(inst.get("width", 0.5)), rng.randf()),
					AudioDsp.Svf.LOWPASS, PackedFloat32Array([float(inst.get("cutoff", 2500.0))]), 0.7, rate)
		"thump":
			# Coup sourd (porte, coup grave de F5B) : sinus qui chute, filtré ≤ cutoff.
			buf = AudioDsp.silence(n)
			var ph: float = 0.0
			var drop: float = float(inst.get("drop", 0.5))
			for i: int in n:
				var u: float = float(i) / rate
				ph += TAU * hz * (1.0 + drop * exp(-u / 0.05)) / rate
				buf[i] = sin(ph)
			buf = AudioDsp.svf(buf, AudioDsp.Svf.LOWPASS, PackedFloat32Array([float(inst.get("cutoff", 200.0))]), 0.7, rate)
		_:
			buf = AudioDsp.sine(n, hz, rate, rng.randf() * TAU)
	return _apply_env(AudioDsp.gain(buf, float(inst.get("level", 0.3))), _adsr(inst, n, dur))


func _rng(tag: String, index: int) -> RandomNumberGenerator:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = SeededRng.mix(SeededRng.mix(seed, SeededRng.hash_string(id + "/" + tag)), index)
	return r
