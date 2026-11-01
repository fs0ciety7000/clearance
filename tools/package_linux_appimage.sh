#!/usr/bin/env bash
# AppImage Linux x86_64 de CLEARANCE (ARCHITECTURE §16.9) — après export_all.sh.
#
# Usage :
#   bash tools/package_linux_appimage.sh          # build/dist/CLEARANCE-<version>-x86_64.AppImage
#   bash tools/package_linux_appimage.sh --demo   # build/dist/CLEARANCE-Demo-<version>-x86_64.AppImage
# Entrée : build/dist/CLEARANCE-<version>[-demo]-linux.tar.gz (tools/export_all.sh [--demo]).
# Prérequis : curl, tar, sha256sum, python3 (aucun FUSE requis pour construire).
# Variable VERSION=… pour une autre version que celle de project.godot.
#
# appimagetool OFFICIEL (github.com/AppImage/appimagetool) et runtime type 2
# (github.com/AppImage/type2-runtime), versions figées, téléchargés à la volée
# dans build/_tools/ et vérifiés par SHA-256 (jamais versionnés). AppDir :
#   AppRun, <id>.desktop, clearance.png, .DirIcon,
#   usr/lib/clearance/  (binaire + .pck + CREDITS.txt + licenses/)
#   usr/bin/clearance → ../lib/clearance/<binaire>
#   usr/share/applications/, usr/share/icons/hicolor/, usr/share/metainfo/ (AppStream)
# Squashfs zstd ; reproductible (dates = SOURCE_DATE_EPOCH, comme export_all.sh).
set -euo pipefail
SCRIPT_NAME=package_linux_appimage
source "$(dirname "${BASH_SOURCE[0]}")/../packaging/common.sh"

APPIMAGETOOL_VERSION="1.9.0"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/$APPIMAGETOOL_VERSION/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="46fdd785094c7f6e545b61afcfb0f3d98d8eab243f644b4b17698c01d06083d1"
RUNTIME_VERSION="20251108"
RUNTIME_URL="https://github.com/AppImage/type2-runtime/releases/download/$RUNTIME_VERSION/runtime-x86_64"
RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

[[ "$(uname -m)" == "x86_64" ]] || die "construction prévue sur x86_64 (appimagetool x86_64)"
for tool in curl tar sha256sum python3; do
	command -v "$tool" >/dev/null 2>&1 || die "outil « $tool » requis"
done

TGZ="$DIST/CLEARANCE-$VERSION-${ARCHIVE_TAG}linux.tar.gz"
[[ -f "$TGZ" ]] || die "$TGZ absent : lancer d'abord bash tools/export_all.sh $([[ $DEMO -eq 1 ]] && echo "--demo ")linux"
if [[ $DEMO -eq 1 ]]; then
	OUT="$DIST/CLEARANCE-Demo-$VERSION-x86_64.AppImage"; ID="com.clearance.game.demo"; NAME="CLEARANCE Demo"
else
	OUT="$DIST/CLEARANCE-$VERSION-x86_64.AppImage"; ID="com.clearance.game"; NAME="CLEARANCE"
fi
BIN="$APP.x86_64"

# --- Outils figés, vérifiés par SHA-256 -------------------------------------------
TOOLS="$ROOT/build/_tools"
mkdir -p "$TOOLS"
fetch() { # $1 url, $2 fichier, $3 sha256
	if [[ ! -f "$2" ]] || ! echo "$3  $2" | sha256sum -c --quiet - >/dev/null 2>&1; then
		rm -f "$2"
		curl -fsSL --retry 3 -o "$2.part" "$1" || die "téléchargement impossible : $1"
		echo "$3  $2.part" | sha256sum -c --quiet - || { rm -f "$2.part"; die "SHA-256 inattendu pour $1"; }
		mv "$2.part" "$2"
	fi
	chmod 0755 "$2"
}
APPIMAGETOOL="$TOOLS/appimagetool-$APPIMAGETOOL_VERSION-x86_64.AppImage"
RUNTIME="$TOOLS/runtime-$RUNTIME_VERSION-x86_64"
fetch "$APPIMAGETOOL_URL" "$APPIMAGETOOL" "$APPIMAGETOOL_SHA256"
fetch "$RUNTIME_URL" "$RUNTIME" "$RUNTIME_SHA256"

# --- AppDir ------------------------------------------------------------------------
WORK="$ROOT/build/_appimage"
rm -rf "$WORK" && mkdir -p "$WORK"
tar -xzf "$TGZ" -C "$WORK"
SRC="$WORK/CLEARANCE-$VERSION-${ARCHIVE_TAG}linux"
[[ -x "$SRC/$BIN" && -f "$SRC/$APP.pck" ]] || die "$BIN / $APP.pck absents de $(basename "$TGZ")"
APPDIR="$WORK/$APP.AppDir"
LIB="$APPDIR/usr/lib/clearance"
mkdir -p "$LIB" "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/metainfo"
cp -a "$SRC/$BIN" "$SRC/$APP.pck" "$SRC/CREDITS.txt" "$SRC/licenses" "$LIB/"
ln -s "../lib/clearance/$BIN" "$APPDIR/usr/bin/clearance"

