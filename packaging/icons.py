#!/usr/bin/env python3
"""Arborescence d'icônes freedesktop (hicolor) depuis les icônes versionnées.

Usage : python3 -I packaging/icons.py <dossier assets/icons> <icon.svg> <sortie> [nom]

Écrit <sortie>/hicolor/<N>x<N>/apps/<nom>.png (16 → 512) et
<sortie>/hicolor/scalable/apps/<nom>.svg (nom par défaut : « clearance »).

Aucune dépendance hors bibliothèque standard, aucune rastérisation : les PNG
sont extraits tels quels de icon.ico (entrées PNG 16…256 px) et de icon.icns
(ic09 = 512 px), eux-mêmes produits par tools/build_icons.gd depuis icon.svg
(ARCHITECTURE §16.6) : les icônes Linux restent identiques à celles de
Windows et de macOS sans nouveau fichier binaire versionné.
"""
from __future__ import annotations

import os
import shutil
import struct
import sys

PNG_MAGIC = b"\x89PNG\r\n\x1a\n"


def png_size(data: bytes) -> tuple[int, int]:
	if not data.startswith(PNG_MAGIC) or data[12:16] != b"IHDR":
		raise ValueError("entrée non PNG")
	return struct.unpack(">II", data[16:24])


def ico_pngs(path: str) -> dict[int, bytes]:
	with open(path, "rb") as f:
		blob = f.read()
	reserved, kind, count = struct.unpack("<HHH", blob[:6])
	if reserved != 0 or kind != 1:
		raise ValueError(f"{path} : en-tête ICO invalide")
	out: dict[int, bytes] = {}
	for i in range(count):
		size, offset = struct.unpack("<II", blob[6 + 16 * i + 8 : 6 + 16 * i + 16])
		data = blob[offset : offset + size]
		w, h = png_size(data)
		if w == h:
			out[w] = data
	return out


def icns_pngs(path: str) -> dict[int, bytes]:
	with open(path, "rb") as f:
		blob = f.read()
	if blob[:4] != b"icns":
		raise ValueError(f"{path} : en-tête ICNS invalide")
	out: dict[int, bytes] = {}
	pos = 8
	while pos + 8 <= len(blob):
		kind, length = struct.unpack(">4sI", blob[pos : pos + 8])
		data = blob[pos + 8 : pos + length]
		# Seules les entrées @1x nous intéressent (ic07 128, ic08 256, ic09 512).
		if kind in (b"ic07", b"ic08", b"ic09") and data.startswith(PNG_MAGIC):
			w, h = png_size(data)
			if w == h:
				out[w] = data
		if length < 8:
			raise ValueError(f"{path} : entrée ICNS invalide")
		pos += length
	return out


def main(argv: list[str]) -> int:
	if len(argv) not in (4, 5):
		print(__doc__.strip().splitlines()[2], file=sys.stderr)
		return 2
	icons_dir, svg, dest = argv[1], argv[2], argv[3]
	name = argv[4] if len(argv) == 5 else "clearance"
	pngs = icns_pngs(os.path.join(icons_dir, "icon.icns"))
	pngs.update(ico_pngs(os.path.join(icons_dir, "icon.ico")))
	wanted = [16, 24, 32, 48, 64, 128, 256, 512]
	missing = [s for s in wanted if s not in pngs]
	if missing:
		print(f"icons.py : tailles absentes des icônes : {missing}", file=sys.stderr)
		return 1
	for s in wanted:
		d = os.path.join(dest, "hicolor", f"{s}x{s}", "apps")
		os.makedirs(d, exist_ok=True)
		with open(os.path.join(d, f"{name}.png"), "wb") as f:
			f.write(pngs[s])
	d = os.path.join(dest, "hicolor", "scalable", "apps")
	os.makedirs(d, exist_ok=True)
	shutil.copyfile(svg, os.path.join(d, f"{name}.svg"))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
