# omarchy-dots

Private pack of **portable** Omarchy desktop config. Another machine clones this repo and applies it.

This file is the apply playbook. An AI on the destination machine should read **this README** and run `./apply.sh`. Do not invent a different copy. Do not rsync `$HOME`.

Not a full home mirror. `monitors.lua`, Chromium, and stock Omarchy files stay out.

## For the applying AI

You are on the **destination** Omarchy box. This is a config pack, not a software project to extend. There is no `session_compact.md`. Do not invent session state. Do not run `create_project` here.

### Hard rules

- Do **not** copy `hypr/monitors.lua` onto this machine. It is not in the pack. Configure monitors locally (`Super+Space` → Setup → Monitors, or edit `~/.config/hypr/monitors.lua` for **this** hardware).
- Do **not** write `/usr/share/omarchy/` (package-owned; next `omarchy update` wipes it).
- Do **not** rsync or copy all of `~/.config` or `$HOME`.
- Do **not** run `omarchy refresh`, `omarchy refresh hyprland`, `omarchy refresh shell`, or `omarchy reinstall configs`. Those reset to stock.
- Do **not** invent a copy. `./apply.sh` is the only mutation path.
- Do **not** vendor Vigil into this repo. Clone it.
- Do **not** force-push `main`.
- Do **not** `curl | sh`.
- Do **not** skip the dry-run unless the human said to apply immediately.

Writing `~/.config/omarchy/plugins/brwsk.tray`, adding Vigil, installing OpenTabletDriver, and copying Huion `hl.device` ignores **is** the requested apply (user ticket 2026-09-05, Huion included 2026-09-05). Do not treat Vigil's "don't inject plugins" rule as a block on this pack.

### Prerequisites

1. This machine is Omarchy. Prefer **4.0.2-1** `stable` (see `source.json`). Run `omarchy update` first if behind. Cross-major (3.x onto 4.x or the reverse) is unsupported — stop and say so.
2. `gh` authenticated as a user who can clone `FirstIntegral/omarchy-dots` **and** `FirstIntegral/vigil` (both private), with SSH to GitHub (`ssh -T git@github.com`).
3. Network. `apply.sh` may prompt for privilege to install `opentabletdriver` (polkit/sudo). Wait for the human; do not bypass.

Companion that is **not** this pack: agents brain is `git@github.com:FirstIntegral/1config.git` → clone to `~/.agents` → `bash ~/.agents/setup.sh`. Do that only if the human wants agents on this box too.

### Apply

```bash
gh repo clone FirstIntegral/omarchy-dots ~/projects/omarchy-dots
cd ~/projects/omarchy-dots

./apply.sh --dry-run
./apply.sh
```

`apply.sh` will:

1. Refuse root, refuse missing `omarchy`, refuse if `hypr/monitors.lua` is in the pack.
2. Warn on Omarchy version mismatch vs `source.json`. Same major 4.x continues; other majors abort.
3. Copy overwritten files to `~/.config/omarchy-dots-backup.<timestamp>/`.
4. Install the files in the table below. Never touches `monitors.lua` on disk.
5. `omarchy plugin add git@github.com:FirstIntegral/vigil.git --enable --yes` if Vigil is not already present.
6. Copy `shell.json` **after** plugins exist so the bar layout wins.
7. `omarchy theme set "Osaka Jade"` and `omarchy font set "JetBrainsMono Nerd Font"`.
8. `omarchy pkg aur add opentabletdriver` (AUR — may prompt for sudo) if `otd-daemon` is missing, copy `opentabletdriver/settings.json` → `~/.config/OpenTabletDriver/settings.json`, then `systemctl --user enable --now opentabletdriver.service`.
9. `hyprctl reload` (if Hyprland is running) then `hyprctl configerrors`.
10. `omarchy restart shell`.

If Vigil clone fails (no GitHub SSH), the rest still lands. Fix SSH, install Vigil, re-run `./apply.sh`.

### Boot sync (this repo is the source of truth)

`sync.sh` runs at every login from the 1config boot dashboard (also safe to run by hand):

```bash
bash ~/projects/omarchy-dots/sync.sh
```

It fetches `origin/main` (validated remote, BatchMode, ff-only), pulls if behind, then drift-checks every pack file against the live `~/.config` target. Drift → runs `./apply.sh --no-pkg` automatically. Local repo edits are never touched — apply only reads the repo and writes `~/.config`.

`--no-pkg` because OS packages need sudo: if `opentabletdriver` is missing, sync reports it and continues; install once by hand with `omarchy pkg aur add opentabletdriver`.

Exit codes: `0` in sync / applied · `1` fetch failed · `2` local commits ahead (nothing applied) · `3` dirty repo (nothing pulled) · `4` divergence/apply failed · `5` files in sync but opentabletdriver package missing.

### After apply

1. Set monitors on **this** machine. Do not copy another box's `monitors.lua`.
2. Plug in the Huion G930L. Hyprland ignores the kernel HID clone; OpenTabletDriver owns the board (LinuxArtistMode). If the mapped area feels wrong on this screen, open OpenTabletDriver and remap display — `settings.json` carries a 1200×675 mapping from the source box.
3. Fingerprint reader? `omarchy setup security fingerprint` — do not copy PAM files.
4. Confirm: `omarchy theme current`, `omarchy plugin list`, `hyprctl configerrors`, `systemctl --user status opentabletdriver.service`.

## What lands

| Pack path | Lands at |
|-----------|----------|
| `hypr/bindings.lua` | `~/.config/hypr/bindings.lua` |
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` |
| `hypr/input.lua` | `~/.config/hypr/input.lua` (pointer sensitivity + Huion G930L `hl.device` ignores) |
| `omarchy/shell.json` | `~/.config/omarchy/shell.json` |
| `omarchy/defaults/agent` | `~/.config/omarchy/defaults/agent` (`grok`) |
| `plugins/brwsk.tray/` | `~/.config/omarchy/plugins/brwsk.tray/` |
| `opentabletdriver/settings.json` | `~/.config/OpenTabletDriver/settings.json` |

Also: Vigil clone, Osaka Jade, JetBrainsMono Nerd Font, `opentabletdriver` package + user service.

Bindings this pack owns: `SUPER+L` lock, `SUPER+F` file manager, `SUPER+S` screenshot. Bar: tray + Vigil on the right, clock format `dddd HH:mm`, idle lock effectively off (`31536000` seconds). `hyprland.lua` prepends `~/.local/bin` to `PATH`.

## What stays out

- `hypr/monitors.lua` — per machine
- Chromium / browser profiles, tokens, fcitx
- Stock Omarchy files (looknfeel, autostart, branding, menu jsonc, invitation hooks)
- OpenTabletDriver `Logs/`
- Agents brain (`FirstIntegral/1config`)

## Updating the pack (source machine)

When portable config changes on the source box, copy the changed files into this repo (still no `monitors.lua`), commit, push. Destination: `git pull && ./apply.sh`.

## Repo

- Remote: `git@github.com:FirstIntegral/omarchy-dots.git` (private)
- Companion plugin: `git@github.com:FirstIntegral/vigil.git` (private, installed by `apply.sh`)
- Brain / agents: `git@github.com:FirstIntegral/1config.git` → `~/.agents` + `bash ~/.agents/setup.sh`
