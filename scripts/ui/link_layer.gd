## Calque des DiscrepancyLinks (DS §7.3, UI_FLOW §3.1–§3.4) : fil en cours
## (pointillé cyan qui suit le curseur), évaluation (remplissage A → B),
## CONCORDANT (cyan fin, dissolution), DISCORDANCE (magenta 3 px + lueur,
## épinglée, numérotée), INCOMPARABLE (gris qui se rétracte vers A).
## Dessine aussi le cadre « VISAGE » sur la vue 3D en Mode Inspection.
## Acte II (scanner partiel, ACT2 §2.5 M3) : liens **suggérés** en pointillés
## dans la couleur de la source (ACV-2 ambre, boîtier des Lucioles magenta),
## losanges creux, visibles même hors Mode Inspection ; le joueur les confirme
## (`ComparisonUI.confirm_suggestion`) : ils deviennent alors une évaluation.
## Plein écran, transparent aux clics.
class_name LinkLayer
extends Control

enum State { EVALUATING, CONCORDANT, DISCORDANT, INCOMPARABLE, SUGGESTED }

## Un lien affiché.
class Link:
	var a: FieldRef
	var b: FieldRef
	var state: State = State.EVALUATING
	var number: int = 0
	## 0 → 1 : tracé de A vers B.
	var progress: float = 0.0
	var alpha: float = 1.0
	var pulse: float = 0.0
	var age: float = 0.0
	## Acte II : couleur de la source d'un lien suggéré.
	var tint: Color = Palette.STATE_AMBER
	## Source d'un lien suggéré (`acv`, `luciole`) : glyphe au milieu du fil,
	## la source ne se lit jamais à la seule couleur (M11).
	var source: StringName = &""

## `rect_provider(ref: FieldRef) -> Rect2` : rectangle global de la cible
## (taille nulle = cible invisible).
var rect_provider: Callable = Callable()
## Rectangle global du visage du passager (zone B), taille nulle = aucun.
var face_rect: Rect2 = Rect2()
## Bande B (globale) : le libellé « VISAGE » y reste contenu.
var band_rect: Rect2 = Rect2()
var face_label: String = "VISAGE"
var face_state: int = 0 # 0 normal, 1 sélectionné (A), 2 discordance
var face_masked: bool = false
var inspection_active: bool = false
var fx_intensity: float = 1.0
var reduce_motion: bool = false
## Champ A en attente du champ B (fil qui suit le curseur).
var pending_a: FieldRef = null

var links: Array[Link] = []
var _time: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Acte II : lien suggéré par le scanner partiel (pointillé, couleur `tint`).
func add_suggested(p: FieldRef, q: FieldRef, tint: Color, source: StringName = &"") -> Link:
	var link: Link = find_link(p, q)
	if link == null:
		link = Link.new()
		link.a = p
		link.b = q
		links.append(link)
	elif link.state != State.SUGGESTED:
		return link
	link.state = State.SUGGESTED
	link.tint = tint
	link.source = source
	link.progress = 1.0
	link.alpha = 1.0
	link.age = 0.0
	return link


## Liens suggérés encore affichés (non confirmés).
func suggested_links() -> Array[Link]:
	var result: Array[Link] = []
	for link: Link in links:
		if link.state == State.SUGGESTED:
			result.append(link)
	return result


## Retire un lien suggéré (ignoré, ou remplacé par l'évaluation).
func remove_suggested(p: FieldRef, q: FieldRef) -> void:
	var link: Link = find_link(p, q)
	if link != null and link.state == State.SUGGESTED:
		links.erase(link)
		queue_redraw()


## Point milieu global d'un lien (pastille « CONFIRMER »), `Vector2.INF` si
## une extrémité est invisible (Rulebook replié, document hors champ).
func link_midpoint(link: Link) -> Vector2:
	var pts: PackedVector2Array = link_points(link)
	return pts[pts.size() >> 1] if not pts.is_empty() else Vector2.INF


## Points de la courbe d'un lien (repère global), vide si un bout manque.
func link_points(link: Link) -> PackedVector2Array:
	var ra: Rect2 = _local_rect(link.a)
	var rb: Rect2 = _local_rect(link.b)
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return PackedVector2Array()
	var sa: Array[Vector2] = anchor(ra, rb.get_center())
	var sb: Array[Vector2] = anchor(rb, ra.get_center())
	return get_global_transform() * curve(sa[0], sa[1], sb[0], sb[1])


func clear() -> void:
	links.clear()
	pending_a = null
	queue_redraw()


