# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A multi-stage bash automation workflow that jailbreaks an iPhone 6s (iOS 15.x) using palera1n and sets it up for marketing operations use. Reduces manual steps and timing errors. Intended for use on Ubuntu 24.04.

Each stage is a standalone script. Do not modify a completed stage — add new stages instead.

## Scripts

| Script | Branch | Purpose |
|---|---|---|
| `stage1_jailbreak.sh` | `main` | Jailbreak via palera1n |
| `stage2_sileo_openssh.sh` | `stage2/sileo-openssh` | WiFi, Sileo, OpenSSH |

## Running the scripts

```bash
./stage1_jailbreak.sh   # jailbreak
./stage2_sileo_openssh.sh   # sileo + openssh setup
```

Both scripts self-elevate to root. There is no build system, package manager, or test suite.

## Prerequisites

### All stages
- Ubuntu 24.04
- udev rule for Apple USB: `SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", MODE="0666", GROUP="plugdev"` in `/etc/udev/rules.d/39-apple-usb.rules`
- User in `plugdev` group (requires logout/login to take effect)

### Stage 1
- `palera1n` and `irecovery` in PATH
- `ideviceinstaller` in PATH

### Stage 2
- `sshpass` — `sudo apt-get install -y sshpass`
- `pymobiledevice3` — `pip3 install --break-system-packages pymobiledevice3`
- `iproxy` (part of `libusbmuxd-tools`) — `sudo apt-get install -y libusbmuxd-tools`

## Architecture

### Stage 1 — `stage1_jailbreak.sh`

Runs a four-step jailbreak sequence:

1. **FakeFS creation** — `palera1n -f -c`
2. **Jailbreak** — `palera1n -f` (requires first DFU entry)
3. **Boot jailbroken OS** — `palera1n -f` again (requires second DFU entry)
4. **Verify** — `ideviceinstaller -l` checks that the palera1n app installed

Key implementation details:

- **Process cleanup** (`cleanup_palera1n`): kills palera1n, checkra1n, and irecovery by process group with `-9` to prevent USB interface conflicts between steps.
- **pongoOS detection** (`wait_for_pongoos_and_stop`): watches for `/dev/ttyACM*` to appear, then auto-kills palera1n after 5 seconds — replaces manual user prompts at this stage.
- **Device state detection** (`detect_device`): uses `irecovery -q` and `lsusb` to distinguish recovery mode, normal mode, or no device.
- **usbmuxd**: stopped before jailbreak steps, restarted before the final `ideviceinstaller` verification.
- `set -euo pipefail` is active throughout.

### Stage 2 — `stage2_sileo_openssh.sh`

Runs after stage 1. Connects the device to WiFi, installs Sileo and OpenSSH.

1. **WiFi** — generates a `.mobileconfig` profile and pushes it via `pymobiledevice3 profile install` over USB. User taps Install in Settings > General > VPN & Device Management; device auto-joins.
2. **Sileo install** *(manual bridge)* — script pauses with instructions to open the palera1n app, tap Install Sileo, and set the root password to `alpine1`.
3. **USB SSH tunnel** — `iproxy 2222 22` forwards localhost:2222 to device port 22; `sshpass` authenticates with `alpine1` non-interactively. Confirmed working on this device.
4. **Sileo analytics** — `defaults write xyz.willy.Sileo sendAnalytics -bool YES` via SSH.
5. **OpenSSH** — `apt-get install -y openssh` via SSH pulls all 4 packages from Nick Chan's Procursus repo.
6. **Verify** — checks WiFi connectivity (ping), Sileo install (`dpkg-query`), and OpenSSH package count (`dpkg -l`) via SSH; prints a human-readable pass/fail summary.
