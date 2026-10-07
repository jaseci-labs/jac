// Phase 2.5 — Spread & Destructuring tests
// Covers: rest params, array/object destructuring, spread in arrays/calls, Set spread, object spread.
var _passed = 0;
var _failed = 0;

function check(id, desc, actual, expected) {
    if (actual === expected) {
        console.log("OK  " + id + "  " + desc);
        _passed = _passed + 1;
    } else {
        console.log("FAIL " + id + "  " + desc);
        console.log("     expected: " + expected);
        console.log("     actual:   " + actual);
        _failed = _failed + 1;
    }
}

// ── Rest parameters ───────────────────────────────────────────────────────────

// ── 1: rest params collect all args ──────────────────────────────────────────
function restAll(...args) { return args.length; }
check(1, "rest: f(1,2,3).length === 3", restAll(1, 2, 3), 3);

// ── 2: rest params — values accessible by index ───────────────────────────────
function restAt(...args) { return args[1]; }
check(2, "rest: args[1] === 20", restAt(10, 20, 30), 20);

// ── 3: rest params — leading fixed params ────────────────────────────────────
function headRest(a, ...rest) { return rest[0]; }
check(3, "rest: head(1,2,3), rest[0] === 2", headRest(1, 2, 3), 2);

// ── 4: rest params — rest length with leading param ──────────────────────────
function tailLen(a, ...rest) { return rest.length; }
check(4, "rest: tail length === 2", tailLen(1, 2, 3), 2);

// ── 5: rest params — empty rest ───────────────────────────────────────────────
check(5, "rest: no extra args gives length 0", restAll(), 0);

// ── 6: rest params — used with reduce-like pattern ────────────────────────────
function sumRest(...ns) {
    var t = 0;
    for (var i = 0; i < ns.length; i++) { t = t + ns[i]; }
    return t;
}
check(6, "rest: sum(10,20,30) === 60", sumRest(10, 20, 30), 60);

// ── Array destructuring ───────────────────────────────────────────────────────

// ── 7: basic array destructuring ─────────────────────────────────────────────
const [da, db, dc] = [10, 20, 30];
check(7, "arr destruct: a === 10", da, 10);
check(8, "arr destruct: b === 20", db, 20);
check(9, "arr destruct: c === 30", dc, 30);

// ── 10: array destructuring — skip (hole) ────────────────────────────────────
const [ha,, hb] = [1, 2, 3];
check(10, "arr destruct hole: a === 1", ha, 1);
check(11, "arr destruct hole: b === 3", hb, 3);

// ── 12: array destructuring — default values ─────────────────────────────────
const [dp = 10, dq = 20] = [5];
check(12, "arr destruct default: p === 5 (provided)", dp, 5);
check(13, "arr destruct default: q === 20 (fallback)", dq, 20);

// ── 14: array destructuring — rest element ───────────────────────────────────
const [rf, ...rrest] = [1, 2, 3, 4];
check(14, "arr destruct rest: first === 1", rf, 1);
check(15, "arr destruct rest: rest.length === 3", rrest.length, 3);
check(16, "arr destruct rest: rest[2] === 4", rrest[2], 4);

// ── 17: array destructuring — nested ─────────────────────────────────────────
const [[nc, nd], [ne]] = [[1, 2], [3]];
check(17, "arr destruct nested: c === 1", nc, 1);
check(18, "arr destruct nested: d === 2", nd, 2);
check(19, "arr destruct nested: e === 3", ne, 3);

// ── Object destructuring ──────────────────────────────────────────────────────

// ── 20: basic object destructuring (shorthand) ───────────────────────────────
const {ox, oy} = {ox: 1, oy: 2};
check(20, "obj destruct shorthand: x === 1", ox, 1);
check(21, "obj destruct shorthand: y === 2", oy, 2);

// ── 22: object destructuring — rename ────────────────────────────────────────
const {a: alpha, b: beta} = {a: 10, b: 20};
check(22, "obj destruct rename: alpha === 10", alpha, 10);
check(23, "obj destruct rename: beta === 20", beta, 20);

// ── 24: object destructuring — defaults ──────────────────────────────────────
const {om = 99, on = 88} = {om: 1};
check(24, "obj destruct default: m === 1 (provided)", om, 1);
check(25, "obj destruct default: n === 88 (fallback)", on, 88);

// ── 26: object destructuring — rest ──────────────────────────────────────────
const {rx, ...orest} = {rx: 1, ry: 2, rz: 3};
check(26, "obj destruct rest: x === 1", rx, 1);
check(27, "obj destruct rest: rest.y === 2", orest.ry, 2);
check(28, "obj destruct rest: rest.z === 3", orest.rz, 3);
check(29, "obj destruct rest: Object.keys.length === 2", Object.keys(orest).length, 2);

