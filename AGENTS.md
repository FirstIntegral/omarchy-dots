# omarchy-dots

Portable Omarchy desktop config pack for Brusk. Private GitHub repo.

You are applying this pack to **this machine**. This is not a software project to extend. There is no `session_compact.md`. Do not invent session state. Do not run `create_project` here.

## Repo

- Remote: `git@github.com:FirstIntegral/omarchy-dots.git` (private)
- Documentation, not authorisation: git remotes decide push; this line is a label.

## What this pack is

A curated subset of `~/.config` from an Omarchy **4.0.2-1** (`stable`) machine, plus an installer.

| Pack path | Lands at |
|-----------|----------|
| `hypr/bindings.lua` | `~/.config/hypr/bindings.lua` |
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` |
| `hypr/input.lua` | `~/.config/hypr/input.lua` |
| `omarchy/shell.json` | `~/.config/omarchy/shell.json` |
| `omarchy/defaults/agent` | `~/.config/omarchy/defaults/agent` (`grok`) |
| `plugins/brwsk.tray/` | `~/.config/omarchy/plugins/brwsk.tray/` |

Also, `apply.sh` clones Vigil (separate private repo) with `omarchy plugin add`, then sets theme **Osaka Jade** and font **JetBrainsMono Nerd Font**.

Bindings this pack owns: `SUPER+L` lock, `SUPER+F` file manager, `SUPER+S` screenshot. Bar: tray + Vigil on the right, clock format `dddd HH:mm`, idle lock effectively off (`31536000` seconds). `hyprland.lua` prepends `~/.local/bin` to `PATH`. `input.lua` sets pointer `sensitivity = 1`.

## HARD RULES — do not

- Do **not** copy `hypr/monitors.lua` onto this machine. It is not in the pack. Configure monitors locally (`Super+Space` → Setup → Monitors, or edit `~/.config/hypr/monitors.lua` for **this** hardware).
- Do **not** write `/usr/share/omarchy/` (package-owned; next `omarchy update` wipes it).
- Do **not** rsync or copy all of `~/.config` or `$HOME`.
- Do **not** run `omarchy refresh`, `omarchy refresh hyprland`, `omarchy refresh shell`, or `omarchy reinstall configs`. Those reset to stock.
- Do **not** invent a copy. `./apply.sh` is the only mutation path.
- Do **not** add Huion / OpenTabletDriver `hl.device` blocks unless **this** machine has that tablet.
- Do **not** vendor Vigil into this repo. Clone it.
- Do **not** force-push `main`.
- Do **not** `curl | sh`.
- Do **not** skip the dry-run unless the human said to apply immediately.

Writing `~/.config/omarchy/plugins/brwsk.tray` and running `omarchy plugin add` for Vigil **is** the requested apply (user ticket 2026-09-05). Do not treat Vigil's "don't inject plugins" rule as a block on this pack.

## Prerequisites

1. This machine is Omarchy. Prefer **4.0.2-1** `stable` (see `source.json`). `omarchy update` first if behind. Cross-major (3.x configs onto 4.x, or the reverse) is unsupported — stop and say so.
2. `gh` authenticated as a user who can clone `FirstIntegral/omarchy-dots` **and** `FirstIntegral/vigil` (both private), with SSH to GitHub (`ssh -T git@github.com`).
3. Network.

Companion that is **not** this pack: agents brain is `git@github.com:FirstIntegral/1config.git` → clone to `~/.agents` → `bash ~/.agents/setup.sh`. Do that only if the human wants agents on this box too.

## Apply (do this)

```bash
# clone if you do not already have the pack
gh repo clone FirstIntegral/omarchy-dots ~/projects/omarchy-dots
cd ~/projects/omarchy-dots

./apply.sh --dry-run
./apply.sh
```

`apply.sh` will:

1. Refuse root, refuse missing `omarchy`, refuse if `hypr/monitors.lua` is in the pack.
2. Warn on Omarchy version mismatch vs `source.json`.
3. Copy overwritten files to `~/.config/omarchy-dots-backup.<timestamp>/`.
4. Install the files in the table above. Never touches `monitors.lua` on disk.
5. `omarchy plugin add git@github.com:FirstIntegral/vigil.git --enable --yes` if Vigil is not already present.
6. Copy `shell.json` **after** plugins exist so the bar layout wins.
7. `omarchy theme set "Osaka Jade"` and `omarchy font set "JetBrainsMono Nerd Font"`.
8. `hyprctl reload` (if Hyprland is running) then `hyprctl configerrors`.
9. `omarchy restart shell`.

If Vigil clone fails (no GitHub SSH), the rest still lands. Install Vigil, then re-run `./apply.sh` so `shell.json` is re-applied.

## After apply

1. Set monitors on **this** machine. Do not copy another box's `monitors.lua`.
2. If this machine has a fingerprint reader: `omarchy setup security fingerprint` — do not copy PAM files.
3. If this machine has a Huion G930L + OpenTabletDriver, add the two `hl.device` ignores to **this** `~/.config/hypr/input.lua` (they were stripped from the pack).
4. Confirm: `omarchy theme current`, `omarchy plugin list`, `hyprctl configerrors`.

## Updating the pack (source machine only)

When portable config changes on the source box, copy the changed files into this repo (still no `monitors.lua`, still no Huion blocks), commit, push. Destination machine: `git pull && ./apply.sh`.
