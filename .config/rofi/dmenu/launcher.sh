#!/usr/bin/env bash

## Author : Aditya Shakya (adi1090x)
## Github : @adi1090x
##Modder:norefz
#
## Rofi   : Launcher (Modi Drun, Run, File Browser, Window)
#
## Available Styles
#
## style-1     style-2     style-3     style-4     style-5
## style-6     style-7     style-8     style-9     style-10

theme="$HOME/.config/rofi/dmenu/style-1.rasi"
colors="$HOME/.cache/wal/colors-rofi-dark.rasi"
wallpaper="$HOME/.config/hypr/current_hyprlock_wallpaper.jpg"

if [[ -f "$theme" && -f "$colors" && -f "$wallpaper" ]]; then
  exec rofi -show drun -theme "$theme"
fi

# Keep the launcher available until the wallpaper and Pywal colors are initialized.
exec rofi -show drun
