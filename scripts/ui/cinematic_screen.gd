## **Cinématique de fin** en illustrations animées (M14 §3, I42 ; D-175,
## D-183 → D-186, D-195 ; ARCHITECTURE §12 ter.3). Plein cadre, jouée par
## `DayScene` **avant** l'écran de fin (inchangé) et avant la conclusion du
## J31, et par le Dossier (REVOIR, figures en silhouette).
##
## - **Données** : `CinematicDef` + planches retenues
##   (`CinematicService.plates_for`) et drapeaux de contexte
##   (`CinematicService.context_flags`). Rien n'est choisi ici : l'appelant
##   sélectionne (`CinematicService.select` / `select_epilogue`).
## - **Planche** (2048×1152, « remplir la hauteur », zone sûre 16:10 au
##   centre) : couches `TextureRect` aux `rect` des données (`BG`, `MID`,
##   `FIG`, `LIT`), papier à l'exécution sur chacune
##   (`PlatePaintStyle.paper_material`, D-195, suit `fx_intensity`), effets
##   `FX` procéduraux (pluie, fumée, poussière, air, brume ; figés si
##   `reduce_motion` ou qualité Bas), voiles `HOLO` (`plate_holo.gdshader` :
##   `holo_flicker`, `fx_intensity`) posés sur les ancres du manifeste des
##   planches, `Label` des `PlateLabelDef` (`display_text()`, police DS, jamais
##   d'effet dessus). Effets scénarisés : `glass_off_sequence` (PL-F9-1 : les
##   couches `LIT` s'éteignent une à une, toutes les 0,5 s ; déjà éteintes si
##   `reduce_motion`), `waveform`, `consortium_eye`, `chime_rings`.
## - **Mouvement** : parallaxe (`depth × parallax_px`, ≤ 12 px) et zoom lent
##   (≤ 1,04), `ease.inout` ; **aucun** si `reduce_motion` (fondus de 160 ms).
## - **Figures nommées** : `PlateFigureService.request_for(slot,
##   GameState.case_memory, ctx, plate.dominant)` pendant la carte de titre —
##   silhouette tout de suite, visage mis à jour sur place (`figure_ready`).
## - **Légende** : `SubtitleText` ×1,25 (≥ 16 px physiques), voile `DS.SCRIM`
##   (contraste ≥ 7:1 sur toute image), dans la zone sûre, ≤ 2 lignes ; suit
##   `text_scale` ; jamais de clé brute (clé absente : pas de légende).
## - **Commandes** (clavier, souris, manette) : un appui (Entrée, Espace, clic,
##   Ⓐ) = planche suivante après 0,6 s (la légende qui se révèle d'abord) ;
##   **maintien 0,8 s** (Échap, Ⓑ, Ⓐ, clic ou « TOUT PASSER ») = toute la
##   séquence, anneau de progression ; Start / F10 = pause (la planche se fige).
##   Avance automatique ou manuelle (`Settings.cinematic_advance` ; manuelle :
##   « ▶ » qui pulse à ≤ 1 Hz). Invite « Maintenir pour passer » dès la
##   première image si la séquence a déjà été vue, sinon après la première
##   planche.
## - **Fin** : `finished(skipped: bool)` (signal hérité de `ScreenBase`, porteur
##   d'un **booléen** ici, contrat ARCHITECTURE §12 ter.6 ; l'`AudioDirector`
##   l'écoute : passée → queue du thème) et `ProfileService.record_cinematic_seen`
##   avec le contexte de REVOIR (`replay_record` : planches retenues, variante,
##   acte, jour, drapeaux lus par les conditions de la séquence et de son
##   thème — QA-073).
## La musique n'est pas pilotée ici : l'`AudioDirector` reconnaît l'écran par sa
## classe et lit `ending` (thème de la fin, ou du monde au J31).
class_name CinematicScreen
extends ScreenBase

## D-203 : la bibliothèque des cinématiques est chargée **avant** tout script
## qui nomme `PlateDef` (sinon fuite de scripts à la sortie de Godot 4.7.2).
const _CINEMATIC_LIBRARY := preload("res://scripts/core/cinematic_library_def.gd")

const PLATE_SIZE: Vector2 = Vector2(2048.0, 1152.0)
## Lignes de planche visibles en hauteur (« remplir la hauteur » : 1 080 sur 1 152).
const VIEW_LINES: float = 1080.0
const MANIFEST_PATH: String = "res://assets/cinematics/manifest.json"
const HOLO_SHADER_PATH: String = "res://assets/shaders/plate_holo.gdshader"
## Effets holographiques scénarisés reconnus (lot E, M14 §7.6 bis).
const HOLO_WAVEFORM: StringName = &"waveform"
const HOLO_EYE: StringName = &"consortium_eye"
const HOLO_RINGS: StringName = &"chime_rings"
## Temps figé des shaders quand rien ne doit bouger.
const FROZEN_TIME: float = 1.7
## Halo des voiles holographiques (marge de `plate_holo` autour du rectangle utile).
const HOLO_HALO: float = 0.18
## Sources d'un maintien.
const HOLD_ACCEPT: StringName = &"accept"
const HOLD_CANCEL: StringName = &"cancel"
const HOLD_CLICK: StringName = &"click"
const HOLD_BUTTON: StringName = &"button"

enum Phase { TITLE, PLATES, DONE }

## Séquence jouée.
var def: CinematicDef = null
var plates: Array[PlateDef] = []
## Drapeaux de contexte (`CinematicService.context_flags`).
var ctx: Dictionary[StringName, Variant] = {}
## Mémoire des cas (figures nommées) ; vide = silhouettes (REVOIR, tests).
var memory: Dictionary = {}
## Fin jouée (lue par l'`AudioDirector` pour le thème) et sa variante.
var ending: StringName = &""
var variant: StringName = &""
## Carte de titre : surtitre, titre, couleur et icône de la fin.
var eyebrow_text: String = ""
var title_text: String = ""
var accent: Color = DS.TEXT_PRIMARY
var icon: UiIcon.Kind = UiIcon.Kind.INFO
## Séquence déjà vue (profil) : invite « Maintenir pour passer » tout de suite.
var already_seen: bool = false
## Inscrire la séquence au profil à la fin (faux : REVOIR, captures).
var record_seen: bool = true
var save_dir: String = SaveService.DEFAULT_DIR
## Vrai si la séquence a été passée (maintien).
var skipped: bool = false