# Icônes : celles de l'archive (packaging/icons.py) ou, à défaut, extraites ici.
if [[ -d "$SRC/icons/hicolor" ]]; then
	mkdir -p "$APPDIR/usr/share/icons" && cp -a "$SRC/icons/hicolor" "$APPDIR/usr/share/icons/"
else
	python3 -I "$ROOT/packaging/icons.py" "$ROOT/assets/icons" "$ROOT/icon.svg" "$APPDIR/usr/share/icons" \
		|| die "icônes non générées"
fi
cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/clearance.png" "$APPDIR/clearance.png"
ln -s clearance.png "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<EOF
#!/bin/sh
# Point d'entrée de l'AppImage $NAME : lance le binaire Godot (le .pck est à côté).
HERE="\$(dirname "\$(readlink -f "\$0")")"
exec "\$HERE/usr/lib/clearance/$BIN" "\$@"
EOF
chmod 0755 "$APPDIR/AppRun"

cat > "$APPDIR/usr/share/applications/$ID.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
GenericName=Identity control game
GenericName[fr]=Jeu de contrôle d'identité
Comment=Identity control at the gate of a corporate orbital station
Comment[fr]=Contrôle d'identité à l'entrée d'une station orbitale corporative
Exec=clearance
Icon=clearance
Terminal=false
Categories=Game;Simulation;
Keywords=papers;border;identity;space;station;
Keywords[fr]=papiers;frontière;identité;espace;station;
StartupWMClass=CLEARANCE
PrefersNonDefaultGPU=true
X-AppImage-Version=$VERSION
EOF
ln -s "usr/share/applications/$ID.desktop" "$APPDIR/$ID.desktop"

DATE="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y-%m-%d 2>/dev/null || date -u -r "$SOURCE_DATE_EPOCH" +%Y-%m-%d)"
sed -e "s/@ID@/$ID/g" -e "s/@NAME@/$NAME/g" -e "s/@VERSION@/$VERSION/g" -e "s/@DATE@/$DATE/g" \
	"$ROOT/packaging/linux/metainfo.xml.in" > "$APPDIR/usr/share/metainfo/$ID.metainfo.xml"
if command -v desktop-file-validate >/dev/null 2>&1; then
	desktop-file-validate "$APPDIR/usr/share/applications/$ID.desktop" || die ".desktop invalide"
fi
if command -v appstreamcli >/dev/null 2>&1; then
	appstreamcli validate --no-net --explain "$APPDIR/usr/share/metainfo/$ID.metainfo.xml" >"$WORK/appstream.log" 2>&1 \
		|| { cat "$WORK/appstream.log" >&2; die "métadonnées AppStream invalides"; }
fi
find "$APPDIR" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

# --- AppImage ----------------------------------------------------------------------
echo "== AppImage $APP $VERSION (appimagetool $APPIMAGETOOL_VERSION, runtime $RUNTIME_VERSION)"
rm -f "$OUT"
LOG="$ROOT/build/appimage_${ARCHIVE_TAG}linux.log"
# APPIMAGE_EXTRACT_AND_RUN : appimagetool s'exécute sans FUSE (conteneurs, CI).
# --no-appstream : la validation est faite ci-dessus par appstreamcli si présent.
# Reproductible au bit près : dates du squashfs passées explicitement à mksquashfs
# (-mkfs-time / -all-time), propriétaire root ; SOURCE_DATE_EPOCH est retiré de
# l'environnement car mksquashfs refuse l'option et la variable à la fois.
(cd "$WORK" && env -u SOURCE_DATE_EPOCH ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 VERSION="$VERSION" "$APPIMAGETOOL" \
	--runtime-file "$RUNTIME" --comp zstd --no-appstream \
	--mksquashfs-opt -mkfs-time --mksquashfs-opt "$SOURCE_DATE_EPOCH" --mksquashfs-opt -all-time --mksquashfs-opt "$SOURCE_DATE_EPOCH" --mksquashfs-opt -all-root \
	"$APPDIR" "$OUT") >"$LOG" 2>&1 \
	|| { tail -30 "$LOG" >&2; die "appimagetool en échec (journal : ${LOG#"$ROOT"/})"; }
[[ -s "$OUT" ]] || die "$OUT non produit"
chmod 0755 "$OUT"
rm -rf "$WORK"
echo "   $(du -h "$OUT" | cut -f1)  ${OUT#"$ROOT"/}"
sha_line "$OUT"
