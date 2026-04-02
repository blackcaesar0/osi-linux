local gears         = require("gears")
local awful         = require("awful")
require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")
local dpi           = require("beautiful.xresources").apply_dpi

-- Error handling
if awesome.startup_errors then
    naughty.notify({
        preset = naughty.config.presets.critical,
        title  = "Startup error",
        text   = awesome.startup_errors
    })
end
do
    local in_error = false
    awesome.connect_signal("debug::error", function(err)
        if in_error then return end
        in_error = true
        naughty.notify({ preset = naughty.config.presets.critical, title = "Error", text = tostring(err) })
        in_error = false
    end)
end

-- Theme
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

local terminal = "alacritty"
local modkey   = "Mod4"

-- Accent color (matches theme)
local accent = "#00ffcc"
local bg     = "#0a0a0f"
local bg_mid = "#1a1b2e"
local fg_dim = "#565f89"

-- Layouts
awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

-- Wallpaper
local function set_wallpaper(s)
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        if type(wallpaper) == "function" then wallpaper = wallpaper(s) end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end
screen.connect_signal("property::geometry", set_wallpaper)

-- Widget helpers
local function make_separator(color, width)
    return wibox.widget {
        {
            forced_width = dpi(width or 1),
            color        = color or fg_dim .. "44",
            widget       = wibox.widget.separator,
            orientation  = "vertical",
        },
        top    = dpi(8),
        bottom = dpi(8),
        widget = wibox.container.margin,
    }
end

local function make_pill(widget, bg_color, fg_color)
    return wibox.widget {
        {
            widget,
            left   = dpi(10),
            right  = dpi(10),
            top    = dpi(4),
            bottom = dpi(4),
            widget = wibox.container.margin,
        },
        bg     = bg_color or bg_mid,
        fg     = fg_color or accent,
        shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end,
        widget = wibox.container.background,
    }
end

-- Taglist mouse buttons
local taglist_buttons = gears.table.join(
    awful.button({},         1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t) if client.focus then client.focus:move_to_tag(t) end end),
    awful.button({},         3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t) if client.focus then client.focus:toggle_tag(t) end end),
    awful.button({},         4, function(t) awful.tag.viewnext(t.screen) end),
    awful.button({},         5, function(t) awful.tag.viewprev(t.screen) end)
)

local tasklist_buttons = gears.table.join(
    awful.button({}, 1, function(c)
        if c == client.focus then c.minimized = true
        else c:emit_signal("request::activate", "tasklist", { raise = true }) end
    end),
    awful.button({}, 4, function() awful.client.focus.byidx(1) end),
    awful.button({}, 5, function() awful.client.focus.byidx(-1) end)
)

