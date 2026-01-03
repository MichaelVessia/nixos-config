{
  lib,
  pkgs,
  ...
}: let
  # Download whisper model (base.en - 142MB, good balance of speed/accuracy)
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    sha256 = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };

  transcribe = pkgs.writeShellScriptBin "transcribe" ''
        #!/usr/bin/env bash
        set -e
        set -u
        set -o pipefail

        VOICE_NOTES_DIR="$HOME/obsidian/VoiceNotes"
        RECORDINGS_DIR="$VOICE_NOTES_DIR/Recordings"
        TRANSCRIPTIONS_DIR="$VOICE_NOTES_DIR/Transcriptions"
        WHISPER_CLI="${pkgs.whisper-cpp}/bin/whisper-cli"
        WHISPER_MODEL="${whisperModel}"

        # Ensure directories exist
        mkdir -p "$TRANSCRIPTIONS_DIR"

        # Find all audio files
        shopt -s nullglob
        files=("$RECORDINGS_DIR"/*.{m4a,mp3,wav,ogg,flac})
        shopt -u nullglob

        if [ ''${#files[@]} -eq 0 ]; then
          echo "No recordings found in $RECORDINGS_DIR"
          exit 0
        fi

        echo "Found ''${#files[@]} recording(s) to transcribe"

        for file in "''${files[@]}"; do
          filename=$(basename "$file")
          name="''${filename%.*}"

          # Parse date from filename (format: YYYYMMDD_HHMMSS)
          if [[ "$name" =~ ^([0-9]{4})([0-9]{2})([0-9]{2})_([0-9]{2})([0-9]{2})([0-9]{2})$ ]]; then
            year="''${BASH_REMATCH[1]}"
            month="''${BASH_REMATCH[2]}"
            day="''${BASH_REMATCH[3]}"
            hour="''${BASH_REMATCH[4]}"
            min="''${BASH_REMATCH[5]}"
            date_formatted="$year-$month-$day $hour:$min"
          else
            date_formatted=$(date +"%Y-%m-%d %H:%M")
          fi

          echo "Transcribing: $filename"

          # Convert to 16kHz WAV (required by whisper.cpp)
          wav_file="$TRANSCRIPTIONS_DIR/$name.wav"
          ${pkgs.ffmpeg}/bin/ffmpeg -i "$file" -ar 16000 -ac 1 -c:a pcm_s16le "$wav_file" -y 2>/dev/null

          # Transcribe with whisper.cpp
          "$WHISPER_CLI" -m "$WHISPER_MODEL" -f "$wav_file" -nt > "$TRANSCRIPTIONS_DIR/$name.txt" 2>/dev/null

          # Clean up temp wav
          rm -f "$wav_file"

          if [ -f "$TRANSCRIPTIONS_DIR/$name.txt" ]; then
            # Read transcription and create markdown
            transcription=$(cat "$TRANSCRIPTIONS_DIR/$name.txt")

            cat > "$TRANSCRIPTIONS_DIR/$name.md" << EOF
    ---
    date: $date_formatted
    tags:
      - voice-note
    ---

    $transcription
    EOF

            rm "$TRANSCRIPTIONS_DIR/$name.txt"
            rm "$file"
            echo "Created: $name.md"
          else
            echo "Failed to transcribe: $filename"
          fi
        done

        echo "Done!"
  '';
in {
  home.packages = [transcribe];
}
