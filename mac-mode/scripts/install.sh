#!/bin/bash

# Omarchy Mac Mode Installer
# Installs Mac Mode on Omarchy

set -euo pipefail

OMARCHY_MAC_DIR="$HOME/.config/omarchy-mac"
SCRIPTS_DIR="$OMARCHY_MAC_DIR/scripts"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

check_omarchy() {
  log "Checking Omarchy installation..."
  if [[ ! -f /etc/os-release ]] || ! grep -q "ID=omarchy" /etc/os-release; then
    error "This is not an Omarchy system"
    exit 1
  fi
  local version=$(grep VERSION_ID /etc/os-release | cut -d= -f2 | tr -d '"')
  success "Omarchy $version detected"
}

check_hardware() {
  log "Checking hardware compatibility..."
  local model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
  log "Hardware: $model"

  # Check for Mac hardware
  if [[ "$model" == *"Mac"* ]] || [[ "$model" == *"MacBook"* ]]; then
    success "Mac hardware detected: $model"
  else
    warn "Non-Mac hardware: $model - Mac Mode will still work but some features may differ"
  fi

  # Check RAM
  local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
  if [[ $ram_gb -lt 8 ]]; then
    warn "Low RAM: ${ram_gb}GB - Performance Mode recommended"
  else
    success "RAM: ${ram_gb}GB"
  fi

  # Check GPU
  local gpu=$(lspci | grep -i vga | head -1)
  log "GPU: $gpu"
}

install_dependencies() {
  log "Checking dependencies..."

  local deps=(
    "hyprctl"
    "omarchy-theme-set"
    "omarchy-menu"
    "omarchy-shell"
    "quickshell"
    "jq"
    "rsync"
  )

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      warn "Missing: $dep"
    else
      success "Found: $dep"
    fi
  done
}

install_themes() {
  log "Installing Mac Mode themes..."

  # Link themes to Omarchy themes directory
  local themes_dir="/usr/share/omarchy/themes"
  if [[ -w "$themes_dir" ]]; then
    ln -sf "$OMARCHY_MAC_DIR/theme/mac-dark" "$themes_dir/mac-dark"
    ln -sf "$OMARCHY_MAC_DIR/theme/mac-light" "$themes_dir/mac-light"
    ln -sf "$OMARCHY_MAC_DIR/theme/xspark-branded" "$themes_dir/xspark-branded"
    success "Themes linked to $themes_dir"
  else
    warn "Cannot write to $themes_dir (need sudo). Themes installed to ~/.config/omarchy/themes instead"
    mkdir -p "$HOME/.config/omarchy/themes"
    ln -sf "$OMARCHY_MAC_DIR/theme/mac-dark" "$HOME/.config/omarchy/themes/mac-dark"
    ln -sf "$OMARCHY_MAC_DIR/theme/mac-light" "$HOME/.config/omarchy/themes/mac-light"
    ln -sf "$OMARCHY_MAC_DIR/theme/xspark-branded" "$HOME/.config/omarchy/themes/xspark-branded"
  fi
}

install_hyprland_config() {
  log "Installing Hyprland Mac Mode config..."

  local hypr_config="$HOME/.config/hypr/hyprland.lua"

  # Backup original
  cp "$hypr_config" "$hypr_config.pre-mac-$(date +%s)"

  # Add Mac Mode require if not present
  if ! grep -q "omarchy-mac.hyprland.mac-mode" "$hypr_config"; then
    # Add after the toggles require
    sed -i '/require("default.hypr.toggles")/a require("omarchy-mac.hyprland.mac-mode")' "$hypr_config"
    success "Hyprland config updated"
  else
    log "Hyprland config already has Mac Mode"
  fi
}

