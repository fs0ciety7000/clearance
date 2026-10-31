#!/usr/bin/env bash
# Export Web (HTML5) de la démo CLEARANCE — M15 lot W, D-216, docs/WEB.md.
#
# Usage (depuis n'importe où) :
#   bash tools/export_web.sh
# Variables : GODOT (binaire, défaut « godot »), GODOT_TEMPLATES_DIR (dossier des
# modèles 4.7.2.stable, défaut : dossier de données Godot de l'utilisateur).
#
# Préréglage « Web » d'export_presets.cfg : démo J1–J5 (feature « demo »),
# rendu Compatibility (WebGL 2), threads (en-têtes COOP/COEP obligatoires à
# l'hébergement : web/nginx-clearance-web.conf).
#
# Sorties (ignorées par git) :
#   build/web/                         site statique prêt à servir :
#     index.html, index.js, index.wasm, index.pck, index.audio*.worklet.js,
#     icônes, CREDITS.txt, licenses/
#     *.gz                             versions gzip -9 (nginx gzip_static)
#   build/dist/CLEARANCE-<version>-web.zip       le dossier ci-dessus (sans .gz)
#   build/dist/SHA256SUMS-web
# Déterministe : dates figées au dernier commit (SOURCE_DATE_EPOCH), ordre trié,
# gzip -n (sans nom ni date). Le .pck et le .wasm de Godot sont eux-mêmes
# identiques d'un export à l'autre (vérifié, docs/WEB.md §6).
set -euo pipefail

GODOT="${GODOT:-godot}"
GODOT_VERSION="4.7.2.stable"
PRESET="Web"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
OUT="$BUILD/web"
DIST="$BUILD/dist"
LOG="$BUILD/export_web.log"

die() { echo "export_web: ERREUR : $*" >&2; exit 1; }

# --- Prérequis ------------------------------------------------------------------
command -v "$GODOT" >/dev/null 2>&1 || die "Godot introuvable (« $GODOT ») : bash tools/install_godot.sh ou GODOT=/chemin/godot"
ACTUAL="$("$GODOT" --version | head -n1)"
[[ "$ACTUAL" == "$GODOT_VERSION"* ]] || die "Godot $GODOT_VERSION requis, trouvé « $ACTUAL »"
for tool in zip gzip sha256sum; do
	command -v "$tool" >/dev/null 2>&1 || die "outil « $tool » requis"
done

grep -q "^name=\"$PRESET\"$" "$ROOT/export_presets.cfg" || die "préréglage « $PRESET » absent d'export_presets.cfg"
# Modèle attendu selon le préréglage : variant/thread_support de [preset.N.options].
idx="$(awk '/^\[preset\.[0-9]+\]$/{gsub(/[^0-9]/,""); n=$0} /^name="Web"$/{print n; exit}' "$ROOT/export_presets.cfg")"
threads="$(awk -v sec="[preset.$idx.options]" '$0==sec{o=1; next} /^\[/{o=0} o&&/^variant\/thread_support=/{print; exit}' "$ROOT/export_presets.cfg")"
if [[ "$threads" == *"=true" ]]; then TEMPLATE="web_release.zip"; else TEMPLATE="web_nothreads_release.zip"; fi

if [[ -z "${GODOT_TEMPLATES_DIR:-}" ]]; then
	if [[ "$(uname -s)" == "Darwin" ]]; then
		GODOT_TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
	else
		GODOT_TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION"
	fi
fi
[[ -f "$GODOT_TEMPLATES_DIR/$TEMPLATE" ]] || die "modèle d'export Web manquant : $GODOT_TEMPLATES_DIR/$TEMPLATE
  Installer Godot_v4.7.2-stable_export_templates.tpz (bash tools/install_godot.sh --templates)."

VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")"
[[ -n "$VERSION" ]] || die "application/config/version absente de project.godot"
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || date +%s)}"
export SOURCE_DATE_EPOCH

