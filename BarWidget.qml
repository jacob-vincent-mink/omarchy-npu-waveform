import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// A deliberately small bar-only view of the kernel's Intel NPU busy counter.
// The one-second cadence follows the driver's recommendation: frequent enough
// to catch inference, slow enough not to perturb job submission.
BarWidget {
  id: root
  moduleName: "jacob.npu"

  property bool available: true
  property real utilization: 0
  property real previousBusyUs: -1
  property double previousSampleMs: 0
  property int frequencyMhz: 0
  property int maxFrequencyMhz: 0
  property double memoryBytes: 0
  property string runtimeState: "unknown"
  property var samples: []
  property var scaleSamples: []
  property real rollingMaximum: 5

  readonly property int configuredSamples: Math.max(12, Math.min(24, Number(setting("sampleCount", 18))))
  readonly property int refreshIntervalMs: Math.max(1000, Number(setting("refreshIntervalMs", 1000)))
  readonly property int scaleWindowSeconds: Math.max(15, Math.min(300, Number(setting("scaleWindowSeconds", 60))))
  readonly property real scaleFloorPercent: Math.max(1, Math.min(25, Number(setting("scaleFloorPercent", 5))))
  readonly property int scaleWindowSamples: Math.max(1, Math.ceil(scaleWindowSeconds * 1000 / refreshIntervalMs))
  readonly property color quietColor: Qt.rgba(0, 0, 0, 0.72)
  readonly property color liveColor: Color.accent
  readonly property string tooltip: available
    ? "NPU  " + utilization.toFixed(1) + "%  ·  scale 0–" + rollingMaximum.toFixed(1)
      + "%  ·  " + frequencyMhz + " / " + maxFrequencyMhz
      + " MHz  ·  " + (memoryBytes / 1048576).toFixed(memoryBytes >= 104857600 ? 0 : 1)
      + " MiB  ·  " + runtimeState
    : "Intel NPU unavailable"

  function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value))
  }

  function pushSample(value) {
    var rawValue = clamp(Number(value) || 0, 0, 100)
    var next = samples.slice(Math.max(0, samples.length - configuredSamples + 1))
    while (next.length < configuredSamples - 1) next.unshift(0)
    next.push(rawValue)
    samples = next

    var nextScale = scaleSamples.slice(Math.max(0, scaleSamples.length - scaleWindowSamples + 1))
    nextScale.push(rawValue)
    scaleSamples = nextScale

    var peak = scaleFloorPercent
    for (var i = 0; i < nextScale.length; i++) peak = Math.max(peak, Number(nextScale[i]) || 0)
    rollingMaximum = clamp(peak, scaleFloorPercent, 100)
  }

  function acceptSample(raw) {
    var parts = String(raw || "").trim().split("|")
    if (parts.length < 5) return

    var busyUs = Number(parts[0])
    var nowMs = Date.now()
    if (!isFinite(busyUs)) return

    if (previousBusyUs >= 0 && previousSampleMs > 0) {
      var elapsedUs = Math.max(1, (nowMs - previousSampleMs) * 1000)
      var busyDeltaUs = Math.max(0, busyUs - previousBusyUs)
      utilization = clamp(busyDeltaUs / elapsedUs * 100, 0, 100)
      pushSample(utilization)
    } else {
      pushSample(0)
    }

    previousBusyUs = busyUs
    previousSampleMs = nowMs
    frequencyMhz = Math.max(0, Number(parts[1]) || 0)
    maxFrequencyMhz = Math.max(0, Number(parts[2]) || 0)
    memoryBytes = Math.max(0, Number(parts[3]) || 0)
    runtimeState = parts[4] || "unknown"
    available = true
  }

  function refresh() {
    if (!sampleProc.running) sampleProc.running = true
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  visible: available

  onSamplesChanged: graph.requestPaint()
  onQuietColorChanged: graph.requestPaint()
  onLiveColorChanged: graph.requestPaint()
  onConfiguredSamplesChanged: pushSample(utilization)
  onRollingMaximumChanged: graph.requestPaint()

  Process {
    id: sampleProc
    command: [
      "sh", "-c",
      "for d in /sys/bus/pci/drivers/intel_vpu/* /sys/devices/pci0000:00/0000:00:0b.0; do "
        + "[ -r \"$d/npu_busy_time_us\" ] || continue; "
        + "printf '%s|%s|%s|%s|%s\\n' \"$(cat \"$d/npu_busy_time_us\")\" "
        + "\"$(cat \"$d/npu_current_frequency_mhz\" 2>/dev/null || echo 0)\" "
        + "\"$(cat \"$d/npu_max_frequency_mhz\" 2>/dev/null || echo 0)\" "
        + "\"$(cat \"$d/npu_memory_utilization\" 2>/dev/null || echo 0)\" "
        + "\"$(cat \"$d/power/runtime_status\" 2>/dev/null || echo unknown)\"; exit 0; done; exit 1"
    ]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.acceptSample(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.previousBusyUs < 0) root.available = false
    }
  }

  Timer {
    interval: root.refreshIntervalMs
    running: root.available
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: root.vertical ? root.barSize : Style.space(46)
    fixedHeight: root.vertical ? Style.space(46) : root.barSize
    hasVisualContent: true
    labelVisible: false
    pressable: false
    tooltipText: root.tooltip

    Canvas {
      id: graph
      anchors.centerIn: parent
      width: root.vertical ? Style.space(13) : Style.space(34)
      height: root.vertical ? Style.space(34) : Style.space(13)
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var values = root.samples
        if (!values || values.length === 0) return

        var count = values.length
        var breadth = root.vertical ? height : width
        var depth = root.vertical ? width : height
        var center = depth / 2
        var maxAmplitude = Math.max(1, center - 1)

        function along(index) {
          return count <= 1 ? 0 : index * (breadth - 1) / (count - 1)
        }

        function amplitude(index) {
          return maxAmplitude * root.clamp(Number(values[index]) || 0, 0, root.rollingMaximum)
            / root.rollingMaximum
        }

        function point(index, side) {
          var a = along(index)
          var d = center + side * amplitude(index)
          return root.vertical ? { x: d, y: a } : { x: a, y: d }
        }

        // Draw a neutral idle centerline. Activity is overlaid using the live
        // Omarchy accent, so theme changes are picked up automatically.
        ctx.beginPath()
        if (root.vertical) {
          ctx.moveTo(center, 0)
          ctx.lineTo(center, breadth - 1)
        } else {
          ctx.moveTo(0, center)
          ctx.lineTo(breadth - 1, center)
        }
        ctx.lineWidth = Math.max(1, Style.spaceReal(1))
        ctx.strokeStyle = root.quietColor
        ctx.stroke()

        // Fill the mirrored, adaptively scaled utilization envelope.
        var p = point(0, -1)
        ctx.beginPath()
        ctx.moveTo(p.x, p.y)
        for (var i = 1; i < count; i++) {
          p = point(i, -1)
          ctx.lineTo(p.x, p.y)
        }
        for (var j = count - 1; j >= 0; j--) {
          p = point(j, 1)
          ctx.lineTo(p.x, p.y)
        }
        ctx.closePath()
        ctx.fillStyle = Qt.rgba(root.liveColor.r, root.liveColor.g, root.liveColor.b, 0.22)
        ctx.fill()

        // Trace only active segments. Idle portions retain the black baseline.
        ctx.lineWidth = Math.max(1, Style.spaceReal(1))
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.strokeStyle = Qt.rgba(root.liveColor.r, root.liveColor.g, root.liveColor.b, 0.96)
        for (var side = -1; side <= 1; side += 2) {
          for (var k = 1; k < count; k++) {
            if ((Number(values[k - 1]) || 0) <= 0 && (Number(values[k]) || 0) <= 0) continue
            var from = point(k - 1, side)
            var to = point(k, side)
            ctx.beginPath()
            ctx.moveTo(from.x, from.y)
            ctx.lineTo(to.x, to.y)
            ctx.stroke()
          }
        }
      }
    }
  }
}
