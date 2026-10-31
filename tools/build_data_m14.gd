## Contenu du jalon M14 « Ambiance » pour `tools/build_data.gd` (lots E et F) —
## fabriques statiques, chargées par `preload` (pas de `class_name` : outil).
##
## Source : `docs/M14.md` (§2.5 tension par jour et poids des événements, §3.4
## séquences et planches, §3.5 figures nommées, §4.4 annonces d'ambiance, §5.2
## portraits) et les décisions D-174 → D-198 (dont D-194 : valeurs des champs
## musicaux par le lot F ; D-195 : traitement « lavis gravé » des planches).
## Formats : lot A (`scripts/core/*`, ARCHITECTURE §12 ter). Les textes sont
## des clés de `data/i18n/fr.csv` (`cin_*`, `cin_lbl_*`, `pa_*`), ajoutées en
## fin de fichier ; `validate_texts` vérifie leur présence et leur longueur.
##
## Sorties (écrites par `build_data.gd`) :
## - `data/cinematics/plates/pl_*.tres` (66 `PlateDef` : les 63 planches de
##   M14 §3.4 + 3 variantes de fond d'une même place : PL-F1-3 borne jaune,
##   PL-F3-2 luciole au crayon, PL-E-FIG au sas Castellanos du monde D) et
##   `data/cinematics/cinematics.tres` (18 `CinematicDef`) ;
## - `data/audio/pa_lines.tres` (`PaLineTable` : 52 annonces d'ambiance) ;
## - champs M14 des jours (`music_tension`, `music_floor`, `music_action` des
##   annonces de jeu), des événements (`music_weight`) et des personnages du
##   Dossier (`portrait_cases`).
##
## Rendu hors ligne (lot C, `tools/build_plates.gd`) : chaque couche nomme son
## image (`res://assets/cinematics/<bg|mid|fig|lit>/<id>.webp`) ; les fonds
## partagés (46, `bg_<id>`) portent le même chemin. Caméras laissées aux valeurs
## par défaut : le lot C les règle et les reporte ici (ou les lit dans son
## manifeste). Rectangles des couches, labels et figures : intentions de
## composition (0..1 sur 2048×1152), à recaler sur les ancres du manifeste.
extends RefCounted

const CINEMATICS_DIR: String = "res://data/cinematics"
const PLATES_DIR: String = "res://data/cinematics/plates"
const AUDIO_DIR: String = "res://data/audio"
const ASSET_ROOT: String = "res://assets/cinematics"
## Lot C (BOOTH_SCENE §21) : manifeste des planches rendues. Quand il existe,
## les rectangles des couches `MID`/`FIG`/`LIT` et des `Label` littéraux posés
## sur une ancre du décor (plaques de numéro, plaque de coque) sont **lus dans le
## rendu** (`_rendered_rect`, `_anchor_rect`) ; sinon les intentions ci-dessous.
const RENDER_MANIFEST: String = "res://assets/cinematics/manifest.json"
static var _render_cache: Dictionary = {}

## Traitement D-195 « lavis gravé » (BOOTH_SCENE §19.4, variante B) : Kuwahara
## rayon 6, rampe de 8 tons ; hachures, papier et grain réglés par le lot C.
const PAINT_RADIUS_PX: int = 6
const PAINT_TONES: int = 8

## Tension narrative par jour (M14 §2.5, P6 / P7) : `[jour, tension, plancher]`
## (plancher −1 = aucun). J31 : 0, sans plancher (plafond N2 tenu par
## `MusicLibraryDef.max_level_for`).
const MUSIC_DAYS: Array[Array] = [
	[1, 0, -1], [2, 0, -1], [3, 0, -1],
	[4, 1, -1], [5, 1, -1], [6, 1, -1], [7, 1, -1],
	[8, 2, -1], [9, 2, -1], [10, 3, -1],
	[11, 1, -1], [12, 1, -1], [13, 1, -1], [14, 1, -1], [15, 1, -1],
	[16, 2, -1], [17, 2, -1], [18, 2, -1], [19, 2, -1], [20, 3, 1],
	[21, 1, -1], [22, 1, -1], [23, 1, -1], [24, 1, -1],
	[25, 2, -1], [26, 2, -1], [27, 2, -1], [28, 2, -1],
	[29, 3, -1], [30, 3, 2],
	[31, 0, -1],
]
## Poids des événements de station (M14 §2.5, P5). EV-05 : cas particulier
## « power down » du lot B, poids 0.
const MUSIC_WEIGHTS: Dictionary[StringName, float] = {
	&"ev_01": 0.1, &"ev_02": 0.4, &"ev_03": 0.5, &"ev_04": 0.4, &"ev_05": 0.0,
	&"ev_06": 0.3, &"ev_07": 0.4, &"ev_08": 0.1, &"ev_09": 0.5,
}
## Effet des annonces de jeu sur la musique (M14 §2.5 « Cas particuliers ») :
## `silence` pour les vitres qui s'éteignent (grèves), `drop` quand le Hall
## écoute (couvre-feu, liste lue, nouvelles graves), `swell` pour l'autorité
## (Arbitre, prorogation, arrestations). Les autres : aucun effet.
const MUSIC_ACTIONS: Dictionary[String, StringName] = {
	"hall_j16_curfew": HallAnnouncementDef.MUSIC_DROP,
	"hall_j20_registre": HallAnnouncementDef.MUSIC_DROP,
	"hall_j20_strike": HallAnnouncementDef.MUSIC_SILENCE,
	"hall_j25_tycho": HallAnnouncementDef.MUSIC_DROP,
	"hall_j27_arbitre": HallAnnouncementDef.MUSIC_SWELL,
	"hall_j27_cameras": HallAnnouncementDef.MUSIC_DROP,
	"hall_j29_prorogation": HallAnnouncementDef.MUSIC_SWELL,
	"hall_j30_transit": HallAnnouncementDef.MUSIC_DROP,
	"hall_j30_arrests": HallAnnouncementDef.MUSIC_SWELL,
	"hall_j30_strike": HallAnnouncementDef.MUSIC_SILENCE,
}
## Liste blanche des portraits du Dossier (M14 §5.2, D-191, D-194) : seuls les
## personnages dont un cas **ne montre pas leur visage** ont une liste ; les
## autres gardent la liste vide (= tous leurs cas). Le visage retenu est
## toujours celui de l'acteur à la vitre (jamais une photo de document : SC-13,
## SC-84b), si bien qu'un usurpateur qui joue sa propre figure (Lev en SC-13,
## Okonkwo en SC-35b, Arkady en SC-20) n'est pas exclu.
const PORTRAIT_CASES: Dictionary[StringName, Array] = {
	# SC-29 : Katya Mazur, la fille de Dariusz (autre visage).
	&"chr_mazur": [&"sc_11", &"sc_78"],
	# SC-31, SC-32 : deux homonymes ; SC-69 reprend le visage de SC-30.
	&"chr_kerr_ceres": [&"sc_30", &"sc_69"],
	# Carte de groupe : « le premier » (tuto concordant, repris par SC-90) ; la
	# première personne refusée (tuto, SC-85a/b) ne prête pas son visage.
	&"chr_premiers": [&"tuto_concordant", &"sc_90"],
}