echo "== CLEARANCE $VERSION — Web ($TEMPLATE) — Godot $ACTUAL"
mkdir -p "$BUILD" "$DIST"

# --- Import puis export ------------------------------------------------------------
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || die "échec de l'import Godot"

rm -rf "$OUT" && mkdir -p "$OUT"
rc=0
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT/index.html" >"$LOG.raw" 2>&1 || rc=$?
sed 's/\x1b\[[0-9;]*m//g' "$LOG.raw" > "$LOG" && rm -f "$LOG.raw"
if [[ $rc -ne 0 ]] || grep -qE "^(SCRIPT )?ERROR" "$LOG"; then
	grep -E -A1 "^(SCRIPT )?ERROR" "$LOG" >&2 || true
	die "export « $PRESET » en échec (journal : ${LOG#"$ROOT"/})"
fi
for f in index.html index.js index.wasm index.pck index.audio.worklet.js; do
	[[ -s "$OUT/$f" ]] || die "fichier exporté absent : build/web/$f"
done

# --- Crédits et licences (comme les archives natives, ARCHITECTURE §16.3) ----------
cp "$ROOT/CREDITS.txt" "$OUT/"
mkdir -p "$OUT/licenses"
cp "$ROOT"/assets/fonts/OFL-*.txt "$ROOT"/assets/models/passenger/License_*.txt "$OUT/licenses/"
"$GODOT" --headless --path "$ROOT" --script res://tools/write_engine_licenses.gd \
	-- --out="$OUT/licenses/GODOT_ENGINE.txt" >"$BUILD/licenses_web.log" 2>&1 || die "notices du moteur non générées"
[[ -s "$OUT/licenses/GODOT_ENGINE.txt" ]] || die "licenses/GODOT_ENGINE.txt vide"

# --- Archive (sans .gz) puis versions gzip pour gzip_static ------------------------
find "$OUT" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
name="CLEARANCE-$VERSION-web"
archive="$DIST/$name.zip"
rm -f "$archive"
stage="$BUILD/_stage_web"
rm -rf "$stage" && mkdir -p "$stage" && cp -a "$OUT" "$stage/$name"
(cd "$stage" && find "$name" -print | LC_ALL=C sort | zip -q -X -@ "$archive")
rm -rf "$stage"

for f in "$OUT"/*.html "$OUT"/*.js "$OUT"/*.wasm "$OUT"/*.pck; do
	gzip -n -9 -c "$f" > "$f.gz"
	touch -h -d "@$SOURCE_DATE_EPOCH" "$f.gz"
done
(cd "$DIST" && sha256sum "$name.zip" > SHA256SUMS-web)

# --- Bilan --------------------------------------------------------------------------
size() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1"; }
mb() { awk -v b="$1" 'BEGIN { printf "%.1f Mo", b / 1048576 }'; }
raw=0; gz=0
for f in index.wasm index.pck index.js index.html index.audio.worklet.js index.audio.position.worklet.js; do
	raw=$((raw + $(size "$OUT/$f")))
	if [[ -f "$OUT/$f.gz" ]]; then gz=$((gz + $(size "$OUT/$f.gz"))); else gz=$((gz + $(size "$OUT/$f"))); fi
done
printf "   %-10s %10s  (gzip %s)\n" "index.wasm" "$(mb "$(size "$OUT/index.wasm")")" "$(mb "$(size "$OUT/index.wasm.gz")")"
printf "   %-10s %10s  (gzip %s)\n" "index.pck" "$(mb "$(size "$OUT/index.pck")")" "$(mb "$(size "$OUT/index.pck.gz")")"
echo "   téléchargement : $(mb $raw) brut, $(mb $gz) compressé (gzip)"
echo "   $(du -h "$archive" | cut -f1)  ${archive#"$ROOT"/}"
echo "== build/web prêt (servir avec COOP/COEP : web/nginx-clearance-web.conf ; test : node tools/smoke_web.js)"
