# omarchy-dots

Portable Omarchy desktop config pack for Brusk. Public GitHub repo.

**Apply playbook is `README.md`.** Read that file and follow it. `./apply.sh` is the only mutation path. Do not invent a copy.

This is not a software project to extend. There is no `session_compact.md`. Do not invent session state. Do not run `create_project` here.

## Repo

- Remote: `git@github.com:FirstIntegral/omarchy-dots.git` (public)
- Documentation, not authorisation: git remotes decide push; this line is a label.

## Hard rules (also in README.md)

- Do **not** copy `hypr/monitors.lua`. Configure monitors on this machine.
- Do **not** write `/usr/share/omarchy/`.
- Do **not** rsync all of `~/.config` or `$HOME`.
- Do **not** run `omarchy refresh` / `omarchy reinstall configs`.
- Huion G930L ignores + OpenTabletDriver **are** in the pack. Apply them.
- Vigil is a separate public repo; `apply.sh` clones it. That plugin add is the requested apply.
- Do **not** force-push `main`. Do **not** `curl | sh`.
