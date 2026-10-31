#!/usr/bin/env bash
# Smoke de la démo J1–J5 (M15 lot A, D-215) — après `bash tools/export_all.sh --demo linux`.
#
# 1. Binaire RELEASE de la démo (build/demo-linux) : écran titre en headless,
#    300 images ; la ligne « main: démo J1–J5 (données : user://demo/saves) »
#    est exigée (fonctionnalité « demo » bien embarquée, sauvegardes séparées).
# 2. Même binaire, langue anglaise forcée par le réglage (settings.cfg
#    `language="en"` dans le dossier utilisateur isolé) : démarrage sans erreur
#    (traduction anglaise embarquée).
# 3. Aucun fichier écrit dans user://saves (jeu complet) : seulement user://demo/.
# Échec si une ligne ERROR / SCRIPT ERROR apparaît. Données utilisateur isolées
# dans build/smoke-demo/xdg (jamais le vrai user://).
#
# Usage : bash tools/smoke_demo.sh     (GODOT inutile : le binaire exporté suffit)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE="$ROOT/build/smoke-demo"
BIN="$ROOT/build/demo-linux/CLEARANCE-Demo.x86_64"

die() { echo "smoke_demo: ERREUR : $*" >&2; exit 1; }
[[ -x "$BIN" ]] || die "$BIN absent : lancer d'abord bash tools/export_all.sh --demo linux"

rm -rf "$SMOKE" && mkdir -p "$SMOKE/xdg"
export XDG_DATA_HOME="$SMOKE/xdg"
USERDIR="$SMOKE/xdg/godot/app_userdata/CLEARANCE"

run() { # $1 nom du journal ; reste : arguments
	local log="$SMOKE/$1.log"; shift
	local rc=0
	timeout 120 "$BIN" --headless --quit-after 300 "$@" >"$log" 2>&1 || rc=$?
	sed -i 's/\x1b\[[0-9;]*m//g' "$log"
	[[ $rc -eq 0 ]] || { tail -20 "$log" >&2; die "$1 : code de sortie $rc"; }
	if grep -E "^(SCRIPT )?ERROR" "$log" | grep -vq "leaked at exit\|resources still in use at exit"; then
		grep -E -A2 "^(SCRIPT )?ERROR" "$log" >&2
		die "$1 : erreur dans le journal ($log)"
	fi
}

echo "-- titre (démo, FR)"
run title_fr
grep -q "main: démo J1–J5 (données : user://demo/saves)" "$SMOKE/title_fr.log" || die "fonctionnalité « demo » absente du paquet"

echo "-- titre (démo, EN)"
mkdir -p "$USERDIR"
printf '[settings]\n\nlanguage="en"\n' > "$USERDIR/settings.cfg"
run title_en
grep -q 'language="en"' "$USERDIR/settings.cfg" || die "réglage de langue perdu"

echo "-- sauvegardes séparées"
[[ ! -e "$USERDIR/saves" ]] || die "la démo a écrit dans user://saves"
echo "smoke_demo: OK"
