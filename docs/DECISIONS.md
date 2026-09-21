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

## 2026-09-19 Bar id is brwsk.vigil; boot sync must not restore xyz
- Plugin id renamed 2026-09-17. Pack `omarchy/shell.json` still said `xyz.brwsk.vigil`. Login `sync.sh` saw drift after any live fix and re-applied the old id. Eye vanished on every reboot. Overlay still ran (plugin dir is `brwsk.vigil`).
- Pack bar id is now `brwsk.vigil`. Presence checks and clone URL follow `FirstIntegral/Vigil.git`.
- Rejected: fixing only `~/.config/omarchy/shell.json` (next login overwrites it). Rejected: stopping boot sync.

## 2026-09-05 apply.sh is the only mutation path
- Another AI on the destination machine runs `./apply.sh`, it does not invent a copy of `~/.config`.
- Apply backs up overwritten files under `~/.config/omarchy-dots-backup.<timestamp>/`.
- Never writes `/usr/share/omarchy/`. Never runs `omarchy refresh` (that resets to defaults).

## 2026-09-05 README.md is the apply playbook
- GitHub shows README on the repo home. Destination AIs read that file, not a chat transcript.
- `AGENTS.md` points at README and restates the hard rules for tools that auto-load AGENTS first.

## 2026-09-19 Pack is appearance + shortcuts, not plugins or tablet
- Login `sync.sh` was a second product installer: Vigil clone, hardcoded `shell.json` bar ids (`xyz.brwsk.vigil` then `brwsk.vigil`), vendored `brwsk.tray`, AUR OpenTabletDriver + `settings.json` overwrite. That clobbered a live Vigil bar id on every boot and would fight `~/Projects/agentic-OpenTabletDriver` (fork daemon, `~/.config/OpenTabletDriver`, user unit drop-in).
- Pack now copies hypr bindings / hyprland / input, Chromium flags, default agent, screensaver wrapper, and sets Osaka Jade + JetBrainsMono. No `shell.json`. No plugins. No OpenTabletDriver. No `omarchy plugin add`. No `omarchy restart shell`.
- `source.json` dropped `vigil_repo`, `opentabletdriver`, `huion`. Hypr still ignores the G930L kernel HID so a tablet driver can own the pen; that is compositor config, not OTD settings.
- Rejected: keeping Vigil in the pack with the renamed id (still a hardcoded plugin). Rejected: shipping OTD 0.6.7-2 from AUR next to the fork. Rejected: turning off boot sync (hypr/theme still want it).

## 2026-09-14 Chromium pins `--password-store=basic`
- Symptom: after some Omarchy updates the browser is logged out of every site without being touched.
- Evidence: at boot after the 2026-09-12/14 updates, `gnome-keyring-daemon` logged `keyring was in an invalid or unrecognized format` for both `Default_keyring.keyring` and `Default_Keyring.keyring`; Secret Service came up empty, Chromium minted a fresh "Chromium Safe Storage" key, and every cookie/password encrypted under the old key became undecryptable.
- Omarchy migration 1784508556 pins `gnome-libsecret` to stop libsecret↔basic flapping, but that assumes a healthy keyring — this machine's keyring corrupts.
- Ship `chromium/chromium-flags.conf` (whole file, since Chromium has no per-flag drop-in) with `--password-store=basic`. The basic key is hardcoded, so it survives any keyring state. Cost: at-rest protection is obfuscation only; LUKS covers disk theft and an unlocked keyring was already readable by any process as this user.
- Rejected: repairing the default keyring (root cause of the corruption not established; recurrence risk). Rejected: re-encrypting the profile from the libsecret key to the basic key (fragile OSCrypt internals, risk of profile damage). Rejected: leaving `gnome-libsecret` (recurring logouts).

## 2026-09-22 Default wallpaper pinned by name; images owned by omarchy-wallpapers
- Boot sync reported "1 drift item fixed" yet the wallpaper was wrong: `apply.sh` runs `omarchy theme set`, which **rotates** the theme background every run, and the live selection (`~/.local/state/omarchy/current/background` symlink) was never drift-checked. The other boot drift was `hypr/hyprland.lua`: live carried imv fullscreen window rules (added by the wallpapers project) that the pack lacked, so every apply clobbered them — the rules now ship in the pack (the pack owns that file).
- `source.json` gains `wallpaper` (file name only, current pick `28-jade-bamboo-path.jpg`) and `wallpaper_repo` (`FirstIntegral/omarchy-wallpapers`). `apply.sh` re-pins it after `theme set` via `omarchy theme bg set <project path>`; `sync.sh` treats a wrong live background as drift. Both skip with a note when the project is not cloned (portable).
- No image files enter this pack. Sole copy stays `~/Projects/omarchy-wallpapers/backgrounds/`; the `~/.config/omarchy/backgrounds/<theme>/` farm remains symlinks only — that is how `omarchy theme bg next` sees the set (project design: "Omarchy gets symlinks only").
- Rejected: vendoring the 300 JPEGs into the pack (bloats a config repo, forks the catalog, CC-BY attribution lives with the project). Rejected: dropping `theme set` from apply to stop rotation (theme install/extras must stay; re-pinning is enough).
- Fixed in passing: `sync.sh` read `source.json` cwd-relative (`open("source.json")`) — the theme drift check silently no-op'd when run from outside the repo; now `"$ROOT/source.json"`.

## 2026-09-22 Theme set must not rotate the pinned wallpaper
- This boot's `omarchy theme set` (dots apply saw drift and ran it) moved the background through `01`, `02`, and `03`. `choose_theme_background` compares `readlink` of `current/background` (the project path) with `find -L` output (the symlink path under `~/.config/omarchy/backgrounds/osaka-jade/`). Those strings never match, so every theme set jumps to the first image, then the second call inside theme set advances one more. Re-pinning afterwards is a race with the shell's theme transition.
- `apply.sh` now sets `OMARCHY_THEME_SKIP_BACKGROUND=1` for `omarchy theme set`, then `omarchy theme bg set` only if the live file differs. `sync.sh` treats wallpaper-only drift as a re-pin, not a full apply. `repin-wallpaper` is installed on `post-boot` and `theme-set` so a login still restores the pin when GitHub fetch fails (sync exits before the drift check) and when anything else runs theme set on Osaka Jade.
- Still no image files in this pack. Still no copies in `~/.config`. The only bytes are `~/Projects/omarchy-wallpapers/backgrounds/`. The config directory holds symlinks so `omarchy theme bg next` can see the catalog; `current/background` points straight at the project file.
- Rejected: copying the JPEG into the pack or into `~/.config` (user wants one home for the project). Rejected: dropping `theme set` from apply (theme extras still have to run). Rejected: relying on re-pin-after-rotate (this boot already lost that race until a later `bg set`).

## 2026-09-22 Docs name agentic-OpenTabletDriver, not stock OpenTabletDriver
- The apply playbook still said "OpenTabletDriver" as the thing this pack leaves alone. On this machine the driver is the fork `~/Projects/agentic-OpenTabletDriver` (`FirstIntegral/agentic-OpenTabletDriver`). README, AGENTS, and apply/sync wording now say that.
- The fork kept the upstream paths. `~/.config/OpenTabletDriver/` and the `opentabletdriver` user unit are still the right names, and this pack still must not write or install them. Hyprland still only ignores the G930L kernel HID.
- Rejected: documenting a new config directory (the fork did not move it). Rejected: vendoring the fork into this pack (already rejected 2026-09-19). Rejected: rewriting the 2026-09-05 ADR that records the old "ship settings.json" choice — that entry is history.
