## Puce de déclaration du journal de dialogue (M13 lot C, I35 ; M13 §1.7,
## ARCHITECTURE §12.2) : une valeur dite par le passager (« trois semaines »,
## « Kessler-Ashe »), **sélectionnable en Mode Inspection comme un champ de
## document** (`FieldRef.statement(id)`), dans le geste A → B (journal ↔
## document, dans les deux sens).
##
## Repères (jamais la couleur seule, D-107) : glyphe `DS.STATEMENT_GLYPH` « » »
## devant la valeur et soulignement pointillé cyan ; réponse imprécise (VN-1) :
## glyphe « ≈ » et pointillé gris (le comparateur répond « réponse
## imprécise ») ; valeur barrée d'une auto-correction (VN-2) : trait en travers,
## non sélectionnable. Les états sélection (A), discordance (hachures et
## numéro) et concordance (coche) sont ceux de tout `InspectableItem`.
class_name StatementChipView
extends InspectableItem

const VAGUE_GLYPH: String = "≈"

var statement: Statement = null
## Valeur barrée (première valeur d'une auto-correction) : jamais comparable.
var struck: bool = false
## Ponctuation collée juste après (QA-070) : pas de marge de droite, le signe
## suit la valeur sans espace visible (« passer. » et non « passer . »).
var tight_end: bool = false:
	set(value):
		tight_end = value
		_sync_min_size()

var _glyph: Label = null
var _label: Label = null
var _box: HBoxContainer = null


## `variation` : style de texte de la réplique qui porte la puce.
func setup(p_statement: Statement, p_struck: bool = false, variation: StringName = &"BodyLabel") -> void:
	statement = p_statement
	struck = p_struck
	ref = FieldRef.statement(statement.id if statement != null else &"")
	comparable = not struck and statement != null
	name = "Chip_%s%s" % [statement.id if statement != null else &"none", "_struck" if struck else ""]
	var text: String = chip_text(statement, struck)
	display_label = text
	if statement != null and statement.vague:
		tooltip_text = UiText.t("disc_statement_vague", "Réponse imprécise : non comparable")
	elif struck:
		tooltip_text = UiText.t("jr_struck_tip", "Valeur corrigée par le passager : non comparable")
	_box = HBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", DS.SPACE_1)
	_box.position = Vector2(DS.SPACE_1, 0)
	add_child(_box)
	if not struck:
		_glyph = Label.new()
		# Glyphe en petit (repère, pas ponctuation) : la valeur garde la taille de la phrase.
		_glyph.theme_type_variation = &"DocFieldLabel"
		_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.text = VAGUE_GLYPH if statement != null and statement.vague else DS.STATEMENT_GLYPH
		_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_box.add_child(_glyph)
	_label = Label.new()
	_label.theme_type_variation = variation
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = text
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_box.add_child(_label)
	_box.minimum_size_changed.connect(_sync_min_size)
	_sync_min_size()
	_refresh_content()


## Texte de la puce : fragment traduit (ou valeur barrée d'une auto-correction).
static func chip_text(p_statement: Statement, p_struck: bool) -> String:
	if p_statement == null:
		return ""
	var translate: Callable = func(key: String) -> String: return UiText.t(key, key)
	var text: String = p_statement.struck_text(translate) if p_struck else p_statement.fragment_text(translate)
	return ComparisonUI.passenger_text(text)


func get_text() -> String:
	return _label.text if _label != null else ""


func is_vague() -> bool:
	return statement != null and statement.vague


func _sync_min_size() -> void:
	if _box == null:
		return
	var inner: Vector2 = _box.get_combined_minimum_size()
	_box.size = inner
	# Puce en ligne dans une phrase : cible un peu plus basse que `HIT_TARGET_MIN`
	# (la manette y va par le focus, DS §7.12), jamais sous la hauteur du texte.
	# Discordance (QA-070) : place réservée à droite pour le repère et la
	# pastille numérotée (①), qui ne se posent plus sur le texte de la puce.
	var end_pad: float = 0.0 if tight_end else float(DS.BORDER_STRONG)
	if is_flagged():
		end_pad = flag_reserve(flag_numbers.size())
	elif concordant:
		end_pad = DS.ICON_S + DS.SPACE_2
	custom_minimum_size = Vector2(inner.x + DS.SPACE_1 + end_pad, maxf(inner.y + DS.SPACE_1, DS.HIT_TARGET_MIN - DS.SPACE_2))
	_box.position = Vector2(DS.SPACE_1, (custom_minimum_size.y - inner.y) * 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _box != null:
		_box.position.y = (size.y - _box.size.y) * 0.5


## Largeur réservée à droite d'une puce en discordance : repère DISCORDANCE
## (`ICON_M`, dessiné par `InspectableItem`) et pastilles numérotées (une
## tous les `SPACE_5` vers la gauche ; le losange déborde de `SPACE_3 * 1.5`
## à gauche du coin).
static func flag_reserve(count: int = 1) -> float:
	return maxf(DS.ICON_M + DS.SPACE_2, DS.SPACE_3 * 1.5 + DS.SPACE_1 + DS.SPACE_5 * maxi(count - 1, 0))


## Coche de concordance (QA-070) : place réservée comme pour la discordance.
func set_concordant(value: bool) -> void:
	super.set_concordant(value)
	_sync_min_size()


func _refresh_content() -> void:
	if _label == null:
		return
	_sync_min_size()
	var color: Color = DS.TEXT_PRIMARY
	if struck:
		color = DS.TEXT_MUTED
	elif is_flagged():
		color = Palette.ACCENT_MAGENTA
	elif selected:
		color = DS.ACCENT_CYAN
	elif is_vague():
		color = Palette.TEXT_SECONDARY
	_label.add_theme_color_override(&"font_color", color)
	if _glyph != null:
		_glyph.add_theme_color_override(&"font_color", Palette.TEXT_SECONDARY if is_vague() else
				(Palette.ACCENT_MAGENTA if is_flagged() else DS.ACCENT_CYAN))


func _draw() -> void:
	super._draw()
	if struck and _label != null:
		var y: float = _box.position.y + _label.position.y + _label.size.y * 0.55
		draw_line(Vector2(_box.position.x, y), Vector2(_box.position.x + _box.size.x, y), DS.TEXT_MUTED, DS.BORDER_STRONG)


## Soulignement pointillé **toujours visible** (une puce est une valeur
## soulignée, M13 §1.7) : cyan 40 % au repos, cyan plein au survol ; gris
## pour une réponse imprécise ; aucun sous une valeur barrée.
func _draw_underline(rect: Rect2) -> void:
	if is_flagged() or selected or struck:
		return
	var color: Color = Palette.TEXT_SECONDARY if is_vague() else (DS.ACCENT_CYAN if _hovered else DS.CYAN_40)
	var y: float = rect.end.y - DS.SPACE_1
	draw_dashed_line(Vector2(rect.position.x + DS.SPACE_1, y), Vector2(rect.end.x - DS.SPACE_1, y), color, 1.0, DASH, true)
