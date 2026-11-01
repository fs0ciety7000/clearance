#!/bin/sh
# CLEARANCE — désinstallation pour l'utilisateur courant (inverse de install.sh).
# CLEARANCE — per-user uninstall (reverts install.sh).
#
# Usage : ./uninstall.sh [--demo]
# Retire le lanceur, les icônes, la commande ~/.local/bin/<id> et le dossier
# copié par install.sh (~/.local/share/<id>/, seulement s'il porte la marque
# .installed-by-clearance). Un dossier installé avec --here n'est pas supprimé.
# Les sauvegardes sont CONSERVÉES / saves are KEPT:
#   ~/.local/share/godot/app_userdata/CLEARANCE/
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
ID=clearance
[ -f "$HERE/CLEARANCE-Demo.x86_64" ] && ID=clearance-demo
for arg in "$@"; do
	case "$arg" in
		--demo) ID=clearance-demo ;;
		-h|--help) sed -n '2,11p' "$0"; exit 0 ;;
		*) echo "uninstall.sh : option inconnue / unknown option: $arg" >&2; exit 2 ;;
	esac
done

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"

rm -f "$DATA/applications/$ID.desktop"
for f in "$DATA"/icons/hicolor/*/apps/"$ID".png "$DATA"/icons/hicolor/*/apps/"$ID".svg; do
	[ -f "$f" ] && rm -f "$f"
done
if [ -f "$BIN_DIR/$ID" ] && grep -q "installed by install.sh" "$BIN_DIR/$ID"; then
	rm -f "$BIN_DIR/$ID"
fi
if [ -f "$DATA/$ID/.installed-by-clearance" ]; then
	rm -rf "${DATA:?}/$ID"
fi

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true

echo "$ID désinstallé / uninstalled (sauvegardes conservées / saves kept: $DATA/godot/app_userdata/CLEARANCE/)."
