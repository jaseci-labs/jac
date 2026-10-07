"""
JSON End-to-End Tests

Exercises JSON.parse() and JSON.stringify() through the full pipeline:
  global bootstrap → run_script() → lex → parse → compile → VM execute

Covers the done-criteria listed in js_engine/docs/PHASE2.md §2.1:
  ✓ JSON.parse('{"a":1}').a === 1
  ✓ JSON.stringify({a:1,b:[2,3]}) === '{"a":1,"b":[2,3]}'
  ✓ JSON.stringify(null) === 'null'
  ✓ JSON.stringify({a:1}, null, 2) produces indented output
  ✓ JSON.parse throws SyntaxError on malformed input

Run with: jac run tests/test_phase2_json.na.jac
"""

import from engine.src.runtime.global { global_context_create, init_global, run_script }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_bool,
    jsv_is_double,
    jsv_is_int32,
    jsv_is_string_cell,
    jsv_to_bool,
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

    # ── 1: JSON.parse — simple object, property access ──────────────────────
    r1: JSValue = run_script(
        ctx, "(function(){ var x = JSON.parse('{\"a\":1}'); return x.a; })()"
    );
    if jsv_is_int32(r1) and jsv_to_int32(r1) == 1 {
        ok += 1;
        print("OK  1  JSON.parse('{\"a\":1}').a === 1");
    } else {
        fail += 1;
        print("FAIL 1  JSON.parse simple object  tag=", r1, "int=", jsv_to_int32(r1));
    }

    # ── 2: JSON.parse — number types ────────────────────────────────────────
    r2: JSValue = run_script(ctx, "(function(){ return JSON.parse('42'); })()");
    if jsv_is_int32(r2) and jsv_to_int32(r2) == 42 {
        ok += 1;
        print("OK  2  JSON.parse('42') === 42");
    } else {
        fail += 1;
        print("FAIL 2  JSON.parse integer  tag=", r2, "int=", jsv_to_int32(r2));
    }

    # ── 3: JSON.parse — float ────────────────────────────────────────────────
    r3: JSValue = run_script(ctx, "(function(){ return JSON.parse('3.14'); })()");
    if jsv_is_double(r3) and jsv_to_double(r3) > 3.13 and jsv_to_double(r3) < 3.15 {
        ok += 1;
        print("OK  3  JSON.parse('3.14') ≈ 3.14");
    } else {
        fail += 1;
        print("FAIL 3  JSON.parse float  tag=", r3, "float=", jsv_to_double(r3));
    }

    # ── 4: JSON.parse — null ────────────────────────────────────────────────
    r4: JSValue = run_script(
        ctx, "(function(){ return JSON.parse('null') === null; })()"
    );
    if jsv_is_bool(r4) and jsv_to_bool(r4) {
        ok += 1;
        print("OK  4  JSON.parse('null') === null");
    } else {
        fail += 1;
        print("FAIL 4  JSON.parse null  tag=", r4);
    }

    # ── 5: JSON.parse — boolean true ────────────────────────────────────────
    r5: JSValue = run_script(ctx, "(function(){ return JSON.parse('true'); })()");
    if jsv_is_bool(r5) and jsv_to_bool(r5) {
        ok += 1;
        print("OK  5  JSON.parse('true') === true");
    } else {
        fail += 1;
        print("FAIL 5  JSON.parse true  tag=", r5);
    }

    # ── 6: JSON.parse — boolean false ───────────────────────────────────────
    r6: JSValue = run_script(ctx, "(function(){ return JSON.parse('false'); })()");
    if jsv_is_bool(r6) and not jsv_to_bool(r6) {
        ok += 1;
        print("OK  6  JSON.parse('false') === false");
    } else {
        fail += 1;
        print("FAIL 6  JSON.parse false  tag=", r6);
    }

    # ── 7: JSON.parse — string ──────────────────────────────────────────────
    r7: JSValue = run_script(ctx, "(function(){ return JSON.parse('\"hello\"'); })()");
    if jsv_is_string_cell(r7) and str_from_id(jsv_to_table_id(r7)) == "hello" {
        ok += 1;
        print("OK  7  JSON.parse('\"hello\"') === 'hello'");
    } else {
        fail += 1;
        print("FAIL 7  JSON.parse string  tag=", r7);
    }

    # ── 8: JSON.parse — nested array ────────────────────────────────────────
    r8: JSValue = run_script(
        ctx, "(function(){ var a = JSON.parse('[1,2,3]'); return a[1]; })()"
    );
    if jsv_is_int32(r8) and jsv_to_int32(r8) == 2 {
        ok += 1;
        print("OK  8  JSON.parse('[1,2,3]')[1] === 2");
    } else {
        fail += 1;
        print("FAIL 8  JSON.parse array  tag=", r8, "int=", jsv_to_int32(r8));
    }

    # ── 9: JSON.parse — array length ────────────────────────────────────────
    r9: JSValue = run_script(
        ctx, "(function(){ return JSON.parse('[10,20,30]').length; })()"
    );
    if jsv_is_int32(r9) and jsv_to_int32(r9) == 3 {
        ok += 1;
        print("OK  9  JSON.parse('[10,20,30]').length === 3");
    } else {
        fail += 1;
        print("FAIL 9  JSON.parse array length  tag=", r9, "int=", jsv_to_int32(r9));
    }

    # ── 10: JSON.parse — deeply nested ──────────────────────────────────────
    r10: JSValue = run_script(
        ctx, "(function(){ return JSON.parse('{\"a\":{\"b\":{\"c\":99}}}').a.b.c; })()"
    );
    if jsv_is_int32(r10) and jsv_to_int32(r10) == 99 {
        ok += 1;
        print("OK  10 JSON.parse deep nesting → 99");
    } else {
        fail += 1;
        print("FAIL 10 JSON.parse deep nesting  tag=", r10, "int=", jsv_to_int32(r10));
    }

    # ── 11: JSON.parse — \uXXXX unicode escape ───────────────────────────────
    # Build the JSON text via fromCharCode so no backslash appears in the
    # Jac string literal (avoids the Jac native '\\X' -> backslash+X bug).
    # q = chr(34) = '"', bs = chr(92) = '\'
    # JSON text = '"' + '\' + 'u0041BC' + '"' = "\u0041BC" => ABC
    r11: JSValue = run_script(
        ctx,
        "(function(){"
            + "  var q = String.fromCharCode(34);"
            + "  var bs = String.fromCharCode(92);"
            + "  return JSON.parse(q + bs + 'u0041BC' + q);"
            + "})()"
    );
    if jsv_is_string_cell(r11) {
        s11: str = str_from_id(jsv_to_table_id(r11));
        if s11 == "ABC" {
            ok += 1;
            print("OK  11 JSON.parse \\uXXXX unicode escape -> ABC");
        } else {
            fail += 1;
            print("FAIL 11 JSON.parse unicode escape got: '" + s11 + "'");
        }
    } else {
        fail += 1;
        print("FAIL 11 JSON.parse escape not a string  tag=", r11);
    }

    # ── 12: JSON.stringify — null ────────────────────────────────────────────
    r12: JSValue = run_script(ctx, "(function(){ return JSON.stringify(null); })()");
    if jsv_is_string_cell(r12) and str_from_id(jsv_to_table_id(r12)) == "null" {
        ok += 1;
        print("OK  12 JSON.stringify(null) === 'null'");
    } else {
        fail += 1;
        print("FAIL 12 JSON.stringify null  tag=", r12);
    }

    # ── 13: JSON.stringify — integer ─────────────────────────────────────────
    r13: JSValue = run_script(ctx, "(function(){ return JSON.stringify(42); })()");
    if jsv_is_string_cell(r13) and str_from_id(jsv_to_table_id(r13)) == "42" {
        ok += 1;
        print("OK  13 JSON.stringify(42) === '42'");
    } else {
        fail += 1;
        print("FAIL 13 JSON.stringify integer  tag=", r13);
    }

    # ── 14: JSON.stringify — boolean ─────────────────────────────────────────
    r14: JSValue = run_script(ctx, "(function(){ return JSON.stringify(true); })()");
    if jsv_is_string_cell(r14) and str_from_id(jsv_to_table_id(r14)) == "true" {
        ok += 1;
        print("OK  14 JSON.stringify(true) === 'true'");
    } else {
        fail += 1;
        print("FAIL 14 JSON.stringify boolean  tag=", r14);
    }

    # ── 15: JSON.stringify — string ───────────────────────────────────────────
    r15: JSValue = run_script(ctx, "(function(){ return JSON.stringify('hello'); })()");
    if jsv_is_string_cell(r15) and str_from_id(jsv_to_table_id(r15)) == "\"hello\"" {
        ok += 1;
        print("OK  15 JSON.stringify('hello') === '\"hello\"'");
    } else {
        fail += 1;
        print(
            "FAIL 15 JSON.stringify string  tag=",
            r15,
            "val=",
            str_from_id(jsv_to_table_id(r15)) if jsv_is_string_cell(r15) else "?"
        );
    }

    # ── 16: JSON.stringify — simple array ────────────────────────────────────
    r16: JSValue = run_script(ctx, "(function(){ return JSON.stringify([1,2,3]); })()");
    if jsv_is_string_cell(r16) and str_from_id(jsv_to_table_id(r16)) == "[1,2,3]" {
        ok += 1;
        print("OK  16 JSON.stringify([1,2,3]) === '[1,2,3]'");
    } else {
        fail += 1;
        print(
            "FAIL 16 JSON.stringify array  tag=",
            r16,
            "val=",
            str_from_id(jsv_to_table_id(r16)) if jsv_is_string_cell(r16) else "?"
        );
    }

    # ── 17: JSON.stringify — simple object ────────────────────────────────────
    r17: JSValue = run_script(ctx, "(function(){ return JSON.stringify({a:1}); })()");
    if jsv_is_string_cell(r17) and str_from_id(jsv_to_table_id(r17)) == "{\"a\":1}" {
        ok += 1;
        print("OK  17 JSON.stringify({a:1}) === '{\"a\":1}'");
    } else {
        fail += 1;
        print(
            "FAIL 17 JSON.stringify simple object  tag=",
            r17,
            "val=",
            str_from_id(jsv_to_table_id(r17)) if jsv_is_string_cell(r17) else "?"
        );
    }

    # ── 18: JSON.stringify — object + array (done-criteria) ──────────────────
    r18: JSValue = run_script(
        ctx, "(function(){ return JSON.stringify({a:1,b:[2,3]}); })()"
    );
    if jsv_is_string_cell(r18)
        and str_from_id(jsv_to_table_id(r18)) == "{\"a\":1,\"b\":[2,3]}" {
        ok += 1;
        print("OK  18 JSON.stringify({a:1,b:[2,3]})");
    } else {
        fail += 1;
        print(
            "FAIL 18 JSON.stringify object+array  tag=",
            r18,
            "val=",
            str_from_id(jsv_to_table_id(r18)) if jsv_is_string_cell(r18) else "?"
        );
    }

    # ── 19: JSON.stringify — indented (space=2) ───────────────────────────────
    r19: JSValue = run_script(
        ctx, "(function(){ return JSON.stringify({a:1}, null, 2); })()"
    );
    if jsv_is_string_cell(r19) {
        s19: str = str_from_id(jsv_to_table_id(r19));
        if s19 == "{\n  \"a\": 1\n}" {
            ok += 1;
            print("OK  19 JSON.stringify({a:1}, null, 2) — indented");
        } else {
            fail += 1;
            print("FAIL 19 JSON.stringify indent  got: '" + s19 + "'");
        }
    } else {
        fail += 1;
        print("FAIL 19 JSON.stringify indent not a string  tag=", r19);
    }

    # ── 20: JSON.stringify — undefined at top level returns undefined ─────────
    r20: JSValue = run_script(
        ctx, "(function(){ return JSON.stringify(undefined) === undefined; })()"
    );
    if jsv_is_bool(r20) and jsv_to_bool(r20) {
        ok += 1;
        print("OK  20 JSON.stringify(undefined) === undefined");
    } else {
        fail += 1;
        print("FAIL 20 JSON.stringify undefined  tag=", r20);
    }

    # ── 21: JSON.parse — throws SyntaxError on malformed input ───────────────
    # JSON.parse must throw a SyntaxError; catch it and verify the error is
    # a non-null object (the SyntaxError instance).
    r21: JSValue = run_script(
        ctx,
        "(function(){ try { JSON.parse('{bad}'); return false; } catch(e) { return e !== null; } })()"
    );
    if jsv_is_bool(r21) and jsv_to_bool(r21) {
        ok += 1;
        print("OK  21 JSON.parse throws SyntaxError on bad input");
    } else {
        fail += 1;
        print("FAIL 21 JSON.parse error handling  tag=", r21);
    }

    # ── 22: JSON.parse — empty array ─────────────────────────────────────────
    r22: JSValue = run_script(ctx, "(function(){ return JSON.parse('[]').length; })()");
    if jsv_is_int32(r22) and jsv_to_int32(r22) == 0 {
        ok += 1;
        print("OK  22 JSON.parse('[]').length === 0");
    } else {
        fail += 1;
        print("FAIL 22 JSON.parse empty array  tag=", r22, "int=", jsv_to_int32(r22));
    }

    # ── 23: JSON.parse — empty object ────────────────────────────────────────
    r23: JSValue = run_script(
        ctx,
        "(function(){"
            + "  var o = JSON.parse('{}');"
            + "  return typeof o === 'object' && o !== null;"
            + "})()"
    );
    if jsv_is_bool(r23) and jsv_to_bool(r23) {
        ok += 1;
        print("OK  23 JSON.parse('{}') is an object");
    } else {
        fail += 1;
        print("FAIL 23 JSON.parse empty object  tag=", r23);
    }

    # ── 24: JSON.stringify — NaN → 'null' ─────────────────────────────────────
    r24: JSValue = run_script(ctx, "(function(){ return JSON.stringify(NaN); })()");
    if jsv_is_string_cell(r24) and str_from_id(jsv_to_table_id(r24)) == "null" {
        ok += 1;
        print("OK  24 JSON.stringify(NaN) === 'null'");
    } else {
        fail += 1;
        print(
            "FAIL 24 JSON.stringify NaN  tag=",
            r24,
            "val=",
            str_from_id(jsv_to_table_id(r24)) if jsv_is_string_cell(r24) else "?"
        );
    }

    # ── 25: JSON.stringify — Infinity → 'null' ───────────────────────────────
    r25: JSValue = run_script(
        ctx, "(function(){ return JSON.stringify(Infinity); })()"
    );
    if jsv_is_string_cell(r25) and str_from_id(jsv_to_table_id(r25)) == "null" {
        ok += 1;
        print("OK  25 JSON.stringify(Infinity) === 'null'");
    } else {
        fail += 1;
        print(
            "FAIL 25 JSON.stringify Infinity  tag=",
            r25,
            "val=",
            str_from_id(jsv_to_table_id(r25)) if jsv_is_string_cell(r25) else "?"
        );
    }

    # ── 26: JSON.parse → JSON.stringify round-trip ────────────────────────────
    r26: JSValue = run_script(
        ctx,
        "(function(){"
            + "  var original = '{\"x\":10,\"y\":[1,2]}';"
            + "  return JSON.stringify(JSON.parse(original)) === original;"
            + "})()"
    );
    if jsv_is_bool(r26) and jsv_to_bool(r26) {
        ok += 1;
        print("OK  26 JSON parse→stringify round-trip");
    } else {
        fail += 1;
        print("FAIL 26 JSON round-trip  tag=", r26);
    }

    # ── 27: JSON.stringify — string escaping (TAB -> \t) ──────────────────────
    # Build A+TAB+B via fromCharCode to avoid Jac '\\t' encoding bug.
    # JSON.stringify('A\tB') => '"A\tB"' = 6 chars
    # charCodeAt(2) = 92 ('\'), charCodeAt(3) = 116 ('t')
    r27: JSValue = run_script(
        ctx,
        "(function(){"
            + "  var s = JSON.stringify(String.fromCharCode(65, 9, 66));"
            + "  return s.length === 6 && s.charCodeAt(2) === 92 && s.charCodeAt(3) === 116;"
            + "})()"
    );
    if jsv_is_bool(r27) and jsv_to_bool(r27) {
        ok += 1;
        print("OK  27 JSON.stringify TAB escape (\\t) in output");
    } else {
        fail += 1;
        print("FAIL 27 JSON.stringify escape  tag=", r27);
    }

    # ── 28: JSON.stringify — indented array ──────────────────────────────────
    r28: JSValue = run_script(
        ctx, "(function(){ return JSON.stringify([1,2], null, 2); })()"
    );
    if jsv_is_string_cell(r28) {
        s28: str = str_from_id(jsv_to_table_id(r28));
        if s28 == "[\n  1,\n  2\n]" {
            ok += 1;
            print("OK  28 JSON.stringify([1,2], null, 2) indented");
        } else {
            fail += 1;
            print("FAIL 28 JSON.stringify indent array  got: '" + s28 + "'");
        }
    } else {
        fail += 1;
        print("FAIL 28 JSON.stringify indent array not string  tag=", r28);
    }

    # ── Summary ──────────────────────────────────────────────────────────────
    print("");
    print("Results:", ok, "passed,", fail, "failed");
    if fail == 0 {
        print("All JSON tests PASSED ✓");
    } else {
        print("FAILURES detected — JSON is not fully functional");
    }
}
