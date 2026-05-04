# Onboarding GUI plan

Plan for moving `mmo` from a single-phone CLI to a 4-slot GUI hosted at
`gateway1.local:3000/onboarding`, driving parallel onboarding on each
operator's local Mac.

## End vision

Zach (on his Macbook, REDO WiFi) visits `http://gateway1.local:3000/onboarding`.
The page is served as static HTML/JS by Caydn's mac mini. It detects whether
`mmo` is installed locally; if not, it shows an install command. Once installed,
a small local mmo server runs in the background on Zach's Mac (launchd) and
the page hydrates a 4-slot grid. Zach plugs phones into his Mac, clicks
"Onboard phone", picks a payload (full / s1 / s2 / s3 / chained), and the
session fills the next free slot. Streams render live in the slot. Operator-
pause prompts (tap Install, tap Allow, swap SIM) become buttons in that slot.
Stage 1 is mutexed across slots (palera1n is single-instance); stage 2 and 3
run in parallel up to the slot count. On stage 3 completion the page opens
`gateway1.local:3000/mmo?phone_number=...` in a new tab and prefills the
SIM modal.

The browser sandbox can't spawn processes, so the GUI talks HTTP/WS to a
local listener (`mmo` running in serve-mode). Per-user isolation is
identical to a login page: one URL, N browsers each talking to their own
machine's local mmo. gateway1 is the page CDN, not the work executor.

---

## First PR — UDID + iproxy port refactor

Scope: `marketing-mobile-operations` only. Pure plumbing, no behavior change
in single-phone CLI mode. Unblocks every parallel-execution piece downstream.

**What it does:**
- `MMO_UDID` env var: when set, every device-talking lib threads it through as
  `--udid <udid>` to `pymobiledevice3` and `-u <udid>` to `ideviceinstaller`.
  When unset, current behavior unchanged.
- `MMO_USB_SSH_PORT` and `MMO_DROPBEAR_PORT` env vars: override the hardcoded
  `2244` in `run_via_dropbear` and the single `USB_SSH_PORT` in `get_wifi_ip`.
  When unset, current behavior unchanged.
- `iproxy --udid <udid>` so the tunnel routes to a specific device when
  multiple are plugged in.
- New `lib/select_udid.sh` (or similar): lists currently-attached UDIDs from
  `idevice_id -l` and classifies each (DFU / stock iOS / jailbroken / fully
  set up). Used by future queue/server code.

**What it doesn't touch:**
- `run.sh` dispatch logic (current flags work identically).
- Any operator-pause or prompt logic.
- Stage scripts (they already read env vars; the libs they source are what
  changes).
- `set-ai-gateway` (separate repo, separate PR).

**Testable milestone:** plug two phones in, run
`MMO_UDID=<a> mmo -vpi` and `MMO_UDID=<b> mmo -vpi` in two terminals
simultaneously, get correct per-phone answers.

Roughly 200–400 lines across ~15 lib files. Single review pass.

---

## Full gap list

### `marketing-mobile-operations` (the CLI)

1. **UDID-awareness.** *(First PR.)*
2. **iproxy port allocation.** *(First PR.)*
3. **Replace `read -rp` with a prompt channel.** Stage scripts currently block
   on stdin. GUI mode needs to write the prompt to a per-session FIFO/socket,
   wait for an ack, continue. Compat shim: read from `$MMO_PROMPT_FD`
   (defaults to stdin → CLI works unchanged). 4 prompts to retrofit (3 in
   stage 2, 1 in stage 3).
4. **Structured JSON event stream.** Today everything is `[MMO] [INFO] ...`
   text. GUI needs `{"event":"step_start","stage":2,"step":"WiFi profile push"}`
   etc. Cleanest approach: a parallel `echo_mmo_event` helper that writes
   NDJSON to `$MMO_EVENT_FD` (silent if unset). Layered alongside `echo_mmo`,
   not a replacement.
