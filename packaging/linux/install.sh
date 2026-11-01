#!/bin/sh
# CLEARANCE — installation pour l'utilisateur courant, sans root.
# CLEARANCE — per-user install, no root required.
#
# Usage, depuis le dossier extrait de l'archive / from the extracted folder:
#   ./install.sh          copie le jeu dans ~/.local/share/clearance/ puis ajoute
#                         le lanceur (menu des applications), les icônes et la
#                         commande ~/.local/bin/clearance
#                         (copies the game, adds the menu entry, icons and command)
#   ./install.sh --here   laisse le jeu dans ce dossier (ne pas le déplacer ensuite)
#                         (keeps the game where it is; do not move the folder)
# Désinstaller / uninstall: ./uninstall.sh   (les sauvegardes sont conservées /
# saves are kept: ~/.local/share/godot/app_userdata/CLEARANCE/)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
MODE=copy
for arg in "$@"; do
	case "$arg" in
		--here) MODE=here ;;
		-h|--help) sed -n '2,14p' "$0"; exit 0 ;;
		*) echo "install.sh : option inconnue / unknown option: $arg" >&2; exit 2 ;;
	esac
done

if [ "$(id -u)" = "0" ]; then
	echo "install.sh : ne pas lancer en root / do not run as root (installation par utilisateur / per-user install)." >&2
	exit 1
fi

# Jeu complet ou démo (même archive, binaire différent) / full game or demo.
BIN=""
for b in CLEARANCE.x86_64 CLEARANCE.arm64 CLEARANCE-Demo.x86_64; do
	if [ -f "$HERE/$b" ]; then BIN=$b; break; fi
done
[ -n "$BIN" ] || { echo "install.sh : binaire CLEARANCE introuvable dans $HERE / game binary not found" >&2; exit 1; }
case "$BIN" in
	CLEARANCE-Demo.*) ID=clearance-demo; NAME="CLEARANCE Demo" ;;
	*) ID=clearance; NAME="CLEARANCE" ;;
esac

DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
BIN_DIR="$HOME/.local/bin"
MARKER=".installed-by-clearance"

if [ "$MODE" = copy ]; then
	GAME_DIR="$DATA/$ID"
	if [ "$HERE" != "$GAME_DIR" ]; then
		if [ -e "$GAME_DIR" ] && [ ! -f "$GAME_DIR/$MARKER" ]; then
			echo "install.sh : $GAME_DIR existe et n'a pas été créé par ce script / exists and was not created by this script." >&2
			exit 1
		fi
		rm -rf "$GAME_DIR"
		mkdir -p "$GAME_DIR"
		cp -R "$HERE/." "$GAME_DIR/"
		: > "$GAME_DIR/$MARKER"
	fi
else
	GAME_DIR="$HERE"
fi
chmod 0755 "$GAME_DIR/$BIN" "$GAME_DIR/install.sh" "$GAME_DIR/uninstall.sh" 2>/dev/null || true

# Icônes / icons (hicolor : 16 → 512 px + SVG).
if [ -d "$HERE/icons/hicolor" ]; then
	for src in "$HERE"/icons/hicolor/*/apps/clearance.*; do
		size_dir=$(basename "$(dirname "$(dirname "$src")")")
		ext=${src##*.}
		mkdir -p "$DATA/icons/hicolor/$size_dir/apps"
		cp "$src" "$DATA/icons/hicolor/$size_dir/apps/$ID.$ext"
	done
fi

# Commande / command: ~/.local/bin/<id>
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/$ID" <<EOF
#!/bin/sh
# $NAME launcher (installed by install.sh)
exec "$GAME_DIR/$BIN" "\$@"
EOF
chmod 0755 "$BIN_DIR/$ID"

# Lanceur / desktop entry.
mkdir -p "$DATA/applications"
DESKTOP="$DATA/applications/$ID.desktop"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=$NAME
GenericName=Identity control game
GenericName[fr]=Jeu de contrôle d'identité
Comment=Identity control at the gate of a corporate orbital station
Comment[fr]=Contrôle d'identité à l'entrée d'une station orbitale corporative
Exec="$GAME_DIR/$BIN"
Path=$GAME_DIR
Icon=$ID
Terminal=false
Categories=Game;Simulation;
Keywords=papers;border;identity;space;station;
Keywords[fr]=papiers;frontière;identité;espace;station;
StartupWMClass=CLEARANCE
PrefersNonDefaultGPU=true
EOF
chmod 0644 "$DESKTOP"

command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q "$DATA/applications" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t "$DATA/icons/hicolor" 2>/dev/null || true

echo "$NAME installé / installed:"
echo "  jeu / game      : $GAME_DIR"
echo "  lanceur / entry : $DESKTOP"
echo "  commande        : $BIN_DIR/$ID"
case ":$PATH:" in
	*":$BIN_DIR:"*) ;;
	*) echo "  (ajoutez / add $BIN_DIR à votre PATH pour lancer « $ID » depuis un terminal)" ;;
esac
echo "Désinstaller / uninstall: $GAME_DIR/uninstall.sh"
