# shellcheck shell=bash
# Fonctions communes aux scripts tools/package_*.sh (ARCHITECTURE §16.9).
# À sourcer après avoir défini SCRIPT_NAME ; exige bash.
#
# Définit : ROOT, DIST, VERSION, DEMO (0/1), APP (CLEARANCE / CLEARANCE-Demo),
# ARCHIVE_TAG ("" / "demo-"), die(), sha_line().
# Variables d'entrée : VERSION (sinon application/config/version de project.godot),
# arguments : [--demo].

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST="${DIST:-$ROOT/build/dist}"

die() { echo "$SCRIPT_NAME: ERREUR : $*" >&2; exit 1; }

DEMO=0
for arg in "$@"; do
	case "$arg" in
		--demo) DEMO=1 ;;
		-h|--help) sed -n '2,/^set -euo/p' "$0" | sed '$d'; exit 0 ;;
		*) die "argument inconnu : $arg (seul --demo est accepté)" ;;
	esac
done

if [[ -z "${VERSION:-}" ]]; then
	VERSION="$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")"
fi
[[ -n "$VERSION" ]] || die "version introuvable (project.godot ou VERSION=…)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.+~-][0-9A-Za-z.]+)?$ ]] || die "version invalide : $VERSION"

if [[ $DEMO -eq 1 ]]; then
	APP="CLEARANCE-Demo"; ARCHIVE_TAG="demo-"
else
	APP="CLEARANCE"; ARCHIVE_TAG=""
fi

# Dates figées (reproductibilité) : celles de export_all.sh.
SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git -C "$ROOT" log -1 --format=%ct 2>/dev/null || date +%s)}"
export SOURCE_DATE_EPOCH

# Empreinte affichée en fin de script (la CI écrit SHA256SUMS-installers).
sha_line() { (cd "$(dirname "$1")" && shasum -a 256 "$(basename "$1")" 2>/dev/null || sha256sum "$(basename "$1")"); }
