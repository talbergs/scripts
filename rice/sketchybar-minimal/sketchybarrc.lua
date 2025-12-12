#!/usr/bin/env lua

-- SketchyBar Minimal Configuration
-- Features: Aerospace workspace, Clock, Battery

-- Load SketchyBar module
local sbar = require("sketchybar")

-- Colors
local colors = {
    bar_bg = 0xcc24273a,
    white = 0xffcad3f5,
    black = 0xff181926,
    blue = 0xff8aadf4,
    green = 0xffa6da95,
    yellow = 0xffeed49f,
    red = 0xffed8796,
    transparent = 0x00000000,
}

-- Bar configuration
sbar.bar({
    height = 40,
    color = colors.bar_bg,
    position = "top",
    sticky = "on",
    padding_left = 10,
    padding_right = 10,
    corner_radius = 9,
    y_offset = 5,
    margin = 10,
    blur_radius = 20,
})

-- Default item settings
sbar.default({
    updates = "when_shown",
    icon = {
        font = "SF Pro:Bold:14.0",
        color = colors.white,
        padding_left = 8,
        padding_right = 8,
    },
    label = {
        font = "SF Pro:Semibold:13.0",
        color = colors.white,
        padding_left = 8,
        padding_right = 8,
    },
    background = {
        height = 26,
        corner_radius = 9,
        padding_left = 4,
        padding_right = 4,
    },
})

-- Aerospace Workspaces
sbar.exec("aerospace list-workspaces --all", function(workspaces)
    for workspace in workspaces:gmatch("[^\r\n]+") do
        local space = sbar.add("item", "space." .. workspace, {
            position = "left",
            icon = {
                string = workspace,
                font = "SF Pro:Bold:14.0",
            },
            label = { drawing = false },
            background = {
                color = colors.transparent,
                border_color = colors.blue,
                border_width = 2,
            },
            click_script = "aerospace workspace " .. workspace,
        })
        
        space:subscribe("aerospace_workspace_change", function(env)
            local focused = env.FOCUSED_WORKSPACE
            if workspace == focused then
                sbar.set(space, {
                    background = { color = colors.blue },
                    icon = { color = colors.black },
                })
            else
                sbar.set(space, {
                    background = { color = colors.transparent },
                    icon = { color = colors.white },
                })
            end
        end)
    end
end)

-- Add aerospace workspace change event
sbar.add("event", "aerospace_workspace_change")

-- Clock
local clock = sbar.add("item", "clock", {
    position = "right",
    update_freq = 1,
    icon = { drawing = false },
    background = {
        color = colors.blue,
    },
})

clock:subscribe("routine", function()
    local time = os.date("%H:%M")
    local date = os.date("%a %d %b")
    sbar.set(clock, {
        label = {
            string = time .. " " .. date,
            color = colors.black,
        },
    })
end)

-- Battery
local battery = sbar.add("item", "battery", {
    position = "right",
    update_freq = 30,
    background = {
        color = colors.green,
    },
})

battery:subscribe("routine", function()
    sbar.exec("pmset -g batt", function(output)
        local percentage = output:match("(%d+)%%")
        local charging = output:match("charging") or output:match("charged")
        
        local icon = "󰁹" -- battery icon
        if charging then
            icon = "󰂄" -- charging icon
        end
        
        local bg_color = colors.green
        if tonumber(percentage) < 20 then
            bg_color = colors.red
        elseif tonumber(percentage) < 50 then
            bg_color = colors.yellow
        end
        
        sbar.set(battery, {
            icon = {
                string = icon,
                color = colors.black,
            },
            label = {
                string = percentage .. "%",
                color = colors.black,
            },
            background = {
                color = bg_color,
            },
        })
    end)
end)

-- Run the bar
sbar.update()
