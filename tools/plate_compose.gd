## Composition figée d'une planche telle qu'à l'écran (M14 §3.3) — partagée par
## `tools/build_plates.gd` (captures `docs/mockups/m14_*`) et
## `tools/qa_plates_audit.gd` (M-16). Préfigure le `CinematicScreen` (lot D)
## sans en être l'implémentation : « remplir la hauteur », zoom et parallaxe à
## l'instant `t` de la planche (`PlateDef.zoom_to`, `parallax_px`, `depth`),
## couches d'état (PL-F9-1 : 04 et 05 éteintes, 06 à 45 %), papier à
## l'exécution (`plate_paper.gdshader`), voiles `plate_holo` sur les ancres du
## manifeste, `Label` des `PlateLabelDef` (police mono DS), figures nommées en
## silhouette de repli, légende (style sous-titre ×1,25, ≥ 16 px physiques, voile
## `bg.void` 72 %, centrée dans la zone sûre 16:10).
extends RefCounted

const BB = preload("res://tools/build_booth.gd")
const PLATE_SIZE: Vector2i = Vector2i(2048, 1152)
const HOLO_SHADER: String = "res://assets/shaders/plate_holo.gdshader"
const CAPTION_SCALE: float = 1.25
const SETTLE_FRAMES: int = 4

## Dernière légende composée (pixels de la capture), pour la mesure de contraste.
var caption_rect: Rect2i = Rect2i()
var caption_text: String = ""
var caption_font_px: int = 0


static func stem_of(path: String) -> String:
	return path.get_file().get_basename()


