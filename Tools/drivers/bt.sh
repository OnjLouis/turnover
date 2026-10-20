#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# bt.sh <App> <wait> keys…: like t.sh, but prints what is said AND what the braille display shows.
APP="$1"; W="$2"; shift 2
L="$(ls -td ~/Library/Application\ Support/TurnOver/logs/* | head -1)"
N=$(( $(wc -l < "$L") + 1 ))
~/Library/Developer/TurnOver/tools/t.sh "$APP" 0 "$W" "$@" | grep -a "USER ACTIVE\|FRONT"
tail -n +$N "$L" | grep -a "input kb\|say:\|braille shows" | sed -E 's/IO say: (.{0,70}).*/  SAY  \1/; s/IO braille shows /  BRL  /; s/IO input /KEY /' | cut -c1-120
