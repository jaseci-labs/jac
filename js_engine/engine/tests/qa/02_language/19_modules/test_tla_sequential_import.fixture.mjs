// TLA-SEQ: top-level `await import()` of distinct uncached modules.
//
// Regression for the frame-pool locals-aliasing crash: a suspended top-level
// (pool-eligible, non-async, non-generator) module frame had its `locals` list
// reused and shrunk by the synchronous run() of the NEXT import's target
// module, so STORE_LOCAL overran on resume ("list assignment index out of
// range"). Fixed by snapshotting locals at the async suspend sites.
//
// Driven by test_tla_sequential_import.sh (ESM entry needs the .mjs runner).
// Prints "TLA-SEQ OK" on success; any "FAIL:" line (or non-zero exit / crash)
// makes the shell driver record a failure.

function check(name, actual, expected) {
    if (actual !== expected) {
        console.log("FAIL: " + name + " expected " + expected + " got " + actual);
    }
}

// TLA-SEQ-001: two sequential CJS imports (the original crash).
const a = await import('./mod_tla_seq_a.fixture.cjs');
const b = await import('./mod_tla_seq_b.fixture.cjs');
check("TLA-SEQ-001 a", a.default.v, 1);
check("TLA-SEQ-001 b", b.default.v, 2);

// TLA-SEQ-002: loop form (three modules) — same root cause, loop incidental.
const loopVals = [];
for (const p of ['./mod_tla_seq_a.fixture.cjs',
                 './mod_tla_seq_b.fixture.cjs',
                 './mod_tla_seq_c.fixture.cjs']) {
    const m = await import(p);
    loopVals.push(m.default.v);
}
check("TLA-SEQ-002 loop", loopVals.join(','), "1,2,3");

// TLA-SEQ-003: three sequential, mixed CJS + ESM targets.
const m1 = await import('./mod_tla_seq_a.fixture.cjs');
const m2 = await import('./mod_tla_seq_e1.fixture.mjs');
const m3 = await import('./mod_tla_seq_c.fixture.cjs');
check("TLA-SEQ-003 mixed", [m1.default.v, m2.v, m3.default.v].join(','), "1,10,3");

// TLA-SEQ-004: two sequential ESM imports.
const e1 = await import('./mod_tla_seq_e1.fixture.mjs');
const e2 = await import('./mod_tla_seq_e2.fixture.mjs');
check("TLA-SEQ-004 esm", [e1.v, e2.v].join(','), "10,20");

// TLA-SEQ-005: for-await-of over an async generator, each step importing —
// exercises the ASYNC_ITER_NEXT suspend site (same aliasing class).
async function* specs() {
    yield './mod_tla_seq_a.fixture.cjs';
    yield './mod_tla_seq_b.fixture.cjs';
    yield './mod_tla_seq_c.fixture.cjs';
}
const forAwaitVals = [];
for await (const p of specs()) {
    const m = await import(p);
    forAwaitVals.push(m.default.v);
}
check("TLA-SEQ-005 for-await", forAwaitVals.join(','), "1,2,3");

console.log("TLA-SEQ OK");
