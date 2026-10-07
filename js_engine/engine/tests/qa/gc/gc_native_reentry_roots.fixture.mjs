// GC-REENTRY-001 fixture: values a native holds only in jac locals while it
// re-enters the VM (receiver/args popped off the operand stack, half-built
// results, JSON holders) must survive a collection fired inside the callback.
// Regressions (all deterministic with a forced collect in the callback):
//   Array.from({length}, fn)   half-built array swept → Promise.all over it hung
//   str.replace(/re/g, fn)     regexp arg swept → only the first match replaced
//   JSON.stringify + toJSON    holder swept → returned undefined
//   Object.assign + getter     target swept → "Cannot assign to read only property"
//   [].concat + spreadable     species result swept → garbage object
//   JSON.parse + reviver       holder swept → undefined
// Runs under `js_engine --gc` (the .sh wrapper forces the flag).
function fail(msg) { console.error("FAIL: " + msg); process.exit(1); }
function gcNow() { if (globalThis.__JS_ENGINE_GC) { __JS_ENGINE_GC.collect(); let j = []; for (let i = 0; i < 20000; i++) j.push({ i }); } }
function eq(a, e, m) { if (a !== e) fail(m + " | expected " + e + " | actual " + a); }

const later = (v, ms) => new Promise(res => setTimeout(() => res(v), ms));
const wd = setTimeout(() => fail("GC-REENTRY-001: Promise.all over Array.from never settled"), 4000);
const all = await Promise.all(Array.from({ length: 3 }, (_, k) => { if (k === 1) gcNow(); return later(k, 100 + k * 30); }));
clearTimeout(wd);
eq(all.join(), "0,1,2", "GC-REENTRY-001: Array.from array-like result survives GC in mapper");

eq(JSON.stringify(Array.from({ length: 3, 0: "x", 1: "y", 2: "z" }, (v, i) => { if (i === 1) gcNow(); return v + i; })), '["x0","y1","z2"]', "GC-REENTRY-002: Array.from array-like values");
eq(JSON.stringify(Array.from(new Set([1, 2, 3]), (v) => { if (v === 2) gcNow(); return v * 2; })), "[2,4,6]", "GC-REENTRY-003: Array.from iterable");
eq("a1b22c333".replace(/\d+/g, (m) => { gcNow(); return "[" + m + "]"; }), "a[1]b[22]c[333]", "GC-REENTRY-004: functional regexp replace keeps all matches");
eq("a1b22c333".replace("22", (m) => { gcNow(); return "[" + m + "]"; }), "a1b[22]c333", "GC-REENTRY-005: functional string replace");
eq(JSON.stringify({ a: { toJSON() { gcNow(); return [1, 2, 3]; } }, b: [4, { c: 5 }] }), '{"a":[1,2,3],"b":[4,{"c":5}]}', "GC-REENTRY-006: JSON.stringify with toJSON");
eq(JSON.stringify({ a: 1, b: [2, 3], c: { d: 4 } }, (k, v) => { if (k === "b") gcNow(); return v; }), '{"a":1,"b":[2,3],"c":{"d":4}}', "GC-REENTRY-007: JSON.stringify replacer");
eq(JSON.stringify(JSON.parse('{"a":1,"b":[2,3],"c":{"d":4}}', (k, v) => { if (k === "b") gcNow(); return v; })), '{"a":1,"b":[2,3],"c":{"d":4}}', "GC-REENTRY-008: JSON.parse reviver");
eq(JSON.stringify(Object.assign({}, { get a() { gcNow(); return 1; }, b: 2 })), '{"a":1,"b":2}', "GC-REENTRY-009: Object.assign with getter");
eq(JSON.stringify([1, 2].concat({ length: 2, 0: 3, get 1() { gcNow(); return 4; }, [Symbol.isConcatSpreadable]: true }, [5])), "[1,2,3,4,5]", "GC-REENTRY-010: concat with spreadable getter");
eq(JSON.stringify(Object.fromEntries([["a", 1], ["b", 2]].map((e, i) => { if (i === 1) gcNow(); return e; }))), '{"a":1,"b":2}', "GC-REENTRY-011: fromEntries");
eq(JSON.stringify([5, 3, 9, 1, 7].sort((a, b) => { gcNow(); return a - b; })), "[1,3,5,7,9]", "GC-REENTRY-012: sort comparator");
eq(JSON.stringify([1, 2, 3].map((x) => { gcNow(); return x * 2; })), "[2,4,6]", "GC-REENTRY-013: map");
console.log("ok");