## Clés de légende des étiquettes holographiques traduisibles (M14 §3.1 r. 6).
const LABEL_KEYS: PackedStringArray = ["cin_lbl_charter", "cin_lbl_ledger"]

## Contexte des annonces d'ambiance (M14 §4.4) : poids de tirage.
const PA_WEIGHT_ACT: float = 1.0
const PA_WEIGHT_DAYS: float = 2.0
const PA_WEIGHT_EVENT: float = 4.0
const PA_WEIGHT_WORLD: float = 1.0
const PA_WEIGHT_GARDE: float = 1.0


# ---------------------------------------------------------------------------
# Champs musicaux et portraits (lot F, D-194)
# ---------------------------------------------------------------------------

## `music_tension` / `music_floor` du jour et `music_action` de ses annonces
## de jeu ; problèmes (jour hors table) en retour.
static func extend_day(day: DayDef) -> PackedStringArray:
	var problems: PackedStringArray = []
	var row: Array = _music_row(day.day_number)
	if row.is_empty():
		problems.append("jour %d sans tension musicale (MUSIC_DAYS)" % day.day_number)
	else:
		day.music_tension = row[1]
		day.music_floor = row[2]
	for announcement: HallAnnouncementDef in day.announcements:
		if announcement != null:
			announcement.music_action = MUSIC_ACTIONS.get(announcement.text_key, &"")
	return problems


static func _music_row(day_number: int) -> Array:
	for row: Array in MUSIC_DAYS:
		if row[0] == day_number:
			return row
	return []


## `music_weight` des événements de station.
static func configure_events(events: Array[StationEventDef]) -> PackedStringArray:
	var problems: PackedStringArray = []
	for event: StationEventDef in events:
		if not MUSIC_WEIGHTS.has(event.id):
			problems.append("événement %s sans poids musical" % event.id)
			continue
		event.music_weight = MUSIC_WEIGHTS[event.id]
	return problems


## `portrait_cases` des personnages du Dossier (liste blanche ⊂ `case_ids`).
static func configure_characters(table: CharacterTableDef) -> PackedStringArray:
	var problems: PackedStringArray = []
	var seen: Array[StringName] = []
	for character: CharacterDef in table.characters:
		if not PORTRAIT_CASES.has(character.id):
			continue
		seen.append(character.id)
		var cases: Array[StringName] = []
		for case_id: StringName in PORTRAIT_CASES[character.id]:
			if not character.case_ids.has(case_id):
				problems.append("%s : cas de portrait %s absent de case_ids" % [character.id, case_id])
			cases.append(case_id)
		character.portrait_cases = cases
	for chr_id: StringName in PORTRAIT_CASES:
		if not seen.has(chr_id):
			problems.append("personnage %s introuvable (PORTRAIT_CASES)" % chr_id)
	return problems


# ---------------------------------------------------------------------------
# Annonces d'ambiance (M14 §4.4, VH-6, B85)
# ---------------------------------------------------------------------------

## Table des 52 annonces `pa_*` : `[clé, condition, poids]`.
static func build_pa_lines() -> PaLineTable:
	var table: PaLineTable = PaLineTable.new()
	var rows: Array[Array] = []
	for i: int in range(1, 11):
		rows.append(["pa_a1_%02d" % i, _pa_act(1), PA_WEIGHT_ACT])
	rows.append(["pa_a1_q2_01", _pa_days(8, 10), PA_WEIGHT_DAYS])
	rows.append(["pa_a1_q2_02", _pa_days(8, 10), PA_WEIGHT_DAYS])
	for i: int in range(1, 11):
		var key: String = "pa_a2_%02d" % i
		if key == "pa_a2_08":
			rows.append([key, _pa_days(16, 20), PA_WEIGHT_DAYS])
		else:
			rows.append([key, _pa_act(2), PA_WEIGHT_ACT])
	var act3_days: Dictionary[String, Vector2i] = {
		"pa_a3_03": Vector2i(21, 29), "pa_a3_05": Vector2i(21, 28), "pa_a3_06": Vector2i(27, 30), "pa_a3_10": Vector2i(28, 30),
	}
	for i: int in range(1, 11):
		var key: String = "pa_a3_%02d" % i
		if act3_days.has(key):
			rows.append([key, _pa_days(act3_days[key].x, act3_days[key].y), PA_WEIGHT_DAYS])
		else:
			rows.append([key, _pa_act(3), PA_WEIGHT_ACT])
	# EV-05 (coupure) : aucune annonce d'ambiance.
	for n: int in [1, 2, 3, 4, 6, 7, 8, 9]:
		rows.append(["pa_ev%02d" % n, _pa_event(StringName("ev_%02d" % n)), PA_WEIGHT_EVENT])
	for i: int in range(1, 5):
		rows.append(["pa_garde_%02d" % i, FlagCondition.make([PaLineTable.FLAG_GARDE]), PA_WEIGHT_GARDE])
	for world: String in ["a", "b", "c", "d"]:
		for i: int in range(1, 3):
			rows.append(["pa_epi_%s_%02d" % [world, i], FlagCondition.make([StringName(PaLineTable.FLAG_WORLD_PREFIX + world)]),
					PA_WEIGHT_WORLD])
	var weights: PackedFloat32Array = []
	for row: Array in rows:
		var line: HallAnnouncementDef = HallAnnouncementDef.new()
		line.text_key = row[0]
		line.condition = row[1]
		# Annonces d'ambiance : ducking −3 dB par l'AudioDirector (M14 §2.10),
		# aucun effet sur le niveau musical.
		line.music_action = &""
		table.lines.append(line)
		weights.append(row[2])
	table.weights = weights
	return table


## Acte `act` de la campagne (jamais en Garde ni au J31 : `pa_act` = 0).
static func _pa_act(act: int) -> FlagCondition:
	return FlagCondition.make([], [PaLineTable.FLAG_GARDE], {PaLineTable.GAUGE_ACT: act}, {PaLineTable.GAUGE_ACT: act})


## Jours `first` → `last` de la campagne.
static func _pa_days(first: int, last: int) -> FlagCondition:
	return FlagCondition.make([], [PaLineTable.FLAG_GARDE], {PaLineTable.GAUGE_ACT: 1, PaLineTable.GAUGE_DAY: first},
			{PaLineTable.GAUGE_DAY: last})


## Pendant l'événement `event_id` (campagne ou Garde).
static func _pa_event(event_id: StringName) -> FlagCondition:
	return FlagCondition.make([StringName(PaLineTable.FLAG_EVENT_PREFIX + String(event_id))])


# ---------------------------------------------------------------------------
# Cinématiques (M14 §3, B91 ; D-183 → D-186, D-195)
# ---------------------------------------------------------------------------

