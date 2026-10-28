#!/usr/bin/env bash
# Export release de CLEARANCE et archives de distribution (ARCHITECTURE §16).
#
# Usage (depuis n'importe où) :
#   bash tools/export_all.sh                   # windows macos linux
#   bash tools/export_all.sh linux             # une ou plusieurs plateformes
#   bash tools/export_all.sh all               # + linux-arm64
# Variables : GODOT (binaire, défaut « godot »), GODOT_TEMPLATES_DIR (dossier des
# modèles 4.7.2.stable, défaut : dossier de données Godot de l'utilisateur).
#
# Sorties (ignorées par git) :
#   build/<plateforme>/                      export brut de Godot
#   build/dist/CLEARANCE-<version>-windows.zip      .exe + .pck + CREDITS.txt + licenses/
#   build/dist/CLEARANCE-<version>-macos.zip        CLEARANCE.app (universel, signé ad hoc) + CREDITS.txt + licenses/
#   build/dist/CLEARANCE-<version>-linux.tar.gz     binaire x86_64 (Steam Deck) + .pck + CREDITS.txt + licenses/
#   build/dist/SHA256SUMS
set -euo pipefail

GODOT="${GODOT:-godot}"
GODOT_VERSION="4.7.2.stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$BUILD/dist"

die() { echo "export_all: ERREUR : $*" >&2; exit 1; }

# --- Plateformes demandées ------------------------------------------------------
PLATFORMS=("$@")
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(windows macos linux)
[[ "${PLATFORMS[*]}" == "all" ]] && PLATFORMS=(windows macos linux linux-arm64)

preset_of()   { case "$1" in windows) echo "Windows Desktop";; macos) echo "macOS";; linux) echo "Linux";; linux-arm64) echo "Linux ARM64";; *) return 1;; esac; }
output_of()   { case "$1" in windows) echo "CLEARANCE.exe";; macos) echo "CLEARANCE.zip";; linux) echo "CLEARANCE.x86_64";; linux-arm64) echo "CLEARANCE.arm64";; esac; }
template_of() { case "$1" in windows) echo "windows_release_x86_64.exe";; macos) echo "macos.zip";; linux) echo "linux_release.x86_64";; linux-arm64) echo "linux_release.arm64";; esac; }

for p in "${PLATFORMS[@]}"; do
	preset_of "$p" >/dev/null || die "plateforme inconnue « $p » (windows, macos, linux, linux-arm64, all)"
done

# --- Prérequis ------------------------------------------------------------------
command -v "$GODOT" >/dev/null 2>&1 || die "Godot introuvable (« $GODOT ») : bash tools/install_godot.sh ou GODOT=/chemin/godot"
ACTUAL="$("$GODOT" --version | head -n1)"
[[ "$ACTUAL" == "$GODOT_VERSION"* ]] || die "Godot $GODOT_VERSION requis, trouvé « $ACTUAL »"

if [[ -z "${GODOT_TEMPLATES_DIR:-}" ]]; then
	if [[ "$(uname -s)" == "Darwin" ]]; then
		GODOT_TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION"
	else
		GODOT_TEMPLATES_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$GODOT_VERSION"
	fi
fi
missing=()
for p in "${PLATFORMS[@]}"; do
	[[ -f "$GODOT_TEMPLATES_DIR/$(template_of "$p")" ]] || missing+=("$(template_of "$p")")
