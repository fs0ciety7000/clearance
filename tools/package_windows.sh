#!/usr/bin/env bash
# Installateur Windows NSIS de CLEARANCE (ARCHITECTURE §16.9) — après export_all.sh.
#
# Usage :
#   bash tools/package_windows.sh          # build/dist/CLEARANCE-Setup-<version>.exe
#   bash tools/package_windows.sh --demo   # build/dist/CLEARANCE-Demo-Setup-<version>.exe
# Entrée : build/dist/CLEARANCE-<version>[-demo]-windows.zip (tools/export_all.sh [--demo]).
# Prérequis : makensis ≥ 3 (Debian/Ubuntu : apt-get install nsis ; Arch : pacman -S nsis ;
# macOS : brew install makensis), unzip. Variable VERSION=… pour une autre version
# que celle de project.godot.
#
# Assistant FR/EN, installation par utilisateur sans droits administrateur
# (%LOCALAPPDATA%\Programs\CLEARANCE), raccourcis menu Démarrer et Bureau
# (facultatifs), désinstalleur enregistré (HKCU), icône, version et éditeur.
# Script NSIS : packaging/windows/clearance.nsi. Non signé (D-070).
set -euo pipefail
SCRIPT_NAME=package_windows
source "$(dirname "${BASH_SOURCE[0]}")/../packaging/common.sh"

command -v makensis >/dev/null 2>&1 || die "makensis introuvable (apt-get install nsis / pacman -S nsis / brew install makensis)"
command -v unzip >/dev/null 2>&1 || die "unzip requis"
NSIS_VER="$(makensis -VERSION)"
[[ "$NSIS_VER" =~ ^v?3\. ]] || die "NSIS 3 requis, trouvé $NSIS_VER"

ZIP="$DIST/CLEARANCE-$VERSION-${ARCHIVE_TAG}windows.zip"
[[ -f "$ZIP" ]] || die "$ZIP absent : lancer d'abord bash tools/export_all.sh $([[ $DEMO -eq 1 ]] && echo "--demo ")windows"
if [[ $DEMO -eq 1 ]]; then OUT="$DIST/CLEARANCE-Demo-Setup-$VERSION.exe"; else OUT="$DIST/CLEARANCE-Setup-$VERSION.exe"; fi

# Version de fichier Windows : 4 nombres (1.2.3-rc1 → 1.2.3.0).
IFS=. read -r v1 v2 v3 _ <<<"${VERSION%%[-+~]*}"
VERSION_QUAD="$v1.$v2.$((10#${v3:-0})).0"

WORK="$ROOT/build/_nsis"
rm -rf "$WORK" && mkdir -p "$WORK"
unzip -q "$ZIP" -d "$WORK"
SRC="$WORK/CLEARANCE-$VERSION-${ARCHIVE_TAG}windows"
[[ -f "$SRC/$APP.exe" && -f "$SRC/$APP.pck" ]] || die "$APP.exe / $APP.pck absents de $(basename "$ZIP")"

defs=(-DVERSION="$VERSION" -DVERSION_QUAD="$VERSION_QUAD" -DSRC_DIR="$SRC" -DOUT_FILE="$OUT" -DICON="$ROOT/assets/icons/icon.ico")
[[ $DEMO -eq 1 ]] && defs+=(-DDEMO)
echo "== installateur Windows $APP $VERSION (NSIS $NSIS_VER)"
rm -f "$OUT"
makensis -V2 -WX -INPUTCHARSET UTF8 "${defs[@]}" "$ROOT/packaging/windows/clearance.nsi" >"$ROOT/build/nsis_${ARCHIVE_TAG}windows.log" 2>&1 \
	|| { tail -30 "$ROOT/build/nsis_${ARCHIVE_TAG}windows.log" >&2; die "makensis en échec (journal : build/nsis_${ARCHIVE_TAG}windows.log)"; }
[[ -s "$OUT" ]] || die "$OUT non produit"
rm -rf "$WORK"
echo "   $(du -h "$OUT" | cut -f1)  ${OUT#"$ROOT"/}"
sha_line "$OUT"
