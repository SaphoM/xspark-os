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
