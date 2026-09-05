#!/usr/bin/env bash
# Apply this Omarchy config pack to the current user on this machine.
# Playbook: README.md. Never writes /usr/share/omarchy or hypr/monitors.lua.

set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
DRY_RUN=0
SKIP_VIGIL=0
SKIP_THEME=0
SKIP_PKG=0
VIGIL_URL="git@github.com:FirstIntegral/vigil.git"
BACKUP_ROOT=""

usage() {
  cat <<'EOF'
Usage: ./apply.sh [--dry-run] [--skip-vigil] [--skip-theme] [--no-pkg]

  --dry-run      print the plan; write nothing
  --skip-vigil   do not clone/add Vigil
  --skip-theme   do not run omarchy theme/font set
  --no-pkg       do not install OS packages (unattended runs — AUR/pacman needs sudo)
EOF
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --skip-vigil) SKIP_VIGIL=1; shift ;;
    --skip-theme) SKIP_THEME=1; shift ;;
    --no-pkg) SKIP_PKG=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ $(id -u) -ne 0 ]] || die "refusing to run as root"
command -v omarchy >/dev/null || die "omarchy not on PATH; this pack is for an Omarchy machine"
command -v python3 >/dev/null || die "python3 is required"

[[ -d /usr/share/omarchy ]] || die "/usr/share/omarchy missing; not an Omarchy install"
[[ -e $ROOT/hypr/monitors.lua ]] && die "pack contains hypr/monitors.lua — remove it; monitors are machine-specific"

for req in \
  "$ROOT/hypr/bindings.lua" \
  "$ROOT/hypr/hyprland.lua" \
  "$ROOT/hypr/input.lua" \
  "$ROOT/omarchy/shell.json" \
  "$ROOT/omarchy/defaults/agent" \
  "$ROOT/plugins/brwsk.tray/manifest.json" \
  "$ROOT/plugins/brwsk.tray/Tray.qml" \
  "$ROOT/plugins/brwsk.tray/TrayModel.js" \
  "$ROOT/opentabletdriver/settings.json" \
  "$ROOT/local-bin/omarchy-screensaver" \
  "$ROOT/source.json"
do
  [[ -f $req ]] || die "pack incomplete: missing $req"
done

grep -Eq 'hl\.device\(\{ name = "huion-huion-tablet_g930l' "$ROOT/hypr/input.lua" \
  || die "pack input.lua is missing the Huion G930L hl.device ignores"

python3 - "$ROOT/omarchy/shell.json" <<'PY' || die "omarchy/shell.json is not valid JSON"
import json, sys
json.load(open(sys.argv[1]))
PY

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
PLUGIN_DIR="$OMARCHY_DIR/plugins/brwsk.tray"

OTD_DIR="$HOME_CONFIG/OpenTabletDriver"
LOCAL_BIN_DIR="$HOME/.local/bin"

copy_files=(
  "hypr/bindings.lua:${HYPR_DIR}/bindings.lua"
  "hypr/hyprland.lua:${HYPR_DIR}/hyprland.lua"
  "hypr/input.lua:${HYPR_DIR}/input.lua"
  "omarchy/defaults/agent:${OMARCHY_DIR}/defaults/agent"
  "plugins/brwsk.tray/manifest.json:${PLUGIN_DIR}/manifest.json"
  "plugins/brwsk.tray/Tray.qml:${PLUGIN_DIR}/Tray.qml"
  "plugins/brwsk.tray/TrayModel.js:${PLUGIN_DIR}/TrayModel.js"
  "opentabletdriver/settings.json:${OTD_DIR}/settings.json"
  "local-bin/omarchy-screensaver:${LOCAL_BIN_DIR}/omarchy-screensaver"
)
# shell.json is copied last, after Vigil exists

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
  local pair from to
  for pair in "${copy_files[@]}"; do
    from=${pair%%:*}
    to=${pair#*:}
    log "  $from  ->  $to"
  done
  log "  omarchy/shell.json  ->  ${OMARCHY_DIR}/shell.json   (after plugins)"
  if (( SKIP_VIGIL )); then
    log "  vigil: skipped"
  else
    log "  vigil: omarchy plugin add $VIGIL_URL --enable --yes  (if not already installed)"
  fi
  if (( SKIP_THEME )); then
    log "  theme/font: skipped"
  else
    log "  omarchy theme set \"Osaka Jade\""
    log "  omarchy font set \"JetBrainsMono Nerd Font\""
  fi
  if (( SKIP_PKG )); then
    log "  opentabletdriver: skipped (--no-pkg)"
  else
    log "  omarchy pkg aur add opentabletdriver  (if otd-daemon missing; AUR, may prompt for sudo)"
  fi
  log "  systemctl --user enable --now opentabletdriver.service"
  log "  hyprctl reload + configerrors (if Hyprland is running)"
  log "  omarchy restart shell"
}

