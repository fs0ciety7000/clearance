## Décor 2D de la **démo** uniquement : remplace la vue 3D du guichet (bande B,
## y 56 → 432) par une vitre stylisée et un passager placeholder, pour tester
## `ComparisonUI` seule. Le vrai guichet est `scenes/booth/` (Godot Architect).
## Clic sur le visage en Mode Inspection → `inspection_target_picked(face)`.
class_name DemoBoothBackdrop
extends Control

const GLASS: Rect2 = Rect2(520, 72, 880, 336)
const ACTOR_SIZE: Vector2 = Vector2(260, 300)
## Repère au sol (centre de la vitre).
const DESK_X: float = 960.0

var actor: PortraitView = null
var inspection_active: bool = false
var slot_glow: float = 0.0
var _rain_time: float = 0.0
var _frame: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor = PortraitView.new()
	actor.framed = false
	actor.size = ACTOR_SIZE
	actor.position = Vector2(-ACTOR_SIZE.x, GLASS.end.y - ACTOR_SIZE.y)
	actor.mouse_filter = Control.MOUSE_FILTER_STOP
	actor.gui_input.connect(_on_actor_input)
	add_child(actor)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(draw_frame.bind(_frame))
	add_child(_frame)
	EventBus.inspection_mode_changed.connect(_on_inspection_mode_changed)


## Rectangle global du visage (cadre « VISAGE », ancre des liens).
func face_rect() -> Rect2:
	var head: Rect2 = Rect2(actor.position + Vector2(ACTOR_SIZE.x * 0.22, ACTOR_SIZE.y * 0.12), Vector2(ACTOR_SIZE.x * 0.56, ACTOR_SIZE.y * 0.6))
	return Rect2(get_global_transform() * head.position, head.size)


func walk_in(appearance: PassengerAppearance, duration: float) -> void:
	actor.appearance = appearance
	actor.position.x = GLASS.position.x - ACTOR_SIZE.x * 0.3
	var tween: Tween = create_tween()
	tween.tween_property(actor, "position:x", DESK_X - ACTOR_SIZE.x * 0.5, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func walk_out(approved: bool, duration: float) -> void:
	var target: float = GLASS.end.x + ACTOR_SIZE.x if approved else GLASS.position.x - ACTOR_SIZE.x
	create_tween().tween_property(actor, "position:x", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func flash_slot() -> void:
	slot_glow = 1.0


func _process(delta: float) -> void:
	_rain_time += delta
	slot_glow = maxf(slot_glow - delta / (DS.DUR_DRAMATIC * 2.0), 0.0)
	queue_redraw()
	_frame.queue_redraw()


func _on_inspection_mode_changed(enabled: bool) -> void:
	inspection_active = enabled
	actor.mouse_default_cursor_shape = Control.CURSOR_CROSS if enabled else Control.CURSOR_ARROW


func _on_actor_input(event: InputEvent) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT and inspection_active:
		EventBus.inspection_target_picked.emit(FieldRef.passenger_face())


func _draw() -> void:
	var band: Rect2 = Rect2(0, 56, size.x, 376)
	draw_rect(band, DS.BG_VOID)
	# Ville derrière la vitre : blocs désaturés, enseignes sobres (décor ≠ cyan).
	draw_rect(GLASS, DS.BG_PANEL)
	var x: float = GLASS.position.x + 40.0
	var i: int = 0
	while x < GLASS.end.x - 40.0:
		var h: float = 80.0 + float((i * 53) % 150)
		draw_rect(Rect2(x, GLASS.end.y - h - 40.0, 60.0 + float((i * 17) % 40), h), DS.BG_ELEVATED)
		x += 110.0
		i += 1
	draw_rect(Rect2(GLASS.position.x + 48, GLASS.position.y + 24, 40, 220), DS.YELLOW_12)
	draw_rect(Rect2(GLASS.position.x + 48, GLASS.position.y + 24, 40, 220), DS.YELLOW_24, false, 2.0)
	# Pluie.
	var rain: Color = Color(Palette.TEXT_SECONDARY, 0.12)
	for n: int in 70:
		var rx: float = GLASS.position.x + fposmod(n * 97.0 + _rain_time * 30.0, GLASS.size.x)
		var ry: float = GLASS.position.y + fposmod(n * 61.0 + _rain_time * 420.0, GLASS.size.y)
		draw_line(Vector2(rx, ry), Vector2(rx - 2.0, ry + 14.0), rain, 1.0)
	# Sol / repère.
	draw_rect(Rect2(GLASS.position.x, GLASS.end.y - 40, GLASS.size.x, 40), DS.BG_VOID.lerp(DS.BG_PANEL, 0.6))


## Cadre métallique, reflet, hygiaphone, fente : dessinés par-dessus l'acteur.
func draw_frame(canvas: Control) -> void:
	var metal: Color = DS.TEXT_MUTED
	canvas.draw_rect(GLASS, metal, false, 6.0)
	canvas.draw_rect(GLASS.grow(-6.0), Palette.LINE_SUBTLE, false, 2.0)
	# Reflet diagonal léger.
	var reflection: PackedVector2Array = [GLASS.position + Vector2(GLASS.size.x * 0.55, 6), GLASS.position + Vector2(GLASS.size.x * 0.68, 6),
			GLASS.position + Vector2(GLASS.size.x * 0.48, GLASS.size.y - 6), GLASS.position + Vector2(GLASS.size.x * 0.35, GLASS.size.y - 6)]
	canvas.draw_colored_polygon(reflection, Color(DS.TEXT_PRIMARY, 0.025))
	# Hygiaphone.
	var hygia: Vector2 = Vector2(GLASS.position.x + 78, GLASS.end.y - 64)
	canvas.draw_circle(hygia, 40.0, DS.BG_VOID)
	canvas.draw_arc(hygia, 40.0, 0.0, TAU, 40, metal, 3.0, true)
	for row: int in range(-3, 4):
		for col: int in range(-3, 4):
			if row * row + col * col <= 10:
				canvas.draw_circle(hygia + Vector2(col, row) * 9.0, 2.0, Palette.LINE_SUBTLE)
	# Fente à documents.
	var slot: Rect2 = Rect2(DESK_X - 120, GLASS.end.y - 8, 240, 14)
	canvas.draw_rect(slot, DS.BG_VOID)
	canvas.draw_rect(slot, metal, false, 2.0)
	if slot_glow > 0.0:
		canvas.draw_rect(slot.grow(-3.0), Color(DS.ACCENT_CYAN, slot_glow))
