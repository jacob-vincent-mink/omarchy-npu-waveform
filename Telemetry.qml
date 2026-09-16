import QtQuick
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  property int interval: 1000
  property bool sampling: true
  property var history: []
  property var current: ({ utilization: null, frequency: null, memory: null, npuPower: null, state: "waiting", npuPowerState: "unavailable" })
  property var previous: null
  property bool stale: false
  readonly property real now: history.length ? history[history.length - 1].time : 0

  function accept(raw) {
    var parsed = Model.parse(raw)
    if (!parsed) { fail(); return }
    var sample = Model.derive(parsed, previous, interval / 1000 * 2.5)
    previous = parsed
    current = sample
    stale = false
    var next = history.filter(function(s) { return s.time >= sample.time - 900 })
    next.push(sample)
    history = next
  }
  function fail() {
    stale = true
    previous = null
    current = Object.assign({}, current, { utilization: null, frequency: null, memory: null, npuPower: null, state: "unavailable" })
  }
  function recent(seconds) {
    return history.filter(function(s) { return s.time >= root.now - seconds })
  }
  Process {
    id: reader
    command: ["sh", decodeURIComponent(Qt.resolvedUrl("sample.sh").toString().replace(/^file:\/\//, ""))]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.accept(text) }
    onExited: function(code) { if (code !== 0) root.fail() }
  }
  Timer {
    interval: root.interval
    running: root.sampling
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!reader.running) reader.running = true
  }
}
