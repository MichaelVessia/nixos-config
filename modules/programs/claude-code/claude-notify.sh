#!/usr/bin/env bash
# Play notification sound (cross-platform)

if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
else
    pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
fi
