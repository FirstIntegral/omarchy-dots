# omarchy-dots

Public pack of **portable** Omarchy desktop config. Another machine clones this repo and applies it.

This file is the apply playbook. An AI on the destination machine should read **this README** and run `./apply.sh`. Do not invent a different copy. Do not rsync `$HOME`.

Appearance and shortcuts only. Bar layout, plugins, and OpenTabletDriver stay on the machine that owns them.

## For the applying AI

You are on the **destination** Omarchy box. This is a config pack, not a software project to extend. There is no `session_compact.md`. Do not invent session state. Do not run `create_project` here.

### Hard rules

- Do **not** copy `hypr/monitors.lua` onto this machine. It is not in the pack. Configure monitors locally (`Super+Space` → Setup → Monitors, or edit `~/.config/hypr/monitors.lua` for **this** hardware).
- Do **not** write `/usr/share/omarchy/` (package-owned; next `omarchy update` wipes it).
- Do **not** rsync or copy all of `~/.config` or `$HOME`.
- Do **not** run `omarchy refresh`, `omarchy refresh hyprland`, `omarchy refresh shell`, or `omarchy reinstall configs`. Those reset to stock.
- Do **not** invent a copy. `./apply.sh` is the only mutation path.
- Do **not** write `~/.config/omarchy/shell.json`. Bar layout is local.
- Do **not** write `~/.config/omarchy/plugins/`. Plugins (Vigil, tray, …) are not this pack.
- Do **not** write `~/.config/OpenTabletDriver/` or install/enable OpenTabletDriver. Tablet driver is a separate project (`agentic-OpenTabletDriver` on this box).
- Do **not** `omarchy plugin add` / `enable` / `remove`.
- Do **not** force-push `main`.
- Do **not** `curl | sh`.
- Do **not** skip the dry-run unless the human said to apply immediately.

### Prerequisites

1. This machine is Omarchy. Prefer **4.0.2-1** `stable` (see `source.json`). Run `omarchy update` first if behind. Cross-major (3.x onto 4.x or the reverse) is unsupported — stop and say so.
2. Network. Theme/font set talks to the local omarchy CLI only.
3. Companion that is **not** this pack: agents brain is `git@github.com:FirstIntegral/1config.git` → clone to `~/.agents` → `bash ~/.agents/setup.sh`. Do that only if the human wants agents on this box too.

### Apply

```bash
gh repo clone FirstIntegral/omarchy-dots ~/Projects/omarchy-dots
cd ~/Projects/omarchy-dots

./apply.sh --dry-run
./apply.sh
```

`apply.sh` will:

1. Refuse root, refuse missing `omarchy`, refuse if `hypr/monitors.lua` is in the pack.
2. Warn on Omarchy version mismatch vs `source.json`. Same major 4.x continues; other majors abort.
3. Copy overwritten files to `~/.config/omarchy-dots-backup.<timestamp>/`.
4. Install the files in the table below. Never touches `monitors.lua`, `shell.json`, plugins, or OpenTabletDriver.
5. `omarchy theme set "Osaka Jade"` and `omarchy font set "JetBrainsMono Nerd Font"` (theme backgrounds come with the theme).
6. `hyprctl reload` (if Hyprland is running) then `hyprctl configerrors`.

### Boot sync

`sync.sh` runs at every login from the 1config boot dashboard (also safe to run by hand):

```bash
bash ~/Projects/omarchy-dots/sync.sh
```

It fetches `origin/main` (validated remote, BatchMode, ff-only), pulls if behind, then drift-checks pack files against live targets. Drift → runs `./apply.sh`. Local repo edits are never touched.

Exit codes: `0` in sync / applied · `1` fetch failed · `2` local commits ahead (nothing applied) · `3` dirty repo (nothing pulled) · `4` divergence/apply failed.

### After apply

1. Set monitors on **this** machine. Do not copy another box's `monitors.lua`.
2. Fingerprint reader? `omarchy setup security fingerprint` — do not copy PAM files.
3. Confirm: `omarchy theme current`, `hyprctl configerrors`. Plugins and the bar are unchanged.

## What lands

| Pack path | Lands at |
|-----------|----------|
| `hypr/bindings.lua` | `~/.config/hypr/bindings.lua` (SUPER+L lock, SUPER+F files, SUPER+S screenshot) |
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` (prepends `~/.local/bin` to PATH) |
| `hypr/input.lua` | `~/.config/hypr/input.lua` (pointer sensitivity; Hyprland ignores the G930L kernel HID so a tablet driver can own it) |
| `chromium/chromium-flags.conf` | `~/.config/chromium-flags.conf` (pins `--password-store=basic`) |
| `omarchy/defaults/agent` | `~/.config/omarchy/defaults/agent` (`grok`) |
| `local-bin/omarchy-screensaver` | `~/.local/bin/omarchy-screensaver` (matrix-only screensaver) |

Also: Osaka Jade + JetBrainsMono Nerd Font. Wallpaper is the theme's backgrounds, not a separate file in this pack.

Chromium pins `--password-store=basic` because a corrupted gnome-keyring (this box gets `invalid or unrecognized format` after some updates) makes Chromium mint a fresh storage key and silently log out of every site.

## What stays out

- `hypr/monitors.lua` — per machine
- `omarchy/shell.json` — bar layout, idle, plugin widget ids
- `~/.config/omarchy/plugins/` — Vigil, tray, anything else
- OpenTabletDriver settings, packages, systemd — `agentic-OpenTabletDriver` owns that
- Chromium profiles, tokens, fcitx (the one Chromium file in the pack is `chromium-flags.conf`)
- Stock Omarchy files (looknfeel, autostart, branding, menu jsonc, invitation hooks)
- Agents brain (`FirstIntegral/1config`)

## Updating the pack (source machine)

When portable config changes on the source box, copy the changed files into this repo (still no `monitors.lua` / `shell.json` / plugins / OpenTabletDriver), commit, push. Destination: `git pull && ./apply.sh`.

## Repo

- Remote: `git@github.com:FirstIntegral/omarchy-dots.git` (public; HTTPS `https://github.com/FirstIntegral/omarchy-dots.git` works read-only)
- Brain / agents: `git@github.com:FirstIntegral/1config.git` → `~/.agents` + `bash ~/.agents/setup.sh`
