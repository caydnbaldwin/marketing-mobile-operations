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
├── run.sh                          # dispatcher
├── stages/                         # workflows (executable)
│   ├── stage1_jailbreak.sh         # palera1n jailbreak
│   ├── stage1_verification.sh      # verifies stage 1 end state
│   ├── stage2_sileo_openssh.sh     # WiFi + Sileo (manual) -> OpenSSH + Local Network (auto via dropbear)
│   ├── stage2_verification.sh      # discovers IP, runs 4 checks, renders table
│   ├── stage3_imessagegateway.sh   # auto-invokes /setup-new-phone skill via claude -p
│   └── stage3_verification.sh      # verifies phone number registered + prints summary
└── lib/                            # functions (sourced)
    ├── echo_mmo.sh                       # [MMO] prefix print helper
    ├── get_phone_number.sh               # MSISDN via pymobiledevice3 lockdown get
    ├── get_wifi_ip.sh                    # phone WiFi IP via brief USB SSH (port 22, post-OpenSSH)
    ├── install_openssh_via_dropbear.sh   # apt-installs OpenSSH over dropbear (port 44, post-Sileo)
    ├── kill_stale_palera1n.sh            # cleanup for orphaned palera1n/checkra1n
    ├── launch_sileo_app.sh               # uiopen sileo:// over dropbear (post-Sileo)
    ├── print_help.sh                     # run.sh usage text
    ├── print_setup_summary.sh            # IP/pass/phone-number readout for stage 3 verification
    ├── push_wifi_profile.sh              # generates + pushes WiFi .mobileconfig via pymobiledevice3
    ├── run_palera1n_to_pongoos.sh        # palera1n + auto-kill at PongoOS boot
    ├── run_setup_new_phone_skill.sh      # invokes /setup-new-phone Claude skill via claude -p
    ├── run_via_dropbear.sh               # generic SSH-as-mobile over dropbear/USB helper
    ├── set_device_language.sh            # lockdownd-set UI language + locale (idempotent; pre-jailbreak OK)
    ├── trigger_local_network_prompt.sh   # uiopen sms:// over dropbear to surface iOS permission prompt
    ├── verify_device_language.sh
    ├── verify_device_reachable.sh        # lockdownd reachability precheck (catches pymobiledevice3 ERROR-but-exit-0)
    ├── verify_dropbear_auth.sh           # probes mobile@phone auth with $SSH_PASS via dropbear (silent)
    ├── verify_openssh_installed.sh       # probes for /usr/sbin/sshd via dropbear (silent)
    ├── verify_palera1n_installed.sh
    ├── verify_sileo_installed.sh
    ├── verify_ssh_as_mobile.sh
    ├── verify_sudo_as_mobile.sh
    ├── verify_wifi_profile_pushed.sh     # probes for com.stage2.wifi profile via pymobiledevice3 (silent)
    ├── verify_wifi_reachable.sh
    ├── wait_for_lockdownd.sh             # post-boot wait so instant lockdownd queries don't fail-fast
    └── wait_for_palera1n_installed.sh
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
- **Lib files do not source other lib files.** When a lib function depends on another (e.g. `wait_for_palera1n_installed` calls `verify_palera1n_installed`), document the dependency in the top-of-file comment and require the caller to source both. This keeps the dependency graph flat and visible at the call site.
- **`verify_*` functions return silently; callers print.** A verify lib's contract is "return 0 if true, 1 if false" — no `echo_mmo` calls in the function body. This makes them safe to reuse as probes (`if verify_X; then skip; fi`) without leaking spurious FAILURE lines on the not-found branch. If the operator-facing context wants a SUCCESS or FAILURE line, the caller (a stage script, `run.sh -vpi`, etc.) prints it based on the return code.

When adding a helper, first check `lib/` for an existing function before writing new inline logic.

### Dispatch layering (stages vs. atomic ops)

Two distinct layers live under `run.sh`:

- **Stages** (`stage*_*.sh`) — workflows that orchestrate multiple atomic ops. They accept no flags of their own; they exist to be run top-to-bottom as a unit. Two kinds coexist:
  - **Main stages** (`stage1_jailbreak.sh`, `stage2_sileo_openssh.sh`, `stage3_imessagegateway.sh`) — do the work (jailbreak, install, hand off).
  - **Verification stages** (`stage1_verification.sh`, `stage2_verification.sh`, `stage3_verification.sh`) — prove the phone is in the expected end state after a main stage. Independently runnable; useful for re-checking a phone without re-running the main work.