func find_link(p: FieldRef, q: FieldRef) -> Link:
	var key: String = InspectionSelection.pair_key(p, q)
	for link: Link in links:
		if InspectionSelection.pair_key(link.a, link.b) == key:
			return link
	return null


## Nouveau lien en évaluation (fil qui se remplit de A vers B).
func add_evaluating(p: FieldRef, q: FieldRef) -> Link:
	var link: Link = find_link(p, q)
	if link == null:
		link = Link.new()
		link.a = p
		link.b = q
		links.append(link)
	link.state = State.EVALUATING
	link.progress = 1.0 if reduce_motion else 0.0
	link.alpha = 1.0
	link.age = 0.0
	return link


func resolve(result: Discrepancy, number: int) -> Link:
	var link: Link = find_link(result.a, result.b)
	if link == null:
		link = add_evaluating(result.a, result.b)
	link.progress = 1.0
	link.age = 0.0
	link.number = number
	match result.result:
		Discrepancy.Result.DISCORDANT:
			link.state = State.DISCORDANT
			link.pulse = 1.0
		Discrepancy.Result.CONCORDANT:
			link.state = State.CONCORDANT
		_:
			link.state = State.INCOMPARABLE
	return link


func pulse_link(p: FieldRef, q: FieldRef) -> void:
	var link: Link = find_link(p, q)
	if link != null:
		link.pulse = 1.0
		link.alpha = 1.0
		link.age = 0.0


func _process(delta: float) -> void:
	_time += delta
	var survivors: Array[Link] = []
	for link: Link in links:
		link.age += delta
		link.pulse = maxf(link.pulse - delta / DS.DUR_SLOW, 0.0)
		match link.state:
			State.EVALUATING:
				link.progress = minf(link.progress + delta / DS.DUR_BASE, 1.0)
			State.CONCORDANT:
				if link.age > DS.CONCORDANT_HOLD:
					link.alpha = maxf(1.0 - (link.age - DS.CONCORDANT_HOLD) / DS.DUR_BASE, 0.0)
			State.INCOMPARABLE:
				link.progress = maxf(1.0 - link.age / DS.INCOMPARABLE_HOLD, 0.0)
				link.alpha = link.progress
		if link.alpha > 0.0:
			survivors.append(link)
	links = survivors
	queue_redraw()


# ---------------------------------------------------------------------------
# Géométrie
# ---------------------------------------------------------------------------

func _local_rect(ref: FieldRef) -> Rect2:
	var global: Rect2 = Rect2()
	if ref != null and ref.is_passenger_face():
		global = face_rect
	elif rect_provider.is_valid():
		global = rect_provider.call(ref)
	if global.size == Vector2.ZERO:
		return Rect2()
	var inv: Transform2D = get_global_transform().affine_inverse()
	return Rect2(inv * global.position, global.size * inv.get_scale())


## Ancre sur le bord de `rect` tourné vers `toward` + direction de sortie.
static func anchor(rect: Rect2, toward: Vector2) -> Array[Vector2]:
	var c: Vector2 = rect.get_center()
	var d: Vector2 = toward - c
	if absf(d.x) * rect.size.y >= absf(d.y) * rect.size.x * 0.5 and absf(d.x) > rect.size.x * 0.5:
		var dir: Vector2 = Vector2(signf(d.x), 0.0)
		return [Vector2(rect.end.x if d.x > 0.0 else rect.position.x, c.y), dir]
	var vdir: Vector2 = Vector2(0.0, signf(d.y) if d.y != 0.0 else 1.0)
	return [Vector2(c.x, rect.end.y if d.y > 0.0 else rect.position.y), vdir]


## Courbe de Bézier A → B échantillonnée.
static func curve(p0: Vector2, d0: Vector2, p3: Vector2, d3: Vector2, samples: int = 40) -> PackedVector2Array:
	var reach: float = clampf(p0.distance_to(p3) * 0.4, DS.SPACE_8, DS.SPACE_16 * 3.0)
	var c1: Vector2 = p0 + d0 * reach
	var c2: Vector2 = p3 + d3 * reach
	var points: PackedVector2Array = []
	for i: int in samples + 1:
		var t: float = float(i) / samples
		var u: float = 1.0 - t
		points.append(u * u * u * p0 + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * p3)
	return points


static func partial(points: PackedVector2Array, amount: float) -> PackedVector2Array:
	if amount >= 1.0:
		return points
	var count: int = maxi(ceili((points.size() - 1) * amount) + 1, 2)
	return points.slice(0, mini(count, points.size()))


