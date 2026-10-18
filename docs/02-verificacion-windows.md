# 02 — Verificación del EDID real: montar C: de Windows

## Objetivo

Confirmar **qué tasas soporta de verdad el panel**. Como Windows corría el
mismo hardware, su configuración (`C:`) es la fuente de verdad del EDID que el
driver de Lenovo en Windows publica.

> Todos los comandos usan `sudo` (pedirá contraseña en el momento; nada queda
> guardado en este repo).

## 1. Montar la partición de Windows en solo lectura

```bash
sudo mkdir -p /tmp/opencode/winc
sudo mount -o ro /dev/nvme0n1p3 /tmp/opencode/winc   # nvme0n1p3 = SYSTEM (NTFS)
ls /tmp/opencode/winc/ | head                        # verificación
```

## 2. Encontrar el EDID del monitor en el registro de Windows

Herramientas (`reglookup`, `libhivex-bin`, `python3-hivex`, `edid-decode`):

```bash
sudo apt install -y reglookup libhivex-bin python3-hivex edid-decode

# Localizar el monitor (el vendor interno es "LEN", no "BOE")
reglookup /tmp/opencode/winc/Windows/System32/config/SYSTEM \
  | grep -E 'Enum\\DISPLAY' | head

# → /ControlSet001/Enum/DISPLAY/LEN9059/4&<id>&0&UID<nnnnnn>/Device Parameters/EDID
```

## 3. Extraer el binario EDID con hivex (Python)

```python
import hivex, hashlib
h = hivex.Hivex("/tmp/opencode/winc/Windows/System32/config/SYSTEM")
node = h.root()
for part in ["ControlSet001", "Enum", "DISPLAY", "LEN9059",
             "4&<id>&0&UID<nnnnnn>", "Device Parameters"]:
    node = h.node_get_child(node, part)
for v in h.node_values(node):
    if h.value_key(v) == "EDID":
        edid = h.value_value(v)[1]           # bytes
open("edid_windows.bin", "wb").write(edid)
print(len(edid), hashlib.md5(edid).hexdigest())
# → 256 bytes, md5 a25045ec04fe0d2ba75c1b353a3e5c8c
```

## 4. Decodificación: la respuesta

Con `edid-decode` (más un mini-parse de DTDs en Python):

| Hallazgo | Valor |
|---|---|
| DTD 1 | `1920x1080 @ 120.002 Hz` (pixel clock `310.470 MHz`, htotal 2200, vtotal 1176) |
| DTD 2 | `1920x1080 @ 60.003 Hz` (**pixel clock `155.240 MHz`**, mismo blanking) |
| Descriptor de rangos (`0xFD`) | **Vertical: min 60 Hz — max 120 Hz** |
| Nombre (`0xFE`) | `LEN156FHD` |
| Vendor/Modelo | LEN, Model 36953 (0x9059) |

**El panel soporta exactamente 60 Hz y 120 Hz** — como sospechábamos.

## 5. Corroborar con la sesión gráfica de Windows

El registro guarda el modo que Windows **estaba usando**:

```
ControlSet001\Control\GraphicsDrivers\Configuration\LEN90590_...\00\00\
  VSyncFreq.Numerator   = 0x0940C640  (=155,240,000)
  VSyncFreq.Denominator = 0x00277A40  (=2,587,968)
  → 155240000/2587200 = 60.003 Hz
```

Windows corría el panel a **60 Hz con el timing del DTD 2**.

## 6. Comparación Linux vs Windows

| | Linux (sysfs) | Windows (LEN9059) |
|---|---|---|
| Bytes | 128 | 256 (128 + relleno en ceros) |
| DTDs | solo 120 Hz | 120 Hz **y** 60 Hz |
| Rango | (no declara) | 60–120 Hz |
| Vendor | BOE / NV156FHM-NX1 | LEN / LEN156FHD |

El EDID de Windows trae **todo lo que el kernel necesita**. La clave del fix:
`saneo + recorte a 128 bytes` (ver `03-inyeccion-edid.md`) porque los 128
bytes extra (relleno en ceros) **el validador estricto del kernel 6.12 los
rechaza** (`Invalid firmware EDID`).

## Limpieza

```bash
sudo umount /tmp/opencode/winc
```