done
if [[ ${#missing[@]} -gt 0 ]]; then
	die "modèles d'export manquants dans $GODOT_TEMPLATES_DIR : ${missing[*]}
  Installer Godot_v4.7.2-stable_export_templates.tpz (bash tools/install_godot.sh --templates)."
fi
for tool in zip tar sha256sum; do
	command -v "$tool" >/dev/null 2>&1 || die "outil « $tool » requis"
done

VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")"
[[ -n "$VERSION" ]] || die "application/config/version absente de project.godot"
# Dates figées dans les archives (reproductibilité) : date du dernier commit.
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || date +%s)}"
export SOURCE_DATE_EPOCH

echo "== CLEARANCE $VERSION — Godot $ACTUAL — ${PLATFORMS[*]}"

# --- Import (génère .godot/imported et fr.fr.translation) -------------------------
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || die "échec de l'import Godot"

# --- Fichiers communs : crédits et licences --------------------------------------
COMMON="$BUILD/_common"
rm -rf "$COMMON" && mkdir -p "$COMMON/licenses"
cp "$ROOT/CREDITS.txt" "$COMMON/"
cp "$ROOT"/assets/fonts/OFL-*.txt "$ROOT"/assets/models/passenger/License_*.txt "$COMMON/licenses/"
"$GODOT" --headless --path "$ROOT" --script res://tools/write_engine_licenses.gd \
	-- --out="$COMMON/licenses/GODOT_ENGINE.txt" >"$BUILD/licenses.log" 2>&1 || die "notices du moteur non générées"
[[ -s "$COMMON/licenses/GODOT_ENGINE.txt" ]] || die "licenses/GODOT_ENGINE.txt vide"
find "$COMMON" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

mkdir -p "$DIST"

# zip déterministe d'un dossier (ordre trié, sans attributs étendus).
zip_dir() { # $1 dossier parent, $2 nom du dossier racine, $3 archive
	(cd "$1" && find "$2" -print | LC_ALL=C sort | zip -q -X -@ "$3")
}

# --- Export + archive par plateforme ----------------------------------------------
for p in "${PLATFORMS[@]}"; do
	preset="$(preset_of "$p")"
	out_dir="$BUILD/$p"
	out_file="$out_dir/$(output_of "$p")"
	rm -rf "$out_dir" && mkdir -p "$out_dir"
	log="$BUILD/export_$p.log"
	echo "-- export « $preset » → ${out_file#"$ROOT"/}"
	rc=0
	"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$out_file" >"$log.raw" 2>&1 || rc=$?
	sed 's/\x1b\[[0-9;]*m//g' "$log.raw" > "$log" && rm -f "$log.raw"
	if [[ $rc -ne 0 ]] || grep -qE "^(SCRIPT )?ERROR" "$log" || [[ ! -s "$out_file" ]]; then
		grep -E -A1 "^(SCRIPT )?ERROR" "$log" >&2 || true
		die "export « $preset » en échec (journal : ${log#"$ROOT"/})"
	fi

	name="CLEARANCE-$VERSION-$p"
	stage="$BUILD/_stage/$name"
	rm -rf "$BUILD/_stage" && mkdir -p "$stage"
	cp -r "$COMMON/." "$stage/"
	case "$p" in
		windows)
			cp "$out_dir"/CLEARANCE.exe "$out_dir"/CLEARANCE.pck "$stage/"
			archive="$DIST/$name.zip"; rm -f "$archive"
			find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
			zip_dir "$BUILD/_stage" "$name" "$archive"
			;;
		macos)
			# Zip produit par Godot (CLEARANCE.app signé ad hoc, droits conservés) ;
			# crédits ajoutés à côté du .app (pas dedans : la signature resterait valide).
			archive="$DIST/$name.zip"; rm -f "$archive"
			cp "$out_file" "$archive"
			find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
			(cd "$stage" && find CREDITS.txt licenses -print | LC_ALL=C sort | zip -q -X -@ "$archive")
			;;
		linux|linux-arm64)
			cp "$out_dir"/CLEARANCE.* "$stage/"
			chmod 0755 "$stage/$(output_of "$p")"
			archive="$DIST/$name.tar.gz"; rm -f "$archive"
			tar -C "$BUILD/_stage" --sort=name --owner=0 --group=0 --numeric-owner \
				--mtime="@$SOURCE_DATE_EPOCH" -cf - "$name" | gzip -n -9 > "$archive"
			;;
	esac
	rm -rf "$BUILD/_stage"
	echo "   $(du -h "$archive" | cut -f1)  ${archive#"$ROOT"/}"
done
rm -rf "$COMMON"

(cd "$DIST" && sha256sum CLEARANCE-"$VERSION"-* > SHA256SUMS)
echo "== archives dans ${DIST#"$ROOT"/} :"
(cd "$DIST" && ls -l CLEARANCE-"$VERSION"-* SHA256SUMS)
