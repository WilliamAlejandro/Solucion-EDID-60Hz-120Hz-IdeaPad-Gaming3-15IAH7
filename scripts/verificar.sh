#!/bin/bash
# Verificacion del fix EDID / tasa de refresco
echo "=== 1. Modo activo del CRTC (60=155240 / 120=310470) ==="
cat /sys/kernel/debug/dri/0/state 2>/dev/null | grep 'mode: "1920x1080"' || \
  sudo cat /sys/kernel/debug/dri/0/state | grep 'mode: "1920x1080"'

echo ""
echo "=== 2. EDID activo (esperado: f8640ef597e010c60cadb81a2363ae8d) ==="
sudo md5sum /sys/class/drm/card0-eDP-1/edid

echo ""
echo "=== 3. Modos publicados por el kernel ==="
sudo modetest -M i915 -c 2>/dev/null | sed -n '/eDP-1/,/props:/p' | head -9
