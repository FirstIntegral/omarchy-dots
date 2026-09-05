# Decisions & Rationale (ADRs)

## 2026-09-05 Curated private pack, not whole ~/.config
- Ship only files that diverge from Omarchy stock and are portable across machines.
- Rejected: rsync of all `~/.config` (Chromium profiles, tokens, fcitx, machine churn).
- Rejected: GNU Stow (official manual hint; inverted layout, extra moving parts).
- Rejected: community config-sync bar plugin (not needed; git + `apply.sh` is the contract).
- Rejected: waiting for unshipped `omarchy dots push/pull` (Omarchy 4.0.2 has no such command).

## 2026-09-05 Machine-specific files stay off the remote
- Never ship `hypr/monitors.lua`. Display layout is per machine. `apply.sh` refuses if that file appears in the pack.
- Strip Huion G930L `hl.device` ignores from `hypr/input.lua`. Those belong on the tablet desktop only.
- Skip stock files (looknfeel, autostart, branding, menu jsonc, invitation hooks) so a newer Omarchy on the other box keeps its packaged defaults.

## 2026-09-05 Vigil is a separate private repo
- Do not vendor Vigil into this pack. `apply.sh` clones `git@github.com:FirstIntegral/vigil.git` via `omarchy plugin add`.
- `brwsk.tray` has no git remote; it is vendored here because `shell.json` hardcodes that plugin id (a clone of `omarchy.tray` with the overflow drawer removed).

## 2026-09-05 apply.sh is the only mutation path
- Another AI on the destination machine runs `./apply.sh`, it does not invent a copy of `~/.config`.
- Apply backs up overwritten files under `~/.config/omarchy-dots-backup.<timestamp>/`.
- Never writes `/usr/share/omarchy/`. Never runs `omarchy refresh` (that resets to defaults).
