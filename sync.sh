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
#   4. drift → ./apply.sh (hypr + theme/font + default wallpaper)
#
# Does not touch plugins or agentic-OpenTabletDriver.
#
# Exit codes:
#   0   up to date (no drift), or applied successfully
#   1   fetch failed (offline / auth / remote unreachable)
#   2   local repo ahead (unpushed commits) — nothing applied
#   3   behind but repo dirty — nothing pulled/applied
#   4   divergence / not a repo / wrong branch / wrong remote / apply failed
#   5   live files locally edited (or changed on both sides) — nothing applied
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

# ── drift check: pack files vs live targets ────────────────────────────────
pairs=(
  "hypr/bindings.lua:$HOME_CONFIG/hypr/bindings.lua"
  "hypr/hyprland.lua:$HOME_CONFIG/hypr/hyprland.lua"
  "hypr/input.lua:$HOME_CONFIG/hypr/input.lua"
  "chromium/chromium-flags.conf:$HOME_CONFIG/chromium-flags.conf"
  "omarchy/defaults/agent:$HOME_CONFIG/omarchy/defaults/agent"
  "omarchy/shell.json:$HOME_CONFIG/omarchy/shell.json"
  "local-bin/omarchy-screensaver:$HOME/.local/bin/omarchy-screensaver"
  "omarchy/hooks/repin-wallpaper:$HOME_CONFIG/omarchy/hooks/theme-set.d/repin-wallpaper"
  "omarchy/hooks/repin-wallpaper:$HOME_CONFIG/omarchy/hooks/post-boot.d/repin-wallpaper"
  "omarchy/hooks/heal-keyring:$HOME_CONFIG/omarchy/hooks/post-boot.d/heal-keyring"
)

# Machine-local memory of what this pack last wrote to each target, so sync
# can tell "live was edited locally" from "pack moved" instead of blindly
# re-applying the pack over local tweaks.
STATE_DIR="$HOME/.local/state/omarchy-dots"
STATE_FILE="$STATE_DIR/sync-state"   # lines: "<target path> <sha256 of pack file>"

state_get() { # $1 target path
  [ -f "$STATE_FILE" ] || return 1
  awk -v k="$1" '$1==k {print $2; exit}' "$STATE_FILE"
}
state_put() { # $1 target path  $2 sha256
  mkdir -p "$STATE_DIR"
  local tmp="$STATE_FILE.tmp.$$"
  if [ -f "$STATE_FILE" ]; then
    grep -vF -e "$1 " "$STATE_FILE" > "$tmp" || true
    mv "$tmp" "$STATE_FILE"
  fi
  printf '%s %s\n' "$1" "$2" >> "$STATE_FILE"
}

incoming=() localedits=() bothchanged=() missing=()

for pair in "${pairs[@]}"; do
  src="$ROOT/${pair%%:*}"
  dst="${pair#*:}"
  [ -f "$src" ] || { echo "dots-sync: pack file missing: $src" >&2; exit 4; }
  if [ ! -f "$dst" ]; then
    missing+=("$dst")
    continue
  fi
  live_sha="$(sha256sum "$dst" | cut -d' ' -f1)"
  pack_sha="$(sha256sum "$src" | cut -d' ' -f1)"
  if [ "$live_sha" = "$pack_sha" ]; then
    state_put "$dst" "$pack_sha"
    continue
  fi
  last_sha="$(state_get "$dst" 2>/dev/null || true)"
  if [ -z "$last_sha" ]; then
    incoming+=("$dst")          # no record yet (first sync run) → trust the pack
  elif [ "$last_sha" = "$pack_sha" ]; then
    localedits+=("$dst")        # pack unchanged since last apply → live was edited
  elif [ "$last_sha" = "$live_sha" ]; then
    incoming+=("$dst")          # pack moved, live untouched
  else
    bothchanged+=("$dst")       # pack and live both moved
  fi
done

theme_cur="$(omarchy theme current 2>/dev/null || true)"
theme_want="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["theme"])' "$ROOT/source.json" 2>/dev/null || true)"
theme_drift=""
if [ -n "$theme_want" ] && [ -n "$theme_cur" ] && [ "$theme_cur" != "$theme_want" ]; then
  theme_drift="theme ($theme_cur vs pack $theme_want)"
