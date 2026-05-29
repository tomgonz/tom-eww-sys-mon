#!/bin/bash
## -------------------------------------------------------------
## scripts/get_ip.sh – Push IP address into Eww
## -------------------------------------------------------------

PATH=/usr/bin:/usr/local/bin
export PATH

DEV=$(eww get net_dev 2>/dev/null)
ip addr show "$DEV" | grep 'inet ' | awk '{print $2}' | cut -d/ -f1

