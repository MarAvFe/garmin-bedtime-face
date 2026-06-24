# garmin-bedtime-face

Garmin watch face (Forerunner 955) with color-coded analog sectors marking bedtime/wake-up routine urgency for a young child.

---

## Quick summary of what this is

An analog watch face. The dial shows colored arcs (green → yellow → red) that mark the urgency of two daily routines (morning wake-up, bedtime). An adult glances at it and knows whether to rush; a ~5-year-old sees the color without needing to read a clock. Outside routine windows the sectors go dark. Nothing else is tracked or alerted.

---

## SDK setup (one-time, your machine)

The Garmin Connect IQ SDK is a free download. You need Java 11+ installed first.

### 1. Install Java (if not already)

```sh
# Ubuntu/Debian/WSL:
sudo apt update && sudo apt install openjdk-17-jdk
java -version   # should print 17.x
```

### 2. Download the Connect IQ SDK

Go to the Garmin developer portal and download the **Connect IQ SDK Manager**:

```
https://developer.garmin.com/connect-iq/sdk/
```

The SDK Manager is a Java `.jar` (or a native installer depending on platform). For Linux/WSL:

1. Download `ciq-sdk-manager-linux.zip` from that page.
2. Unzip it somewhere permanent, e.g. `~/garmin-sdk/`:

```sh
mkdir -p ~/garmin-sdk
cd ~/garmin-sdk
unzip ~/Downloads/ciq-sdk-manager-linux.zip
```

3. Run the SDK Manager to download the actual SDK and device images:

```sh
cd ~/garmin-sdk
java -jar connectiq-sdk-manager-linux.jar
```

In the UI:
- Accept the license.
- Under **SDKs**, download the latest SDK (4.2.x or newer).
- Under **Devices**, download **fr955** (Forerunner 955).

The SDK will install to `~/.Garmin/ConnectIQ/Sdks/<version>/`.

### 3. Add SDK tools to your PATH

```sh
# Add to ~/.bashrc or ~/.zshrc:
export CIQ_SDK_HOME="$HOME/.Garmin/ConnectIQ/Sdks/$(ls ~/.Garmin/ConnectIQ/Sdks | sort -V | tail -1)"
export PATH="$CIQ_SDK_HOME/bin:$PATH"
```

Then reload: `source ~/.bashrc`

Verify:
```sh
monkeyc --version
```

### 4. Get a developer key (required to sign the build)

```sh
cd ~/.Garmin/ConnectIQ
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```

You'll pass `~/.Garmin/ConnectIQ/developer_key.der` to the build command below.

---

## Building the project

From the project root (`garmin-bedtime-face/`):

```sh
mkdir -p build
monkeyc \
  -f monkey.jungle \
  -o build/BedtimeFace.prg \
  -y ~/.Garmin/ConnectIQ/developer_key.der \
  -d fr955 \
  -w
```

- `-f monkey.jungle` — points to the project build file
- `-o build/BedtimeFace.prg` — output `.prg` file
- `-y` — your developer signing key
- `-d fr955` — target device
- `-w` — show all warnings

---

## Running in the simulator

```sh
connectiq &            # starts the Connect IQ simulator in the background
monkeydo build/BedtimeFace.prg fr955
```

The simulator window will display the watch face. You can use **View → Set Time** to test different times and see the sector colors change.

To test settings: in the simulator, go to **File → Edit Application Settings** and change any of the 8 time boundary values (entered as minutes-since-midnight; e.g. `1020` = 17:00).

---

## Sideloading to a physical Forerunner 955

1. Build the `.prg` as above.
2. Connect the watch via USB.
3. Copy the `.prg` to the watch's `GARMIN/APPS/` folder:
   ```sh
   cp build/BedtimeFace.prg /media/$USER/GARMIN/GARMIN/APPS/
   ```
4. Safely eject the watch. The face will appear in **Settings → Watch Face** on the device.

To change settings on a physical device: open the **Garmin Connect** mobile app → **Watch Face Settings** for this face. Enter times as minutes-since-midnight.

---

## Configurable settings

All 8 time boundaries are configurable (default values shown):

| Setting key     | Default | Meaning              |
|-----------------|---------|----------------------|
| `PmGreenStart`  | 1020    | 17:00 — PM routine starts (green) |
| `PmYellowStart` | 1080    | 18:00 — PM yellow zone starts |
| `PmRedStart`    | 1170    | 19:30 — PM red zone starts |
| `PmRedEnd`      | 1230    | 20:30 — PM routine ends |
| `AmGreenStart`  | 300     | 05:00 — AM routine starts (green) |
| `AmYellowStart` | 390     | 06:30 — AM yellow zone starts |
| `AmRedStart`    | 435     | 07:15 — AM red zone starts |
| `AmRedEnd`      | 465     | 07:45 — AM routine ends |

Values are **minutes since midnight** (0–1439).

---

## Project structure

```
garmin-bedtime-face/
├── manifest.xml                  # App identity, target device, permissions
├── monkey.jungle                 # Build configuration (source/resource paths)
├── source/
│   ├── BedtimeFaceApp.mc         # Entry point (AppBase subclass)
│   └── BedtimeFaceView.mc        # All rendering logic (WatchFace subclass)
└── resources/
    ├── settings/
    │   ├── properties.xml        # Property definitions and defaults
    │   └── settings.xml          # Garmin Connect mobile app UI for settings
    └── strings/
        └── strings.xml           # App name string resource
```

---

## Open items flagged from the spec

1. **Forerunner 955 display specs**: 360×360 AMOLED, circular. Connect IQ API level 3.4. The code targets `minApiLevel="3.2.0"` and uses only APIs available since 3.x.

2. **On-device settings UI for 8 time values**: Connect IQ's on-device settings widget set does not provide a time-picker; it supports only list, toggle, and numeric fields. The `settings.xml` uses numeric inputs (minutes-since-midnight). This is editable via the Garmin Connect mobile app. A polished time-picker UX would require a companion GCM plugin — out of MVP scope.

3. **API level**: Forerunner 955 supports Connect IQ API 3.4.0. All APIs used here (`Application.Properties`, `Graphics.drawArc`, `Graphics.drawText`) are available since API 2.x.

---

## Deferred ideas (not implemented, not in scope)

- Numeric countdown in the current sector (e.g., "12 min left in green zone") — would help adults, possibly confuse the child
- Weekend/holiday mode toggle — deliberately out of MVP
- Haptic pulse at zone boundaries — explicitly excluded
- "Should be asleep" post-red zone coloring — excluded; that time renders as dead gray