- **Atomic operations** (`lib/*.sh`) — single-purpose functions. Called as functions by stages. Only a small subset is exposed as run.sh flags.

`run.sh` is the sole dispatcher. **It composes main and verification stages** into the default full run (`mmo` with no args runs stage1 → stage1_verification → stage2 → stage2_verification → stage3 → stage3_verification). Main stages do **not** call verification stages themselves — `run.sh` owns the sequencing. If you run a main stage in isolation (e.g. `mmo -s1`) it does the work but does not verify; run the verification flag separately (`mmo -s1v`).

Flag conventions:

- `--stageN`, `--stageN-verification` — dispatches to the corresponding stage script.
- `--<function_name>` (matching a `lib/` filename) — run a single atomic op. Reserved for ops with a real standalone use case (currently `--verify-palera1n-installed`, `--kill-stale-palera1n`, `--set-device-language`, `--run-setup-new-phone-skill`).
- Every long flag has a short form built from the first letter of each word: `--stage1` / `-s1`, `--stage1-verification` / `-s1v`, `--verify-palera1n-installed` / `-vpi`, `--kill-stale-palera1n` / `-ksp`, `--set-device-language` / `-sdl`, `--run-setup-new-phone-skill` / `-rsnps`. Case-by-case resolution if two long flags collapse to the same short form.

**Not every `lib/` function is exposed as a flag.** Most atomic verify ops (`verify_wifi_reachable`, `verify_sileo_installed`, `verify_ssh_as_mobile`, `verify_sudo_as_mobile`) are only used internally by `stage2_verification.sh`. The useful unit for the operator is the verification stage (`-s2v`), not the individual checks. Expose a function as a flag only when running it standalone is a real user need.

**Do not add flags to stage scripts.** If a user needs a subset of a stage, extract the subset into a `lib/` function and expose it as a flag on `run.sh`. Stage scripts should read top-to-bottom as pure workflows with no conditional dispatch.

### `[MMO] [TYPE]` prefix convention

Every line of output originating from our own scripts is prefixed with `[MMO] [<TYPE>] ` so it's trivially distinguishable from palera1n / checkra1n / pymobiledevice3 output AND each line is tagged with its semantic role. The `echo_mmo` helper (`lib/echo_mmo.sh`) is the single entry point and takes the type as a required first argument:

```bash
echo_mmo HEADER  "Stage 1: Jailbreak"
echo_mmo INFO    "[1/4] Entering DFU…"
echo_mmo SUCCESS "palera1n successfully installed on device."
echo_mmo FAILURE "Timed out waiting for PongoOS" >&2
cat <<EOF | echo_mmo INFO     # stdin mode also takes the type
banner line 1
banner line 2
EOF
```

The six canonical types:

| Type      | Use for                                                           | Tag color |
|-----------|-------------------------------------------------------------------|-----------|
| `HEADER`  | Stage banner — exactly one per stage (`Stage N: …`)               | cyan `#00d7ff` |
| `INFO`    | Neutral progress / status lines, multi-line operator banners      | gray `#a8a8a8` |
| `SUCCESS` | Positive confirmation (verify passed, install completed, handoff) | green `#5fd700` |
| `SKIP`    | Step skipped because a probe found it already satisfied (probe-first pattern in main stages — see below) | dim gray `#5f5f5f` |
| `WARNING` | Non-fatal: long-poll heartbeat, transient retry, soft anomaly. "The thing isn't done yet, but we're not giving up." | amber `#ffaf00` |
| `FAILURE` | Error path — almost always paired with `>&2`                      | red `#ff5f5f` |

Other strings get printed verbatim inside the brackets but stick to these six.

**Where WARNING belongs**: long polls and retry loops, where intermediate failures aren't yet terminal. `wait_for_palera1n_installed` emits one every 30s of its 180s budget; `run_palera1n_to_pongoos` emits one every 60s of its 660s budget. The pattern is: `INFO` to announce the wait, `WARNING` for "still going" heartbeats, then `SUCCESS` on completion or `FAILURE` on timeout. Don't add a heartbeat to a poll that finishes in <30s — too noisy for not-much-payoff.