## Toutes les planches, dans l'ordre de M14 §3.4 (ids uniques).
static func build_plates() -> Array[PlateDef]:
	var plates: Array[PlateDef] = []
	plates.append_array(_plates_f1())
	plates.append_array(_plates_f2())
	plates.append_array(_plates_f3())
	plates.append_array(_plates_f4())
	plates.append_array(_plates_f5())
	plates.append_array(_plates_f6())
	plates.append_array(_plates_f7())
	plates.append_array(_plates_f8())
	plates.append_array(_plates_f9())
	plates.append_array(_plates_f10())
	plates.append_array(_plates_epilogue())
	return plates


## Les 18 séquences ; `plates` : planches de `build_plates` (déjà enregistrées,
## référencées par chemin).
static func build_cinematics(plates: Array[PlateDef]) -> CinematicLibraryDef:
	var by_id: Dictionary[StringName, PlateDef] = {}
	for p: PlateDef in plates:
		by_id[p.id] = p
	var lib: CinematicLibraryDef = CinematicLibraryDef.new()
	lib.version = 1
	var cinematics: Array[CinematicDef] = lib.cinematics
	var act3: PackedInt32Array = PackedInt32Array([3])
	var specs: Array[Array] = [
		# [id, fin, variantes, actes, thème, planches]
		[&"cin_f1", EndingService.F1_ARRESTED, [], PackedInt32Array(), &"th_f1",
				[&"pl_f1_1", &"pl_f1_2", &"pl_f1_3", &"pl_f1_3_borne", &"pl_f1_4"]],
		[&"cin_f2", EndingService.F2_REASSIGNED, [], PackedInt32Array(), &"th_f2", [&"pl_f2_1", &"pl_f2_2", &"pl_f2_3", &"pl_f2_4"]],
		[&"cin_f3", EndingService.F3_FAMILY_LOST, [], PackedInt32Array(), &"th_f3",
				[&"pl_f3_1", &"pl_f3_2", &"pl_f3_2_lumika", &"pl_f3_3"]],
		[&"cin_f4", EndingService.F4_GLORY, [], act3, &"th_f4", [&"pl_f4_1", &"pl_f4_2", &"pl_f4_3", &"pl_f4_4"]],
		[&"cin_f5c", EndingService.F5_AIR, [EpilogueService.VARIANT_CHARTER], act3, &"th_f5c",
				[&"pl_f5c_1", &"pl_f5_2", &"pl_f5c_3", &"pl_f5_4"]],
		[&"cin_f5s", EndingService.F5_AIR, [EpilogueService.VARIANT_SECOND_VALVE], act3, &"th_f5s",
				[&"pl_f5s_1", &"pl_f5_2", &"pl_f5s_3", &"pl_f5_4"]],
		[&"cin_f5b", EndingService.F5_AIR, [EpilogueService.VARIANT_BURNERS], act3, &"th_f5b",
				[&"pl_f5b_1", &"pl_f5b_2", &"pl_f5b_3", &"pl_f5b_4"]],
		[&"cin_f6e", EndingService.F6_DRIFT, [EpilogueService.VARIANT_J10, EpilogueService.VARIANT_J20], PackedInt32Array([1, 2]),
				&"th_f6", [&"pl_f6e_1", &"pl_f6_2", &"pl_f6_3", &"pl_f6e_4"]],
		[&"cin_f6d", EndingService.F6_DRIFT, [EpilogueService.VARIANT_DRIFT], act3, &"th_f6d",
				[&"pl_f6d_1", &"pl_f6_2", &"pl_f6_3", &"pl_f6d_4"]],
		[&"cin_f6t", EndingService.F6_DRIFT, [EpilogueService.VARIANT_TYCHO], act3, &"th_f6t",
				[&"pl_f6t_1", &"pl_f6_3", &"pl_f6t_3", &"pl_f6t_4"]],
		[&"cin_f7", EndingService.F7_REOPENS, [], act3, &"th_f7", [&"pl_f7_1", &"pl_f7_2", &"pl_f7_3", &"pl_f7_4"]],
		[&"cin_f8", EndingService.F8_REGISTRE, [], act3, &"th_f8", [&"pl_f8_1", &"pl_f8_2", &"pl_f8_3", &"pl_f8_4"]],
		[&"cin_f9", EndingService.F9_STRIKE, [], act3, &"th_f9", [&"pl_f9_1", &"pl_f9_2", &"pl_f9_3", &"pl_f9_4"]],
		[&"cin_f10", EndingService.F10_PONT, [], act3, &"th_f10", [&"pl_f10_1", &"pl_f10_2", &"pl_f10_3", &"pl_f10_4"]],
	]
	for spec: Array in specs:
		var c: CinematicDef = CinematicDef.new()
		c.id = spec[0]
		c.endings = [spec[1]]
		c.ending_variants.assign(spec[2])
		c.acts = spec[3]
		c.theme_id = spec[4]
		for plate_id: StringName in spec[5]:
			c.plates.append(by_id[plate_id])
		c.title_card = true
		cinematics.append(c)
	# Conclusion du J31 (« UN AN PLUS TARD » déjà affiché au matin : pas de
	# carte de titre) ; PL-E-FIG en deuxième position, omise sans visage.
	var worlds: Array[Array] = [
		[&"cin_ea", EpilogueService.WORLD_A, [&"pl_ea_1", &"pl_e_fig", &"pl_ea_2", &"pl_ea_3"]],
		[&"cin_eb", EpilogueService.WORLD_B, [&"pl_eb_1", &"pl_e_fig", &"pl_eb_2", &"pl_eb_3"]],
		[&"cin_ec", EpilogueService.WORLD_C, [&"pl_ec_1", &"pl_e_fig", &"pl_ec_2", &"pl_ec_3"]],
		[&"cin_ed", EpilogueService.WORLD_D, [&"pl_ed_1", &"pl_e_fig_d", &"pl_ed_2", &"pl_ed_3"]],
	]
	for spec: Array in worlds:
		var c: CinematicDef = CinematicDef.new()
		c.id = spec[0]
		c.worlds = [spec[1]]
		c.theme_id = StringName("th_e" + String(spec[1]))
		for plate_id: StringName in spec[2]:
			c.plates.append(by_id[plate_id])
		c.title_card = false
		cinematics.append(c)
	return lib


## Clés de texte M14 manquantes ou trop longues dans `texts` (fr.csv).
static func validate_texts(texts: Dictionary[String, String], plates: Array[PlateDef], pa: PaLineTable) -> PackedStringArray:
	var problems: PackedStringArray = []
	for plate: PlateDef in plates:
		for key: String in plate.all_caption_keys():
			if not texts.has(key):
				problems.append("légende %s absente de fr.csv (%s)" % [key, plate.id])
			elif texts[key].length() > PlateDef.CAPTION_MAX_CHARS:
				problems.append("légende %s : %d caractères > %d" % [key, texts[key].length(), PlateDef.CAPTION_MAX_CHARS])
		for label: PlateLabelDef in plate.labels:
			if not label.literal and not texts.has(label.text_key):
				problems.append("étiquette %s absente de fr.csv (%s)" % [label.text_key, plate.id])
	for key: String in pa.all_keys():
		if not texts.has(key):
			problems.append("annonce %s absente de fr.csv" % key)
		elif texts[key].length() > PaLineTable.MAX_CHARS:
			problems.append("annonce %s : %d caractères > %d" % [key, texts[key].length(), PaLineTable.MAX_CHARS])
	return problems


