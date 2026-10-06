#!/bin/bash

# omarchy:summary=Enable, disable or toggle Omarchy Mac Mode
# omarchy:examples=omarchy-mac-toggle [on|off|status|toggle]

set -euo pipefail

MAC_DIR="$HOME/.config/omarchy-mac"
STATE_DIR="$HOME/.local/state/omarchy-mac"
STATE_FILE="$STATE_DIR/enabled"
SHELL_CFG="$HOME/.config/omarchy/shell.json"
SHELL_MAC="$MAC_DIR/shell/shell.json"
BACKUP_DIR="$MAC_DIR/backup"
PRE_SHELL="$BACKUP_DIR/shell.json.pre-mac"
PRE_HYPR="$BACKUP_DIR/hyprland.lua.pre-mac"

ON_THEME="mac-dark"
OFF_THEME="catppuccin"

mkdir -p "$STATE_DIR" "$BACKUP_DIR"

usage() {
  cat <<EOF
Usage: $(basename "$0") [on|off|status|toggle]

  on       Enable Mac Mode (Mac bar layout, mac-dark theme, Mac bindings)
  off      Disable Mac Mode (restore stock Omarchy shell + catppuccin)
  status   Show current state
  toggle   Flip the current state
EOF
}

state() {
  if [[ -f $STATE_FILE ]]; then
    cat "$STATE_FILE"
  else
    echo 1
  fi
}

backup_once() {
  if [[ ! -f $PRE_SHELL && -f $SHELL_CFG ]]; then
    cp "$SHELL_CFG" "$PRE_SHELL"
  fi
  if [[ ! -f $PRE_HYPR && -f "$HOME/.config/hypr/hyprland.lua" ]]; then
    cp "$HOME/.config/hypr/hyprland.lua" "$PRE_HYPR"
  fi
}

enable_mac_mode() {
  backup_once
  [[ -f $SHELL_MAC ]] || { echo "Missing $SHELL_MAC" >&2; exit 1; }
  cp "$SHELL_MAC" "$SHELL_CFG"
  echo 1 > "$STATE_FILE"
  omarchy theme set "$ON_THEME" >/dev/null
  hyprctl reload >/dev/null 2>&1 || true
  echo "Mac Mode: ON (theme: $ON_THEME, Mac bar layout applied)"
}

disable_mac_mode() {
  if [[ -f $PRE_SHELL ]]; then
    cp "$PRE_SHELL" "$SHELL_CFG"
  fi
  echo 0 > "$STATE_FILE"
  omarchy theme set "$OFF_THEME" >/dev/null
  hyprctl reload >/dev/null 2>&1 || true
  echo "Mac Mode: OFF (stock shell restored, theme: $OFF_THEME)"
}

status_mac_mode() {
  local s theme
  s=$(state)
  theme=$(omarchy theme current 2>/dev/null || echo unknown)
  if [[ $s == 1 ]]; then
    echo "Mac Mode: ON"
  else
    echo "Mac Mode: OFF"
  fi
  echo "Theme: $theme"
  echo "Hyprland Mac modules: $(grep -q 'omarchy-mac.hyprland.mac-mode' "$HOME/.config/hypr/hyprland.lua" 2>/dev/null && echo wired || echo not-wired)"
}

main() {
  case "${1:-}" in
    on) enable_mac_mode ;;
    off) disable_mac_mode ;;
    status) status_mac_mode ;;
    toggle)
      if [[ $(state) == 1 ]]; then disable_mac_mode; else enable_mac_mode; fi
      ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
