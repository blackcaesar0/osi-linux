local theme = {}
local home   = os.getenv("HOME")
local gfs    = require("gears.filesystem")
local dpi    = require("beautiful.xresources").apply_dpi

theme.font          = "Hack 10"
theme.bg_normal     = "#0a0a0a"
theme.bg_focus      = "#1a1a1a"
theme.bg_urgent     = "#0a0a0a"
theme.bg_minimize   = "#0a0a0a"
theme.bg_systray    = "#0a0a0a"
theme.fg_normal     = "#999999"
theme.fg_focus      = "#ffffff"
theme.fg_urgent     = "#ff3333"
theme.fg_minimize   = "#444444"
theme.border_width  = dpi(2)
theme.border_normal = "#1a1a1a"
theme.border_focus  = "#ffffff"
theme.border_marked = "#ffffff"
theme.useless_gap   = dpi(4)
theme.wallpaper     = home .. "/wallpaper/osi.png"

-- Taglist (workspace tabs)
theme.taglist_bg_focus    = "#ffffff"
theme.taglist_fg_focus    = "#0a0a0a"
theme.taglist_bg_occupied = "#0a0a0a"
theme.taglist_fg_occupied = "#999999"
theme.taglist_bg_empty    = "#0a0a0a"
theme.taglist_fg_empty    = "#333333"
theme.taglist_bg_urgent   = "#ff3333"
theme.taglist_fg_urgent   = "#ffffff"

-- Tasklist (open windows)
theme.tasklist_bg_focus  = "#1a1a1a"
theme.tasklist_fg_focus  = "#ffffff"
theme.tasklist_bg_normal = "#0a0a0a"
theme.tasklist_fg_normal = "#888888"

-- Menu
theme.menu_height       = dpi(24)
theme.menu_width        = dpi(200)
theme.menu_bg_normal    = "#0a0a0a"
theme.menu_bg_focus     = "#1a1a1a"
theme.menu_fg_normal    = "#e0e0e0"
theme.menu_fg_focus     = "#ffffff"
theme.menu_border_color = "#333333"
theme.menu_border_width = dpi(1)

-- Tooltip
theme.tooltip_bg           = "#0a0a0a"
theme.tooltip_fg           = "#e0e0e0"
theme.tooltip_border_color = "#333333"
theme.tooltip_border_width = dpi(1)

-- Hotkeys popup
theme.hotkeys_bg           = "#0a0a0aee"
theme.hotkeys_fg           = "#e0e0e0"
theme.hotkeys_border_color = "#333333"
theme.hotkeys_border_width = dpi(2)
theme.hotkeys_modifiers_fg = "#ffffff"
theme.hotkeys_label_bg     = "#1a1a1a"
theme.hotkeys_label_fg     = "#888888"
theme.hotkeys_group_margin = dpi(20)
theme.hotkeys_font         = "Hack 10"
theme.hotkeys_description_font = "Hack 9"

-- Wibar (top bar)
theme.wibar_bg           = "#0a0a0a"
theme.wibar_fg           = "#e0e0e0"
theme.wibar_height       = dpi(28)
theme.wibar_border_width = 0

-- Notification
theme.notification_bg           = "#0a0a0a"
theme.notification_fg           = "#e0e0e0"
theme.notification_border_color = "#333333"
theme.notification_border_width = dpi(1)
theme.notification_max_width    = dpi(400)
theme.notification_max_height   = dpi(200)

-- Systray
theme.systray_icon_spacing = dpi(4)

return theme