# --- Fabriques de planches --------------------------------------------------

static func _plate(id: StringName, bg: String, set_id: StringName, set_variant: StringName, lighting: StringName,
		dominant: StringName, caption: String, min_act: int = 1) -> PlateDef:
	var p: PlateDef = PlateDef.new()
	p.id = id
	p.min_act = min_act
	p.max_act = 3
	p.caption_key = caption
	p.set_id = set_id
	p.set_variant = set_variant
	p.lighting = lighting
	p.dominant = dominant
	p.paint_tones = PAINT_TONES
	p.paint_radius_px = PAINT_RADIUS_PX
	p.parallax_px = 10.0
	p.zoom_to = 1.03
	p.pan = Vector2(1.0, 0.0)
	var layer: PlateLayerDef = PlateLayerDef.new()
	layer.kind = PlateLayerDef.KIND_BG
	layer.texture_path = "%s/bg/%s.webp" % [ASSET_ROOT, bg]
	layer.depth = 0.0
	p.layers.append(layer)
	return p


## Couche `MID` (accessoires, foule) : image `mid/<planche>_<nom>.webp`.
static func _mid(p: PlateDef, name: String, rect: Rect2, depth: float, props: Array[StringName] = [],
		seed: int = 0, pose: StringName = &"") -> void:
	var layer: PlateLayerDef = PlateLayerDef.new()
	layer.kind = PlateLayerDef.KIND_MID
	layer.texture_path = "%s/mid/%s_%s.webp" % [ASSET_ROOT, p.id, name]
	layer.rect = _rendered_rect(layer.texture_path, rect)
	layer.depth = depth
	layer.props = props
	layer.figure_seed = seed
	layer.pose = pose
	p.layers.append(layer)


## Couche `FIG` : silhouette **anonyme** figée (jamais un visage nommé ;
## l'agent·e toujours de dos, de profil sans visage ou en mains seules).
static func _fig(p: PlateDef, name: String, rect: Rect2, depth: float, pose: StringName, facing_deg: float,
		seed: int) -> void:
	var layer: PlateLayerDef = PlateLayerDef.new()
	layer.kind = PlateLayerDef.KIND_FIG
	layer.texture_path = "%s/fig/%s_%s.webp" % [ASSET_ROOT, p.id, name]
	layer.rect = _rendered_rect(layer.texture_path, rect)
	layer.depth = depth
	layer.pose = pose
	layer.facing_deg = facing_deg
	layer.figure_seed = seed
	p.layers.append(layer)


## Couche `FX` procédurale (shader à l'exécution, figée si `reduce_motion`).
static func _fx(p: PlateDef, kind: StringName, density: float, depth: float = 0.8) -> void:
	var layer: PlateLayerDef = PlateLayerDef.new()
	layer.kind = PlateLayerDef.KIND_FX
	layer.fx_kind = kind
	layer.fx_density = density
	layer.depth = depth
	p.layers.append(layer)


## Étiquette `HOLO` : clé `fr.csv`, ou texte littéral (numéro, horloge).
static func _label(p: PlateDef, text: String, rect: Rect2, style: StringName, literal: bool) -> void:
	var label: PlateLabelDef = PlateLabelDef.new()
	label.text_key = text
	label.rect = _anchor_rect(p, text, rect) if literal else rect
	label.style = style
	label.literal = literal
	p.labels.append(label)


## Emplacement de figure nommée (rendu à l'exécution, D-185).
static func _slot(p: PlateDef, id: StringName, cases: Array[ConditionalKey], pose: StringName, framing: StringName,
		rect: Rect2, depth: float, omit: bool = false) -> void:
	var slot: FigureSlotDef = FigureSlotDef.new()
	slot.id = id
	slot.memory_cases = cases
	slot.pose = pose
	slot.pose_frame = 0.0
	slot.framing = framing
	slot.lighting = p.lighting
	slot.render_size = Vector2i(512, 768)
	slot.rect = rect
	slot.depth = depth
	slot.silhouette_path = "%s/fig/%s_%s.webp" % [ASSET_ROOT, id, p.id]
	slot.omit_plate_if_missing = omit
	p.figures.append(slot)


## Manifeste du lot C (vide s'il n'a pas encore été rendu).
static func _rendered() -> Dictionary:
	if _render_cache.is_empty() and FileAccess.file_exists(RENDER_MANIFEST):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(RENDER_MANIFEST))
		_render_cache = data if data is Dictionary else {"files": {}}
	return _render_cache


## Rectangle réel d'une couche rendue (0..1), sinon l'intention.
static func _rendered_rect(path: String, intent: Rect2) -> Rect2:
	var entry: Dictionary = (_rendered().get("files", {}) as Dictionary).get(path, {})
	if entry.is_empty():
		return intent
	var r: Array = entry["rect_norm"]
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Ancre d'un `Label` littéral dans le décor de la planche (plaque « 04 »…), sinon l'intention.
static func _anchor_rect(p: PlateDef, text: String, intent: Rect2) -> Rect2:
	if p.layers.is_empty():
		return intent
	var stem: String = p.layers[0].texture_path.get_file().get_basename()
	var group: Dictionary = (_rendered().get("groups", {}) as Dictionary).get(stem, {})
	for anchor: Dictionary in group.get("labels", []):
		if String(anchor.get("text", "")) == text:
			var r: Array = anchor["rect_norm"]
			return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	return intent


static func _flag(name: StringName) -> FlagCondition:
	return FlagCondition.make([name])


static func _variant(variant: StringName) -> FlagCondition:
	return FlagCondition.make([StringName(CinematicService.FLAG_VARIANT_PREFIX + String(variant))])


static func _act_flag(act: int) -> StringName:
	return StringName(CinematicService.FLAG_ACT_PREFIX + str(act))


## FG-FIGURE : figure finale du J30 (Dora si `final3_dora`, sinon Mira).
static func _figure_cases() -> Array[ConditionalKey]:
	return [ConditionalKey.make("sc_82a", _flag(&"final3_dora")),
			ConditionalKey.make("sc_82b", FlagCondition.make([], [&"final3_dora"]))]


## FG-WREN : sa rencontre la plus récente (même visage, `appearance_from_case`).
static func _wren_cases() -> Array[ConditionalKey]:
	return [ConditionalKey.make("sc_72"), ConditionalKey.make("sc_46"), ConditionalKey.make("sc_19")]


