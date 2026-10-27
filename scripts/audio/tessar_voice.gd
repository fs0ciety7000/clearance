## Voix des passagers en **Tessar** (D-020, LORE §10) : babillage syllabique
## procédural, synthèse source-filtre (impulsions glottiques + 3 formants,
## bruits filtrés pour les consonnes). Toujours sous-titré en français par l'UI ;
## le filtre « hygiaphone » est appliqué par le bus `Voice`.
##
## - `profile_for(passenger)` : timbre par passager (sexe, tranche d'âge,
##   taille, graine d'apparence) — même passager ⇒ même voix.
## - `phrase_for(line_key, text)` : phrase Tessar d'une réplique (lexique du
##   Lore, sinon syllabes tirées de la clé ; longueur calée sur le sous-titre).
## - `render(...)` : `AudioStreamWAV` mono 16 kHz, crête −3 dBFS, ≤ ~2 s.
## Pur et déterministe (testable sans scène).
class_name TessarVoice
extends RefCounted

const SAMPLE_RATE: int = 16000
const MAX_SYLLABLES: int = 9
const PEAK_DB: float = -3.0

## Humeurs reconnues (prosodie).
const MOOD_NEUTRAL: StringName = &"neutral"
const MOOD_NERVOUS: StringName = &"nervous"
const MOOD_ANGRY: StringName = &"angry"
const MOOD_SHRUG: StringName = &"shrug"
const MOOD_RELIEVED: StringName = &"relieved"
const MOOD_PA: StringName = &"pa"

## Phrases du lexique (LORE §10) par clé de réplique.
const LEXICON: Dictionary[String, String] = {
	"bark_arrival": "oru ka",
	"bark_present": "tal ka nesu",
	"react_nervous": "esh ta, esh ta",
	"react_angry": "kumo ri sava sa?",
	"react_shrug": "hanu pe",
	"react_relieved": "shen tavi",
	"line_confront_nervous": "esh ta, esh ta",
	"line_confront_angry": "kumo ri sava sa?",
	"line_generic_shrug": "hanu pe",
	"line_purpose_family_visit": "ravel ka ota",
	"bark_depart_ok": "vesh ota lumi",
}

const CONSONANTS: Array[String] = ["p", "t", "k", "m", "n", "s", "sh", "v", "l", "r", "h"]
const ONSET_WEIGHTS: PackedFloat32Array = [0.6, 1.2, 1.2, 0.9, 1.0, 1.0, 0.6, 0.7, 1.0, 0.9, 0.5]
const VOWELS: Array[String] = ["a", "e", "i", "o", "u"]
const CODAS: Array[String] = ["n", "s", "r"]

## Formants (Hz) d'une voix d'homme ; mis à l'échelle par `formant_scale`.
const VOWEL_FORMANTS: Dictionary[String, Vector3] = {
	"a": Vector3(730, 1090, 2440),
	"e": Vector3(530, 1840, 2480),
	"i": Vector3(300, 2200, 2950),
	"o": Vector3(570, 840, 2410),
	"u": Vector3(320, 870, 2240),
}
const NASAL_FORMANTS: Vector3 = Vector3(260, 1200, 2300)

## Timbre d'un passager.
class Profile:
	extends RefCounted
	var voice_seed: int = 0
	## Fréquence fondamentale moyenne (Hz).
	var f0: float = 130.0
	var formant_scale: float = 1.0
	## Débit (1 = normal).
	var rate: float = 1.0
	## Part de souffle dans la source (0..1).
	var breath: float = 0.08
	var jitter: float = 0.01
	var vibrato: float = 0.0
	## Famille de voix (docs/AUDIO.md §8.1) : low / mid / high / old.
	var family: StringName = &"mid"


## Segment de la chaîne phonétique.
class Segment:
	extends RefCounted
	## &"vowel", &"nasal", &"liquid", &"fric", &"stop", &"aspir", &"pause".
	var kind: StringName = &"pause"
	var duration: float = 0.05
	var formants: Vector3 = Vector3(500, 1500, 2500)
	var voiced: float = 0.0
	var noise: float = 0.0
	var noise_freq: float = 4000.0
	var amp: float = 1.0
	## Multiplicateur de f0 au début / à la fin du segment.
	var pitch: Vector2 = Vector2.ONE


