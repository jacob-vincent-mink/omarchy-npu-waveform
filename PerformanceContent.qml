import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

FocusScope {
  id: root
  required property var hostWidget
  property int windowSeconds: 60
  readonly property var telemetry: hostWidget.telemetry
  readonly property var current: telemetry.current
  readonly property var history: telemetry.recent(windowSeconds)
  readonly property var stats: Model.summary(history)
  signal closeRequested()
  implicitHeight: body.implicitHeight
  Keys.onEscapePressed: closeRequested()

  Column {
    id: body
    width: parent.width
    spacing: Style.space(18)
    Item {
      width: parent.width
      height: Style.space(46)
      Column {
        spacing: Style.space(4)
        Text { text: "Intel NPU"; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.title; font.bold: true }
        Text {
          text: root.current.state === "suspended" ? "Suspended · ready for work"
            : root.current.state === "active" ? "Active · sampling every " + (root.telemetry.interval / 1000) + "s"
            : root.current.state === "waiting" ? "Waiting for first sample" : "NPU unavailable"
          color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
      }
      Text {
        anchors.right: parent.right
        anchors.top: parent.top
        text: Model.format("utilization", root.current.utilization)
        color: Color.accent; font.family: Style.font.family; font.pixelSize: Style.font.displayLarge
      }
    }
    Row {
      spacing: Style.space(6)
      Repeater {
        model: [60, 300, 900]
        Button {
          required property int modelData
          text: (modelData / 60) + " min"
          selected: root.windowSeconds === modelData
          focusable: true
          fontSize: Style.font.caption
          onClicked: root.windowSeconds = modelData
        }
      }
    }
    Column {
      width: parent.width
      spacing: Style.space(16)
      Repeater {
        model: Model.metrics
        Column {
          id: section
          required property var modelData
          width: parent.width
          spacing: Style.space(6)
          readonly property bool unavailable: root.current[modelData.key] === null || root.current[modelData.key] === undefined
          readonly property real ceiling: modelData.key === "utilization" ? 100
            : modelData.key === "frequency" ? Math.max(1, root.current.maxFrequency || 1)
            : Math.max(1, Model.maximum(root.history, modelData.key, 1) * 1.1)
          Item {
            width: parent.width
            height: Style.space(18)
            Text { text: section.modelData.title; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body }
            Text {
              anchors.right: parent.right
              text: Model.format(section.modelData.key, root.current[section.modelData.key])
              color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body
            }
          }
          HistoryGraph {
            width: parent.width
            height: Style.space(section.modelData.key === "utilization" ? 70 : 38)
            visible: section.modelData.key !== "npuPower" || !section.unavailable || Model.maximum(root.history, section.modelData.key, 0) > 0
            history: root.history
            metric: section.modelData.key
            ceiling: section.ceiling
            seconds: root.windowSeconds
            endTime: root.telemetry.now
            maxGap: root.telemetry.interval / 1000 * 2.5
            ink: section.modelData.key === "utilization" ? Color.accent : Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.65)
          }
          Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: section.modelData.key === "npuPower"
              ? (root.current.npuPowerState === "reader" ? "Dedicated NPU energy counter · Intel PMT"
                : root.current.npuPowerState === "stale" ? "NPU power reader stopped reporting." : "Dedicated NPU power is unavailable.")
              : "0–" + Math.ceil(section.ceiling) + " " + section.modelData.unit
            color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
          }
        }
      }
      Item {
        width: parent.width
        height: Style.space(14)
        Text {
          text: "−" + (root.windowSeconds / 60) + " min"
          color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
        Text {
          anchors.right: parent.right
          text: "now"
          color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption
        }
      }
    }
    Rectangle { width: parent.width; height: 1; color: Color.foreground; opacity: 0.12 }
    Row {
      width: parent.width
      Repeater {
        model: [
          { label: "AVG ACTIVITY", value: Model.format("utilization", root.stats.average) },
          { label: "PEAK ACTIVITY", value: Model.format("utilization", root.stats.peak) },
          { label: "TIME SUSPENDED", value: Model.format("utilization", root.stats.sleep) }
        ]
        Column {
          required property var modelData
          width: parent.width / 3
          spacing: Style.space(5)
          Text { text: modelData.label; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
          Text { text: modelData.value; color: Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.subtitle }
        }
      }
    }
    Rectangle { width: parent.width; height: 1; color: Color.foreground; opacity: 0.12 }
    Column {
      width: parent.width
      spacing: Style.space(8)
      Text { text: "IN THE BAR"; color: Color.muted; font.family: Style.font.family; font.pixelSize: Style.font.caption }
      Flow {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
          model: Model.metrics
          Button {
            required property var modelData
            text: modelData.key === "utilization" ? "NPU" : modelData.key === "frequency" ? "Frequency" : modelData.key === "memory" ? "Memory" : "NPU W"
            selected: root.hostWidget.selectedMetrics.some(function(m) { return m.key === modelData.key })
            focusable: true
            fontSize: Style.font.caption
            onClicked: root.hostWidget.selectMetric(modelData)
          }
        }
      }
    }
  }
}
