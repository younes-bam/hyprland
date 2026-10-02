-- Hyprland 0.55+ configuration. The legacy hyprland.conf remains for older releases.

local home = os.getenv("HOME") or ""
local wal_colors_path = home .. "/.cache/wal/colors-hyprland.lua"
local wal_colors = {}
local colors_ok, colors = pcall(dofile, wal_colors_path)
if colors_ok and type(colors) == "table" then
  wal_colors = colors
end

local accent = wal_colors.accent or "rgba(DAA7A7ff)"
local main_mod = "SUPER"

local terminal = "kitty"
local launcher = home .. "/.config/rofi/dmenu/launcher.sh"
local wallpaper_picker = home .. "/.config/rofi/wallchanger/wallpaperpicker.sh"
local random_wallpaper = home .. "/.local/bin/random_wallpaper.sh"

hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 13,
    border_size = 2,
    col = {
      active_border = accent,
      inactive_border = "rgba(595959aa)",
    },
    resize_on_border = true,
    allow_tearing = false,
    layout = "dwindle",
  },
  decoration = {
    rounding = 15,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = {
      enabled = true,
      size = 7,
      passes = 1,
      vibrancy = 0.1696,
      new_optimizations = true,
      ignore_opacity = true,
      special = true,
    },
  },
  dwindle = { preserve_split = true },
  master = { new_status = "master" },
  misc = {
    force_default_wallpaper = -1,
    disable_hyprland_logo = false,
  },
  input = {
    kb_layout = "fr",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = { natural_scroll = false },
  },
})

-- Preserve the existing animation style and timing.
hl.curve("wind", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("winIn", { type = "bezier", points = { { 0.1, 1.1 }, { 0.1, 1.1 } } })
hl.curve("winOut", { type = "bezier", points = { { 0.3, -0.3 }, { 0, 1 } } })
hl.curve("liner", { type = "bezier", points = { { 1, 1 }, { 1, 1 } } })
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "windows", enabled = true, speed = 6, bezier = "wind", style = "slide" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 6, bezier = "winIn", style = "slide" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "winOut", style = "slide" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "wind" })
hl.animation({ leaf = "border", enabled = true, speed = 1, bezier = "liner" })
hl.animation({ leaf = "fade", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "wind" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "myBezier", style = "slidefade 20%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 4, bezier = "myBezier", style = "fade" })

hl.on("hyprland.start", function()
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_CURRENT_DESKTOP=Hyprland")
  hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
  hl.exec_cmd(home .. "/.local/bin/start_wallpaper.sh")
  hl.exec_cmd(home .. "/.local/bin/battery_notif.sh")
  hl.exec_cmd("hypridle")
  hl.exec_cmd(home .. "/.config/hypr/Scripts/hotcorner.sh")
  hl.exec_cmd("fcitx5")
  hl.exec_cmd(home .. "/.local/bin/volume_notif.sh daemon")
  hl.exec_cmd("waybar")
  hl.exec_cmd("nm-applet --indicator")
  hl.exec_cmd("swaync")
end)

-- Main shortcuts.
hl.bind(main_mod .. " + RETURN", hl.dsp.exec_cmd(terminal))
hl.bind(main_mod .. " + X", hl.dsp.window.close())
hl.bind(main_mod .. " + M", hl.dsp.exit())
hl.bind(main_mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(main_mod .. " + T", hl.dsp.window.float())
hl.bind(main_mod .. " + D", hl.dsp.exec_cmd(launcher))
hl.bind(main_mod .. " + R", hl.dsp.exec_cmd(random_wallpaper))
hl.bind(main_mod .. " + P", hl.dsp.window.pseudo())
hl.bind(main_mod .. " + V", hl.dsp.layout("togglesplit"))
hl.bind(main_mod .. " + W", hl.dsp.exec_cmd(wallpaper_picker))

-- Focus and swap windows with Vim keys or arrow keys.
for key, direction in pairs({ h = "left", j = "down", k = "up", l = "right" }) do
  hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
  hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = direction }))
end
for key, direction in pairs({ left = "left", down = "down", up = "up", right = "right" }) do
  hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
  hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.swap({ direction = direction }))
end

hl.bind(main_mod .. " + SHIFT + C", hl.dsp.exec_cmd("pkill waybar; waybar"))

local workspace_keys = {
  "ampersand", "eacute", "quotedbl", "apostrophe", "parenleft",
  "minus", "egrave", "underscore", "ccedilla", "agrave",
}
for i, key in ipairs(workspace_keys) do
  hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + bracketleft", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(main_mod .. " + SHIFT + RETURN", hl.dsp.exec_cmd("kitty --title=kitty-float"))

-- Screenshots: save in Pictures/Screenshots and copy each image to the clipboard.
local screenshot_dir = home .. "/Pictures/Screenshots"
local function screenshot_command(kind, region_selector)
  local command = "dir='" .. screenshot_dir .. "'; mkdir -p \"$dir\"; "
  if region_selector then
    command = command .. "region=$(slurp " .. region_selector .. ") && [ -n \"$region\" ] && "
  end
  command = command .. "file=\"$dir/$(date +%s%N)_" .. kind .. ".png\" && "
    .. (region_selector and "grim -g \"$region\" \"$file\"" or "grim \"$file\"")
    .. " && wl-copy < \"$file\" && notify-send -t 2300 -i \"$file\" 'Screenshot saved' \"$file\""
  return command
end

hl.bind("PRINT", hl.dsp.exec_cmd(screenshot_command("fullscreen")))
hl.bind(main_mod .. " + PRINT", hl.dsp.exec_cmd(screenshot_command("window", "-w 0")))
hl.bind(main_mod .. " + SHIFT + PRINT", hl.dsp.exec_cmd(screenshot_command("region", "")))
hl.bind(main_mod .. " + CTRL + PRINT", hl.dsp.exec_cmd(screenshot_command("selected", "")))

-- Audio and brightness keys.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(home .. "/.local/bin/volume_notif.sh volume_up"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(home .. "/.local/bin/volume_notif.sh volume_down"), { repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(home .. "/.local/bin/volume_notif.sh volume_mute"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(home .. "/.local/bin/bright_notif.sh 5%+"), { repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(home .. "/.local/bin/bright_notif.sh 5%-"), { repeating = true })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd(home .. "/.config/hypr/Scripts/wlogout.sh"))

-- Window rules carried over from the legacy Hyprland configuration.
hl.window_rule({ match = { title = "^kitty-float$" }, float = true, size = "1300 800", center = true })
hl.window_rule({ match = { class = "^org\\.pulseaudio\\.pavucontrol$" }, float = true, size = "700 500" })
hl.window_rule({ match = { class = "^spotify$" }, opacity = "0.9" })
hl.window_rule({ match = { class = "^legcord$" }, opacity = "0.9" })
hl.window_rule({ match = { class = "^blueman-manager$" }, opacity = "0.8" })
hl.window_rule({ match = { class = "^vscodium$" }, opacity = "0.6" })
hl.window_rule({ match = { class = "^mousepad$" }, opacity = "0.8" })
hl.window_rule({ match = { class = "^rofi$" }, opacity = "0.8" })
hl.window_rule({ match = { class = "^apple-music$" }, opacity = "0.8" })
hl.window_rule({ match = { class = "^xdg-desktop-portal-gtk$" }, float = true, size = "900 600", center = true })

hl.layer_rule({ match = { namespace = "^waybar$" }, blur = false, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "^swaync.*$" }, ignore_alpha = 0 })
hl.layer_rule({ match = { namespace = "^rofi$" }, blur = true, animation = "popin" })