var phase: Phase = Phase.TITLE
## Planche affichée (−1 : carte de titre).
var index: int = -1
## Temps passé sur la carte de titre ou la planche courante (s).
var elapsed: float = 0.0
## Maintien en cours (`HOLD_*`, vide sinon) et sa durée.
var hold_source: StringName = &""
var hold_time: float = 0.0
## Invite « Maintenir pour passer » affichée.
var skip_prompt_visible: bool = false

## Nœuds (tests, captures).
var stage_host: Control = null
var title_card: Control = null
var caption_panel: PanelContainer = null
var caption_label: Label = null
var next_mark: Label = null
var skip_row: HBoxContainer = null
var skip_button: Button = null
var hold_ring: HoldRing = null
var figure_service: PlateFigureService = null
## Planche courante (scène de couches) et précédente (fondu croisé).
var stage: PlateStage = null
var _previous: PlateStage = null
## Textures des figures nommées : « plate_id/slot_id » → texture (mise à jour sur place).
var figure_textures: Dictionary[String, Texture2D] = {}
var _caption_tween: Tween = null
var _caption_revealing: bool = false
var _next_tween: Tween = null
var _preloaded: PackedStringArray = []
var _tweens: Array[Tween] = []
## Légende avant retour à la ligne.
var _caption_source: String = ""

static var _manifest: Dictionary = {}
static var _manifest_loaded: bool = false
static var _fx_shader: Shader = null


func _init() -> void:
	super._init()
	name = "CinematicScreen"


## Prépare la séquence (avant `add_child`).
func setup(p_def: CinematicDef, p_plates: Array[PlateDef], p_ctx: Dictionary[StringName, Variant], p_memory: Dictionary = {},
		p_ending: StringName = &"", p_variant: StringName = &"") -> void:
	def = p_def
	plates = p_plates
	ctx = p_ctx
	memory = p_memory
	ending = p_ending
	variant = p_variant
	if EndingService.ALL_ENDINGS.has(ending):
		accent = EndScreen.accent_of(ending, String(variant))
		icon = EndScreen.icon_of(ending)


## Carte de titre (clés `end*_eyebrow_*`, `end*_title` déjà traduites).
func set_title(p_eyebrow: String, p_title: String) -> void:
	eyebrow_text = p_eyebrow
	title_text = p_title


## Vrai si la séquence a une carte de titre.
func has_title_card() -> bool:
	return def != null and def.title_card and not title_text.is_empty()


## Durée d'affichage d'une planche (DS : max(6 ; 2,5 + 0,06 × caractères),
## ×1,5 avec l'horloge ralentie ; durée imposée par les données sinon).
static func plate_duration(plate: PlateDef, caption: String) -> float:
	var base: float = plate.duration_sec if plate != null and plate.duration_sec > 0.0 \
			else maxf(DS.PLATE_MIN_SEC, DS.PLATE_BASE_SEC + DS.PLATE_CHARS_SEC * caption.length())
	return base * (DS.PLATE_SLOW_FACTOR if Settings.clock_slow_accessibility else 1.0)


## Texte de la légende d'une planche (vide si la clé n'est pas traduite :
## jamais de clé brute à l'écran).
static func caption_text(plate: PlateDef, flags: Dictionary[StringName, Variant]) -> String:
	var key: String = CinematicService.caption_key(plate, flags)
	return UiText.t(key, "") if UiText.has(key) else ""


## QA-073 : ce que REVOIR doit savoir pour rejouer **cette** séquence telle
## que vue (`ProfileService.cinematic_replays`) : planches retenues (ids, dans
## l'ordre), fin, variante, monde (J31), acte et jour (pseudo-drapeaux de
## `ctx`), et la valeur des seuls drapeaux que lisent les conditions des
## planches (planche, légendes, figures) et des variantes du thème.
func replay_record() -> Dictionary:
	if def == null:
		return {}
	var names: Array[StringName] = []
	for plate: PlateDef in def.plates:
		if plate == null:
			continue
		condition_flags(plate.condition, names)
		for entry: ConditionalKey in plate.captions:
			if entry != null:
				condition_flags(entry.condition, names)
		for slot: FigureSlotDef in plate.figures:
			if slot != null:
				for entry: ConditionalKey in slot.memory_cases:
					if entry != null:
						condition_flags(entry.condition, names)
	var world: String = ""
	if def.is_epilogue():
		world = str(GameState.epilogue_seed.get("world", ""))
		if not def.worlds.has(StringName(world)) and not def.worlds.is_empty():
			world = String(def.worlds[0])
	var theme_path: String = AudioDirector.theme_path_for_world(StringName(world)) if not world.is_empty() \
			else AudioDirector.theme_path_for_ending(ending, variant)
	if not theme_path.is_empty() and ResourceLoader.exists(theme_path):
		var theme: MusicThemeDef = load(theme_path) as MusicThemeDef
		if theme != null:
			for v: MusicThemeVariantDef in theme.variants:
				if v != null:
					condition_flags(v.condition, names)
	var flags: Dictionary = {}
	for flag: StringName in names:
		if ctx.has(flag):
			flags[String(flag)] = ctx[flag]
	var ids: Array = []
	for plate: PlateDef in plates:
		if plate != null:
			ids.append(String(plate.id))
	return {"ending": String(ending), "variant": String(variant), "world": world,
			"act": _ctx_number(CinematicService.FLAG_ACT_PREFIX, 3), "day": _ctx_number(CinematicService.FLAG_DAY_PREFIX, 0),
			"plates": ids, "flags": flags}


## Noms des drapeaux et jauges qu'une condition lit (sous-conditions comprises).
static func condition_flags(condition: FlagCondition, out: Array[StringName]) -> void:
	if condition == null:
		return
	var all_names: Array = []
	all_names.append_array(condition.all_of)
	all_names.append_array(condition.none_of)
	all_names.append_array(condition.gauges_min.keys())
	all_names.append_array(condition.gauges_max.keys())
	for flag: Variant in all_names:
		if not out.has(StringName(flag)):
			out.append(StringName(flag))
	for sub: Resource in condition.any_of:
		condition_flags(sub as FlagCondition, out)


## Nombre d'un pseudo-drapeau `cin_act_<n>` / `cin_day_<n>` de `ctx` (sinon `fallback`).
func _ctx_number(prefix: String, fallback: int) -> int:
	for key: StringName in ctx:
		var text: String = String(key)
		if text.begins_with(prefix) and text.trim_prefix(prefix).is_valid_int() and FlagCondition.is_flag_true(ctx, key):
			return text.trim_prefix(prefix).to_int()
	return fallback


## Durée totale aux réglages courants (carte de titre comprise) — M-14.
func total_duration() -> float:
	var total: float = DS.PLATE_TITLE_SEC if has_title_card() else 0.0
	for plate: PlateDef in plates:
		total += plate_duration(plate, caption_text(plate, ctx))
	return total


