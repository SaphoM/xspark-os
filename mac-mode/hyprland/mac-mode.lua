-- Omarchy Mac Mode - entry point
-- Loaded from ~/.config/hypr/hyprland.lua via:
--   require("omarchy-mac.hyprland.mac-mode")

local state_file = (os.getenv("HOME") or "") .. "/.local/state/omarchy-mac/enabled"

local enabled = true
local handle = io.open(state_file, "r")
if handle then
  local content = handle:read("*a") or ""
  handle:close()
  if content:match("^0") then
    enabled = false
  end
end

_G.mac_mode_enabled = enabled
if not enabled then
  return
end

_G.hl = _G.hl or require("hyprland")
_G.o = _G.o or require("default.hypr.helpers")

-- The Mac shim for `omarchy-menu` targets the top-left clone (xspark.menu).
-- Put ~/.local/bin first so bindings' exec resolves the shim, not the stock
-- CLI in /usr/share/omarchy/bin.
_G.hl.env("PATH", os.getenv("HOME") .. "/.local/bin:" .. (os.getenv("PATH") or ""))

-- Reload Mac Mode modules on every Hyprland config reload so edits land
-- without restarting the session.
local modules = {
  "omarchy-mac.hyprland.bindings",
  "omarchy-mac.hyprland.input",
  "omarchy-mac.hyprland.looknfeel",
  "omarchy-mac.hyprland.windows",
  "omarchy-mac.hyprland.gestures",
}
for _, name in ipairs(modules) do
  package.loaded[name] = nil
end

require("omarchy-mac.hyprland.bindings")
require("omarchy-mac.hyprland.input")
require("omarchy-mac.hyprland.looknfeel")
require("omarchy-mac.hyprland.windows")
require("omarchy-mac.hyprland.gestures")

-- Mac Mode on/off (kept clear of Cmd+Opt+M, which is minimize-app)
_G.o.bind("SUPER + CTRL + ALT + M", "Toggle Mac Mode", "omarchy-mac-toggle toggle")
