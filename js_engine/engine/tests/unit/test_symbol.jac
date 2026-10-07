"""
Symbol End-to-End Tests

Exercises Symbol creation, uniqueness, global registry, typeof, and
Symbol-keyed object properties through the full pipeline:
  global bootstrap → run_script() → lex → parse → compile → VM execute

Covers the done-criteria listed in js_engine/docs/PHASE2.md §2.2:
  ✓ Symbol("x") !== Symbol("x")                     — uniqueness
  ✓ Symbol.for("shared") === Symbol.for("shared")   — global registry
  ✓ typeof Symbol("x") === "symbol"                 — typeof branch
  ✓ Symbol.iterator is a well-known Symbol (defined)
  ✓ Symbol.toString() → "Symbol(<desc>)"            — prototype.toString
  ✓ Symbol-keyed properties on plain objects         — Symbol key encoding

Run with: jac run tests/test_phase2_symbol.na.jac
"""

import from engine.src.runtime.global { global_context_create, init_global, run_script }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_bool,
    jsv_is_string_cell,
    jsv_is_int32,
    jsv_is_undefined,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_from_id }

with entry {
    ok: int = 0;
    fail: int = 0;

    ctx = global_context_create();
    init_global(ctx);

    # ── 1: Symbol uniqueness ─────────────────────────────────────────────────
    r1: JSValue = run_script(
        ctx,
        "(function(){ var a = Symbol('x'); var b = Symbol('x'); return a !== b; })()"
    );
    if jsv_is_bool(r1) and jsv_to_bool(r1) {
        ok += 1;
        print("OK  1  Symbol('x') !== Symbol('x')  (uniqueness)");
    } else {
        fail += 1;
        print("FAIL 1  Symbol uniqueness  tag=", r1, " bool=", jsv_to_bool(r1));
    }

    # ── 2: typeof Symbol ─────────────────────────────────────────────────────
    r2: JSValue = run_script(ctx, "(function(){ return typeof Symbol('test'); })()");
    if jsv_is_string_cell(r2) and str_from_id(jsv_to_table_id(r2)) == "symbol" {
        ok += 1;
        print("OK  2  typeof Symbol('test') === 'symbol'");
    } else {
        fail += 1;
        print("FAIL 2  typeof Symbol  tag=", r2);
    }

    # ── 3: Symbol.for — global registry (same key → same symbol) ─────────────
    r3: JSValue = run_script(
        ctx,
        "(function(){ var a = Symbol.for('shared'); var b = Symbol.for('shared'); return a === b; })()"
    );
    if jsv_is_bool(r3) and jsv_to_bool(r3) {
        ok += 1;
        print("OK  3  Symbol.for('shared') === Symbol.for('shared')");
    } else {
        fail += 1;
        print("FAIL 3  Symbol.for registry  tag=", r3, " bool=", jsv_to_bool(r3));
    }

    # ── 4: Symbol.for vs Symbol — not equal ───────────────────────────────────
    r4: JSValue = run_script(
        ctx,
        "(function(){ var a = Symbol('hello'); var b = Symbol.for('hello'); return a !== b; })()"
    );
    if jsv_is_bool(r4) and jsv_to_bool(r4) {
        ok += 1;
        print("OK  4  Symbol('hello') !== Symbol.for('hello')");
    } else {
        fail += 1;
        print("FAIL 4  Symbol vs Symbol.for  tag=", r4, " bool=", jsv_to_bool(r4));
    }

    # ── 5: Symbol.keyFor — registered symbol ─────────────────────────────────
    r5: JSValue = run_script(
        ctx, "(function(){ var s = Symbol.for('mykey'); return Symbol.keyFor(s); })()"
    );
    if jsv_is_string_cell(r5) and str_from_id(jsv_to_table_id(r5)) == "mykey" {
        ok += 1;
        print("OK  5  Symbol.keyFor(Symbol.for('mykey')) === 'mykey'");
    } else {
        fail += 1;
        print("FAIL 5  Symbol.keyFor  tag=", r5);
    }

    # ── 6: Symbol.keyFor — unregistered symbol → undefined ───────────────────
    r6: JSValue = run_script(
        ctx,
        "(function(){ var s = Symbol('local'); return Symbol.keyFor(s) === undefined; })()"
    );
    if jsv_is_bool(r6) and jsv_to_bool(r6) {
        ok += 1;
        print("OK  6  Symbol.keyFor(unregistered) === undefined");
    } else {
        fail += 1;
        print("FAIL 6  Symbol.keyFor unregistered  tag=", r6);
    }

    # ── 7: Symbol.iterator is defined ────────────────────────────────────────
    r7: JSValue = run_script(ctx, "(function(){ return typeof Symbol.iterator; })()");
    if jsv_is_string_cell(r7) and str_from_id(jsv_to_table_id(r7)) == "symbol" {
        ok += 1;
        print("OK  7  typeof Symbol.iterator === 'symbol'");
    } else {
        fail += 1;
        print("FAIL 7  Symbol.iterator  tag=", r7);
    }

    # ── 8: Symbol.iterator is a stable well-known symbol ─────────────────────
    r8: JSValue = run_script(
        ctx, "(function(){ return Symbol.iterator === Symbol.iterator; })()"
    );
    if jsv_is_bool(r8) and jsv_to_bool(r8) {
        ok += 1;
        print("OK  8  Symbol.iterator === Symbol.iterator  (stable)");
    } else {
        fail += 1;
        print("FAIL 8  Symbol.iterator stability  tag=", r8);
    }

    # ── 9: Symbol-keyed property on plain object — set and get ───────────────
    r9: JSValue = run_script(
        ctx,
        "(function(){ var k = Symbol('myProp'); var o = {}; o[k] = 42; return o[k]; })()"
    );
    if jsv_is_int32(r9) and jsv_to_int32(r9) == 42 {
        ok += 1;
        print("OK  9  obj[Symbol('myProp')] = 42 roundtrip");
    } else {
        fail += 1;
        print("FAIL 9  Symbol-keyed property  tag=", r9, " int=", jsv_to_int32(r9));
    }

    # ── 10: Symbol-keyed property does NOT appear in for-in ──────────────────
    r10: JSValue = run_script(
        ctx,
        "(function(){ var k = Symbol('h'); var o = {a:1}; o[k] = 2; var n = 0; for (var p in o) { n = n + 1; } return n; })()"
    );
    if jsv_is_int32(r10) and jsv_to_int32(r10) == 1 {
        ok += 1;
        print("OK  10 Symbol key hidden from for-in");
    } else {
        fail += 1;
        print("FAIL 10 for-in sees Symbol key  tag=", r10, " int=", jsv_to_int32(r10));
    }

    # ── 11: Symbol.toString() via prototype ──────────────────────────────────
    r11: JSValue = run_script(
        ctx, "(function(){ var s = Symbol('hello'); return s.toString(); })()"
    );
    if jsv_is_string_cell(r11)
        and str_from_id(jsv_to_table_id(r11)) == "Symbol(hello)" {
        ok += 1;
        print("OK  11 Symbol('hello').toString() === 'Symbol(hello)'");
    } else {
        fail += 1;
        r11_s: str = "";
        if jsv_is_string_cell(r11) {
            r11_s = str_from_id(jsv_to_table_id(r11));
        }
        print("FAIL 11 Symbol toString  tag=", r11, " str=", r11_s);
    }

    # ── 12: Symbol well-known: toPrimitive / hasInstance / toStringTag / species
    r12: JSValue = run_script(
        ctx,
        "(function(){ return typeof Symbol.toPrimitive === 'symbol' && typeof Symbol.hasInstance === 'symbol' && typeof Symbol.toStringTag === 'symbol' && typeof Symbol.species === 'symbol'; })()"
    );
    if jsv_is_bool(r12) and jsv_to_bool(r12) {
        ok += 1;
        print("OK  12 all well-known symbols are typeof 'symbol'");
    } else {
        fail += 1;
        print("FAIL 12 well-known symbol types  tag=", r12);
    }

    # ── Summary ───────────────────────────────────────────────────────────────
    print("");
    print("Symbol: ", ok, " passed, ", fail, " failed");
}
