#!/usr/bin/env bash
# CLEARANCE M16 (lot C) — pilote d'intégration du client en ligne contre un
# PocketBase LOCAL jetable (tools/online_dev_server.sh, mode dev OTP).
# Serveur et pilote dans une seule commande ; données et user:// jetables
# (jamais le vrai user://, jamais le serveur de production).
#   bash tests/qa_drivers/qa_m16_online_live.sh [journal] [port]
# Sortie : 0 si toutes les étapes passent (lignes « M16LIVE … » du journal).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG="${1:-$(mktemp -t m16live.XXXX.log)}"
PORT="${2:-8097}"
WORK="$(mktemp -d -t m16live.XXXX)"
cleanup() {
	[[ -n "${PB_PID:-}" ]] && kill "$PB_PID" 2>/dev/null
	wait 2>/dev/null
	rm -rf "$WORK"
}
trap cleanup EXIT
cd "$ROOT"
bash tools/online_dev_server.sh --port "$PORT" --data "$WORK/pb_data" --fresh >"$WORK/pb.log" 2>&1 &
PB_PID=$!
for _ in $(seq 1 60); do
	curl -sf "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1 && break
	sleep 1
done
if ! curl -sf "http://127.0.0.1:$PORT/api/health" >/dev/null 2>&1; then
	echo "PocketBase local injoignable (voir $WORK/pb.log)" >&2
	cat "$WORK/pb.log" >&2
	exit 2
fi
mkdir -p "$WORK/xdg"
XDG_DATA_HOME="$WORK/xdg" timeout 300 godot --headless --path . --script res://tools/qa_boot.gd -- \
	--qa-node=res://tests/qa_drivers/qa_m16_online_live.gd --online-url="http://127.0.0.1:$PORT" >"$LOG" 2>&1
code=$?
grep -E "^M16LIVE" "$LOG"
echo "journal : $LOG"
exit $code
