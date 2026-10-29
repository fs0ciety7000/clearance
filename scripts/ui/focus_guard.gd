## Focus d'appoint (M11, UI_FLOW §9) : quand une direction (croix, stick
## gauche, flèches, Tab) arrive alors qu'aucun contrôle de l'écran n'a le
## focus, le focus est donné au contrôle par défaut de l'écran (`fallback`,
## sinon le premier contrôle focalisable visible) au lieu d'être perdu. Ainsi
## chaque écran se navigue à la manette seule, même après un clic de souris
## ailleurs ou un changement de panneau.
## Défilement : actions `scroll_up` / `scroll_down` (stick droit, Pg↑ / Pg↓)
## sur le `ScrollContainer` qui contient le focus, sinon `scroll_target`,
## sinon le premier défilable visible de l'écran.
## Boîtes modales (QA-057) : tant qu'une boîte du groupe `MODAL_GROUP`
## (`ConfirmDialog`) est ouverte hors de l'écran gardé, le garde se tait — il
## ne ramène pas le focus derrière le voile.
## Enfant de l'écran qu'il garde (`ScreenBase`, `ComparisonUI`).
class_name FocusGuard
extends Node

## Groupe des boîtes modales ouvertes (`ConfirmDialog`).
const MODAL_GROUP: StringName = &"ui_modal"
const DIRECTIONS: Array[StringName] = [&"ui_up", &"ui_down", &"ui_left", &"ui_right", &"ui_focus_next", &"ui_focus_prev"]

## Racine gardée : seuls ses descendants comptent comme « focus dans l'écran ».
var root: Control = null
## `func() -> Control` : contrôle par défaut (null : premier focalisable).
var fallback: Callable = Callable()
## `func() -> ScrollContainer` : zone défilée par défaut (optionnel).
var scroll_target: Callable = Callable()

## Vitesse de défilement à fond (px logiques / s).
const SCROLL_SPEED: float = 900.0


static func attach(p_root: Control, p_fallback: Callable = Callable()) -> FocusGuard:
	var guard: FocusGuard = FocusGuard.new()
	guard.name = "FocusGuard"
	guard.root = p_root
	guard.fallback = p_fallback
	p_root.add_child(guard)
	return guard


func _process(delta: float) -> void:
	if root == null or not root.is_visible_in_tree():
		return
	var strength: float = Input.get_axis(&"scroll_up", &"scroll_down")
	if is_zero_approx(strength):
		return
	var scroll: ScrollContainer = scroll_container()
	if scroll != null:
		scroll.scroll_vertical += roundi(strength * SCROLL_SPEED * delta)


## Zone défilée : celle du focus, sinon `scroll_target`, sinon la première
## zone visible qui a du contenu à faire défiler.
func scroll_container() -> ScrollContainer:
	var owner_control: Control = root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	var node: Node = owner_control
	while node != null and node != root.get_parent():
		var found: ScrollContainer = node as ScrollContainer
		if found != null and found.is_visible_in_tree():
			return found
		node = node.get_parent()
	if scroll_target.is_valid():
		var target: ScrollContainer = scroll_target.call() as ScrollContainer
		if target != null and target.is_visible_in_tree():
			return target
	return _first_scrollable(root)


static func _first_scrollable(node: Node) -> ScrollContainer:
	for child: Node in node.get_children():
		var scroll: ScrollContainer = child as ScrollContainer
		if scroll != null and scroll.is_visible_in_tree() and scroll.get_v_scroll_bar().max_value > scroll.size.y + 1.0:
			return scroll
		var found: ScrollContainer = _first_scrollable(child)
		if found != null:
			return found
	return null


func _input(event: InputEvent) -> void:
	if root == null or not root.is_visible_in_tree() or event.is_echo() or not event.is_pressed():
		return
	var direction: bool = false
	for action: StringName in DIRECTIONS:
		if event.is_action_pressed(action, false, true):
			direction = true
			break
	if not direction or has_focus_inside() or modal_over(root):
		return
	if focus_default():
		get_viewport().set_input_as_handled()


## Vrai si une boîte modale visible (`MODAL_GROUP`) recouvre `node` : une
## boîte qui n'est ni `node`, ni l'un de ses descendants, ni l'un de ses
## ancêtres (QA-057 : la croix et Ⓐ restent dans la boîte).
static func modal_over(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	for modal: Node in node.get_tree().get_nodes_in_group(MODAL_GROUP):
		var control: Control = modal as Control
		if control == null or control.is_queued_for_deletion() or not control.is_visible_in_tree():
			continue
		if control == node or node.is_ancestor_of(control) or control.is_ancestor_of(node):
			continue
		return true
	return false


## Rend le focus à la boîte modale ouverte (dernière ouverte) : son premier
## contrôle focalisable (ANNULER d'une `ConfirmDialog`). Faux si aucune.
static func focus_modal(tree: SceneTree) -> bool:
	if tree == null:
		return false
	var modals: Array[Node] = tree.get_nodes_in_group(MODAL_GROUP)
	for i: int in range(modals.size() - 1, -1, -1):
		var control: Control = modals[i] as Control
		if control == null or control.is_queued_for_deletion() or not control.is_visible_in_tree():
			continue
		var target: Control = first_focusable(control)
		if target != null:
			target.grab_focus()
			return true
	return false


## Vrai si un contrôle visible de l'écran a le focus.
func has_focus_inside() -> bool:
	var owner_control: Control = root.get_viewport().gui_get_focus_owner() if root.is_inside_tree() else null
	return owner_control != null and owner_control.is_visible_in_tree() and (owner_control == root or root.is_ancestor_of(owner_control))


## Donne le focus au contrôle par défaut ; faux si rien n'est focalisable.
func focus_default() -> bool:
	var target: Control = null
	if fallback.is_valid():
		target = fallback.call() as Control
	if target == null or not target.is_visible_in_tree() or target.focus_mode == Control.FOCUS_NONE:
		target = first_focusable(root)
	if target == null:
		return false
	target.grab_focus()
	return true


## Premier descendant visible, focalisable et actif (ordre de l'arbre).
static func first_focusable(node: Node) -> Control:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null:
			if not control.is_visible_in_tree():
				continue
			var button: BaseButton = control as BaseButton
			if control.focus_mode == Control.FOCUS_ALL and not (button != null and button.disabled):
				return control
		var found: Control = first_focusable(child)
		if found != null:
			return found
	return null
