# Troubleshooting — Los 3 errores del camino (EDID / refresco)

## Resumen

| # | Mensaje | Causa | Solución |
|---|---|---|---|
| 1 | `Requesting EDID firmware "panel60-120.bin" failed (err=-2)` | El EDID no estaba dentro del initramfs (i915 arranca en early-KMS y pedido antes del rootfs) | hook de initramfs-tools que copia el EDID al initramfs |
| 2 | `failed to load panel60-120.bin (-2)` **aún con el archivo** en el initramfs | El parámetro no tenía el prefijo `edid/`; kernel 6.12 no lo añade por ti | `drm.edid_firmware=eDP-1:edid/panel60-120.bin` |
| 3 | `Invalid firmware EDID "edid/panel60-120.bin"` | EDID de Windows de 256 bytes con **128 bytes de relleno en ceros**; el `ext count` del bloque base declara 0, y la validación del kernel 6.12 (`drm_edid_valid` estricta) rechaza el archivo entero | truncar el EDID a 128 bytes (queda solo el bloque base completo: 2 DTD + rango + nombre + checksum correcto) |

## Detalle 1: `-2` (ENOENT) por early-KMS

El panel `eDP-1` lo maneja `i915`, que Debian carga desde el **initramfs**
(modules instalados via initramfs-tools con early-KMS). El EDID override se
pide en la inicialización del conector ⇒ si el `.bin` no está dentro del
initramfs, falla aunque exista en el rootfs.

Verificar:

```bash
sudo dmesg | grep -i "edid" | head
sudo lsinitramfs /boot/initrd.img-$(uname -r) | grep panel60
```

Arreglo: hook en `/etc/initramfs-tools/hooks/` + `update-initramfs -u -k all`
(los pasos completos en `docs/03-inyeccion-edid.md`).

## Detalle 2: el prefijo `edid/`

Código relevante del kernel (drivers/gpu/drm/drm_edid_load.c, 6.12):
`edid_load(connector, name)` hace `request_firmware(&fw, name, ...)` con el
nombre **tal cual** lo escribes. Sin prefijo, busca en `/lib/firmware/panel60-120.bin`
a secas — y ahí no estaba.

Sintaxis que funciona:

```
drm.edid_firmware=eDP-1:edid/panel60-120.bin
```

(también corrobora documentación del kernel: `admin-guide/edid`).

## Detalle 3: EDID "con relleno" y validación estricta

El EDID del registro de Windows es de **256 bytes**, pero su bloque base dice
`0` extensiones (byte 126 = 0) y los últimos 128 bytes son ceros. Trim
antiguo: el validador del kernel (refactor de Jani Nikula, 2022, "strict
validation") exige coherencia tamaño↔ext-count, y las extensiones no pueden
ser bloque 0x00-muerto ⇒ **rechaza el EDID entero** con:

```
[drm] *ERROR* Invalid firmware EDID "edid/panel60-120.bin"
```

Caso análogo en la web (foro Raspberry Pi): *"EDID specified 2 extension
block(s), but found 1... the kernel is behaving as expected... Correcting the
edid file and loading the fixed one with drm.edid_firmware is the solution"*.

## Bonus: "El controlador ha rechazado la configuración de salida"

Este mensaje (mismo txt en KDE y en settings de GNOME) NO es un bug del
driver: significa que se le pidió al kernel un modo que **no existe** en el
conector. La GUI (KScreen / GNOME Displays) lista modos "fantasma"
estándar/derivados, pero el commit de DRM los rechaza. Con el EDID override
los modos son reales y el commit pasa limpio.
