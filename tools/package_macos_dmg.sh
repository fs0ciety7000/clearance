#!/usr/bin/env bash
# Image disque macOS (.dmg) de CLEARANCE (ARCHITECTURE §16.9) — SUR UN MAC uniquement
# (hdiutil, ditto, codesign) : runner macOS de la CI, après le job Linux qui fournit
# l'archive macOS (artefact), ou localement après tools/export_all.sh macos.
#
# Usage :
#   bash tools/package_macos_dmg.sh          # build/dist/CLEARANCE-<version>.dmg
#   bash tools/package_macos_dmg.sh --demo   # build/dist/CLEARANCE-Demo-<version>.dmg
# Entrée : build/dist/CLEARANCE-<version>[-demo]-macos.zip (DIST=… pour un autre dossier).
# Facultatif : create-dmg (brew install create-dmg) pour le fond et la disposition ;
# sans lui, ou si la mise en page Finder échoue (AppleScript sur un runner sans
# session graphique), repli sur une image simple par hdiutil (même contenu).
# Variable VERSION=… pour une autre version que celle de project.godot.
#
# Contenu : CLEARANCE.app (« CLEARANCE Demo.app » pour la démo, pour ne pas écraser
# le jeu complet dans Applications ; renommer le paquet ne touche pas la signature),
# lien vers /Applications, « LISEZ-MOI - READ ME.txt » (clic droit › Ouvrir),
# dossier « Licences » (CREDITS.txt + licenses/). Signature ad hoc de Godot
# conservée telle quelle (D-070), vérifiée par codesign ; UDZO, volume HFS+.
set -euo pipefail
SCRIPT_NAME=package_macos_dmg
source "$(dirname "${BASH_SOURCE[0]}")/../packaging/common.sh"

[[ "$(uname -s)" == "Darwin" ]] || die "macOS requis (hdiutil) : en CI, job « macos-dmg » de .github/workflows/build.yml"
for tool in hdiutil ditto codesign python3; do
	command -v "$tool" >/dev/null 2>&1 || die "outil « $tool » requis"
done

ZIP="$DIST/CLEARANCE-$VERSION-${ARCHIVE_TAG}macos.zip"
[[ -f "$ZIP" ]] || die "$ZIP absent : lancer d'abord bash tools/export_all.sh $([[ $DEMO -eq 1 ]] && echo "--demo ")macos (ou télécharger l'artefact de la CI)"
if [[ $DEMO -eq 1 ]]; then
	OUT="$DIST/CLEARANCE-Demo-$VERSION.dmg"; APP_NAME="CLEARANCE Demo"
else
	OUT="$DIST/CLEARANCE-$VERSION.dmg"; APP_NAME="CLEARANCE"
fi
APP_FILE="$APP_NAME.app"
VOLNAME="$APP_NAME $VERSION"
README_FILE="LISEZ-MOI - READ ME.txt"

WORK="$ROOT/build/_dmg"
cleanup() {
	[[ -d "$WORK/mnt" ]] && hdiutil detach "$WORK/mnt" -force -quiet >/dev/null 2>&1 || true
}
trap cleanup EXIT
rm -rf "$WORK" && mkdir -p "$WORK/unzip" "$WORK/src"

# --- Contenu ------------------------------------------------------------------------
ditto -x -k "$ZIP" "$WORK/unzip"      # ditto : droits, liens et attributs conservés
[[ -d "$WORK/unzip/CLEARANCE.app/Contents/MacOS" ]] || die "CLEARANCE.app absent de $(basename "$ZIP")"
SRC="$WORK/src"
ditto "$WORK/unzip/CLEARANCE.app" "$SRC/$APP_FILE"
# Une signature invalide empêche tout lancement sur Apple Silicon : échec bloquant.
codesign --verify --deep --verbose=2 "$SRC/$APP_FILE" || die "signature du .app invalide (codesign --verify)"
codesign --verify --deep --strict "$SRC/$APP_FILE" 2>&1 || echo "$SCRIPT_NAME: note : codesign --strict signale un écart (non bloquant)" >&2
sig="$(codesign -dv "$SRC/$APP_FILE" 2>&1 || true)"
echo "$sig" | grep -q "Signature=adhoc" || echo "$SCRIPT_NAME: note : signature non ad hoc ($(echo "$sig" | grep -E '^(Signature|Authority)=' | head -1))"
mkdir -p "$SRC/Licences"
cp "$WORK/unzip/CREDITS.txt" "$SRC/Licences/"
ditto "$WORK/unzip/licenses" "$SRC/Licences/licenses"
sed -e "s/@APP_NAME@/$APP_NAME/g" -e "s/@APP_FILE@/$APP_FILE/g" -e "s/@VERSION@/$VERSION/g" \
	"$ROOT/packaging/macos/LISEZ-MOI.txt" > "$SRC/$README_FILE"

