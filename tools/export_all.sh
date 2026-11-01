#!/usr/bin/env bash
# Export release de CLEARANCE et archives de distribution (ARCHITECTURE §16).
#
# Usage (depuis n'importe où) :
#   bash tools/export_all.sh                   # windows macos linux
#   bash tools/export_all.sh linux             # une ou plusieurs plateformes
#   bash tools/export_all.sh all               # + linux-arm64
#   bash tools/export_all.sh --demo [linux…]   # M15 (D-215) : démo J1–J5, préréglages « … Demo »
#                                              # (fonctionnalité « demo » ; windows macos linux)
# Variables : GODOT (binaire, défaut « godot »), GODOT_TEMPLATES_DIR (dossier des
# modèles 4.7.2.stable, défaut : dossier de données Godot de l'utilisateur).
#
# Sorties (ignorées par git) :
#   build/<plateforme>/                      export brut de Godot
#   build/dist/CLEARANCE-<version>-windows.zip      .exe + .pck + CREDITS.txt + licenses/
#   build/dist/CLEARANCE-<version>-macos.zip        CLEARANCE.app (universel, signé ad hoc) + CREDITS.txt + licenses/
#   build/dist/CLEARANCE-<version>-linux.tar.gz     binaire x86_64 (Steam Deck) + .pck + CREDITS.txt + licenses/
#   build/dist/SHA256SUMS
# Avec --demo : build/demo-<plateforme>/ et build/dist/CLEARANCE-<version>-demo-<plateforme>.*
# (SHA256SUMS couvre alors les archives de la démo).
set -euo pipefail

GODOT="${GODOT:-godot}"
GODOT_VERSION="4.7.2.stable"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$BUILD/dist"

die() { echo "export_all: ERREUR : $*" >&2; exit 1; }

# --- Plateformes demandées ------------------------------------------------------
DEMO=0
PLATFORMS=()
for arg in "$@"; do
	case "$arg" in
		--demo) DEMO=1 ;;
		*) PLATFORMS+=("$arg") ;;
	esac
done
[[ ${#PLATFORMS[@]} -eq 0 ]] && PLATFORMS=(windows macos linux)
[[ "${PLATFORMS[*]}" == "all" ]] && PLATFORMS=(windows macos linux linux-arm64)

preset_of()   { case "$1" in windows) echo "Windows Desktop";; macos) echo "macOS";; linux) echo "Linux";; linux-arm64) echo "Linux ARM64";; *) return 1;; esac; }
output_of()   { case "$1" in windows) echo "CLEARANCE.exe";; macos) echo "CLEARANCE.zip";; linux) echo "CLEARANCE.x86_64";; linux-arm64) echo "CLEARANCE.arm64";; esac; }
if [[ $DEMO -eq 1 ]]; then
	# Démo (D-215) : préréglages « <nom> Demo », binaires CLEARANCE-Demo.*, pas d'ARM64.
	preset_of() { case "$1" in windows) echo "Windows Desktop Demo";; macos) echo "macOS Demo";; linux) echo "Linux Demo";; *) return 1;; esac; }
	output_of() { case "$1" in windows) echo "CLEARANCE-Demo.exe";; macos) echo "CLEARANCE-Demo.zip";; linux) echo "CLEARANCE-Demo.x86_64";; esac; }
	kept=()
	for p in "${PLATFORMS[@]}"; do [[ "$p" == "linux-arm64" ]] || kept+=("$p"); done
	PLATFORMS=("${kept[@]}")
fi
build_dir_of() { if [[ $DEMO -eq 1 ]]; then echo "$BUILD/demo-$1"; else echo "$BUILD/$1"; fi; }
DIST_TAG=""
[[ $DEMO -eq 1 ]] && DIST_TAG="demo-"
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

echo "== CLEARANCE $VERSION$([[ $DEMO -eq 1 ]] && echo " DÉMO J1–J5") — Godot $ACTUAL — ${PLATFORMS[*]}"

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
	out_dir="$(build_dir_of "$p")"
	out_file="$out_dir/$(output_of "$p")"
	rm -rf "$out_dir" && mkdir -p "$out_dir"
	log="$BUILD/export_${DIST_TAG}$p.log"
	echo "-- export « $preset » → ${out_file#"$ROOT"/}"
	rc=0
	"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$out_file" >"$log.raw" 2>&1 || rc=$?
	sed 's/\x1b\[[0-9;]*m//g' "$log.raw" > "$log" && rm -f "$log.raw"
	if [[ $rc -ne 0 ]] || grep -qE "^(SCRIPT )?ERROR" "$log" || [[ ! -s "$out_file" ]]; then
		grep -E -A1 "^(SCRIPT )?ERROR" "$log" >&2 || true
		die "export « $preset » en échec (journal : ${log#"$ROOT"/})"
	fi

	name="CLEARANCE-$VERSION-${DIST_TAG}$p"
	stage="$BUILD/_stage/$name"
	rm -rf "$BUILD/_stage" && mkdir -p "$stage"
	cp -r "$COMMON/." "$stage/"
	case "$p" in
		windows)
			cp "$out_file" "${out_file%.exe}.pck" "$stage/"
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
			cp "${out_file%.*}".* "$stage/"
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

SUMS="SHA256SUMS"
[[ $DEMO -eq 1 ]] && SUMS="SHA256SUMS-demo"
if [[ $DEMO -eq 1 ]]; then
	(cd "$DIST" && sha256sum CLEARANCE-"$VERSION"-demo-* > "$SUMS")
else
	(cd "$DIST" && find . -maxdepth 1 -name "CLEARANCE-$VERSION-*" ! -name "CLEARANCE-$VERSION-demo-*" -printf '%f\n' | LC_ALL=C sort | xargs sha256sum > "$SUMS")
fi
echo "== archives dans ${DIST#"$ROOT"/} :"
(cd "$DIST" && ls -l CLEARANCE-"$VERSION"-${DIST_TAG}* "$SUMS")
