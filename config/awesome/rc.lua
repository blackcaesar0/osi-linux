local gears         = require("gears")
local awful         = require("awful")
require("awful.autofocus")
local wibox         = require("wibox")
local beautiful     = require("beautiful")
local naughty       = require("naughty")
local hotkeys_popup = require("awful.hotkeys_popup")

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

beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

local terminal = "alacritty"
local modkey   = "Mod4"

awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.fair,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.floating,
}

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

awful.screen.connect_for_each_screen(function(s)
    awful.tag({ "term", "web", "tools", "recon", "exploit", "post", "files", "misc", "scratch" }, s, awful.layout.layouts[1])

    s.mypromptbox = awful.widget.prompt()
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(gears.table.join(
        awful.button({}, 1, function() awful.layout.inc(1) end),
        awful.button({}, 3, function() awful.layout.inc(-1) end)
    ))

    s.mytaglist = awful.widget.taglist {
        screen  = s,
        filter  = awful.widget.taglist.filter.all,
        buttons = taglist_buttons,
        style   = { shape = gears.shape.rectangle },
        layout  = { spacing = 0, layout = wibox.layout.fixed.horizontal },
        widget_template = {
            {
                { id = "text_role", widget = wibox.widget.textbox },
                left = 8, right = 8,
                widget = wibox.container.margin
            },
            id     = "background_role",
            widget = wibox.container.background,
        },
    }

    s.mytasklist = awful.widget.tasklist {
        screen  = s,
        filter  = awful.widget.tasklist.filter.currenttags,
        buttons = tasklist_buttons,
        style   = { shape = gears.shape.rectangle },
    }

    s.mywibox = awful.wibar({ position = "top", screen = s, height = beautiful.wibar_height })
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        {
            layout = wibox.layout.fixed.horizontal,
            wibox.widget {
                markup = "  <b>OSI</b>  ",
                widget = wibox.widget.textbox
            },
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist,
        {
            layout = wibox.layout.fixed.horizontal,
            wibox.widget.systray(),
            wibox.widget.textclock("  %Y-%m-%d  %H:%M  "),
            s.mylayoutbox,
        },
    }
end)

screen.connect_signal("property::geometry", function()
    awful.spawn("feh --bg-fill " .. os.getenv("HOME") .. "/wallpaper/osi.png")
end)

root.buttons(gears.table.join(
    awful.button({}, 3, function()
        awful.spawn("rofi -show drun -theme " .. os.getenv("HOME") .. "/.config/rofi/osi.rasi")
    end),
    awful.button({}, 4, awful.tag.viewnext),
    awful.button({}, 5, awful.tag.viewprev)
))

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
    awful.key({ modkey, "Control"}, "l",      function()
        awful.spawn("slock")
    end, { description = "lock screen", group = "awesome" }),
    awful.key({ modkey },           "e",      function()
        awful.spawn(terminal .. " -e ranger")
    end, { description = "file manager", group = "launcher" })
)

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

local clientkeys = gears.table.join(
    awful.key({ modkey },           "f",     function(c) c.fullscreen = not c.fullscreen; c:raise() end, { description = "fullscreen",      group = "client" }),
    awful.key({ modkey, "Shift" },  "c",     function(c) c:kill() end,                                   { description = "close",           group = "client" }),
    awful.key({ modkey, "Control"}, "space", awful.client.floating.toggle,                                { description = "toggle floating",  group = "client" }),
    awful.key({ modkey },           "t",     function(c) c.ontop = not c.ontop end,                      { description = "toggle on top",    group = "client" }),
    awful.key({ modkey },           "n",     function(c) c.minimized = true end,                         { description = "minimize",         group = "client" }),
    awful.key({ modkey },           "m",     function(c) c.maximized = not c.maximized; c:raise() end,   { description = "maximize",         group = "client" })
)

local clientbuttons = gears.table.join(
    awful.button({},         1, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }) end),
    awful.button({ modkey }, 1, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.move(c) end),
    awful.button({ modkey }, 3, function(c) c:emit_signal("request::activate", "mouse_click", { raise = true }); awful.mouse.client.resize(c) end)
)

root.keys(globalkeys)

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
    { rule = { class = "Alacritty" }, properties = { tag = "term"   } },
    { rule = { class = "firefox"   }, properties = { tag = "web"    } },
    { rule_any = { type = { "dialog" } },
      properties = { floating = true, placement = awful.placement.centered }
    },
}

client.connect_signal("manage", function(c)
    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
        awful.placement.no_offscreen(c)
    end
end)

client.connect_signal("focus",   function(c) c.border_color = beautiful.border_focus  end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

awful.spawn.with_shell("picom --config " .. os.getenv("HOME") .. "/.config/picom/picom.conf -b")
awful.spawn.with_shell("feh --bg-fill " .. os.getenv("HOME") .. "/wallpaper/osi.png")
awful.spawn.with_shell("nm-applet")
awful.spawn.with_shell("mkdir -p ~/screenshots")
