#!/bin/sh
# Run as root, passing the desktop user's group. Only that group can read output.
set -eu
[ "$(id -u)" = 0 ] || { echo 'Run with sudo (terminal) or pkexec (desktop).' >&2; exit 1; }
reader_group=${1:?Pass the desktop user group}
case "$reader_group" in ''|*[!a-zA-Z0-9_-]*) echo 'Invalid group' >&2; exit 1;; esac
getent group "$reader_group" >/dev/null
[ -x /usr/bin/python3 ] || { echo 'Python 3 is required for NPU power support.' >&2; exit 1; }
supported=false
for device in /sys/class/intel_pmt/telem*; do
  [ -r "$device/guid" ] || continue
  if [ "$(cat "$device/guid")" = 0x3086000 ] && [ -r "$device/telem" ]; then
    supported=true
    break
  fi
done
[ "$supported" = true ] || {
  echo 'NPU power currently requires Panther Lake PMT telemetry (GUID 0x3086000).' >&2
  exit 1
}
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
install -d -m 0755 -o root -g root /usr/local/libexec
install -m 0644 -o root -g root "$source_dir/reader.py" /usr/local/libexec/npu-waveform-power-reader.py
unit_tmp=$(mktemp)
trap 'rm -f "$unit_tmp"' EXIT HUP INT TERM
sed "s/@GROUP@/$reader_group/" "$source_dir/npu-waveform-power.service" > "$unit_tmp"
install -m 0644 -o root -g root "$unit_tmp" /etc/systemd/system/npu-waveform-power.service
systemctl daemon-reload
systemctl enable --now npu-waveform-power.service
systemctl restart npu-waveform-power.service
