#!/usr/bin/env bash
# Install jargon: CLI on PATH, plugin copied into the Omarchy plugin dir.
#
# The plugin directory is a real copy, not a symlink: the shell's hot-reload
# watcher does not follow symlinked plugin directories, so edits to a linked
# one are never picked up.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="$HOME/.config/omarchy/plugins/rufussed.jargon"
old_icon_dir="$HOME/.config/omarchy/plugins/rufussed.jargon-icon"

mkdir -p "$HOME/.local/bin"
ln -sfn "$plugin_dir/jargon" "$HOME/.local/bin/jargon"

# One plugin id: the panel and the ear icon ship together. (Earlier versions
# installed the icon as a second id, rufussed.jargon-icon; clear that out.)
if [ -d "$old_icon_dir" ]; then
  omarchy plugin disable rufussed.jargon-icon >/dev/null 2>&1 || true
  rm -rf "$old_icon_dir"
fi

[ -L "$plugin_dir" ] && rm "$plugin_dir"
mkdir -p "$plugin_dir"
cp -f "$src"/manifest.json "$src"/Jargon.qml "$src"/BarWidget.qml "$src"/jargon "$plugin_dir/"
rm -rf "$plugin_dir/library"
cp -r "$src"/library "$plugin_dir/library"

# A panel with no way to open it is not installed, so bind by default.
# --no-bind skips this for anyone who manages their own keybindings.
if [ "${1:-}" != "--no-bind" ]; then
  bindings="$HOME/.config/hypr/bindings.lua"
  if grep -q "rufussed.jargon" "$bindings" 2>/dev/null; then
    echo "keybinding already present"
  elif hyprctl binds 2>/dev/null | grep -B2 "key: F9" | grep -q "modmask: 64"; then
    echo "Super+F9 is already bound to something else; skipping."
    echo "  bind it yourself with:"
    echo "  o.bind(\"SUPER + F9\", \"Dictation vocabulary\", \"omarchy-shell shell toggle rufussed.jargon\")"
  else
    [ -f "$bindings" ] && cp "$bindings" "$bindings.bak.jargon-$(date +%Y%m%d-%H%M%S)"
    cat >> "$bindings" <<'BIND'

-- Jargon: F9 dictates, Super+F9 configures what it hears.
o.bind("SUPER + F9", "Dictation vocabulary", "omarchy-shell shell toggle rufussed.jargon")
BIND
    hyprctl reload >/dev/null 2>&1 || true
    echo "bound Super+F9 (bindings.lua backed up first)"
  fi
fi

# Discover newly copied plugins before enabling them. Report failures instead
# of claiming success with a disabled panel and icon.
omarchy-shell shell rescanPlugins
# Enabling puts the ear in the bar. Re-enable from scratch so an install over
# an older layout ends with exactly one entry, in the right place.
omarchy plugin disable rufussed.jargon >/dev/null 2>&1 || true
sleep 1
omarchy plugin enable rufussed.jargon right
echo "installed — Super+F9 opens the panel, 'jargon' runs the CLI"