// ── 30: object destructuring — nested ────────────────────────────────────────
const {na: {nb: inner}} = {na: {nb: 42}};
check(30, "obj destruct nested: inner === 42", inner, 42);

// ── Spread in array literals ──────────────────────────────────────────────────

// ── 31: spread two arrays ────────────────────────────────────────────────────
const sa1 = [1, 2], sa2 = [3, 4];
const sc = [...sa1, ...sa2];
check(31, "spread arr: length === 4", sc.length, 4);
check(32, "spread arr: [0] === 1", sc[0], 1);
check(33, "spread arr: [2] === 3", sc[2], 3);

// ── 34: spread mixed with literals ───────────────────────────────────────────
const mid = [3, 4];
const mixed = [1, 2, ...mid, 5, 6];
check(34, "spread mixed: length === 6", mixed.length, 6);
check(35, "spread mixed: [2] === 3", mixed[2], 3);
check(36, "spread mixed: [5] === 6", mixed[5], 6);

// ── 37: string spread ────────────────────────────────────────────────────────
const chars = [..."abc"];
check(37, "str spread: length === 3", chars.length, 3);
check(38, "str spread: [0] === 'a'", chars[0], "a");
check(39, "str spread: [2] === 'c'", chars[2], "c");

// ── 40: Set spread (deduplication) ───────────────────────────────────────────
const uniq = [...new Set([1, 2, 2, 3])];
check(40, "Set spread: length === 3", uniq.length, 3);
check(41, "Set spread: [0] === 1", uniq[0], 1);
check(42, "Set spread: [2] === 3", uniq[2], 3);

// ── Spread in function calls ──────────────────────────────────────────────────

// ── 43: spread args into fixed-param function ────────────────────────────────
function add3(a, b, c) { return a + b + c; }
check(43, "spread call: add3(...[1,2,3]) === 6", add3(...[1, 2, 3]), 6);

// ── 44: spread into rest param ───────────────────────────────────────────────
function joinArgs(...args) { return args.join("-"); }
const parts = ["x", "y", "z"];
check(44, "spread into rest: join === 'x-y-z'", joinArgs(...parts), "x-y-z");

// ── 45: partial spread with leading literal ───────────────────────────────────
function mul(a, b, c) { return a * b * c; }
check(45, "spread partial: 2 * ...[3,4] === 24", mul(2, ...[3, 4]), 24);

// ── Object spread ─────────────────────────────────────────────────────────────

// ── 46: basic object spread ───────────────────────────────────────────────────
const oa = {x: 1, y: 2};
const ob = {...oa, z: 3};
check(46, "obj spread: x === 1", ob.x, 1);
check(47, "obj spread: y === 2", ob.y, 2);
check(48, "obj spread: z === 3", ob.z, 3);

// ── 49: object spread — override ─────────────────────────────────────────────
const defaults = {a: 1, b: 2, c: 3};
const overrides = {b: 20, d: 4};
const merged = {...defaults, ...overrides};
check(49, "obj spread override: a === 1", merged.a, 1);
check(50, "obj spread override: b === 20 (overridden)", merged.b, 20);
check(51, "obj spread override: c === 3", merged.c, 3);
check(52, "obj spread override: d === 4", merged.d, 4);

// ── Mixed patterns ─────────────────────────────────────────────────────────────

// ── 53: mixed array+object destructuring ─────────────────────────────────────
const [{px}, [py]] = [{px: 10}, [20]];
check(53, "mixed destruct: x === 10", px, 10);
check(54, "mixed destruct: y === 20", py, 20);

// ── 55: destructuring in function params (object) ────────────────────────────
function area({width, height}) { return width * height; }
check(55, "param obj destruct: area({w:5,h:4}) === 20", area({width: 5, height: 4}), 20);

// ── 56: destructuring in function params (array) ─────────────────────────────
function sumPair([pa, pb]) { return pa + pb; }
check(56, "param arr destruct: sumPair([3,4]) === 7", sumPair([3, 4]), 7);

// ── 57: spread creates a copy (mutation safety) ───────────────────────────────
const orig = [1, 2, 3];
const copy = [...orig];
copy[0] = 99;
check(57, "spread copy: orig[0] still === 1", orig[0], 1);

// ── 58: object spread creates a copy ─────────────────────────────────────────
const osrc = {val: 1};
const ocopy = {...osrc};
ocopy.val = 99;
check(58, "obj spread copy: src.val still === 1", osrc.val, 1);

// ── Summary ───────────────────────────────────────────────────────────────────
console.log("\n=== Spread & Destructuring tests: " + _passed + " passed, " + _failed + " failed ===");
