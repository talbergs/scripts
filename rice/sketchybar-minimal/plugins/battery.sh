#!/usr/bin/env bash

# Battery plugin

BLACK=0xff181926
GREEN=0xffa6da95
YELLOW=0xffeed49f
RED=0xffed8796

# Get battery info
BATTERY_INFO=$(pmset -g batt)
PERCENTAGE=$(echo "$BATTERY_INFO" | grep -Eo "\d+%" | cut -d% -f1)
CHARGING=$(echo "$BATTERY_INFO" | grep 'AC Power')

# Determine icon
if [[ $CHARGING != "" ]]; then
    ICON="󰂄"  # Charging icon
else
    ICON="󰁹"  # Battery icon
fi

# Determine color based on percentage
if [ "$PERCENTAGE" -lt 20 ]; then
    BG_COLOR=$RED
elif [ "$PERCENTAGE" -lt 50 ]; then
    BG_COLOR=$YELLOW
else
    BG_COLOR=$GREEN
fi

sketchybar --set $NAME \
    icon="$ICON" \
    icon.color=$BLACK \
    label="${PERCENTAGE}%" \
    label.color=$BLACK \
    background.color=$BG_COLOR
