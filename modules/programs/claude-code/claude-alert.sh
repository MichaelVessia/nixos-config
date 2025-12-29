#!/usr/bin/env bash
# Play alert sound for urgent attention (permission/question)

if [[ "$OSTYPE" == "darwin"* ]]; then
    for i in 1 2 3; do afplay /System/Library/Sounds/Sosumi.aiff 2>/dev/null; done &
else
    for i in 1 2 3; do pw-play /run/current-system/sw/share/sounds/freedesktop/stereo/bell.oga 2>/dev/null; done &
fi
