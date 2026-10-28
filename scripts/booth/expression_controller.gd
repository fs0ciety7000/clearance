## Micro-expressions du passager (ARCHITECTURE §8 bis.5, BOOTH_SCENE §10.3).
##
## Pilote les uniformes de `face_dither.gdshader` : une expression = (cellule
## yeux, cellule bouche) ; transition par fondu de seuil de dither (120 ms).
## Clignements à intervalle tiré d'un RNG seedé par le `case_id` (cosmétique
## mais reproductible), alternance `talk_a/talk_b` pendant une réplique.
## « Réduire les animations » : transitions instantanées.
class_name ExpressionController
extends Node

const TRANSITION_SEC: float = 0.12
const BLINK_SEC: float = 0.12
const TALK_SWAP_SEC: float = 0.14
const KEEP: int = -1

## id → [cellule yeux, cellule bouche] (`KEEP` = inchangée).
const EXPRESSIONS: Dictionary[StringName, Array] = {
	&"neutral": [FaceAtlas.EYES_NEUTRAL, FaceAtlas.MOUTH_NEUTRAL],
	&"blink": [FaceAtlas.EYES_CLOSED, KEEP],
	&"talk_a": [KEEP, FaceAtlas.MOUTH_OPEN_A],
	&"talk_b": [KEEP, FaceAtlas.MOUTH_OPEN_O],
	&"nervous": [FaceAtlas.EYES_NERVOUS, FaceAtlas.MOUTH_GRIMACE],
	&"angry": [FaceAtlas.EYES_ANGRY, FaceAtlas.MOUTH_CLENCHED],
	&"relieved": [FaceAtlas.EYES_RELIEVED, FaceAtlas.MOUTH_SMILE],
	&"suspicious": [FaceAtlas.EYES_SUSPICIOUS, FaceAtlas.MOUTH_TIGHT],
	&"contempt": [FaceAtlas.EYES_SUSPICIOUS, FaceAtlas.MOUTH_SMILE],
	&"sad": [FaceAtlas.EYES_SAD, FaceAtlas.MOUTH_POUT],
	&"wink": [FaceAtlas.EYES_WINK, FaceAtlas.MOUTH_SMILE],
}

var material: ShaderMaterial = null
var base: StringName = &"neutral"
var paused: bool = false
var instant: bool = false

var _held: StringName = &""
var _hold_left: float = 0.0
var _talking: bool = false
var _talk_left: float = 0.0
var _talk_open_a: bool = true
var _blink_left: float = 0.0
var _next_blink: float = 3.0
var _eyes: int = FaceAtlas.EYES_NEUTRAL
var _mouth: int = FaceAtlas.MOUTH_NEUTRAL
var _blend: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(p_material: ShaderMaterial, rng_seed: int) -> void:
	material = p_material
	_rng.seed = rng_seed
	base = &"neutral"
	_held = &""
	_hold_left = 0.0
	_talking = false
	_next_blink = _rng.randf_range(2.0, 5.0)
	_apply_cells(FaceAtlas.EYES_NEUTRAL, FaceAtlas.MOUTH_NEUTRAL, true)


## Expression de base, ou temporaire si `hold_sec > 0` (retour à la base ensuite).
func set_expression(id: StringName, hold_sec: float = 0.0) -> void:
	if not EXPRESSIONS.has(id):
		push_warning("ExpressionController: expression inconnue « %s »" % id)
		return
	if hold_sec > 0.0:
		_held = id
		_hold_left = hold_sec
	else:
		base = id
		_held = &""
	_refresh()


func set_talking(talking: bool) -> void:
	_talking = talking
	_talk_left = 0.0
	_refresh()


func current_expression() -> StringName:
	return _held if _held != &"" else base


func _process(delta: float) -> void:
	if material == null or paused:
		return
	if _hold_left > 0.0:
		_hold_left -= delta
		if _hold_left <= 0.0:
			_held = &""
			_refresh()
	if _talking:
		_talk_left -= delta
		if _talk_left <= 0.0:
			_talk_left = TALK_SWAP_SEC
			_talk_open_a = not _talk_open_a
			_refresh()
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			_refresh()
	else:
		_next_blink -= delta
		if _next_blink <= 0.0:
			_next_blink = _rng.randf_range(2.0, 6.0)
			_blink_left = BLINK_SEC
			_refresh()
	if _blend < 1.0:
		_blend = minf(_blend + delta / TRANSITION_SEC, 1.0)
		material.set_shader_parameter(&"blend", _blend)


func _refresh() -> void:
	if material == null:
		return
	var cells: Array = EXPRESSIONS[current_expression()]
	var eyes: int = cells[0] if cells[0] != KEEP else _eyes
	var mouth: int = cells[1] if cells[1] != KEEP else _mouth
	if _talking:
		mouth = FaceAtlas.MOUTH_OPEN_A if _talk_open_a else FaceAtlas.MOUTH_OPEN_O
	if _blink_left > 0.0:
		# Clignement : coupe franche (pas de fondu).
		material.set_shader_parameter(&"eyes_from", FaceAtlas.EYES_CLOSED)
		material.set_shader_parameter(&"eyes_to", FaceAtlas.EYES_CLOSED)
		return
	_apply_cells(eyes, mouth, instant or _talking)


func _apply_cells(eyes: int, mouth: int, cut: bool) -> void:
	if cut:
		_blend = 1.0
		material.set_shader_parameter(&"eyes_from", eyes)
		material.set_shader_parameter(&"mouth_from", mouth)
	else:
		material.set_shader_parameter(&"eyes_from", _eyes)
		material.set_shader_parameter(&"mouth_from", _mouth)
		_blend = 0.0
	_eyes = eyes
	_mouth = mouth
	material.set_shader_parameter(&"eyes_to", eyes)
	material.set_shader_parameter(&"mouth_to", mouth)
	material.set_shader_parameter(&"blend", _blend)
