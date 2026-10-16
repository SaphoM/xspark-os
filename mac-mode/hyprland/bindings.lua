-- Omarchy Mac Mode - Mac-style keybindings
-- Shell commands do the work (see ~/.config/omarchy-mac/scripts/omarchy-mac-*).

if not _G.mac_mode_enabled then
  return
end

local hl = _G.hl
local o = _G.o

-- ============================================================
-- APPLICATION (Cmd = SUPER)
-- ============================================================

o.bind("SUPER + Q", "Quit Application", hl.dsp.window.close())
o.bind("SUPER + W", "Close Window", hl.dsp.window.close())
o.bind("SUPER + N", "New Terminal Window", "omarchy-launch-terminal")

-- ============================================================
-- APPLICATION SWITCHING (Cmd+Tab)
-- ============================================================

hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")

o.bind("SUPER + TAB", "App Switcher (next)", "omarchy-mac-app-switcher next")
o.bind("SUPER + SHIFT + TAB", "App Switcher (prev)", "omarchy-mac-app-switcher prev")
o.bind("SUPER + GRAVE", "Cycle App Windows", "omarchy-mac-winops cycle")

-- ============================================================
-- SPOTLIGHT / SEARCH (Option+Space)
-- ============================================================

-- Toggle the floating search box (xspark.spotlight overlay plugin).
o.bind("ALT + SPACE", "Spotlight Search", "omarchy-shell shell toggle xspark.spotlight")

-- ============================================================
-- WINDOW MANAGEMENT
-- ============================================================

o.bind("SUPER + M", "Minimize Window", "omarchy-mac-winops minimize")
o.bind("SUPER + CTRL + M", "Maximize / Restore Window", "omarchy-mac-winops maximize")
o.bind("SUPER + H", "Hide Application", "omarchy-mac-winops hide")
o.bind("SUPER + ALT + H", "Hide Other Applications", "omarchy-mac-winops hide-others")
o.bind("SUPER + ALT + M", "Minimize App Windows", "omarchy-mac-winops hide")
o.bind("SUPER + ALT + ESCAPE", "Force Quit", "omarchy-mac-force-quit")

-- ============================================================
-- WORKSPACES / MISSION CONTROL / APP EXPOSÉ
-- ============================================================

o.bind("CTRL + LEFT", "Previous Workspace", hl.dsp.focus({ workspace = "e-1" }))
o.bind("CTRL + RIGHT", "Next Workspace", hl.dsp.focus({ workspace = "e+1" }))
o.bind("CTRL + UP", "Mission Control", "omarchy-mac-mission-control")
o.bind("F3", "Mission Control", "omarchy-mac-mission-control")
o.bind("F4", "Launchpad / Spotlight", "omarchy-shell shell toggle xspark.spotlight")
o.bind("CTRL + DOWN", "App Exposé", "omarchy-mac-app-expose")

-- ============================================================
-- SCREENSHOTS (Cmd+Shift+3/4/5)
-- ============================================================

o.bind("SUPER + SHIFT + 3", "Full Screenshot", "omarchy-capture-screenshot")
o.bind("SUPER + SHIFT + 4", "Area Screenshot", "omarchy-capture-region")
o.bind("SUPER + SHIFT + W", "Capture Window", "omarchy-mac-capture-window")
o.bind("SUPER + SHIFT + 5", "Screenshot UI", "omarchy-menu toggle capture")

-- ============================================================
-- LOCK (Cmd+Shift+Ctrl+Q style stays on SUPER+CTRL+L)
-- ============================================================

-- Dock (Cmd+Opt+D toggles, like macOS)
o.bind("SUPER + ALT + D", "Toggle Dock", "omarchy-shell omadock toggleVisibility")
o.bind("SUPER + ALT + SHIFT + D", "Dock Settings", "omarchy-shell omadock openSettings")


-- ============================================================
-- UNIVERSAL TEXT SHORTCUTS (Cmd = Super) — application-aware
-- ============================================================

local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window or not window.class then return false end
  local cls = string.lower(window.class)
  return cls:find("foot", 1, true) ~= nil
      or cls:find("kitty", 1, true) ~= nil
      or cls:find("ghostty", 1, true) ~= nil
      or cls:find("alacritty", 1, true) ~= nil
end

o.bind("SUPER + Z", "Universal undo", function()
  if active_window_is_terminal() then return end
  send_shortcut_once("CTRL", "Z")()
end)
o.bind("SUPER + SHIFT + Z", "Universal redo", function()
  if active_window_is_terminal() then return end
  send_shortcut_once("CTRL SHIFT", "Z")()
end)
o.bind("SUPER + A", "Universal select all", function()
  if active_window_is_terminal() then
    send_shortcut_once("CTRL SHIFT", "A")()
    return
  end
  send_shortcut_once("CTRL", "A")()
end)
