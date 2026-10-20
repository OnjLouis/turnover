#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# step.sh <wait> <drive args...>: sends keys to the front app only if it is the App Store (or $APP), then prints what TurnOver said.
W=$1; shift
L="$(ls -td ~/Library/Application\ Support/TurnOver/logs/* | head -1)"
F=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
[ "$F" = "${APP:-App Store}" ] || { echo "front is $F; nothing sent"; exit 1; }
N=$(( $(wc -l < "$L") + 1 ))
~/Library/Developer/TurnOver/tools/drive "$@"
sleep $W
tail -n +$N "$L" | grep -E "say:|app store|input|ERROR" | grep -v "IO say: \(Bash\|Read\|Run\)" | cut -c1-190
