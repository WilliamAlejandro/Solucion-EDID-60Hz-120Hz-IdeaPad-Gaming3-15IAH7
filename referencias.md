# Referencias

## Fuentes consultadas durante la investigación

1. **Código del kernel** — el validador y loader de EDID por firmware:
   - `drivers/gpu/drm/drm_edid_load.c` (6.12):
     https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/drm_edid_load.c
   - `edid_load()` hace `request_firmware(&fw, name, ...)` **con el nombre tal
     cual** — de ahí la necesidad del prefijo `edid/` en el parámetro.
   - Refactor estricto de validación (Jani Nikula, dri-devel, octubre 2022):
     https://lists.freedesktop.org/archives/dri-devel/2022-October/376370.html
     *(“no longer tries to fix errors or filter invalid blocks. It's stricter”)*

2. **Documentación del kernel** — parámetros EDID:
   - EDID override via boot params:
     https://www.kernel.org/doc/html/latest/admin-guide/edid.html
   - Formato: `drm.edid_firmware=<conector>:edid/<archivo>.bin`

3. **Caso análogo documentado** (foro Raspberry Pi) — ediD "con relleno/padding"
   rechazado por validación estricta; solución: corregir el archivo:
   https://forums.raspberrypi.com/viewtopic.php?t=384503

4. **Ficha técnica del panel** — BOE NV156FHM-NX1 (15.6" FHD IPS 120 Hz):
   - https://www.panelook.com/NV156FHM-NX1_BOE_15.6_LCM_overview_45539.html
   - https://laptopmedia.com/screen/boe-nv156fhm-nx1-boe0a81/
