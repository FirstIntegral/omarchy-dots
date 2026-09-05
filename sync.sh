#!/usr/bin/env bash
# sync.sh — keep this machine's Omarchy config in line with github:FirstIntegral/omarchy-dots.
#
# Runs at login from the 1config boot dashboard; safe to run anytime:
#   bash ~/Projects/omarchy-dots/sync.sh
#
# Flow:
#   1. fetch origin/main (validated remote only)
#   2. if local repo behind → fast-forward pull (never over local edits, never over unpushed commits)
#   3. drift-check pack files vs ~/.config targets
#   4. drift → ./apply.sh (which ends with hyprctl reload + omarchy restart shell)
#
# Guarantees:
#   * fast-forward only — never rewrites local commits, never clobbers local edits
#   * never prompts (ssh BatchMode) and never hangs (fetch is time-bounded)
#   * monitors.lua is never in the pack, never touched
#
# Exit codes:
#   0   up to date (no drift), or applied successfully
#   1   fetch failed (offline / auth / remote unreachable)
#   2   local repo ahead (unpushed commits) — nothing applied
#   3   behind but repo dirty — nothing pulled/applied
#   4   divergence / not a repo / wrong branch / wrong remote / apply failed
#   5   config files in sync, but opentabletdriver package missing/disabled (sudo needed)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
REMOTE_HTTPS="https://github.com/FirstIntegral/omarchy-dots.git"
REMOTE_SSH="git@github.com:FirstIntegral/omarchy-dots.git"
BRANCH="main"
FETCH_TIMEOUT="${DOTS_SYNC_FETCH_TIMEOUT:-45}"
HOME_CONFIG="${HOME}/.config"

git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "dots-sync: $ROOT is not a git repo" >&2; exit 4; }
[ "$(realpath "$(git -C "$ROOT" rev-parse --show-toplevel)")" = "$(realpath "$ROOT")" ] \
  || { echo "dots-sync: $ROOT is not the repo root" >&2; exit 4; }
[ "$(git -C "$ROOT" branch --show-current)" = "$BRANCH" ] \
  || { echo "dots-sync: not on branch $BRANCH" >&2; exit 4; }

mapfile -t fetch_urls < <(git -C "$ROOT" remote get-url --all origin 2>/dev/null || true)
[ "${#fetch_urls[@]}" -gt 0 ] || { echo "dots-sync: no origin fetch URL" >&2; exit 4; }
for url in "${fetch_urls[@]}"; do
  case "$url" in
    "$REMOTE_HTTPS"|"$REMOTE_SSH") ;;
    *) echo "dots-sync: refusing non-omarchy-dots origin: $url" >&2; exit 4 ;;
  esac
done

# BatchMode: never prompt for a passphrase at boot (ssh-agent must already hold the key).
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"

if ! timeout "$FETCH_TIMEOUT" git -C "$ROOT" fetch -q origin \
     "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"; then
  echo "dots-sync: fetch failed (offline or key not available)" >&2
  exit 1
fi

local_sha="$(git -C "$ROOT" rev-parse "$BRANCH")"
remote_sha="$(git -C "$ROOT" rev-parse "refs/remotes/origin/$BRANCH")"
behind="$(git -C "$ROOT" rev-list --count "$local_sha..$remote_sha")"
ahead="$(git -C "$ROOT" rev-list --count "$remote_sha..$local_sha")"

if [ "$behind" -eq 0 ] && [ "$ahead" -gt 0 ]; then
  echo "dots-sync: $ahead local commit(s) ahead — not pulling"
  exit 2
fi

if [ "$behind" -gt 0 ]; then
  if [ "$ahead" -gt 0 ]; then
    echo "dots-sync: diverged from origin/$BRANCH ($behind behind, $ahead ahead) — needs a manual merge" >&2
    exit 4
  fi
  if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "dots-sync: $behind commit(s) behind but repo dirty — not pulling"
    exit 3
  fi
  if ! git -C "$ROOT" merge --ff-only "refs/remotes/origin/$BRANCH" >/dev/null; then
    echo "dots-sync: non-fast-forward divergence — needs a manual merge" >&2
    exit 4
  fi
  echo "dots-sync: fast-forwarded $behind commit(s) → matches origin/$BRANCH"