func default_focus() -> Control:
	return null # aucun contrôle focalisable : Ⓐ / Ⓑ agissent sur la séquence


# ---------------------------------------------------------------------------
# Construction
# ---------------------------------------------------------------------------

func _build() -> void:
	clip_contents = true
	stage_host = Control.new()
	stage_host.name = "Stage"
	stage_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_host)
	figure_service = PlateFigureService.new()
	figure_service.name = "PlateFigureService"
	add_child(figure_service)
	_build_title_card()
	_build_caption()
	_build_skip_row()
	EventBus.settings_changed.connect(_on_cinematic_settings_changed)
	get_viewport().size_changed.connect(_layout)
	already_seen = already_seen or (def != null and ProfileService.has_seen_cinematic(ProfileService.load_profile(save_dir), String(def.id)))
	_request_figures()
	if plates.is_empty():
		_finish.call_deferred(false)
		return
	if has_title_card():
		phase = Phase.TITLE
		index = -1
		elapsed = 0.0
		title_card.visible = true
		_preload_plate(0)
	else:
		title_card.visible = false
		_show_plate(0)
	_set_skip_prompt(already_seen)
	_layout.call_deferred()


func _build_title_card() -> void:
	title_card = CenterContainer.new()
	title_card.name = "TitleCard"
	title_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_card)
	var box: VBoxContainer = vbox(DS.SPACE_4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_card.add_child(box)
	var top: HBoxContainer = hbox(DS.SPACE_3)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(top)
	top.add_child(UiIcon.make(icon, accent, DS.ICON_M))
	var brow: Label = eyebrow(eyebrow_text, accent)
	brow.name = "Eyebrow"
	top.add_child(brow)
	var line: ColorRect = rule_line(Color(accent, 0.24))
	box.add_child(line)
	var title: Label = label(title_text, &"DisplayLabel", accent)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)


func _build_caption() -> void:
	caption_panel = PanelContainer.new()
	caption_panel.name = "Caption"
	caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Voile `bg.void` 72 % : contraste ≥ 7:1 du texte primaire sur toute image.
	caption_panel.add_theme_stylebox_override(&"panel", ThemeBuilder.chamfer_box(DS.SCRIM, Color(0, 0, 0, 0), 0, DS.CHAMFER_S,
			DS.SPACE_4, true))
	caption_panel.visible = false
	add_child(caption_panel)
	var row: HBoxContainer = hbox(DS.SPACE_3)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_panel.add_child(row)
	caption_label = Label.new()
	caption_label.name = "CaptionText"
	caption_label.theme_type_variation = &"SubtitleText"
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Retour à la ligne calculé ici (`wrap_text`) : hauteur exacte, sans
	# aller-retour de mise en page des `Label` à retour automatique.
	caption_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption_label)
	# Avance manuelle : « ▶ » (texte, pas une couleur seule) qui pulse doucement.
	next_mark = label(UiText.t("cin_next", "▶"), &"SubtitleText", DS.ACCENT_CYAN)
	next_mark.name = "NextMark"
	next_mark.size_flags_vertical = Control.SIZE_SHRINK_END
	next_mark.visible = false
	row.add_child(next_mark)


func _build_skip_row() -> void:
	skip_row = hbox(DS.SPACE_2)
	skip_row.name = "SkipRow"
	skip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip_row)
	hold_ring = HoldRing.new()
	hold_ring.name = "HoldRing"
	skip_row.add_child(hold_ring)
	skip_row.add_child(PromptGlyph.make(&"cancel"))
	var hint: Label = label(UiText.t("cin_skip_hold", "Maintenir pour passer"), &"CaptionLabel", DS.TEXT_PRIMARY)
	hint.name = "SkipHint"
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_row.add_child(hint)
	# Cible souris du maintien (la manette et le clavier passent par Ⓑ / Échap).
	skip_button = button(UiText.t("cin_skip_all", "TOUT PASSER"), &"ButtonGhost")
	skip_button.name = "SkipAll"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_row.add_child(skip_button)
	skip_row.modulate.a = 0.0


## Figures nommées : rendues pendant la carte de titre (≤ 2 par séquence).
func _request_figures() -> void:
	for plate: PlateDef in plates:
		for slot: FigureSlotDef in plate.figures:
			if slot == null:
				continue
			var key: String = "%s/%s" % [plate.id, slot.id]
			if figure_textures.has(key):
				continue
			var tex: Texture2D = figure_service.request_for(slot, memory, ctx, plate.dominant)
			if tex != null:
				figure_textures[key] = tex


# ---------------------------------------------------------------------------
# Mise en page
# ---------------------------------------------------------------------------

## Échelle de la planche : 1 080 lignes dans la hauteur (et toute la largeur).
func plate_scale() -> float:
	if size.y <= 0.0:
		return 1.0
	return maxf(size.y / VIEW_LINES, size.x / PLATE_SIZE.x)


## Zone sûre 16:10 au centre de l'écran.
func safe_rect() -> Rect2:
	var w: float = minf(size.x, size.y * DS.CIN_SAFE_ASPECT)
	return Rect2(Vector2((size.x - w) * 0.5, 0.0), Vector2(w, size.y))


## Retour à la ligne glouton par mots : lignes de `max_w` px au plus (une
## légende de 70 caractères tient sur 2 lignes, 3 au-delà de 130 % de texte).
static func wrap_text(text: String, font: Font, px: int, max_w: float) -> String:
	var lines: PackedStringArray = []
	var line: String = ""
	for word: String in text.split(" ", false):
		var trial: String = word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > max_w:
			lines.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)


## Taille de la légende (px logiques) : sous-titre ×1,25 à l'échelle du texte,
## jamais moins de 16 px physiques.
func caption_font_px() -> int:
	var screen_scale: float = get_viewport().get_final_transform().get_scale().x if is_inside_tree() else 1.0
	# Plancher physique pour un écran réduit réel (0,5 ≤ échelle < 1 : Deck
	# 0,67 → 24 px logiques) ; fenêtres minuscules / headless : non appliqué.
	var floor_px: int = ceili(DS.CIN_CAPTION_MIN_PHYSICAL / screen_scale) if screen_scale >= 0.5 and screen_scale < 1.0 \
			else DS.CIN_CAPTION_MIN_PHYSICAL
	return maxi(roundi(DS.FS_SUBTITLE * DS.CIN_CAPTION_SCALE * Settings.text_scale), floor_px)


