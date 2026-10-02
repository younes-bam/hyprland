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

if ! command -v awww >/dev/null 2>&1 || ! command -v awww-daemon >/dev/null 2>&1; then
  notify-send "Wallpaper" "awww is not installed; finish the package installation first." 2>/dev/null || true
  exit 1
fi

# Start the daemon here so the wallpaper waits for the process it depends on.
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/hyprdots"
if ! awww query >/dev/null 2>&1; then
  mkdir -p "$state_dir"
  awww-daemon --quiet >"$state_dir/awww.log" 2>&1 &
fi

for _ in {1..80}; do
  if awww query >/dev/null 2>&1; then
    if awww img "$wallpaper" --transition-type simple; then
      exit 0
    fi
    notify-send "Wallpaper" "awww could not display the selected image." 2>/dev/null || true
    exit 1
  fi
  sleep 0.25
done

query_error=$(awww query 2>&1 || true)
notify-send "Wallpaper" "awww did not start: ${query_error:-unknown error}. Log: $state_dir/awww.log" 2>/dev/null || true
exit 1