5. **palera1n inside a pty.** When stage 1 runs from a non-TTY parent (the
   local server's subprocess), palera1n disables its countdown. Wrap with
   `script -q` or a small Python `pty.spawn` shim so its TTY behavior
   survives. Only matters once GUI starts driving s1.
6. **Stage 1 mutex.** Cross-process lock so two `mmo -s1` invocations can't
   race for palera1n. `flock` on a file in `/tmp` is enough. Local server
   checks the lock before scheduling. CLI gets the lock too (so two terminals
   can't break each other).
7. **Sudo handling for stage 1.** `stage1_jailbreak.sh` self-elevates with
   `exec sudo -E`. From a GUI subprocess with no TTY, sudo hangs. Options:
   (a) require operator to `sudo -v` in a terminal first to cache credentials
   before opening the page; (b) run the local server as root (no, awful);
   (c) prompt-channel a password and pipe to `sudo -S`. Probably (a) for v1
   with a clear UI hint.

### `set-ai-gateway` (the gateway1 site)

8. **`/onboarding` route + page.** Add to `routes.js` (one new `if`-branch +
   handler). New `onboarding.html` next to `mmo.html`, follows existing hand-
   rolled style. 4-slot grid, payload selector, log panel per slot, prompt
   buttons. WebSocket client to local mmo.
9. **`/mmo` URL-param prefill.** ~10 lines in `mmo.html` — `URLSearchParams`
   on load, call `openAdd()`, fill matching `<input name="...">` for
   `phone_number`, `sim_type`, `iphone_device_id` (etc.). No backend change.
10. **`/install.sh` (or `/install`) endpoint.** Serves the install script
    that bootstraps mmo + local server + dependencies + launchd plist on the
    operator's Mac. Optional: serve a tarball of the mmo source.
11. **CORS headers on relevant endpoints.** Probably skippable for v1 — the
    data flow is browser → local and browser → gateway1, never local →
    gateway1.

### New component: local mmo server (lives in `marketing-mobile-operations`, runs on operator's Mac)

12. **HTTP/WebSocket listener.** Vanilla Node `http.createServer` + `ws`
    package, ~300–500 lines. Same stack pattern as gateway1, easier to
    maintain. Runs on a fixed loopback port (e.g. `localhost:7878`).
13. **Endpoints:**
    - `GET /health` — presence check the SPA pings on load.
    - `GET /sessions` — current 4-slot state.
    - `POST /sessions` — start a session
      `{ udid, payload: ["s1","s1v","s2","s2v","s3","s3v"], iphone_device_id }`.
    - `DELETE /sessions/:id` — kill session.
    - `POST /sessions/:id/prompt-ack` — operator clicked Continue on an
      operator-pause prompt.
    - `GET /devices` — currently-attached UDIDs + classification.
    - `WS /sessions/:id/stream` — live stdout + structured events.
14. **Slot manager.** Tracks 4 sessions, allocates UDIDs and iproxy ports,
    enforces stage-1 mutex, holds the prompt-channel FIFOs.
15. **Subprocess driver.** Spawns `mmo` inside a pty (so palera1n behaves),
    threads `MMO_UDID`, `MMO_USB_SSH_PORT`, `MMO_DROPBEAR_PORT`,
    `MMO_PROMPT_FD`, `MMO_EVENT_FD` env vars, multiplexes pty bytes + JSON
    events to WebSocket subscribers.
16. **CORS + Private Network Access preflight.** Allow
    `http://gateway1.local:3000` origin. Set
    `Access-Control-Allow-Private-Network: true` if Chrome's PNA preflight
    comes calling.
17. **Origin enforcement.** Reject requests whose `Origin` header isn't
    `http://gateway1.local:3000` (so a malicious page in the operator's
    browser can't drive their local mmo).
18. **launchd plist.** `~/Library/LaunchAgents/com.redo.mmo.plist`,
    `KeepAlive=true`, runs on login.
19. **Log file + rotation.** Output goes to `~/Library/Logs/mmo/`, rotated
    on size.

### Distribution

20. **Install script.** `curl http://gateway1.local:3000/install.sh | bash`:
    - `brew install` deps that aren't already there (palera1n is its own
      `curl|sudo bash` from palera.in, separate).
    - `pipx install pymobiledevice3`.
    - clone or download `marketing-mobile-operations` to a stable path
      (e.g. `/usr/local/share/mmo`).
    - symlink `mmo` to `/usr/local/bin`.
    - install the local server.
    - drop the launchd plist + `launchctl load`.
    - prompt for `.env` values (`WIFI_SSID`, `WIFI_PASS`, `SSH_PASS`).
    - report success.
21. **Update path.** When mmo updates, how does the operator's install pick
    it up? Cheapest: `mmo --self-update` that re-pulls. Cleanest: a homebrew
    tap. Doesn't have to be solved before v1.

---

## What v1 actually needs

Minimum to ship something usable end-to-end:

- Gaps 1, 2, 3, 4 (CLI prep work)
- Gap 5 (palera1n pty) — needed for s1 inside GUI
- Gap 6 (stage 1 mutex)
- Gaps 8, 9 (gateway1 page + prefill)
- Gaps 12–18 (local server)
- Gap 20 (install script)

Can be deferred:

- Gap 7 (sudo) — punt to "operator runs `sudo -v` first" with UI hint
- Gap 10 (install endpoint) — can hand-distribute the install script for
  early users
- Gap 11 (CORS on gateway1) — no data flow needs it yet
- Gap 19 (log rotation) — single file is fine until it isn't
- Gap 21 (update path) — ship without, add when it hurts

## Open questions

1. Local server stack — vanilla Node `http` + `ws` (matches gateway1) vs
   something heavier. Probably the former.
2. launchd auto-start vs `mmo gui` on demand. Auto-start matches the
   "visit gateway1, it just works" UX; on-demand is simpler. Probably
   auto-start.
3. Update story (gap 21).
4. SIM image-capture for provider/activation-code prefill — see follow-up.