func _layout() -> void:
	if not is_inside_tree() or caption_panel == null:
		return
	for s: PlateStage in [stage, _previous]:
		if s != null and is_instance_valid(s):
			_place_stage(s)
	var safe: Rect2 = safe_rect()
	var px: int = caption_font_px()
	caption_label.add_theme_font_size_override(&"font_size", px)
	next_mark.add_theme_font_size_override(&"font_size", px)
	var max_w: float = safe.size.x * DS.CIN_CAPTION_WIDTH - DS.SPACE_4 * 2.0 - (px + DS.SPACE_3)
	var font: Font = caption_label.get_theme_font(&"font")
	caption_label.text = wrap_text(_caption_source, font, px, max_w) if font != null else _caption_source
	caption_label.custom_minimum_size = Vector2.ZERO
	caption_label.reset_size()
	# Ancré en bas au centre (grandit vers le haut) : la hauteur suit le retour
	# à la ligne dès que le conteneur a placé la légende.
	caption_panel.anchor_left = 0.5
	caption_panel.anchor_right = 0.5
	caption_panel.anchor_top = 1.0
	caption_panel.anchor_bottom = 1.0
	caption_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bottom: float = -DS.SPACE_16 * (size.y / VIEW_LINES)
	caption_panel.offset_left = 0.0
	caption_panel.offset_right = 0.0
	caption_panel.offset_top = bottom
	caption_panel.offset_bottom = bottom
	caption_panel.reset_size()
	skip_row.reset_size()
	skip_row.position = Vector2(safe.end.x - skip_row.size.x - DS.SPACE_8, DS.SPACE_8)


func _place_stage(s: PlateStage) -> void:
	var k: float = plate_scale()
	s.base_scale = k
	s.pivot_offset = PLATE_SIZE * 0.5
	var raise: float = DS.CIN_PLATE_RAISE * size.y if Settings.text_scale > 1.3 else 0.0
	s.position = size * 0.5 - PLATE_SIZE * 0.5 - Vector2(0.0, raise)
	s.apply_motion(_motion_t(), Settings.reduce_motion)


func _on_cinematic_settings_changed(key: StringName, _value: Variant) -> void:
	if key == Settings.KEY_LANGUAGE or key == Settings.KEY_PSEUDO_LOC:
		# M15 : légende recomposée (retour à la ligne manuel) dans la nouvelle langue.
		if phase == Phase.PLATES and index >= 0 and index < plates.size():
			_caption_source = caption_text(plates[index], ctx)
		_layout.call_deferred()
	elif key == Settings.KEY_TEXT_SCALE or key == Settings.KEY_REDUCE_MOTION:
		_layout.call_deferred()
	elif key == Settings.KEY_FX_INTENSITY or key == Settings.KEY_HOLO_FLICKER or key == Settings.KEY_GRAPHICS_QUALITY:
		if stage != null and is_instance_valid(stage):
			stage.apply_settings()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), DS.BG_VOID) # fond plein, sans grille (la planche couvre tout)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_RESIZED:
		_layout.call_deferred()
	elif what == NOTIFICATION_PAUSED:
		_cancel_hold() # un maintien ne survit pas à la pause


# ---------------------------------------------------------------------------
# Déroulé
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)


## Avance l'horloge de la séquence de `delta` secondes (horloge simulée en test).
func tick(delta: float) -> void:
	if phase == Phase.DONE or is_closing():
		return
	_update_hold(delta)
	if phase == Phase.DONE:
		return
	elapsed += delta
	if phase == Phase.TITLE:
		if elapsed >= DS.PLATE_TITLE_SEC:
			_show_plate(0)
		return
	if stage != null and is_instance_valid(stage):
		stage.apply_motion(_motion_t(), Settings.reduce_motion)
		stage.update_effects(elapsed)
	var duration: float = current_duration()
	if elapsed >= DS.PLATE_ADVANCE_LOCK and Settings.is_cinematic_manual() and not next_mark.visible:
		_show_next_mark()
	if not Settings.is_cinematic_manual() and elapsed >= duration:
		advance()


## Durée de la planche courante (0 sur la carte de titre).
func current_duration() -> float:
	if index < 0 or index >= plates.size():
		return DS.PLATE_TITLE_SEC
	return plate_duration(plates[index], caption_text(plates[index], ctx))


## Avancement 0 → 1 de la planche courante (mouvement).
func _motion_t() -> float:
	var d: float = current_duration()
	return clampf(elapsed / d, 0.0, 1.0) if d > 0.0 else 0.0


## Planche suivante (ou fin de la séquence après la dernière).
func advance() -> void:
	if phase == Phase.DONE:
		return
	if index + 1 < plates.size():
		_show_plate(index + 1)
	else:
		_finish(false)


## Appui court (Entrée, Ⓐ, clic) : après 0,6 s d'affichage, la légende qui se
## révèle s'affiche d'abord, sinon la planche suivante. Vrai si l'appui a agi.
func request_next() -> bool:
	if phase == Phase.DONE or elapsed < DS.PLATE_ADVANCE_LOCK:
		return false
	if phase == Phase.PLATES and _caption_revealing:
		_complete_caption()
		return true
	advance()
	return true


## Passe toute la séquence (maintien abouti).
func skip_all() -> void:
	_finish(true)


## Captures et tests : planche `i` affichée d'emblée (fondu achevé, légende
## révélée) à l'instant `t` (s) de la planche.
func jump_to(i: int, t: float = 0.0) -> void:
	if i < 0 or i >= plates.size() or phase == Phase.DONE:
		return
	_show_plate(i)
	if title_card != null:
		title_card.visible = false
	if _previous != null and is_instance_valid(_previous):
		_previous.queue_free()
		_previous = null
	stage.modulate.a = 1.0
	_complete_caption()
	elapsed = maxf(t, 0.0)
	stage.apply_motion(_motion_t(), Settings.reduce_motion)
	stage.update_effects(elapsed)


func _show_plate(i: int) -> void:
	phase = Phase.PLATES
	if i >= 1:
		_set_skip_prompt(true) # l'invite paraît après la première planche
	var plate: PlateDef = plates[i]
	index = i
	elapsed = 0.0
	if title_card != null and title_card.visible:
		_fade_out_and_hide(title_card)
	if _previous != null and is_instance_valid(_previous):
		_previous.queue_free()
	_previous = stage
	stage = PlateStage.new()
	stage.name = "Plate_%s" % plate.id
	stage.screen = self
	stage_host.add_child(stage)
	stage.build(plate, ctx, figure_textures, _texture_for)
	_place_stage(stage)
	var xfade: float = DS.DUR_FAST if Settings.reduce_motion else DS.DUR_PLATE_XFADE
	stage.modulate.a = 0.0
	var tween: Tween = _own(stage.create_tween())
	tween.tween_property(stage, "modulate:a", 1.0, xfade)
	var old: PlateStage = _previous
	if old != null and is_instance_valid(old):
		tween.tween_callback(func() -> void:
			if is_instance_valid(old):
				old.queue_free())
	_set_caption(caption_text(plate, ctx), xfade)
	next_mark.visible = false
	if _next_tween != null:
		_next_tween.kill()
	_preload_plate(i + 1)