## FG-FIGURE31 : figure du J31 **approuvée** (M14 §3.4) ; la mémoire ne contient
## que les cas du monde joué.
static func _figure31_cases() -> Array[ConditionalKey]:
	return [
		ConditionalKey.make("sc_93a", _flag(&"sc93_dora_passed")),
		ConditionalKey.make("sc_93b", _flag(&"sc93_mira_passed")),
		ConditionalKey.make("sc_93c", _flag(&"sc93_ilan_passed")),
		ConditionalKey.make("sc_96a", _flag(&"sc96_figure_passed")),
		ConditionalKey.make("sc_96b", _flag(&"sc96_figure_passed")),
		ConditionalKey.make("sc_96c", _flag(&"sc96_figure_passed")),
		ConditionalKey.make("sc_96d", _flag(&"sc96_figure_passed")),
		ConditionalKey.make("sc_100a", _flag(&"sc100_figure_passed")),
		ConditionalKey.make("sc_100b", _flag(&"sc100_figure_passed")),
		ConditionalKey.make("sc_103", _flag(&"sc103_mira_passed")),
	]


# CIN-F1 · « MISE EN ATTENTE » — blanc clinique teinté de rouge.
static func _plates_f1() -> Array[PlateDef]:
	var d: StringName = &"state.red"
	var p1: PlateDef = _plate(&"pl_f1_1", "bg_b1", &"s5", &"corridor", &"clinical", d, "cin_f1_1_double")
	p1.captions = [ConditionalKey.make("cin_f1_1_audit", _variant(EpilogueService.VARIANT_AUDIT)),
			ConditionalKey.make("cin_f1_1_review", _variant(EpilogueService.VARIANT_REVIEW)),
			ConditionalKey.make("cin_f1_1_deposition", _variant(EpilogueService.VARIANT_DEPOSITION))]
	# Double jeu des actes I–II (simulation seulement) : la planche des « trente
	# jours » est retirée, la séquence garde ses trois autres planches.
	p1.condition = FlagCondition.any([_variant(EpilogueService.VARIANT_AUDIT), _variant(EpilogueService.VARIANT_REVIEW),
			_variant(EpilogueService.VARIANT_DEPOSITION), _flag(_act_flag(3))])
	_fig(p1, "agent", Rect2(0.44, 0.30, 0.12, 0.62), 0.55, &"leave", 180.0, 1401)
	_fig(p1, "guards", Rect2(0.30, 0.26, 0.40, 0.68), 0.7, &"leave", 180.0, 1402)
	var p2: PlateDef = _plate(&"pl_f1_2", "bg_b2", &"s5", &"cell", &"clinical", d, "cin_f1_2")
	_fig(p2, "seated", Rect2(0.40, 0.42, 0.20, 0.50), 0.5, &"sit", 180.0, 1403)
	var p3: PlateDef = _plate(&"pl_f1_3", "bg_h3", &"s1", &"booth04", &"hall", d, "cin_f1_3")
	p3.max_act = 2
	_fig(p3, "newcomer", Rect2(0.44, 0.34, 0.12, 0.36), 0.3, &"idle", 0.0, 1404)
	_label(p3, "04", Rect2(0.47, 0.18, 0.06, 0.06), &"holo_small", true)
	var p3b: PlateDef = _plate(&"pl_f1_3_borne", "bg_h4", &"s1", &"bornes", &"hall", d, "cin_f1_3_borne", 3)
	_label(p3b, "04", Rect2(0.47, 0.18, 0.06, 0.06), &"holo_small", true)
	var p4: PlateDef = _plate(&"pl_f1_4", "bg_b2", &"s5", &"cell_door", &"night", d, "cin_f1_4")
	p4.captions = [ConditionalKey.make("cin_f1_4_okonkwo", _flag(&"okonkwo_warned"))]
	_mid(p4, "light_lines", Rect2(0.30, 0.86, 0.40, 0.08), 0.2, [&"door_gap_light"])
	_fx(p4, PlateLayerDef.FX_RAIN, 0.15)
	# Séquence ≥ 25 s même à trois planches (double jeu simulé des actes I–II).
	for p: PlateDef in [p2, p3, p3b, p4]:
		p.duration_sec = 7.5
	return [p1, p2, p3, p3b, p4]


# CIN-F2 · « RÉAFFECTATION » — ambre.
static func _plates_f2() -> Array[PlateDef]:
	var d: StringName = &"state.amber"
	var p1: PlateDef = _plate(&"pl_f2_1", "bg_h5", &"s1", &"hall_door", &"hall", d, "cin_f2_1")
	_mid(p1, "hand", Rect2(0.52, 0.44, 0.22, 0.36), 0.8, [&"badge"])
	var p2: PlateDef = _plate(&"pl_f2_2", "bg_p1", &"s4", &"emptied", &"cabin", d, "cin_f2_2")
	_mid(p2, "boxes", Rect2(0.10, 0.52, 0.46, 0.44), 0.6, [&"cartons", &"stove"])
	var p3: PlateDef = _plate(&"pl_f2_3", "bg_q3", &"s2", &"porthole", &"dock", d, "cin_f2_3")
	_mid(p3, "halcyon", Rect2(0.36, 0.26, 0.28, 0.30), 0.1, [&"halcyon_far"])
	var p4: PlateDef = _plate(&"pl_f2_4", "bg_t2", &"s7", &"dust", &"mine_lamp", d, "cin_f2_4")
	_fx(p4, PlateLayerDef.FX_DUST, 0.4)
	return [p1, p2, p3, p4]


# CIN-F3 · « LA CABINE SILENCIEUSE » — gris ; 3 planches, durée allongée
# (séquence ≥ 25 s, M14 §3.3).
static func _plates_f3() -> Array[PlateDef]:
	var d: StringName = &"text.secondary"
	var p1: PlateDef = _plate(&"pl_f3_1", "bg_p2", &"s4", &"night", &"night", d, "cin_f3_1")
	p1.duration_sec = 7.5
	var p2: PlateDef = _plate(&"pl_f3_2", "bg_p3", &"s4", &"porthole_fog", &"night", d, "cin_f3_2")
	p2.condition = FlagCondition.make([], [&"lumika_learned"])
	p2.duration_sec = 7.5
	_fx(p2, PlateLayerDef.FX_FOG, 0.5, 0.3)
	var p2b: PlateDef = _plate(&"pl_f3_2_lumika", "bg_p4", &"s4", &"under_bunk", &"night", d, "cin_f3_2_lumika")
	p2b.condition = _flag(&"lumika_learned")
	p2b.duration_sec = 7.5
	# La luciole au crayon : seul magenta de la planche (décor, D-073).
	_mid(p2b, "firefly", Rect2(0.42, 0.40, 0.16, 0.18), 0.3, [&"firefly_drawing"])
	var p3: PlateDef = _plate(&"pl_f3_3", "bg_h1", &"s1", &"counter", &"hall", d, "cin_f3_3")
	p3.duration_sec = 7.5
	_mid(p3, "hands", Rect2(0.30, 0.56, 0.40, 0.40), 0.8, [&"stamp"])
	_label(p3, "10:00", Rect2(0.78, 0.10, 0.10, 0.06), &"clock", true)
	return [p1, p2, p2b, p3]


