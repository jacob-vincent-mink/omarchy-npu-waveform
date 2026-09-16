.pragma library

var metrics = [
  { key: "utilization", setting: "showUtilization", label: "U", title: "NPU activity", unit: "%" },
  { key: "frequency", setting: "showFrequency", label: "F", title: "NPU frequency", unit: "MHz" },
  { key: "memory", setting: "showMemory", label: "M", title: "NPU memory", unit: "MiB" },
  { key: "npuPower", setting: "showNpuPower", label: "P", title: "NPU power", unit: "W" }
]
function numeric(value) {
  if (value === undefined || String(value).trim() === "") return null
  var n = Number(value)
  return isFinite(n) && n >= 0 ? n : null
}
function parse(raw) {
  var p = String(raw).trim().split("|")
  if (p.length !== 11 || numeric(p[0]) === null) return null
  return { time: numeric(p[0]), busy: numeric(p[1]), frequency: numeric(p[2]),
    maxFrequency: numeric(p[3]), memory: numeric(p[4]) === null ? null : Number(p[4]) / 1048576,
    state: p[5] || "unavailable", active: numeric(p[6]), suspended: numeric(p[7]),
    npuPowerTime: numeric(p[8]), measuredNpuPower: numeric(p[9]), npuPowerState: p[10] || "unavailable" }
}
function derive(current, previous, maxGap) {
  var out = Object.assign({}, current, { utilization: null, npuPower: null, sleepPercent: null })
  if (current.npuPowerState === "reader") {
    var age = current.npuPowerTime === null ? Infinity : current.time - current.npuPowerTime
    if (age >= -0.1 && age <= 3) out.npuPower = current.measuredNpuPower
    else out.npuPowerState = "stale"
  }
  var dt = previous ? current.time - previous.time : 0
  if (!previous || dt <= 0 || dt > maxGap) return out
  if (current.busy !== null && previous.busy !== null && current.busy >= previous.busy)
    out.utilization = Math.min(100, (current.busy - previous.busy) / (dt * 10000))
  if (current.active !== null && previous.active !== null && current.suspended !== null && previous.suspended !== null) {
    var a = current.active - previous.active, s = current.suspended - previous.suspended
    if (a >= 0 && s >= 0 && a + s > 0) out.sleepPercent = s / (a + s) * 100
  }
  return out
}
function format(key, value) {
  if (value === null || value === undefined || !isFinite(value)) return "—"
  if (key === "utilization") return value.toFixed(1) + "%"
  if (key === "frequency") return Math.round(value) + " MHz"
  if (key === "memory") return value.toFixed(value < 100 ? 1 : 0) + " MiB"
  return value.toFixed(1) + " W"
}
function maximum(history, key, floor) {
  var max = floor
  for (var i = 0; i < history.length; i++) {
    var v = history[i][key]
    if (v !== null && v !== undefined) max = Math.max(max, v)
  }
  return max
}
function summary(history) {
  var total = 0, duration = 0, peak = null, sleep = 0, sleepDuration = 0
  for (var i = 1; i < history.length; i++) {
    var s = history[i], dt = s.time - history[i - 1].time
    if (dt <= 0) continue
    if (s.utilization !== null) {
      total += s.utilization * dt; duration += dt
      peak = Math.max(peak || 0, s.utilization)
    }
    if (s.sleepPercent !== null) { sleep += s.sleepPercent * dt; sleepDuration += dt }
  }
  return { average: duration ? total / duration : null, peak: peak,
    sleep: sleepDuration ? sleep / sleepDuration : null }
}