**Colors**: 24-bit ANSI. `[MMO]` is the project indigo `#402da3`; per-type tag colors are in the table above. Message bodies are left in the terminal's default color so long messages stay readable. Colors auto-disable when stdout isn't a TTY (so piping into `tee` or a file gives clean text), and honor `NO_COLOR=1` per [no-color.org](https://no-color.org). The implementation is entirely inside `lib/echo_mmo.sh` — don't add ad-hoc ANSI codes elsewhere.

For `read -rp` prompts, inline the literal `[MMO]` (no type) in the prompt string — read prompts aren't routed through `echo_mmo`. For purely visual spacing between groups, use plain `echo ""` (no prefix at all) rather than `echo_mmo INFO ""` so the spacer doesn't carry a tag.

The only printer exempt from the prefix is `print_help` — usage text stands alone.

Every stage opens with a single `echo_mmo HEADER "..."` line. Stages do **not** end with "next stage is…" announcements — the next stage's HEADER self-announces.

Every lib function that prints must document "Requires echo_mmo to be in scope" in its top-of-file comment. Callers source `lib/echo_mmo.sh` explicitly before sourcing any function that depends on it.

### Probe-first pattern in main stages

Every step in a main stage (`stage1_jailbreak.sh`, `stage2_sileo_openssh.sh`, `stage3_imessagegateway.sh`) probes "is this already satisfied?" first and skips cleanly if it is. This makes `mmo -sN` reruns idempotent — the WiFi profile isn't re-pushed, OpenSSH doesn't error out as already-installed, the operator-tap pauses don't fire when the work was already done.

The wrapper template:

```bash
CURRENT_STEP="WiFi profile push"
if verify_wifi_profile_pushed 2>/dev/null; then
    echo_mmo SKIP "WiFi profile already pushed — skipping push"
else
    echo_mmo INFO "Pushing WiFi configuration profile to device..."
    push_wifi_profile
fi
```

Conventions:
- Probe libs are named `verify_*`, return silently (per the lib convention above), and live in `lib/`. The `2>/dev/null` redirect on the probe call belt-and-suspenders against any underlying tool printing to stderr.
- The SKIP message is the operator's signal that we noticed and elided work. Phrase it as `<thing> already <state> — skipping`.
- Some steps don't have clean probes (Local Network grant lives in a binary plist not safely shell-readable). Those steps re-run unconditionally and rely on the underlying operation being idempotent itself.
- Stage 1 uses a single top-level `verify_palera1n_installed` guard rather than gating each of the 4 palera1n calls; jailbreak is atomic and DFU/PongoOS state isn't a meaningful skip boundary.
- Stage 3 has no shell-side probes — the `/setup-new-phone` skill owns its own idempotency (dpkg checks for the tweak, file presence for the LaunchDaemon).
- `CURRENT_STEP` is the human-readable step name picked up by the stage-level ERR trap (see "Graceful failure" below). Set it on the line *before* each step.

### Graceful failure

Each main stage installs an ERR trap that names the failing step:

```bash
CURRENT_STEP="initializing"
trap 'echo_mmo FAILURE "Stage 2 aborted at step: $CURRENT_STEP" >&2' ERR
```

Without it, a mid-stage failure dumps the underlying tool's stderr and the operator has to scroll up to figure out which manual bridge or library call they were in. The trap is installed once per stage, immediately after sourcing `echo_mmo`. Each step sets `CURRENT_STEP` before running its work.

Remediation hints belong in the FAILURE message body of the lib that owns the failure mode (not at the stage level — keeps the hint close to the code that knows the failure shape). Examples already in the codebase:
- `verify_device_reachable` lists cable / port / Trust dialog / force-restart.
- `push_wifi_profile` mentions device-unlocked + no-conflicting-Settings-dialog.
- `install_openssh_via_dropbear` mentions Sileo finish + `.env`-password match.

What's deliberately *not* implemented:
- **Retry-on-transient-failure** (apt locks, USB re-enum drops). Wide surface, low value for a single-operator flow. Operator reruns.
- **SIGINT cleanup beyond `kill_stale_palera1n`**. Stage 1 already covers its worst case (orphaned palera1n/checkra1n). Stage 2/3 don't leave bad state on interrupt.

## Running the scripts

```bash
./run.sh                                # full pipeline: s1 -> s1v -> s2 -> s2v -> s3 -> s3v
./run.sh -s1                            # just the jailbreak (no verify)
./run.sh -s1v                           # verify stage 1 end state
./run.sh -s2                            # WiFi profile + Sileo + OpenSSH (manual bridges)
./run.sh -s2v                           # verify stage 2 end state (prints table)
./run.sh -s3                            # auto-invoke /setup-new-phone skill via claude -p
./run.sh -s3v                           # verify phone number registered + print setup summary
./run.sh -vpi                           # atomic: one-shot palera1n-app check
./run.sh -ksp                           # atomic: kill stale palera1n/checkra1n (prompts for sudo)
./run.sh -rsnps                         # atomic: run /setup-new-phone skill (auto-discovers IP)
./run.sh -rsnps 10.10.130.58 alpine1    # atomic: run /setup-new-phone skill with explicit IP/pass
./run.sh --help                         # show usage
```

`run.sh` itself does not self-elevate; `stage1_jailbreak.sh` does (via `exec sudo -E`). Verification stages and stage 2/3 run as the user. There is no build system, package manager, or test suite.

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

Self-elevates via `exec sudo -E`, then probes `verify_palera1n_installed` as a top-level guard — if the palera1n app is already on the device, the whole stage prints `[SKIP]` and exits 0 without touching anything. Otherwise it runs `kill_stale_palera1n` (pre-flight cleanup), then sequentially invokes palera1n four times. **Two DFU holds total**, not four — calls 1 and 3 prompt for DFU; calls 2 and 4 continue from PongoOS over USB.

The 4-call sequence is *not* decomposed into per-step probes: jailbreak is atomic, and DFU/PongoOS state is transient and not a meaningful skip boundary. The single `verify_palera1n_installed` guard at the top is the right idempotency unit for stage 1.

1. `run_palera1n_to_pongoos -f -c` (call 1/4, **DFU needed**) — DFU → checkm8 → PongoOS boot. palera1n **hangs** at "Booting PongoOS…"; `run_palera1n_to_pongoos` watches for the PongoOS USB device and sends SIGINT (+ SIGKILL fallback) so the workflow can continue.
2. `palera1n -f -c` (call 2/4, no DFU) — picks up from PongoOS over USB, uploads the FakeFS-creation ramdisk/overlay/kpf, chain-boots. Device creates FakeFS and reboots to stock iOS. Exits cleanly on its own.
3. `run_palera1n_to_pongoos -f` (call 3/4, **DFU needed**) — same hang-then-auto-kill pattern as call 1.
4. `palera1n -f` (call 4/4, no DFU) — picks up from PongoOS, chain-boots the jailbroken kernel. Device boots into jailbroken iOS; palera1n app auto-installs.

Stage 1 does **not** verify its own result; that's `stage1_verification.sh`'s job and `run.sh` runs it afterwards in the default pipeline. Running `mmo -s1` standalone will complete without checking whether the palera1n app appeared.

Defensive `sleep 2` between same-phase handoffs (calls 1→2 and 3→4) gives USB re-enumeration time to settle. No sleep between 2→3 because the DFU prompt on call 3 absorbs any delay.

Before each palera1n call the script prints a `[MMO] [N/4]` phase label stating whether DFU is needed, so the operator doesn't have to watch raw palera1n output to know what's coming.

The script accepts no flags — it is a pure workflow. To re-check device state without reflashing, use `run.sh -s1v` (the verification stage) or `run.sh -vpi` (the atomic op — instantaneous, no retry).

**Why 4 calls, not 2, and why `run_palera1n_to_pongoos`**: palera1n's single invocation should in theory do checkm8 → PongoOS boot → payload upload → chain-boot, but on this setup (palera1n v2.2.1, macOS arm64, iPhone 6s) it hangs after booting PongoOS — it does not exit or error, it just stalls. The prior manual workflow was Ctrl+C + rerun; `run_palera1n_to_pongoos` automates the Ctrl+C by streaming palera1n's stdout through a FIFO, matching on the "Booting PongoOS" line, and sending SIGINT to the palera1n PID. A second invocation then sees the device in PongoOS state and completes the remaining work (payload upload + chain-boot) on its own. Do not reduce to fewer calls or switch back to plain `palera1n` for calls 1/3 without re-testing end-to-end — the script will hang.

On macOS no host-side USB setup is needed — the kernel handles device muxing. The older Ubuntu version called `modprobe -r ipheth` and `systemctl start usbmuxd`; both have been removed.

**Language pre-flight**: the script starts with `set_device_language en en_US` (from `lib/`). Phones from sourcing often arrive in `zh-Hans-CN` / `zh_CN`; without this step, stage 2's "Settings > VPN & Device Management" tap is in Chinese. Lockdownd accepts the `AppleLanguages` / `AppleLocale` writes on stock iOS without supervision (this is unusual — most MDM-ish settings need supervision, but these don't). The change persists through palera1n's reboots and SpringBoard picks it up on next launch, so we don't need to manually respring. Idempotent: no-op when already English. Also exposed as `mmo --set-device-language` / `-sdl` for ad-hoc use.

