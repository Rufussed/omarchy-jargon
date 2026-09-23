#!/usr/bin/env bash
# Install jargon: CLI on PATH, plugin copied into the Omarchy plugin dir.
#
# The plugin directory is a real copy, not a symlink: the shell's hot-reload
# watcher does not follow symlinked plugin directories, so edits to a linked
# one are never picked up.
set -euo pipefail
src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_dir="$HOME/.config/omarchy/plugins/rufussed.jargon"

mkdir -p "$HOME/.local/bin"
ln -sfn "$src/jargon" "$HOME/.local/bin/jargon"

[ -L "$plugin_dir" ] && rm "$plugin_dir"
mkdir -p "$plugin_dir"
cp -f "$src/plugin/manifest.json" "$src/plugin/Jargon.qml" "$plugin_dir/"

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

omarchy plugin enable rufussed.jargon >/dev/null 2>&1 || true
qs -p /usr/share/omarchy/shell ipc call shell rescanPlugins >/dev/null 2>&1 || true
echo "installed — Super+F9 opens the panel, 'jargon' runs the CLI"
