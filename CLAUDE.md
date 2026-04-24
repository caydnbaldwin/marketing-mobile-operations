# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A multi-stage bash automation workflow that jailbreaks an iPhone 6s (iOS 15.x) using palera1n and sets it up for marketing operations use. Reduces manual steps and timing errors. Intended for use on macOS (tested on macOS 26 / Apple Silicon). The project was previously targeted at Ubuntu 24.04 but was migrated to macOS to avoid persistent USB/udev/libusb issues on Linux — don't reintroduce Linux-specific logic without a good reason.

Each stage is a standalone script. Do not modify a completed stage — add new stages instead.

## Scripts

`run.sh` is the single entry point. The user always calls `run.sh`; the `stage*_*.sh` files are implementation and should never be invoked directly from docs, examples, or other scripts. If you need to run a subset of the workflow, add a flag to `run.sh` that dispatches to it.

| Path | Role |
|---|---|
| `run.sh` | Entry point — parses flags, dispatches to stages or atomic ops |
| `stages/*.sh` | Workflows — executable, called by `run.sh` as subprocesses |
| `lib/*.sh` | Atomic ops — sourced (not executed), called as functions |

### Directory layout

```
marketing-mobile-operations/
├── run.sh            # dispatcher
├── stages/           # workflows (executable)
│   ├── stage1_jailbreak.sh
│   └── stage2_sileo_openssh.sh
└── lib/              # functions (sourced)
    ├── print_help.sh
    └── verify_palera1n_installed.sh
```

The split reflects two distinct layers (see "Dispatch layering" below). Don't nest `stages/` under `lib/` — `lib/` conventionally means sourced code, and stages are executables.

### `ROOT_DIR` convention

Every script computes a `ROOT_DIR` variable pointing at the repo root. The recipe depends on where the script lives:

- **Root-level (`run.sh`)**: `ROOT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"` where `$SOURCE` has been symlink-resolved.
- **One level deep (`stages/*.sh`)**: `ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`.

All paths to siblings go through `$ROOT_DIR` (`$ROOT_DIR/lib/...`, `$ROOT_DIR/stages/...`, `$ROOT_DIR/.env`). Don't introduce a `SCRIPT_DIR` that means different things in different files.

### `lib/` convention

Shared functions live in `lib/`. The rules:

- **One function per file.** The filename matches the function name (e.g. `lib/verify_palera1n_installed.sh` defines `verify_palera1n_installed`). This makes `ls lib/` the directory of available functions.
- **Functions `return`, they do not `exit`.** Callers decide how to handle failure. `set -euo pipefail` in the caller turns a non-zero return into an abort automatically.
- **Library files are sourced, not executed.** No `chmod +x`. Top of the file is a shebang + one-line comment describing behavior and return contract.
- **No side effects at source time.** Only function definitions. Sourcing must be idempotent and free of I/O.
- **Name functions in verb-first, declarative form**: `verify_*`, `ensure_*`, `install_*`, `wait_for_*`. Avoid generic names like `check_foo` or `do_foo`.
- **Callers source explicitly.** Each caller (stage script or `run.sh`) sources only the libs it uses, via `source "$ROOT_DIR/lib/<name>.sh"`. No auto-loader — explicit dependencies make the import graph visible.

When adding a helper, first check `lib/` for an existing function before writing new inline logic.

### Dispatch layering (stages vs. atomic ops)

Two distinct layers live under `run.sh`:

- **Stages** (`stage*_*.sh`) — workflows that orchestrate multiple atomic ops. They accept no flags of their own; they exist to be run top-to-bottom as a unit.
- **Atomic operations** (`lib/*.sh`) — single-purpose functions. Each one is independently runnable.

`run.sh` is the sole dispatcher for both layers. Flag conventions:

- `--stage1`, `--stage2` — run a whole workflow (dispatches to the stage script).
- `--<function_name>` (matching a `lib/` filename) — run a single atomic op (sources the lib file and calls the function directly).

**Not every `lib/` function is exposed as a flag.** Some functions are purely internal helpers used by `run.sh` or a stage (e.g. `print_help` is called by `run.sh`'s own `-h`/`--help` handling; it's not meaningful as `--print-help`). Expose a function as a flag only when running it standalone is a real user need.

**Do not add flags to stage scripts.** If a user needs a subset of a stage, extract the subset into a `lib/` function and expose it as a flag on `run.sh`. Stage scripts should read top-to-bottom as pure workflows with no conditional dispatch.

## Running the scripts