# --- Fond (1x + 2x Retina) ------------------------------------------------------------
python3 -I "$ROOT/packaging/macos/dmg_background.py" "$WORK/bg.png" 1
python3 -I "$ROOT/packaging/macos/dmg_background.py" "$WORK/bg@2x.png" 2
BG="$WORK/bg.png"
if command -v tiffutil >/dev/null 2>&1 && tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/bg.tiff" >/dev/null 2>&1; then
	BG="$WORK/bg.tiff"
fi

# hdiutil échoue parfois (« Resource busy ») sur les runners : 3 essais.
retry() { local n; for n in 1 2 3; do "$@" && return 0; echo "$SCRIPT_NAME: essai $n en échec : $1" >&2; sleep $((n * 5)); done; return 1; }

# --- Image disque -------------------------------------------------------------------
echo "== DMG $APP_NAME $VERSION"
rm -f "$OUT"
made=0
if command -v create-dmg >/dev/null 2>&1; then
	layout=(--volname "$VOLNAME" --volicon "$ROOT/assets/icons/icon.icns" --background "$BG"
		--window-pos 200 120 --window-size 640 420 --icon-size 96 --text-size 12
		--icon "$APP_FILE" 160 120 --hide-extension "$APP_FILE" --app-drop-link 480 120
		--icon "$README_FILE" 240 350 --icon "Licences" 400 350 --hdiutil-quiet)
	if create-dmg "${layout[@]}" "$OUT" "$SRC"; then
		made=1
	else
		echo "$SCRIPT_NAME: create-dmg (mise en page Finder) en échec : nouvel essai sans AppleScript" >&2
		rm -f "$OUT" "$DIST"/rw.*.dmg
		if create-dmg --skip-jenkins "${layout[@]}" "$OUT" "$SRC"; then made=1; else rm -f "$OUT" "$DIST"/rw.*.dmg; fi
	fi
fi
if [[ $made -eq 0 ]]; then
	echo "$SCRIPT_NAME: repli hdiutil (sans fond ni disposition)" >&2
	ln -s /Applications "$SRC/Applications"
	retry hdiutil create -quiet -volname "$VOLNAME" -srcfolder "$SRC" -fs HFS+ -format UDZO \
		-imagekey zlib-level=9 -ov "$OUT" || die "hdiutil create en échec"
fi
[[ -s "$OUT" ]] || die "$OUT non produit"

# --- Vérification : montage, contenu, signature -----------------------------------------
retry hdiutil verify -quiet "$OUT" || die "hdiutil verify en échec"
mkdir -p "$WORK/mnt"
retry hdiutil attach -quiet -nobrowse -readonly -noautoopen -mountpoint "$WORK/mnt" "$OUT" || die "montage impossible"
[[ -d "$WORK/mnt/$APP_FILE/Contents/MacOS" ]] || die "$APP_FILE absent du DMG"
[[ -L "$WORK/mnt/Applications" ]] || die "lien Applications absent du DMG"
[[ -f "$WORK/mnt/$README_FILE" && -f "$WORK/mnt/Licences/CREDITS.txt" ]] || die "LISEZ-MOI ou Licences absents du DMG"
codesign --verify --deep "$WORK/mnt/$APP_FILE" || die "signature invalide dans le DMG"
ls -la "$WORK/mnt"
hdiutil detach "$WORK/mnt" -quiet || hdiutil detach "$WORK/mnt" -force -quiet
rm -rf "$WORK"
echo "   $(du -h "$OUT" | cut -f1)  ${OUT#"$ROOT"/}"
sha_line "$OUT"
