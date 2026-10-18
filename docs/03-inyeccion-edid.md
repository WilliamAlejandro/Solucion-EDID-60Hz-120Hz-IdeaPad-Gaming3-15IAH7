# 03 — Inyección del EDID oficial vía `drm.edid_firmware` (3 iteraciones)

La inyección del EDID no salió a la primera: **3 arranques** con un hallazgo
distinto en cada uno. Cada error está documentado también en
`troubleshooting/edid-3-errores.md`.

## Estado final (lo que quedó instalado en el sistema)

```bash
# 1) EDID saneado (128 bytes) en /lib/firmware (y toplevel)
sudo cp edid_fixed128.bin /usr/lib/firmware/edid/panel60-120.bin
sudo cp edid_fixed128.bin /usr/lib/firmware/panel60-120.bin

# 2) Hook de initramfs para que el archivo viaje dentro del initramfs
#    (i915 hace early-KMS y pide el EDID antes de que el rootfs esté en chaos)
sudo tee /etc/initramfs-tools/hooks/edid-firmware-panel <<'HOOK'
#!/bin/sh
PREREQ=""
prereqs () { echo "$PREREQ"; }
case "$1" in
  prereqs) prereqs; exit 0 ;;
esac
. /usr/share/initramfs-tools/hook-functions
mkdir -p "$DESTDIR/usr/lib/firmware/edid"
cp /usr/lib/firmware/edid/panel60-120.bin "$DESTDIR/usr/lib/firmware/edid/panel60-120.bin"
cp /usr/lib/firmware/panel60-120.bin "$DESTDIR/usr/lib/firmware/panel60-120.bin"
HOOK
sudo chmod +x /etc/initramfs-tools/hooks/edid-firmware-panel

# 3) Parámetro de kernel en GRUB  (¡con prefijo edid/!)
#    /etc/default/grub:
#      GRUB_CMDLINE_LINUX_DEFAULT='quiet splash drm.edid_firmware=eDP-1:edid/panel60-120.bin'
sudo sed -i \
  "s|GRUB_CMDLINE_LINUX_DEFAULT='quiet splash'|GRUB_CMDLINE_LINUX_DEFAULT='quiet splash drm.edid_firmware=eDP-1:edid/panel60-120.bin'|" \
  /etc/default/grub

# 4) Regenerar
sudo update-grub
sudo update-initramfs -u -k all

# 5) Verificar dentro del initramfs
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep panel60
#  usr/lib/firmware/edid/panel60-120.bin
#  usr/lib/firmware/panel60-120.bin
```

Backup del GRUB previo a cualquier cambio: `/etc/default/grub.bak-20261017`.

## Cómo se fabricó el EDID saneado (128 bytes)

Del archivo de 256 bytes extraído del registro de Windows (`02-verificacion`):

```python
b = open('edid_windows.bin','rb').read()
short = b[:128]                 # solo el bloque base (ext count del byte126 = 0)
open('edid_fixed128.bin','wb').write(short)
# md5: f8640ef597e010c60cadb81a2363ae8d
```

Verificación del resultado:

```bash
edid-decode edid_fixed128.bin
# Block 0, Base EDID:
#   DTD 1: 1920x1080  120.002319 Hz  310.470000 MHz
#   DTD 2: 1920x1080   60.003092 Hz  155.240000 MHz
#   Display Range Limits: (vert 60–120 Hz implícito en el descriptor 0xFD)
#   Checksum: 0x69  ✓  (y byte 126 = extension count 0)
```

Todo lo útil está en el bloque base: los 2 DTD, el rango (`0xFD`) y el nombre
(`0xFE`). Los 128 bytes finales eran **relleno en ceros**, y son justamente lo
que hace rechazar el EDID entero en kernels 6.12 (validación estricta).

## Las 3 iteraciones (lo que NO funcionó, y por qué)

### Iteración 1 — archivo faltante en initramfs

`dmesg`: `failed to load panel60-120.bin (-2)` — `ENOENT`.
El hook no existía; el EDID estaba solo en el rootfs, pero i915 pide el EDID
desde el **initramfs** (early-KMS). → Se creó el hook (yes, sí, arriba).

### Iteración 2 — falta el prefijo `edid/` en el parámetro

Con el archivo dentro del initramfs seguía `(-2)`. Clave en `dmesg`:

```
firmware: failed to load panel60-120.bin (-2)        ← sin "edid/"
```

Investigando el código del kernel (`drm_edid_load.c` del 6.12):
`drm.edid_firmware` pasa el nombre **tal cual** al `request_firmware()`; no
anteponer la carpeta. Sintaxis correcta: `eDP-1:edid/panel60-120.bin`.

### Iteración 3 — "Invalid firmware EDID" (256 bytes con relleno)

Con el parametro correcto, la carga **sí** se encuentra el archivo, pero:

```
[drm] *ERROR* Invalid firmware EDID "edid/panel60-120.bin"
```

El kernel valida con `drm_edid_valid()` **estricta** (desde el refactor a
`struct drm_edid`, no repara ni filtra bloques): el `ext count` del bloque base
dice **0 extensiones**, pero el archivo mide 256 bytes. → Se **truncó a 128
bytes** (edid-decode: OK). Caso equivalente documentado en el foro de Raspberry
Pi (ver `referencias.md`).

## Verificación del arranque exitoso

```bash
sudo dmesg | grep -i edid          # SIN errores de firmware EDID
sudo md5sum /sys/class/drm/card0-eDP-1/edid
#  f8640ef597e010c60cadb81a2363ae8d  → EL EDID OVERRIDE ESTÁ ACTIVO
sudo modetest -M i915 -c | sed -n '/eDP-1/,/props:/p'
#  #0 1920x1080 120.00  ... 310470  preferred
#  #1 1920x1080  60.00  ... 155240  ← EL MODO REAL 60Hz YA EXISTE
```

A partir de aquí, aplicar 60 Hz es trivial → `04-aplicar-kscreen-doctor.md`.
