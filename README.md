# NPU Waveform

A compact Omarchy bar widget for Intel NPUs using the `intel_vpu` kernel driver.

The widget samples `npu_busy_time_us` once per second and converts the delta to utilization. Activity appears as a dense, mirrored audio-style waveform growing from a black idle centerline in your current Omarchy accent color.

Its amplitude adapts to the highest utilization seen over the last 60 seconds, with a 5% minimum scale ceiling. This keeps small NPU bursts visible without misrepresenting the raw value, which is always shown in the hover tooltip alongside the current scale, frequency, memory utilization, and runtime power state.

It does not require a daemon, elevated privileges, network access, or an MCP server.

## Requirements

- Omarchy Quattro with shell plugin support
- An Intel NPU using the `intel_vpu` kernel driver
- Read access to the driver's `npu_busy_time_us` sysfs counter

## Install

```bash
omarchy plugin add https://github.com/jacob-vincent-mink/omarchy-npu-waveform.git --enable
omarchy bar move jacob.npu --section right --index 0
```

## Remove

```bash
omarchy plugin disable jacob.npu
omarchy plugin remove jacob.npu
```

## Settings

- `refreshIntervalMs`: polling cadence, 1000–5000 ms
- `sampleCount`: visible history, 12–24 samples
- `scaleWindowSeconds`: rolling maximum window, 15–300 seconds
- `scaleFloorPercent`: smallest adaptive scale ceiling, 1–25%

## External dependencies

None. The widget uses only Quickshell/QML, POSIX `sh`, and Linux sysfs files supplied by the Intel NPU kernel driver.

## License

MIT