func _draw_dashed(points: PackedVector2Array, color: Color, width: float, offset: float) -> void:
	var dash: float = 6.0
	var gap: float = 4.0
	var pos: float = -fposmod(offset, dash + gap)
	for i: int in points.size() - 1:
		var p: Vector2 = points[i]
		var q: Vector2 = points[i + 1]
		var seg_len: float = p.distance_to(q)
		var start: float = 0.0
		while start < seg_len:
			var phase: float = fposmod(pos + start, dash + gap)
			var step: float = minf((dash - phase) if phase < dash else (dash + gap - phase), seg_len - start)
			if phase < dash:
				draw_line(p.lerp(q, start / seg_len), p.lerp(q, (start + step) / seg_len), color, width, true)
			start += maxf(step, 0.5)
		pos += seg_len


func _diamond(center: Vector2, half: float, color: Color, filled: bool = true) -> void:
	var pts: PackedVector2Array = [center + Vector2(0, -half), center + Vector2(half, 0), center + Vector2(0, half), center + Vector2(-half, 0)]
	if filled:
		draw_colored_polygon(pts, color)
	else:
		pts.append(pts[0])
		draw_polyline(pts, color, 1.5, true)


## Glyphe de la source d'un lien suggéré, sur une pastille sombre : luciole
## (boîtier des Lucioles) ou réticule (scanner ACV-2).
func _draw_source_glyph(center: Vector2, source: StringName, color: Color) -> void:
	if source == &"":
		return
	var half: float = DS.SPACE_2 + 2.0
	draw_rect(Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), DS.SUBTITLE_BG)
	if source == ComparisonUI.SCANNER_LUCIOLE:
		SlippedItemView.draw_luciole(self, center, half * 0.7, color)
	else:
		UiIcon.draw_icon(self, UiIcon.Kind.SCANNER, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), color)


# ---------------------------------------------------------------------------
# Dessin
# ---------------------------------------------------------------------------

func _draw() -> void:
	_draw_face_frame()
	for link: Link in links:
		_draw_link(link)
	if pending_a != null:
		var rect: Rect2 = _local_rect(pending_a)
		if rect.size != Vector2.ZERO:
			var mouse: Vector2 = get_local_mouse_position()
			var start: Array[Vector2] = anchor(rect, mouse)
			var pts: PackedVector2Array = curve(start[0], start[1], mouse, -start[1] * 0.2, 24)
			var speed: float = DS.FX_LINK_DASH_SPEED * fx_intensity
			_draw_dashed(pts, DS.ACCENT_CYAN, 1.5, -_time * speed)
			_diamond(start[0], 4.0, DS.ACCENT_CYAN)


func _draw_link(link: Link) -> void:
	var ra: Rect2 = _local_rect(link.a)
	var rb: Rect2 = _local_rect(link.b)
	if ra.size == Vector2.ZERO or rb.size == Vector2.ZERO:
		return
	var sa: Array[Vector2] = anchor(ra, rb.get_center())
	var sb: Array[Vector2] = anchor(rb, ra.get_center())
	var pts: PackedVector2Array = curve(sa[0], sa[1], sb[0], sb[1])
	var shown: PackedVector2Array = partial(pts, link.progress)
	var dim: float = 1.0 if inspection_active else 0.55
	match link.state:
		State.EVALUATING:
			_draw_dashed(pts, Color(DS.ACCENT_CYAN, 0.35 * dim), 1.5, -_time * DS.FX_LINK_DASH_SPEED * fx_intensity)
			draw_polyline(shown, Color(DS.ACCENT_CYAN, dim), 2.0, true)
			_diamond(sa[0], 4.0, DS.ACCENT_CYAN)
		State.CONCORDANT:
			var c: Color = Color(DS.ACCENT_CYAN, link.alpha * dim)
			draw_polyline(pts, c, 1.0, true)
			_diamond(sa[0], 3.5, c)
			_diamond(sb[0], 3.5, c)
			# Pas d'étiquette sur le fil (elle masquerait des valeurs) : le
			# bandeau du plan et les coches des champs portent le « ✓ ».
		State.INCOMPARABLE:
			var g: Color = Color(Palette.TEXT_SECONDARY, link.alpha)
			_draw_dashed(shown, g, 1.5, 0.0)
			_diamond(sa[0], 3.5, g)
		State.SUGGESTED:
			# Pointillé de la source, défilant (≤ 20 px/s), losanges creux.
			var tint: Color = Color(link.tint, 0.9 if inspection_active else 0.7)
			if fx_intensity > 0.0:
				draw_polyline(pts, Color(link.tint, 0.12 * fx_intensity), 5.0, true)
			_draw_dashed(pts, tint, 2.0, -_time * DS.FX_LINK_DASH_SPEED * fx_intensity)
			_diamond(sa[0], 4.5, tint, false)
			_diamond(sb[0], 4.5, tint, false)
			_draw_source_glyph(pts[pts.size() >> 1], link.source, tint)
		State.DISCORDANT:
			var m: Color = Color(Palette.ACCENT_MAGENTA, dim)
			if fx_intensity > 0.0:
				var glow: Color = Color(Palette.MAGENTA_60, (0.35 + 0.4 * link.pulse) * fx_intensity * dim)
				draw_polyline(pts, glow, 3.0 + 6.0 * fx_intensity, true)
			draw_polyline(pts, m, 3.0, true)
			_diamond(sa[0], 5.0, m)
			_diamond(sb[0], 5.0, m)
			var mid: Vector2 = pts[pts.size() >> 1]
			_diamond(mid, DS.SPACE_3, m)
			var font: Font = get_theme_font(&"font", &"BadgeLabel")
			var font_size: int = get_theme_font_size(&"font_size", &"BadgeLabel")
			var text: String = str(link.number)
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, mid + Vector2(-tw * 0.5, font.get_ascent(font_size) * 0.5 - 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, DS.TEXT_ON_ACCENT)
			if link.pulse > 0.0:
				_diamond(mid, DS.SPACE_3 + DS.SPACE_3 * (1.0 - link.pulse), Color(Palette.ACCENT_MAGENTA, link.pulse), false)


