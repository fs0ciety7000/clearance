## Audit objectif des planches de cinématique (M14 §6.2 : M-09, M-11, M-12,
## M-16 ; lot C, BOOTH_SCENE §21). Sous xvfb (`opengl3`), sans écoute ni œil :
## - **M-16** légendes : clés présentes dans `fr.csv`, ≤ 70 caractères ; chaque
##   planche composée en 1280×800 (Steam Deck) et 1920×1080 (`plate_compose.gd`) :
##   contraste du texte sur le voile ≥ 7:1 (95ᵉ centile du fond), bandeau dans
##   la zone sûre 16:10, corps ≥ 16 px physiques ;
## - **M-09** déterminisme : SHA-256 des PNG = manifeste (`build_plates --verify`
##   rejoue le rendu) ;
## - **M-11** VRAM : planche courante + suivante (pire paire consécutive d'une
##   séquence, RGBA8/RGB8 non compressés + figures 512×768) ≤ 32 Mo ;
## - **M-12** disque : somme des `.ctex` importés (WebP 0,75) ≤ 12 Mo (plafond
##   relevé à 18 Mo par D-195) ;
## - cohérence données ↔ rendu : textures présentes, rectangles des couches
##   d'état et ancres des `Label` comparés au manifeste (écarts signalés).
## Usage :
##   xvfb-run -a -s "-screen 0 1920x1200x24" godot --path . --rendering-driver opengl3 \
##       --script res://tools/qa_plates_audit.gd -- [--only=pl_f9_1,…] [--captures=/dossier] [--report=/x.json]
## Code de sortie 1 si une cible dure échoue (contraste, longueur, zone sûre,
## texture absente, SHA, VRAM, disque > 18 Mo).
extends SceneTree

const COMPOSE = preload("res://tools/plate_compose.gd")
const MANIFEST: String = "res://assets/cinematics/manifest.json"
const PLATES_DIR: String = "res://data/cinematics/plates"
const CONTRAST_MIN: float = 7.0
const VRAM_MAX: int = 32 * 1048576
const DISK_TARGET: int = 12 * 1048576
const DISK_MAX: int = 18 * 1048576
const SIZES: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(1920, 1080)]

var _failures: PackedStringArray = []
var _warnings: PackedStringArray = []


func _initialize() -> void:
	await process_frame
	UiText.ensure_translations()
	TranslationServer.set_locale("fr")
	var only: PackedStringArray = []
	var captures: String = ""
	var report_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",", false)
		elif arg.begins_with("--captures="):
			captures = arg.trim_prefix("--captures=")
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	if DisplayServer.get_name() == "headless":
		printerr("qa_plates_audit: rendu requis (xvfb, opengl3)")
		quit(1)
		return
	if not FileAccess.file_exists(MANIFEST):
		printerr("qa_plates_audit: manifeste absent — lancer tools/build_plates.gd")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	# `CinematicLibraryDef` d'abord : charger les `PlateDef` avant la bibliothèque
	# laisse une fuite à la sortie de Godot 4.7.2 (constat des lots E/F).
	CinematicLibraryDef.load_default()
	var plates: Dictionary[String, PlateDef] = {}
	var files: PackedStringArray = DirAccess.get_files_at(PLATES_DIR)
	files.sort()
	for f: String in files:
		if f.ends_with(".tres"):
			var p: PlateDef = load(PLATES_DIR.path_join(f)) as PlateDef
			if p != null:
				plates[String(p.id)] = p
	var report: Dictionary = {"plates": {}, "sequences": {}}
	report["sha"] = _check_sha(manifest)
	report["disk"] = _check_disk(manifest)
	report["data"] = _check_data(plates, manifest)
	report["vram"] = _check_vram(plates, manifest)
	var composer: COMPOSE = COMPOSE.new()
	if not captures.is_empty():
		DirAccess.make_dir_recursive_absolute(captures)
	for id: String in plates:
		if not only.is_empty() and not only.has(id):
			continue
		var plate: PlateDef = plates[id]
		var entry: Dictionary = _check_captions(plate)
		for size: Vector2i in SIZES:
			var img: Image = await composer.compose(root, plate, size, manifest)
			var contrast: float = COMPOSE.contrast_under(img, composer.caption_rect, DS.TEXT_PRIMARY)
			var safe: Rect2i = _safe_zone(size)
			var inside: bool = safe.encloses(composer.caption_rect)
			var tag: String = "%dx%d" % [size.x, size.y]
			entry[tag] = {"contrast": snappedf(contrast, 0.01), "caption_rect": [composer.caption_rect.position.x, composer.caption_rect.position.y,
					composer.caption_rect.size.x, composer.caption_rect.size.y], "inside_safe": inside, "font_px": composer.caption_font_px}
			if contrast < CONTRAST_MIN:
				_failures.append("%s %s : contraste de la légende %.2f:1 < 7:1" % [id, tag, contrast])
			if not inside:
				_failures.append("%s %s : légende hors zone sûre 16:10" % [id, tag])
			if composer.caption_font_px < 16:
				_failures.append("%s %s : légende à %d px < 16" % [id, tag, composer.caption_font_px])
			if not captures.is_empty():
				img.save_png(captures.path_join("%s_%s.png" % [id, tag]))
		(report["plates"] as Dictionary)[id] = entry
		print("qa_plates_audit: %s — contraste %.1f:1 (Deck) / %.1f:1 (1080p)" % [id, entry["1280x800"]["contrast"], entry["1920x1080"]["contrast"]])
	report["failures"] = _failures
	report["warnings"] = _warnings
	if not report_path.is_empty():
		var f: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "\t", true))
		f.close()
	for w: String in _warnings:
		print("qa_plates_audit: AVERTISSEMENT — " + w)
	for e: String in _failures:
		printerr("qa_plates_audit: ÉCHEC — " + e)
	print("qa_plates_audit: %d planche(s), disque %.2f Mo (cible 12, plafond 18), VRAM pire paire %.1f Mo (≤ 32), %d échec(s), %d avertissement(s)" % [
			(report["plates"] as Dictionary).size(), float((report["disk"] as Dictionary)["ctex_bytes"]) / 1048576.0,
			float((report["vram"] as Dictionary)["worst_pair_bytes"]) / 1048576.0, _failures.size(), _warnings.size()])
	quit(0 if _failures.is_empty() else 1)


