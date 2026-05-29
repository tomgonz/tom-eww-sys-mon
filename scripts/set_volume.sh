#!/bin/bash

PATH=/usr/bin:/usr/local/bin
export PATH

wpctl set-volume @DEFAULT_AUDIO_SINK@ "$1"
NEW_VOLUME=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{print int($2 * 100)}')
eww update volume_value="$NEW_VOLUME"
