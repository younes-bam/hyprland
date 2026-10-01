#!/bin/bash

brightness_step=$1
notification_timeout=2000

if ! brightnessctl s "$brightness_step"; then
  notify-send "Brightness" "No adjustable backlight device was found." 2>/dev/null || true
  exit 0
fi

val=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
if [[ ! "$val" =~ ^[0-9]+$ ]]; then
  notify-send "Brightness" "Could not read the current brightness." 2>/dev/null || true
  exit 0
fi

if [ "$val" -le 30 ]; then
  icon="$HOME/.local/bin/icons/brightness_low.svg"
elif [ "$val" -le 50 ]; then
  icon="$HOME/.local/bin/icons/brightness_med.svg"
elif [ "$val" -le 70 ]; then
  icon="$HOME/.local/bin/icons/brightness_medium.svg"
elif [ "$val" -le 100 ]; then
  icon="$HOME/.local/bin/icons/brightness_high.svg"

fi

icon_args=()
[[ -f "$icon" ]] && icon_args=(-i "$icon")

notify-send -e -t $notification_timeout \
  -a "SwayNC_Brightness" \
  -h string:x-canonical-private-synchronous:brightness_notif \
  -h int:value:"$val" \
  "${icon_args[@]}" \
  "Brightness" "$val%"
