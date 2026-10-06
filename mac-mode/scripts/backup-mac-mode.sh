#!/bin/bash

# Omarchy Mac Mode Backup Script
# Backs up all Mac Mode customizations

set -euo pipefail

BACKUP_DIR="$HOME/.config/omarchy-mac/backup/$(date +%Y%m%d-%H%M%S)"
OMARCHY_MAC_DIR="$HOME/.config/omarchy-mac"

mkdir -p "$BACKUP_DIR"

echo "Backing up Mac Mode configuration to $BACKUP_DIR"

# Backup omarchy-mac directory (except backup subdir)
rsync -av --exclude='backup' "$OMARCHY_MAC_DIR/" "$BACKUP_DIR/omarchy-mac/"

# Backup Hyprland config
cp "$HOME/.config/hypr/hyprland.lua" "$BACKUP_DIR/hyprland.lua" 2>/dev/null || true
cp -r "$HOME/.config/hypr/" "$BACKUP_DIR/hypr/" 2>/dev/null || true

# Backup Omarchy shell config
cp "$HOME/.config/omarchy/shell.json" "$BACKUP_DIR/shell.json" 2>/dev/null || true
cp -r "$HOME/.config/omarchy/" "$BACKUP_DIR/omarchy/" 2>/dev/null || true

# Backup Quickshell config if exists
if [[ -d "$HOME/.config/quickshell" ]]; then
  cp -r "$HOME/.config/quickshell/" "$BACKUP_DIR/quickshell/" 2>/dev/null || true
fi

# Create manifest
cat > "$BACKUP_DIR/MANIFEST.txt" <<EOF
Omarchy Mac Mode Backup
Date: $(date)
Host: $(hostname)
Omarchy Version: $(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | tr -d '"')
Hyprland Version: $(hyprctl version | head -1)
Quickshell Version: $(quickshell --version 2>/dev/null || echo "not found")

Contents:
- omarchy-mac/         : Mac Mode configuration
- hyprland.lua         : Hyprland main config
- hypr/                : Full Hyprland config directory
- shell.json           : Omarchy shell config
- omarchy/             : Full Omarchy config directory
EOF

echo "Backup complete: $BACKUP_DIR"
echo "Manifest written to $BACKUP_DIR/MANIFEST.txt"