**Stale-palera1n pre-flight**: the script then runs `kill_stale_palera1n` (from `lib/`). If a prior stage 1 was Ctrl+C'd or its terminal closed mid-flight, the backgrounded `palera1n` process — and/or the `checkra1n` helper palera1n extracts to `/var/folders/.../T//checkra1n.XXXXXX` at runtime — can survive as orphaned root processes. A stale `palera1n` grabs the next USB device and forces it into DFU/recovery ("plugging in a phone breaks it"). A stale `checkra1n` holds exclusive USB access, causing the next jailbreak attempt to fail with `kIOReturnExclusiveAccess` (0xe00002c5, "Unable to open device"). The function matches both: `^palera1n` for the parent, `/checkra1n\.` for the extracted helper. Also exposed as an atomic op: `run.sh --kill-stale-palera1n` (prompts for sudo) to clean up from outside a stage 1 run.

`set -euo pipefail` is active throughout.

### Stage 1 verification — `stages/stage1_verification.sh`

Three steps, in order:

1. `wait_for_lockdownd` — polls `pymobiledevice3 lockdown info` every 3s for up to 120s. Stage 1's last `palera1n -f` call returns the instant the kernel starts booting, not when iOS is up; lockdownd doesn't come back online until ~30-60s later. Without this wait, the next step's instant lockdownd query hard-fails for purely timing reasons. On a fully-booted phone (e.g. standalone `mmo -s1v` re-runs) the first poll succeeds in <1s, so the cost outside the post-stage-1 case is ~zero.
2. `verify_device_language en en_US` — confirms `set_device_language` stuck through stage 1's reboots. Hard-fails fast (lockdownd query is instant *now that we've waited for it*) so the operator can re-run `mmo -sdl` without waiting on the longer palera1n poll. Wrong language at this point usually means lockdownd was busy when stage 1 ran the preflight; just re-run `-sdl` then `-s1v`.
3. `wait_for_palera1n_installed` — polls `verify_palera1n_installed` every 3s for up to 180s to absorb the rest of the post-jailbreak boot (lockdownd comes up before SpringBoard finishes installing the palera1n app). Emits a `WARNING` heartbeat every 30s so the operator knows it's still trying.

