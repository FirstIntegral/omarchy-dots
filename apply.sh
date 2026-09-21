#!/usr/bin/env bash
# Apply this Omarchy config pack to the current user on this machine.
# Playbook: README.md. Never writes /usr/share/omarchy or hypr/monitors.lua.
# Does not install plugins, does not touch shell.json, does not touch OpenTabletDriver.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=0
SKIP_THEME=0
BACKUP_ROOT=""

usage() {
  cat <<'EOF'
Usage: ./apply.sh [--dry-run] [--skip-theme]

  --dry-run      print the plan; write nothing
  --skip-theme   do not run omarchy theme/font set
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-theme) SKIP_THEME=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $(id -u) -ne 0 ]] || die "refusing to run as root"
command -v omarchy >/dev/null || die "omarchy not on PATH; this pack is for an Omarchy machine"

[[ -d /usr/share/omarchy ]] || die "/usr/share/omarchy missing; not an Omarchy install"
[[ -e $ROOT/hypr/monitors.lua ]] && die "pack contains hypr/monitors.lua — remove it; monitors are machine-specific"

for req in \
  "$ROOT/hypr/bindings.lua" \
  "$ROOT/hypr/hyprland.lua" \
  "$ROOT/hypr/input.lua" \
  "$ROOT/chromium/chromium-flags.conf" \
  "$ROOT/omarchy/defaults/agent" \
  "$ROOT/local-bin/omarchy-screensaver" \
  "$ROOT/source.json"
do
  [[ -f $req ]] || die "pack incomplete: missing $req"
done

installed=$(omarchy version 2>/dev/null || true)
expected=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["omarchy_version"])' "$ROOT/source.json")
channel=$(omarchy version channel 2>/dev/null || true)
log "This machine: omarchy ${installed:-unknown} (${channel:-unknown channel})"
log "Pack source:  omarchy $expected ($(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["channel"])' "$ROOT/source.json"))"
if [[ -n $installed && $installed != "$expected" ]]; then
  warn "Omarchy version mismatch. Pack is $expected. Cross-major apply is unsupported."
  case "$installed" in
    "$expected") ;;
    4.*) warn "same major (4); continuing" ;;
    *) die "refusing to apply a 4.x pack onto omarchy $installed" ;;
  esac
fi

HOME_CONFIG="${HOME}/.config"
HYPR_DIR="$HOME_CONFIG/hypr"
OMARCHY_DIR="$HOME_CONFIG/omarchy"
LOCAL_BIN_DIR="$HOME/.local/bin"

# Default wallpaper lives in the omarchy-wallpapers project, not in this pack.
# source.json pins the file name; the image itself is owned by that repo.
WALLPAPER="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("wallpaper",""))' "$ROOT/source.json" 2>/dev/null || true)"
WALLPAPER_DIR="$HOME/Projects/omarchy-wallpapers/backgrounds"
WALLPAPER_FILE="$WALLPAPER_DIR/$WALLPAPER"

copy_files=(
  "hypr/bindings.lua:${HYPR_DIR}/bindings.lua"
  "hypr/hyprland.lua:${HYPR_DIR}/hyprland.lua"
  "hypr/input.lua:${HYPR_DIR}/input.lua"
  "chromium/chromium-flags.conf:${HOME_CONFIG}/chromium-flags.conf"
  "omarchy/defaults/agent:${OMARCHY_DIR}/defaults/agent"
  "local-bin/omarchy-screensaver:${LOCAL_BIN_DIR}/omarchy-screensaver"
  "omarchy/hooks/repin-wallpaper:${OMARCHY_DIR}/hooks/theme-set.d/repin-wallpaper"
  "omarchy/hooks/repin-wallpaper:${OMARCHY_DIR}/hooks/post-boot.d/repin-wallpaper"
)

backup_if_exists() {
  local src=$1
  local rel=$2
  [[ -e $src || -L $src ]] || return 0
  local dest="$BACKUP_ROOT/$rel"
  mkdir -p "$(dirname "$dest")"
  cp -a "$src" "$dest"
}

install_file() {
  local from=$1
  local to=$2
  mkdir -p "$(dirname "$to")"
  cp -a "$from" "$to"
}

