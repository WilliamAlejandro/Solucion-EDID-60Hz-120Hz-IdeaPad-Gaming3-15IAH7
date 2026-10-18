# 04 — Aplicar 60 Hz con `kscreen-doctor` y verificar a nivel kernel

Con el modo `60.00` ya publicado por el kernel (gracias al EDID override),
aplicarlo es directo con la herramienta nativa de KDE.

## Aplicar

```bash
# Ver los modos que KScreen ve ahora (el @60 debe existir y el "modo real")
kscreen-doctor -o | grep Modes
#   Modes: 1:1920x1080@120*!  2:1920x1080@60  3:...  (los demás son derivados)

# La tasa se pide TAL COMO SE LISTA (dos dígitos). NOTA:
#   - "@60003" (mHz)  → "Output mode 1920x1080@60003 not found."
#   - "@60000"        → igualmente no reconocido
#   - "@60"           → ✅ correcto
kscreen-doctor output.eDP-1.mode.1920x1080@60
# kscreen.doctor: Found mode "2" "1920x1080@60"
# kscreen.doctor: Output 1 set mode "1920x1080@60"
#   (SIN "El controlador ha rechazado...")
```

## Verificación (multi-nivel)

### KScreen (asterisco = modo activo)

```bash
kscreen-doctor -o | grep Modes | head -1
#   ... 2:1920x1080@60* ...   ← el '*' pasó de 120 a 60
```

### Kernel (autoridad final)

```bash
sudo cat /sys/kernel/debug/dri/0/state | grep 'mode: "1920x1080"'
#   mode: "1920x1080": 60 155240 1920 1968 2000 2200 1080 1083 1089 1176
#                                     ↑ 60.00 Hz con el timing oficial
```

### ID del EDID activo

```bash
sudo md5sum /sys/class/drm/card0-eDP-1/edid
#   f8640ef597e010c60cadb81a2363ae8d  (= nuestro panel60-120.bin saneado)
```

## Persistencia (detalles de KScreen)

- **`kscreen-doctor` NO guarda la configuración**: el JSON de
  `~/.local/share/kscreen/` no se actualiza con este método (solo se guarda al
  aplicar desde Preferencias del sistema).
- Solución adoptada: **autostart de KDE**
  (`~/.config/autostart/edid-60hz.desktop`, incluido en `configs/autostart/`)
  que corre `kscreen-doctor output.eDP-1.mode.1920x1080@60` con `sleep 8`
  tras el login.

## Alternativa de persistencia "nativa"

Abrir **Preferencias del sistema → Pantalla**, seleccionar 60 Hz y **Aplicar**;
KScreen entonces sí escribe el JSON y lo aplicará solo en próximos logins
(identidad por hash de EDID — con el EDID override la identidad cambia a
LEN/LEN156FHD y escribirá una nueva config; no es grave, ambos caminos
convergen a 60 Hz).

## Cambiar de 60 ↔ 120 en caliente

```bash
kscreen-doctor output.eDP-1.mode.1920x1080@120   # volver a 120 Hz
kscreen-doctor output.eDP-1.mode.1920x1080@60    # bajar a 60 Hz
```

## Fechas yEtiquetas

- El parpadeo al cambiar el modo es normal (reprogramación del CRTC).
- Batería: con 60 Hz el consumo del panel baja razonablemente en lectura
  estática; en 120 Hz la fluidez es superior. Tú eliges por sesión con
  `kscreen-doctor` o cambios en Preferencias del sistema.
