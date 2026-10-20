#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# privacy-check.sh <feedback.zip> <words-file>: unzips a feedback report into its own folder and looks for each
# word or phrase from the words file (one per line: names, subjects, typed text) in the report's files.
# Anything found is a redaction bug (SHAKE-OUT-PLAN.md, privacy). Prints the file and the line, masked.
ZIP="$1"; WORDS="$2"
[ -f "$ZIP" ] && [ -f "$WORDS" ] || { echo "usage: privacy-check.sh <feedback.zip> <words-file>"; exit 2; }
D="$(mktemp -d /tmp/privacy-check.XXXXXX)"
unzip -oq "$ZIP" -d "$D"
found=0
while IFS= read -r w; do
  [ -n "$w" ] || continue
  hits=$(grep -rIl --fixed-strings -- "$w" "$D" 2>/dev/null)
  if [ -n "$hits" ]; then
    found=$((found+1))
    echo "FOUND \"$(echo "$w" | sed 's/[A-Za-z]/x/g')\" in:"; echo "$hits" | sed "s|$D/||" | sed 's/^/   /'
  fi
done < "$WORDS"
echo "privacy-check: $found of $(grep -c . "$WORDS") words found"
rm -rf "$D"
[ "$found" -eq 0 ]
