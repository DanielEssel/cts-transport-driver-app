#!/usr/bin/env bash
# Forwards the phone's loopback ports to the emulators on this machine over
# USB, so the emulator build reaches them at 127.0.0.1 (no LAN exposure).
set -euo pipefail
DEVICE="${1:-ZY22JXJ8DS}"
for port in 9099 8080 5001 9199 4400; do
  adb -s "$DEVICE" reverse "tcp:$port" "tcp:$port"
done
adb -s "$DEVICE" reverse --list