## Profil de voix d'un passager (null → voix médiane neutre).
static func profile_for(passenger: Passenger) -> Profile:
	var p: Profile = Profile.new()
	if passenger == null:
		return p
	var seed_value: int = passenger.appearance_seed if passenger.appearance_seed != 0 else SeededRng.hash_string(String(passenger.id))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	p.voice_seed = seed_value
	var age_band: int = 1
	var height_step: int = 0
	if passenger.appearance != null:
		age_band = passenger.appearance.age_band
		height_step = passenger.appearance.height_step
	match passenger.sex:
		Passenger.SEX_F:
			p.f0 = rng.randf_range(185.0, 225.0)
			p.formant_scale = 1.15
			p.family = &"high"
		Passenger.SEX_M:
			p.f0 = rng.randf_range(98.0, 128.0)
			p.formant_scale = 1.0
			p.family = &"low"
		_:
			p.f0 = rng.randf_range(135.0, 170.0)
			p.formant_scale = 1.07
			p.family = &"mid"
	p.formant_scale *= (1.0 - 0.025 * height_step) * rng.randf_range(0.97, 1.03)
	p.rate = rng.randf_range(0.92, 1.08)
	p.breath = rng.randf_range(0.05, 0.16)
	p.jitter = rng.randf_range(0.006, 0.014)
	if age_band >= 2:
		p.family = &"old"
		p.f0 *= 0.92 if passenger.sex == Passenger.SEX_F else 1.04
		p.rate *= 0.9
		p.jitter *= 2.2
		p.vibrato = 0.025
		p.breath += 0.06
	elif age_band == 0:
		p.f0 *= 1.05
		p.rate *= 1.05
	return p


## Humeur d'une réaction.
static func mood_for_reaction(reaction: PassengerReaction.Kind) -> StringName:
	match reaction:
		PassengerReaction.Kind.NERVOUS:
			return MOOD_NERVOUS
		PassengerReaction.Kind.ANGRY:
			return MOOD_ANGRY
		PassengerReaction.Kind.SHRUG:
			return MOOD_SHRUG
		PassengerReaction.Kind.RELIEVED:
			return MOOD_RELIEVED
	return MOOD_NEUTRAL


## Phrase Tessar d'une réplique : lexique, sinon syllabes déterministes tirées
## de la clé, en nombre proportionnel au sous-titre (`text`).
static func phrase_for(line_key: String, text: String = "") -> String:
	if LEXICON.has(line_key):
		return LEXICON[line_key]
	for prefix: String in ["line_origin_"]:
		if line_key.begins_with(prefix):
			return "ka vira " + _word(SeededRng.hash_string(line_key), 2)
	var count: int = clampi(roundi(text.length() / 5.5), 2, MAX_SYLLABLES) if not text.is_empty() else 3
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SeededRng.hash_string(line_key)
	var words: PackedStringArray = PackedStringArray()
	var left: int = count
	while left > 0:
		var n: int = mini(left, rng.randi_range(1, 3))
		words.append(_word(rng.randi(), n))
		left -= n
	# Une virgule du sous-titre devient une respiration au milieu de la phrase.
	if (text.contains(",") or text.contains("…")) and words.size() > 1:
		var mid: int = int(words.size() * 0.5) - 1
		words[mid] = words[mid] + ","
	var phrase: String = " ".join(words)
	if text.strip_edges().ends_with("?"):
		phrase += " sa?"
	return phrase


