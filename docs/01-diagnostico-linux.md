# 01 — Diagnóstico en Linux: ¿por qué fallaba el cambio a 60 Hz?

## Síntoma

En **Preferencias del sistema → Pantalla** (KDE Plasma, Wayland), al seleccionar
`1920x1080@60` y aplicar:

> *"No se ha podido aplicar la configuración de la pantalla: **El controlador ha
> rechazado la configuración de salida**"*

## Contexto del equipo

```bash
# Cómo llegar a estas conclusiones (todos comandos solo lectura)

# Escritorio y sesión
echo $XDG_SESSION_TYPE                  # wayland
pgrep -a gnome-shell >/dev/null && echo GNOME || true
busctl --user list | grep -E "kwin_wayland|plasmashell"   # → KDE Plasma

# GPUs (híbrida Optimus)
lspci | grep -iE "vga|3d|display"
#  00:02.0 VGA compatible: Intel Alder Lake-P GT1 [UHD Graphics]  ← panel interno
#  01:00.0 VGA compatible: NVIDIA GA106M [RTX 3060 Mobile / Max-Q]
lspci -k | grep -A 3 Alder              # Kernel driver in use: i915

# Kernel y distro
uname -r                                # 6.12.107+deb13-amd64
cat /etc/os-release | head -2           # Debian GNU/Linux 13 (trixie)

# Modelo de laptop (solo lectura)
cat /sys/class/dmi/id/product_family    # IdeaPad Gaming 3 15IAH7
```

## El conector del panel: `eDP-1` (i915) y sus modos

```bash
sudo modetest -M i915 -c | sed -n '/eDP-1/,/props:/p'
# 241  240  connected  eDP-1  340x190   1  240
#  modes:
#  index name        refresh (Hz) ...
#  #0    1920x1080   120.00 1920 1968 2000 2200 1080 1083 1089 1176 310470
#        flags: phsync, nvsync; type: preferred, driver
```

**Solo existe UN modo en el kernel: 120 Hz.** (El `modetest` está en el paquete
`libdrm-tests`.)

## El EDID que Linux recibe del panel

```bash
sudo md5sum /sys/class/drm/card0-eDP-1/edid
# 432e6858cdcb73c57cd8181959ad2cb3   (128 bytes)
```

Decodificado (128 bytes): vendor **BOE**, producto **NV156FHM-NX1**,
un único DTD `1920x1080 @ 120.002 Hz`, **sin descriptor de rangos**.

## Modo "fantasma": la causa del mensaje de error

KScreen lista modos **estándar derivados** (1280x720@60, 1600x900@60,
`1920x1080@60`…) aunque el kernel no los tenga:

```bash
kscreen-doctor -o
# Output: 1 eDP-1
#   Modes: 1:1920x1080@120*!  2:1280x1024@60  ... 8:1920x1080@60 ...
```

Al intentar aplicar el modo fantasma:

```bash
kscreen-doctor output.eDP-1.mode.8
# kscreen.doctor: Found mode "8" "1920x1080@60"
# applying config failed! El controlador ha rechazado la configuración de salida
```

**Moral:** el error del "controlador" no es un bug del driver — es que el modo
no existe en el conector porque el EDID del panel no lo declara.

## Referencia de datos clave

- Panel: BOE NV156FHM-NX1 (15.6" FHD IPS 120 Hz) — ficha en referencias.md
- EDID Linux: md5 `432e6858cdcb73c57cd8181959ad2cb3` (128 bytes, 1 modo 120 Hz)
- Conector: `eDP-1` en `card0` (i915); la RTX 3060 es `card1` (nvidia-drm)
