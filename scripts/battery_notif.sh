#!/bin/bash

#!/usr/bin/env bash

BAT_PATH=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' -print -quit)
if [[ -z "$BAT_PATH" || ! -r "$BAT_PATH/status" || ! -r "$BAT_PATH/capacity" ]]; then
  exit 0
fi

LOW_BATTERY=20
CRITICAL_BATTERY=10
LAST_STATUS=$(<"$BAT_PATH/status")
LOW_ALERT_SENT=false
CRITICAL_ALERT_SENT=false

while true; do
  BATTERY_LEVEL=$(<"$BAT_PATH/capacity")
  BATTERY_STATUS=$(<"$BAT_PATH/status")

  if [[ "$BATTERY_STATUS" != "$LAST_STATUS" ]]; then
    if [[ "$BATTERY_STATUS" == "Charging" ]]; then
      notify-send -u normal "Power connected" "Battery is charging (${BATTERY_LEVEL}%)"
    elif [[ "$BATTERY_STATUS" == "Discharging" ]]; then
      notify-send -u normal "Power disconnected" "Running on battery (${BATTERY_LEVEL}%)"
    fi
    LAST_STATUS="$BATTERY_STATUS"
  fi

  if [[ "$BATTERY_STATUS" == "Discharging" ]]; then
    if (( BATTERY_LEVEL > LOW_BATTERY )); then
      LOW_ALERT_SENT=false
      CRITICAL_ALERT_SENT=false
    elif (( BATTERY_LEVEL <= CRITICAL_BATTERY )) && [[ "$CRITICAL_ALERT_SENT" == false ]]; then
      notify-send -u critical "Critical battery" "Battery level: ${BATTERY_LEVEL}%"
      LOW_ALERT_SENT=true
      CRITICAL_ALERT_SENT=true
    elif (( BATTERY_LEVEL <= LOW_BATTERY )) && [[ "$LOW_ALERT_SENT" == false ]]; then
      notify-send -u normal "Low battery" "Battery level: ${BATTERY_LEVEL}%"
      LOW_ALERT_SENT=true
    fi
  else
    LOW_ALERT_SENT=false
    CRITICAL_ALERT_SENT=false
  fi

  sleep 15
done
