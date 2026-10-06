#!/bin/bash

# Omarchy Mac Mode Validation Script
# Runs comprehensive tests to verify Mac Mode is working

set -euo pipefail

OMARCHY_MAC_DIR="$HOME/.config/omarchy-mac"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS+1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL+1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

test_config_exists() {
  local file="$1"
  local desc="$2"
  if [[ -f "$file" ]]; then
    pass "$desc exists: $file"
  else
    fail "$desc missing: $file"
  fi
}

test_dir_exists() {
  local dir="$1"
  local desc="$2"
  if [[ -d "$dir" ]]; then
    pass "$desc exists: $dir"
  else
    fail "$desc missing: $dir"
  fi
}

test_executable() {
  local file="$1"
  local desc="$2"
  if [[ -x "$file" ]]; then
    pass "$desc executable: $file"
  else
    fail "$desc not executable: $file"
  fi
}

test_theme() {
  local theme="$1"
  local theme_file="/usr/share/omarchy/themes/$theme/colors.toml"
  if [[ ! -f "$theme_file" ]]; then
    theme_file="$HOME/.config/omarchy/themes/$theme/colors.toml"
  fi
  if [[ -f "$theme_file" ]]; then
    pass "Theme $theme installed"
  else
    fail "Theme $theme not found"
  fi
}

main() {
  echo "=========================================="
  echo "  Omarchy Mac Mode Validation"
  echo "=========================================="
  echo

  info "Checking directory structure..."
  test_dir_exists "$OMARCHY_MAC_DIR" "Mac Mode root"
  test_dir_exists "$OMARCHY_MAC_DIR/theme" "Themes directory"
  test_dir_exists "$OMARCHY_MAC_DIR/hyprland" "Hyprland config"
  test_dir_exists "$OMARCHY_MAC_DIR/shell" "Shell config"
  test_dir_exists "$OMARCHY_MAC_DIR/scripts" "Scripts directory"

  echo
  info "Checking theme files..."
  test_theme "mac-dark"
  test_theme "mac-light"
  test_theme "xspark-branded"

  echo
  info "Checking Hyprland config..."
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/mac-mode.lua" "Mac Mode entry"
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/bindings.lua" "Mac bindings"
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/input.lua" "Mac input config"
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/looknfeel.lua" "Mac looknfeel"
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/windows.lua" "Mac window rules"
  test_config_exists "$OMARCHY_MAC_DIR/hyprland/gestures.lua" "Mac gestures"

  echo
  info "Checking integration..."
  if grep -q "omarchy-mac.hyprland.mac-mode" "$HOME/.config/hypr/hyprland.lua" 2>/dev/null; then
    pass "Hyprland loads Mac Mode config"
  else
    fail "Hyprland does not load Mac Mode config"
  fi

  echo
  info "Checking scripts..."
  test_executable "$OMARCHY_MAC_DIR/scripts/toggle-mac-mode.sh" "Toggle script"
  test_executable "$OMARCHY_MAC_DIR/scripts/backup-mac-mode.sh" "Backup script"
  test_executable "$OMARCHY_MAC_DIR/scripts/restore-mac-mode.sh" "Restore script"
  test_executable "$OMARCHY_MAC_DIR/scripts/install.sh" "Install script"

  echo
  info "Checking Omarchy integration..."
  if command -v omarchy-theme-set &>/dev/null; then
    pass "omarchy-theme-set available"
  else
    fail "omarchy-theme-set not found"
  fi

  if command -v omarchy-menu &>/dev/null; then
    pass "omarchy-menu available"
  else
    fail "omarchy-menu not found"
  fi

  if command -v hyprctl &>/dev/null; then
    pass "hyprctl available"
  else
    fail "hyprctl not found"
  fi

  echo
  echo "=========================================="
  echo "  Results: $PASS passed, $FAIL failed"
  echo "=========================================="

  if [[ $FAIL -eq 0 ]]; then
    success "All checks passed!"
    exit 0
  else
    error "Some checks failed"
    exit 1
  fi
}

main "$@"