plan

if (( DRY_RUN )); then
  log "DRY RUN — nothing written."
  exit 0
fi

BACKUP_ROOT="$HOME_CONFIG/omarchy-dots-backup.$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_ROOT"
log "Backup: $BACKUP_ROOT"

mkdir -p "$HYPR_DIR" "$OMARCHY_DIR/defaults" "$PLUGIN_DIR" "$OTD_DIR"

# Never overwrite monitors.lua — backup it only as a snapshot of current, then leave it.
if [[ -e $HYPR_DIR/monitors.lua || -L $HYPR_DIR/monitors.lua ]]; then
  backup_if_exists "$HYPR_DIR/monitors.lua" "hypr/monitors.lua.untouched"
  log "Left ~/.config/hypr/monitors.lua in place (machine-specific)."
fi

for pair in "${copy_files[@]}"; do
  from=${pair%%:*}
  to=${pair#*:}
  rel=${to#"$HOME_CONFIG/"}
  # targets outside ~/.config (e.g. ~/.local/bin) — strip $HOME/ instead
  [[ $rel != /* ]] || rel=${to#"$HOME/"}
  backup_if_exists "$to" "$rel"
  install_file "$ROOT/$from" "$to"
  log "installed $to"
done

vigil_present=0
if [[ -f $OMARCHY_DIR/plugins/xyz.brwsk.vigil/manifest.json ]]; then
  vigil_present=1
  log "Vigil already installed at ~/.config/omarchy/plugins/xyz.brwsk.vigil"
fi

if (( SKIP_VIGIL )); then
  log "Skipping Vigil install."
elif (( vigil_present )); then
  :
else
  log "Installing Vigil from $VIGIL_URL"
  if omarchy plugin add "$VIGIL_URL" --enable --yes; then
    vigil_present=1
  else
    warn "Vigil install failed. Bar will miss xyz.brwsk.vigil until you fix GitHub SSH and re-run ./apply.sh"
    warn "  ssh -T git@github.com"
    warn "  omarchy plugin add $VIGIL_URL --enable --yes"
  fi
fi

backup_if_exists "$OMARCHY_DIR/shell.json" "omarchy/shell.json"
install_file "$ROOT/omarchy/shell.json" "$OMARCHY_DIR/shell.json"
log "installed $OMARCHY_DIR/shell.json"

if (( ! SKIP_THEME )); then
  omarchy theme set "Osaka Jade" || warn "theme set failed"
  omarchy font set "JetBrainsMono Nerd Font" || warn "font set failed"
fi

if command -v otd-daemon >/dev/null; then
  log "OpenTabletDriver already installed"
elif (( SKIP_PKG )); then
  warn "opentabletdriver not installed and --no-pkg given — run once by hand: omarchy pkg aur add opentabletdriver"
else
  log "Installing opentabletdriver (AUR — may prompt for sudo)"
  omarchy pkg aur add opentabletdriver || warn "opentabletdriver package install failed — install it, then re-run ./apply.sh"
fi
if command -v systemctl >/dev/null; then
  systemctl --user enable --now opentabletdriver.service \
    || warn "could not enable opentabletdriver.service"
else
  warn "systemctl missing; start OpenTabletDriver yourself"
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

if command -v omarchy >/dev/null; then
  omarchy restart shell || warn "omarchy restart shell failed"
fi

log ""
log "DONE. Next:"
log "  1. Set monitors on THIS machine (Super+Space → Setup → Monitors). Do not copy another box's monitors.lua."
log "  2. Fingerprint reader?  omarchy setup security fingerprint"
log "  3. Plug in the Huion G930L. If the mapped area is wrong, open OpenTabletDriver and remap display."
log "  4. Agents brain is separate: clone FirstIntegral/1config to ~/.agents && bash ~/.agents/setup.sh"
if (( ! vigil_present )); then
  log "  5. Vigil is NOT installed. Fix GitHub SSH and re-run ./apply.sh"
fi