func _fade_out_and_hide(node: CanvasItem) -> void:
	var tween: Tween = _own(node.create_tween())
	tween.tween_property(node, "modulate:a", 0.0, DS.DUR_FAST if Settings.reduce_motion else DS.DUR_PLATE_XFADE * 0.7)
	tween.tween_callback(func() -> void: node.visible = false)


func _set_caption(text: String, delay: float) -> void:
	if _caption_tween != null:
		_caption_tween.kill()
	_caption_source = text
	caption_label.text = text
	caption_panel.visible = not text.is_empty()
	_layout()
	if text.is_empty():
		_caption_revealing = false
		return
	caption_panel.modulate.a = 0.0
	_caption_revealing = true
	_caption_tween = _own(caption_panel.create_tween())
	if not Settings.reduce_motion:
		_caption_tween.tween_interval(delay * 0.5)
	_caption_tween.tween_property(caption_panel, "modulate:a", 1.0, DS.DUR_FAST if Settings.reduce_motion else DS.DUR_SLOW)
	_caption_tween.tween_callback(func() -> void: _caption_revealing = false)


func _complete_caption() -> void:
	if _caption_tween != null:
		_caption_tween.kill()
	caption_panel.modulate.a = 1.0
	_caption_revealing = false


## Vrai tant que la légende de la planche courante se révèle.
func is_caption_revealing() -> bool:
	return _caption_revealing


