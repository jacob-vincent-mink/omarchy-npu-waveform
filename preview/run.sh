#!/bin/sh
# Isolated preview using the installed shell's real theme and UI components.
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
shell_root=${OMARCHY_SHELL_ROOT:-$HOME/.local/share/omarchy/shell}
preview_dir=$(mktemp -d /tmp/npu-waveform-preview.XXXXXX)
trap 'rm -rf "$preview_dir"' EXIT HUP INT TERM
ln -s "$shell_root/Commons" "$preview_dir/Commons"
ln -s "$shell_root/Ui" "$preview_dir/Ui"
ln -s "$repo" "$preview_dir/plugin"
cp "$repo/preview/shell.qml" "$preview_dir/shell.qml"
qs -p "$preview_dir"
