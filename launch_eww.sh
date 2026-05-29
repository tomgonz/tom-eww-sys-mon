#!/bin/bash
## -------------------------------------------------------------
## launch_eww.sh – Starts this EWW config
## -------------------------------------------------------------

PATH=/usr/bin:/usr/sbin:/usr/local/bin
export PATH

# Kill existing instances to avoid "daemon already running" errors
eww kill

# Kill script that get disk and network data
pkill -f disk-net-max.lua

sleep 1

# Start the bar (the daemon starts automatically with 'open')
eww open sys-mon

# Need to start eww first, as the lua gets the graph_width or sample size from eww.
# Start script for disk and network data
${HOME}/.config/eww/scripts/disk-net-max.lua > /dev/null 2>&1 &

