#!/bin/bash
# Stress D-083 du moteur musical M14 (docs/AUDIO.md §13.6, docs/M14.md M-17).
# Lance tools/qa_audio_stress.gd (via qa_boot) dans un user:// jetable et
# résume le journal : plantages (signal 11), fuites (« leaked », « still in
# use »), « Playback can only happen… », SCRIPT ERROR.
# Usage : bash tools/qa_audio_stress.sh <journal> [arguments utilisateur…]
#   ex. bash tools/qa_audio_stress.sh /tmp/r1.log --qa-stress=reload --qa-reloads=1000 --autoplay --day=7 --seed=3
# Variables : GODOT (défaut godot), STRESS_TIMEOUT (s, défaut 3000),
# STRESS_VERBOSE=1 (--verbose : détail des objets en cas de fuite à la sortie).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot}"
LOG="$1"; shift
DATA="$(mktemp -d)"
start=$(date +%s)
XDG_DATA_HOME="$DATA" timeout "${STRESS_TIMEOUT:-3000}" "$GODOT" --headless ${STRESS_VERBOSE:+--verbose} --path "$ROOT" \
  --script res://tools/qa_boot.gd -- --qa-node=res://tools/qa_audio_stress.gd "$@" >"$LOG" 2>&1
code=$?
end=$(date +%s)
rm -rf "$DATA"
crash=$(grep -c -E "handle_crash|signal 11|Program crashed" "$LOG")
leaked=$(grep -c -E "leaked|still in use" "$LOG")
playback=$(grep -c "Playback can only happen" "$LOG")
script_err=$(grep -c "SCRIPT ERROR" "$LOG")
done_line=$(grep "QA_STRESS_DONE\|QA_END" "$LOG" | tail -1)
last=$(grep "QA_STRESS " "$LOG" | tail -1)
echo "QA_AUDIO_STRESS exit=$code secs=$((end - start)) crash=$crash leaked=$leaked playback=$playback script_errors=$script_err"
echo "  ${done_line:-$last}"