```bash
./run.sh                                # full run: stage 1 then stage 2
./run.sh --stage1                       # only stage 1 (jailbreak)
./run.sh --stage2                       # only stage 2 (Sileo + OpenSSH)
./run.sh --verify-palera1n-installed    # atomic: lib/verify_palera1n_installed.sh
./run.sh --help                         # show usage
```

`run.sh` itself does not self-elevate; the stage scripts do (via `exec sudo -E`) when they need root. Atomic operations that don't need root (e.g. `verify_palera1n_installed`) run without sudo. There is no build system, package manager, or test suite.

## Prerequisites

### All stages
- macOS (Apple Silicon tested)
- Homebrew
- macOS handles USB device muxing natively — no udev rules, kernel module tweaks, or user/group changes needed.

### Stage 1
- `palera1n` — install via `sudo /bin/bash -c "$(curl -fsSL https://static.palera.in/scripts/install.sh)"` (installs to `/usr/local/bin/palera1n`)
- `irecovery`, `ideviceinstaller` — `brew install libirecovery ideviceinstaller libimobiledevice`

### Stage 2
- `sshpass` — `brew install sshpass`
- `pymobiledevice3` — `pipx install pymobiledevice3` (or `pip3 install --user pymobiledevice3`). Avoid `pip install` into Homebrew Python directly; it's externally-managed and will fail.
- `iproxy` — `brew install libusbmuxd`
- `.env` file next to the script, populated from `.env.example`. Required vars: `WIFI_SSID`, `WIFI_PASS`, `USB_SSH_PORT`, `SSH_PASS`. Stage 2 `source`s this file on startup and will fail under `set -u` if any var is missing.

## Architecture

### Stage 1 — `stages/stage1_jailbreak.sh`

Sequentially invokes palera1n four times, then verifies:

1. `palera1n -f -c` — create FakeFS (first DFU entry)
2. `palera1n -f -c` — second FakeFS pass (second DFU entry)
3. `palera1n -f` — jailbreak (third DFU entry)
4. `palera1n -f` — boot jailbroken OS (fourth DFU entry)
5. Sleep 3s, then `ideviceinstaller -l -o list_all | grep -qi palera1n` to confirm the palera1n app installed.

Each `palera1n` invocation is a standalone process — the script relies on palera1n's own "Hold Power + Home" prompts for timing. There is no custom pongoOS watcher, process-group cleanup, or device-state detection; earlier versions had these but were simplified away.

On macOS no host-side USB setup is needed — the kernel handles device muxing. On the older Ubuntu version this script called `modprobe -r ipheth` and `systemctl start usbmuxd`; both have been removed.

The script accepts no flags — it is a pure workflow. To re-check device state without reflashing, use `run.sh --verify-palera1n-installed` (the atomic op), not stage 1.

`set -euo pipefail` is active throughout.

### Stage 2 — `stages/stage2_sileo_openssh.sh`

Runs after stage 1. Connects the device to WiFi, installs Sileo and OpenSSH.

1. **WiFi** — `push_wifi_profile` generates a `.mobileconfig` from `WIFI_SSID`/`WIFI_PASS` and pushes it via `pymobiledevice3 profile install` over USB. User taps Install in Settings > General > VPN & Device Management; device auto-joins.
2. **Sileo install** *(manual bridge)* — script pauses with instructions to open the palera1n app, tap Install Sileo, and set the root password to match `SSH_PASS` in `.env` (conventionally `alpine1`).
3. **USB SSH tunnel** — `iproxy "$USB_SSH_PORT" 22` forwards localhost to device port 22, backgrounded with an `EXIT` trap that kills the `iproxy` PID. `wait_for_ssh` polls for up to 60s (30 × 2s).
4. **Sileo analytics** — `defaults write xyz.willy.Sileo sendAnalytics -bool YES` via SSH.
5. **APT refresh + OpenSSH** — `apt-get update -y` then `apt-get install -y openssh` via SSH (Nick Chan's Procursus repo ships 4 packages).
6. **Verify** — `verify()` checks WiFi (ping 8.8.8.8), Sileo (`dpkg-query`), and OpenSSH package count (≥ 4 via `dpkg -l`) over SSH, prints a formatted pass/fail table, and exits non-zero if any check fails.

The `_ssh` helper wraps `sshpass -p "$SSH_PASS" ssh -p "$USB_SSH_PORT" -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@localhost`. Any new SSH call should go through `_ssh` rather than building its own command so the port / password / host-key handling stays consistent.
