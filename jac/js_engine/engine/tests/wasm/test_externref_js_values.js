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
        8, 0, 32, 0, 65, 0, 38, 0, 11
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
} catch (e) {
    failures++;
    console.error('FAIL [externref_js_values] unexpected ' + (e && e.stack ? e.stack : e));
}

console.log('externref_js_values: ' + checks + ' checks, ' + failures + ' failures');
console.log('REGRESSION_TESTCASE_FINISHED failures=' + failures);
if (typeof process !== 'undefined' && process.exit) process.exit(failures ? 1 : 0);
