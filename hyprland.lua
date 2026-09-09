-- YORHA_LUA_CONFIG
-- Yorha configuration for Hyprland 0.55+

local home = os.getenv("HOME")
local themeDir = home .. "/.config/hypr/themes/yorha"
local terminal = "kitty"
local mainMod = "SUPER"

hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = "auto",
})

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.config({
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        touchpad = { natural_scroll = false },
    },
    general = {
        gaps_in = 20,
        gaps_out = 20,
        border_size = 0,
        col = {
            active_border = "rgba(00000000)",
            inactive_border = "rgba(00000000)",
        },
    },
    decoration = {
        rounding = 0,
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
            noise = 0.05,
        },
        shadow = {
            enabled = true,
            range = 1,
            render_power = 1,
            offset = { 5, 5 },
        },
        screen_shader = themeDir .. "/components/gridlines.frag",
    },
    animations = { enabled = true },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
    plugin = {
        hyprbars = {
            bar_height = 40,
            bar_text_size = 17,
            bar_text_font = "FOT-Rodin Pro M",
            bar_text_align = "left",
            bar_color = "rgb(c2bda6)",
            col = { text = "rgb(48463d)" },
        },
    },
})

hl.curve("yorhaInOut", { type = "bezier", points = { {0.65, -0.01}, {0, 0.95} } })
hl.curve("yorhaWoa", { type = "bezier", points = { {0, 0}, {0, 1} } })
hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "windows", enabled = true, speed = 2, bezier = "yorhaWoa", style = "popin" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "yorhaInOut", style = "slide" })

hl.layer_rule({ match = { namespace = "bg_settings" }, blur = true, ignore_alpha = 0.3 })
hl.layer_rule({ match = { namespace = "side" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "bar" }, blur = true, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "geom" }, ignore_alpha = 0 })

hl.window_rule({
    name = "yorha-fly-foot",
    match = { title = "^(fly_is_foot)$" },
    move = { 400, 510 },
})

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal), { description = "Open Kitty" })
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("footclient"), { description = "Open Foot" })
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("ags -b settings -t settings"))
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("ags -b player -t player"))

for i = 1, 9 do
    hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end

hl.on("hyprland.start", function()
    hl.exec_cmd("pkill ags; awww-daemon")
    hl.exec_cmd("sleep 1; awww img " .. themeDir .. "/wallpapers/nier_light.png --transition-type simple --transition-step 255")
    hl.exec_cmd("ags -c " .. themeDir .. "/components/ags/config.js")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
end)
