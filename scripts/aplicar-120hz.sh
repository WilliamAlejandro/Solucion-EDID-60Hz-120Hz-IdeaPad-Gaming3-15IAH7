#!/bin/bash
# Aplicar 120 Hz al panel eDP-1 (Lenovo IdeaPad Gaming 3 15IAH7)
set -e
kscreen-doctor output.eDP-1.mode.1920x1080@120
echo "Modo aplicado. Corroborar con:"
echo "  sudo cat /sys/kernel/debug/dri/0/state | grep 'mode: \"1920x1080\"'"