# CIN-F4 · « ADJOINT·E DE L'ARBITRE » (J30) — jaune Consortium.
static func _plates_f4() -> Array[PlateDef]:
	var d: StringName = &"accent.yellow"
	var p1: PlateDef = _plate(&"pl_f4_1", "bg_q1", &"s2", &"dock2", &"dock", d, "cin_f4_1", 3)
	p1.captions = [ConditionalKey.make("cin_f4_1_dora", _flag(&"final3_dora"))]
	_fig(p1, "guards", Rect2(0.50, 0.28, 0.34, 0.66), 0.5, &"leave", 90.0, 1421)
	_slot(p1, &"fg_figure", _figure_cases(), &"leave", &"profile", Rect2(0.36, 0.24, 0.20, 0.70), 0.6)
	var p2: PlateDef = _plate(&"pl_f4_2", "bg_x3", &"s8", &"office", &"office", d, "cin_f4_2", 3)
	_mid(p2, "queue_below", Rect2(0.10, 0.62, 0.80, 0.34), 0.1, [], 1422, &"idle")
	var p3: PlateDef = _plate(&"pl_f4_3", "bg_p5", &"s4", &"ring_d", &"dawn", d, "cin_f4_3", 3)
	_mid(p3, "drawings", Rect2(0.24, 0.60, 0.52, 0.32), 0.6, [&"door_drawings"])
	var p4: PlateDef = _plate(&"pl_f4_4", "bg_h6", &"s1", &"wide", &"hall", d, "cin_f4_4", 3)
	p4.holo_effect = &"consortium_eye"
	return [p1, p2, p3, p4]


# CIN-F5C / F5S / F5B · « RENDRE L'AIR » — magenta (Brûlants : rouge).
static func _plates_f5() -> Array[PlateDef]:
	var d: StringName = &"accent.magenta"
	var c1: PlateDef = _plate(&"pl_f5c_1", "bg_r1", &"s6", &"valve", &"recycler", d, "cin_f5c_1", 3)
	_fig(c1, "watchers", Rect2(0.18, 0.34, 0.40, 0.58), 0.5, &"idle", 120.0, 1451)
	_fx(c1, PlateLayerDef.FX_AIR, 0.6)
	var shared2: PlateDef = _plate(&"pl_f5_2", "bg_h7", &"s1", &"glass_open", &"hall", d, "cin_f5_2", 3)
	shared2.captions = [ConditionalKey.make("cin_f5_2_dora", _flag(&"final3_dora"))]
	_mid(shared2, "families", Rect2(0.04, 0.30, 0.48, 0.64), 0.3, [], 1452, &"idle")
	_slot(shared2, &"fg_figure", _figure_cases(), &"leave", &"full", Rect2(0.50, 0.20, 0.22, 0.76), 0.6)
	var c3: PlateDef = _plate(&"pl_f5c_3", "bg_h8", &"s1", &"charter", &"hall", d, "cin_f5c_3", 3)
	_label(c3, "cin_lbl_charter", Rect2(0.38, 0.24, 0.24, 0.08), &"holo_display", false)
	var shared4: PlateDef = _plate(&"pl_f5_4", "bg_p6", &"s4", &"noa_table", &"cabin", d, "cin_f5_4", 3)
	_mid(shared4, "prints", Rect2(0.22, 0.54, 0.56, 0.38), 0.6, [&"stamp", &"firefly_prints"])
	var s1: PlateDef = _plate(&"pl_f5s_1", "bg_q2", &"s2", &"tanks", &"dock", d, "cin_f5s_1", 3)
	_fx(s1, PlateLayerDef.FX_AIR, 0.5)
	var s3: PlateDef = _plate(&"pl_f5s_3", "bg_t1", &"s7", &"dome", &"dawn", d, "cin_f5s_3", 3)
	_fx(s3, PlateLayerDef.FX_AIR, 0.3, 0.4)
	var r: StringName = &"state.red"
	var b1: PlateDef = _plate(&"pl_f5b_1", "bg_q1", &"s2", &"dock2_smoke", &"dock", r, "cin_f5b_1", 3)
	# Fumée lente, **aucun flash** (D-186, hypersensibilité).
	_fx(b1, PlateLayerDef.FX_SMOKE, 0.7, 0.5)
	var b2: PlateDef = _plate(&"pl_f5b_2", "bg_q4", &"s2", &"crossing", &"dock", r, "cin_f5b_2", 3)
	_mid(b2, "families", Rect2(0.10, 0.28, 0.80, 0.66), 0.4, [], 1453, &"leave")
	_fx(b2, PlateLayerDef.FX_SMOKE, 0.6, 0.7)
	var b3: PlateDef = _plate(&"pl_f5b_3", "bg_h9", &"s1", &"seals", &"hall", r, "cin_f5b_3", 3)
	var b4: PlateDef = _plate(&"pl_f5b_4", "bg_p6", &"s4", &"noa_table", &"cabin", r, "cin_f5b_4", 3)
	_mid(b4, "drawings", Rect2(0.22, 0.54, 0.56, 0.38), 0.6, [&"shuttle_drawings"])
	return [c1, shared2, c3, shared4, s1, s3, b1, b2, b3, b4]


