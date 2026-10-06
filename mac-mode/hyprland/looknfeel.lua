-- Omarchy Mac Mode - Look & Feel
-- Mac-inspired visual design: rounded corners, subtle shadows, smooth animations

if not _G.mac_mode_enabled then
  return
end

local hl = _G.hl

-- Mac-inspired color scheme (uses theme colors via Hyprland variables)
-- Gradient format: { colors = { "rgba(...)", "rgba(...)" }, angle = 45 }
local active_border_gradient = { colors = { "rgba(007affee)", "rgba(30d158ee)" }, angle = 45 }
local inactive_border_color = "rgba(48484aff)"
local shadow_color = "rgba(00000044)"

hl.config({
  general = {
    gaps_in = 8,
    gaps_out = 16,
    border_size = 1,                  -- Hairline window borders

    col = {
      active_border = active_border_gradient,
      inactive_border = inactive_border_color,
    },

    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 12,                    -- Mac-style rounded corners

    shadow = {
      enabled = true,
      range = 24,
      render_power = 3,
      color = shadow_color,
    },

    blur = {
      enabled = true,
      size = 8,
      passes = 2,
      new_optimizations = true,
      xray = 0,
      noise = 0.0117,
      contrast = 1.0,
      brightness = 1.0,
      vibrancy = 0.1667,
      vibrancy_darkness = 0.0,
    },

    active_opacity = 1.0,
    inactive_opacity = 0.95,
    fullscreen_opacity = 1.0,
  },

  group = {
    col = {
      border_active = active_border_gradient,
      border_inactive = inactive_border_color,
    },

    groupbar = {
      font_size = 11,
      font_family = "SF Pro Display,Inter,JetBrains Mono,monospace",
      font_weight_active = "semibold",
      font_weight_inactive = "medium",
      indicator_height = 2,
      indicator_gap = 4,
      height = 24,
      gaps_in = 8,
      gaps_out = 4,
      text_color = "rgb(ffffff)",
      text_color_inactive = "rgba(ffffffaa)",
      col = {
        active = "rgba(00000044)",
        inactive = "rgba(00000022)",
      },
      gradients = true,
      gradient_rounding = 10,
      gradient_round_only_edges = true,
    },
  },

  animations = {
    enabled = true,
  },
})

-- Mac-style animation curves
hl.curve("mac-ease-out", { type = "bezier", points = { { 0.33, 0.66 }, { 0.66, 1.0 } } })
hl.curve("mac-ease-in-out", { type = "bezier", points = { { 0.42, 0.0 }, { 0.58, 1.0 } } })

-- Animation configs (optimized for older Intel Macs)
hl.animation({ leaf = "global", enabled = true, speed = 8, bezier = "mac-ease-out" })
hl.animation({ leaf = "border", enabled = true, speed = 6, bezier = "mac-ease-out" })
hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "mac-ease-out" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "mac-ease-out", style = "popin 90%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "mac-ease-out", style = "popin 90%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 4, bezier = "mac-ease-out" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "mac-ease-out" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "mac-ease-out" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "mac-ease-in-out", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "mac-ease-out", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "mac-ease-out" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 6, bezier = "mac-ease-out", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "mac-ease-out", style = "fade" })

-- Layout configs
hl.config({
  dwindle = {
    preserve_split = true,
    force_split = 2,
  },

  master = {
    new_status = "master",
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    disable_scale_notification = true,
    focus_on_activate = true,
    anr_missed_pings = 3,
    on_focus_under_fullscreen = 1,
    initial_workspace_tracking = 0,
    allow_session_lock_restore = true,
    -- Mac-like: don't warp cursor on workspace change by default
    -- warp_on_change_workspace = 0,
  },

  cursor = {
    hide_on_key_press = true,
    warp_on_change_workspace = 0,  -- Mac doesn't warp cursor
  },

  binds = {
    hide_special_on_workspace_change = true,
  },
})