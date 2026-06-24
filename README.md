# garmin-bedtime-face

Garmin watch face (Forerunner 955) with color-coded analog sectors marking bedtime and wake-up routine urgency for a young child.

<img width="388" height="540" alt="image" src="https://github.com/user-attachments/assets/18649b1d-62b4-41f0-8a7b-6f4afab8a3dc" />

---

## What it does

An analog watch face. The dial shows colored arcs (green → yellow → red) marking the urgency of two daily routines — morning wake-up and evening bedtime. An adult glances at it and knows whether to hurry; a ~5-year-old sees the color without needing to read a clock. Outside routine windows the sectors go near-black and recede.

**Visual hierarchy (intentional):**
- Primary: the single hour hand and colored sectors
- Secondary: a small date at 3 o'clock, a tiny digital time near 12, a 5px battery arc along the top bezel
- Nothing else competes for attention

---

## SDK setup (one-time, Windows)

### 1. Install Java 11+

Download from [adoptium.net](https://adoptium.net) or use `winget`:

```powershell
winget install EclipseAdoptium.Temurin.17.JDK
java -version   # should print 17.x
```

### 2. Download the Connect IQ SDK

Go to [developer.garmin.com/connect-iq/sdk](https://developer.garmin.com/connect-iq/sdk/) and download the **SDK Manager** for Windows. Run it, then:

- Under **SDKs** — download the latest (6.x)
- Under **Devices** — download **fr955**

The SDK installs to `%APPDATA%\Garmin\ConnectIQ\Sdks\<version>\`. Set a PowerShell variable to that path:

```powershell
$sdk = "$env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-6.4.2-2024-10-31-306c0e4ca"
```

Adjust the version folder name to match what you installed.

### 3. Generate a developer key (required to sign builds)

Run once; keep the `.der` file — you'll pass it to every build:

```powershell
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
$key = "C:\path\to\developer_key.der"
```

---

## Building

From the project root:

```powershell
mkdir -Force build
& "$sdk\monkeyc.bat" -f monkey.jungle -o build\BedtimeFace.prg -y $key -d fr955 -w
```

| Flag | Meaning |
|------|---------|
| `-f monkey.jungle` | project build file |
| `-o build\BedtimeFace.prg` | output binary |
| `-y $key` | signing key |
| `-d fr955` | target device |
| `-w` | show all warnings |

---

## Running in the simulator

```powershell
& "$sdk\monkeydo.bat" build\BedtimeFace.prg fr955
```

This launches the Connect IQ simulator and loads the watch face onto a virtual fr955. No separate `connectiq` process needed — `monkeydo` handles it.

**Testing tips:**
- **Simulator → Edit → Set Time** — jump to any time to see sector colors change
- **Simulator → File → Edit Application Settings** — change the 8 boundary values live (enter as minutes-since-midnight, e.g. `1020` = 17:00)

---

## Sideloading to a physical Forerunner 955

1. Build the `.prg` as above.
2. Connect the watch via USB.
3. Copy the file to the watch:
   ```powershell
   Copy-Item build\BedtimeFace.prg "D:\GARMIN\APPS\"   # adjust drive letter
   ```
4. Eject safely. The face appears under **Settings → Watch Face** on the device.

To change settings on the physical watch: open **Garmin Connect** (mobile app) → your watch → **Watch Face Settings**. Enter times as minutes-since-midnight.

---

## Configurable settings

All 8 time boundaries are set via Garmin Connect. Values are **minutes since midnight** (0 = 00:00, 1439 = 23:59).

**Quick reference:** `hh:mm → h*60+mm` &nbsp; e.g. 19:30 = 19×60+30 = **1170**

### PM (bedtime) routine — defaults

| Setting key     | Default | Time  | Meaning |
|-----------------|---------|-------|---------|
| `PmGreenStart`  | 1020    | 17:00 | Routine begins — green zone |
| `PmYellowStart` | 1080    | 18:00 | Getting close — yellow zone |
| `PmRedStart`    | 1170    | 19:30 | Need to move — red zone |
| `PmRedEnd`      | 1230    | 20:30 | Routine window closes |

### AM (wake-up) routine — defaults

| Setting key     | Default | Time  | Meaning |
|-----------------|---------|-------|---------|
| `AmGreenStart`  | 300     | 05:00 | Routine begins — green zone |
| `AmYellowStart` | 390     | 06:30 | Getting close — yellow zone |
| `AmRedStart`    | 435     | 07:15 | Need to move — red zone |
| `AmRedEnd`      | 465     | 07:45 | Routine window closes |

Outside all windows the sector ring goes near-black (dead zone).

---

## Project structure

```
garmin-bedtime-face/
├── manifest.xml                  # App identity, target device, permissions
├── monkey.jungle                 # Build config (source + resource paths)
├── source/
│   ├── BedtimeFaceApp.mc         # Entry point (AppBase subclass)
│   └── BedtimeFaceView.mc        # All rendering logic (WatchFace subclass)
└── resources/
    ├── drawables/
    │   ├── drawables.xml         # Declares launcher icon bitmap
    │   └── launcher_icon.png     # 40×40 launcher icon (fr955 size)
    ├── settings/
    │   ├── properties.xml        # Property definitions and defaults
    │   └── settings.xml          # Garmin Connect mobile app settings UI
    └── strings/
        └── strings.xml           # App name string resource
```

---

## Design notes

- **Single hand**: only the hour hand is rendered. One hand is enough for a child to see which sector they're in; the minute hand is commented out in `drawHands()` and can be re-enabled trivially.
- **Geometry**: all pixel values are derived from `dc.getWidth()` / `dc.getHeight()` at render time — no hardcoded screen dimensions.
- **Settings reload**: `loadSettings()` is called on every `onUpdate()` so changes from the Garmin Connect app take effect within one minute without reinstalling.
- **Dead zone color**: `0x181818` (near-black) so it visually recedes rather than competing with the colored sectors.

---

## Deferred / out of scope

- Countdown label ("12 min left in green zone") — useful for adults, likely confusing for the child
- Weekend/holiday mode
- Haptic pulse at zone transitions
- Post-red "should be asleep" coloring — that window simply shows dead zone
