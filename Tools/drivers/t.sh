#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# t.sh <app name> <mask 0|1> <wait> <drive args…>: runs keys in an app only if the user is idle and the app is in front,
# then prints what TurnOver did (spoken words masked when mask=1). Exit 3: user active; 4: app not in front.
# Idle: the Mac's input idle time, unless the last input was our own drive (its time is kept in /tmp/to-drive-at).
APP="$1"; MASK="$2"; W="$3"; shift 3
T=~/Library/Developer/TurnOver/tools
I=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
NOW=$(date +%s); LAST=$(cat /tmp/to-drive-at 2>/dev/null || echo 0)
SINCE=$(( NOW - LAST ))
# Our own keys explain the idle time if it matches the time since we drove (within 3 s).
# Someone else typed if the last input came well after our last keys, and recently.
if [ "$I" -lt 25 ] && [ $(( SINCE - I )) -gt 3 ]; then echo "USER ACTIVE ($I s, ours $SINCE s ago)"; exit 3; fi
if [ "$1" != "" ]; then :; fi
F=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
[ "$F" = "$APP" ] || { echo "FRONT IS $F, not $APP"; exit 4; }
L="$(ls -td ~/Library/Application\ Support/TurnOver/logs/* | head -1)"
N=$(( $(wc -l < "$L") + 1 ))
$T/drive "$@"
date +%s > /tmp/to-drive-at
sleep $W
if [ "$MASK" = 1 ]; then $T/maskedlog.py "$L" $N
else tail -n +$N "$L" | grep -a "input kb\|say:\|ERROR\|WARN\|media:\|chat:\|menu opened\|app activated\|hung\|watchdog\|not responding" | grep -av "speech: first" | cut -c1-170; fi
