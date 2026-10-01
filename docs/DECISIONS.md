# Decisions & Rationale (ADRs)

## 2026-10-02 Keyring prompt loop fixed: park unreadable keyrings, promote healthy Default
- Symptom: every Grok Bot or ProtonVPN open popped "Choose password for new keyring"; answering it (empty password) created yet another numbered keyring, and the prompt returned after the next login.
- Root cause: three old keyring files (`Default.keyring`, `Default_keyring.keyring`, `Default_Keyring.keyring`) were unreadable to the daemon — every boot logs `keyring was in an invalid or unrecognized format` for exactly those three. They squatted the canonical names while `~/.local/share/keyrings/default` pointed at `Default`, so the daemon dropped the default collection; any libsecret-using app (Electron safeStorage in Grok Bot and ProtonVPN) then triggered the CreateCollection prompt. Each answer created a numbered file (`Default_1`, `Default_Keyring_N`) but the pointer kept resolving to the squatted name — loop.
- Fix: parked the three unreadable files as `*.bricked-20261002` (bytes kept), moved the healthy empty-password keyring (created via the latest prompt) to `Default.keyring`. The `default` pointer now resolves healthy. Daemon restarted in place (`gnome-keyring-daemon -r`); verified with a secret-tool store/lookup/clear round-trip — no prompt.
- Empty-password (unencrypted) keyrings are the right class on this autologin machine — same pattern as the `gpg-signing` collection. The old encrypted keyrings were already unreadable (contents effectively lost since their creation); parked in case offline recovery is ever wanted.
- Rejected: deleting the unreadable files. Rejected: password-protecting the new default keyring (autologin cannot unlock it → prompt returns). Rejected: `--password-store=basic` for Grok Bot via `grok-bot-flags.conf` (Electron safeStorage ignores the Chromium password-store flag, and the keyring fix covers every app at once).
- **Packed:** `omarchy/hooks/heal-keyring` ships in the pack (applies to `post-boot.d/`, runs once during apply, drift-checked by `sync.sh`). Health signal is the default pointer naming an existing unencrypted keyring plus no "invalid or unrecognized format" lines for the canonical files in this boot's user journal — the D-Bus alias object is deliberately not used (gnome-keyring leaves it dangling even when the default works). Heal parks (never deletes) the three canonical files, writes a fresh empty-password `Default.keyring`, rewrites the pointer, and restarts the daemon in place.

## 2026-10-02 Bar layout packed again; omarchy.menu logo removed
- Reverses the 2026-09-19 "No shell.json" ADR. The user wants the bar layout to ship with the pack, so `omarchy/shell.json` (the full live file) joins `apply.sh` copy_files and `sync.sh` drift pairs.
- Live bar left section was `[omarchy.workspaces, omarchy.menu]` (stock default puts `omarchy.menu` before workspaces; this machine had drifted). The user wants the logo gone entirely: left section is now `omarchy.workspaces` only.
- Ships idle settings too (`screensaver` 600, `lock` 31536000 = effectively never). Bar layout references `brwsk.tray` / `brwsk.vigil`; the pack still never installs plugins (2026-09-19 rule) — apply.sh keeps printing the `omarchy plugin add` note for missing ones, and the widgets just do not render until installed.
- Rejected: keeping the bar local (explicit request). Rejected: shipping only a layout fragment (whole-file contract matches every other pack file and the drift classifier). Rejected: moving the logo back before the workspaces (user asked for removal, not repositioning).

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

## 2026-09-29 Sync drift gets categories; local edits are never clobbered
- Before: any byte diff between a pack file and its live target ran `apply.sh`, which installs the whole pack — a deliberate live tweak (an extra binding tested by hand) was silently overwritten at the next login.
- Now `sync.sh` keeps a machine-local state file `~/.local/state/omarchy-dots/sync-state` recording the sha256 of each target as last applied. Per-file drift is classified: missing / incoming (pack moved, live untouched, or first sync run) / local edit (pack unchanged, live moved) / both changed.
- Auto-apply runs only when drift is purely missing/incoming (+ theme/wallpaper). Any local edit or both-changed file stops the whole apply (apply.sh installs everything, so a mixed apply would clobber the edits) and exits `5` with per-file instructions: copy the live files into the pack and push, or run `apply.sh` to force the pack.
- Theme and wallpaper drift keep their previous handling (theme set / re-pin).
- Rejected: per-file selective apply flags on `apply.sh` (more surface, same human decision needed anyway). Rejected: prompting at boot (unattended; must never hang). Rejected: auto-committing local edits up like config-sync's Publish (pack stays hand-curated; see 2026-09-05 ADR). Rejected: a single "last sync" timestamp (a per-file record is what makes local-edit detection precise).

## 2026-09-29 Default agent is opencode, not grok
- Live `~/.config/omarchy/defaults/agent` said `opencode` (user switched tools; deepseek-v4-pro via opencode). Sync's new local-edit guard refused to clobber it with the pack's `grok`.
- Pack follows the live machine: `omarchy/defaults/agent` and `source.json.default_agent` now say `opencode`.
- Rejected: forcing `grok` back with apply.sh (live state was the deliberate one).

## 2026-09-29 config-sync comparison: what we took, what we rejected
- Compared against `gladimdim.config-sync` (bar plugin: two-way, private repo, syncs everything).
- Adopted: drift categories in `sync.sh` (previous entry). Adopted: a `plugins` list in `source.json` — **info only**: `apply.sh` checks each listed plugin and prints the exact `omarchy plugin add` command for missing ones. Never installs/enables/removes (keeps the 2026-09-19 "no plugins in pack" rule and the bar-layout-stays-local rule; a fresh machine still needs a human to run the command).
- Rejected: Publish / two-way auto-commit (pack stays hand-curated; see 2026-09-05 ADR). Rejected: `.omarchy-config.json` `machine_local` list (exactly one machine-local file today — `monitors.lua`; new pack files are hand-reviewed in the commit that adds them). Rejected: repo-shape validation (my flow has one fixed, validated origin — no free-form URL to mis-paste). Nothing to adopt on exec bits (`cp -a` already preserves them) or no-prompt git (BatchMode already).

## 2026-09-22 Docs name agentic-OpenTabletDriver, not stock OpenTabletDriver
- The apply playbook still said "OpenTabletDriver" as the thing this pack leaves alone. On this machine the driver is the fork `~/Projects/agentic-OpenTabletDriver` (`FirstIntegral/agentic-OpenTabletDriver`). README, AGENTS, and apply/sync wording now say that.
- The fork kept the upstream paths. `~/.config/OpenTabletDriver/` and the `opentabletdriver` user unit are still the right names, and this pack still must not write or install them. Hyprland still only ignores the G930L kernel HID.
- Rejected: documenting a new config directory (the fork did not move it). Rejected: vendoring the fork into this pack (already rejected 2026-09-19). Rejected: rewriting the 2026-09-05 ADR that records the old "ship settings.json" choice — that entry is history.
