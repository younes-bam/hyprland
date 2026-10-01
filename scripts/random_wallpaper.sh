#!/usr/bin/env bash
set -euo pipefail

wall_dir="$HOME/Pictures/wallpaper"
mapfile -d '' wallpapers < <(find "$wall_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 2>/dev/null)

if [[ ${#wallpapers[@]} -eq 0 ]]; then
  notify-send "Wallpaper" "No wallpapers found in $wall_dir." 2>/dev/null || true
  exit 1
fi

selected="${wallpapers[RANDOM % ${#wallpapers[@]}]}"
exec "$HOME/.local/bin/apply_wallpaper.sh" "$selected"
