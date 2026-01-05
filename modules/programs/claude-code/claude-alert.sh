#!/usr/bin/env bash
# Play alert sound for urgent attention (permission/question)

if [[ "$OSTYPE" == "darwin"* ]]; then
    afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
else
    pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null &
fi
