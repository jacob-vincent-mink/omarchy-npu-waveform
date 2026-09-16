#!/usr/bin/python3
"""Publish the fixed NPU energy counter; no IPC or caller-supplied paths."""
import os
from pathlib import Path
import time

OUTPUT = Path('/run/npu-waveform/npu-energy')


def watts(previous, current):
    if previous is None:
        return None
    dt = current[0] - previous[0]
    if dt <= 0 or dt > 3 or current[2] != previous[2]:
        return None
    delta = current[1] - previous[1]
    if delta < 0:
        delta += current[2]
    return delta / (1 << 14) / dt if delta >= 0 else None


# Intel linux-npu-driver's Panther Lake PMT register map: GUID 0x3086000,
# VPU energy at 0x670, little-endian U32 with 14 fractional bits (joules).
# Only this verified GUID is supported; do not guess offsets for other chips.
def npu_zone():
    for path in sorted(Path('/sys/class/intel_pmt').glob('telem*')):
        if (path / 'guid').read_text().strip() == '0x3086000':
            return path
    raise FileNotFoundError('No supported NPU PMT counter')


def npu_counter(zone):
    fd = os.open(zone / 'telem', os.O_RDONLY)
    try:
        raw = os.pread(fd, 4, 0x670)
    finally:
        os.close(fd)
    if len(raw) != 4:
        raise ValueError('Short NPU energy register read')
    return int.from_bytes(raw, 'little'), 1 << 32


def publish(path, current, power):
    power_text = '' if power is None else f'{power:.6f}'
    temporary = path.with_suffix('.tmp')
    temporary.write_text(f'{current[0]:.6f}|{current[1]}|{current[2]}|{power_text}\n')
    temporary.replace(path)


def main():
    os.umask(0o027)
    zone = None
    previous = None
    failed = False
    while True:
        try:
            zone = zone or npu_zone()
            energy, limit = npu_counter(zone)
            current = (time.clock_gettime(time.CLOCK_BOOTTIME), energy, limit)
            publish(OUTPUT, current, watts(previous, current))
            previous = current
            failed = False
        except (OSError, ValueError) as error:
            # Log once per failure; stale snapshots are rejected by the widget.
            if not failed:
                print(f'NPU energy unavailable: {error}', flush=True)
            zone = None
            previous = None
            failed = True
        time.sleep(1)


if __name__ == '__main__':
    main()
