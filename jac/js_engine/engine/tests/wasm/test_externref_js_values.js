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
        3, 2, 1, 0,
        2, 8, 1, 1, 116, 1, 103, 3, 111, 1,
        7, 7, 1, 3, 105, 115, 110, 0, 0,
        10, 8, 1, 6, 0, 53, 0, 209, 11
    ]);
    var nullGlobalModule = new WebAssembly.Module(nullGlobalModuleBytes);
    var nullGlobalInstance = new WebAssembly.Instance(nullGlobalModule, { t: { g: nullGlobal } });
    check('constructed-null externref global is null to Wasm',
          nullGlobalInstance.exports.isn() === 1);
    var nullFuncGlobalModuleBytes = new Uint8Array(nullGlobalModuleBytes);
    nullFuncGlobalModuleBytes[27] = 112;
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
} catch (e) {
    failures++;
    console.error('FAIL [externref_js_values] unexpected ' + (e && e.stack ? e.stack : e));
}

console.log('externref_js_values: ' + checks + ' checks, ' + failures + ' failures');
console.log('REGRESSION_TESTCASE_FINISHED failures=' + failures);
if (typeof process !== 'undefined' && process.exit) process.exit(failures ? 1 : 0);
