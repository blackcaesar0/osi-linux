local theme = {}
local home   = os.getenv("HOME")

theme.font          = "JetBrains Mono 10"
theme.bg_normal     = "#000000"
theme.bg_focus      = "#000000"
theme.bg_urgent     = "#000000"
theme.bg_minimize   = "#000000"
theme.bg_systray    = "#000000"
theme.fg_normal     = "#e0e0e0"
theme.fg_focus      = "#ffffff"
theme.fg_urgent     = "#ff3333"
theme.fg_minimize   = "#444444"
theme.border_width  = 2
theme.border_normal = "#2a2a2a"
theme.border_focus  = "#ffffff"
theme.border_marked = "#ffffff"
theme.useless_gap   = 4
theme.wallpaper     = home .. "/wallpaper/osi.png"

theme.taglist_bg_focus    = "#1a1a1a"
theme.taglist_fg_focus    = "#ffffff"
theme.taglist_bg_occupied = "#000000"
theme.taglist_fg_occupied = "#888888"
theme.taglist_bg_empty    = "#000000"
theme.taglist_fg_empty    = "#333333"
theme.taglist_bg_urgent   = "#000000"
theme.taglist_fg_urgent   = "#ff3333"

theme.tasklist_bg_focus  = "#1a1a1a"
theme.tasklist_fg_focus  = "#ffffff"
theme.tasklist_bg_normal = "#000000"
theme.tasklist_fg_normal = "#888888"

theme.menu_height       = 20
theme.menu_width        = 200
theme.menu_bg_normal    = "#000000"
theme.menu_bg_focus     = "#1a1a1a"
theme.menu_fg_normal    = "#e0e0e0"
theme.menu_fg_focus     = "#ffffff"
theme.menu_border_color = "#333333"
theme.menu_border_width = 1

theme.tooltip_bg           = "#000000"
theme.tooltip_fg           = "#e0e0e0"
theme.tooltip_border_color = "#333333"
theme.tooltip_border_width = 1

theme.hotkeys_bg           = "#000000"
theme.hotkeys_fg           = "#e0e0e0"
theme.hotkeys_border_color = "#333333"
theme.hotkeys_modifiers_fg = "#ffffff"
theme.hotkeys_label_bg     = "#1a1a1a"
theme.hotkeys_label_fg     = "#888888"
theme.hotkeys_group_margin = 20

theme.wibar_bg           = "#000000"
theme.wibar_fg           = "#e0e0e0"
theme.wibar_height       = 24
theme.wibar_border_width = 0

return theme