static func _safe_zone(size: Vector2i) -> Rect2i:
	var w: int = mini(size.x, int(size.y * 1.6))
	return Rect2i(Vector2i((size.x - w) / 2, 0), Vector2i(w, size.y))


func _check_captions(plate: PlateDef) -> Dictionary:
	var out: Dictionary = {"captions": {}}
	for key: String in plate.all_caption_keys():
		var text: String = TranslationServer.translate(key)
		var n: int = text.length()
		(out["captions"] as Dictionary)[key] = n
		if text == key:
			_failures.append("%s : clé de légende %s absente de fr.csv" % [plate.id, key])
		elif n > PlateDef.CAPTION_MAX_CHARS:
			_failures.append("%s : légende %s de %d caractères > 70" % [plate.id, key, n])
	return out


## M-09 : chaque fichier du manifeste existe et a le SHA-256 enregistré.
func _check_sha(manifest: Dictionary) -> Dictionary:
	var ok: int = 0
	for path: String in manifest.get("files", {}):
		if not FileAccess.file_exists(path):
			_failures.append("fichier du manifeste absent : %s" % path)
		elif FileAccess.get_sha256(path) != (manifest["files"][path] as Dictionary)["sha256"]:
			_failures.append("SHA-256 différent du manifeste : %s" % path)
		else:
			ok += 1
	return {"files_ok": ok}


## M-12 : taille des textures importées (`.ctex` listés par chaque `.import`).
func _check_disk(manifest: Dictionary) -> Dictionary:
	var total: int = 0
	var missing: int = 0
	for path: String in manifest.get("files", {}):
		var dest: String = _import_dest(path)
		if dest.is_empty() or not FileAccess.file_exists(dest):
			missing += 1
			continue
		total += FileAccess.get_file_as_bytes(dest).size()
	if missing > 0:
		_warnings.append("%d texture(s) non importée(s) (lancer godot --headless --import)" % missing)
	if total > DISK_MAX:
		_failures.append("disque des planches %.2f Mo > 18 Mo (M-12, D-195)" % (total / 1048576.0))
	elif total > DISK_TARGET:
		_warnings.append("disque des planches %.2f Mo > cible 12 Mo (plafond 18 Mo, D-195)" % (total / 1048576.0))
	return {"ctex_bytes": total, "not_imported": missing, "source_bytes": int((manifest.get("summary", {}) as Dictionary).get("source_bytes", 0))}


static func _import_dest(path: String) -> String:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(path + ".import") != OK:
		return ""
	var dests: Variant = cfg.get_value("deps", "dest_files", [])
	if dests is Array and not (dests as Array).is_empty():
		return String((dests as Array)[0])
	return String(cfg.get_value("remap", "path", ""))


