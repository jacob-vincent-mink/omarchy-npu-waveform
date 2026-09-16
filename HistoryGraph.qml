import QtQuick
import qs.Commons

Canvas {
  id: graph
  property var history: []
  property string metric: "utilization"
  property real ceiling: 100
  property real seconds: 60
  property real endTime: 0
  property real maxGap: 2.5
  property bool mirrored: false
  property bool vertical: false
  property color ink: Color.accent
  property color guide: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.12)
  property real progress: 1
  property real cadence: 1000
  property real displayedCeiling: ceiling
  Behavior on displayedCeiling { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
  onHistoryChanged: {
    if (mirrored) { progress = 0; scroll.restart() }
    requestPaint()
  }
  onProgressChanged: requestPaint()
  onDisplayedCeilingChanged: requestPaint()
  onSecondsChanged: requestPaint()
  onMetricChanged: requestPaint()
  onInkChanged: requestPaint()
  onGuideChanged: requestPaint()
  onEndTimeChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVerticalChanged: requestPaint()
  NumberAnimation { id: scroll; target: graph; property: "progress"; to: 1; duration: Math.max(200, graph.cadence - 80) }
  antialiasing: true
  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var w = vertical ? height : width, h = vertical ? width : height
    if (vertical) { ctx.translate(width, 0); ctx.rotate(Math.PI / 2) }
    ctx.strokeStyle = guide
    ctx.lineWidth = 1
    var baseline = mirrored ? h / 2 : h - 1
    ctx.beginPath(); ctx.moveTo(0, baseline); ctx.lineTo(w, baseline); ctx.stroke()
    if (!mirrored) {
      ctx.beginPath(); ctx.moveTo(0, 1); ctx.lineTo(w, 1); ctx.stroke()
      ctx.setLineDash([2, 4]); ctx.beginPath(); ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2); ctx.stroke(); ctx.setLineDash([])
    }
    var end = endTime - (mirrored ? (1 - progress) * cadence / 1000 : 0)
    var start = end - seconds, top = Math.max(1, displayedCeiling)
    ctx.strokeStyle = ink; ctx.lineWidth = mirrored ? 1 : 1.6
    var prev = null
    for (var i = 0; i < history.length; i++) {
      var s = history[i], v = s[metric]
      if (v === null || v === undefined || !isFinite(v)) { prev = null; continue }
      var x = (s.time - start) / seconds * w
      var y = Math.min(1, Math.max(0, v / top))
      if (prev && s.time - prev.time <= maxGap) {
        if (mirrored) {
          for (var p = Math.max(0, Math.ceil(prev.x)); p <= Math.min(w, x); p++) {
            var mix = (p - prev.x) / Math.max(1, x - prev.x)
            mix = mix * mix * (3 - 2 * mix)
            var magnitude = (prev.y + (y - prev.y) * mix) * (h / 2 - 1)
            var noise = Math.sin((p + 1) * 12.9898) * 43758.5453
            magnitude *= 0.72 + (noise - Math.floor(noise)) * 0.28
            if (magnitude > 0) { ctx.beginPath(); ctx.moveTo(p, baseline - Math.max(.55, magnitude)); ctx.lineTo(p, baseline + Math.max(.55, magnitude)); ctx.stroke() }
          }
        } else {
          ctx.beginPath(); ctx.moveTo(prev.x, h - 1 - prev.y * (h - 2)); ctx.lineTo(x, h - 1 - y * (h - 2)); ctx.stroke()
        }
      }
      prev = { x: x, y: y, time: s.time }
    }
  }
}
