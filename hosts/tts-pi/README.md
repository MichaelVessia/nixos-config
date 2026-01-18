# tts-pi

Raspberry Pi 3 running NixOS with Snapcast for TTS announcements.

## What it does

- Snapserver + Snapclient for audio streaming
- TTS HTTP server on port 5000
- Audio output via 3.5mm jack to Onkyo AUX input
- Snapweb UI at http://192.168.1.37:1780

## Building the image

Requires aarch64 emulation on your build machine. Enable in framework13 config:

```nix
boot.binfmt.emulatedSystems = ["aarch64-linux"];
```

Then rebuild framework13:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#framework13
```

Build the Pi image:

```bash
cd ~/nixos-config
nix build .#images.tts-pi
```

## Flashing

```bash
# Find USB device
lsblk

# Decompress and flash (replace sdX)
zstd -d result/sd-image/*.img.zst -o tts-pi.img
sudo dd if=tts-pi.img of=/dev/sdX bs=4M status=progress
sync
```

## First boot

1. Insert USB into Pi
2. Boot and wait ~1-2 min
3. SSH in: `ssh pi@192.168.1.37`

## Testing

```bash
# Test TTS
curl -X POST http://192.168.1.37:5000 \
  -H "Content-Type: application/json" \
  -d '{"message":"hello from nixos"}'

# Check services
ssh pi@192.168.1.37 'systemctl status snapserver snapclient tts-server'
```

## Updating

After making config changes:

```bash
# From your machine
nixos-rebuild switch --flake ~/nixos-config#tts-pi --target-host pi@192.168.1.37
```

## Architecture

```
Home Assistant → curl Pi:5000 → tts_server.py → tts.sh
    → Google TTS → ffmpeg → /run/snapserver/fifo
    → snapserver → snapclient → 3.5mm → Onkyo AUX → speakers
```

Speaker zone selection is handled by Home Assistant, not the Pi.