Both are hard-fail (any non-zero return aborts the script under `set -euo pipefail`); we don't aggregate into a table because the value of stage 1 verification is a fast pass-or-stop signal for the pipeline, not a full state report.

Two atomic ops to pick between for ad-hoc checks:
- `run.sh -s1v` — retry-and-wait version (same as what runs during the pipeline). Use when the phone just finished booting.
- `run.sh -vpi` — instantaneous one-shot. Use when you just want to know *right now* whether the app is there.

### Stage 2 — `stages/stage2_sileo_openssh.sh`

Runs after stage 1 verification passes. Drives two manual bridges (WiFi profile install, Install Sileo in the palera1n app) and then automates the next two (OpenSSH install, Local Network permission prompt) over palera1n's bundled dropbear SSH on port 44. Does **no** verification — that's `stage2_verification.sh`'s job.

The stage opens with `verify_device_reachable` because **`pymobiledevice3` has a quirk: it logs `ERROR Device is not connected` to stderr but exits 0**, so `set -e` doesn't trip and downstream calls silently no-op. Without this precheck, the operator would see "Tap Install on the WiFi profile" prompts for a profile that was never pushed. The precheck captures stdout+stderr and treats any `ERROR` line — or empty output — as a hard failure with remediation hints (cable, port, Trust dialog, force-restart).

