#!/usr/bin/env bash
# Met à jour le paquet AUR clearance-bin pour une Release (ARCHITECTURE §16.9).
#
# Usage :
#   bash tools/update_aur.sh <version> [--pkgrel N] [--local <archive.tar.gz>]
#     <version>   version publiée (tag v<version>), ex. 1.0.0 ou 1.1.0-rc1
#     --pkgrel N  révision du paquet (défaut 1 ; à incrémenter si seul le PKGBUILD change)
#     --local F   prend l'archive Linux locale F au lieu de la télécharger (tests ;
#                 la somme doit alors être identique à celle de la Release)
#
# Télécharge CLEARANCE-<version>-linux.tar.gz depuis la Release GitHub (gh si
# connecté — dépôt privé —, sinon curl), la recoupe avec SHA256SUMS de la Release,
# vérifie son contenu (binaire, .pck, icons/hicolor, licences), puis réécrit dans
# packaging/aur/clearance-bin/ : _relver, pkgrel, sha256sums et .SRCINFO
# (makepkg --printsrcinfo si disponible hors root, sinon générateur interne au
# même format). Ne publie rien : voir packaging/aur/README.md.
set -euo pipefail

REPO="fs0ciety7000/clearance"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${AUR_DIR:-$ROOT/packaging/aur/clearance-bin}"   # AUR_DIR=… : copie de travail (tests, dépôt AUR cloné)
die() { echo "update_aur: ERREUR : $*" >&2; exit 1; }

VERSION=""; PKGREL=1; LOCAL=""
while [[ $# -gt 0 ]]; do
	case "$1" in
		--pkgrel) PKGREL="${2:-}"; shift 2 ;;
		--local) LOCAL="${2:-}"; shift 2 ;;
		-h|--help) sed -n '2,17p' "$0"; exit 0 ;;
		-*) die "option inconnue : $1" ;;
		*) [[ -z "$VERSION" ]] || die "une seule version attendue"; VERSION="${1#v}"; shift ;;
	esac
done
[[ -n "$VERSION" ]] || die "usage : tools/update_aur.sh <version> [--pkgrel N] [--local archive]"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || die "version invalide : $VERSION"
[[ "$PKGREL" =~ ^[1-9][0-9]*$ ]] || die "pkgrel invalide : $PKGREL"
command -v sha256sum >/dev/null 2>&1 || die "sha256sum requis"

ARCHIVE="CLEARANCE-$VERSION-linux.tar.gz"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- Archive de la Release -------------------------------------------------------------
if [[ -n "$LOCAL" ]]; then
	[[ -f "$LOCAL" ]] || die "$LOCAL introuvable"
	cp "$LOCAL" "$TMP/$ARCHIVE"
	echo "-- archive locale : $LOCAL (non recoupée avec la Release)"
else
	if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
		gh release download "v$VERSION" -R "$REPO" -p "$ARCHIVE" -p SHA256SUMS -D "$TMP" \
			|| die "Release v$VERSION ou $ARCHIVE introuvable sur $REPO"
	else
		base="https://github.com/$REPO/releases/download/v$VERSION"
		curl -fsSL --retry 3 -o "$TMP/$ARCHIVE" "$base/$ARCHIVE" || die "téléchargement impossible : $base/$ARCHIVE (dépôt privé ? gh auth login)"
		curl -fsSL --retry 3 -o "$TMP/SHA256SUMS" "$base/SHA256SUMS" || die "SHA256SUMS absent de la Release v$VERSION"
	fi
	(cd "$TMP" && grep " $ARCHIVE\$" SHA256SUMS | sha256sum -c --quiet -) \
		|| die "$ARCHIVE ne correspond pas à SHA256SUMS de la Release"
	echo "-- $ARCHIVE téléchargée et recoupée avec SHA256SUMS de la Release v$VERSION"
fi
SUM="$(sha256sum "$TMP/$ARCHIVE" | cut -d' ' -f1)"

listing="$(tar -tzf "$TMP/$ARCHIVE")" || die "archive illisible"
for f in CLEARANCE.x86_64 CLEARANCE.pck CREDITS.txt licenses/GODOT_ENGINE.txt \
	icons/hicolor/256x256/apps/clearance.png icons/hicolor/scalable/apps/clearance.svg; do
	grep -qx "CLEARANCE-$VERSION-linux/$f" <<<"$listing" \
		|| die "$f absent de $ARCHIVE (Release antérieure à l'archive avec icônes ?)"
done

# --- PKGBUILD ---------------------------------------------------------------------------
cd "$PKG_DIR"
DESKTOP_SUM="$(sha256sum clearance.desktop | cut -d' ' -f1)"
sed -i.bak \
	-e "s/^_relver=.*/_relver=$VERSION/" \
	-e "s/^pkgrel=.*/pkgrel=$PKGREL/" \
	PKGBUILD
python3 -I - "$SUM" "$DESKTOP_SUM" <<'PY' || die "sha256sums non réécrites"
import re, sys
p = "PKGBUILD"
s = open(p, encoding="utf-8").read()
new = "sha256sums=('%s'\n            '%s')" % (sys.argv[1], sys.argv[2])
s, n = re.subn(r"^sha256sums=\([^)]*\)", new, s, count=1, flags=re.M)
if n != 1:
	sys.exit(1)
open(p, "w", encoding="utf-8").write(s)
PY
rm -f PKGBUILD.bak
bash -n PKGBUILD || die "PKGBUILD invalide après réécriture"

# --- .SRCINFO ---------------------------------------------------------------------------
srcinfo_internal() { # même format que makepkg --printsrcinfo (pacman 6) pour ce PKGBUILD
	(
		set +u
		# shellcheck disable=SC1091
		source ./PKGBUILD
		kv() { local k="$1"; shift; local v; for v in "$@"; do printf '\t%s = %s\n' "$k" "$v"; done; }
		printf 'pkgbase = %s\n' "$pkgname"
		kv pkgdesc "$pkgdesc"; kv pkgver "$pkgver"; kv pkgrel "$pkgrel"; kv url "$url"
		kv arch "${arch[@]}"; kv license "${license[@]}"
		kv depends "${depends[@]}"; kv optdepends "${optdepends[@]}"
		kv provides "${provides[@]}"; kv conflicts "${conflicts[@]}"; kv options "${options[@]}"
		kv source "${source[@]}"; kv sha256sums "${sha256sums[@]}"
		printf '\npkgname = %s\n' "$pkgname"
	)
}
if command -v makepkg >/dev/null 2>&1 && [[ "$(id -u)" != "0" ]]; then
	makepkg --printsrcinfo > .SRCINFO
	echo "-- .SRCINFO : makepkg --printsrcinfo"
else
	srcinfo_internal > .SRCINFO
	echo "-- .SRCINFO : générateur interne (makepkg absent ou root)"
fi

echo "== clearance-bin $VERSION-$PKGREL prêt dans ${PKG_DIR#"$ROOT"/} :"
echo "   $ARCHIVE  sha256 $SUM"
echo "   publier : packaging/aur/README.md (git clone ssh://aur@aur.archlinux.org/clearance-bin.git)"
