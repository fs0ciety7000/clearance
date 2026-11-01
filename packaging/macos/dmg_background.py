#!/usr/bin/env python3
"""Fond de la fenêtre du DMG CLEARANCE (ARCHITECTURE §16.9).

Usage : python3 -I packaging/macos/dmg_background.py <sortie.png> [échelle]
  échelle 1 → 640×420 (points de la fenêtre), 2 → 1280×840 (Retina).

Bibliothèque standard seulement (zlib) : aucun outil d'image requis sur le
runner. Couleurs reprises de l'icône (icon.svg) : fond #07080C, cyan #00E5FF.
Texte en police bitmap 5×7 (majuscules) : « glisser dans Applications » et
« 1er lancement : clic droit > Ouvrir » (application non notarisée, D-070).
La disposition (positions des icônes) est celle de tools/package_macos_dmg.sh.
"""
from __future__ import annotations

import struct
import sys
import zlib

W, H = 640, 420
BG = (0x07, 0x08, 0x0C)
GRID = (0x0D, 0x10, 0x17)
CYAN = (0x00, 0xE5, 0xFF)
DIM = (0x6B, 0x7A, 0x8C)

# Police 5×7 : 7 lignes de 5 bits par glyphe.
FONT = {
	"A": "01110 10001 10001 11111 10001 10001 10001",
	"B": "11110 10001 10001 11110 10001 10001 11110",
	"C": "01110 10001 10000 10000 10000 10001 01110",
	"D": "11110 10001 10001 10001 10001 10001 11110",
	"E": "11111 10000 10000 11110 10000 10000 11111",
	"F": "11111 10000 10000 11110 10000 10000 10000",
	"G": "01110 10001 10000 10111 10001 10001 01111",
	"H": "10001 10001 10001 11111 10001 10001 10001",
	"I": "01110 00100 00100 00100 00100 00100 01110",
	"K": "10001 10010 10100 11000 10100 10010 10001",
	"L": "10000 10000 10000 10000 10000 10000 11111",
	"M": "10001 11011 10101 10101 10001 10001 10001",
	"N": "10001 11001 10101 10011 10001 10001 10001",
	"O": "01110 10001 10001 10001 10001 10001 01110",
	"P": "11110 10001 10001 11110 10000 10000 10000",
	"R": "11110 10001 10001 11110 10100 10010 10001",
	"S": "01111 10000 10000 01110 00001 00001 11110",
	"T": "11111 00100 00100 00100 00100 00100 00100",
	"U": "10001 10001 10001 10001 10001 10001 01110",
	"V": "10001 10001 10001 10001 10001 01010 00100",
	"W": "10001 10001 10001 10101 10101 10101 01010",
	"Z": "11111 00001 00010 00100 01000 10000 11111",
	"1": "00100 01100 00100 00100 00100 00100 01110",
	":": "00000 00100 00100 00000 00100 00100 00000",
	">": "01000 00100 00010 00001 00010 00100 01000",
	"-": "00000 00000 00000 11111 00000 00000 00000",
	"/": "00001 00010 00010 00100 01000 01000 10000",
	" ": "00000 00000 00000 00000 00000 00000 00000",
}

# (texte, y du haut en points, couleur)
LINES = [
	("GLISSEZ DANS APPLICATIONS", 196, CYAN),
	("DRAG TO APPLICATIONS", 214, DIM),
	("1ER LANCEMENT : CLIC DROIT > OUVRIR", 250, CYAN),
	("FIRST LAUNCH: RIGHT-CLICK > OPEN", 268, DIM),
]
TEXT_PX = 2  # taille d'un pixel de police, en points


def render(scale: int) -> bytes:
	w, h = W * scale, H * scale
	px = [bytearray(BG * w) for _ in range(h)]

	def rect(x0: float, y0: float, x1: float, y1: float, c: tuple[int, int, int]) -> None:
		for y in range(max(0, int(y0 * scale)), min(h, int(y1 * scale))):
			row = px[y]
			for x in range(max(0, int(x0 * scale)), min(w, int(x1 * scale))):
				row[3 * x : 3 * x + 3] = bytes(c)

	# Trame discrète.
	for gx in range(0, W, 32):
		rect(gx, 0, gx + 1 / scale, H, GRID)
	for gy in range(0, H, 32):
		rect(0, gy, W, gy + 1 / scale, GRID)

	# Flèche entre l'application (x=160) et Applications (x=480), y=120.
	cy = 120
	rect(250, cy - 3, 372, cy + 3, CYAN)
	for i in range(0, 22 * scale):
		t = i / scale
		half = 14 - t * 14 / 22
		rect(372 + t, cy - half, 372 + t + 1 / scale, cy + half, CYAN)

	# Texte centré.
	for text, top, color in LINES:
		width = len(text) * 6 * TEXT_PX - TEXT_PX
		x = (W - width) / 2
		for ch in text:
			rows = FONT[ch].split()
			for r, bits in enumerate(rows):
				for c, bit in enumerate(bits):
					if bit == "1":
						rect(x + c * TEXT_PX, top + r * TEXT_PX, x + (c + 1) * TEXT_PX, top + (r + 1) * TEXT_PX, color)
			x += 6 * TEXT_PX

	# Filet bas.
	rect(32, H - 120, W - 32, H - 120 + 1, GRID)

	raw = b"".join(b"\x00" + bytes(row) for row in px)

	def chunk(kind: bytes, data: bytes) -> bytes:
		return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

	dpi = int(72 * scale / 0.0254)  # pixels par mètre (pHYs) : 72 ou 144 dpi
	return (
		b"\x89PNG\r\n\x1a\n"
		+ chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
		+ chunk(b"pHYs", struct.pack(">IIB", dpi, dpi, 1))
		+ chunk(b"IDAT", zlib.compress(raw, 9))
		+ chunk(b"IEND", b"")
	)


def main(argv: list[str]) -> int:
	if len(argv) not in (2, 3):
		print(__doc__.strip().splitlines()[2], file=sys.stderr)
		return 2
	scale = int(argv[2]) if len(argv) == 3 else 1
	with open(argv[1], "wb") as f:
		f.write(render(scale))
	return 0


if __name__ == "__main__":
	sys.exit(main(sys.argv))
