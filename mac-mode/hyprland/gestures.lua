-- Omarchy Mac Mode - Trackpad Gestures
-- Mac-like gestures for Apple Force Touch trackpad

if not _G.mac_mode_enabled then
  return
end

local hl = _G.hl

-- ============================================================
-- WORKSPACE NAVIGATION (3-finger horizontal swipe)
-- ============================================================

-- 3-finger swipe left = next workspace (Ctrl+Right)
hl.gesture({
  fingers = 3,
  direction = "right",
  action = function()
    hl.dispatch(hl.dsp.focus({ workspace = "e+1" }))
  end,
})

-- 3-finger swipe right = previous workspace (Ctrl+Left)
hl.gesture({
  fingers = 3,
  direction = "left",
  action = function()
    hl.dispatch(hl.dsp.focus({ workspace = "e-1" }))
  end,
})

-- ============================================================
-- MISSION CONTROL (3-finger swipe up)
-- ============================================================

hl.gesture({
  fingers = 3,
  direction = "up",
  action = function()
    hl.exec_cmd("omarchy-mac-mission-control")
  end,
})

-- ============================================================
-- APP EXPOSÉ (3-finger swipe down)
-- ============================================================

hl.gesture({
  fingers = 3,
  direction = "down",
  action = function()
    hl.exec_cmd("omarchy-mac-app-expose")
  end,
})

-- ============================================================
-- LAUNCHER / SPOTLIGHT (4-finger pinch in)
-- ============================================================

-- Note: Pinch gestures require Hyprland 0.40+
-- hl.gesture({
--   fingers = 4,
--   direction = "pinch_in",
--   action = function()
--     hl.dispatch(hl.dsp.exec("omarchy-menu toggle"))
--   end,
-- })

-- ============================================================
-- SHOW DESKTOP (4-finger spread)
-- ============================================================

-- hl.gesture({
--   fingers = 4,
--   direction = "pinch_out",
--   action = function()
--     hl.dispatch(hl.dsp.exec("omarchy-mac-show-desktop"))
--   end,
-- })

-- ============================================================
-- ZOOM (2-finger pinch)
-- ============================================================

-- Handled by applications themselves (browser, image viewer, etc.)

-- ============================================================
-- NOTIFICATION CENTER (2-finger swipe from right edge)
-- ============================================================

-- This would require edge gesture support
-- hl.gesture({
--   fingers = 2,
--   direction = "right_edge",
--   action = function()
--     hl.dispatch(hl.dsp.exec("omarchy-shell notifications showHistory"))
--   end,
-- })

-- ============================================================
-- WINDOW MOVE/RESIZE (already in Omarchy defaults)
-- SUPER + left-click drag = move window
-- SUPER + right-click drag = resize window
-- These are in /usr/share/omarchy/default/hypr/bindings/tiling.lua
-- ============================================================

-- Note: For older Hyprland versions without gesture support,
-- these will be no-ops. The gestures require Hyprland 0.40+
-- and a compatible libinput version.