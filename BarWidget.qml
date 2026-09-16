import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "jacob.npu"
  property bool stacked: true
  readonly property int refreshIntervalMs: Math.max(1000, Math.min(5000, Number(setting("refreshIntervalMs", 1000))))
  readonly property int configuredSamples: Math.max(12, Math.min(24, Number(setting("sampleCount", 18))))
  readonly property int scaleWindowSeconds: Math.max(15, Math.min(300, Number(setting("scaleWindowSeconds", 60))))
  readonly property real scaleFloorPercent: Math.max(1, Math.min(25, Number(setting("scaleFloorPercent", 5))))
  readonly property var selectedMetrics: {
    var selected = Model.metrics.filter(function(m) { return root.setting(m.setting, m.key === "utilization") === true })
    return selected.length ? selected : [Model.metrics[0]]
  }
  property alias telemetry: telemetry
  readonly property bool opened: detail.opened
  readonly property bool popoutSwitchClosing: detail.popoutSwitchClosing
  function open() { detail.open() }
  function close() { detail.close() }
  function toggle() { detail.toggle() }
  function closeForPopoutSwitch() { detail.closeForPopoutSwitch() }
  function selectMetric(metric) {
    var entry = Object.assign({}, settings, { id: moduleName })
    var selected = selectedMetrics.some(function(m) { return m.key === metric.key })
    if (selected && selectedMetrics.length === 1) return
    entry[metric.setting] = !selected
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }
  function ceiling(key) {
    if (key === "frequency") return Math.max(1, telemetry.current.maxFrequency || 1)
    return Model.maximum(telemetry.recent(scaleWindowSeconds), key, key === "utilization" ? scaleFloorPercent : 1)
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Telemetry { id: telemetry; interval: root.refreshIntervalMs }
  PerformancePanel { id: detail; hostWidget: root; anchorItem: button; bar: root.bar }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    fixedWidth: root.vertical ? root.barSize : metricLayout.width + Style.space(16)
    fixedHeight: root.vertical ? metricLayout.height + Style.space(12) : root.barSize
    hasVisualContent: true
    labelVisible: false
    tooltipText: Model.metrics.map(function(m) { return m.title + "  " + Model.format(m.key, telemetry.current[m.key]) + " · scale 0–" + Model.format(m.key, root.ceiling(m.key)) }).join("\n")
      + "\n" + telemetry.current.state + " · Click for history"
    onPressed: function(b) { if (b === Qt.LeftButton) root.toggle() }

    Grid {
      id: metricLayout
      columns: root.stacked ? 1 : root.selectedMetrics.length
      spacing: root.stacked ? 0 : Style.space(12)
      anchors.centerIn: parent
      readonly property real rowWidth: root.vertical ? Math.max(16, root.barSize - Style.space(8)) : Style.space(root.setting("showValues", false) ? 132 : 72)
      readonly property real rowHeight: !root.stacked ? root.barSize : root.vertical ? Style.space(12)
        : Math.max(1, (root.barSize - Style.space(2)) / root.selectedMetrics.length)
      Repeater {
        model: root.selectedMetrics
        delegate: Item {
          id: metricItem
          required property var modelData
          width: metricLayout.rowWidth
          height: metricLayout.rowHeight
          Text {
            id: label
            text: metricItem.modelData.label
            color: root.bar ? root.bar.barForeground : Color.foreground
            opacity: 0.75
            font.family: Style.font.family
            font.pixelSize: Math.min(Style.font.caption, metricLayout.rowHeight)
            width: Style.space(8)
            horizontalAlignment: Text.AlignHCenter
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }
          HistoryGraph {
            id: waveform
            anchors.left: label.right
            anchors.leftMargin: Style.space(3)
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(4, metricItem.width - label.width - Style.space(3)
              - (value.visible ? Style.space(60) : 0))
            height: Math.max(3, Math.min(Style.space(13), metricLayout.rowHeight - 1))
            history: telemetry.history
            metric: metricItem.modelData.key
            ceiling: root.ceiling(metric)
            seconds: (root.configuredSamples - 1) * root.refreshIntervalMs / 1000
            endTime: telemetry.now
            cadence: root.refreshIntervalMs
            maxGap: root.refreshIntervalMs / 1000 * 2.5
            mirrored: true
            opacity: telemetry.current[metric] === null ? 0.35 : 1
          }
          Text {
            id: value
            visible: !root.vertical && root.setting("showValues", false)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Model.format(metricItem.modelData.key, telemetry.current[metricItem.modelData.key])
            color: root.bar ? root.bar.barForeground : Color.foreground
            font.family: Style.font.family
            font.pixelSize: Math.min(Style.font.caption, metricLayout.rowHeight)
          }
          Text {
            visible: telemetry.current[metricItem.modelData.key] === null
            anchors.centerIn: waveform
            text: "—"
            color: Color.muted
            font.pixelSize: Math.min(Style.font.caption, metricLayout.rowHeight)
          }
        }
      }
    }
  }
}
