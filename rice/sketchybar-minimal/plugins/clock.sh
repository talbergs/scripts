#!/usr/bin/env bash

# Clock plugin

BLACK=0xff181926

TIME=$(date '+%H:%M')
DATE=$(date '+%a %d %b')

sketchybar --set $NAME \
    label="$TIME $DATE" \
    label.color=$BLACK