## Textures des données présentes ; rectangles et ancres comparés au manifeste.
func _check_data(plates: Dictionary[String, PlateDef], manifest: Dictionary) -> Dictionary:
	var files: Dictionary = manifest.get("files", {})
	var groups: Dictionary = manifest.get("groups", {})
	var mismatched_rects: Array = []
	var label_hints: Array = []
	for id: String in plates:
		var plate: PlateDef = plates[id]
		var group: Dictionary = {}
		for layer: PlateLayerDef in plate.layers:
			if layer == null or layer.kind == PlateLayerDef.KIND_FX:
				continue
			if layer.texture_path.is_empty() or not FileAccess.file_exists(layer.texture_path):
				_failures.append("%s : texture absente %s" % [id, layer.texture_path])
				continue
			if layer.kind == PlateLayerDef.KIND_BG:
				group = groups.get(layer.texture_path.get_file().get_basename(), {})
			var e: Dictionary = files.get(layer.texture_path, {})
			if not e.is_empty() and layer.kind != PlateLayerDef.KIND_BG:
				var rn: Array = e["rect_norm"]
				var d: Rect2 = layer.rect
				if absf(d.position.x - float(rn[0])) > 0.01 or absf(d.position.y - float(rn[1])) > 0.01 \
						or absf(d.size.x - float(rn[2])) > 0.01 or absf(d.size.y - float(rn[3])) > 0.01:
					mismatched_rects.append({"plate": id, "path": layer.texture_path, "data": [d.position.x, d.position.y, d.size.x, d.size.y], "render": rn})
				if float(e.get("clipped", 0.0)) > 0.02:
					_warnings.append("%s : %.0f %% de la couche %s hors de son rectangle (donnée)" % [id, float(e["clipped"]) * 100.0, layer.texture_path.get_file()])
		for slot: FigureSlotDef in plate.figures:
			if slot != null and not slot.silhouette_path.is_empty() and not FileAccess.file_exists(slot.silhouette_path):
				_failures.append("%s : silhouette de repli absente %s" % [id, slot.silhouette_path])
		# Ancres des `Label` littéraux : rectangle du décor au texte identique.
		for lab: PlateLabelDef in plate.labels:
			if lab == null:
				continue
			for anchor: Dictionary in group.get("labels", []):
				if String(anchor.get("text", "")) == lab.text_key:
					var rn: Array = anchor["rect_norm"]
					if absf(lab.rect.position.x - float(rn[0])) > 0.02 or absf(lab.rect.position.y - float(rn[1])) > 0.02:
						label_hints.append({"plate": id, "text": lab.text_key, "data": [lab.rect.position.x, lab.rect.position.y, lab.rect.size.x, lab.rect.size.y], "anchor": rn})
	if not mismatched_rects.is_empty():
		_warnings.append("%d rectangle(s) de couche ≠ rendu (voir rapport : `data.rects`)" % mismatched_rects.size())
	if not label_hints.is_empty():
		_warnings.append("%d Label(s) loin de leur ancre dans le décor (voir rapport : `data.labels`)" % label_hints.size())
	return {"rects": mismatched_rects, "labels": label_hints}


## M-11 : VRAM d'une planche (couches non compressées + figures) ; pire paire
## de planches consécutives d'une séquence.
func _check_vram(plates: Dictionary[String, PlateDef], manifest: Dictionary) -> Dictionary:
	var files: Dictionary = manifest.get("files", {})
	var per_plate: Dictionary = {}
	for id: String in plates:
		var v: int = 0
		for layer: PlateLayerDef in plates[id].layers:
			if layer != null and files.has(layer.texture_path):
				v += int((files[layer.texture_path] as Dictionary)["vram_bytes"])
		for slot: FigureSlotDef in plates[id].figures:
			if slot != null:
				v += slot.render_size.x * slot.render_size.y * 4
		per_plate[id] = v
	var worst: int = 0
	var worst_pair: String = ""
	var lib: CinematicLibraryDef = CinematicLibraryDef.load_default()
	if lib != null:
		for c: CinematicDef in lib.cinematics:
			for i: int in c.plates.size() - 1:
				var a: PlateDef = c.plates[i]
				var b: PlateDef = c.plates[i + 1]
				if a == null or b == null:
					continue
				var pair: int = int(per_plate.get(String(a.id), 0)) + int(per_plate.get(String(b.id), 0))
				if pair > worst:
					worst = pair
					worst_pair = "%s + %s (%s)" % [a.id, b.id, c.id]
	if worst > VRAM_MAX:
		_failures.append("VRAM %.1f Mo > 32 Mo : %s" % [worst / 1048576.0, worst_pair])
	return {"per_plate": per_plate, "worst_pair_bytes": worst, "worst_pair": worst_pair}
