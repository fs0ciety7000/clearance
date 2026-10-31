## Sonie ITU-R BS.1770-4 / EBU R128 hors temps réel (M14 ; docs/AUDIO.md
## §13.5) : pondération K, blocs de 400 ms (recouvrement 75 %), portes
## absolue (−70 LUFS) et relative (−10 LU). Sert au rendu (gains des niveaux
## N0 → N4 de `tools/build_music.gd`) et à l'audit ; recoupée par ffmpeg
## (`ebur128`) dans `tools/qa_audio_audit.gd` (écart attendu ≤ 0,2 LU).
## Classe-espace de noms : jamais instanciée.
class_name AudioLoudness
extends RefCounted

const ABS_GATE_LUFS: float = -70.0
const REL_GATE_LU: float = -10.0
## Sous-bloc de 100 ms : un bloc de 400 ms = 4 sous-blocs consécutifs.
const SUB_BLOCK_SEC: float = 0.1


## Coefficients des deux étages de pondération K à `rate` (libebur128) :
## [b0, b1, b2, a1, a2] × 2.
static func k_coeffs(rate: int) -> Array[PackedFloat64Array]:
	var f0: float = 1681.974450955533
	var g: float = 3.999843853973347
	var q: float = 0.7071752369554196
	var k: float = tan(PI * f0 / rate)
	var vh: float = pow(10.0, g / 20.0)
	var vb: float = pow(vh, 0.4996667741545416)
	var a0: float = 1.0 + k / q + k * k
	var shelf: PackedFloat64Array = PackedFloat64Array([(vh + vb * k / q + k * k) / a0, 2.0 * (k * k - vh) / a0,
		(vh - vb * k / q + k * k) / a0, 2.0 * (k * k - 1.0) / a0, (1.0 - k / q + k * k) / a0])
	f0 = 38.13547087602444
	q = 0.5003270373238773
	k = tan(PI * f0 / rate)
	var d: float = 1.0 + k / q + k * k
	var hp: PackedFloat64Array = PackedFloat64Array([1.0, -2.0, 1.0, 2.0 * (k * k - 1.0) / d, (1.0 - k / q + k * k) / d])
	return [shelf, hp]


## Signal pondéré K (deux biquads en cascade, calcul en double précision).
static func k_weight(buf: PackedFloat32Array, rate: int) -> PackedFloat64Array:
	var stages: Array[PackedFloat64Array] = k_coeffs(rate)
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(buf.size())
	for i: int in buf.size():
		out[i] = buf[i]
	for c: PackedFloat64Array in stages:
		var x1: float = 0.0
		var x2: float = 0.0
		var y1: float = 0.0
		var y2: float = 0.0
		for i: int in out.size():
			var x: float = out[i]
			var y: float = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2
			x2 = x1
			x1 = x
			y2 = y1
			y1 = y
			out[i] = y
	return out


## Somme des carrés par sous-bloc de 100 ms, canaux additionnés.
static func sub_block_energy(channels: Array[PackedFloat64Array], rate: int) -> PackedFloat64Array:
	var sub: int = roundi(SUB_BLOCK_SEC * rate)
	var n: int = channels[0].size() if not channels.is_empty() else 0
	var count: int = n / sub
	var out: PackedFloat64Array = PackedFloat64Array()
	out.resize(count)
	for ch: PackedFloat64Array in channels:
		for b: int in count:
			var s: float = 0.0
			var base: int = b * sub
			for i: int in sub:
				var v: float = ch[base + i]
				s += v * v
			out[b] += s
	return out


## Sonie intégrée (LUFS) depuis les énergies des sous-blocs de 100 ms.
static func integrated_from_sub_blocks(energy: PackedFloat64Array, rate: int) -> float:
	var sub: int = roundi(SUB_BLOCK_SEC * rate)
	var powers: PackedFloat64Array = PackedFloat64Array()
	for b: int in range(0, energy.size() - 3):
		var z: float = (energy[b] + energy[b + 1] + energy[b + 2] + energy[b + 3]) / (4.0 * sub)
		powers.append(z)
	return integrated_from_powers(powers)


## Sonie intégrée depuis les puissances moyennes des blocs de 400 ms.
static func integrated_from_powers(powers: PackedFloat64Array) -> float:
	var abs_gate: float = pow(10.0, (ABS_GATE_LUFS + 0.691) / 10.0)
	var sum: float = 0.0
	var count: int = 0
	for z: float in powers:
		if z > abs_gate:
			sum += z
			count += 1
	if count == 0:
		return -INF
	var rel_gate: float = sum / count * pow(10.0, REL_GATE_LU / 10.0)
	sum = 0.0
	count = 0
	for z: float in powers:
		if z > abs_gate and z > rel_gate:
			sum += z
			count += 1
	if count == 0:
		return -INF
	return -0.691 + 10.0 * log(sum / count) / log(10.0)


## Sonie intégrée d'un signal stéréo (ou mono si `right` vide).
static func integrated(left: PackedFloat32Array, right: PackedFloat32Array, rate: int) -> float:
	var channels: Array[PackedFloat64Array] = [k_weight(left, rate)]
	if not right.is_empty():
		channels.append(k_weight(right, rate))
	return integrated_from_sub_blocks(sub_block_energy(channels, rate), rate)


## Sonie maximale à court terme (fenêtre de 3 s, pas de 100 ms).
static func max_short_term(left: PackedFloat32Array, right: PackedFloat32Array, rate: int) -> float:
	var channels: Array[PackedFloat64Array] = [k_weight(left, rate)]
	if not right.is_empty():
		channels.append(k_weight(right, rate))
	var energy: PackedFloat64Array = sub_block_energy(channels, rate)
	var sub: int = roundi(SUB_BLOCK_SEC * rate)
	var best: float = -INF
	for b: int in range(0, energy.size() - 29):
		var s: float = 0.0
		for k: int in 30:
			s += energy[b + k]
		var z: float = s / (30.0 * sub)
		if z > 0.0:
			best = maxf(best, -0.691 + 10.0 * log(z) / log(10.0))
	return best
