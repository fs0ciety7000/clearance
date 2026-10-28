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
BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VER}"

if [[ "${1:-}" != "--templates-only" ]]; then
	mkdir -p /opt/godot && cd /opt/godot
	curl -sSL -o godot.zip "${BASE_URL}/Godot_v${GODOT_VER}_linux.x86_64.zip"
	unzip -qo godot.zip && rm godot.zip
	ln -sf "/opt/godot/Godot_v${GODOT_VER}_linux.x86_64" /usr/local/bin/godot
fi

if [[ "${1:-}" == "--templates" || "${1:-}" == "--templates-only" ]]; then
	TPL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/${GODOT_VER/-/.}"
	TMP="$(mktemp -d)"
	curl -sSL -o "$TMP/templates.tpz" "${BASE_URL}/Godot_v${GODOT_VER}_export_templates.tpz"
	unzip -q "$TMP/templates.tpz" -d "$TMP"
	mkdir -p "$TPL_DIR"
	cp -r "$TMP/templates/." "$TPL_DIR/"
	rm -rf "$TMP"
	echo "Modèles d'export : $TPL_DIR ($(cat "$TPL_DIR/version.txt"))"
fi

if command -v godot >/dev/null; then godot --version; fi