-- Screen setup
awful.screen.connect_for_each_screen(function(s)
    set_wallpaper(s)

    awful.tag({ "OSI", "term", "web", "tools", "recon", "exploit", "post", "files", "misc" }, s, awful.layout.layouts[1])

    s.mypromptbox = awful.widget.prompt()
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end)
    ))

    -- Taglist with custom styling
    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        style   = {
            shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end,
        },
        layout  = {
            spacing = dpi(4),
            layout  = wibox.layout.fixed.horizontal,
        },
        widget_template = {
            {
                {
                    { id = "text_role", widget = wibox.widget.textbox },
                    left   = dpi(10),
                    right  = dpi(10),
                    top    = dpi(3),
                    bottom = dpi(3),
                    widget = wibox.container.margin,
                },
                id     = "background_role",
                widget = wibox.container.background,
                shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end,
            },
            top    = dpi(4),
            bottom = dpi(4),
            widget = wibox.container.margin,
        },
    }

    -- Tasklist
    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        style   = { shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end },
    }

    -- Clock widget
    local clock = wibox.widget {
        format = " %H:%M ",
        font   = "Hack Bold 10",
        widget = wibox.widget.textclock,
    }
    local date_widget = wibox.widget {
        format = " %Y-%m-%d ",
        font   = "Hack 9",
        widget = wibox.widget.textclock,
    }

    -- Layout indicator
    local layout_pill = make_pill(
        wibox.widget {
            s.mylayoutbox,
            forced_width  = dpi(16),
            forced_height = dpi(16),
            widget        = wibox.container.place,
        },
        bg_mid
    )

    -- Wibar
    s.mywibox = awful.wibar({
        position = "top",
        screen   = s,
        height   = beautiful.wibar_height,
    })

    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        -- Left: taglist
        {
            layout = wibox.layout.fixed.horizontal,
            {
                s.mytaglist,
                left  = dpi(6),
                right = dpi(6),
                widget = wibox.container.margin,
            },
            make_separator(),
            {
                s.mypromptbox,
                left = dpi(6),
                widget = wibox.container.margin,
            },
        },
        -- Center: tasklist
        {
            s.mytasklist,
            left  = dpi(12),
            right = dpi(12),
            widget = wibox.container.margin,
        },
        -- Right: systray + clock + layout
        {
            layout = wibox.layout.fixed.horizontal,
            {
                wibox.widget.systray(),
                top    = dpi(6),
                bottom = dpi(6),
                right  = dpi(6),
                widget = wibox.container.margin,
            },
            make_separator(),
            make_pill(date_widget, bg_mid, fg_dim),
            {
                forced_width = dpi(4),
                widget       = wibox.container.margin,
            },
            make_pill(clock, bg_mid, accent),
            {
                forced_width = dpi(4),
                widget       = wibox.container.margin,
            },
            layout_pill,
            {
                forced_width = dpi(6),
                widget       = wibox.container.margin,
            },
        },
    }
end)

-- Mouse bindings on desktop
root.buttons(gears.table.join(
    awful.button({}, 3, function()
        awful.spawn("rofi -show drun -theme " .. os.getenv("HOME") .. "/.config/rofi/osi.rasi")
    end),
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))

-- Global keybindings
local globalkeys = gears.table.join(
    awful.key({ modkey },           "s",      hotkeys_popup.show_help,             { description = "show help",        group = "awesome" }),
    awful.key({ modkey },           "Left",   awful.tag.viewprev,                  { description = "previous tag",     group = "tag" }),
    awful.key({ modkey },           "Right",  awful.tag.viewnext,                  { description = "next tag",         group = "tag" }),
    awful.key({ modkey },           "Escape", awful.tag.history.restore,           { description = "last tag",         group = "tag" }),
    awful.key({ modkey },           "j",      function() awful.client.focus.byidx(1)  end, { description = "focus next",  group = "client" }),
    awful.key({ modkey },           "k",      function() awful.client.focus.byidx(-1) end, { description = "focus prev",  group = "client" }),
    awful.key({ modkey, "Shift" },  "j",      function() awful.client.swap.byidx(1)   end, { description = "swap next",   group = "client" }),
    awful.key({ modkey, "Shift" },  "k",      function() awful.client.swap.byidx(-1)  end, { description = "swap prev",   group = "client" }),
    awful.key({ modkey },           "Tab",    function()
        awful.client.focus.history.previous()
        if client.focus then client.focus:raise() end
    end, { description = "go back", group = "client" }),
    awful.key({ modkey },           "Return", function() awful.spawn(terminal) end,  { description = "terminal",        group = "launcher" }),
    awful.key({ modkey },           "d",      function()
        awful.spawn("rofi -show drun -theme " .. os.getenv("HOME") .. "/.config/rofi/osi.rasi")
    end, { description = "launcher", group = "launcher" }),
    awful.key({ modkey },           "r",      function() awful.screen.focused().mypromptbox:run() end, { description = "run prompt", group = "launcher" }),
    awful.key({ modkey, "Control"}, "r",      awesome.restart,                     { description = "reload awesome",   group = "awesome" }),
    awful.key({ modkey, "Shift" },  "q",      awesome.quit,                        { description = "quit awesome",     group = "awesome" }),
    awful.key({ modkey },           "l",      function() awful.tag.incmwfact(0.05)  end, { description = "grow master",  group = "layout" }),
    awful.key({ modkey },           "h",      function() awful.tag.incmwfact(-0.05) end, { description = "shrink master",group = "layout" }),
    awful.key({ modkey },           "space",  function() awful.layout.inc(1)  end,  { description = "next layout",     group = "layout" }),
    awful.key({ modkey, "Shift" },  "space",  function() awful.layout.inc(-1) end,  { description = "prev layout",     group = "layout" }),
    awful.key({},                   "Print",  function()
        awful.spawn("scrot -e 'mkdir -p ~/screenshots && mv $f ~/screenshots/'")
    end, { description = "screenshot", group = "launcher" }),
    awful.key({ "Shift" },          "Print",  function()
        awful.spawn("flameshot gui")
    end, { description = "screenshot (select)", group = "launcher" }),
    awful.key({ modkey, "Control"}, "l",      function()
        awful.spawn("slock")
    end, { description = "lock screen", group = "awesome" }),
    awful.key({ modkey },           "e",      function()
        awful.spawn(terminal .. " -e ranger")
    end, { description = "file manager", group = "launcher" })
)

