# Pin the OpenCode theme named in source.json. Sourced, not executed.
# No effect until apply.sh or sync.sh calls the pin function.
#
# The theme file is a normal pack file (opencode/themes/<name>.json).
# cli.json and tui.json are not pack files: they may hold other keys.
# The pin writes only the theme name and leaves every other key alone.

# Print nothing when both selectors match. Print one reason line when not.
dots_opencode_theme_drift() {
  local name
  name="$(dots_json_get opencode_theme)"
  [ -n "$name" ] || return 0
  python3 - "$name" "$HOME/.config/opencode/cli.json" "$HOME/.config/opencode/tui.json" <<'PY'
import json, os, sys

name, cli_path, tui_path = sys.argv[1:]

def load(path):
    if not os.path.exists(path):
        return None, "missing"
    try:
        with open(path) as f:
            return json.load(f), None
    except json.JSONDecodeError:
        return None, "invalid JSON"

reasons = []
cli, err = load(cli_path)
if err:
    reasons.append(f"cli.json {err}")
else:
    theme = cli.get("theme")
    got = theme.get("name") if isinstance(theme, dict) else None
    if got != name:
        reasons.append(f"cli.json theme.name is {got!r}")

tui, err = load(tui_path)
if err:
    reasons.append(f"tui.json {err}")
else:
    got = tui.get("theme")
    if got != name:
        reasons.append(f"tui.json theme is {got!r}")

if reasons:
    print("pack wants " + name + "; " + "; ".join(reasons))
PY
}

# $1 theme name. Exit 0 when the selectors match that name.
# Exit 2 when a file that needs a write is not valid JSON or has an
# unexpected theme type. Other keys in either file are kept.
dots_pin_opencode_theme() {
  local name=$1
  [ -n "$name" ] || return 1
  python3 - "$name" "$HOME/.config/opencode/cli.json" "$HOME/.config/opencode/tui.json" <<'PY'
import json, os, sys

name, cli_path, tui_path = sys.argv[1:]
fail = 0
changed = False

def load(path):
    if not os.path.exists(path):
        return None, None
    try:
        with open(path) as f:
            return json.load(f), None
    except json.JSONDecodeError as exc:
        return None, str(exc)

def dump(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".dots-tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)

cli, err = load(cli_path)
if err:
    print(f"WARN: {cli_path} is not valid JSON ({err}); left it", file=sys.stderr)
    fail = 2
elif cli is None:
    dump(cli_path, {
        "$schema": "https://opencode.ai/v2/cli.json",
        "theme": {"name": name},
    })
    changed = True
    print(f"created {cli_path}")
else:
    theme = cli.get("theme")
    if isinstance(theme, dict):
        if theme.get("name") != name:
            theme["name"] = name
            cli["theme"] = theme
            dump(cli_path, cli)
            changed = True
            print(f"pinned {cli_path} theme.name={name}")
    elif theme is None or isinstance(theme, str):
        cli["theme"] = {"name": name}
        dump(cli_path, cli)
        changed = True
        print(f"pinned {cli_path} theme.name={name}")
    else:
        print(f"WARN: {cli_path} theme is {type(theme).__name__}; left it", file=sys.stderr)
        fail = 2

tui, err = load(tui_path)
if err:
    print(f"WARN: {tui_path} is not valid JSON ({err}); left it", file=sys.stderr)
    fail = 2
elif tui is None:
    dump(tui_path, {
        "$schema": "https://opencode.ai/tui.json",
        "theme": name,
    })
    changed = True
    print(f"created {tui_path}")
else:
    got = tui.get("theme")
    if isinstance(got, str) or got is None:
        if got != name:
            tui["theme"] = name
            dump(tui_path, tui)
            changed = True
            print(f"pinned {tui_path} theme={name}")
    else:
        print(f"WARN: {tui_path} theme is {type(got).__name__}; left it", file=sys.stderr)
        fail = 2

if not changed and fail == 0:
    print(f"OpenCode theme already {name}")
sys.exit(fail)
PY
}
