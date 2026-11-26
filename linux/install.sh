#!/usr/bin/env bash
set -euo pipefail

# Installs the Spellchord Linux bundle for the current user (~/.local)
# so it appears in the desktop application menu with its icon.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/spellchord"
BIN_DIR="$HOME/.local/bin"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
APP_DIR="$HOME/.local/share/applications"

if [[ ! -f "$SCRIPT_DIR/harmonic_explorer" ]]; then
  echo "Error: Run this script from inside the extracted Spellchord-Linux-x64 folder."
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$ICON_DIR" "$APP_DIR"

rm -rf "$INSTALL_DIR"/*
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/harmonic_explorer"

if [[ -f "$INSTALL_DIR/data/flutter_assets/assets/icon/app_icon.png" ]]; then
  cp "$INSTALL_DIR/data/flutter_assets/assets/icon/app_icon.png" "$ICON_DIR/spellchord.png"
fi

ln -sf "$INSTALL_DIR/harmonic_explorer" "$BIN_DIR/spellchord"

cat > "$APP_DIR/spellchord.desktop" <<EOF
[Desktop Entry]
Name=Spellchord
Comment=Harmonic & Modal Explorer
Exec=$INSTALL_DIR/harmonic_explorer
Icon=spellchord
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Education;
StartupWMClass=harmonic_explorer
EOF

chmod +x "$APP_DIR/spellchord.desktop"
update-desktop-database "$APP_DIR" 2>/dev/null || true

echo "Spellchord installed successfully!"
echo "  - Launch from your application menu (search 'Spellchord')"
echo "  - Or run: $BIN_DIR/spellchord"
