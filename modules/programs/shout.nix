{
  lib,
  pkgs,
  ...
}: let
  # Download whisper model (base.en - 142MB, English-only, more accurate)
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    sha256 = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };

  # Wrap the shout script with proper paths
  shout = pkgs.writeShellScriptBin "shout" ''
    #!/bin/bash
    #
    # shout - Simple speech-to-text for Wayland
    #
    # Press keybind once to start recording, again to stop and transcribe.
    # Text is automatically typed into the focused application.

    STATE_FILE="/tmp/shout.pid"
    AUDIO_FILE="/tmp/shout.wav"
    WHISPER_CLI="${pkgs.whisper-cpp}/bin/whisper-cli"
    WHISPER_MODEL="${whisperModel}"

    if [[ -f "$STATE_FILE" ]]; then
        # Stop recording
        kill "$(cat "$STATE_FILE")" 2>/dev/null
        rm "$STATE_FILE"

        ${pkgs.libnotify}/bin/notify-send -t 1000 -h string:x-canonical-private-synchronous:shout "shout" "Processing..."

        # Transcribe (strip leading whitespace)
        TEXT=$("$WHISPER_CLI" -m "$WHISPER_MODEL" --no-timestamps "$AUDIO_FILE" 2>/dev/null | grep -v '^\[' | sed 's/^[[:space:]]*//' | tr -d '\n')

        # Type it out and press Enter
        if [[ -n "$TEXT" ]]; then
            ${pkgs.ydotool}/bin/ydotool type "$TEXT"
            ${pkgs.ydotool}/bin/ydotool key 28:1 28:0  # Enter key press and release
            ${pkgs.libnotify}/bin/notify-send -t 1000 -h string:x-canonical-private-synchronous:shout "shout" "Done"
        else
            ${pkgs.libnotify}/bin/notify-send -t 2000 -h string:x-canonical-private-synchronous:shout "shout" "No speech detected"
        fi

        rm -f "$AUDIO_FILE"
    else
        # Start recording
        ${pkgs.libnotify}/bin/notify-send -t 0 -h string:x-canonical-private-synchronous:shout "shout" "Recording..."
        ${pkgs.pipewire}/bin/pw-record --rate=16000 --channels=1 --format=s16 "$AUDIO_FILE" &
        echo $! > "$STATE_FILE"
    fi
  '';
in {
  home.packages = [shout];
}
