#!/bin/bash

PATH=/usr/bin:/usr/local/bin
export PATH

wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

if wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -q MUTED; then
    eww update is_muted="MUTED"
else
    eww update is_muted="MUTE"
fi
