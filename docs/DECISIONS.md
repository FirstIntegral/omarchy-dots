# Decisions & Rationale (ADRs)

## 2026-09-05 Curated private pack, not whole ~/.config
- Ship only files that diverge from Omarchy stock and are portable across machines.
- Rejected: rsync of all `~/.config` (Chromium profiles, tokens, fcitx, machine churn).
- Rejected: GNU Stow (official manual hint; inverted layout, extra moving parts).
- Rejected: community config-sync bar plugin (not needed; git + `apply.sh` is the contract).
- Rejected: waiting for unshipped `omarchy dots push/pull` (Omarchy 4.0.2 has no such command).

## 2026-09-05 Machine-specific files stay off the remote
- Never ship `hypr/monitors.lua`. Display layout is per machine. `apply.sh` refuses if that file appears in the pack.
- Skip stock files (looknfeel, autostart, branding, menu jsonc, invitation hooks) so a newer Omarchy on the other box keeps its packaged defaults.

## 2026-09-05 Huion G930L is part of the pack
- Both machines use the same board. Ship the Hyprland `hl.device` ignores (kernel HID clone is the wrong size; OpenTabletDriver owns the tablet) and `OpenTabletDriver/settings.json` (LinuxArtistMode profile).
- `apply.sh` installs `opentabletdriver` if missing and enables the user service.
- Rejected: leaving tablet setup as a post-apply footnote. The other box would get a broken pen until someone remembered.
- Display mapping in `settings.json` is 1200×675 from the source box; remap in the OTD UI if this screen differs.
- Still not shipping OTD `Logs/`.

## 2026-09-05 Vigil is a separate private repo
- Do not vendor Vigil into this pack. `apply.sh` clones `git@github.com:FirstIntegral/vigil.git` via `omarchy plugin add`.
- `brwsk.tray` has no git remote; it is vendored here because `shell.json` hardcodes that plugin id (a clone of `omarchy.tray` with the overflow drawer removed).

## 2026-09-05 apply.sh is the only mutation path
- Another AI on the destination machine runs `./apply.sh`, it does not invent a copy of `~/.config`.
- Apply backs up overwritten files under `~/.config/omarchy-dots-backup.<timestamp>/`.
- Never writes `/usr/share/omarchy/`. Never runs `omarchy refresh` (that resets to defaults).

## 2026-09-05 README.md is the apply playbook
- GitHub shows README on the repo home. Destination AIs read that file, not a chat transcript.
- `AGENTS.md` points at README and restates the hard rules for tools that auto-load AGENTS first.
