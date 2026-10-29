#!/usr/bin/env bash
# Smoke test des exports Linux (ARCHITECTURE §16.8) — après tools/export_all.sh.
#
# 1. Binaire RELEASE (build/linux) : écran titre en headless, 300 images.
# 2. Export DEBUG temporaire (build/smoke/debug) lancé directement sur la scène
#    de jour (override.cfg à côté du binaire : un binaire exporté refuse un
#    chemin de scène en ligne de commande) avec les arguments de debug
#    `--day=N --seed=3 --autoplay` (booth 3D compris) pour J1, J4, J7, J10,
#    J15, J20 (Acte II : quota, couvre-feu, révocations, pivot), J25 et J30
#    (Acte III : répondants, lock-out, dernier jour).
#    Détecte ce que la suite GUT ne voit pas : ressources mal converties à
#    l'export, fichiers non embarqués, traduction absente…
# 3. M12 : une Garde de nuit courte (`--garde=CODE`, 8 passagers jugés dont
#    3 faux : directive n° 1, puis FIN DE GARDE) et un J31 par clé d'épilogue
#    (`--epilogue=<fin>`, 7 passagers jugés puis conclusion).
# Échec si une ligne ERROR / SCRIPT ERROR apparaît (hors fuites signalées à la
# sortie forcée par --quit-after). Données utilisateur isolées dans build/smoke/.
#
# Usage : bash tools/smoke_export.sh [--garde=CODE] [--epilogue=<fin>]…
#   --garde=CODE      code de la Garde (défaut K2Q-9TX ; --garde seul = défaut)
#   --epilogue=<fin>  fin d'où part le J31 (répétable ; défaut f10_pont et
#                     f6_drift : mondes C et D) — ex. --epilogue=f9_strike
#   --no-m12          campagne seule (comportement d'avant M12)
#   GODOT=… pour un autre binaire.
set -euo pipefail

GARDE_CODE="K2Q-9TX"
EPILOGUES=()
WITH_M12=1
for arg in "$@"; do
	case "$arg" in
		--garde) ;;
		--garde=*) GARDE_CODE="${arg#--garde=}" ;;
		--epilogue=*) EPILOGUES+=("${arg#--epilogue=}") ;;
		--no-m12) WITH_M12=0 ;;
		*) echo "smoke_export: argument inconnu : $arg" >&2; exit 2 ;;
	esac
done
[[ ${#EPILOGUES[@]} -gt 0 ]] || EPILOGUES=(f10_pont f6_drift)

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
for day in 1 4 7 10 15 20 25 30; do
	run "debug_day$day" "$SMOKE/debug" --quit-after 2000 -- --day="$day" --seed=3 --autoplay
done
if [[ $WITH_M12 -eq 1 ]]; then
	run "debug_garde" "$SMOKE/debug" --quit-after 900 -- --garde="$GARDE_CODE" --skip-cases=8 --wrong-cases=3
	for ending in "${EPILOGUES[@]}"; do
		run "debug_epilogue_$ending" "$SMOKE/debug" --quit-after 900 -- --epilogue="$ending" --skip-cases=7
	done
fi
rm -rf "$SMOKE/debug" "$SMOKE/xdg"
echo "== smoke test OK (journaux dans build/smoke/)"