## Rend la planche dans une `SubViewport` de `size` ; `manifest` = contenu de
## `assets/cinematics/manifest.json` (rectangles réels, ancres).
func compose(tree_root: Node, plate: PlateDef, size: Vector2i, manifest: Dictionary, t: float = 0.6) -> Image:
	var files: Dictionary = manifest.get("files", {})
	var groups: Dictionary = manifest.get("groups", {})
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree_root.add_child(vp)
	var ui: Control = Control.new()
	ui.size = Vector2(size)
	ui.theme = ThemeBuilder.build(1.0)
	vp.add_child(ui)
	var fill: ColorRect = ColorRect.new()
	fill.color = DS.BG_VOID
	fill.size = Vector2(size)
	ui.add_child(fill)
	# « Remplir la hauteur » : 1 080 lignes de planche à l'écran (marge de 72 px).
	var scale: float = float(size.y) / 1080.0
	var stage: Control = Control.new()
	stage.size = Vector2(PLATE_SIZE)
	stage.pivot_offset = Vector2(PLATE_SIZE) * 0.5
	stage.scale = Vector2.ONE * lerpf(1.0, plate.zoom_to, t) * scale
	stage.position = Vector2(size) * 0.5 - Vector2(PLATE_SIZE) * 0.5
	ui.add_child(stage)
	var pan: Vector2 = plate.pan.normalized() if plate.pan.length() > 0.0 else Vector2.RIGHT
	var off_state: Dictionary = {3: 0.0, 4: 0.0, 5: 0.45} if plate.holo_effect == PlateDef.HOLO_GLASS_OFF_SEQUENCE else {}
	var travel: float = (t - 0.5) * 2.0
	for layer: PlateLayerDef in plate.layers:
		if layer == null or layer.texture_path.is_empty() or not FileAccess.file_exists(layer.texture_path):
			continue
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(layer.texture_path))
		var r: Array = (files.get(layer.texture_path, {}) as Dictionary).get("rect", [0, 0, img.get_width(), img.get_height()])
		var shift: Vector2 = -pan * plate.parallax_px * layer.depth * travel * (1152.0 / 1080.0)
		var power: float = float(off_state.get(int(layer.get("state_index")), 1.0)) if layer.kind == &"lit" else 1.0
		add_layer(stage, img, Vector2(float(r[0]), float(r[1])) + shift, Vector2(float(r[2]), float(r[3])), power)
	for slot: FigureSlotDef in plate.figures:
		if slot != null and FileAccess.file_exists(slot.silhouette_path):
			var img: Image = Image.load_from_file(ProjectSettings.globalize_path(slot.silhouette_path))
			var rp: Vector2 = Vector2(slot.rect.position.x * PLATE_SIZE.x, slot.rect.position.y * PLATE_SIZE.y)
			var rs: Vector2 = Vector2(slot.rect.size.x * PLATE_SIZE.x, slot.rect.size.y * PLATE_SIZE.y)
			add_layer(stage, img, rp - pan * plate.parallax_px * slot.depth * travel, rs, 1.0)
	var group: Dictionary = {}
	for layer: PlateLayerDef in plate.layers:
		if layer != null and layer.kind == PlateLayerDef.KIND_BG:
			group = groups.get(stem_of(layer.texture_path), {})
	var holos: Array = group.get("holo", [])
	if not plate.labels.is_empty() or plate.holo_effect != &"":
		var holo_shader: Shader = load(HOLO_SHADER) as Shader
		for i: int in holos.size():
			var r: Array = holos[i]
			var holo: ColorRect = ColorRect.new()
			var halo: float = 0.18
			var hs: Vector2 = Vector2(float(r[2]), float(r[3])) / (1.0 - 2.0 * halo)
			holo.position = Vector2(float(r[0]), float(r[1])) - (hs - Vector2(float(r[2]), float(r[3]))) * 0.5
			holo.size = hs
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = holo_shader
			mat.set_shader_parameter("tint", PlatePaintStyle.dominant_color(plate.dominant).lerp(DS.ACCENT_CYAN, 0.3).lerp(BB.KEY, 0.3))
			mat.set_shader_parameter("power", float(off_state.get(i, 1.0)) * 0.7)
			mat.set_shader_parameter("halo", halo)
			mat.set_shader_parameter("plate_time", 1.7)
			holo.material = mat
			stage.add_child(holo)
	for lab: PlateLabelDef in plate.labels:
		if lab == null:
			continue
		var l: Label = Label.new()
		l.text = lab.display_text(func(k: String) -> String: return TranslationServer.translate(k))
		var font_px: int = int(lab.rect.size.y * PLATE_SIZE.y * (0.7 if lab.style == &"holo_small" else 0.45))
		l.add_theme_font_override("font", load(DS.FONT_MONO_PATH) as Font)
		l.add_theme_font_size_override("font_size", clampi(font_px, DS.FS_CAPTION, 96))
		l.add_theme_color_override("font_color", DS.TEXT_PRIMARY)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if lab.style == &"holo_display" else TextServer.AUTOWRAP_OFF
		l.position = Vector2(lab.rect.position.x * PLATE_SIZE.x, lab.rect.position.y * PLATE_SIZE.y)
		l.size = Vector2(lab.rect.size.x * PLATE_SIZE.x, lab.rect.size.y * PLATE_SIZE.y)
		stage.add_child(l)
	# Légende : clé par défaut (sans drapeau), texte de `fr.csv`.
	var key: String = CinematicService.caption_key(plate, CinematicService.context_flags({}, 3))
	caption_text = TranslationServer.translate(key)
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.chamfer_box(DS.SCRIM, Color(0, 0, 0, 0), 0, DS.CHAMFER_S, DS.SPACE_4, true))
	var cap: Label = Label.new()
	cap.text = caption_text
	cap.theme_type_variation = &"SubtitleText"
	# ≥ 1,25 × corps, et jamais moins de 16 px physiques (Deck).
	caption_font_px = maxi(roundi(DS.FS_SUBTITLE * CAPTION_SCALE * scale), 16)
	cap.add_theme_font_size_override("font_size", caption_font_px)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(cap)
	ui.add_child(panel)
	# Largeur : le texte sur une ligne s'il tient dans 86 % de la zone sûre 16:10,
	# sinon deux lignes (au plus 2 lignes à 70 caractères, M14 §3.3).
	var safe_w: float = minf(size.x, size.y * 1.6) * 0.86
	var font: Font = cap.get_theme_font(&"font")
	var natural: float = font.get_string_size(caption_text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_font_px).x + 4.0
	cap.custom_minimum_size = Vector2(minf(natural, safe_w - DS.SPACE_4 * 2.0), 0)
	await tree_root.get_tree().process_frame
	panel.reset_size()
	panel.position = Vector2((size.x - panel.size.x) * 0.5, size.y - panel.size.y - DS.SPACE_16 * scale)
	caption_rect = Rect2i(Vector2i(panel.position), Vector2i(panel.size))
	for i: int in SETTLE_FRAMES:
		await RenderingServer.frame_post_draw
	var out: Image = vp.get_texture().get_image()
	out.convert(Image.FORMAT_RGBA8)
	vp.queue_free()
	return out


func add_layer(parent: Control, img: Image, pos: Vector2, size: Vector2, alpha: float) -> void:
	var t: TextureRect = TextureRect.new()
	t.texture = ImageTexture.create_from_image(img)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.position = pos
	t.size = size
	t.modulate.a = alpha
	t.material = PlatePaintStyle.paper_material(pos, size, 1.0)
	parent.add_child(t)


## Contraste WCAG de `fg` sur le fond le plus clair du bandeau (95ᵉ centile de
## luminance des pixels hors glyphes).
static func contrast_under(img: Image, rect: Rect2i, fg: Color) -> float:
	var lums: PackedFloat32Array = []
	var r: Rect2i = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for y: int in range(r.position.y + 2, r.end.y - 2, 2):
		for x: int in range(r.position.x + 2, r.end.x - 2, 2):
			var c: Color = img.get_pixel(x, y)
			if absf(c.get_luminance() - fg.get_luminance()) > 0.25:
				lums.append(rel_lum(c))
	if lums.is_empty():
		return 0.0
	lums.sort()
	var bg_l: float = lums[int(lums.size() * 0.95)]
	return (rel_lum(fg) + 0.05) / (bg_l + 0.05)


static func rel_lum(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b
