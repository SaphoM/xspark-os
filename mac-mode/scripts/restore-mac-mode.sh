#!/bin/bash

# Omarchy Mac Mode Restore Script
# Restores Mac Mode from a backup

set -euo pipefail

OMARCHY_MAC_DIR="$HOME/.config/omarchy-mac"
BACKUP_BASE="$OMARCHY_MAC_DIR/backup"

usage() {
  cat <<EOF
Usage: $(basename "$0") [backup_timestamp]

Omarchy Mac Mode Restore

Arguments:
  backup_timestamp    Timestamp of backup to restore (YYYYMMDD-HHMMSS)
                      If omitted, lists available backups.

Examples:
  $(basename "$0")                    # List available backups
  $(basename "$0") 20241219-143000    # Restore specific backup

EOF
}

list_backups() {
  echo "Available backups:"
  ls -1 "$BACKUP_BASE" 2>/dev/null | while read -r dir; do
    if [[ -f "$BACKUP_BASE/$dir/MANIFEST.txt" ]]; then
      echo "  $dir"
      head -3 "$BACKUP_BASE/$dir/MANIFEST.txt" | tail -2 | sed 's/^/    /'
    else
      echo "  $dir (no manifest)"
    fi
  done
}

restore_backup() {
  local timestamp="$1"
  local backup_dir="$BACKUP_BASE/$timestamp"

  if [[ ! -d "$backup_dir" ]]; then
    echo "Error: Backup not found: $backup_dir"
    exit 1
  fi

  echo "Restoring from $backup_dir"

  # Confirm
  read -p "This will overwrite current Mac Mode config. Continue? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi

  # Restore omarchy-mac
  if [[ -d "$backup_dir/omarchy-mac" ]]; then
    rsync -av --delete "$backup_dir/omarchy-mac/" "$OMARCHY_MAC_DIR/" --exclude='backup'
  fi

  # Restore Hyprland config
  if [[ -f "$backup_dir/hyprland.lua" ]]; then
    cp "$backup_dir/hyprland.lua" "$HOME/.config/hypr/hyprland.lua"
  fi

  # Restore Omarchy shell config
  if [[ -f "$backup_dir/shell.json" ]]; then
    cp "$backup_dir/shell.json" "$HOME/.config/omarchy/shell.json"
  fi

  # Reload Hyprland
  hyprctl reload 2>/dev/null || true

  echo "Restore complete from $timestamp"
  echo "Reload Hyprland (SUPER+SHIFT+R) or re-login to apply fully"
}

main() {
  case "${1:-}" in
    "") list_backups ;;
    *) restore_backup "$1" ;;
  esac
}

main "$@"