#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Installs the parts-sweep apps from Homebrew, in priority order, keeping at least 8 GB free.
FLOOR=8
for c in firefox libreoffice audacity visual-studio-code slack musescore keepassxc localsend pdfsam-basic \
         thunderbird discord obsidian spotify obs appflowy reaper iterm2 intellij-idea; do
  free=$(df -g /System/Volumes/Data | awk 'NR==2{print $4}')
  if (( free < FLOOR + 2 )); then echo "SKIPPED $c: only ${free} GB free"; continue; fi
  if brew list --cask $c >/dev/null 2>&1; then echo "ALREADY $c"; continue; fi
  if brew install --cask $c </dev/null >/tmp/sweep-$c.log 2>&1; then echo "OK $c"; else echo "FAILED $c: $(tail -2 /tmp/sweep-$c.log | tr '\n' ' ')"; fi
  rm -f "$(brew --cache --cask $c 2>/dev/null)"
done
echo "FREE $(df -h /System/Volumes/Data | awk 'NR==2{print $4}')"
