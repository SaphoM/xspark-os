-- Omarchy Mac Mode - Window rules
-- Floating-first for common apps (Mac-like), editors still tile.

if not _G.mac_mode_enabled then
  return
end

local o = _G.o

-- Terminals: float, centered
o.window("foot", { float = true, size = { 800, 600 }, center = true })
o.window("com.mitchellh.ghostty", { float = true, size = { 800, 600 }, center = true })
o.window("kitty", { float = true, size = { 800, 600 }, center = true })
o.window("Alacritty", { float = true, size = { 800, 600 }, center = true })

-- Browsers: float, centered, large
o.window("firefox", { float = true, size = { "1200", "800" }, center = true, decorate = false })
o.window("Google-chrome", { float = true, size = { "1200", "800" }, center = true })
o.window("google-chrome", { float = true, size = { "1200", "800" }, center = true })
o.window("Brave-browser", { float = true, size = { "1200", "800" }, center = true })
o.window({ tag = "chromium-based-browser" }, { float = true, size = { "1200", "800" }, center = true })

-- File manager: float, centered
o.window("org.gnome.Nautilus", { float = true, size = { 900, 600 }, center = true })
o.window("thunar", { float = true, size = { 900, 600 }, center = true })

-- Editors: tile (work-focused)
o.window("code", { float = false })
o.window("cursor", { float = false })

-- Dialogs / settings: always float, centered
o.window({ class = "dialog" }, { float = true, center = true })
o.window("xdg-desktop-portal-gtk", { float = true, center = true })
o.window("gnome-control-center", { float = true, center = true })

-- Media: float, centered
o.window("spotify", { float = true, size = { 1000, 700 }, center = true })
o.window("vlc", { float = true, center = true })
o.window("mpv", { float = true, center = true })

-- Communication: float, centered (no default decorations - use winbuttons)
o.window("discord", { float = true, size = { 1000, 700 }, center = true, decorate = false })
o.window("Slack", { float = true, size = { 1000, 700 }, center = true, decorate = false })
o.window("signal", { float = true, size = { 900, 600 }, center = true, decorate = false })

-- Chromium and browsers: float, centered (no default decorations - use winbuttons)
o.window("chromium", { float = true, size = { "1200", "800" }, center = true, decorate = false })
o.window("Google-chrome", { float = true, size = { "1200", "800" }, center = true, decorate = false })
o.window("google-chrome", { float = true, size = { "1200", "800" }, center = true, decorate = false })
o.window("Brave-browser", { float = true, size = { "1200", "800" }, center = true, decorate = false })
o.window({ tag = "chromium-based-browser" }, { float = true, size = { "1200", "800" }, center = true, decorate = false })

-- Utilities: float, centered
o.window("gnome-calculator", { float = true, center = true, size = { 400, 500 } })
o.window("org.gnome.Calculator", { float = true, center = true, size = { 400, 500 } })

-- Telegram: float, centered (no default decorations - use winbuttons)
o.window("telegramdesktop", { float = true, center = true, decorate = false })
