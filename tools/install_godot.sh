#!/bin/bash
# Installe Godot à la version figée du projet (voir DECISIONS.md D-003).
# GUT 9.7.1 est versionné dans addons/gut : rien à cloner.
# Usage : bash tools/install_godot.sh [--templates | --templates-only]   (Linux x86_64)
#   (sans option) : éditeur dans /opt/godot + lien /usr/local/bin/godot (droits root)
#   --templates      : éditeur + modèles d'export 4.7.2-stable dans
#                      ${XDG_DATA_HOME:-~/.local/share}/godot/export_templates/4.7.2.stable/
#                      (requis par tools/export_all.sh, ARCHITECTURE §16)
#   --templates-only : modèles seulement, sans root (CI : à lancer sans sudo
#                      pour que le dossier appartienne à l'utilisateur)
set -e
GODOT_VER=4.7.2-stable
# Official builds mirror first (godotengine/godot-builds), main repo as fallback.
MIRRORS=(
	"https://github.com/godotengine/godot-builds/releases/download/${GODOT_VER}"
	"https://github.com/godotengine/godot/releases/download/${GODOT_VER}"
)

# fetch <file name> <destination>: first mirror that answers with a real zip wins.
fetch() {
	local base
	for base in "${MIRRORS[@]}"; do
		if curl -fsSL --retry 3 --retry-delay 5 -o "$2" "${base}/$1" && unzip -tq "$2" >/dev/null 2>&1; then
			return 0
		fi
		echo "échec du téléchargement depuis ${base}, essai suivant" >&2
	done
	echo "impossible de télécharger $1" >&2
	return 1
}

if [[ "${1:-}" != "--templates-only" ]]; then
	mkdir -p /opt/godot && cd /opt/godot
	fetch "Godot_v${GODOT_VER}_linux.x86_64.zip" godot.zip
	unzip -qo godot.zip && rm godot.zip
	ln -sf "/opt/godot/Godot_v${GODOT_VER}_linux.x86_64" /usr/local/bin/godot
fi

if [[ "${1:-}" == "--templates" || "${1:-}" == "--templates-only" ]]; then
	TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VER/-/.}"
	TMP="$(mktemp -d)"
	fetch "Godot_v${GODOT_VER}_export_templates.tpz" "$TMP/templates.tpz"
	unzip -q "$TMP/templates.tpz" -d "$TMP"
	mkdir -p "$TPL_DIR"
	cp -r "$TMP/templates/." "$TPL_DIR/"
	rm -rf "$TMP"
	echo "Modèles d'export : $TPL_DIR ($(cat "$TPL_DIR/version.txt"))"
fi

if command -v godot >/dev/null; then godot --version; fi
