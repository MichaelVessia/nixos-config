#!/usr/bin/env bash
# Play notification sound (cross-platform)

if [[ "$OSTYPE" == "darwin"* ]]; then
    for i in 1 2 3; do afplay /System/Library/Sounds/Glass.aiff 2>/dev/null; done &
else
    for i in 1 2 3; do pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null; done &
fi