## Mot de `syllables` syllabes conformes à la phonotactique (V, CV, CVn/s/r).
static func _word(seed_value: int, syllables: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var word: String = ""
	for i: int in syllables:
		if i == 0 and rng.randf() < 0.2:
			word += VOWELS[rng.randi() % VOWELS.size()]
		else:
			word += CONSONANTS[rng.rand_weighted(ONSET_WEIGHTS)] + VOWELS[rng.randi() % VOWELS.size()]
		if i == syllables - 1 and rng.randf() < 0.3:
			word += CODAS[rng.randi() % CODAS.size()]
	return word


## Découpe une phrase Tessar en syllabes : tableau de mots, chaque mot un
## tableau de syllabes `[onset, voyelle, coda]`.
static func syllabify(phrase: String) -> Array[Array]:
	var words: Array[Array] = []
	for raw: String in phrase.to_lower().replace(",", " , ").replace("?", " ").replace(".", " ").split(" ", false):
		if raw == ",":
			words.append([])
			continue
		var syls: Array = []
		var i: int = 0
		while i < raw.length():
			var onset: String = ""
			if raw.substr(i, 2) == "sh":
				onset = "sh"
				i += 2
			elif not VOWELS.has(raw[i]):
				onset = raw[i]
				i += 1
			if i >= raw.length():
				if not syls.is_empty():
					var last: Array = syls[-1]
					last[2] = onset # consonne finale isolée → coda
				break
			var vowel: String = raw[i]
			i += 1
			var coda: String = ""
			if i < raw.length() and CODAS.has(raw[i]):
				var next_is_vowel: bool = i + 1 < raw.length() and VOWELS.has(raw[i + 1])
				if not next_is_vowel:
					coda = raw[i]
					i += 1
			syls.append([onset, vowel, coda])
		words.append(syls)
	return words


## Chaîne de segments (durées, cibles, contour de f0) d'une phrase.
static func segments_for(phrase: String, profile: Profile, mood: StringName) -> Array[Segment]:
	var words: Array[Array] = syllabify(phrase)
	var question: bool = phrase.strip_edges().ends_with("?")
	var tempo: float = profile.rate
	match mood:
		MOOD_NERVOUS:
			tempo *= 1.18
		MOOD_ANGRY:
			tempo *= 1.1
		MOOD_SHRUG, MOOD_RELIEVED:
			tempo *= 0.9
		MOOD_PA:
			tempo *= 0.85
	var total: int = 0
	for w: Array in words:
		total += w.size()
	var segs: Array[Segment] = []
	var index: int = 0
	for w: Array in words:
		if w.is_empty():
			segs.append(_pause(0.16 / tempo))
			continue
		for s: int in w.size():
			var syl: Array = w[s]
			var stressed: bool = (w.size() >= 2 and s == w.size() - 2) or w.size() == 1
			var t0: float = float(index) / maxf(total, 1)
			var t1: float = float(index + 1) / maxf(total, 1)
			var last: bool = index == total - 1
			var p0: float = _contour(t0, mood) * (1.12 if stressed else 1.0)
			var p1: float = _contour(t1, mood) * (1.05 if stressed else 0.97)
			if last and question:
				p1 = p0 * 1.35
			elif last:
				p1 *= 0.9
			var onset: String = syl[0]
			var vowel: String = syl[1]
			var coda: String = syl[2]
			var vf: Vector3 = VOWEL_FORMANTS[vowel] * profile.formant_scale
			if not onset.is_empty():
				segs.append_array(_consonant(onset, vf, tempo, p0))
			var v: Segment = Segment.new()
			v.kind = &"vowel"
			v.duration = (0.15 if stressed else 0.105) / tempo + (0.05 if last else 0.0)
			v.formants = vf
			v.voiced = 1.0
			v.amp = 1.0 if stressed else 0.8
			v.pitch = Vector2(p0, p1)
			segs.append(v)
			if not coda.is_empty():
				segs.append_array(_consonant(coda, vf, tempo, p1))
			index += 1
		segs.append(_pause(0.045 / tempo))
	return segs


## Contour d'intonation (multiplicateur de f0) à la position `t` (0..1).
static func _contour(t: float, mood: StringName) -> float:
	var decl: float = 1.06 - 0.14 * t
	match mood:
		MOOD_ANGRY:
			return 1.18 + 0.1 * sin(t * PI) - 0.1 * t
		MOOD_NERVOUS:
			return 1.12 + 0.05 * sin(t * 9.0)
		MOOD_RELIEVED:
			return 1.08 - 0.22 * t
		MOOD_SHRUG:
			return 0.98 - 0.1 * t
		MOOD_PA:
			return 1.0
	return decl


static func _pause(duration: float) -> Segment:
	var s: Segment = Segment.new()
	s.kind = &"pause"
	s.duration = duration
	s.amp = 0.0
	return s


static func _consonant(c: String, vf: Vector3, tempo: float, pitch: float) -> Array[Segment]:
	var out: Array[Segment] = []
	var s: Segment = Segment.new()
	s.pitch = Vector2(pitch, pitch)
	s.formants = vf
	match c:
		"m", "n":
			s.kind = &"nasal"
			s.duration = 0.065 / tempo
			s.formants = NASAL_FORMANTS * (1.0 if c == "m" else 1.1)
			s.voiced = 1.0
			s.amp = 0.45
		"l", "r":
			s.kind = &"liquid"
			s.duration = (0.05 if c == "l" else 0.035) / tempo
			s.formants = Vector3(380, 1300 if c == "l" else 1150, 2600 if c == "l" else 1700)
			s.voiced = 1.0
			s.amp = 0.55 if c == "l" else 0.4
		"s", "sh":
			s.kind = &"fric"
			s.duration = 0.09 / tempo
			s.noise = 0.55 if c == "s" else 0.6
			s.noise_freq = 5200.0 if c == "s" else 2800.0
			s.amp = 1.0
		"v":
			s.kind = &"fric"
			s.duration = 0.06 / tempo
			s.voiced = 0.6
			s.noise = 0.2
			s.noise_freq = 3500.0
			s.formants = Vector3(250, 1200, 2300)
			s.amp = 0.6
		"h":
			s.kind = &"aspir"
			s.duration = 0.055 / tempo
			s.noise = 0.5
			s.amp = 0.6
		_: # p t k
			var closure: Segment = _pause(0.045 / tempo)
			out.append(closure)
			s.kind = &"stop"
			s.duration = 0.018
			s.noise = 0.9
			s.noise_freq = {"p": 900.0, "t": 4200.0, "k": 2000.0}.get(c, 2000.0)
			s.amp = 1.0
	out.append(s)
	return out


## Rend une réplique. `mood` : voir `MOOD_*`. Résultat mono 16 kHz.
static func render(phrase: String, profile: Profile, mood: StringName = MOOD_NEUTRAL) -> AudioStreamWAV:
	return AudioDsp.to_wav(synthesize(phrase, profile, mood), SAMPLE_RATE)


## Synthèse brute (tampon −1..1, crête `PEAK_DB`).
static func synthesize(phrase: String, profile: Profile, mood: StringName = MOOD_NEUTRAL) -> PackedFloat32Array:
	var segs: Array[Segment] = segments_for(phrase, profile, mood)
	var sr: float = SAMPLE_RATE
	var total_sec: float = 0.0
	for s: Segment in segs:
		total_sec += s.duration
	var n: int = int(total_sec * sr) + int(0.06 * sr)
	var out: PackedFloat32Array = AudioDsp.silence(n)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = profile.voice_seed ^ SeededRng.hash_string(phrase)
	var f0: float = profile.f0 * (1.12 if mood == MOOD_ANGRY else 1.0)
	var jitter: float = profile.jitter * (2.0 if mood == MOOD_NERVOUS else 1.0)
	var breath: float = profile.breath + (0.12 if mood == MOOD_RELIEVED or mood == MOOD_SHRUG else 0.0)
	var loud: float = 1.0
	# État des filtres : 3 résonateurs (y1, y2), bruit filtré, lissages.
	var r1: Vector2 = Vector2.ZERO
	var r2: Vector2 = Vector2.ZERO
	var r3: Vector2 = Vector2.ZERO
	var nz: Vector4 = Vector4.ZERO # x1, x2, y1, y2 du passe-bande de bruit
	var cur_f: Vector3 = segs[0].formants if not segs.is_empty() else Vector3(500, 1500, 2500)
	var cur_amp: float = 0.0
	var cur_voiced: float = 0.0
	var cur_noise: float = 0.0
	var phase: float = 0.0
	var period_jit: float = 1.0
	var prev_g: float = 0.0
	var smooth_f: float = 1.0 - exp(-1.0 / (0.022 * sr))
	var smooth_a: float = 1.0 - exp(-1.0 / (0.006 * sr))
	var c1: Vector3 = Vector3.ZERO
	var c2: Vector3 = Vector3.ZERO
	var c3: Vector3 = Vector3.ZERO
	var nc: PackedFloat32Array = AudioDsp.biquad_coeffs(AudioDsp.Filter.BANDPASS, 4000.0, 1.2, SAMPLE_RATE)
	var i: int = int(0.01 * sr)
	var vib_phase: float = rng.randf() * TAU
	for s: Segment in segs:
		var ns: int = maxi(int(s.duration * sr), 1)
		if s.noise > 0.0:
			nc = AudioDsp.biquad_coeffs(AudioDsp.Filter.BANDPASS, minf(s.noise_freq, sr * 0.45), 1.4, SAMPLE_RATE)
		for k: int in ns:
			if i >= n:
				break
			var t: float = float(k) / ns
			cur_f += (s.formants - cur_f) * smooth_f
			cur_amp += (s.amp * loud - cur_amp) * smooth_a
			cur_voiced += (s.voiced - cur_voiced) * smooth_a
			cur_noise += (s.noise - cur_noise) * smooth_a
			if k % 16 == 0:
				c1 = _reson(cur_f.x, 80.0, sr)
				c2 = _reson(cur_f.y, 110.0, sr)
				c3 = _reson(cur_f.z, 170.0, sr)
			# Source glottique (Rosenberg dérivée) + souffle.
			var pitch: float = lerpf(s.pitch.x, s.pitch.y, t) if s.voiced > 0.0 else 1.0
			vib_phase += TAU * 5.5 / sr
			var freq: float = f0 * pitch * period_jit * (1.0 + profile.vibrato * sin(vib_phase))
			phase += freq / sr
			if phase >= 1.0:
				phase -= 1.0
				period_jit = 1.0 + rng.randfn(0.0, jitter)
			var g: float = 0.0
			if phase < 0.6:
				g = 0.5 * (1.0 - cos(PI * phase / 0.6))
			elif phase < 0.75:
				g = cos(0.5 * PI * (phase - 0.6) / 0.15)
			var dg: float = (g - prev_g) * 18.0
			prev_g = g
			var white: float = rng.randf() * 2.0 - 1.0
			var src: float = dg * cur_voiced + white * breath * cur_voiced * 0.5
			# Aspiration : bruit dans les formants.
			if s.kind == &"aspir":
				src += white * cur_noise * 0.9
			var y1: float = c1.x * src + c1.y * r1.x + c1.z * r1.y
			r1 = Vector2(y1, r1.x)
			var y2: float = c2.x * src + c2.y * r2.x + c2.z * r2.y
			r2 = Vector2(y2, r2.x)
			var y3: float = c3.x * src + c3.y * r3.x + c3.z * r3.y
			r3 = Vector2(y3, r3.x)
			var voice: float = y1 + 0.55 * y2 + 0.25 * y3
			# Bruit de friction / explosion (passe-bande dédié).
			var fric: float = 0.0
			if cur_noise > 0.001 and s.kind != &"aspir":
				fric = nc[0] * white + nc[1] * nz.x + nc[2] * nz.y - nc[3] * nz.z - nc[4] * nz.w
				nz = Vector4(white, nz.x, fric, nz.z)
				fric *= cur_noise * 2.2
			out[i] = (voice * 0.9 + fric) * cur_amp
			i += 1
	out = AudioDsp.filter(out, AudioDsp.Filter.HIGHPASS, 90.0, 0.7, SAMPLE_RATE)
	out = AudioDsp.fade(out, 0.004, 0.02, SAMPLE_RATE)
	return AudioDsp.normalize(out, PEAK_DB)


## Résonateur 2 pôles à gain ~unitaire : (a0, b1, b2).
static func _reson(freq: float, bw: float, sr: float) -> Vector3:
	var r: float = exp(-PI * bw / sr)
	var f: float = minf(freq, sr * 0.45)
	var b1: float = 2.0 * r * cos(TAU * f / sr)
	var b2: float = -r * r
	return Vector3(1.0 - r, b1, b2)