-- Tag switching with number keys
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        awful.key({ modkey },           "#" .. i + 9, function()
            local t = awful.screen.focused().tags[i]
            if t then t:view_only() end
        end, { description = "view tag #" .. i, group = "tag" }),
        awful.key({ modkey, "Control"}, "#" .. i + 9, function()
            local t = awful.screen.focused().tags[i]
            if t then awful.tag.viewtoggle(t) end
        end, { description = "toggle tag #" .. i, group = "tag" }),
        awful.key({ modkey, "Shift" },  "#" .. i + 9, function()
            if client.focus then
                local t = client.focus.screen.tags[i]
                if t then client.focus:move_to_tag(t) end
            end
        end, { description = "move to tag #" .. i, group = "tag" })
    )
end

-- Client keybindings
local clientkeys = gears.table.join(
    awful.key({ modkey },           "f",     function(c) c.fullscreen = not c.fullscreen; c:raise() end, { description = "fullscreen",      group = "client" }),
    awful.key({ modkey, "Shift" },  "c",     function(c) c:kill() end,                                   { description = "close",           group = "client" }),
    awful.key({ modkey, "Control"}, "space", awful.client.floating.toggle,                                { description = "toggle floating",  group = "client" }),
    awful.key({ modkey },           "t",     function(c) c.ontop = not c.ontop end,                      { description = "toggle on top",    group = "client" }),
    awful.key({ modkey },           "n",     function(c) c.minimized = true end,                         { description = "minimize",         group = "client" }),
    awful.key({ modkey },           "m",     function(c) c.maximized = not c.maximized; c:raise() end,   { description = "maximize",         group = "client" })
)

-- Client mouse buttons
local clientbuttons = gears.table.join(
    awful.button({},         1, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }) end),
    awful.button({ modkey }, 1, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.move(c) end),
    awful.button({ modkey }, 3, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.resize(c) end)
)

root.keys(globalkeys)

-- Rules
awful.rules.rules = {
    { rule = {},
      properties = {
          border_width      = beautiful.border_width,
          border_color      = beautiful.border_normal,
          focus             = awful.client.focus.filter,
          raise             = true,
          keys              = clientkeys,
          buttons           = clientbuttons,
          screen            = awful.screen.preferred,
          placement         = awful.placement.no_overlap + awful.placement.no_offscreen,
          titlebars_enabled = false,
      }
    },
    { rule = { class = "Alacritty" }, properties = { tag = "term"    } },
    { rule = { class = "firefox"   }, properties = { tag = "web"     } },
    { rule = { class = "Firefox"   }, properties = { tag = "web"     } },
    { rule_any = { type = { "dialog" } },
      properties = { floating = true, placement = awful.placement.centered }
    },
}

-- Signals
client.connect_signal("manage", function(c)
    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus  end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

-- Autostart — only run once per session using pgrep guard
local function run_once(cmd, name)
    name = name or cmd:match("([^%s]+)")
    awful.spawn.easy_async_with_shell(
        "pgrep -x " .. name .. " > /dev/null || " .. cmd,
        function() end
    )
end

run_once("picom --config " .. os.getenv("HOME") .. "/.config/picom/picom.conf -b", "picom")
run_once("nm-applet", "nm-applet")
run_once("mkdir -p ~/screenshots")
