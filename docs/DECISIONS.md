# Decisions & Rationale (ADRs)

## 2026-10-18 This machine's bar stays transparent; key order stays the 4.0.5 writer
- This box is still omarchy 4.0.4-1. The 4.0.5 update is not installed here. The pack's alphabetical `shell.json` and the Chromium `--no-default-browser-check` line came from the machine that already updated. Login sync applied nothing: this machine's `shell.json` had moved too (`bar.transparent` true since 2026-10-16 17:13, and the pre-update key order).
- Pack `omarchy/shell.json` keeps that 4.0.5 key order and now says `transparent: true`. `./apply.sh --skip-theme` installed it here, plus the Chromium flag that was incoming. Theme and wallpaper were not touched. A sorted file round-trips through `JSON.stringify`, so the update's rewrite does not look like a new local edit. Migration `1791935188` appends the Chromium flag only when it is absent.
- Rejected: applying `transparent: false` (turns this bar opaque). Rejected: putting this machine's pre-update key order back into the pack (the other machine is already on the sorted file; the next update here would sort again and the slip would return). Rejected: waiting for the update to clear the slip (the writer keeps the boolean, so true vs false would still exit 5).

## 2026-10-18 Pack shell.json in the order Omarchy writes
- Same update (omarchy 4.0.4-1 → 4.0.5-1, 18:24) rewrote `~/.config/omarchy/shell.json` at 18:29. `json.load` of the pack file and the live file compare equal. Every object key is alphabetical. Bar ids, `iconOnly`, idle (`screensaver` 600, `lock` 31536000), and `plugins: []` are unchanged. `sync.sh` hashes bytes, so it called this a local edit.
- Pack file is now those live bytes. The shell persists with `JSON.stringify` (`shell.qml` `persistShellConfig`). A sorted file round-trips sorted. Putting the old key order back would make the next save drift again.
- During the update, one `sync.sh` run also saw theme Tokyo Night and a wallpaper miss. A later read was Osaka Jade and `28-jade-bamboo-path.jpg`. Those were not packed.
- Rejected: `./apply.sh` (overwrites the writer's order and can theme-set). Rejected: teaching `sync.sh` to compare JSON semantically (hides a real settings edit that happens to share a hash-unstable file).

## 2026-10-18 Absorb Omarchy's `--no-default-browser-check`
- Omarchy 4.0.5-1 migration `1791935188` appended `--no-default-browser-check` to every existing `~/.config/*-flags.conf`. On this machine that touched `chromium-flags.conf` (and `chrome-flags.conf`, which is not in the pack). Login `sync.sh` saw the pack hash unchanged and the live file moved, so it classified a local edit and applied nothing. The boot slip named that file.
- Pack `chromium/chromium-flags.conf` now matches the live file: the migration's flag, and `--password-store=basic` from 2026-09-14. Stock `/usr/share/omarchy/config/chromium-flags.conf` has the new flag too, but still says `--password-store=gnome-libsecret`. The migration only appends; it did not replace the password-store line.
- Rejected: `./apply.sh` to force the old pack (drops the flag; the next update appends it again and the slip returns). Rejected: copying the stock file (puts `gnome-libsecret` back; keyring corruption still logs Chromium out). Rejected: packing `chrome-flags.conf` (it already matches stock byte for byte; this pack still ships only the Chromium file).

## 2026-10-15 grokbot-brain removed
- Grok Bot re-sends the whole chat on every turn. A compact file and a bar widget do not change that meter. The tracker is deleted: GitHub repo, plugin directory, notes.
- Bar right side no longer has `brwsk.brain`. Order is `brwsk.tray`, `brwsk.vigil`, `firstintegral.1config`, then the stock widgets.
- `SUPER+ALT+B` and `SUPER+ALT+SHIFT+B` are unbound. The pack still does not install plugins. This entry is what stops login sync from putting the id and the binds back.
- Rejected: leaving the bar id so a missing plugin draws nothing. The id is the layout, and the next sync would restore it.

## 2026-10-10 Terminal moves to SUPER+T; Ctrl+C/Ctrl+V are terminal-aware copy/paste
- Terminal: was SUPER+RETURN (default `omarchy-launch-terminal`). Now SUPER+T; both SUPER+T (was: toggle window floating/tiling, now unbound) and SUPER+RETURN are unbound first. The old float toggle is not remapped — restore it on a free key if wanted.
- Ctrl+C / Ctrl+V now copy/paste on the keys themselves. Same terminal detection as Omarchy's universal clipboard bindings (`default/hypr/bindings/clipboard.lua`): terminal tag from `default/hypr/apps/terminals.lua`; terminals get the Ctrl+Insert / Shift+Insert convention, other windows get their native shortcut.
- Ctrl+C is `non_consuming`: the terminal still receives the interrupt, and a selection is additionally copied. Ctrl+V is consumed (a terminal would otherwise hand the tty a quoted-insert); paste replaces vim's Ctrl+V visual block inside a terminal.
- grokbot-brain's two binds (SUPER+ALT+B menu, SUPER+ALT+SHIFT+B attention) moved from the live-only file into the pack; the local-edit drift is resolved by folding, not by forcing.
- Rejected: a plain consuming Ctrl+C (loses SIGINT — a runaway process could not be stopped). Rejected: `wtype`-typed paste (the physically held Ctrl merges into the injected chord; same reason Omarchy uses `send_key_state` with the down/up split). Rejected: foot-only key bindings in `~/.config/foot` (covers foot but not every tagged terminal; the compositor covers all of them, and `apply.sh` does not own foot.ini).

## 2026-10-09 Pack the live bar, including 1config and brwsk.brain
- The live `~/.config/omarchy/shell.json` had drifted from the pack: `brwsk.vigil` gained `iconOnly: false`, and `brwsk.brain` plus `firstintegral.1config` sat on the right. Login `sync.sh` classified that as a local edit and applied nothing.
- The pack file is now that live file. Right side order: `brwsk.tray`, `brwsk.vigil`, `brwsk.brain`, `firstintegral.1config`, then the stock agents / bluetooth / network / audio / power / monitor widgets.
- The pack still does not install plugins. `brwsk.brain` is the grokbot-brain tracker. `firstintegral.1config` is 1config's own plugin and is copied by `~/.agents/setup.sh`. A machine without those directories keeps the ids and draws nothing for them.
- Rejected: packing only `firstintegral.1config` and leaving `brwsk.brain` out (the files would still differ, so login sync would stay on exit 5). Rejected: vendoring either plugin into this repo. Rejected: `apply.sh` as the way to publish the layout (the live file was already the desired layout; copying it into the pack is the edit).

## 2026-10-04 sync.sh re-execs after a fast-forward
- Boot 2026-10-04 00:50 fast-forwarded `06df758` → `3d32d32` (bar layout, heal-keyring, machine map) and still exited 0 with the desktop on the old bar. `~/.config/omarchy/shell.json` stayed the 2026-09-30 file. `heal-keyring` was not installed.
- Cause: `sync.sh` pulled a new `sync.sh` and kept running. Bash reads the script inode it opened. The pre-pull script (`06df758`) does not touch `shell.json`, its watched files matched, so it reported in sync. The dashboard row was green because that process really exited 0.
- Fix: after a successful fast-forward, `exec bash "$ROOT/sync.sh"`. The new process fetches again, sees behind=0, and runs the pulled drift list. No loop.
- Rejected: teaching the 1config dashboard to run `sync.sh` twice. The script is also run by hand; the caller is the wrong place. Rejected: `hash -r` / sourcing the new file (bash does not re-read the already-open script). Rejected: applying from the old script by guessing which files the new one cares about.
- Same turn, `./apply.sh` installed the already-fetched pack onto this machine (live files matched `3d32d32` before this commit). That overwrote the 2026-09-30 bar (screensaver 300s, transparent bar, menu logo, Vigil `iconOnly: false`). Backup: `~/.config/omarchy-dots-backup.20261004-010524/`.

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

## 2026-10-16 Theme picker shows the theme's walls plus one default
- The background switcher lists the current theme's own backgrounds and `~/.config/omarchy/backgrounds/<theme>/`. Osaka Jade's user folder held all 300 catalog symlinks from `omarchy-wallpapers/scripts/install-omarchy.sh`, so that theme's picker showed the stock walls, the pinned default, and the whole project. Other themes have no user folder, so they already showed only their own few walls.
- `repin-wallpaper` now keeps one catalog symlink, the file named in `source.json` (`28-jade-bamboo-path.jpg`), and deletes the other symlinks in `~/.config/omarchy/backgrounds/osaka-jade/` whose target is inside `~/Projects/omarchy-wallpapers/backgrounds/`. Real files and links that point elsewhere stay. Other themes are not given the default.
- Supersedes the 2026-09-22 line that the config directory holds the catalog so `omarchy theme bg next` can see the whole set. The live pin is unchanged.
- Rejected: copying the JPEG into the theme. Rejected: adding the default onto every theme's list. Rejected: leaving the trim only as a one-time `rm` on this machine (the next install or a fresh apply would pour the catalog back; the hook is what holds the list).
