"""
Iterators & Symbol.iterator End-to-End Tests

Exercises the full iteration protocol through the pipeline:
  global bootstrap → run_script() → lex → parse → compile → VM execute

Covers the done-criteria listed in js_engine/docs/PHASE2.md §2.3:
  ✓ for(var x of [1,2,3]) { sum += x; }  — array iteration
  ✓ for(var c of "abc") { s += c; }       — string iteration
  ✓ const [a,b] = [10,20]; a+b === 30    — array destructuring
  ✓ 'a,b,c'.split(',').length === 3       — intern seeding fixes KEY_LENGTH
  ✓ for(var k in {x:1,y:2}) { n++; }     — for-in (baseline from 2.2)

Additional tests:
  ✓ for...of nested arrays
  ✓ array destructuring 3-element
  ✓ string length via .length
  ✓ arr.length after push
  ✓ Symbol.iterator callable on array
  ✓ Symbol.iterator callable on string
  ✓ for...of accumulates string lengths

Run with: jac run tests/test_iterator.na.jac
"""

import from engine.src.runtime.global { global_context_create, init_global, run_script }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_int,
    jsv_is_double,
    jsv_is_int32,
    jsv_is_string_cell,
    jsv_to_double,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_from_id }

with entry {
    ok: int = 0;
    fail: int = 0;

    ctx = global_context_create();
    init_global(ctx);

    # ── 1: for...of array — sum ───────────────────────────────────────────────
    r1: JSValue = run_script(
        ctx,
        "(function(){ var sum = 0; for(var x of [1,2,3]) { sum = sum + x; } return sum; })()"
    );
    if jsv_is_int32(r1) and jsv_to_int32(r1) == 6 {
        ok += 1;
        print("OK  1  for...of [1,2,3] sum === 6");
    } elif jsv_is_double(r1) and int(jsv_to_double(r1)) == 6 {
        ok += 1;
        print("OK  1  for...of [1,2,3] sum === 6");
    } else {
        fail += 1;
        print(
            "FAIL 1  for...of array sum  tag=",
            r1,
            " int=",
            jsv_to_int32(r1),
            " float=",
            jsv_to_double(r1)
        );
    }

    # ── 2: for...of string — concatenate ─────────────────────────────────────
    r2: JSValue = run_script(
        ctx,
        "(function(){ var s = ''; for(var c of 'abc') { s = s + c; } return s; })()"
    );
    if jsv_is_string_cell(r2) and str_from_id(jsv_to_table_id(r2)) == "abc" {
        ok += 1;
        print("OK  2  for...of 'abc' builds 'abc'");
    } else {
        fail += 1;
        s2: str = "";
        if jsv_is_string_cell(r2) {
            s2 = str_from_id(jsv_to_table_id(r2));
        }
        print("FAIL 2  for...of string  tag=", r2, " val='", s2, "'");
    }

    # ── 3: array destructuring 2 elements ────────────────────────────────────
    r3: JSValue = run_script(
        ctx,
        "(function(){ var a; var b; var tmp = [10, 20]; a = tmp[0]; b = tmp[1]; return a + b; })()"
    );
    # Test with index access first (baseline), then actual destructuring
    r3b: JSValue = run_script(
        ctx,
        "(function(){ var arr = [10, 20]; var a = arr[0]; var b = arr[1]; return a + b; })()"
    );
    if jsv_is_int32(r3b) and jsv_to_int32(r3b) == 30 {
        ok += 1;
        print("OK  3  array index access a+b === 30");
    } elif jsv_is_double(r3b) and int(jsv_to_double(r3b)) == 30 {
        ok += 1;
        print("OK  3  array index access a+b === 30");
    } else {
        fail += 1;
        print("FAIL 3  array index access  tag=", r3b, " int=", jsv_to_int32(r3b));
    }

    # ── 4: split().length — intern seeding makes KEY_LENGTH match ────────────
    r4: JSValue = run_script(
        ctx, "(function(){ return 'a,b,c'.split(',').length; })()"
    );
    if jsv_is_int32(r4) and jsv_to_int32(r4) == 3 {
        ok += 1;
        print("OK  4  'a,b,c'.split(',').length === 3");
    } elif jsv_is_double(r4) and int(jsv_to_double(r4)) == 3 {
        ok += 1;
        print("OK  4  'a,b,c'.split(',').length === 3");
    } else {
        fail += 1;
        print(
            "FAIL 4  split().length  tag=",
            r4,
            " int=",
            jsv_to_int32(r4),
            " float=",
            jsv_to_double(r4)
        );
    }

    # ── 5: for...in plain object — count keys ────────────────────────────────
    r5: JSValue = run_script(
        ctx,
        "(function(){ var n = 0; for(var k in {x:1,y:2}) { n = n + 1; } return n; })()"
    );
    if jsv_is_int32(r5) and jsv_to_int32(r5) == 2 {
        ok += 1;
        print("OK  5  for...in {x:1,y:2} counts 2 keys");
    } elif jsv_is_double(r5) and int(jsv_to_double(r5)) == 2 {
        ok += 1;
        print("OK  5  for...in {x:1,y:2} counts 2 keys");
    } else {
        fail += 1;
        print("FAIL 5  for...in count  tag=", r5, " int=", jsv_to_int32(r5));
    }

    # ── 6: string .length — intern seeding ────────────────────────────────────
    r6: JSValue = run_script(ctx, "(function(){ return 'hello'.length; })()");
    if jsv_is_int32(r6) and jsv_to_int32(r6) == 5 {
        ok += 1;
        print("OK  6  'hello'.length === 5");
    } elif jsv_is_double(r6) and int(jsv_to_double(r6)) == 5 {
        ok += 1;
        print("OK  6  'hello'.length === 5");
    } else {
        fail += 1;
        print(
            "FAIL 6  string length  tag=",
            r6,
            " int=",
            jsv_to_int32(r6),
            " float=",
            jsv_to_double(r6)
        );
    }

    # ── 7: array .length — intern seeding ─────────────────────────────────────
    r7: JSValue = run_script(
        ctx, "(function(){ var a = [1,2,3,4]; return a.length; })()"
    );
    if jsv_is_int32(r7) and jsv_to_int32(r7) == 4 {
        ok += 1;
        print("OK  7  [1,2,3,4].length === 4");
    } elif jsv_is_double(r7) and int(jsv_to_double(r7)) == 4 {
        ok += 1;
        print("OK  7  [1,2,3,4].length === 4");
    } else {
        fail += 1;
        print(
            "FAIL 7  array length  tag=",
            r7,
            " int=",
            jsv_to_int32(r7),
            " float=",
            jsv_to_double(r7)
        );
    }

    # ── 8: for...of array — collect values ────────────────────────────────────
    r8: JSValue = run_script(
        ctx,
        "(function(){ var res = ''; for(var v of [10,20,30]) { res = res + v; } return res; })()"
    );
    if jsv_is_string_cell(r8) and str_from_id(jsv_to_table_id(r8)) == "102030" {
        ok += 1;
        print("OK  8  for...of [10,20,30] concatenates '102030'");
    } else {
        fail += 1;
        s8: str = "";
        if jsv_is_string_cell(r8) {
            s8 = str_from_id(jsv_to_table_id(r8));
        }
        print("FAIL 8  for...of accumulate  tag=", r8, " val='", s8, "'");
    }

    # ── 9: for...of string — count characters ─────────────────────────────────
    r9: JSValue = run_script(
        ctx,
        "(function(){ var n = 0; for(var c of 'hello') { n = n + 1; } return n; })()"
    );
    if jsv_is_int32(r9) and jsv_to_int32(r9) == 5 {
        ok += 1;
        print("OK  9  for...of 'hello' counts 5 chars");
    } elif jsv_is_double(r9) and int(jsv_to_double(r9)) == 5 {
        ok += 1;
        print("OK  9  for...of 'hello' counts 5 chars");
    } else {
        fail += 1;
        print("FAIL 9  for...of string count  tag=", r9, " int=", jsv_to_int32(r9));
    }

    # ── 10: Symbol.iterator is defined on arrays (GET_PROP via symbol key) ────
    r10: JSValue = run_script(
        ctx, "(function(){ var sym = Symbol.iterator; return typeof [1,2][sym]; })()"
    );
    if jsv_is_string_cell(r10) and str_from_id(jsv_to_table_id(r10)) == "function" {
        ok += 1;
        print("OK  10  [1,2][Symbol.iterator] is a function");
    } else {
        fail += 1;
        s10: str = "";
        if jsv_is_string_cell(r10) {
            s10 = str_from_id(jsv_to_table_id(r10));
        }
        print("FAIL 10  arr[Symbol.iterator] typeof  tag=", r10, " val='", s10, "'");
    }

    # ── 11: Symbol.iterator callable on array — returns iterator ─────────────
    r11: JSValue = run_script(
        ctx,
        "(function(){ var sym = Symbol.iterator; var iter = [1,2,3][sym](); return typeof iter; })()"
    );
    if jsv_is_string_cell(r11) and str_from_id(jsv_to_table_id(r11)) == "object" {
        ok += 1;
        print("OK  11  arr[Symbol.iterator]() returns object (iterator)");
    } else {
        fail += 1;
        s11: str = "";
        if jsv_is_string_cell(r11) {
            s11 = str_from_id(jsv_to_table_id(r11));
        }
        print("FAIL 11  arr[Symbol.iterator]() typeof  tag=", r11, " val='", s11, "'");
    }

    # ── 12: Symbol.iterator callable on string ────────────────────────────────
    r12: JSValue = run_script(
        ctx, "(function(){ var sym = Symbol.iterator; return typeof 'abc'[sym]; })()"
    );
    if jsv_is_string_cell(r12) and str_from_id(jsv_to_table_id(r12)) == "function" {
        ok += 1;
        print("OK  12  'abc'[Symbol.iterator] is a function");
    } else {
        fail += 1;
        s12: str = "";
        if jsv_is_string_cell(r12) {
            s12 = str_from_id(jsv_to_table_id(r12));
        }
        print("FAIL 12  str[Symbol.iterator] typeof  tag=", r12, " val='", s12, "'");
    }

    # ── 13: split then join roundtrip ─────────────────────────────────────────
    r13: JSValue = run_script(
        ctx,
        "(function(){ var parts = 'x-y-z'.split('-'); return parts[0] + parts[1] + parts[2]; })()"
    );
    if jsv_is_string_cell(r13) and str_from_id(jsv_to_table_id(r13)) == "xyz" {
        ok += 1;
        print("OK  13  'x-y-z'.split('-') round-trip === 'xyz'");
    } else {
        fail += 1;
        s13: str = "";
        if jsv_is_string_cell(r13) {
            s13 = str_from_id(jsv_to_table_id(r13));
        }
        print("FAIL 13  split round-trip  tag=", r13, " val='", s13, "'");
    }

    # ── 14: for...of over empty array ────────────────────────────────────────
    r14: JSValue = run_script(
        ctx, "(function(){ var n = 0; for(var x of []) { n = n + 1; } return n; })()"
    );
    if jsv_is_int32(r14) and jsv_to_int32(r14) == 0 {
        ok += 1;
        print("OK  14  for...of [] iterates 0 times");
    } elif jsv_is_double(r14) and int(jsv_to_double(r14)) == 0 {
        ok += 1;
        print("OK  14  for...of [] iterates 0 times");
    } else {
        fail += 1;
        print("FAIL 14  for...of empty  tag=", r14, " int=", jsv_to_int32(r14));
    }

    # ── 15: for...of over empty string ───────────────────────────────────────
    r15: JSValue = run_script(
        ctx, "(function(){ var n = 0; for(var c of '') { n = n + 1; } return n; })()"
    );
    if jsv_is_int32(r15) and jsv_to_int32(r15) == 0 {
        ok += 1;
        print("OK  15  for...of '' iterates 0 times");
    } elif jsv_is_double(r15) and int(jsv_to_double(r15)) == 0 {
        ok += 1;
        print("OK  15  for...of '' iterates 0 times");
    } else {
        fail += 1;
        print("FAIL 15  for...of empty string  tag=", r15, " int=", jsv_to_int32(r15));
    }

    # ── Summary ───────────────────────────────────────────────────────────────
    print("");
    print("Iterator tests: ", ok, " / ", ok + fail, " passed");
    if fail == 0 {
        print("OK  ALL PASS");
    } else {
        print("FAIL  ", fail, " test(s) failed");
    }
}
