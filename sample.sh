#!/bin/sh
# Read-only, one-shot sample. /proc/uptime supplies a monotonic time base.
read -r uptime rest < /proc/uptime
read_value() { if [ -r "$1" ]; then cat "$1" 2>/dev/null; fi; }
device=
for d in /sys/bus/pci/drivers/intel_vpu/*; do
  if [ -r "$d/npu_busy_time_us" ]; then device=$d; break; fi
done
npu_time=
npu_watts=
npu_state=unavailable
if [ -r /run/npu-waveform/npu-energy ]; then
  IFS='|' read -r npu_time npu_energy npu_range npu_watts < /run/npu-waveform/npu-energy
  npu_state=reader
fi
printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
  "$uptime" "$(read_value "$device/npu_busy_time_us")" \
  "$(read_value "$device/npu_current_frequency_mhz")" \
  "$(read_value "$device/npu_max_frequency_mhz")" \
  "$(read_value "$device/npu_memory_utilization")" \
  "$(read_value "$device/power/runtime_status")" \
  "$(read_value "$device/power/runtime_active_time")" \
  "$(read_value "$device/power/runtime_suspended_time")" \
  "$npu_time" "$npu_watts" "$npu_state"
