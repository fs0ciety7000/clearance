## Générateur pseudo-aléatoire déterministe (ARCHITECTURE §9.1, principe P4).
##
## Enveloppe un `RandomNumberGenerator` seedé et fournit le mélange de graines
## « maison » (finaliseur SplitMix64) utilisé pour dériver
## `day_seed = mix(campaign_seed, day_number)` et
## `case_seed = mix(day_seed, case_index)`.
## On n'utilise pas `hash()` de Godot, dont la stabilité entre versions n'est
## pas garantie.
##
## Interdits ailleurs dans le code : `randi()`, `randf()`, `Array.shuffle()`,
## `Array.pick_random()` (RNG global). Utiliser cette classe.
##
## Note : les entiers GDScript sont 64 bits signés et les débordements
## arithmétiques bouclent (comportement documenté de `int`), ce qui permet
## d'implémenter SplitMix64 directement.
class_name SeededRng
extends RefCounted

## 0x9E3779B97F4A7C15 (nombre d'or 64 bits), en entier signé.
const GOLDEN_GAMMA: int = -7046029254386353131
## 0xBF58476D1CE4E5B9
const MIX_MUL_1: int = -4658895280553007687
## 0x94D049BB133111EB
const MIX_MUL_2: int = -7723592293110705685
## FNV-1a 64 : offset basis 0xCBF29CE484222325 et prime 0x100000001B3.
const FNV_OFFSET: int = -3750763034362895579
const FNV_PRIME: int = 1099511628211

var _seed: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	_seed = p_seed
	_rng.seed = p_seed


# ---------------------------------------------------------------------------
# Mélange de graines (statique, pur)
# ---------------------------------------------------------------------------

## Décalage logique à droite (les `>>` GDScript sont arithmétiques).
static func _lsr(x: int, bits: int) -> int:
	return (x >> bits) & ((1 << (64 - bits)) - 1)


## Finaliseur SplitMix64 : bijection 64 bits à forte avalanche.
static func avalanche(x: int) -> int:
	var z: int = x
	z = (z ^ _lsr(z, 30)) * MIX_MUL_1
	z = (z ^ _lsr(z, 27)) * MIX_MUL_2
	return z ^ _lsr(z, 31)


## Combine deux entiers en une graine dérivée. Non commutatif :
## `mix(a, b) != mix(b, a)` en général.
static func mix(a: int, b: int) -> int:
	return avalanche(a ^ avalanche(b + GOLDEN_GAMMA))


## Combine trois entiers (ex. `mix3(day_seed, index, attempt)`, §9.3).
static func mix3(a: int, b: int, c: int) -> int:
	return mix(mix(a, b), c)


## Hachage FNV-1a 64 d'une chaîne (UTF-8), stable entre versions de Godot.
## Sert à saler une graine avec un identifiant (ex. `&"faction"`).
static func hash_string(text: String) -> int:
	var h: int = FNV_OFFSET
	for byte: int in text.to_utf8_buffer():
		h = (h ^ byte) * FNV_PRIME
	return h


## Combine une graine et un sel textuel : `mix(a, hash_string(salt))`.
static func mix_string(a: int, salt: String) -> int:
	return mix(a, hash_string(salt))


## Graine d'un jour de campagne.
static func day_seed(campaign_seed: int, day_number: int) -> int:
	return mix(campaign_seed, day_number)


## Graine d'un cas dans un jour.
static func case_seed(p_day_seed: int, case_index: int) -> int:
	return mix(p_day_seed, case_index)


# ---------------------------------------------------------------------------
# Tirages
# ---------------------------------------------------------------------------

## Graine d'origine de ce générateur.
func get_seed() -> int:
	return _seed


## Remet le générateur dans son état initial.
func reset() -> void:
	_rng.seed = _seed


## Nouveau générateur indépendant dérivé de cette graine et d'un sel.
## Ne consomme aucun tirage de ce générateur.
func fork(salt: int) -> SeededRng:
	return SeededRng.new(mix(_seed, salt))


## Entier non signé 32 bits dans [0, 2^32 - 1].
func next_u32() -> int:
	return _rng.randi()


## Entier dans [from, to] (bornes incluses).
@warning_ignore("shadowed_global_identifier")
func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Flottant dans [0, 1].
@warning_ignore("shadowed_global_identifier")
func randf() -> float:
	return _rng.randf()


## Flottant dans [from, to].
@warning_ignore("shadowed_global_identifier")
func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)


## Vrai avec la probabilité `p` (0..1).
func chance(p: float) -> bool:
	if p <= 0.0:
		return false
	if p >= 1.0:
		return true
	return _rng.randf() < p


## Élément uniforme de `items` ; `null` (+ erreur) si vide.
func pick(items: Array) -> Variant:
	if items.is_empty():
		push_error("SeededRng.pick: tableau vide (seed %d)" % _seed)
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Index tiré proportionnellement à `weights` (poids négatifs = 0).
## Renvoie -1 si la somme des poids est nulle.
func weighted_index(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	var last_positive: int = -1
	for i: int in weights.size():
		if weights[i] > 0.0:
			total += weights[i]
			last_positive = i
	if last_positive < 0:
		return -1
	var r: float = _rng.randf() * total
	var acc: float = 0.0
	for i: int in weights.size():
		if weights[i] <= 0.0:
			continue
		acc += weights[i]
		if r < acc:
			return i
	# r == total (randf est inclusif) ou erreur d'arrondi.
	return last_positive


## Élément de `items` tiré selon `weights` (même taille) ; `null` si impossible.
func weighted_pick(items: Array, weights: PackedFloat32Array) -> Variant:
	if items.size() != weights.size():
		push_error("SeededRng.weighted_pick: %d éléments pour %d poids" % [items.size(), weights.size()])
		return null
	var index: int = weighted_index(weights)
	if index < 0:
		push_error("SeededRng.weighted_pick: somme des poids nulle (seed %d)" % _seed)
		return null
	return items[index]


## Trie des identifiants (`StringName`, `String`) par ordre alphabétique, en
## place. Finition M13 : `Array.sort()` ordonne les `StringName` par adresse
## interne, un ordre qui dépend de l'histoire du processus (une même graine
## tirait d'autres leurres après d'autres générations) ; tout tirage indexé
## dans une liste d'identifiants passe par ici.
static func sort_names(names: Array) -> void:
	names.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))


## Mélange de Fisher-Yates en place, déterministe.
func shuffle(items: Array) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp


## Copie mélangée (le tableau d'origine est intact ; le type est conservé).
func shuffled(items: Array) -> Array:
	var copy: Array = items.duplicate()
	shuffle(copy)
	return copy