## Cadre « VISAGE » en coins pointillés (UI_FLOW §4.9) : visible en Mode
## Inspection, cyan plein + « A » une fois sélectionné, magenta si discordance.
func _draw_face_frame() -> void:
	if face_rect.size == Vector2.ZERO or not (inspection_active or face_state != 0):
		return
	var inv: Transform2D = get_global_transform().affine_inverse()
	var rect: Rect2 = Rect2(inv * face_rect.position, face_rect.size * inv.get_scale())
	var color: Color = DS.ACCENT_CYAN
	if face_state == 2:
		color = Palette.ACCENT_MAGENTA
	elif not inspection_active:
		color = Color(DS.ACCENT_CYAN, 0.5)
	var l: float = DS.SPACE_5
	var corners: Array[PackedVector2Array] = [
		PackedVector2Array([rect.position + Vector2(0, l), rect.position, rect.position + Vector2(l, 0)]),
		PackedVector2Array([Vector2(rect.end.x - l, rect.position.y), Vector2(rect.end.x, rect.position.y), Vector2(rect.end.x, rect.position.y + l)]),
		PackedVector2Array([Vector2(rect.position.x, rect.end.y - l), Vector2(rect.position.x, rect.end.y), Vector2(rect.position.x + l, rect.end.y)]),
		PackedVector2Array([rect.end - Vector2(l, 0), rect.end, rect.end - Vector2(0, l)]),
	]
	for corner: PackedVector2Array in corners:
		if face_state == 0:
			_draw_dashed(corner, color, 1.5, 0.0)
		else:
			draw_polyline(corner, color, DS.BORDER_STRONG)
	var label: String = face_label
	if face_state == 2:
		label = "≠ " + label # discordance : signe, pas la couleur seule (M11)
	if face_masked:
		label += " · " + UiText.t("face_masked", "MASQUÉ")
	var font: Font = get_theme_font(&"font", &"DocFieldLabel")
	var font_size: int = get_theme_font_size(&"font_size", &"DocFieldLabel")
	var tw: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var chip: Rect2 = Rect2(Vector2(rect.get_center().x - (tw + DS.SPACE_6) * 0.5, rect.position.y - DS.SPACE_6), Vector2(tw + DS.SPACE_6, DS.SPACE_5))
	# Pas de place au-dessus du cadre dans la bande : libellé à l'intérieur.
	var band_top: float = (inv * band_rect.position).y if band_rect.size != Vector2.ZERO else -INF
	if chip.position.y < band_top:
		chip.position.y = rect.position.y + DS.SPACE_1
	draw_rect(chip, DS.SUBTITLE_BG)
	_diamond(chip.position + Vector2(DS.SPACE_2, chip.size.y * 0.5), 3.0, color)
	draw_string(font, Vector2(chip.position.x + DS.SPACE_4, chip.get_center().y + font.get_ascent(font_size) * 0.4), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
	if face_state == 1:
		InspectableItem.draw_letter_badge(self, Vector2(rect.end.x, rect.position.y), "A", DS.ACCENT_CYAN)
