#!/bin/bash
# Installe Godot et GUT (tests) aux versions figées du projet (voir DECISIONS.md D-003).
# Usage : bash tools/install_godot.sh   (Linux x86_64)
set -e
GODOT_VER=4.7.2-stable
GUT_VER=v9.7.1

mkdir -p /opt/godot && cd /opt/godot
curl -sSL -o godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip"
unzip -qo godot.zip && rm godot.zip
ln -sf "/opt/godot/Godot_v${GODOT_VER}_linux.x86_64" /usr/local/bin/godot

rm -rf /opt/gut
git clone -q --depth 1 --branch "${GUT_VER}" https://github.com/bitwes/Gut.git /opt/gut

godot --version
