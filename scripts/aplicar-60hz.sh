#!/bin/bash
# Aplicar 60 Hz al panel eDP-1 (Lenovo IdeaPad Gaming 3 15IAH7)
# Requiere: EDID override cargado (drm.edid_firmware) — ver el README.md
set -e
kscreen-doctor output.eDP-1.mode.1920x1080@60
echo "Modo aplicado. Corroborar con:"
echo "  sudo cat /sys/kernel/debug/dri/0/state | grep 'mode: \"1920x1080\"'"
