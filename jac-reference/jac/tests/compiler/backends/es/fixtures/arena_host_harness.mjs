import assert from 'node:assert/strict';
import {run_game} from './host.mjs';
import {state} from './wasm_host.mjs';

class Target {
  listeners = new Map();
  addEventListener(type, fn) {
    if (!this.listeners.has(type)) this.listeners.set(type, new Set());
    this.listeners.get(type).add(fn);
  }
  removeEventListener(type, fn) { this.listeners.get(type)?.delete(fn); }
  emit(type, event) { for (const fn of this.listeners.get(type) ?? []) fn(event); }
  count() { return [...this.listeners.values()].reduce((n, set) => n + set.size, 0); }
}
const frames = new Map();
let nextFrame = 0, buffers = 0, programs = 0, shaders = 0;
globalThis.window = new Target();
globalThis.document = new Target();
document.exitPointerLock = () => { document.pointerLockElement = null; };
globalThis.requestAnimationFrame = fn => { frames.set(++nextFrame, fn); return nextFrame; };
globalThis.cancelAnimationFrame = id => frames.delete(id);
const gl = new Proxy({
  createShader: () => { shaders++; return {}; },
  deleteShader: () => shaders--,
  getShaderParameter: () => !state.failShader,
  createProgram: () => { programs++; return {}; },
  deleteProgram: () => programs--,
  getProgramParameter: () => true,
  createBuffer: () => { buffers++; return {}; },
  deleteBuffer: () => buffers--,
}, {get: (obj, key) => obj[key] ?? (() => {})});
const canvas = new Target();
canvas.getContext = () => gl;
canvas.focus = () => { document.activeElement = canvas; };
canvas.requestPointerLock = () => { document.pointerLockElement = canvas; };
const settle = () => new Promise(resolve => setTimeout(resolve, 0));
const boot = async () => { state.pending.shift()(); await settle(); };
const frame = async () => {
  const [id, callback] = frames.entries().next().value;
  frames.delete(id);
  callback(1000 + id * 16);
  await settle();
};
const key = () => ({code: 'Space', preventDefault() {}});
const hud = [];
const stop = run_game(canvas, (...values) => hud.push(values));
await boot();
await frame();
assert.deepEqual(hud[0], [12, 95, 3, 63]); // The typed Wasm boundary exposes JavaScript scalar values.
window.emit('keydown', key());
assert.equal(state.env.IsKeyPressed(32), true);
await frame();
window.emit('keydown', key());
assert.equal(state.env.IsKeyPressed(32), false); // Repeated keydown is not a new jump.
assert.equal(state.env.IsMouseButtonPressed(0), false);
canvas.emit('mousedown', {button: 2});
assert.equal(state.env.IsMouseButtonPressed(0), false);
canvas.emit('mousedown', {button: 0});
assert.equal(state.env.IsMouseButtonPressed(0), true);
window.emit('blur', {});
assert.equal(state.env.IsKeyDown(32), false);
assert.equal(state.env.IsMouseButtonPressed(0), false);
const replacement = run_game(canvas);
stop();
await boot();
assert.equal(frames.size, 1);
replacement();
replacement();
assert.deepEqual(state.dropped, [1, 2]);
assert.equal(frames.size, 0);
// Stop while init is pending, then replace it before the old init resolves.
const pendingStop = run_game(canvas);
pendingStop();
const finalStop = run_game(canvas);
await boot();
assert.equal(frames.size, 0);
await boot();
assert.equal(frames.size, 1);
finalStop();
assert.deepEqual(state.dropped, [1, 2, 3, 4]);
// A failing frame must release the same resources as an explicit stop.
run_game(canvas);
await boot();
state.failFrame = true;
const errors = [];
const logError = console.error;
try {
  console.error = (...args) => errors.push(args);
  await frame();
} finally {
  console.error = logError;
}
assert.equal(errors.length, 1);
assert.deepEqual(state.dropped, [1, 2, 3, 4, 5]);
state.failShader = true;
assert.throws(() => run_game(canvas));
assert.equal(window.count() + document.count() + canvas.count(), 0);
assert.equal(frames.size + buffers + programs + shaders, 0);
console.log('arena host checks passed');
