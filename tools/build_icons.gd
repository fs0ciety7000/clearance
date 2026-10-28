## Icônes d'application (ARCHITECTURE §16.6) : `icon.svg` → `assets/icons/`.
##
## - `icon.ico` (Windows) : 16, 24, 32, 48, 64, 128, 256 px, entrées PNG
##   (format ICO « Vista+ », lu par l'exportateur Windows de Godot qui réécrit
##   lui-même les ressources PE, sans rcedit).
## - `icon.icns` (macOS) : entrées PNG `icp4`…`ic10` (16 → 1024 px, @1x/@2x).
## - `icon_1024.png` : rendu de référence (vignettes, magasins).
##
## Rendu par le rastériseur SVG de Godot (ThorVG) : aucun outil externe, sortie
## identique pour une même version de Godot. Les fichiers ne sont pas des
## ressources Godot (aucun `.import`) : ils ne partent pas dans le `.pck`, les
## presets les référencent seulement (`application/icon`).
##
## Usage (depuis la racine du projet) :
##   godot --headless --script res://tools/build_icons.gd
extends SceneTree

const SOURCE: String = "res://icon.svg"
const OUT_DIR: String = "res://assets/icons"
const ICO_SIZES: Array[int] = [16, 24, 32, 48, 64, 128, 256]
## Type ICNS → taille en pixels (entrées PNG, macOS 10.7+).
const ICNS_ENTRIES: Array[Array] = [
	["icp4", 16], ["ic11", 32], ["icp5", 32], ["ic12", 64], ["icp6", 64],
	["ic07", 128], ["ic13", 256], ["ic08", 256], ["ic14", 512], ["ic09", 512], ["ic10", 1024],
]


func _init() -> void:
	var svg: String = FileAccess.get_file_as_string(SOURCE)
	if svg.is_empty():
		push_error("build_icons: %s introuvable" % SOURCE)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var cache: Dictionary = {}
	var ok: bool = _write(OUT_DIR.path_join("icon.ico"), _build_ico(svg, cache))
	ok = _write(OUT_DIR.path_join("icon.icns"), _build_icns(svg, cache)) and ok
	ok = _write(OUT_DIR.path_join("icon_1024.png"), _png(svg, 1024, cache)) and ok
	print("build_icons : %s" % ("OK" if ok else "ÉCHEC"))
	quit(0 if ok else 1)


## PNG carré `size` px, rendu directement à la bonne échelle (net aux petites tailles).
func _png(svg: String, size: int, cache: Dictionary) -> PackedByteArray:
	if cache.has(size):
		return cache[size]
	var image: Image = Image.new()
	var err: Error = image.load_svg_from_string(svg, float(size) / 128.0)
	if err != OK:
		push_error("build_icons: rendu SVG %d px impossible (%s)" % [size, error_string(err)])
		return PackedByteArray()
	if image.get_width() != size:
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	var data: PackedByteArray = image.save_png_to_buffer()
	cache[size] = data
	return data


func _build_ico(svg: String, cache: Dictionary) -> PackedByteArray:
	var header: StreamPeerBuffer = StreamPeerBuffer.new()
	header.big_endian = false
	header.put_u16(0)
	header.put_u16(1)
	header.put_u16(ICO_SIZES.size())
	var images: Array[PackedByteArray] = []
	var offset: int = 6 + 16 * ICO_SIZES.size()
	for size: int in ICO_SIZES:
		var png: PackedByteArray = _png(svg, size, cache)
		images.append(png)
		header.put_u8(size % 256)  # 256 s'écrit 0
		header.put_u8(size % 256)
		header.put_u8(0)  # palette
		header.put_u8(0)  # réservé
		header.put_u16(1)  # plans
		header.put_u16(32)  # bits par pixel
		header.put_u32(png.size())
		header.put_u32(offset)
		offset += png.size()
	var out: PackedByteArray = header.data_array
	for png: PackedByteArray in images:
		out.append_array(png)
	return out


func _build_icns(svg: String, cache: Dictionary) -> PackedByteArray:
	var body: PackedByteArray = PackedByteArray()
	for entry: Array in ICNS_ENTRIES:
		var tag: String = entry[0]
		var size: int = entry[1]
		var png: PackedByteArray = _png(svg, size, cache)
		body.append_array(tag.to_ascii_buffer())
		body.append_array(_u32_be(png.size() + 8))
		body.append_array(png)
	var out: PackedByteArray = "icns".to_ascii_buffer()
	out.append_array(_u32_be(body.size() + 8))
	out.append_array(body)
	return out


func _u32_be(value: int) -> PackedByteArray:
	var stream: StreamPeerBuffer = StreamPeerBuffer.new()
	stream.big_endian = true
	stream.put_u32(value)
	return stream.data_array


func _write(path: String, data: PackedByteArray) -> bool:
	if data.is_empty():
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("build_icons: écriture de %s impossible" % path)
		return false
	file.store_buffer(data)
	file.close()
	print("  %s (%d octets)" % [path, data.size()])
	return true