# CIN-F6E / F6D / F6T · « À LA DÉRIVE » / « PARTIR » — cyan.
static func _plates_f6() -> Array[PlateDef]:
	var d: StringName = &"accent.cyan"
	var e1: PlateDef = _plate(&"pl_f6e_1", "bg_q5", &"s3", &"dock6", &"dawn", d, "cin_f6e_1")
	_label(e1, "BASSE-MARÉE", Rect2(0.56, 0.40, 0.18, 0.05), &"holo_small", true)
	_fx(e1, PlateLayerDef.FX_FOG, 0.35, 0.5)
	var shared2: PlateDef = _plate(&"pl_f6_2", "bg_q6", &"s3", &"cargo_hold", &"mine_lamp", d, "cin_f6_2")
	_mid(shared2, "ledger", Rect2(0.30, 0.60, 0.30, 0.30), 0.7, [&"register"])
	_slot(shared2, &"fg_wren", _wren_cases(), &"present_docs", &"bust", Rect2(0.52, 0.16, 0.30, 0.80), 0.5)
	var shared3: PlateDef = _plate(&"pl_f6_3", "bg_q7", &"s3", &"porthole", &"night", d, "cin_f6_3")
	_mid(shared3, "halcyon", Rect2(0.42, 0.30, 0.16, 0.18), 0.05, [&"halcyon_far"])
	_fig(shared3, "noa", Rect2(0.30, 0.46, 0.18, 0.50), 0.7, &"idle", 180.0, 1461)
	var e4: PlateDef = _plate(&"pl_f6e_4", "bg_q7", &"s3", &"porthole", &"night", d, "cin_f6e_4")
	# Cadrage serré du même fond : couche agrandie 1,6× (M14 §3.4).
	e4.layers[0].rect = Rect2(-0.3, -0.3, 1.6, 1.6)
	_mid(e4, "hand", Rect2(0.40, 0.30, 0.24, 0.40), 0.6, [&"child_hand"])
	var d1: PlateDef = _plate(&"pl_f6d_1", "bg_q8", &"s3", &"lock9", &"dawn", d, "cin_f6d_1", 3)
	_fx(d1, PlateLayerDef.FX_FOG, 0.3, 0.5)
	var d4: PlateDef = _plate(&"pl_f6d_4", "bg_q7", &"s3", &"porthole", &"night", d, "cin_f6d_4", 3)
	_mid(d4, "cargo_lights", Rect2(0.34, 0.24, 0.32, 0.30), 0.05, [&"cargo_lights"])
	var t1: PlateDef = _plate(&"pl_f6t_1", "bg_q3", &"s2", &"cabin_empty", &"dock", d, "cin_f6t_1", 3)
	_mid(t1, "bags", Rect2(0.56, 0.62, 0.24, 0.30), 0.7, [&"two_bags"])
	var t3: PlateDef = _plate(&"pl_f6t_3", "bg_t3", &"s7", &"castellanos", &"mine_lamp", d, "cin_f6t_3", 3)
	_mid(t3, "committee", Rect2(0.20, 0.30, 0.60, 0.64), 0.4, [], 1462, &"idle")
	_fx(t3, PlateLayerDef.FX_DUST, 0.3)
	var t4: PlateDef = _plate(&"pl_f6t_4", "bg_t4", &"s7", &"refectory", &"mine_lamp", d, "cin_f6t_4", 3)
	return [e1, shared2, shared3, e4, d1, d4, t1, t3, t4]


# CIN-F7 · « LE GUICHET ROUVRE JEUDI » — blanc.
static func _plates_f7() -> Array[PlateDef]:
	var d: StringName = &"text.primary"
	var p1: PlateDef = _plate(&"pl_f7_1", "bg_h6", &"s1", &"wide", &"hall", d, "cin_f7_1", 3)
	p1.holo_effect = &"chime_rings"
	_label(p1, "10:00", Rect2(0.80, 0.08, 0.10, 0.06), &"clock", true)
	var p2: PlateDef = _plate(&"pl_f7_2", "bg_q1", &"s2", &"dock2_empty", &"dock", d, "cin_f7_2", 3)
	var p3: PlateDef = _plate(&"pl_f7_3", "bg_h10", &"s1", &"forms", &"hall", d, "cin_f7_3", 3)
	_label(p3, "27-B", Rect2(0.42, 0.30, 0.16, 0.10), &"holo_display", true)
	var p4: PlateDef = _plate(&"pl_f7_4", "bg_h2", &"s1", &"queue", &"hall", d, "cin_f7_4", 3)
	_mid(p4, "queue", Rect2(0.06, 0.30, 0.88, 0.64), 0.4, [], 1471, &"idle")
	return [p1, p2, p3, p4]


# CIN-F8 · « LES TÉMOINS » — cyan.
static func _plates_f8() -> Array[PlateDef]:
	var d: StringName = &"accent.cyan"
	var p1: PlateDef = _plate(&"pl_f8_1", "bg_h11", &"s1", &"speaker", &"hall", d, "cin_f8_1", 3)
	p1.holo_effect = &"waveform"
	_label(p1, "12:20", Rect2(0.80, 0.08, 0.10, 0.06), &"clock", true)
	var p2: PlateDef = _plate(&"pl_f8_2", "bg_h1", &"s1", &"glass_reflection", &"hall", d, "cin_f8_2", 3)
	p2.holo_effect = &"waveform"
	# Reflet flou de l'agent·e dans la vitre : jamais un visage (LORE §11).
	_fig(p2, "reflection", Rect2(0.40, 0.18, 0.20, 0.56), 0.2, &"idle", 0.0, 1481)
	var p3: PlateDef = _plate(&"pl_f8_3", "bg_p7", &"s4", &"radio", &"cabin", d, "cin_f8_3", 3)
	_mid(p3, "hand", Rect2(0.48, 0.46, 0.20, 0.30), 0.7, [&"radio"])
	var p4: PlateDef = _plate(&"pl_f8_4", "bg_x2", &"s8", &"archives", &"archive", d, "cin_f8_4", 3)
	return [p1, p2, p3, p4]


# CIN-F9 · « LES VITRES ÉTEINTES » — acier (témoin du lot C, BOOTH §19).
static func _plates_f9() -> Array[PlateDef]:
	var d: StringName = &"world.steel"
	var p1: PlateDef = _plate(&"pl_f9_1", "bg_h12", &"s1", &"arc", &"hall", d, "cin_f9_1", 3)
	p1.holo_effect = PlateDef.HOLO_GLASS_OFF_SEQUENCE
	# 12 vitres + temps de lecture (1 toutes les 0,5 s).
	p1.duration_sec = 8.0
	_mid(p1, "foreground", Rect2(0.0, 0.62, 1.0, 0.38), 0.6, [&"barriers"], 1491, &"idle")
	# Couches d'état « allumé », dans l'ordre d'extinction : 04, 05, puis toutes.
	var order: Array[int] = [4, 5, 6, 7, 8, 9, 10, 11, 12, 1, 2, 3]
	for n: int in order:
		var layer: PlateLayerDef = PlateLayerDef.new()
		layer.kind = PlateLayerDef.KIND_LIT
		layer.texture_path = "%s/lit/%s_lit_%02d.webp" % [ASSET_ROOT, p1.id, n]
		layer.state_index = n - 1
		layer.rect = _rendered_rect(layer.texture_path, Rect2(0.0, 0.0, 1.0, 1.0))
		layer.depth = 0.0
		p1.layers.append(layer)
	for n: int in range(1, 13):
		# Plaques de numéro sur l'arc (ancres du manifeste du lot C).
		_label(p1, "%02d" % n, Rect2(0.04 + 0.08 * (n - 1), 0.30, 0.04, 0.04), &"holo_small", true)
	var p2: PlateDef = _plate(&"pl_f9_2", "bg_h13", &"s1", &"lights_out", &"hall_dark", d, "cin_f9_2", 3)
	_mid(p2, "families", Rect2(0.08, 0.30, 0.84, 0.64), 0.4, [], 1492, &"leave")
	var p3: PlateDef = _plate(&"pl_f9_3", "bg_h14", &"s1", &"stamps_flat", &"hall_dark", d, "cin_f9_3", 3)
	var p4: PlateDef = _plate(&"pl_f9_4", "bg_c1", &"s8", &"ring_c_walkway", &"night", d, "cin_f9_4", 3)
	_mid(p4, "crowd", Rect2(0.0, 0.34, 1.0, 0.62), 0.5, [], 1493, &"leave")
	_fx(p4, PlateLayerDef.FX_RAIN, 0.5)
	return [p1, p2, p3, p4]


