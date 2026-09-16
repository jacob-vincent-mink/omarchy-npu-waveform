# NPU Waveform

A compact Omarchy bar widget for Intel NPUs using the `intel_vpu` kernel driver.

The widget samples `npu_busy_time_us` once per second and converts the delta to utilization. Activity appears as a dense, mirrored audio-style waveform growing from a quiet idle centerline in your current Omarchy accent color. History scrolls continuously between samples, and scale changes ease smoothly when a new rolling maximum arrives.

Its amplitude adapts to the highest utilization seen over the last 60 seconds, with a 5% minimum scale ceiling. This keeps small NPU bursts visible without misrepresenting the raw value, which is always shown in the hover tooltip alongside the current scale, frequency, memory utilization, and runtime power state.

Utilization, frequency, and memory telemetry do not require a daemon, elevated privileges, network access, or an MCP server. An optional scoped system service makes NPU power available when the PMT NPU energy counter is restricted.

## Demo

![NPU Waveform in the Omarchy top bar during an active Intel NPU workload](https://github.com/user-attachments/assets/6323762e-0202-4f0f-b735-dbc78cd02d38)

[Watch the waveform respond to several Voxtype OpenVINO workloads running on an Intel NPU.](https://github.com/user-attachments/assets/91047206-8a80-45ae-a695-25a2afc07550)

## Requirements

- Omarchy Quattro with shell plugin support
- An Intel NPU using the `intel_vpu` kernel driver
- Read access to the driver's `npu_busy_time_us` sysfs counter

## Install

```bash
omarchy plugin add https://github.com/jacob-vincent-mink/omarchy-npu-waveform.git --enable
omarchy bar move jacob.npu --section right --index 0
```

Click the waveform to open the performance panel. Select **NPU**, **Frequency**,
**Memory**, and **NPU W** under **In the bar** to add stacked U/F/M/P rows.

### Enable NPU power (optional, requires sudo once)

Dedicated NPU power currently supports **Intel Panther Lake** with PMT GUID
`0x3086000`. Python 3 and systemd are required for the reader. Other NPU
metrics work without this step.

After installing the plugin, run this in a terminal as your normal user:

```sh
sudo sh "$HOME/.config/omarchy/plugins/jacob.npu/power-reader/install.sh" "$(id -gn)"
```

The command prompts for your sudo password, checks hardware support, and
installs a scoped system service that starts at boot. Quickshell continues
running as your normal user. Readings appear automatically within a few
seconds; select **NPU W** to show P in the bar.

Check the service with:

```sh
systemctl status npu-waveform-power.service
```

To update the plugin, run `omarchy plugin update jacob.npu`. If an update
changes the privileged reader, rerun the sudo command above to update its
root-owned copy. If an older widget stays visible after an update, run
`omarchy restart shell` to clear its cached QML.

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

The base widget uses Quickshell/QML, POSIX `sh`, and Linux sysfs. Optional
NPU power support also uses Python 3 and a systemd service.

## License

MIT

## Performance panel and bar metrics

Click the widget to open the native Omarchy panel. It shows aligned 1, 5, or
15 minute histories for activity, frequency, allocated memory, and NPU
power, plus average/peak activity and time spent runtime-suspended. History
starts when the widget loads; missing readings are gaps. The panel activity
axis is fixed at 0–100%, while the bar retains adaptive scaling.

Select multiple metrics under **In the bar**. Each selection gets its own
stacked waveform row: **U** (utilization), **F** (frequency), **M** (memory),
and **P** (NPU watts). At least one metric stays selected. Choices
persist through the shell's normal widget settings API. The rows share one
compact bar slot. The settings form also exposes `showUtilization`,
`showFrequency`, `showMemory`, `showNpuPower`, and optional `showValues` (numeric
values beside horizontal bar graphs).

NPU power comes from a dedicated Intel PMT energy counter through the optional
reader below. It currently supports the verified Panther Lake GUID
`0x3086000`; other platforms report unavailable instead of guessing offsets.
The widget always runs unprivileged. This is NPU energy-derived power, not
an estimate from utilization. Frequency uses the device maximum as its scale;
memory and power use a rolling adaptive maximum. The tooltip reports raw
values. These metrics describe device activity, not inference throughput.

### Local preview and checks

With Omarchy installed, run `sh preview/run.sh` for a separate live preview.
`NPU_PREVIEW_DEMO=1 sh preview/run.sh` displays explicitly labeled simulated
history. The large preview lays selected graphs out horizontally; the actual
bar stacks U/F/M/P in one compact slot. The preview uses installed Omarchy UI
components and the current theme, and never writes bar settings or installs the plugin. Its selections
are temporary. Click the preview bar to exercise the actual anchored panel.

Run `node tests/model.test.cjs` to check utilization, power freshness,
missing data, discontinuities, and time-weighted statistics. Node is needed
only for these development checks, not for the plugin.

### Power-reader internals and removal

For development from a repository checkout, the equivalent install command is:

```sh
sudo sh power-reader/install.sh "$(id -gn)"
```

The installer adds `npu-waveform-power.service` and a root-owned reader under
`/usr/local/libexec`. The service reads only the four-byte NPU energy register
at offset `0x670` for PMT GUID `0x3086000`, once per second. The units are
2^-14 joules with a 32-bit wrapping counter, following Intel's official
[intel-npu-smi register map](https://github.com/intel/linux-npu-driver/blob/main/tools/intel-npu-smi/src/npu_smi_common.cpp)
and [energy decoder](https://github.com/intel/linux-npu-driver/blob/main/tools/intel-npu-smi/src/pmt_telemetry.cpp).

It publishes an atomic snapshot (timestamp, counter, range, watts) to
`/run/npu-waveform/npu-energy`, readable by root and the selected desktop
group. It accepts no commands, has no network, uses an empty capability set,
and has a read-only filesystem except its runtime directory. It does not
change sysfs permissions or elevate Quickshell. Python 3 is required only
for this optional reader. The service starts at boot. Snapshots older than
three seconds are rejected by the widget. It does not collect package power.

Check it with `systemctl status npu-waveform-power.service`. To remove it:

```sh
sudo systemctl disable --now npu-waveform-power.service
sudo rm /etc/systemd/system/npu-waveform-power.service /usr/local/libexec/npu-waveform-power-reader.py
sudo systemctl daemon-reload
```

Reader calculations are covered by `python -B tests/reader.test.py`.