install_shell_config() {
  log "Installing Omarchy Shell Mac Mode config..."

  local shell_config="$HOME/.config/omarchy/shell.json"
  local mac_shell_config="$OMARCHY_MAC_DIR/shell/shell.json"

  # Backup original
  cp "$shell_config" "$shell_config.pre-mac-$(date +%s)"

  # For now, just ensure the Mac Mode shell config exists
  mkdir -p "$(dirname "$mac_shell_config")"
  if [[ ! -f "$mac_shell_config" ]]; then
    cat > "$mac_shell_config" <<'EOF'
{
  "version": 1,
  "idle": { "screensaver": 150, "lock": 300 },
  "bar": {
    "position": "top",
    "transparent": true,
    "centerAnchor": "omarchy.clock",
    "layout": {
      "left": [{ "id": "omarchy.menu" }, { "id": "omarchy.workspaces" }],
      "center": [{ "id": "omarchy.clock", "format": "HH:mm" }],
      "right": [{ "id": "omarchy.tray" }, { "id": "omarchy.audio" }, { "id": "omarchy.network" }, { "id": "omarchy.bluetooth" }, { "id": "omarchy.power" }]
    }
  },
  "plugins": []
}
EOF
  fi
  success "Shell config prepared"
}

set_default_theme() {
  log "Setting default theme to mac-dark..."
  omarchy-theme-set mac-dark 2>/dev/null || warn "Could not set theme (omarchy-theme-set not found)"
}

create_desktop_entries() {
  log "Creating X Spark application entries..."

  local apps_dir="$HOME/.local/share/applications"
  mkdir -p "$apps_dir"

  # BeeHIVE web app wrapper
  cat > "$apps_dir/xspark-beehive.desktop" <<'EOF'
[Desktop Entry]
Name=BeeHIVE
Comment=X Spark BeeHIVE Application
Exec=omarchy-mac-launch-beehive
Icon=beehive
Terminal=false
Type=Application
Categories=XSpark;Development;
StartupNotify=true
EOF

  success "Desktop entries created"
}

add_to_path() {
  log "Adding Mac Mode scripts to PATH..."

  local shell_rc="$HOME/.bashrc"
  local path_entry="export PATH=\"$SCRIPTS_DIR:\$PATH\""

  if ! grep -q "omarchy-mac/scripts" "$shell_rc" 2>/dev/null; then
    echo "" >> "$shell_rc"
    echo "# Omarchy Mac Mode" >> "$shell_rc"
    echo "$path_entry" >> "$shell_rc"
    success "Added to PATH in $shell_rc"
  else
    log "Already in PATH"
  fi
}

validate_install() {
  log "Validating installation..."

  local errors=0

  # Check themes
  for theme in mac-dark mac-light xspark-branded; do
    if [[ -d "/usr/share/omarchy/themes/$theme" ]] || [[ -d "$HOME/.config/omarchy/themes/$theme" ]]; then
      success "Theme $theme installed"
    else
      error "Theme $theme missing"
      ((errors++))
    fi
  done

  # Check Hyprland config
  if grep -q "omarchy-mac.hyprland.mac-mode" "$HOME/.config/hypr/hyprland.lua"; then
    success "Hyprland config linked"
  else
    error "Hyprland config not linked"
    ((errors++))
  fi

  # Check scripts
  for script in toggle-mac-mode.sh backup-mac-mode.sh restore-mac-mode.sh; do
    if [[ -x "$SCRIPTS_DIR/$script" ]]; then
      success "Script $script executable"
    else
      error "Script $script missing or not executable"
      ((errors++))
    fi
  done

  if [[ $errors -eq 0 ]]; then
    success "All validation checks passed!"
  else
    error "$errors validation error(s)"
    return 1
  fi
}

main() {
  echo "=========================================="
  echo "  Omarchy Mac Mode Installer"
  echo "=========================================="
  echo

  check_omarchy
  check_hardware
  install_dependencies
  install_themes
  install_hyprland_config
  install_shell_config
  set_default_theme
  create_desktop_entries
  add_to_path
  validate_install

  echo
  echo "=========================================="
  success "Omarchy Mac Mode installed successfully!"
  echo "=========================================="
  echo
  echo "Next steps:"
  echo "  1. Reload Hyprland: SUPER+SHIFT+R (or run: hyprctl reload)"
  echo "  2. Or re-login to apply all changes"
  echo "  3. Toggle Mac Mode: omarchy-mac-toggle"
  echo "  4. Switch themes: omarchy-theme-set mac-light|mac-dark|xspark-branded"
  echo
}

main "$@"