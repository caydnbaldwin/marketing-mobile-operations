# Marketing Mobile Operations

Automated workflow for preparing iPhones for use in marketing operations.

---

## Requirements

- macOS (tested on macOS 26 / Apple Silicon)
- [Homebrew](https://brew.sh)
- iPhone 6s running iOS 15.x
- USB cable (Lightning)

---

## Step 1 — Install dependencies

**palera1n**

```bash
sudo /bin/bash -c "$(curl -fsSL https://static.palera.in/scripts/install.sh)"
```

**libimobiledevice tooling + sshpass**

```bash
brew install libirecovery ideviceinstaller libusbmuxd libimobiledevice sshpass
```

**pymobiledevice3**

```bash
pipx install pymobiledevice3   # or: pip3 install --user pymobiledevice3
```

If you don't have `pipx`, install it with `brew install pipx && pipx ensurepath`.

Verify:

```bash
which palera1n && which irecovery && which ideviceinstaller && which iproxy && which sshpass
```

Every command should print a file path. If any is blank, the corresponding install failed.

---

## Step 2 — Configure `.env`

```bash
cp .env.example .env
```

Edit `.env` and fill in:

- `WIFI_SSID` — the SSID the iPhone should auto-join
- `WIFI_PASS` — WPA2 password
- `USB_SSH_PORT` — local port for the iproxy tunnel (default `2222`)
- `SSH_PASS` — the root password you will set during the Sileo install (conventionally `alpine1`)

---

## Step 3 — Install the `mmo` command

One-time setup so you can invoke the program from anywhere:

```bash
sudo ln -s "$(pwd)/run.sh" /usr/local/bin/mmo
```

This symlinks `run.sh` into `/usr/local/bin` (already on macOS's default PATH). From now on, `mmo` runs the whole workflow; `mmo --help` shows the flag reference.

To uninstall: `sudo rm /usr/local/bin/mmo`.

---

## Step 4 — Run the program

Plug the iPhone into the Mac via USB, then run:

```bash
mmo
```

That's the entry point for every use case. It runs the full workflow end-to-end:

Under the hood, the pipeline runs five stages in sequence. Every line of output from the script itself is prefixed with `[MMO] ` so you can tell it apart from palera1n / checkra1n output.

1. **Stage 1 — Jailbreak via palera1n.** `palera1n` is called four times. Calls 1 and 3 ask you to put the iPhone into DFU mode — hold **Power + Home** on the phone when palera1n prompts. Follow palera1n's own on-screen instructions.
2. **Stage 1 verification.** The device is checked for the installed palera1n app.
3. **Stage 2 — WiFi, Sileo, OpenSSH, Local Network.** Two manual taps plus two automated steps:
   - *(manual)* Push a WiFi config profile and install it in Settings > General > VPN & Device Management. Device auto-joins `WIFI_SSID`.
   - *(manual)* Open the palera1n app, tap Install Sileo, set the password to `SSH_PASS`. This is also what unlocks dropbear authentication for the next two steps.
   - *(automated)* Install OpenSSH on the phone via `apt-get install openssh` run over palera1n's bundled dropbear SSH on port 44 (USB). No taps.
   - *(semi-automated)* Bring Messages to the foreground via `uiopen sms://` over the same dropbear tunnel; iOS shows the Local Network permission prompt — tap Allow.
4. **Stage 2 verification.** From the Mac, over Wi-Fi as `mobile@<ip>`: pings the phone, confirms Sileo is installed, confirms SSH auth works, confirms `sudo` works. Prints a pass/fail table.
5. **Stage 3 — iMessageGateway handoff.** Prints the exact `/setup-new-phone <ip>` command to paste into Claude Code next.

When the pipeline finishes you should see `[MMO] All checks passed.` and the `/setup-new-phone` invocation.

### Running subsets

You rarely need this, but if something fails partway through you can re-run just one piece:

```bash
mmo -s1      # just the jailbreak
mmo -s1v     # just stage 1 verification
mmo -s2      # just stage 2 (WiFi+Sileo manual taps; OpenSSH+Messages automated via dropbear)
mmo -s2v     # just stage 2 verification (prints the table)
mmo -s3      # just the /setup-new-phone handoff
mmo -vpi     # one-shot: is palera1n installed on this device right now?
mmo -ksp     # cleanup: kill stale palera1n/checkra1n (prompts for sudo)
```

`mmo --help` lists everything.

---

## Checking if the phone is already jailbroken

If you're not sure whether a device still has palera1n installed, check without re-running the whole workflow:

```bash
mmo --verify-palera1n-installed
```

Exits 0 and prints `palera1n successfully installed on device.` if it's there; exits 1 otherwise. `mmo --help` lists other atomic operations.

---

## Troubleshooting

**`palera1n not found in PATH`**
Re-run the palera1n install command from Step 1 and open a new terminal. The script installs to `/usr/local/bin/palera1n`, which should already be on PATH.

**`irecovery not found in PATH` / `ideviceinstaller not found`**
Re-run the Homebrew install from Step 1.

**iPhone not detected / palera1n times out waiting for device**
- Try a different USB cable or port (prefer a direct Mac USB port over a hub)
- Make sure the iPhone screen is on and unlocked before starting
- Unplug and replug the iPhone, then re-run the program

**"Allow this computer to access the device?" prompt on iPhone**
Tap Trust on the iPhone, enter the passcode, then re-run.
