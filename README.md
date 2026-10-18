# Solución EDID: Tasa de refresco 60Hz ↔ 120Hz — Lenovo IdeaPad Gaming 3 15IAH7

Documentacion completa de como resolvi el error:

> *"No se ha podido aplicar la configuración de la pantalla: **El controlador ha rechazado la configuración de salida**"*

al intentar bajar el panel de **120 Hz a 60 Hz** en Debian GNU/Linux 13 (trixie), kernel **6.12.107+deb13-amd64**, escritorio **KDE Plasma (Wayland)**.

## TL;DR (qué pasa y qué hace el fix)

- El panel interno **BOE NV156FHM-NX1** (15.6" FHD) **soporta 60 Hz y 120 Hz** (rango oficial en EDID: `60–120`).
- Linux recibe un **EDID corto del panel** que **solo declara 120 Hz**, así que el modo de 60 Hz **no existe** para el kernel; cuando KDE/GNOME intenta pedirlo, el driver lo rechaza.
- Windows usa un **EDID extendido del driver Lenovo** (`LEN9059` / `LEN156FHD`) que declara **ambos modos**: `120.002 Hz` y `60.003 Hz` (pixel clock `155.240 MHz`).
- **Solución:** extraer el EDID oficial de Windows (del registro de `C:`), **recortarlo a 128 bytes** (sane) e **inyectarlo al kernel** con `drm.edid_firmware`, dentro del **initramfs** (i915 arranca en early-KMS).
- Después, en KDE: `kscreen-doctor output.eDP-1.mode.1920x1080@60` — sin rechazo. 

## Estructura

```
├── README.md
├── docs/
│   ├── 01-diagnostico-linux.md        ← como se detecto que faltaba el modo 60Hz
│   ├── 02-verificacion-windows.md     ← montaje de disco C: y el EDID real del panel
│   ├── 03-inyeccion-edid.md           ← drm.edid_firmware + initramfs (3 iteraciones)
│   └── 04-aplicar-kscreen-doctor.md   ← aplicar 60Hz y verificar a nivel kernel
├── configs/
│   ├── grub/                          ← /etc/default/grub actual (con el fix)
│   ├── initramfs/hooks/               ← hook que mete el EDID al initramfs
│   ├── firmware/edid/                 ← panel60-120.bin (128 b) — el EDID saneado
│   └── autostart/                     ← autostart de KDE que aplica 60Hz al login
├── scripts/                           ← aplicar-60hz.sh / aplicar-120hz.sh / verificar.sh
├── troubleshooting/                   ← los 3 errores del camino y su solución
└── referencias.md                     ← fuentes (kernel.org, foro RPi, etc.)
```

## Comandos rápidos (en esta laptop)

```bash
# Cambiar a 60 Hz
kscreen-doctor output.eDP-1.mode.1920x1080@60

# Cambiar a 120 Hz
kscreen-doctor output.eDP-1.mode.1920x1080@120

# Verificar tasa activa (debe decir 60 155240 o 120 310470)
sudo cat /sys/kernel/debug/dri/0/state | grep 'mode: "1920x1080"'

# Verificar que el EDID override este activo (md5 esperado:
# f8640ef597e010c60cadb81a2363ae8d = EDID oficial saneado)
sudo md5sum /sys/class/drm/card0-eDP-1/edid /usr/lib/firmware/edid/panel60-120.bin
```


## Reversión completa (si se necesita)

```bash
# GRUB: restaurar el backup si existe; o equivalentemente editar
# /etc/default/grub quitando drm.edid_firmware=... de GRUB_CMDLINE_LINUX_DEFAULT
sudo cp /etc/default/grub.bak-20261017 /etc/default/grub && sudo update-grub
```

```bash
# Retirar el resto de piezas:
sudo rm -f /usr/lib/firmware/edid/panel60-120.bin /usr/lib/firmware/panel60-120.bin
sudo rm -f /etc/initramfs-tools/hooks/edid-firmware-panel
rm -f ~/.config/autostart/edid-60hz.desktop
sudo update-initramfs -u -k all
```

## Estado final

| Ítem | Valor |
|---|---|
| Laptop | Lenovo IdeaPad Gaming 3 15IAH7 (82S9) |
| GPU interna | Intel UHD (Alder Lake-P, driver `i915`) — panel eDP-1 |
| GPU dGPU | NVIDIA RTX 3060 Mobile (`nvidia`, para HDMI externo) |
| Panel | BOE NV156FHM-NX1, EDID override `LEN156FHD` |
| Modos kernel | `120.00 Hz (310.470 MHz)` + `60.00 Hz (155.240 MHz)` |
| EDID activo (md5) | `f8640ef597e010c60cadb81a2363ae8d` |
