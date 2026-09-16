const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const model = vm.createContext({});
vm.runInContext(fs.readFileSync('Model.js', 'utf8').replace('.pragma library', ''), model);
const parse = s => model.parse(s);
const a = parse('10|100000|1000|2000|1048576|active|100|100|9.9|1.5|reader');
const b = parse('12|1100000|1500|2000|2097152|active|600|1600|11.9|7.5|reader');
assert.equal(model.derive(b, a, 3).utilization, 50);
assert.equal(model.derive(b, a, 3).sleepPercent, 75);
assert.equal(model.derive(b, null, 3).utilization, null);
assert.equal(model.derive({...b, busy: 1}, a, 3).utilization, null);
assert.equal(model.derive({...b, time: 20}, a, 3).utilization, null);
assert.equal(model.derive({...b, time: 9}, a, 3).utilization, null);
const missing = parse('12|1100000||2000||suspended|600|1600|||unavailable');
assert.equal(missing.frequency, null);
assert.equal(missing.memory, null);
assert.equal(model.derive(missing, a, 3).npuPower, null);
assert.equal(parse('garbage'), null);
assert.equal(model.format('npuPower', null), '—');
assert.equal(model.format('frequency', 0), '0 MHz');
const summary = model.summary([
 {time: 0, utilization: null, sleepPercent: null},
 {time: 1, utilization: 100, sleepPercent: 0},
 {time: 4, utilization: 0, sleepPercent: 100}
]);
assert.equal(summary.average, 25);
assert.equal(summary.sleep, 75);
assert.equal(model.derive(b, a, 3).npuPower, 7.5);
assert.equal(model.derive({...b, time: 16}, null, 3).npuPower, null);
assert.equal(model.derive({...b, time: 16}, null, 3).npuPowerState, 'stale');
assert.equal(model.derive({...b, npuPowerTime: 30}, null, 3).npuPower, null);
assert.equal(model.derive(b, b, 3).npuPower, 7.5);
console.log('Telemetry tests passed: deltas, resets, missing data, weighted summaries, NPU power freshness.');
