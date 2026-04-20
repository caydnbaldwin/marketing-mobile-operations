# Marketing Mobile Operations

Automated workflow for preparing iPhones for use in marketing operations.

---

## Requirements

- Ubuntu 24.04
- iPhone 6s running iOS 15.x
- USB cable (Lightning)

---

## Stage 1 — Jailbreak the iPhone

### Step 1 — Install dependencies

**palera1n**

```bash
sudo /bin/bash -c "$(curl -fsSL https://static.palera.in/scripts/install.sh)"
```

**irecovery**

```bash
sudo apt-get install irecovery -y
```

Verify both are installed:

```bash
which palera1n && which irecovery
```

Both commands should print a file path. If either is blank, the install failed.

---

### Step 2 — Configure USB permissions

Linux restricts direct USB access by default. Without this step, the script will hang with a `LIBUSB_ERROR_ACCESS` error.

**Add a udev rule for Apple USB devices:**

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="05ac", MODE="0666", GROUP="plugdev"' | sudo tee /etc/udev/rules.d/39-apple-usb.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

**Add your user to the `plugdev` group:**

```bash
sudo usermod -aG plugdev $USER
```

**Log out and log back in.** Group membership does not apply until you start a new session.

**Verify your group membership:**

```bash
groups | grep plugdev
```

You should see `plugdev` in the output. If not, log out and back in again before proceeding.

---

### Step 3 — Run the script

Plug the iPhone into the computer via USB, then run:

```bash
cd ~/marketing-mobile-operations
./stage1_jailbreak.sh
```

---

### What to expect

The script will walk you through the process step by step. There are two points where you must physically interact with the iPhone — the script will tell you exactly when and what to do.

| Prompt | What to do |
|--------|-----------|
| `Hold Power + Home when palera1n prompts for DFU` | Watch the palera1n output. When it says it is ready, hold the **Power** and **Home** buttons simultaneously on the iPhone. Hold until the script moves on. |
| *(repeats once more)* | Same as above — the process requires two DFU entries. |

Everything else is automated. The script detects device state, handles branching logic, and auto-stops palera1n at the right moments. When it finishes you will see:

```
============================================
  Stage 1 complete — iPhone is jailbroken!
============================================
```

---

### Troubleshooting

**`palera1n not found in PATH`**
Re-run the palera1n install command from Step 1 and open a new terminal.

**`irecovery not found in PATH`**
Re-run `sudo apt-get install irecovery -y` and open a new terminal.

**`LIBUSB_ERROR_ACCESS` — script freezes after "Booting PongoOS"**
You skipped or did not fully complete Step 2. Make sure you have logged out and back in after adding yourself to `plugdev`.

**iPhone not detected / script times out waiting for device**
- Try a different USB cable or port
- Make sure the iPhone screen is on and unlocked before starting
- Unplug and replug the iPhone, then re-run the script