1. **WiFi push** — `push_wifi_profile` generates a `.mobileconfig` from `WIFI_SSID`/`WIFI_PASS` and pushes it via `pymobiledevice3 profile install` over USB (lockdownd). Captures stderr and re-checks for `ERROR` patterns inside the function as a belt-and-suspenders against the same quirk; the precheck above should have caught a fully-disconnected device, but transient/partial failures can still leak through.
2. **WiFi install** *(manual bridge)* — pauses while operator taps Install in Settings > General > VPN & Device Management. Device auto-joins. Apple gates silent profile install behind device supervision (which requires wiping the phone), so we accept this tap.
3. **Sileo install** *(semi-automated bridge)* — operator opens the palera1n app, taps Install Sileo, and sets the password to match `SSH_PASS` in `.env` (conventionally `alpine1`). On rootful palera1n with this build, the password sets on the `mobile` user, not `root` — SSH-as-root doesn't work on these phones regardless, so everything downstream targets `mobile@…`. **This step is also what unlocks dropbear authentication** — until mobile has a hash in `/etc/master.passwd`, nothing can SSH in (root is permanently locked with `!`). That's why bridges 4 and 5 must run *after* this one, not before. After the operator presses Enter, the script auto-launches Sileo via `uiopen sileo://` over dropbear (`launch_sileo_app`) so it warms its source indexes while OpenSSH installs in the background — saves a Home-screen tap.

   **Why no auto-launch for the palera1n loader?** Tried it via `pymobiledevice3 developer dvt launch in.palera.loader` (the only pre-Sileo path, since dropbear can't auth before Sileo install). DVT does launch the process, but Apple's Instruments protocol intentionally launches apps in the background for measurement, not foreground for UI — the app starts but never visibly opens, which is worse UX than just telling the operator to tap once. The loader has no `CFBundleURLTypes` either, so a `uiopen palera1n://` style hop isn't available. Manual tap stays.
4. **OpenSSH install** *(automated)* — `install_openssh_via_dropbear` runs `apt-get install -y openssh` on the phone over `run_via_dropbear`. Idempotent. Replaces the prior "open Sileo, search 'openssh by Nick Chan', tap Get" manual bridge.
5. **Local Network prompt** *(semi-automated)* — `trigger_local_network_prompt` runs `uiopen sms://` over the same dropbear tunnel, which brings Messages to the foreground and lets iOS surface the Local Network prompt. Operator still taps Allow on the prompt; the grant itself lives in `/private/var/preferences/com.apple.networkextension.plist` as an NSKeyedArchiver-serialized blob (NOT in TCC.db on iOS 15) and isn't safely shell-writable. Skipping this means the iMessageGateway tweak later fails with `EHOSTUNREACH` that looks like a network issue but isn't.

Stage 2 does **not** self-elevate to root. Nothing in stage 2 requires sudo on macOS (`pymobiledevice3` uses lockdownd as the user; `sshpass`/`iproxy` are unprivileged; `sudo` for apt happens *on the phone* with mobile's password). Earlier versions did `exec sudo -E` — that was an Ubuntu holdover and has been removed. Do not reintroduce it; it causes `python3` to resolve to root's PATH (Xcode's Python) and breaks the `pymobiledevice3` call.

**Why dropbear (port 44), not OpenSSH (port 22), for bridges 3 and 4**: bridge 3 is what installs OpenSSH, so port 22 isn't available yet when we need shell access. Dropbear is bundled in palera1n's binpack at `/cores/binpack/Library/LaunchDaemons/dropbear-*.plist` and runs from boot. It auths against `/etc/master.passwd`, so it inherits the post-Sileo mobile credential automatically. `run_via_dropbear` is the helper; `install_openssh_via_dropbear` and `trigger_local_network_prompt` are thin wrappers around it. Don't try to use dropbear *before* bridge 2 — `master.passwd` has both root (`!`) and mobile (`*`) locked until Install Sileo runs.

### Stage 2 verification — `stages/stage2_verification.sh`

Proves the phone is in the state the `/setup-new-phone` skill expects: `mobile@<wifi_ip>` reachable over WiFi with `$SSH_PASS`, `sudo` working, Sileo installed.

1. **Discover WiFi IP** via `get_wifi_ip` (brief iproxy + SSH-as-mobile, returns the IP, tears down the tunnel). `lockdownd` / `pymobiledevice3` expose only hardware MACs, not the DHCP-assigned IP, so SSH is the only deterministic path.
2. **Prime `~/.ssh/known_hosts`** for `$WIFI_IP` via `ssh-keygen -R` then `ssh-keyscan`. The `/setup-new-phone` skill calls plain `ssh mobile@<ip>` without `StrictHostKeyChecking` overrides, so without priming it would prompt on first contact (and `sshpass` would silently fail the prompt). The `-R` first clears stale entries from reused IPs.
3. **Four atomic checks** (each is its own `lib/verify_*.sh` function):
   - `verify_wifi_reachable` — Mac-side `ping $WIFI_IP`. Exact same probe the skill does first.
   - `verify_sileo_installed` — `pymobiledevice3 apps list | grep '"org.coolstar.SileoStore"'` over USB/lockdownd.
   - `verify_ssh_as_mobile` — `sshpass ssh mobile@$WIFI_IP true`. Proves sshd + password in one shot.
   - `verify_sudo_as_mobile` — `sshpass ssh mobile@$WIFI_IP "echo $SSH_PASS | sudo -S -k whoami"` == `root`. Proves the skill's step-2 root-password bootstrap path.
4. Renders a pass/fail table with `$WIFI_IP` in the header, exits non-zero on any failure.

**Why `pymobiledevice3 apps list` for Sileo and not `ideviceinstaller`**: on freshly-jailbroken devices `ideviceinstaller list --all` intermittently fails with `Could not connect to lockdownd: Invalid HostID` — a pairing-record mismatch between the macOS pairing cache and the post-jailbreak lockdownd. `pymobiledevice3` handles pairing differently and doesn't hit it. `ideviceinstaller` is still used in stage 1 verification (works reliably before the Sileo/OpenSSH install steps seem to trigger the HostID drift). If `verify_palera1n_installed` ever starts failing with "Invalid HostID," port it to `pymobiledevice3 apps list` too.

**Why these four checks and not `dpkg` / phone-side `ping`**: palera1n on iPhone 6s / iOS 15 ships a minimal userland — `awk`, `ping`, `ifconfig`, and many Debian package names just aren't there. Sileo isn't reliably a dpkg package on every build. The four checks use only tools that exist on *either* side (macOS `ping`; `pymobiledevice3` on the Mac; `sudo`/`whoami` on the phone). Don't reintroduce phone-side `awk`/`ping`/`dpkg` dependencies without first confirming they're installed on the target phone.

SSH always targets `mobile@…`, not `root@…`. `root` login is disabled on these palera1n builds. The Sileo-install password sets the `mobile` password, and the skill uses the same convention. If you ever port this to a setup with usable root login, change the user in every `verify_*` lib and in `get_wifi_ip`, and document it.

All SSH calls share the same option set (via inline args in each verify lib for now): `StrictHostKeyChecking=no`, `UserKnownHostsFile=/dev/null`, `PubkeyAuthentication=no`, `PreferredAuthentications=keyboard-interactive,password`, `NumberOfPasswordPrompts=1`. **Do not remove the host-key overrides.** USB connections to `localhost:$USB_SSH_PORT` look identical across phones, and WiFi IPs get reused across fleet turnover — either way, `ssh` otherwise sees "REMOTE HOST IDENTIFICATION HAS CHANGED" and silently disables password + keyboard-interactive auth, which makes `sshpass` fail with no visible error. The skill's known_hosts priming (step 2 above) is a separate, clean write to the real file.

**Idempotent reruns**: every step in stage 2 is wrapped in the probe-first pattern (see "Probe-first pattern in main stages" above). Reruns against a partially- or fully-set-up phone print `[SKIP]` for steps that already passed, so the WiFi profile isn't re-pushed, OpenSSH doesn't error as already-installed, and the operator-tap pauses don't fire when the underlying state already matches. The probes:

| Step | Probe | Notes |
|---|---|---|
| WiFi profile push | `verify_wifi_profile_pushed` | greps `pymobiledevice3 profile list` for `com.stage2.wifi` |
| WiFi-installed operator tap | `verify_wifi_profile_pushed && get_wifi_ip` succeeds | tap-pause skipped only if profile is on device *and* phone is reachable on WiFi |
| Sileo install operator tap | `verify_sileo_installed && verify_dropbear_auth` | dual-probe: Sileo on disk *and* mobile's password matches current `$SSH_PASS` (skipping on Sileo presence alone would silently fail at the OpenSSH step on a stale-password phone) |
| Sileo auto-launch | (always run) | cheap; foregrounding an already-foregrounded app is a no-op |
| OpenSSH install | `verify_openssh_installed` | `run_via_dropbear "test -x /usr/sbin/sshd"` |
| Local Network prompt | (always re-trigger) | the grant lives in a binary plist not safely shell-readable; iOS no-ops the modal when already granted |

### Stage 3 — `stages/stage3_imessagegateway.sh`

Discovers the WiFi IP (via `get_wifi_ip`, same as stage 2 verification), then auto-invokes the `/setup-new-phone` Claude skill via `claude -p` (`run_setup_new_phone_skill`). The skill streams its output to the terminal so the operator can watch tool calls in real time, but cannot intervene mid-flight.

The skill lives at `~/.claude/skills/setup-new-phone/SKILL.md`. Do not edit it from this project; stage 3 is its counterpart on the shell side.

**Idempotency boundary**: stage 3 has no shell-side probes of its own. Re-running `mmo -s3` against an already-set-up phone is safe because the `/setup-new-phone` skill itself owns idempotency for the work it does (dpkg checks for the tweak `.deb`, file-presence for the LaunchDaemon plist, etc.). The shell stage is a thin wrapper around `claude -p`; if you find yourself wanting to gate stage 3 from the shell side, the right move is almost always to push the check into the skill instead.

**Two-phase flow with an operator pause for the SIM swap**:

1. **Deploy pass** — `claude -p "/setup-new-phone <ip> <pass>"` deploys the tweak, sets the LaunchDaemon, prompts the iOS Local Network grant. The first event in the stream-json output is `system/init` with a `session_id`; the function captures it via `tee` to a temp file + post-stream `jq`.
2. **Operator pause** — `read -rp "Insert SIM, toggle iMessage off then on, wait for the phone number to register, then press Enter…"`. This is the same pattern stage 2 uses for its WiFi/Sileo manual bridges: deterministic shell on either side of a human action.
3. **Reverify pass** — `claude --resume <session_id> -p "reverify"`. Resuming the same Claude session means the skill still has the deploy context (knows which phone, what tweak version, what already worked), so "reverify" is enough — no need to repass IP/password. Mirrors how the skill is used interactively.

**Why `--output-format stream-json --verbose` + jq instead of plain `-p`**: default `-p` text output buffers until the whole pass completes — minutes of silence followed by a wall of text. stream-json emits each event (assistant text, tool calls, tool results) as it happens; the jq filter renders them as `→ ToolName <input>` and `← <result>` lines so the operator sees a running log. Tool inputs/outputs are truncated to 240 chars to keep the log skimmable; if you ever need full payloads, drop the `.[0:240]` clamps.

**Why `--dangerously-skip-permissions`**: the skill issues many SSH, scp, and sudo tool calls. In a non-interactive `claude -p` invocation each one would otherwise block on a prompt with no human there to approve it. The skill is deterministic and only touches the target phone + the local tweak `.deb` files, so bypassing prompts is the right call here. Don't reuse this pattern for skills that mutate broader state.

**Why capture session_id from stream-json instead of `--continue`**: `claude --continue` resumes "the most recent conversation in the current directory," which is fragile — if the operator runs any other claude command between the two passes (or `mmo -s3` is invoked from a different cwd than expected), `--continue` grabs the wrong session. Pinning the session_id from pass 1's `system/init` event guarantees pass 2 resumes the right conversation.

**Standalone use**: `mmo -rsnps` exposes `run_setup_new_phone_skill` directly. With no args it auto-discovers the IP and uses `$SSH_PASS` from `.env`; with `-rsnps <ip> <pass>` it skips discovery. Useful for re-running the deploy on a phone that's already past stage 2 (e.g. after a tweak rebuild) without re-doing IP discovery if you already know it. The two-phase pause still happens — press Enter to skip if you're not actually swapping the SIM this run.

IP rediscovery is redundant with stage 2 verification when the full pipeline runs, but it makes stage 3 self-contained: `mmo -s3` works standalone on an already-set-up phone.

### Stage 3 verification — `stages/stage3_verification.sh`

Proves the SIM-related half of stage 3 actually took, and prints the end-of-pipeline readout the operator needs (IP, SSH password, registered phone number).

1. **Discover WiFi IP** via `get_wifi_ip` (same probe as stage 2 verification — keeps s3v independently runnable).
2. **Query phone number** via `get_phone_number` → `pymobiledevice3 lockdown get --key PhoneNumber`. Lockdownd populates this once the SIM is inserted and registered with the carrier; if the operator forgot to swap the SIM (or it hasn't registered yet), the call returns empty.
3. **Render summary** via `print_setup_summary "$WIFI_IP" "$SSH_PASS"` — `IP address`, `SSH password`, `Phone number`. On missing number, prints `(unavailable)` and the lib returns 1, which s3v escalates to a hard failure with a remediation hint.

**Why `pymobiledevice3 lockdown get` and not SSH-grep `/var/wireless/...`**: lockdownd already exposes `PhoneNumber` as a documented key, queryable over USB without root, no hunting through commcenter plists. Same channel s2v uses for `apps list`, so no new dependencies. If the key ever becomes unreliable on this iOS/palera1n combo, the fallback would be `defaults read /var/wireless/Library/Preferences/com.apple.commcenter` over SSH-as-root — but that's brittle (binary plist, key name varies by carrier).

**Why a verification stage and not just an inline summary at the end of stage 3**: matches the s1v/s2v pattern — main stages do work, verification stages confirm end state and are independently re-runnable. After a failed SIM swap the operator can fix it and re-run `mmo -s3v` to confirm + see the readout, without re-doing the whole tweak deploy.

**No atomic-op flag for `print_setup_summary` or `get_phone_number`**: same reasoning as s2v's verify libs — running them standalone isn't a real user need. The operator-facing unit is `mmo -s3v`.
