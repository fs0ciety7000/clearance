#!/bin/bash
# Installe Godot à la version figée du projet (voir DECISIONS.md D-003).
# GUT 9.7.1 est versionné dans addons/gut : rien à cloner.
# Usage : bash tools/install_godot.sh   (Linux x86_64)
set -e
GODOT_VER=4.7.2-stable

mkdir -p /opt/godot && cd /opt/godot
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
unzip -qo godot.zip && rm godot.zip
ln -sf "/opt/godot/Godot_v${GODOT_VER}_linux.x86_64" /usr/local/bin/godot

godot --version
