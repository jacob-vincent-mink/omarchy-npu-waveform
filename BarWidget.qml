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
  property var animationStartSamples: []
  property real scrollProgress: 1
  property var scaleSamples: []
  property real rollingMaximum: 5
  property real displayMaximum: 5

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

  function renderedSample(index) {
    var target = index < samples.length ? Number(samples[index]) || 0 : 0
    var start = index < animationStartSamples.length
      ? Number(animationStartSamples[index]) || 0
      : target
    return start + (target - start) * scrollProgress
  }

  function pushSample(value) {
    var rawValue = clamp(Number(value) || 0, 0, 100)
    var rendered = []
    for (var sampleIndex = 0; sampleIndex < configuredSamples; sampleIndex++) {
      rendered.push(renderedSample(sampleIndex))
    }
    var next = samples.slice(Math.max(0, samples.length - configuredSamples + 1))
    while (next.length < configuredSamples - 1) next.unshift(0)
    next.push(rawValue)

    animationStartSamples = rendered
    scrollProgress = 0
    samples = next
    scrollAnimation.restart()

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
  onScrollProgressChanged: graph.requestPaint()
  onDisplayMaximumChanged: graph.requestPaint()
  onRollingMaximumChanged: {
    scaleAnimation.from = displayMaximum
    scaleAnimation.to = rollingMaximum
    scaleAnimation.restart()
  }

  NumberAnimation {
    id: scrollAnimation
    target: root
    property: "scrollProgress"
    from: 0
    to: 1
    duration: Math.max(200, root.refreshIntervalMs - 80)
    easing.type: Easing.Linear
  }

  NumberAnimation {
    id: scaleAnimation
    target: root
    property: "displayMaximum"
    duration: 350
    easing.type: Easing.OutCubic
  }

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
    fixedWidth: root.vertical ? root.barSize : Style.space(72)
    fixedHeight: root.vertical ? Style.space(72) : root.barSize
    hasVisualContent: true
    labelVisible: false
    pressable: false
    tooltipText: root.tooltip

    Canvas {
      id: graph
      anchors.centerIn: parent
      width: root.vertical ? Style.space(13) : Style.space(60)
      height: root.vertical ? Style.space(60) : Style.space(13)
      antialiasing: true

      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (!root.samples || root.samples.length === 0) return

        var count = root.samples.length
        var breadth = root.vertical ? height : width
        var depth = root.vertical ? width : height
        var center = depth / 2
        var maxAmplitude = Math.max(1, center - 1)

        function utilizationAt(pixel) {
          if (count <= 1 || breadth <= 1) return root.renderedSample(0)
          var position = pixel / (breadth - 1) * (count - 1)
          var left = Math.floor(position)
          var right = Math.min(count - 1, left + 1)
          var mix = position - left
          // Smooth interpolation gives the measured one-second samples an
          // audio-like envelope without inventing additional activity peaks.
          mix = mix * mix * (3 - 2 * mix)
          return root.renderedSample(left) * (1 - mix) + root.renderedSample(right) * mix
        }

        function edgeTexture(pixel, amount) {
          // Deterministic high-frequency texture keeps the compact silhouette
          // visually waveform-like while always staying inside its data envelope.
          var seed = Math.sin((pixel + 1) * 12.9898 + amount * 78.233) * 43758.5453
          var noise = seed - Math.floor(seed)
          return 0.72 + noise * 0.28
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

        // Dense mirrored amplitude columns produce the audio-waveform shape.
        // Their outer edge is scaled from real utilization and can never exceed it.
        ctx.lineWidth = 1
        ctx.lineCap = "butt"
        ctx.strokeStyle = Qt.rgba(root.liveColor.r, root.liveColor.g, root.liveColor.b, 0.96)
        for (var pixel = 0; pixel < Math.ceil(breadth); pixel++) {
          var amount = root.clamp(utilizationAt(pixel), 0, root.displayMaximum)
          if (amount <= 0) continue
          var scaled = maxAmplitude * amount / root.displayMaximum
          var magnitude = Math.max(0.55, scaled * edgeTexture(pixel, amount))
          ctx.beginPath()
          if (root.vertical) {
            ctx.moveTo(center - magnitude, pixel + 0.5)
            ctx.lineTo(center + magnitude, pixel + 0.5)
          } else {
            ctx.moveTo(pixel + 0.5, center - magnitude)
            ctx.lineTo(pixel + 0.5, center + magnitude)
          }
          ctx.stroke()
        }
      }
    }
  }
}
