'use strict';

var checks = 0;
var failures = 0;

function check(name, condition) {
    checks++;
    if (!condition) {
        failures++;
        console.error('FAIL [externref_js_values] ' + name);
    }
}

try {

    var addModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 7, 1, 96, 2, 127, 127, 1, 127,
        3, 2, 1, 0,
        7, 7, 1, 3, 97, 100, 100, 0, 0,
        10, 9, 1, 7, 0, 32, 0, 32, 1, 106, 11
    ]);
    var add = new WebAssembly.Instance(new WebAssembly.Module(addModuleBytes));
    check('i32 add executes through exported WebAssembly function',
          add.exports.add(19, 23) === 42);

    var addI64ModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 7, 1, 96, 2, 126, 126, 1, 126,
        3, 2, 1, 0,
        7, 9, 1, 5, 97, 100, 100, 54, 52, 0, 0,
        10, 9, 1, 7, 0, 32, 0, 32, 1, 124, 11
    ]);
    var addI64 = new WebAssembly.Instance(new WebAssembly.Module(addI64ModuleBytes));
    check('i64 add retains values beyond Number precision',
          addI64.exports.add64(9007199254740993n, 3n) === 9007199254740996n);

    var global = new WebAssembly.Global({ value: 'externref', mutable: true });
    check('externref global defaults to undefined', global.value === undefined);
    var globalToken = {};
    global.value = globalToken;
    check('externref global preserves object identity', global.value === globalToken);
    global.value = undefined;
    check('externref global preserves undefined', global.value === undefined);
    global.value = null;
    check('externref global preserves null', global.value === null);

    // Constructor nulls use the same slot-0 encoding as the setter, so a
    // global built with null reads as a null ref inside Wasm; and a funcref
    // global rejects a non-function initial value instead of coercing to null.
    var nullGlobal = new WebAssembly.Global({ value: 'externref', mutable: true }, null);
    check('externref global constructed with null reads null', nullGlobal.value === null);
    var nullGlobalModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 5, 1, 96, 0, 1, 127,
        2, 8, 1, 1, 116, 1, 103, 3, 111, 1,
        3, 2, 1, 0,
        7, 7, 1, 3, 105, 115, 110, 0, 0,
        10, 7, 1, 5, 0, 35, 0, 209, 11
    ]);
    var nullGlobalModule = new WebAssembly.Module(nullGlobalModuleBytes);
    var nullGlobalInstance = new WebAssembly.Instance(nullGlobalModule, { t: { g: nullGlobal } });
    check('constructed-null externref global is null to Wasm',
          nullGlobalInstance.exports.isn() === 1);
    var nullFuncGlobalModuleBytes = new Uint8Array(nullGlobalModuleBytes);
    nullFuncGlobalModuleBytes[23] = 112;
    var nullFuncGlobal = new WebAssembly.Global({ value: 'funcref', mutable: true }, null);
    var nullFuncInstance = new WebAssembly.Instance(
        new WebAssembly.Module(nullFuncGlobalModuleBytes), { t: { g: nullFuncGlobal } });
    check('constructed-null funcref global is null to Wasm',
          nullFuncInstance.exports.isn() === 1);
    var threwTypeError = false;
    try {
        new WebAssembly.Global({ value: 'funcref', mutable: true }, {});
    } catch (e) {
        threwTypeError = e instanceof TypeError;
    }
    check('funcref global constructor rejects a non-function with TypeError', threwTypeError);

    var table = new WebAssembly.Table({ element: 'externref', initial: 1 });
    check('externref table defaults to undefined', table.get(0) === undefined);
    table.set(0, undefined);
    check('externref table preserves undefined', table.get(0) === undefined);
    var tableToken = {};
    table.set(0, tableToken);
    check('externref table preserves object identity', table.get(0) === tableToken);
    table.set(0, null);
    check('externref table preserves null', table.get(0) === null);
    check('table grow returns old size', table.grow(1) === 1);
    check('grown externref slot defaults to undefined', table.get(1) === undefined);
    table.grow(1, null);
    check('table grow preserves explicit null', table.get(2) === null);

    // A module exporting an externref table plus get/set functions. This
    // exercises reference values crossing both JS→Wasm and Wasm→JS.
    var tableModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 9, 2, 96, 0, 1, 111, 96, 1, 111, 0,
        3, 3, 2, 0, 1,
        4, 4, 1, 111, 0, 1,
        7, 37, 3,
        13, 103, 101, 116, 45, 101, 120, 116, 101, 114, 110, 114, 101, 102, 0, 0,
        13, 115, 101, 116, 45, 101, 120, 116, 101, 114, 110, 114, 101, 102, 0, 1,
        1, 116, 1, 0,
        10, 17, 2, 6, 0, 65, 0, 37, 0, 11,
        8, 0, 65, 0, 32, 0, 38, 0, 11
    ]);
    var tableInstance = new WebAssembly.Instance(new WebAssembly.Module(tableModuleBytes));
    var wasmToken = {};
    tableInstance.exports['set-externref'](wasmToken);
    check('Wasm table set/get preserves object identity',
          tableInstance.exports['get-externref']() === wasmToken);
    tableInstance.exports['set-externref'](undefined);
    check('Wasm table set/get preserves undefined',
          tableInstance.exports['get-externref']() === undefined);
    tableInstance.exports['set-externref'](null);
    check('Wasm table set/get preserves null',
          tableInstance.exports['get-externref']() === null);

    var getExternref = tableInstance.exports['get-externref'];
    var funcrefTable = new WebAssembly.Table({ element: 'funcref', initial: 1 });
    funcrefTable.set(0, getExternref);
    check('funcref table returns cached callable wrapper',
          funcrefTable.get(0) === getExternref);
    var funcrefGlobal = new WebAssembly.Global({ value: 'funcref', mutable: true }, getExternref);
    check('funcref global returns cached callable wrapper', funcrefGlobal.value === getExternref);

    // A second module imports and calls a JS function. Instantiating another
    // module must not invalidate callbacks already registered by an instance.
    var importModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 6, 1, 96, 1, 111, 1, 111,
        2, 12, 1, 3, 101, 110, 118, 4, 101, 99, 104, 111, 0, 0,
        3, 2, 1, 0,
        7, 8, 1, 4, 99, 97, 108, 108, 0, 1,
        10, 8, 1, 6, 0, 32, 0, 16, 0, 11
    ]);
    var importModule = new WebAssembly.Module(importModuleBytes);
    var echo = function(value) { return value; };
    var imports = { env: { echo: echo } };
    var first = new WebAssembly.Instance(importModule, imports);
    var firstToken = {};
    check('JS import callback round-trips externref', first.exports.call(firstToken) === firstToken);
    var second = new WebAssembly.Instance(importModule, imports);
    var secondToken = {};
    check('second instance callback round-trips externref', second.exports.call(secondToken) === secondToken);
    var retainedToken = {};
    check('first instance callback remains registered', first.exports.call(retainedToken) === retainedToken);

    // Externref results must come back untouched even when they look like
    // the bridge's internal funcref markers or hold frozen arrays.
    var markerShaped = Object.create(null);
    markerShaped.__jacFuncRefH = 7;
    check('marker-shaped externref result is not unwrapped',
          first.exports.call(markerShaped) === markerShaped);
    var frozenArr = Object.freeze(['a', 'b']);
    check('externref array result is neither mutated nor rebuilt',
          first.exports.call(frozenArr) === frozenArr);

    // A funcref argument reaches the JS import as the cached callable, so
    // the callback can call it and compare it with exported wrappers.
    var fnArgModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 10, 2, 96, 1, 112, 1, 127, 96, 0, 1, 127,
        2, 10, 1, 3, 101, 110, 118, 2, 99, 98, 0, 0,
        3, 3, 2, 1, 1,
        7, 5, 1, 1, 102, 0, 2,
        9, 5, 1, 3, 0, 1, 1,
        10, 13, 2, 4, 0, 65, 42, 11, 6, 0, 210, 1, 16, 0, 11
    ]);
    var fnArgModule = new WebAssembly.Module(fnArgModuleBytes);
    var gotFn = null;
    var fnArgInstance = new WebAssembly.Instance(fnArgModule, { env: { cb: function (fn) {
        gotFn = fn;
        return typeof fn === 'function' ? fn() : -1;
    } } });
    check('funcref argument is callable through the import',
          fnArgInstance.exports.f() === 42);
    check('funcref argument stays callable after the call',
          typeof gotFn === 'function' && gotFn() === 42);

    // Memory: fractional sizes coerce, growth detaches the old buffer, and
    // contents survive into the new one (js-engine memory-buffer semantics).
    var memory = new WebAssembly.Memory({ initial: 1.9, maximum: 3.9 });
    var oldBuffer = memory.buffer;
    var oldView = new Uint8Array(oldBuffer);
    oldView[0] = 37;
    check('initial memory page count coerces down', oldBuffer.byteLength === 65536);
    check('grow coerces a fractional page delta', memory.grow(1.9) === 1);
    check('growth detaches the old buffer', oldBuffer.byteLength === 0);
    check('growth detaches old views', oldView.byteLength === 0);
    check('grown buffer has the new length', memory.buffer.byteLength === 131072);
    check('memory contents survive growth', new Uint8Array(memory.buffer)[0] === 37);

    // Wasm-side growth reaches the JS MemoryObject layer: every successful
    // grow — the memory.grow opcode or Memory.prototype.grow — detaches the
    // old ArrayBuffer and its views BEFORE the engine frees the old backing
    // store, so views never read freed memory across repeated grows.
    var growModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 6, 1, 96, 1, 127, 1, 127,
        3, 2, 1, 0,
        5, 4, 1, 1, 1, 10,
        7, 14, 2, 4, 103, 114, 111, 119, 0, 0, 3, 109, 101, 109, 2, 0,
        10, 8, 1, 6, 0, 32, 0, 64, 0, 11
    ]);
    var growInstance = new WebAssembly.Instance(new WebAssembly.Module(growModuleBytes));
    var growMem = growInstance.exports.mem;
    var buf0 = growMem.buffer;
    var view0 = new Uint8Array(buf0);
    view0[0] = 99;
    check('wasm grow returns the previous page count',
          growInstance.exports.grow(1) === 1);
    check('one wasm-side grow detaches the old buffer', buf0.byteLength === 0);
    check('one wasm-side grow detaches old views', view0.byteLength === 0);
    check('detached views read undefined', view0[0] === undefined);
    check('grown buffer has the new length', growMem.buffer.byteLength === 131072);
    check('contents survive a wasm-side grow', new Uint8Array(growMem.buffer)[0] === 99);

    var buf1 = growMem.buffer;
    var view1 = new Uint8Array(buf1);
    view1[1] = 55;
    // Two wasm-side grows with no `memory.buffer` read in between: the views
    // taken before the first grow must already be detached, not left
    // wrapping backing stores that a later grow frees.
    check('second wasm grow returns the previous page count',
          growInstance.exports.grow(1) === 2);
    check('third wasm grow still succeeds', growInstance.exports.grow(1) === 3);
    check('repeated wasm-side grows detach the intermediate buffer',
          buf1.byteLength === 0);
    check('repeated wasm-side grows detach intermediate views',
          view1.byteLength === 0);
    check('buffer after repeated grows is fresh', growMem.buffer.byteLength === 262144);
    check('contents survive repeated grows', new Uint8Array(growMem.buffer)[1] === 55);

    // The same memory through two MemoryObjects (a JS-created Memory both
    // imported into a module and re-exported from it): a grow through either
    // detaches both wrappers.
    var sharedModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 6, 1, 96, 1, 127, 1, 127,
        2, 9, 1, 1, 101, 1, 109, 2, 1, 1, 4,
        3, 2, 1, 0,
        7, 9, 2, 1, 103, 0, 0, 1, 109, 2, 0,
        10, 8, 1, 6, 0, 32, 0, 64, 0, 11
    ]);
    var sharedMem = new WebAssembly.Memory({ initial: 1, maximum: 4 });
    var sharedInstance = new WebAssembly.Instance(
        new WebAssembly.Module(sharedModuleBytes), { e: { m: sharedMem } });
    var sharedBuf = sharedMem.buffer;
    new Uint8Array(sharedBuf)[0] = 21;
    check('imported memory grows from wasm', sharedInstance.exports.g(1) === 1);
    check('the JS MemoryObject of an imported memory detaches',
          sharedBuf.byteLength === 0);
    check('the imported memory re-wraps after growth',
          sharedMem.buffer.byteLength === 131072);
    var reexported = sharedInstance.exports.m;
    var reexportedBuf = reexported.buffer;
    check('re-exported memory shares contents', new Uint8Array(reexportedBuf)[0] === 21);
    check('grow through one object detaches the other wrapper',
          (sharedMem.grow(1) === 2 && reexportedBuf.byteLength === 0));
    check('the re-exported wrapper re-wraps after growth',
          reexported.buffer.byteLength === 196608);

    // A wasm call that grows and then reaches an imported JS callback: the
    // callback must observe the pre-grow views detached and memory.buffer at
    // the new size, during the same wasm call.
    var cbModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 4, 1, 96, 0, 0,
        2, 10, 1, 3, 101, 110, 118, 2, 99, 98, 0, 0,
        3, 2, 1, 0,
        5, 4, 1, 1, 1, 10,
        7, 13, 2, 3, 114, 117, 110, 0, 1, 3, 109, 101, 109, 2, 0,
        10, 18, 1, 16, 0, 65, 1, 64, 0, 26, 16, 0, 65, 1, 64, 0, 26, 16, 0, 11
    ]);
    var cbObservations = [];
    var cbMem = null;
    var preCbView = null;
    var cbInstance = new WebAssembly.Instance(new WebAssembly.Module(cbModuleBytes), {
        env: { cb: function () {
            cbObservations.push({
                preDetached: preCbView.byteLength === 0,
                preRead: preCbView[2],
                liveLen: cbMem.buffer.byteLength,
                liveRead: new Uint8Array(cbMem.buffer)[2]
            });
        } }
    });
    cbMem = cbInstance.exports.mem;
    preCbView = new Uint8Array(cbMem.buffer);
    preCbView[2] = 77;
    cbInstance.exports.run();
    check('callback fires after each growth', cbObservations.length === 2);
    check('first callback sees the pre-grow view detached',
          cbObservations[0].preDetached === true);
    check('first callback reads the grown buffer',
          cbObservations[0].liveLen === 131072 && cbObservations[0].liveRead === 77);
    check('second callback sees the view detached after the second growth',
          cbObservations[1].preDetached === true);
    check('second callback reads the second growth',
          cbObservations[1].liveLen === 196608 && cbObservations[1].liveRead === 77);
    check('detached pre-grow views read undefined in callbacks',
          cbObservations[1].preRead === undefined);

    // The detach hook can synchronously re-enter Wasm. Reserve the active
    // interpreter frame so the nested export cannot overwrite its locals.
    var reentryModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 10, 2, 96, 0, 1, 127, 96, 1, 127, 1, 127,
        3, 3, 2, 1, 0,
        5, 4, 1, 1, 1, 3,
        7, 24, 3, 5, 111, 117, 116, 101, 114, 0, 0,
        6, 110, 101, 115, 116, 101, 100, 0, 1, 3, 109, 101, 109, 2, 0,
        10, 29, 2,
        16, 1, 1, 127, 65, 205, 0, 33, 1, 32, 0, 64, 0, 26, 32, 1, 11,
        10, 1, 2, 127, 65, 42, 33, 1, 32, 1, 11
    ]);
    var reentryInstance = new WebAssembly.Instance(
        new WebAssembly.Module(reentryModuleBytes));
    var reentryBuffer = reentryInstance.exports.mem.buffer;
    var originalDetach = globalThis.__napiBinary.detach;
    var didReenter = false;
    var nestedResult = -1;
    globalThis.__napiBinary.detach = function (buffer) {
        if (!didReenter) {
            didReenter = true;
            nestedResult = reentryInstance.exports.nested();
        }
        return originalDetach(buffer);
    };
    var outerResult;
    try {
        outerResult = reentryInstance.exports.outer(1);
    } finally {
        globalThis.__napiBinary.detach = originalDetach;
    }
    check('growth detach callback can re-enter a Wasm export', nestedResult === 42);
    check('re-entrant export preserves the active Wasm frame', outerResult === 77);
    check('re-entrant growth detaches the old memory buffer',
          reentryBuffer.byteLength === 0);

    // Failed growth leaves the current buffer and its views attached.
    var failModuleBytes = new Uint8Array([
        0, 97, 115, 109, 1, 0, 0, 0,
        1, 6, 1, 96, 1, 127, 1, 127,
        3, 2, 1, 0,
        5, 4, 1, 1, 1, 2,
        7, 14, 2, 4, 103, 114, 111, 119, 0, 0, 3, 109, 101, 109, 2, 0,
        10, 8, 1, 6, 0, 32, 0, 64, 0, 11
    ]);
    var failInstance = new WebAssembly.Instance(new WebAssembly.Module(failModuleBytes));
    var failMem = failInstance.exports.mem;
    var failBuf = failMem.buffer;
    var failView = new Uint8Array(failBuf);
    failView[0] = 11;

    // If native detach reports failure, keep the old allocation alive and
    // retry detaching that wrapper on the next successful growth.
    var detachFailBytes = new Uint8Array(failModuleBytes);
    detachFailBytes[25] = 3;
    var detachFailInstance = new WebAssembly.Instance(
        new WebAssembly.Module(detachFailBytes));
    var detachFailMem = detachFailInstance.exports.mem;
    var detachFailBuf = detachFailMem.buffer;
    var detachFailView = new Uint8Array(detachFailBuf);
    detachFailView[0] = 99;
    globalThis.__napiBinary.detach = function () { return 0; };
    var detachFailPages;
    try {
        detachFailPages = detachFailInstance.exports.grow(1);
    } finally {
        globalThis.__napiBinary.detach = originalDetach;
    }
    check('failed detachment leaves the old view attached and readable',
          detachFailPages === 1 && detachFailView.byteLength === 65536 &&
          detachFailView[0] === 99);
    check('next successful growth retries and detaches the old view',
          detachFailInstance.exports.grow(1) === 2 && detachFailView.byteLength === 0);

    check('wasm grow beyond the maximum returns -1',
          failInstance.exports.grow(1000) === -1);
    check('failed wasm grow leaves the buffer attached', failBuf.byteLength === 65536);
    check('failed wasm grow keeps views readable', failView[0] === 11);
    check('failed wasm grow keeps buffer identity', failMem.buffer === failBuf);
    check('grow still works after a failed grow', failInstance.exports.grow(1) === 1);
    check('the grow after the failure detaches', failBuf.byteLength === 0);
    var threwRange = false;
    try { failMem.grow(5); } catch (e) { threwRange = e instanceof RangeError; }
    check('js grow beyond the maximum throws RangeError', threwRange);
    var failBuf2 = failMem.buffer;
    check('failed js grow leaves the buffer attached', failBuf2.byteLength === 131072);
    check('failed js grow keeps buffer identity', failMem.buffer === failBuf2);
    check('wasm grow by zero pages keeps the buffer object',
          (failInstance.exports.grow(0) === 2 && failMem.buffer === failBuf2));
} catch (e) {
    failures++;
    console.error('FAIL [externref_js_values] unexpected ' + (e && e.stack ? e.stack : e));
}

console.log('externref_js_values: ' + checks + ' checks, ' + failures + ' failures');
console.log('REGRESSION_TESTCASE_FINISHED failures=' + failures);
if (typeof process !== 'undefined' && process.exit) process.exit(failures ? 1 : 0);
