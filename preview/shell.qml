import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "plugin" as Plugin

ShellRoot {
  id: preview
  property bool demo: Quickshell.env("NPU_PREVIEW_DEMO") === "1"
  QtObject {
    id: mockBar
    property bool vertical: false
    property int barSize: Style.space(32)
    property string position: "top"
    property color foreground: Color.foreground
    property color barForeground: Color.foreground
    property color background: Color.background
    property color urgent: Color.urgent
    property string fontFamily: Style.font.family
    property bool foregroundAnimationEnabled: true
    property var activePopout: null
    property var clickTargets: []
    function registerClickTarget(t) { clickTargets = clickTargets.concat([t]) }
    function unregisterClickTarget(t) { clickTargets = clickTargets.filter(function(v) { return v !== t }) }
    function showTooltip(t, text) {}
    function hideTooltip(t) {}
    function requestPopout(t) { activePopout = t }
    function releasePopout(t) { if (activePopout === t) activePopout = null }
  }
  IpcHandler {
    target: "preview"
    function state(): string {
      return JSON.stringify({ open: widget.opened, metrics: widget.selectedMetrics.map(function(m) { return m.key }),
        geometry: [widget.width, widget.height, widget.implicitWidth, widget.implicitHeight], samples: widget.telemetry.history.length, current: widget.telemetry.current })
    }
    function capture(): void {
      if (!Quickshell.env("NPU_PREVIEW_CAPTURE")) return
      capture.grabToImage(function(result) { result.saveToFile(Quickshell.env("NPU_PREVIEW_CAPTURE")) })
    }
    function open(): void { widget.open() }
    function close(): void { widget.close() }
    function check(): string {
      var original = widget.settings
      widget.settings = { showUtilization: true }
      widget.selectMetric({ key: "utilization", setting: "showUtilization" })
      if (widget.selectedMetrics.length !== 1) throw new Error("Last metric was removed")
      widget.selectMetric({ key: "frequency", setting: "showFrequency" })
      if (widget.selectedMetrics.length !== 2) throw new Error("Multi-select failed")
      widget.selectMetric({ key: "utilization", setting: "showUtilization" })
      if (widget.selectedMetrics[0].key !== "frequency") throw new Error("Deselection failed")
      widget.settings = original
      return "Selection checks passed"
    }
    function vertical(value: bool): void { mockBar.vertical = value }
  }
  FloatingWindow {
    id: window
    title: "NPU Waveform · native panel preview"
    implicitWidth: Style.space(520)
    implicitHeight: Math.min(screen ? screen.height - 80 : 900, main.implicitHeight + Style.space(48))
    color: Color.background
    visible: true
    Item {
      id: capture
      anchors.fill: parent
      Rectangle { anchors.fill: parent; color: Color.popups.background }
      Flickable {
        anchors.fill: parent
        anchors.margins: Style.space(24)
        contentHeight: main.implicitHeight
        clip: true
        Column {
          id: main
          width: parent.width
          spacing: Style.space(20)
          Text { text: preview.demo ? "DESIGN PREVIEW · SIMULATED HISTORY" : "NPU Waveform"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Rectangle {
            width: parent.width
            height: Math.max(Style.space(48), widget.implicitHeight + Style.space(16))
            color: Color.popups.background
            Plugin.BarWidget {
              id: widget
              stacked: false
              anchors.centerIn: parent
              bar: mockBar
              settings: ({ showUtilization: true, showFrequency: true, showMemory: true, showNpuPower: true })
              telemetry.sampling: !preview.demo
              Component.onCompleted: {
                if (!preview.demo) return
                var values = []
                for (var i = 0; i <= 60; i++) {
                  var busy = i < 8 || i > 52 ? 0 : Math.max(0, Math.sin(i * .26) * 32 + 38 + Math.sin(i * 1.7) * 9)
                  values.push({ time: i, utilization: busy, frequency: busy ? 900 + busy * 12 : 0,
                    maxFrequency: 2050, memory: 76 + (i > 12 && i < 49 ? 42 : 0), npuPower: busy * 0.065, npuPowerState: "reader",
                    state: "suspended", sleepPercent: busy ? 0 : 100 })
                }
                widget.telemetry.history = values
                widget.telemetry.current = values[values.length - 1]
              }
            }
          }
          Plugin.PerformanceContent {
            width: parent.width
            hostWidget: widget
            onCloseRequested: window.visible = false
          }
        }
      }
    }
    Timer {
      interval: 1800
      running: !!Quickshell.env("NPU_PREVIEW_CAPTURE")
      onTriggered: capture.grabToImage(function(result) {
        result.saveToFile(Quickshell.env("NPU_PREVIEW_CAPTURE"))
        console.log("Preview captured")
      })
    }
  }
}