func _show_next_mark() -> void:
	next_mark.visible = true
	next_mark.modulate.a = 1.0
	if Settings.reduce_motion or Settings.fx_intensity <= 0.0:
		return
	if _next_tween != null:
		_next_tween.kill()
	var half: float = 0.5 / DS.CIN_NEXT_BLINK_HZ
	_next_tween = _own(next_mark.create_tween().set_loops())
	_next_tween.tween_property(next_mark, "modulate:a", 0.45, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_next_tween.tween_property(next_mark, "modulate:a", 1.0, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_skip_prompt(on: bool) -> void:
	if on == skip_prompt_visible and skip_row != null and (skip_row.modulate.a > 0.0) == on:
		return
	skip_prompt_visible = on
	if skip_row == null:
		return
	if Settings.reduce_motion or not is_inside_tree():
		skip_row.modulate.a = 1.0 if on else 0.0
		return
	_own(skip_row.create_tween()).tween_property(skip_row, "modulate:a", 1.0 if on else 0.0, DS.DUR_BASE)


func _finish(was_skipped: bool) -> void:
	if phase == Phase.DONE or is_closing():
		return
	phase = Phase.DONE
	skipped = was_skipped
	_cancel_hold()
	if record_seen and def != null:
		ProfileService.record_cinematic_seen(save_dir, String(def.id), replay_record())
	_closing = true
	_kill_tweens()
	_collect_preloads()
	# Contrat §12 ter.6 : `finished(skipped: bool)` (signal hérité de ScreenBase).
	finished.emit(was_skipped)
	queue_free()


# ---------------------------------------------------------------------------
# Chargement (planche suivante en tâche de fond, sauf qualité Bas)
# ---------------------------------------------------------------------------

func _preload_plate(i: int) -> void:
	if i < 0 or i >= plates.size() or Settings.graphics_quality_level() == 0:
		return
	for layer: PlateLayerDef in plates[i].layers:
		if layer == null or layer.texture_path.is_empty() or _preloaded.has(layer.texture_path):
			continue
		if not ResourceLoader.exists(layer.texture_path) or ResourceLoader.has_cached(layer.texture_path):
			continue
		if ResourceLoader.load_threaded_request(layer.texture_path, "Texture2D") == OK:
			_preloaded.append(layer.texture_path)


func _texture_for(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	if _preloaded.has(path):
		_preloaded.erase(path)
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			return ResourceLoader.load_threaded_get(path) as Texture2D
	return load(path) as Texture2D


## Tween suivi : tous sont arrêtés à la sortie (aucun ne survit à l'écran).
func _own(tween: Tween) -> Tween:
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t != null and t.is_valid())
	_tweens.append(tween)
	return tween


func _kill_tweens() -> void:
	for t: Tween in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


## Récupère les chargements en tâche de fond lancés (une requête abandonnée
## reste en mémoire jusqu'à la sortie) ; appelé à la fin, encore dans l'arbre.
func _collect_preloads() -> void:
	for path: String in _preloaded:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	_preloaded.clear()


func _exit_tree() -> void:
	_kill_tweens()
	# Requêtes terminées récupérées (sans bloquer : une requête encore en cours
	# finit seule dans le cache de `ResourceLoader`).
	for path: String in _preloaded:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
	_preloaded.clear()


## Manifeste des planches (ancres holographiques), lu une fois ; vide si absent.
static func manifest() -> Dictionary:
	if not _manifest_loaded:
		_manifest_loaded = true
		if FileAccess.file_exists(MANIFEST_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
			if parsed is Dictionary:
				_manifest = parsed
	return _manifest


## Rectangles holographiques (px de planche) du fond d'une planche.
static func holo_rects(plate: PlateDef) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var groups: Dictionary = manifest().get("groups", {})
	for layer: PlateLayerDef in plate.layers:
		if layer == null or layer.kind != PlateLayerDef.KIND_BG:
			continue
		var group: Dictionary = groups.get(layer.texture_path.get_file().get_basename(), {})
		for raw: Variant in group.get("holo", []):
			var r: Array = raw as Array
			if r != null and r.size() == 4:
				rects.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	if rects.is_empty():
		# Repli : la boîte des étiquettes, sinon le centre haut de la planche.
		var union: Rect2 = Rect2()
		for lab: PlateLabelDef in plate.labels:
			if lab != null:
				var r: Rect2 = Rect2(lab.rect.position * PLATE_SIZE, lab.rect.size * PLATE_SIZE)
				union = r if union.size == Vector2.ZERO else union.merge(r)
		if union.size == Vector2.ZERO:
			union = Rect2(PLATE_SIZE * Vector2(0.38, 0.22), PLATE_SIZE * Vector2(0.24, 0.24))
		rects.append(union.grow(DS.SPACE_4))
	return rects


static func fx_shader() -> Shader:
	if _fx_shader == null:
		_fx_shader = Shader.new()
		_fx_shader.code = FX_SHADER_CODE
	return _fx_shader


# ---------------------------------------------------------------------------
# Commandes : appui = planche suivante, maintien 0,8 s = tout passer
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if phase == Phase.DONE or is_closing() or not is_visible_in_tree():
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		var on_button: bool = skip_button != null and skip_row.modulate.a > 0.0 and skip_button.get_global_rect().has_point(click.position)
		var source: StringName = HOLD_BUTTON if on_button else HOLD_CLICK
		if click.pressed:
			begin_hold(source)
		else:
			end_hold(source)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse:
		return
	if event.is_action(&"cancel") or event.is_action(&"ui_cancel"):
		if event.is_echo():
			get_viewport().set_input_as_handled()
			return
		if event.is_pressed():
			begin_hold(HOLD_CANCEL)
		else:
			end_hold(HOLD_CANCEL)
		get_viewport().set_input_as_handled() # Échap / Ⓑ n'ouvrent pas la pause ici
		return
	if event.is_action(&"ui_accept"):
		if not event.is_echo():
			if event.is_pressed():
				begin_hold(HOLD_ACCEPT)
			else:
				end_hold(HOLD_ACCEPT)
		get_viewport().set_input_as_handled()


func begin_hold(source: StringName) -> void:
	if hold_source != &"" or phase == Phase.DONE:
		return
	hold_source = source
	hold_time = 0.0


## Fin d'un maintien : relâché avant 0,8 s, c'est un appui (planche suivante ;
## Échap / Ⓑ / TOUT PASSER : l'invite s'affiche).
func end_hold(source: StringName) -> void:
	if hold_source != source:
		return
	var short: bool = hold_time < DS.CIN_SKIP_HOLD
	_cancel_hold()
	if not short:
		return
	if source == HOLD_ACCEPT or source == HOLD_CLICK:
		request_next()
	else:
		_set_skip_prompt(true)


func _update_hold(delta: float) -> void:
	if hold_source == &"":
		return
	hold_time += delta
	if hold_ring != null:
		hold_ring.progress = clampf(hold_time / DS.CIN_SKIP_HOLD, 0.0, 1.0)
	if hold_time >= DS.CIN_SKIP_HOLD:
		skip_all()


func _cancel_hold() -> void:
	hold_source = &""
	hold_time = 0.0
	if hold_ring != null:
		hold_ring.progress = 0.0


# ---------------------------------------------------------------------------
# Planche : couches, effets, étiquettes
# ---------------------------------------------------------------------------

## Une planche affichée : couches aux `rect` des données (espace 2048×1152),
## parallaxe par profondeur, zoom autour du centre.
class PlateStage:
	extends Control

	var screen: CinematicScreen = null
	var plate: PlateDef = null
	var base_scale: float = 1.0
	## [nœud, position de base, profondeur].
	var layers: Array[Array] = []
	## Couches d'état `LIT` dans l'ordre d'extinction, et voiles holographiques.
	## [nœud, `state_index`] des couches `LIT`.
	var lit_layers: Array[Array] = []
	var holo_veils: Array[ColorRect] = []
	var fx_rects: Array[ColorRect] = []
	var glyph: HoloGlyph = null
	## Couches `LIT` déjà éteintes (PL-F9-1).
	var glass_off: int = 0

	func _init() -> void:
		size = CinematicScreen.PLATE_SIZE
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func build(p_plate: PlateDef, flags: Dictionary[StringName, Variant], figures: Dictionary[String, Texture2D],
			loader: Callable) -> void:
		plate = p_plate
		for layer: PlateLayerDef in plate.layers:
			if layer == null:
				continue
			if layer.kind == PlateLayerDef.KIND_FX:
				_add_fx(layer)
				continue
			var tex: Texture2D = loader.call(layer.texture_path) as Texture2D
			if tex == null:
				continue
			var node: TextureRect = _add_texture(tex, layer.rect, layer.depth, false)
			node.name = "%s_%s" % [String(layer.kind).to_upper(), layer.texture_path.get_file().get_basename()]
			if layer.kind == PlateLayerDef.KIND_LIT:
				lit_layers.append([node, layer.state_index])
		for slot: FigureSlotDef in plate.figures:
			if slot == null:
				continue
			var tex: Texture2D = figures.get("%s/%s" % [plate.id, slot.id], null)
			if tex == null:
				continue
			var fig: TextureRect = _add_texture(tex, slot.rect, slot.depth, true)
			fig.name = "Figure_%s" % slot.id
		_add_holo()
		_add_labels()
		apply_settings()
		update_effects(0.0)

	func _add_texture(tex: Texture2D, rect: Rect2, depth: float, keep_aspect: bool) -> TextureRect:
		var t: TextureRect = TextureRect.new()
		t.texture = tex
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
		var pos: Vector2 = rect.position * CinematicScreen.PLATE_SIZE
		var sz: Vector2 = rect.size * CinematicScreen.PLATE_SIZE
		t.position = pos
		t.size = sz
		t.material = PlatePaintStyle.paper_material(pos, sz, Settings.fx_intensity)
		add_child(t)
		layers.append([t, pos, depth])
		return t

	func _add_fx(layer: PlateLayerDef) -> void:
		var fx: ColorRect = ColorRect.new()
		fx.name = "FX_%s" % layer.fx_kind
		fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pos: Vector2 = layer.rect.position * CinematicScreen.PLATE_SIZE
		fx.position = pos
		fx.size = layer.rect.size * CinematicScreen.PLATE_SIZE
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = CinematicScreen.fx_shader()
		mat.set_shader_parameter(&"kind", CinematicScreen.fx_index(layer.fx_kind))
		mat.set_shader_parameter(&"density", layer.fx_density)
		mat.set_shader_parameter(&"tint", DS.TEXT_PRIMARY)
		mat.set_shader_parameter(&"plate_px", fx.size)
		fx.material = mat
		add_child(fx)
		fx_rects.append(fx)
		layers.append([fx, pos, layer.depth])

	## Voiles `HOLO` (jamais sous la légende, qui est hors de la planche) et
	## effet scénarisé ; seulement si la planche porte des étiquettes ou un effet.
	func _add_holo() -> void:
		if plate.labels.is_empty() and plate.holo_effect == &"":
			return
		var shader: Shader = load(CinematicScreen.HOLO_SHADER_PATH) as Shader
		var tint: Color = PlatePaintStyle.dominant_color(plate.dominant).lerp(DS.ACCENT_CYAN, 0.3).lerp(DS.TEXT_PRIMARY, 0.2)
		var rects: Array[Rect2] = CinematicScreen.holo_rects(plate)
		for r: Rect2 in rects:
			var veil: ColorRect = ColorRect.new()
			veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var grown: Vector2 = r.size / (1.0 - 2.0 * CinematicScreen.HOLO_HALO)
			veil.position = r.position - (grown - r.size) * 0.5
			veil.size = grown
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter(&"tint", tint)
			mat.set_shader_parameter(&"power", DS.CIN_HOLO_POWER)
			mat.set_shader_parameter(&"halo", CinematicScreen.HOLO_HALO)
			veil.material = mat
			veil.name = "Holo_%d" % holo_veils.size()
			add_child(veil)
			holo_veils.append(veil)
		if plate.holo_effect in [CinematicScreen.HOLO_WAVEFORM, CinematicScreen.HOLO_EYE, CinematicScreen.HOLO_RINGS]:
			glyph = HoloGlyph.new()
			glyph.name = "HoloGlyph_%s" % plate.holo_effect
			glyph.effect = plate.holo_effect
			var area: Rect2 = rects[0]
			glyph.position = area.position
			glyph.size = area.size
			add_child(glyph)

	func _add_labels() -> void:
		for lab: PlateLabelDef in plate.labels:
			if lab == null:
				continue
			var text: String = lab.display_text(func(k: String) -> String: return UiText.t(k, "") if UiText.has(k) else "")
			if text.is_empty():
				continue # jamais une clé brute
			var l: Label = Label.new()
			l.name = "Label_%s" % lab.text_key.validate_node_name()
			l.text = text
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var display: bool = lab.style == &"holo_display"
			var font_px: int = int(lab.rect.size.y * CinematicScreen.PLATE_SIZE.y * (0.45 if display else 0.7))
			l.add_theme_font_override(&"font", load(DS.FONT_DISPLAY_PATH if display else DS.FONT_MONO_PATH) as Font)
			l.add_theme_font_size_override(&"font_size", clampi(font_px, DS.FS_CAPTION, 96))
			l.add_theme_color_override(&"font_color", DS.TEXT_PRIMARY)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if display else TextServer.AUTOWRAP_OFF
			l.clip_text = false
			var pos: Vector2 = lab.rect.position * CinematicScreen.PLATE_SIZE
			l.position = pos
			l.size = lab.rect.size * CinematicScreen.PLATE_SIZE
			add_child(l)
			layers.append([l, pos, 0.0])

	## Réglages d'effets (scintillement, intensité, qualité) appliqués aux shaders.
	func apply_settings() -> void:
		var frozen: bool = Settings.reduce_motion or Settings.fx_intensity <= 0.0
		for veil: ColorRect in holo_veils:
			var mat: ShaderMaterial = veil.material as ShaderMaterial
			mat.set_shader_parameter(&"flicker", 1.0 if Settings.holo_flicker else 0.0)
			mat.set_shader_parameter(&"fx_intensity", Settings.fx_intensity)
			mat.set_shader_parameter(&"plate_time", CinematicScreen.FROZEN_TIME if frozen else -1.0)
		var still_fx: bool = frozen or Settings.graphics_quality_level() == 0
		for fx: ColorRect in fx_rects:
			var mat: ShaderMaterial = fx.material as ShaderMaterial
			mat.set_shader_parameter(&"strength", maxf(Settings.fx_intensity, 0.5))
			mat.set_shader_parameter(&"frozen_time", CinematicScreen.FROZEN_TIME if still_fx else -1.0)
		for entry: Array in layers:
			var node: CanvasItem = entry[0]
			var paper: ShaderMaterial = node.material as ShaderMaterial
			if paper != null and paper.shader != null and paper.shader.resource_path == PlatePaintStyle.PAPER_SHADER:
				paper.set_shader_parameter(&"paper_alpha", PlatePaintStyle.PAPER_ALPHA * clampf(Settings.fx_intensity, 0.0, 1.0))
		if glyph != null:
			glyph.animated = not frozen and Settings.holo_flicker
			glyph.queue_redraw()

	## Zoom lent et parallaxe à l'instant `t` (0 → 1) de la planche.
	func apply_motion(t: float, reduced: bool) -> void:
		if plate == null:
			return
		var eased: float = 0.5 - 0.5 * cos(PI * clampf(t, 0.0, 1.0)) # ease.inout (sinus)
		var zoom: float = 1.0 if reduced else lerpf(1.0, minf(plate.zoom_to, DS.KEN_BURNS_MAX), eased)
		scale = Vector2.ONE * base_scale * zoom
		var pan: Vector2 = plate.pan.normalized() if plate.pan.length() > 0.0 else Vector2.RIGHT
		var amount: float = 0.0 if reduced else minf(plate.parallax_px, DS.PARALLAX_MAX_PX) * (eased - 0.5)
		for entry: Array in layers:
			var node: Control = entry[0]
			var base: Vector2 = entry[1]
			var depth: float = entry[2]
			# Décalage en px de planche (1 080 lignes visibles : px à 1080p × 1152/1080).
			node.position = base - pan * amount * depth * (CinematicScreen.PLATE_SIZE.y / CinematicScreen.VIEW_LINES)

	## Effets scénarisés à l'instant `t` (s) de la planche.
	func update_effects(t: float) -> void:
		if plate == null or plate.holo_effect != PlateDef.HOLO_GLASS_OFF_SEQUENCE:
			return
		var off: int = lit_layers.size() if Settings.reduce_motion \
				else clampi(floori((t - DS.CIN_GLASS_OFF_DELAY) / DS.CIN_GLASS_OFF_STEP) + 1, 0, lit_layers.size())
		while glass_off < off:
			_switch_off(glass_off, not Settings.reduce_motion)
			glass_off += 1

	## Éteint la `n`-ième couche `LIT` (ordre d'extinction) et son voile.
	func _switch_off(n: int, animated: bool) -> void:
		var node: CanvasItem = lit_layers[n][0]
		var state: int = lit_layers[n][1]
		var veil: ColorRect = holo_veils[state] if state >= 0 and state < holo_veils.size() else null
		if not animated:
			node.modulate.a = 0.0
			if veil != null:
				(veil.material as ShaderMaterial).set_shader_parameter(&"power", 0.0)
			return
		var tween: Tween = screen._own(node.create_tween()) if screen != null else node.create_tween()
		tween.tween_property(node, "modulate:a", 0.0, DS.DUR_SLOW)
		if veil != null:
			var mat: ShaderMaterial = veil.material as ShaderMaterial
			tween.parallel().tween_method(func(v: float) -> void: mat.set_shader_parameter(&"power", v), DS.CIN_HOLO_POWER, 0.0,
					DS.DUR_SLOW)

	## Couches `LIT` encore allumées (tests, captures).
	func lit_count() -> int:
		return lit_layers.size() - glass_off


## Effet holographique dessiné (forme d'onde, Œil du Consortium, cercles du
## carillon) : traits fins, mouvement lent ≤ 0,5 Hz, figé si `animated` est faux.
class HoloGlyph:
	extends Control

	var effect: StringName = &""
	var animated: bool = true
	var _t: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if animated:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var fx: float = clampf(Settings.fx_intensity, 0.5, 1.0)
		var c: Vector2 = size * 0.5
		match effect:
			CinematicScreen.HOLO_WAVEFORM:
				var color: Color = Color(DS.ACCENT_CYAN, 0.75 * fx)
				var points: PackedVector2Array = []
				var n: int = 64
				for i: int in n + 1:
					var x: float = float(i) / n
					var env: float = sin(PI * x)
					var y: float = env * (0.5 * sin(TAU * (x * 3.0 + _t * 0.25)) + 0.3 * sin(TAU * (x * 7.0 - _t * 0.4)) \
							+ 0.2 * sin(TAU * (x * 13.0 + _t * 0.15)))
					points.append(Vector2(x * size.x, c.y - y * size.y * 0.32))
				draw_polyline(points, color, 3.0, true)
				draw_line(Vector2(0.0, c.y), Vector2(size.x, c.y), Color(DS.ACCENT_CYAN, 0.25 * fx), 1.0)
			CinematicScreen.HOLO_EYE:
				var pulse: float = 0.85 + (0.1 * sin(TAU * 0.25 * _t) if animated else 0.0)
				var color: Color = Color(DS.ACCENT_YELLOW, pulse * fx)
				var w: float = minf(size.x * 0.45, size.y * 0.8)
				var h: float = w * 0.42
				var upper: PackedVector2Array = []
				var lower: PackedVector2Array = []
				for i: int in 33:
					var x: float = lerpf(-w, w, float(i) / 32.0)
					var y: float = h * (1.0 - pow(x / w, 2.0))
					upper.append(c + Vector2(x, -y))
					lower.append(c + Vector2(x, y))
				draw_polyline(upper, color, 3.0, true)
				draw_polyline(lower, color, 3.0, true)
				draw_arc(c, h * 0.82, 0.0, TAU, 48, color, 3.0, true)
				draw_circle(c, h * 0.3, color)
			CinematicScreen.HOLO_RINGS:
				var color: Color = Color(DS.ACCENT_YELLOW, 0.8 * fx)
				var max_r: float = minf(size.x, size.y) * 0.5
				for k: int in 3:
					var phase_k: float = fposmod(_t / 3.0 + k / 3.0, 1.0) if animated else (k + 1) / 3.5
					var r: float = max_r * (0.15 + 0.85 * phase_k)
					draw_arc(c, r, 0.0, TAU, 64, Color(color, color.a * (1.0 - phase_k * 0.7)), 2.0, true)


## Anneau de progression du maintien (cyan = interactif ; le libellé dit l'action).
class HoldRing:
	extends Control

	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(DS.CIN_RING_SIZE, DS.CIN_RING_SIZE)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - DS.BORDER_STRONG
		draw_arc(c, r, 0.0, TAU, 40, Palette.LINE_SUBTLE, DS.BORDER_STRONG, true)
		if progress > 0.0:
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * progress, 40, DS.ACCENT_CYAN, DS.BORDER_STRONG + 1.0, true)


## Index du type d'effet procédural (`PlateLayerDef.FX_*`) dans le shader.
static func fx_index(kind: StringName) -> int:
	match kind:
		PlateLayerDef.FX_RAIN:
			return 0
		PlateLayerDef.FX_SMOKE:
			return 1
		PlateLayerDef.FX_DUST:
			return 2
		PlateLayerDef.FX_AIR:
			return 3
	return 4 # brume


## Effets `FX` procéduraux (M14 §3.3) : pluie, fumée (lente, jamais de flash),
## poussière, particules d'air, brume. `frozen_time` ≥ 0 : image fixe
## (`reduce_motion`, qualité Bas). Teinte DS passée par uniforme.
const FX_SHADER_CODE: String = """
shader_type canvas_item;
render_mode blend_mix, unshaded;
uniform int kind = 0;
uniform float density : hint_range(0.0, 1.0) = 0.5;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float frozen_time = -1.0;
uniform vec4 tint : source_color = vec4(0.91, 0.945, 0.96, 1.0);
uniform vec2 plate_px = vec2(2048.0, 1152.0);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}
void fragment() {
	float t = frozen_time >= 0.0 ? frozen_time : TIME;
	vec2 p = UV * plate_px;
	float a = 0.0;
	if (kind == 0) {
		vec2 q = vec2(p.x + p.y * 0.18, p.y);
		float lane = floor(q.x / 11.0);
		float h = hash12(vec2(lane, 3.0));
		float y = fract(q.y / 260.0 + t * (1.4 + h) + h * 9.0);
		float streak = smoothstep(0.0, 0.03, y) * (1.0 - smoothstep(0.03, 0.16, y));
		float thin = 1.0 - smoothstep(0.0, 1.0, abs(fract(q.x / 11.0) - 0.5) * 11.0);
		a = streak * thin * step(1.0 - density * 0.5, h) * 0.32;
	} else if (kind == 1 || kind == 4) {
		float speed = kind == 1 ? 0.012 : 0.004;
		float n = fbm(p / 340.0 + vec2(t * speed, -t * speed * 0.6));
		float band = kind == 1 ? smoothstep(1.05, 0.25, UV.y) : 1.0;
		a = smoothstep(0.42, 0.9, n) * density * (kind == 1 ? 0.5 : 0.35) * band;
	} else {
		float cell = 26.0;
		float rise = kind == 3 ? -t * 9.0 : t * 4.0;
		vec2 q = vec2(p.x + sin(t * 0.3 + p.y * 0.01) * 6.0, p.y + rise);
		vec2 id = floor(q / cell);
		vec2 f = fract(q / cell) - 0.5;
		float h = hash12(id);
		vec2 off = vec2(hash12(id + 7.1), hash12(id + 3.7)) - 0.5;
		float d = length(f - off * 0.6);
		float r = kind == 3 ? 0.07 : 0.05;
		a = step(1.0 - density * 0.4, h) * (1.0 - smoothstep(r * 0.4, r, d)) * (kind == 3 ? 0.45 : 0.35);
	}
	COLOR = vec4(tint.rgb, clamp(a * strength, 0.0, 0.6));
}
"""