fi

# ── drift check: pack files vs live ~/.config targets ───────────────────────
pairs=(
  "hypr/bindings.lua:$HOME_CONFIG/hypr/bindings.lua"
  "hypr/hyprland.lua:$HOME_CONFIG/hypr/hyprland.lua"
  "hypr/input.lua:$HOME_CONFIG/hypr/input.lua"
  "omarchy/defaults/agent:$HOME_CONFIG/omarchy/defaults/agent"
  "omarchy/shell.json:$HOME_CONFIG/omarchy/shell.json"
  "plugins/brwsk.tray/manifest.json:$HOME_CONFIG/omarchy/plugins/brwsk.tray/manifest.json"
  "plugins/brwsk.tray/Tray.qml:$HOME_CONFIG/omarchy/plugins/brwsk.tray/Tray.qml"
  "plugins/brwsk.tray/TrayModel.js:$HOME_CONFIG/omarchy/plugins/brwsk.tray/TrayModel.js"
  "opentabletdriver/settings.json:$HOME_CONFIG/OpenTabletDriver/settings.json"
)

drift=()
for pair in "${pairs[@]}"; do
  src="$ROOT/${pair%%:*}"
  dst="${pair#*:}"
  if [ ! -f "$dst" ]; then
    drift+=("${pair%%:*} (missing)")
  elif ! cmp -s "$src" "$dst"; then
    drift+=("${pair%%:*}")
  fi
done

# theme drift (best-effort; only when omarchy CLI answers)
theme_cur="$(omarchy theme current 2>/dev/null || true)"
theme_want="$(python3 -c 'import json; print(json.load(open("source.json"))["theme"])' 2>/dev/null || true)"
if [ -n "$theme_want" ] && [ -n "$theme_cur" ] && [ "$theme_cur" != "$theme_want" ]; then
  drift+=("theme ($theme_cur vs pack $theme_want)")
fi

# vigil drift
if [ ! -f "$HOME_CONFIG/omarchy/plugins/xyz.brwsk.vigil/manifest.json" ]; then
  drift+=("vigil plugin (missing)")
fi

# opentabletdriver drift — package needs sudo/AUR, which unattended sync cannot do.
# Report only; never blocks apply of the config files.
otd_needs_pkg=0
if ! command -v otd-daemon >/dev/null 2>&1; then
  otd_needs_pkg=1
elif ! systemctl --user is-enabled opentabletdriver.service >/dev/null 2>&1; then
  otd_needs_pkg=1
fi

if [ "${#drift[@]}" -eq 0 ]; then
  if [ "$otd_needs_pkg" -eq 1 ]; then
    echo "dots-sync: config files in sync; opentabletdriver package needs a manual: omarchy pkg aur add opentabletdriver"
    exit 5
  fi
  echo "dots-sync: config in sync with origin/$BRANCH"
  exit 0
fi

echo "dots-sync: drift detected:"
printf '  - %s\n' "${drift[@]}"

# Do not apply over tracked local pack modifications (a human editing the pack
# here). Untracked files are fine — they do not affect apply.sh.
if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
  echo "dots-sync: pack repo has uncommitted changes to tracked files — not auto-applying"
  exit 3
fi

echo "dots-sync: applying pack…"
if [ "$otd_needs_pkg" -eq 1 ]; then
  echo "dots-sync: opentabletdriver missing — applying with --no-pkg; then run: omarchy pkg aur add opentabletdriver"
fi
if "$ROOT/apply.sh" --no-pkg; then
  echo "dots-sync: applied (${#drift[@]} drift item(s) fixed)"
  exit 0
else
  echo "dots-sync: apply failed" >&2
  exit 4
fi
