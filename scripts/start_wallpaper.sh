#!/usr/bin/env bash
set -euo pipefail

wall_dir="$HOME/Pictures/wallpaper"
wall_link="$HOME/.config/hypr/current_hyprlock_wallpaper.jpg"
wallpaper=""

if [[ -L "$wall_link" && -f "$wall_link" ]]; then
  wallpaper=$(readlink -f "$wall_link")
elif [[ -f "$wall_link" ]]; then
  wallpaper="$wall_link"
fi

if [[ -z "$wallpaper" ]]; then
  wallpaper=$(find "$wall_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)
fi

[[ -n "$wallpaper" && -f "$wallpaper" ]] || exit 0
ln -sfn "$wallpaper" "$wall_link"

# swww-daemon is launched separately by Hyprland; wait briefly for its socket.
for _ in {1..20}; do
  if swww query >/dev/null 2>&1; then
    exec swww img "$wallpaper" --transition-type simple
  fi
  sleep 0.25
done

notify-send "Wallpaper" "swww did not become ready; wallpaper was not applied." 2>/dev/null || true
exit 1
