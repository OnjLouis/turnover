#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# sweep-try.sh <bundle id> <mask 0|1> <keys…>: lets TurnOver's try run keys in the app for this call only
# (consent added, then removed), prints what TurnOver said. mask=1 hides words not in the UI word list.
B="$1"; M="$2"; shift 2
# Never while the user is at the keyboard: the last input must be ours (try's own keys) or 20 s old.
I=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF/1000000000); exit}')
LAST=$(cat /tmp/to-sweep-at 2>/dev/null || echo 0); SINCE=$(( $(date +%s) - LAST ))
if [ "$I" -lt 20 ] && [ $(( SINCE - I )) -gt 3 ]; then echo "USER ACTIVE (input $I s ago): not tried"; exit 3; fi
TP=/Applications/TurnOver.app/Contents/MacOS/turnover-plugin
defaults write com.turnover.reader pluginTryConsent -dict "$B" -date "$(date -u -v+10M '+%Y-%m-%d %H:%M:%S +0000')"
OUT=$($TP try "$B" "$@" 2>&1)
defaults delete com.turnover.reader pluginTryConsent 2>/dev/null
date +%s > /tmp/to-sweep-at
if [ "$M" = 1 ]; then print -r -- "$OUT" | python3 -I ~/Library/Developer/TurnOver/tools/sweep-mask.py; else print -r -- "$OUT"; fi
