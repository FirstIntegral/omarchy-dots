-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Lock screen with SUPER + L only (was: toggle workspace layout)
hl.unbind("SUPER + L")
hl.unbind("SUPER + CTRL + L")
o.bind("SUPER + L", "Lock system", "omarchy-system-lock")

-- File manager with SUPER + F (was: fullscreen)
hl.unbind("SUPER + F")
hl.unbind("SUPER + SHIFT + F")
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })

-- Screenshot with SUPER + S only (was: toggle scratchpad; PRINT was screenshot)
hl.unbind("SUPER + S")
hl.unbind("PRINT")
o.bind("SUPER + S", "Screenshot", "omarchy-capture-screenshot")

-- Terminal on SUPER + T (was there: toggle window floating/tiling; SUPER + RETURN
-- no longer opens one either).
hl.unbind("SUPER + T")
hl.unbind("SUPER + RETURN")
o.bind("SUPER + T", "Terminal", { omarchy = "terminal" })

-- Copy / paste on Ctrl + C / Ctrl + V themselves, everywhere, with the same
-- terminal detection Omarchy's universal clipboard bindings use (tag comes from
-- default/hypr/apps/terminals.lua). Terminals get the Ctrl+Insert / Shift+Insert
-- convention; every other window gets its native shortcut.
-- Ctrl + C stays an interrupt: the bind is non_consuming, so the focused app
-- still receives the key, and a terminal with a selection additionally copies
-- it. Ctrl + V is consumed (a terminal would otherwise send a literal-insert to
-- the tty), so paste replaces vim's Ctrl+V visual block inside a terminal.
local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then
    return false
  end

  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then
      return true
    end
  end

  return false
end

o.bind("CTRL + C", "Copy (terminal aware)", function()
  if active_window_is_terminal() then
    send_shortcut_once("CTRL", "Insert")()
  end
end, { non_consuming = true })

o.bind("CTRL + V", "Paste (terminal aware)", function()
  if active_window_is_terminal() then
    send_shortcut_once("SHIFT", "Insert")()
  else
    send_shortcut_once("CTRL", "V")()
  end
end)

-- grokbot-brain menu (terminal + fzf; this Omarchy has no walker/waybar).
o.bind("SUPER + ALT + B", "Grok Bot brain", "xdg-terminal-exec bash -lc 'BRAIN_HOME=$HOME/Projects/grokbot-brain ~/.local/share/grokbot-brain/omarchy/brain-menu.sh'")
o.bind("SUPER + ALT + SHIFT + B", "Grok Bot brain attention", "xdg-terminal-exec bash -lc 'BRAIN_HOME=$HOME/Projects/grokbot-brain ~/.local/share/grokbot-brain/omarchy/brain-menu.sh attention'")
