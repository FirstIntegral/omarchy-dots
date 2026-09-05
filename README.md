# omarchy-dots

Private pack of **portable** Omarchy desktop config from one machine, for another.

This is not a full home-directory mirror. Monitors, tablet device ignores, Chromium, and stock Omarchy files are out on purpose.

## Human

```bash
gh repo clone FirstIntegral/omarchy-dots ~/projects/omarchy-dots
cd ~/projects/omarchy-dots
./apply.sh --dry-run
./apply.sh
```

Then set monitors on **that** box (`Super+Space` → Setup → Monitors). Do not copy `monitors.lua` from anywhere.

## AI

Read `AGENTS.md`. Run `./apply.sh`. Do not invent a different copy.

## Repo

- Remote: `git@github.com:FirstIntegral/omarchy-dots.git` (private)
- Companion plugin: `git@github.com:FirstIntegral/vigil.git` (private, installed by `apply.sh`)
- Brain / agents setup is **not** this repo: `github.com:FirstIntegral/1config` → `~/.agents` + `bash ~/.agents/setup.sh`