# CIN-F10 · « LE PONT » — vert (témoin PL-F10-3 du lot C).
static func _plates_f10() -> Array[PlateDef]:
	var d: StringName = &"state.green"
	var p1: PlateDef = _plate(&"pl_f10_1", "bg_q1", &"s2", &"dock2_docked", &"dock", d, "cin_f10_1", 3)
	_mid(p1, "transit7", Rect2(0.20, 0.20, 0.70, 0.50), 0.2, [&"transit7_hull"])
	_label(p1, "14:00", Rect2(0.80, 0.08, 0.10, 0.06), &"clock", true)
	var p2: PlateDef = _plate(&"pl_f10_2", "bg_h15", &"s1", &"ledger", &"hall", d, "cin_f10_2", 3)
	_label(p2, "cin_lbl_ledger", Rect2(0.36, 0.20, 0.28, 0.07), &"holo_display", false)
	for i: int in 3:
		_label(p2, "%03d" % (117 + 2 * i), Rect2(0.40, 0.32 + 0.07 * i, 0.20, 0.05), &"holo_small", true)
	var p3: PlateDef = _plate(&"pl_f10_3", "bg_x1", &"s8", &"school", &"school", d, "cin_f10_3", 3)
	_mid(p3, "benches", Rect2(0.04, 0.44, 0.92, 0.54), 0.5, [&"added_benches"], 1501, &"sit")
	var p4: PlateDef = _plate(&"pl_f10_4", "bg_h16", &"s1", &"evening", &"dusk", d, "cin_f10_4", 3)
	_mid(p4, "hand", Rect2(0.36, 0.50, 0.30, 0.40), 0.7, [&"folded_sheet"])
	return [p1, p2, p3, p4]


# CIN-EA → CIN-ED · conclusion du J31 (« UN AN PLUS TARD »).
static func _plates_epilogue() -> Array[PlateDef]:
	var plates: Array[PlateDef] = []
	var y: StringName = &"accent.yellow"
	var ea1: PlateDef = _plate(&"pl_ea_1", "bg_h17", &"s1", &"bornes_evening", &"hall", y, "cin_ea_1", 3)
	_label(ea1, "18:00", Rect2(0.80, 0.08, 0.10, 0.06), &"clock", true)
	var ea2: PlateDef = _plate(&"pl_ea_2", "bg_h3", &"s1", &"booth04", &"hall", y, "cin_ea_2", 3)
	_mid(ea2, "short_queue", Rect2(0.10, 0.40, 0.40, 0.54), 0.4, [], 1511, &"idle")
	_label(ea2, "04", Rect2(0.47, 0.18, 0.06, 0.06), &"holo_small", true)
	var ea3: PlateDef = _plate(&"pl_ea_3", "bg_h1", &"s1", &"counter", &"dusk", y, "cin_ea_3", 3)
	_mid(ea3, "hands", Rect2(0.30, 0.56, 0.40, 0.40), 0.8, [&"stamp"])
	plates.append_array([ea1, ea2, ea3])
	var w: StringName = &"world.key"
	var eb1: PlateDef = _plate(&"pl_eb_1", "bg_h8", &"s1", &"charter", &"hall_warm", w, "cin_eb_1", 3)
	_label(eb1, "cin_lbl_charter", Rect2(0.38, 0.24, 0.24, 0.08), &"holo_display", false)
	_mid(eb1, "pencil", Rect2(0.40, 0.36, 0.20, 0.12), 0.2, [&"pencil_correction"])
	var eb2: PlateDef = _plate(&"pl_eb_2", "bg_r2", &"s6", &"council", &"recycler", w, "cin_eb_2", 3)
	_mid(eb2, "council", Rect2(0.14, 0.34, 0.72, 0.60), 0.4, [], 1521, &"sit")
	_fx(eb2, PlateLayerDef.FX_AIR, 0.3)
	var eb3: PlateDef = _plate(&"pl_eb_3", "bg_h18", &"s1", &"arc_lit", &"hall_warm", w, "cin_eb_3", 3)
	plates.append_array([eb1, eb2, eb3])
	var c: StringName = &"accent.cyan"
	var ec1: PlateDef = _plate(&"pl_ec_1", "bg_h11", &"s1", &"speaker", &"hall", c, "cin_ec_1", 3)
	ec1.holo_effect = &"waveform"
	_label(ec1, "12:20", Rect2(0.80, 0.08, 0.10, 0.06), &"clock", true)
	var ec2: PlateDef = _plate(&"pl_ec_2", "bg_x1", &"s8", &"school_register", &"school", c, "cin_ec_2", 3)
	_mid(ec2, "register", Rect2(0.34, 0.56, 0.32, 0.30), 0.6, [&"open_register"])
	_label(ec2, "2187", Rect2(0.44, 0.50, 0.12, 0.05), &"holo_small", true)
	var ec3: PlateDef = _plate(&"pl_ec_3", "bg_x2", &"s8", &"archives", &"archive", c, "cin_ec_3", 3)
	plates.append_array([ec1, ec2, ec3])
	var a: StringName = &"state.amber"
	var ed1: PlateDef = _plate(&"pl_ed_1", "bg_t3", &"s7", &"castellanos", &"mine_lamp", a, "cin_ed_1", 3)
	_fx(ed1, PlateLayerDef.FX_DUST, 0.25)
	var ed2: PlateDef = _plate(&"pl_ed_2", "bg_t4", &"s7", &"refectory", &"mine_lamp", a, "cin_ed_2", 3)
	_mid(ed2, "kept_seat", Rect2(0.40, 0.52, 0.22, 0.32), 0.5, [&"empty_seat", &"bowl"])
	var ed3: PlateDef = _plate(&"pl_ed_3", "bg_t5", &"s7", &"outside", &"mine_lamp", a, "cin_ed_3", 3)
	_fx(ed3, PlateLayerDef.FX_DUST, 0.6)
	plates.append_array([ed1, ed2, ed3])
	# PL-E-FIG : la figure du J31 approuvée, à la vitre (A, B, C : Hall ;
	# D : sas Castellanos). Omise sans visage mémorisé (D-185).
	var fig: PlateDef = _plate(&"pl_e_fig", "bg_h3", &"s1", &"booth04", &"hall", &"world.key", "cin_e_fig", 3)
	_slot(fig, &"fg_figure31", _figure31_cases(), &"present_docs", &"bust", Rect2(0.38, 0.18, 0.24, 0.62), 0.5, true)
	var fig_d: PlateDef = _plate(&"pl_e_fig_d", "bg_t3", &"s7", &"castellanos", &"mine_lamp", a, "cin_e_fig", 3)
	_slot(fig_d, &"fg_figure31", _figure31_cases(), &"present_docs", &"bust", Rect2(0.38, 0.18, 0.24, 0.62), 0.5, true)
	plates.append_array([fig, fig_d])
	for p: PlateDef in plates:
		# Épilogue 18–30 s sans carte de titre (M14 §3.3).
		p.duration_sec = 7.0
	return plates
