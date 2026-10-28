#!/usr/bin/env bash
# Smoke test des exports Linux (ARCHITECTURE §16.8) — après tools/export_all.sh.
#
# 1. Binaire RELEASE (build/linux) : écran titre en headless, 300 images.
# 2. Export DEBUG temporaire (build/smoke/debug) lancé directement sur la scène
#    de jour (override.cfg à côté du binaire : un binaire exporté refuse un
#    chemin de scène en ligne de commande) avec les arguments de debug
#    `--day=N --seed=3 --autoplay` (booth 3D compris) pour J1, J4, J7, J10,
#    J15 et J20 (Acte II : quota, couvre-feu, révocations, dernier jour).
#    Détecte ce que la suite GUT ne voit pas : ressources mal converties à
#    l'export, fichiers non embarqués, traduction absente…
# Échec si une ligne ERROR / SCRIPT ERROR apparaît (hors fuites signalées à la
# sortie forcée par --quit-after). Données utilisateur isolées dans build/smoke/.
#
# Usage : bash tools/smoke_export.sh     (GODOT=… pour un autre binaire)
set -euo pipefail

GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMOKE="$ROOT/build/smoke"
RELEASE_BIN="$ROOT/build/linux/CLEARANCE.x86_64"

die() { echo "smoke_export: ERREUR : $*" >&2; exit 1; }
[[ -x "$RELEASE_BIN" ]] || die "$RELEASE_BIN absent : lancer d'abord bash tools/export_all.sh linux"

rm -rf "$SMOKE" && mkdir -p "$SMOKE/debug" "$SMOKE/xdg"

# run <libellé> <dossier> <args…> : lance le binaire, filtre les erreurs.
run() {
	local label="$1" dir="$2"; shift 2
	local log="$SMOKE/$label.log"
	local rc=0
	(cd "$dir" && XDG_DATA_HOME="$SMOKE/xdg" timeout 600 ./CLEARANCE.x86_64 --headless "$@") >"$log" 2>&1 || rc=$?
	local errors
	errors="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E "^(SCRIPT )?ERROR" | grep -v "resources still in use at exit" || true)"
	if [[ $rc -ne 0 || -n "$errors" ]]; then
		echo "$errors" | sort | uniq -c | sort -rn | head -10 >&2
		die "$label : code $rc (journal : ${log#"$ROOT"/})"
	fi
	echo "   OK  $label"
}

echo "== smoke test des exports Linux"
run release_title "$ROOT/build/linux" --quit-after 300

"$GODOT" --headless --path "$ROOT" --export-debug "Linux" "$SMOKE/debug/CLEARANCE.x86_64" >"$SMOKE/export_debug.log" 2>&1 \
	|| die "export debug en échec (journal : build/smoke/export_debug.log)"
printf '[application]\n\nrun/main_scene="res://scenes/main/day.tscn"\n' > "$SMOKE/debug/override.cfg"
for day in 1 4 7 10 15 20; do
	run "debug_day$day" "$SMOKE/debug" --quit-after 2000 -- --day="$day" --seed=3 --autoplay
done
rm -rf "$SMOKE/debug" "$SMOKE/xdg"
echo "== smoke test OK (journaux dans build/smoke/)"
