## Petite boîte à outils DSP hors temps réel (docs/AUDIO.md §8) : tampons
## `PackedFloat32Array` (−1..1), filtres biquad RBJ, enveloppes, mixage,
## conversion ↔ `AudioStreamWAV` PCM 16 bits.
##
## Utilisée par l'outil `tools/build_audio.gd` (génération des assets) et, à
## l'exécution, par `TessarVoice` (barks). Aucune dépendance à la scène.
## Classe-espace de noms : jamais instanciée.
class_name AudioDsp
extends RefCounted

enum Filter { LOWPASS, HIGHPASS, BANDPASS, PEAK }


## Silence de `n` échantillons.
static func silence(n: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(maxi(n, 0))
	return buf


static func samples(seconds: float, rate: int) -> int:
	return maxi(roundi(seconds * rate), 0)


## Bruit blanc uniforme (−1..1), reproductible.
static func white(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf: PackedFloat32Array = silence(n)
	for i: int in n:
		buf[i] = rng.randf() * 2.0 - 1.0
	return buf


## Bruit rose approché (filtre de Paul Kellet, version économique).
static func pink(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf: PackedFloat32Array = silence(n)
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	for i: int in n:
		var w: float = rng.randf() * 2.0 - 1.0
		b0 = 0.99765 * b0 + w * 0.0990460
		b1 = 0.96300 * b1 + w * 0.2965164
		b2 = 0.57000 * b2 + w * 1.0526913
		buf[i] = (b0 + b1 + b2 + w * 0.1848) * 0.2
	return buf


## Bruit brun (intégration fuyante du blanc) : grondements.
static func brown(n: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var buf: PackedFloat32Array = silence(n)
	var y: float = 0.0
	for i: int in n:
		y = y * 0.995 + (rng.randf() * 2.0 - 1.0) * 0.06
		buf[i] = y
	return buf


## Coefficients biquad RBJ normalisés : [b0, b1, b2, a1, a2].
static func biquad_coeffs(type: Filter, freq: float, q: float, rate: int, gain_db: float = 0.0) -> PackedFloat32Array:
	var f: float = clampf(freq, 10.0, rate * 0.49)
	var w0: float = TAU * f / rate
	var cw: float = cos(w0)
	var alpha: float = sin(w0) / (2.0 * maxf(q, 0.05))
	var b0: float = 0.0
	var b1: float = 0.0
	var b2: float = 0.0
	var a0: float = 1.0 + alpha
	var a1: float = -2.0 * cw
	var a2: float = 1.0 - alpha
	match type:
		Filter.LOWPASS:
			b0 = (1.0 - cw) * 0.5
			b1 = 1.0 - cw
			b2 = b0
		Filter.HIGHPASS:
			b0 = (1.0 + cw) * 0.5
			b1 = -(1.0 + cw)
			b2 = b0
		Filter.BANDPASS:
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		Filter.PEAK:
			var amp: float = pow(10.0, gain_db / 40.0)
			b0 = 1.0 + alpha * amp
			b1 = -2.0 * cw
			b2 = 1.0 - alpha * amp
			a0 = 1.0 + alpha / amp
			a1 = -2.0 * cw
			a2 = 1.0 - alpha / amp
	return PackedFloat32Array([b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0])


## Filtre biquad statique (en place sur une copie).
static func filter(buf: PackedFloat32Array, type: Filter, freq: float, q: float, rate: int, gain_db: float = 0.0) -> PackedFloat32Array:
	var c: PackedFloat32Array = biquad_coeffs(type, freq, q, rate, gain_db)
	var out: PackedFloat32Array = silence(buf.size())
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var b0: float = c[0]
	var b1: float = c[1]
	var b2: float = c[2]
	var a1: float = c[3]
	var a2: float = c[4]
	for i: int in buf.size():
		var x: float = buf[i]
		var y: float = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Filtre dont la fréquence suit linéairement `f_start → f_end` (balayage).
static func sweep(buf: PackedFloat32Array, type: Filter, f_start: float, f_end: float, q: float, rate: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = silence(buf.size())
	var x1: float = 0.0
	var x2: float = 0.0
	var y1: float = 0.0
	var y2: float = 0.0
	var c: PackedFloat32Array = PackedFloat32Array()
	var n: int = buf.size()
	for i: int in n:
		if i % 32 == 0:
			var t: float = float(i) / maxf(n - 1, 1)
			c = biquad_coeffs(type, lerpf(f_start, f_end, t), q, rate)
		var x: float = buf[i]
		var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		out[i] = y
	return out


## Passe-bas à un pôle (doux, sans résonance).
static func one_pole(buf: PackedFloat32Array, cutoff: float, rate: int) -> PackedFloat32Array:
	var a: float = 1.0 - exp(-TAU * cutoff / rate)
	var out: PackedFloat32Array = silence(buf.size())
	var y: float = 0.0
	for i: int in buf.size():
		y += a * (buf[i] - y)
		out[i] = y
	return out


## Enveloppe attaque linéaire / décroissance exponentielle (`decay` = τ en s).
static func env_ad(n: int, attack: float, decay: float, rate: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = silence(n)
	var na: int = maxi(samples(attack, rate), 1)
	var k: float = 1.0 / maxf(decay * rate, 1.0)
	for i: int in n:
		if i < na:
			buf[i] = float(i) / na
		else:
			buf[i] = exp(-(i - na) * k)
	return buf


## Enveloppe trapèze : attaque, maintien, relâchement (linéaires, en s).
static func env_ahr(n: int, attack: float, release: float, rate: int) -> PackedFloat32Array:
	var buf: PackedFloat32Array = silence(n)
	var na: int = maxi(samples(attack, rate), 1)
	var nr: int = maxi(samples(release, rate), 1)
	for i: int in n:
		var g: float = 1.0
		if i < na:
			g = float(i) / na
		var left: int = n - 1 - i
		if left < nr:
			g = minf(g, float(left) / nr)
		buf[i] = g
	return buf


## Produit échantillon par échantillon (tailles : celle de `a`).
static func mul(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = silence(a.size())
	var m: int = mini(a.size(), b.size())
	for i: int in m:
		out[i] = a[i] * b[i]
	return out


static func gain(buf: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = silence(buf.size())
	for i: int in buf.size():
		out[i] = buf[i] * g
	return out


## Ajoute `src × g` dans `dst` à partir de `offset` (agrandit `dst` si besoin).
static func mix_into(dst: PackedFloat32Array, src: PackedFloat32Array, offset: int, g: float = 1.0) -> PackedFloat32Array:
	var out: PackedFloat32Array = dst
	var need: int = offset + src.size()
	if need > out.size():
		out.resize(need)
	for i: int in src.size():
		var j: int = offset + i
		if j >= 0:
			out[j] += src[i] * g
	return out


static func peak(buf: PackedFloat32Array) -> float:
	var p: float = 0.0
	for v: float in buf:
		p = maxf(p, absf(v))
	return p


static func rms(buf: PackedFloat32Array) -> float:
	if buf.is_empty():
		return 0.0
	var s: float = 0.0
	for v: float in buf:
		s += v * v
	return sqrt(s / buf.size())


## Normalise la crête à `peak_db` dBFS.
static func normalize(buf: PackedFloat32Array, peak_db: float = -1.0) -> PackedFloat32Array:
	var p: float = peak(buf)
	if p <= 0.0:
		return buf
	return gain(buf, db_to_linear(peak_db) / p)


## Saturation douce (tanh), `drive` > 1 = plus de grain.
static func saturate(buf: PackedFloat32Array, drive: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = silence(buf.size())
	var norm: float = 1.0 / tanh(drive)
	for i: int in buf.size():
		out[i] = tanh(buf[i] * drive) * norm
	return out


## Fondu d'entrée/sortie (anti-clic).
static func fade(buf: PackedFloat32Array, fade_in: float, fade_out: float, rate: int) -> PackedFloat32Array:
	return mul(buf, env_ahr(buf.size(), fade_in, fade_out, rate))


## Rééchantillonnage linéaire (facteur > 1 = plus aigu / plus court).
static func resample(buf: PackedFloat32Array, ratio: float) -> PackedFloat32Array:
	var n: int = maxi(int(buf.size() / maxf(ratio, 0.01)), 1)
	var out: PackedFloat32Array = silence(n)
	var last: int = buf.size() - 1
	for i: int in n:
		var pos: float = i * ratio
		var j: int = int(pos)
		if j >= last:
			out[i] = buf[last] if last >= 0 else 0.0
		else:
			var t: float = pos - j
			out[i] = buf[j] * (1.0 - t) + buf[j + 1] * t
	return out


static func reverse(buf: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = buf.duplicate()
	out.reverse()
	return out


## Boucle sans clic : la fin (`xfade` s) est fondue enchaînée sur le début.
static func make_loop(buf: PackedFloat32Array, xfade: float, rate: int) -> PackedFloat32Array:
	var nx: int = mini(samples(xfade, rate), buf.size() >> 1)
	var n: int = buf.size() - nx
	var out: PackedFloat32Array = silence(n)
	for i: int in n:
		out[i] = buf[i]
	for i: int in nx:
		var t: float = float(i) / maxf(nx, 1)
		out[i] = buf[n + i] * (1.0 - t) + buf[i] * t
	return out


## Sinus amorti (partiel de cloche / clic métallique).
static func ping(freq: float, seconds: float, decay: float, rate: int, phase: float = 0.0) -> PackedFloat32Array:
	var n: int = samples(seconds, rate)
	var buf: PackedFloat32Array = silence(n)
	var w: float = TAU * freq / rate
	var k: float = 1.0 / maxf(decay * rate, 1.0)
	for i: int in n:
		buf[i] = sin(phase + w * i) * exp(-i * k)
	return buf


## Sinus à fréquence glissante (blips holographiques).
static func chirp(f_start: float, f_end: float, seconds: float, rate: int) -> PackedFloat32Array:
	var n: int = samples(seconds, rate)
	var buf: PackedFloat32Array = silence(n)
	var phase: float = 0.0
	for i: int in n:
		var t: float = float(i) / maxf(n - 1, 1)
		phase += TAU * lerpf(f_start, f_end, t) / rate
		buf[i] = sin(phase)
	return buf


## Dent de scie (non limitée en bande, à filtrer ensuite).
static func saw(freq: float, seconds: float, rate: int, detune: float = 0.0) -> PackedFloat32Array:
	var n: int = samples(seconds, rate)
	var buf: PackedFloat32Array = silence(n)
	var phase: float = detune
	var inc: float = freq / rate
	for i: int in n:
		phase = fposmod(phase + inc, 1.0)
		buf[i] = phase * 2.0 - 1.0
	return buf


## Espace léger (2 peignes en rétroaction + 1 passe-tout), `wet` 0..1 ;
## `offset_ms` décorrèle les canaux (gauche / droite).
static func space(buf: PackedFloat32Array, rate: int, wet: float, size: float = 1.0, offset_ms: float = 0.0) -> PackedFloat32Array:
	var d1: int = maxi(int((0.0297 * size + offset_ms * 0.001) * rate), 1)
	var d2: int = maxi(int((0.0371 * size + offset_ms * 0.0013) * rate), 1)
	var da: int = maxi(int(0.005 * rate), 1)
	var fb: float = 0.72
	var l1: PackedFloat32Array = silence(d1)
	var l2: PackedFloat32Array = silence(d2)
	var la: PackedFloat32Array = silence(da)
	var p1: int = 0
	var p2: int = 0
	var pa: int = 0
	var damp1: float = 0.0
	var damp2: float = 0.0
	var out: PackedFloat32Array = silence(buf.size())
	for i: int in buf.size():
		var x: float = buf[i]
		var o1: float = l1[p1]
		damp1 = o1 * 0.6 + damp1 * 0.4
		l1[p1] = x + damp1 * fb
		p1 = (p1 + 1) % d1
		var o2: float = l2[p2]
		damp2 = o2 * 0.6 + damp2 * 0.4
		l2[p2] = x + damp2 * fb
		p2 = (p2 + 1) % d2
		var comb: float = (o1 + o2) * 0.5
		var ao: float = la[pa]
		var ain: float = comb + ao * 0.5
		la[pa] = ain
		pa = (pa + 1) % da
		out[i] = x * (1.0 - wet * 0.5) + (ao - ain * 0.5) * wet
	return out


# --- AudioStreamWAV ----------------------------------------------------------

## Tampon(s) → `AudioStreamWAV` PCM 16 bits (mono si `right` vide).
static func to_wav(left: PackedFloat32Array, rate: int, right: PackedFloat32Array = PackedFloat32Array(), loop: bool = false) -> AudioStreamWAV:
	var stereo: bool = not right.is_empty()
	var n: int = left.size()
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * (4 if stereo else 2))
	for i: int in n:
		if stereo:
			data.encode_s16(i * 4, _to_s16(left[i]))
			data.encode_s16(i * 4 + 2, _to_s16(right[i] if i < right.size() else 0.0))
		else:
			data.encode_s16(i * 2, _to_s16(left[i]))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = stereo
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


## `AudioStreamWAV` 16 bits → tampon mono (moyenne des canaux).
static func from_wav(wav: AudioStreamWAV) -> PackedFloat32Array:
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return PackedFloat32Array()
	var data: PackedByteArray = wav.data
	var channels: int = 2 if wav.stereo else 1
	var n: int = data.size() >> channels # 2 octets × canaux (1 ou 2)
	var buf: PackedFloat32Array = silence(n)
	for i: int in n:
		var s: float = 0.0
		for c: int in channels:
			s += data.decode_s16((i * channels + c) * 2) / 32768.0
		buf[i] = s / channels
	return buf


static func _to_s16(v: float) -> int:
	return clampi(roundi(v * 32767.0), -32768, 32767)