fi

# Default wallpaper: pinned by name in source.json, owned by the
# omarchy-wallpapers project (NOT this pack — no image files here).
wallpaper="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$ROOT/source.json" 2>/dev/null || true)"
wall_file=""
wall_drift=0
if [ -n "$wallpaper" ]; then
  wall_file="$HOME/Projects/omarchy-wallpapers/backgrounds/$wallpaper"
  live_bg="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
  if [ ! -f "$wall_file" ]; then
    echo "dots-sync: note — pack wallpaper '$wallpaper' missing (clone FirstIntegral/omarchy-wallpapers to ~/Projects/omarchy-wallpapers); not treated as drift"
  elif [ "$live_bg" != "$(readlink -f "$wall_file" 2>/dev/null)" ]; then
    wall_drift=1
  fi
fi

file_drift=0
{ [ ${#missing[@]} -gt 0 ] || [ ${#incoming[@]} -gt 0 ]; } && file_drift=1

if [ "$file_drift" -eq 0 ] && [ ${#localedits[@]} -eq 0 ] && [ ${#bothchanged[@]} -eq 0 ] \
   && [ -z "$theme_drift" ] && [ "$wall_drift" -eq 0 ]; then
  echo "dots-sync: config in sync with origin/$BRANCH"
  exit 0
fi

echo "dots-sync: drift detected:"
[ ${#missing[@]} -gt 0 ]  && printf '  - %s (missing, will install)\n' "${missing[@]}"
[ ${#incoming[@]} -gt 0 ] && printf '  - %s (incoming, will apply)\n' "${incoming[@]}"
[ ${#localedits[@]} -gt 0 ] && printf '  - %s (local edit)\n' "${localedits[@]}"
[ ${#bothchanged[@]} -gt 0 ] && printf '  - %s (changed on both sides)\n' "${bothchanged[@]}"
[ -n "$theme_drift" ] && echo "  - $theme_drift"
[ "$wall_drift" -eq 1 ] && echo "  - wallpaper"

# Local edits (or files changed on both sides) need a human decision. Never
# clobber them silently — and do not apply the rest either: apply.sh installs
# the whole pack, so a mixed apply would overwrite the local edits on the way.
if [ ${#localedits[@]} -gt 0 ] || [ ${#bothchanged[@]} -gt 0 ]; then
  echo "dots-sync: nothing applied — resolve by hand:"
  echo "  keep your edits:  copy the live files into the pack repo, commit, push"
  echo "  force the pack:   run $ROOT/apply.sh (overwrites the edits)"
  if [ ${#missing[@]} -gt 0 ] || [ ${#incoming[@]} -gt 0 ]; then
    echo "  (${#missing[@]} missing / ${#incoming[@]} incoming also waiting; they apply after this is resolved)"
  fi
  exit 5
fi

# Wallpaper-only: re-pin. Do not run apply — `omarchy theme set` rotates the
# background even when the theme name is already correct.
if [ "$wall_drift" -eq 1 ] && [ "$file_drift" -eq 0 ] && [ -z "$theme_drift" ]; then
  echo "dots-sync: wallpaper only — re-pinning $wallpaper (no theme set)"
  if omarchy theme bg set "$wall_file"; then
    echo "dots-sync: wallpaper re-pinned"
    exit 0
  fi
  echo "dots-sync: wallpaper re-pin failed" >&2
  exit 4
fi

if [ -n "$(git -C "$ROOT" status --porcelain --untracked-files=no)" ]; then
  echo "dots-sync: pack repo has uncommitted changes to tracked files — not auto-applying"
  exit 3
fi

echo "dots-sync: applying pack…"
if "$ROOT/apply.sh"; then
  echo "dots-sync: applied (${#missing[@]} missing, ${#incoming[@]} incoming file(s) fixed)"
  for pair in "${pairs[@]}"; do
    state_put "${pair#*:}" "$(sha256sum "$ROOT/${pair%%:*}" | cut -d' ' -f1)"
  done
  exit 0
else
  echo "dots-sync: apply failed" >&2
  exit 4
fi
