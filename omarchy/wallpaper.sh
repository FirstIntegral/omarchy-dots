# Resolve the wallpaper named in source.json. Sourced, not executed.
# No side effects. apply.sh, sync.sh, and repin-wallpaper all use this.
#
# Image bytes stay out of omarchy-dots. A theme photo is found in the
# installed theme or ~/Projects/starship-theme. A catalog photo is found
# in ~/Projects/omarchy-wallpapers. First hit wins.

dots_source_json() {
  printf '%s\n' "${DOTS_ROOT:-$HOME/Projects/omarchy-dots}/source.json"
}

dots_json_get() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' \
    "$(dots_source_json)" "$1" 2>/dev/null || true
}

dots_theme_slug() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Print the pinned file, or return 1.
# $1 filename  $2 theme slug
dots_resolve_wallpaper() {
  local name=$1 slug=$2 f
  local candidates=(
    "$HOME/.config/omarchy/themes/$slug/backgrounds/$name"
    "$HOME/Projects/starship-theme/backgrounds/$name"
    "/usr/share/omarchy/themes/$slug/backgrounds/$name"
    "$HOME/Projects/omarchy-wallpapers/backgrounds/$name"
  )
  for f in "${candidates[@]}"; do
    if [ -f "$f" ]; then
      printf '%s\n' "$f"
      return 0
    fi
  done
  return 1
}

# Same photo, including Omarchy's staged copy under current/theme.
dots_wallpaper_current() {
  local name=$1 live
  live="$(readlink -f "$HOME/.local/state/omarchy/current/background" 2>/dev/null || true)"
  [ -n "$live" ] && [ "$(basename "$live")" = "$name" ]
}

dots_wallpaper_in_catalog() {
  case "$1" in
    "$HOME/Projects/omarchy-wallpapers/backgrounds"/*) return 0 ;;
    *) return 1 ;;
  esac
}
