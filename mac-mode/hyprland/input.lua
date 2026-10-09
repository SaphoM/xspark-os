-- Omarchy Mac Mode - Input Configuration
-- Optimized for Apple SPI Keyboard and Trackpad (Force Touch)

if not _G.mac_mode_enabled then
  return
end

local hl = _G.hl

-- Read vconsole for keyboard layout
local function read_vconsole()
  local values = {}
  local file = io.open("/etc/vconsole.conf", "r")
  if not file then return values end
  for line in file:lines() do
    local key, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key and value then
      value = value:gsub("%s+#.*$", "")
      value = value:gsub('^"(.*)"$', "%1")
      value = value:gsub("^'(.*)'$", "%1")
      values[key] = value
    end
  end
  file:close()
  return values
end

local vconsole = read_vconsole()
local kb_layout = vconsole.XKBLAYOUT or "gb"
local kb_variant = vconsole.XKBVARIANT or ""
-- shift:both_capslock_cancel puts <LFSH> into both Shift and Lock modifier
-- maps; xkbcomp then logs "Key <LFSH> added to map for multiple modifiers" on
-- every keymap compile. Dropped for compose:caps only.
local kb_options = "compose:caps"

-- Mac keyboard specific: Cmd=Super, Option=Alt, Control=Control
-- The Apple SPI keyboard sends proper keycodes

hl.config({
  input = {
    kb_layout = kb_layout,
    kb_variant = kb_variant,
    kb_model = "apple",
    kb_options = kb_options,
    kb_rules = "",

    follow_mouse = 1,
    sensitivity = 0.1,

    repeat_rate = 35,
    repeat_delay = 300,
    numlock_by_default = false,

    follow_mouse = 0,                  -- Click to focus (macOS behavior), not hover

    touchpad = {
      -- Mac-like trackpad behavior
      natural_scroll = true,           -- Natural scrolling (content follows fingers)
      clickfinger_behavior = true,     -- Two-finger click = right click
      tap_to_click = true,             -- Tap to click
      tap_and_drag = true,             -- Tap and drag
      drag_lock = false,
      disable_while_typing = true,     -- Disable trackpad while typing

      -- Scrolling
      scroll_factor = 0.5,             -- Smooth scrolling speed
    },
  },

  misc = {
    key_press_enables_dpms = true,
    mouse_move_enables_dpms = true,
  },
})

-- Terminal scroll speeds - use o.window from global
_G.o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
_G.o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Apple SPI Keyboard specific: ensure Fn keys work
-- XF86 keys already handled in media.lua bindings