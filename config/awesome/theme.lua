--  OSI Linux — awesome WM theme
--  Cyberpunk dark with cyan accent
local theme = {}
local home   = os.getenv("HOME")
local dpi    = require("beautiful.xresources").apply_dpi

-- Color palette
local colors = {
    bg        = "#0a0a0f",
    bg_light  = "#12121a",
    bg_mid    = "#1a1b2e",
    fg        = "#c0caf5",
    fg_dim    = "#565f89",
    fg_dark   = "#3b4261",
    accent    = "#00ffcc",
    accent2   = "#7b68ee",
    red       = "#f7768e",
    green     = "#9ece6a",
    yellow    = "#e0af68",
    blue      = "#7aa2f7",
    magenta   = "#bb9af7",
    cyan      = "#7dcfff",
    white     = "#ffffff",
}

theme.font          = "Hack Bold 9"
theme.bg_normal     = colors.bg
theme.bg_focus      = colors.bg_mid
theme.bg_urgent     = colors.bg
theme.bg_minimize   = colors.bg
theme.bg_systray    = colors.bg
theme.fg_normal     = colors.fg_dim
theme.fg_focus      = colors.fg
theme.fg_urgent     = colors.red
theme.fg_minimize   = colors.fg_dark
theme.border_width  = dpi(2)
theme.border_normal = colors.bg_light
theme.border_focus  = colors.accent
theme.border_marked = colors.accent2
theme.useless_gap   = dpi(6)
theme.wallpaper     = home .. "/wallpaper/osi.png"

-- Taglist (workspace tabs)
theme.taglist_bg_focus    = colors.accent
theme.taglist_fg_focus    = colors.bg
theme.taglist_bg_occupied = colors.bg_mid
theme.taglist_fg_occupied = colors.fg
theme.taglist_bg_empty    = colors.bg
theme.taglist_fg_empty    = colors.fg_dark
theme.taglist_bg_urgent   = colors.red
theme.taglist_fg_urgent   = colors.bg
theme.taglist_bg_volatile = colors.magenta
theme.taglist_fg_volatile = colors.bg
theme.taglist_font        = "Hack Bold 9"

-- Tasklist (open windows)
theme.tasklist_bg_focus    = colors.bg_light
theme.tasklist_fg_focus    = colors.accent
theme.tasklist_bg_normal   = colors.bg
theme.tasklist_fg_normal   = colors.fg_dim
theme.tasklist_bg_urgent   = colors.bg
theme.tasklist_fg_urgent   = colors.red
theme.tasklist_font        = "Hack 9"
theme.tasklist_disable_icon = false

-- Menu
theme.menu_height       = dpi(28)
theme.menu_width        = dpi(220)
theme.menu_bg_normal    = colors.bg .. "ee"
theme.menu_bg_focus     = colors.bg_mid
theme.menu_fg_normal    = colors.fg
theme.menu_fg_focus     = colors.accent
theme.menu_border_color = colors.accent .. "44"
theme.menu_border_width = dpi(1)

-- Tooltip
theme.tooltip_bg           = colors.bg_light .. "ee"
theme.tooltip_fg           = colors.fg
theme.tooltip_border_color = colors.accent .. "44"
theme.tooltip_border_width = dpi(1)
theme.tooltip_font         = "Hack 9"

-- Hotkeys popup
theme.hotkeys_bg               = colors.bg .. "f0"
theme.hotkeys_fg               = colors.fg
theme.hotkeys_border_color     = colors.accent .. "66"
theme.hotkeys_border_width     = dpi(2)
theme.hotkeys_modifiers_fg     = colors.accent
theme.hotkeys_label_bg         = colors.bg_mid
theme.hotkeys_label_fg         = colors.fg
theme.hotkeys_group_margin     = dpi(20)
theme.hotkeys_font             = "Hack Bold 10"
theme.hotkeys_description_font = "Hack 9"

-- Wibar (top bar)
theme.wibar_bg           = colors.bg .. "dd"
theme.wibar_fg           = colors.fg
theme.wibar_height       = dpi(32)
theme.wibar_border_width = 0

-- Notification
theme.notification_bg           = colors.bg_light .. "ee"
theme.notification_fg           = colors.fg
theme.notification_border_color = colors.accent .. "66"
theme.notification_border_width = dpi(1)
theme.notification_max_width    = dpi(420)
theme.notification_max_height   = dpi(200)
theme.notification_font         = "Hack 10"

-- Systray
theme.systray_icon_spacing = dpi(6)

-- Snap
theme.snap_bg     = colors.accent .. "66"
theme.snap_border_width = dpi(2)

return theme