plan() {
  log "Plan:"
  log "  backup overwritten files under ~/.config/omarchy-dots-backup.<timestamp>/"
  log "  never touch ~/.config/hypr/monitors.lua"
  log "  never touch /usr/share/omarchy/"
  log "  never touch ~/.config/omarchy/shell.json"
  log "  never touch ~/.config/omarchy/plugins/"
  log "  never touch ~/.config/OpenTabletDriver/"
  local pair from to
  for pair in "${copy_files[@]}"; do
    from=${pair%%:*}
    to=${pair#*:}
    log "  $from  ->  $to"
  done
  if (( SKIP_THEME )); then
    log "  theme/font: skipped"
  else
    log "  OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set \"Osaka Jade\""
    log "  omarchy font set \"JetBrainsMono Nerd Font\""
    if [[ -n "$WALLPAPER" ]]; then
      log "  re-pin wallpaper if needed: $WALLPAPER_FILE"
    fi
  fi
  log "  hyprctl reload + configerrors (if Hyprland is running)"
}

plan

if (( DRY_RUN )); then
  log "DRY RUN — nothing written."
  exit 0
fi

BACKUP_ROOT="$HOME_CONFIG/omarchy-dots-backup.$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_ROOT"
log "Backup: $BACKUP_ROOT"

mkdir -p "$HYPR_DIR" "$OMARCHY_DIR/defaults" "$LOCAL_BIN_DIR"

# Never overwrite monitors.lua — backup it only as a snapshot of current, then leave it.
if [[ -e $HYPR_DIR/monitors.lua || -L $HYPR_DIR/monitors.lua ]]; then
  backup_if_exists "$HYPR_DIR/monitors.lua" "hypr/monitors.lua.untouched"
  log "Left ~/.config/hypr/monitors.lua in place (machine-specific)."
fi

for pair in "${copy_files[@]}"; do
  from=${pair%%:*}
  to=${pair#*:}
  rel=${to#"$HOME_CONFIG/"}
  [[ $rel != /* ]] || rel=${to#"$HOME/"}
  backup_if_exists "$to" "$rel"
  install_file "$ROOT/$from" "$to"
  log "installed $to"
done

if (( ! SKIP_THEME )); then
  # theme set rotates the background (and the project-path symlink never matches
  # the config symlink list, so it jumps to the first image). Skip that.
  # The theme-set hook re-pins too, in case something else calls theme set.
  OMARCHY_THEME_SKIP_BACKGROUND=1 omarchy theme set "Osaka Jade" || warn "theme set failed"
  omarchy font set "JetBrainsMono Nerd Font" || warn "font set failed"
  if [[ -n "$WALLPAPER" ]]; then
    if [[ -f "$WALLPAPER_FILE" ]]; then
      live_bg="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
      want_bg="$(readlink -f "$WALLPAPER_FILE")"
      if [[ "$live_bg" != "$want_bg" ]]; then
        omarchy theme bg set "$WALLPAPER_FILE" || warn "wallpaper set failed"
      else
        log "wallpaper already $WALLPAPER"
      fi
    else
      warn "wallpaper '$WALLPAPER' not found — clone omarchy-wallpapers to $WALLPAPER_DIR/.."
    fi
  fi
fi

if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v hyprctl >/dev/null; then
  hyprctl reload || warn "hyprctl reload failed"
  errors=$(hyprctl configerrors 2>/dev/null || true)
  if [[ -n $errors && $errors != "ok" && $errors != "No errors" ]]; then
    warn "hyprctl configerrors:"
    printf '%s\n' "$errors" >&2
  else
    log "hyprctl configerrors: clean"
  fi
else
  warn "Hyprland not running in this session; skip hyprctl reload. Next login picks up hypr files."
fi

log ""
log "DONE. Next:"
log "  1. Set monitors on THIS machine (Super+Space → Setup → Monitors). Do not copy another box's monitors.lua."
log "  2. Fingerprint reader?  omarchy setup security fingerprint"
log "  3. Plugins (Vigil, tray), bar layout, and OpenTabletDriver are not this pack."
log "  4. Agents brain is separate: clone FirstIntegral/1config to ~/.agents && bash ~/.agents/setup.sh"
