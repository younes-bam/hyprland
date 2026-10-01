#!/usr/bin/env bash
set -euo pipefail

wallpaper="${1:-}"
if [[ -z "$wallpaper" || ! -f "$wallpaper" ]]; then
  notify-send "Wallpaper" "The selected image could not be found." 2>/dev/null || true
  exit 1
fi

wallpaper=$(realpath "$wallpaper")
wall_link="$HOME/.config/hypr/current_hyprlock_wallpaper.jpg"

wal -i "$wallpaper" -n -q
ln -sfn "$wallpaper" "$wall_link"
swww img "$wallpaper" --transition-type wipe --transition-angle 30 --transition-step 90

# Reload Hyprland colors and let Waybar detect the regenerated Pywal stylesheet.
hyprctl reload
swaync-client -rs >/dev/null 2>&1 || true
swaync-client -R >/dev/null 2>&1 || true
notify-send "Environment Updated" "Wallpaper set to: $(basename "$wallpaper")" -i "$wallpaper" -a "System" --hint=string:resident:false
