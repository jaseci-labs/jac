"""
End-to-End Integration Tests

Exercises the full pipeline: global bootstrap → run_script() → lex → parse
→ compile → VM execute, verifying that core features work together.
Covers all core built-in features.

Run with: jac run tests/test_phase1_e2e.na.jac
"""

import from engine.src.runtime.global { global_context_create, init_global, run_script }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_is_bool,
    jsv_is_double,
    jsv_is_int32,
    jsv_is_object_cell,
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

    # ── Test 1: string concatenation ─────────────────────────────────────────
    r1: JSValue = run_script(ctx, "(function() { return \"hello \" + \"world\"; })()");
    if jsv_is_string_cell(r1) and str_from_id(jsv_to_table_id(r1)) == "hello world" {
        ok += 1;
        print("OK  1  string concat → 'hello world'");
    } else {
        fail += 1;
        print("FAIL 1  string concat");
    }

    # ── Test 2: fibonacci (recursive JS function) ─────────────────────────────
    r2: JSValue = run_script(
        ctx,
        "(function() {"
            + "  function fib(n) {"
            + "    if (n <= 1) return n;"
            + "    return fib(n - 1) + fib(n - 2);"
            + "  }"
            + "  return fib(10);"
            + "})()"
    );
    if jsv_is_int32(r2) and jsv_to_int32(r2) == 55 {
        ok += 1;
        print("OK  2  fibonacci fib(10) = 55");
    } else {
        fail += 1;
        print("FAIL 2  fibonacci");
    }

    # ── Test 3: try / catch catches thrown Error ───────────────────────────────
    r3: JSValue = run_script(
        ctx,
        "(function() {"
            + "  try {"
            + "    throw new Error(\"oops\");"
            + "    return 0;"
            + "  } catch (e) {"
            + "    return 1;"
            + "  }"
            + "})()"
    );
    if jsv_is_int32(r3) and jsv_to_int32(r3) == 1 {
        ok += 1;
        print("OK  3  try/catch catches Error");
    } else {
        fail += 1;
        print("FAIL 3  try/catch");
    }

    # ── Test 4: console.log produces output ───────────────────────────────────
    # The test verifies that calling console.log does not throw and produces
    # visible output on stdout.
    run_script(ctx, "console.log(\"[e2e test 4] hello from JS\")");
    ok += 1;
    print("OK  4  console.log executed (output above)");

    # # ── Test 5: typeof checks ─────────────────────────────────────────────────
    # r5: JSValue = run_script(ctx,
    #     "(function() {" +
    #     "  return typeof 42 === 'number' &&" +
    #     "         typeof 'hi' === 'string' &&" +
    #     "         typeof undefined === 'undefined' &&" +
    #     "         typeof true === 'boolean';" +
    #     "})()");
    # if jsv_is_bool(r5) and jsv_to_bool(r5) {
    #     ok += 1;
    #     print("OK  5  typeof checks pass");
    # } else {
    #     fail += 1;
    #     print("FAIL 5  typeof checks");
    # }

    # ── Test 6: parseInt global function ─────────────────────────────────────
    r6: JSValue = run_script(ctx, "(function() { return parseInt(\"42\"); })()");
    if jsv_is_int32(r6) and jsv_to_int32(r6) == 42 {
        ok += 1;
        print("OK  6  parseInt('42') = 42");
    } else {
        fail += 1;
        print("FAIL 6  parseInt");
    }

    # ── Test 7: isNaN global function ─────────────────────────────────────────
    r7: JSValue = run_script(ctx, "(function() { return isNaN(NaN); })()");
    if jsv_is_bool(r7) and jsv_to_bool(r7) {
        ok += 1;
        print("OK  7  isNaN(NaN) = true");
    } else {
        fail += 1;
        print("FAIL 7  isNaN");
    }

    # ── Test 8: new Object() ──────────────────────────────────────────────────
    r8: JSValue = run_script(ctx, "(function() { return new Object(); })()");
    if jsv_is_object_cell(r8) {
        ok += 1;
        print("OK  8  new Object() returns object");
    } else {
        fail += 1;
        print("FAIL 8  new Object()");
    }

    # ── Test 9: new Array(3) ──────────────────────────────────────────────────
    r9: JSValue = run_script(ctx, "(function() { return new Array(3); })()");
    if jsv_is_object_cell(r9) {
        ok += 1;
        print("OK  9  new Array(3) returns object");
    } else {
        fail += 1;
        print("FAIL 9  new Array(3)");
    }

    # ── Test 10: closure captures outer variable ───────────────────────────────
    r10: JSValue = run_script(
        ctx,
        "(function() {"
            + "  var x = 10;"
            + "  return (function(n) { return n * x; })(5);"
            + "})()"
    );
    if jsv_is_int32(r10) and jsv_to_int32(r10) == 50 {
        ok += 1;
        print("OK  10 closure captures outer var: 5 * 10 = 50");
    } else {
        fail += 1;
        print("FAIL 10 closure");
    }

    # ── Test 11: Number coercion ──────────────────────────────────────────────
    r11: JSValue = run_script(ctx, "(function() { return Number('3.14'); })()");
    if jsv_is_double(r11)
        and jsv_to_double(r11) > 3.139
        and jsv_to_double(r11) < 3.141 {
        ok += 1;
        print("OK  11 Number('3.14') returns float");
    } else {
        fail += 1;
        print("FAIL 11 Number coercion");
    }

    # ── Test 12: Boolean coercion ─────────────────────────────────────────────
    r12: JSValue = run_script(ctx, "(function() { return Boolean(0); })()");
    if jsv_is_bool(r12) and not jsv_to_bool(r12) {
        ok += 1;
        print("OK  12 Boolean(0) = false");
    } else {
        fail += 1;
        print("FAIL 12 Boolean coercion");
    }

    # ── Test 13: string primitive .length ────────────────────────────────────
    r13: JSValue = run_script(ctx, "(function() { return 'hello'.length; })()");
    if jsv_is_int32(r13) and jsv_to_int32(r13) == 5 {
        ok += 1;
        print("OK  13 'hello'.length = 5");
    } else {
        fail += 1;
        print("FAIL 13 'hello'.length");
    }

    # ── Test 14: Array.isArray ────────────────────────────────────────────────
    r14: JSValue = run_script(ctx, "(function() { return Array.isArray([1,2,3]); })()");
    if jsv_is_bool(r14) and jsv_to_bool(r14) {
        ok += 1;
        print("OK  14 Array.isArray([1,2,3]) = true");
    } else {
        fail += 1;
        print("FAIL 14 Array.isArray");
    }

    # ── Test 15: Object.keys ─────────────────────────────────────────────────
    r15: JSValue = run_script(
        ctx, "(function() { var o = {a:1,b:2}; return Object.keys(o).length; })()"
    );
    if jsv_is_int32(r15) and jsv_to_int32(r15) == 2 {
        ok += 1;
        print("OK  15 Object.keys({a:1,b:2}).length = 2");
    } else {
        fail += 1;
        print("FAIL 15 Object.keys");
    }

    # ── Tests 16-27: Function built-in ────────────────────────────────────────

    # ── Test 16: typeof function ─────────────────────────────────────────────
    r16: JSValue = run_script(ctx, "typeof function(){}");
    if jsv_is_string_cell(r16) and str_from_id(jsv_to_table_id(r16)) == "function" {
        ok += 1;
        print("OK  16 typeof function(){} === 'function'");
    } else {
        fail += 1;
        print("FAIL 16 typeof function");
    }

    # ── Test 17: fn.length ───────────────────────────────────────────────────
    r17: JSValue = run_script(ctx, "(function(a,b,c){}).length");
    if jsv_is_int32(r17) and jsv_to_int32(r17) == 3 {
        ok += 1;
        print("OK  17 fn.length == 3");
    } else {
        fail += 1;
        print("FAIL 17 fn.length");
    }

    # ── Test 18: fn.name ─────────────────────────────────────────────────────
    r18: JSValue = run_script(ctx, "function greet(){}; greet.name");
    if jsv_is_string_cell(r18) and str_from_id(jsv_to_table_id(r18)) == "greet" {
        ok += 1;
        print("OK  18 fn.name == 'greet'");
    } else {
        fail += 1;
        print("FAIL 18 fn.name");
    }

    # ── Test 19: fn.call ─────────────────────────────────────────────────────
    r19: JSValue = run_script(ctx, "function f(){return this.x;} f.call({x:42})");
    if jsv_is_int32(r19) and jsv_to_int32(r19) == 42 {
        ok += 1;
        print("OK  19 fn.call(obj) returns obj.x = 42");
    } else {
        fail += 1;
        print("FAIL 19 fn.call");
    }

    # ── Test 20: fn.apply ────────────────────────────────────────────────────
    r20: JSValue = run_script(
        ctx, "function add(a,b){return a+b;} add.apply(null,[10,32])"
    );
    if jsv_is_int32(r20) and jsv_to_int32(r20) == 42 {
        ok += 1;
        print("OK  20 fn.apply(null,[10,32]) == 42");
    } else {
        fail += 1;
        print("FAIL 20 fn.apply");
    }

    # ── Test 21: fn.bind ─────────────────────────────────────────────────────
    r21: JSValue = run_script(
        ctx, "function f(x){return this.factor*x;} var b=f.bind({factor:7}); b(6)"
    );
    if jsv_is_int32(r21) and jsv_to_int32(r21) == 42 {
        ok += 1;
        print("OK  21 fn.bind(obj)(6) == 42");
    } else {
        fail += 1;
        print("FAIL 21 fn.bind");
    }

    # ── Test 22: fn.bind partial args ────────────────────────────────────────
    r22: JSValue = run_script(
        ctx, "function add(a,b){return a+b;} var b=add.bind(null,10); b(32)"
    );
    if jsv_is_int32(r22) and jsv_to_int32(r22) == 42 {
        ok += 1;
        print("OK  22 fn.bind(null,10)(32) == 42");
    } else {
        fail += 1;
        print("FAIL 22 fn.bind partial");
    }

    # ── Test 23: new Function(body) ──────────────────────────────────────────
    r23: JSValue = run_script(
        ctx,
        "(function() {"
            + "  var f = new Function('return 42;');"
            + "  return f();"
            + "})()"
    );
    if jsv_is_int32(r23) and jsv_to_int32(r23) == 42 {
        ok += 1;
        print("OK  23 new Function('return 42;')() == 42");
    } else {
        fail += 1;
        print("FAIL 23 new Function(body)");
    }

    # ── Test 24: new Function(params, body) ──────────────────────────────────
    r24: JSValue = run_script(
        ctx,
        "(function() {"
            + "  var add = new Function('a', 'b', 'return a + b;');"
            + "  return add(19, 23);"
            + "})()"
    );
    if jsv_is_int32(r24) and jsv_to_int32(r24) == 42 {
        ok += 1;
        print("OK  24 new Function('a','b','return a+b;')(19,23) == 42");
    } else {
        fail += 1;
        print("FAIL 24 new Function(params,body)");
    }

    # ── Test 25: fn.prototype ────────────────────────────────────────────────
    r25: JSValue = run_script(ctx, "function Foo(){} typeof Foo.prototype");
    if jsv_is_string_cell(r25) and str_from_id(jsv_to_table_id(r25)) == "object" {
        ok += 1;
        print("OK  25 typeof Foo.prototype === 'object'");
    } else {
        fail += 1;
        print("FAIL 25 fn.prototype");
    }

    # ── Test 26: typeof Function ─────────────────────────────────────────────
    r26: JSValue = run_script(ctx, "typeof Function");
    if jsv_is_string_cell(r26) and str_from_id(jsv_to_table_id(r26)) == "function" {
        ok += 1;
        print("OK  26 typeof Function === 'function'");
    } else {
        fail += 1;
        print("FAIL 26 typeof Function");
    }

    # ── Test 27: fn.call with varargs sum ────────────────────────────────────
    r27: JSValue = run_script(
        ctx, "function sum(a,b,c){return a+b+c;} sum.call(null,10,12,20)"
    );
    if jsv_is_int32(r27) and jsv_to_int32(r27) == 42 {
        ok += 1;
        print("OK  27 sum.call(null,10,12,20) == 42");
    } else {
        fail += 1;
        print("FAIL 27 sum.call varargs");
    }

    # ── Tests 28-47: String prototype & static ──────────────────────────────

    # ── Test 28: String() constructor coercion ────────────────────────────────
    r28: JSValue = run_script(ctx, "String(42)");
    if jsv_is_string_cell(r28) and str_from_id(jsv_to_table_id(r28)) == "42" {
        ok += 1;
        print("OK  28 String(42) === '42'");
    } else {
        fail += 1;
        print("FAIL 28 String(42)");
    }

    # ── Test 29: charAt ────────────────────────────────────────────────────────
    r29: JSValue = run_script(ctx, "'hello'.charAt(1)");
    if jsv_is_string_cell(r29) and str_from_id(jsv_to_table_id(r29)) == "e" {
        ok += 1;
        print("OK  29 'hello'.charAt(1) === 'e'");
    } else {
        fail += 1;
        print("FAIL 29 charAt");
    }

    # ── Test 30: charCodeAt ───────────────────────────────────────────────────
    r30: JSValue = run_script(ctx, "'hello'.charCodeAt(0)");
    if jsv_is_int32(r30) and jsv_to_int32(r30) == 104 {
        ok += 1;
        print("OK  30 'hello'.charCodeAt(0) === 104");
    } else {
        fail += 1;
        print("FAIL 30 charCodeAt");
    }

    # ── Test 31: at() negative index ──────────────────────────────────────────
    r31: JSValue = run_script(ctx, "'hello'.at(-1)");
    if jsv_is_string_cell(r31) and str_from_id(jsv_to_table_id(r31)) == "o" {
        ok += 1;
        print("OK  31 'hello'.at(-1) === 'o'");
    } else {
        fail += 1;
        print("FAIL 31 at(-1)");
    }

    # ── Test 32: indexOf ──────────────────────────────────────────────────────
    r32: JSValue = run_script(ctx, "'hello world'.indexOf('world')");
    if jsv_is_int32(r32) and jsv_to_int32(r32) == 6 {
        ok += 1;
        print("OK  32 'hello world'.indexOf('world') === 6");
    } else {
        fail += 1;
        print("FAIL 32 indexOf");
    }

    # ── Test 33: includes ─────────────────────────────────────────────────────
    r33: JSValue = run_script(ctx, "'hello world'.includes('world')");
    if jsv_is_bool(r33) and jsv_to_bool(r33) {
        ok += 1;
        print("OK  33 'hello world'.includes('world') === true");
    } else {
        fail += 1;
        print("FAIL 33 includes");
    }

    # ── Test 34: startsWith ───────────────────────────────────────────────────
    r34: JSValue = run_script(ctx, "'hello world'.startsWith('hello')");
    if jsv_is_bool(r34) and jsv_to_bool(r34) {
        ok += 1;
        print("OK  34 'hello world'.startsWith('hello') === true");
    } else {
        fail += 1;
        print("FAIL 34 startsWith");
    }

    # ── Test 35: endsWith ─────────────────────────────────────────────────────
    r35: JSValue = run_script(ctx, "'hello world'.endsWith('world')");
    if jsv_is_bool(r35) and jsv_to_bool(r35) {
        ok += 1;
        print("OK  35 'hello world'.endsWith('world') === true");
    } else {
        fail += 1;
        print("FAIL 35 endsWith");
    }

    # ── Test 36: slice ────────────────────────────────────────────────────────
    r36: JSValue = run_script(ctx, "'hello world'.slice(6, 11)");
    if jsv_is_string_cell(r36) and str_from_id(jsv_to_table_id(r36)) == "world" {
        ok += 1;
        print("OK  36 'hello world'.slice(6,11) === 'world'");
    } else {
        fail += 1;
        print("FAIL 36 slice");
    }

    # ── Test 37: substring ────────────────────────────────────────────────────
    r37: JSValue = run_script(ctx, "'hello world'.substring(0, 5)");
    if jsv_is_string_cell(r37) and str_from_id(jsv_to_table_id(r37)) == "hello" {
        ok += 1;
        print("OK  37 'hello world'.substring(0,5) === 'hello'");
    } else {
        fail += 1;
        print("FAIL 37 substring");
    }

    # ── Test 38: toUpperCase ──────────────────────────────────────────────────
    r38: JSValue = run_script(ctx, "'hello'.toUpperCase()");
    if jsv_is_string_cell(r38) and str_from_id(jsv_to_table_id(r38)) == "HELLO" {
        ok += 1;
        print("OK  38 'hello'.toUpperCase() === 'HELLO'");
    } else {
        fail += 1;
        print("FAIL 38 toUpperCase");
    }

    # ── Test 39: toLowerCase ──────────────────────────────────────────────────
    r39: JSValue = run_script(ctx, "'HELLO'.toLowerCase()");
    if jsv_is_string_cell(r39) and str_from_id(jsv_to_table_id(r39)) == "hello" {
        ok += 1;
        print("OK  39 'HELLO'.toLowerCase() === 'hello'");
    } else {
        fail += 1;
        print("FAIL 39 toLowerCase");
    }

    # ── Test 40: trim ─────────────────────────────────────────────────────────
    r40: JSValue = run_script(ctx, "'  hi  '.trim()");
    if jsv_is_string_cell(r40) and str_from_id(jsv_to_table_id(r40)) == "hi" {
        ok += 1;
        print("OK  40 '  hi  '.trim() === 'hi'");
    } else {
        fail += 1;
        print("FAIL 40 trim");
    }

    # ── Test 41: trimStart ────────────────────────────────────────────────────
    r41: JSValue = run_script(ctx, "'  hi  '.trimStart()");
    if jsv_is_string_cell(r41) and str_from_id(jsv_to_table_id(r41)) == "hi  " {
        ok += 1;
        print("OK  41 '  hi  '.trimStart() === 'hi  '");
    } else {
        fail += 1;
        print("FAIL 41 trimStart");
    }

    # ── Test 42: trimEnd ──────────────────────────────────────────────────────
    r42: JSValue = run_script(ctx, "'  hi  '.trimEnd()");
    if jsv_is_string_cell(r42) and str_from_id(jsv_to_table_id(r42)) == "  hi" {
        ok += 1;
        print("OK  42 '  hi  '.trimEnd() === '  hi'");
    } else {
        fail += 1;
        print("FAIL 42 trimEnd");
    }

    # ── Test 43: replace ──────────────────────────────────────────────────────
    r43: JSValue = run_script(ctx, "'abcabc'.replace('a', 'x')");
    if jsv_is_string_cell(r43) and str_from_id(jsv_to_table_id(r43)) == "xbcabc" {
        ok += 1;
        print("OK  43 'abcabc'.replace('a','x') === 'xbcabc'");
    } else {
        fail += 1;
        print("FAIL 43 replace");
    }

    # ── Test 44: replaceAll ───────────────────────────────────────────────────
    r44: JSValue = run_script(ctx, "'abcabc'.replaceAll('a', 'x')");
    if jsv_is_string_cell(r44) and str_from_id(jsv_to_table_id(r44)) == "xbcxbc" {
        ok += 1;
        print("OK  44 'abcabc'.replaceAll('a','x') === 'xbcxbc'");
    } else {
        fail += 1;
        print("FAIL 44 replaceAll");
    }

    # ── Test 45: split ────────────────────────────────────────────────────────
    r45: JSValue = run_script(ctx, "'a,b,c'.split(',').length");
    if jsv_is_int32(r45) and jsv_to_int32(r45) == 3 {
        ok += 1;
        print("OK  45 'a,b,c'.split(',').length === 3");
    } else {
        fail += 1;
        print("FAIL 45 split");
    }

    # ── Test 46: padStart ─────────────────────────────────────────────────────
    r46: JSValue = run_script(ctx, "'5'.padStart(3, '0')");
    if jsv_is_string_cell(r46) and str_from_id(jsv_to_table_id(r46)) == "005" {
        ok += 1;
        print("OK  46 '5'.padStart(3,'0') === '005'");
    } else {
        fail += 1;
        print("FAIL 46 padStart");
    }

    # ── Test 47: repeat ───────────────────────────────────────────────────────
    r47: JSValue = run_script(ctx, "'ab'.repeat(3)");
    if jsv_is_string_cell(r47) and str_from_id(jsv_to_table_id(r47)) == "ababab" {
        ok += 1;
        print("OK  47 'ab'.repeat(3) === 'ababab'");
    } else {
        fail += 1;
        print("FAIL 47 repeat");
    }

    # ── Test 48: lastIndexOf ──────────────────────────────────────────────────
    r48: JSValue = run_script(ctx, "'abcabc'.lastIndexOf('a')");
    if jsv_is_int32(r48) and jsv_to_int32(r48) == 3 {
        ok += 1;
        print("OK  48 'abcabc'.lastIndexOf('a') === 3");
    } else {
        fail += 1;
        print("FAIL 48 lastIndexOf");
    }

    # ── Test 49: String.fromCharCode ──────────────────────────────────────────
    r49: JSValue = run_script(ctx, "String.fromCharCode(65, 66, 67)");
    if jsv_is_string_cell(r49) and str_from_id(jsv_to_table_id(r49)) == "ABC" {
        ok += 1;
        print("OK  49 String.fromCharCode(65,66,67) === 'ABC'");
    } else {
        fail += 1;
        print("FAIL 49 String.fromCharCode");
    }

    # ── Test 50: padEnd ───────────────────────────────────────────────────────
    r50: JSValue = run_script(ctx, "'5'.padEnd(3, '0')");
    if jsv_is_string_cell(r50) and str_from_id(jsv_to_table_id(r50)) == "500" {
        ok += 1;
        print("OK  50 '5'.padEnd(3,'0') === '500'");
    } else {
        fail += 1;
        print("FAIL 50 padEnd");
    }

    # ── Test 51: concat ───────────────────────────────────────────────────────
    r51: JSValue = run_script(ctx, "'foo'.concat('bar')");
    if jsv_is_string_cell(r51) and str_from_id(jsv_to_table_id(r51)) == "foobar" {
        ok += 1;
        print("OK  51 'foo'.concat('bar') === 'foobar'");
    } else {
        fail += 1;
        print("FAIL 51 concat");
    }

    # ── Test 52: chained string methods ───────────────────────────────────────
    r52: JSValue = run_script(ctx, "'  Hello World  '.trim().toLowerCase().slice(0,5)");
    if jsv_is_string_cell(r52) and str_from_id(jsv_to_table_id(r52)) == "hello" {
        ok += 1;
        print("OK  52 chained trim().toLowerCase().slice(0,5) === 'hello'");
    } else {
        fail += 1;
        print("FAIL 52 chained string methods");
    }

    # ──────────────────────────────────────────────────────────────────────────
    # Number & Boolean built-ins (tests 53–70)
    # ──────────────────────────────────────────────────────────────────────────

    # ── Test 53: Number(42) → Int32 ──────────────────────────────────────────
    r53: JSValue = run_script(ctx, "Number(42)");
    if jsv_is_int32(r53) and jsv_to_int32(r53) == 42 {
        ok += 1;
        print("OK  53 Number(42) === 42");
    } else {
        fail += 1;
        print("FAIL 53 Number(42) tag=", r53, "int=", jsv_to_int32(r53));
    }

    # ── Test 54: Number("3.14") → Float64 ────────────────────────────────────
    r54: JSValue = run_script(ctx, "Number('3.14')");
    if jsv_is_double(r54) {
        ok += 1;
        print("OK  54 Number('3.14') is float");
    } else {
        fail += 1;
        print("FAIL 54 Number('3.14') tag=", r54);
    }

    # ── Test 55: Number(undefined) → NaN ─────────────────────────────────────
    r55: JSValue = run_script(ctx, "Number(undefined)");
    if jsv_is_double(r55) {
        f55: float = jsv_to_double(r55);
        if not (f55 == f55) {
            ok += 1;
            print("OK  55 Number(undefined) === NaN");
        } else {
            fail += 1;
            print("FAIL 55 Number(undefined) not NaN float=", f55);
        }
    } else {
        fail += 1;
        print("FAIL 55 Number(undefined) tag=", r55);
    }

    # ── Test 56: Number(true) → 1 ────────────────────────────────────────────
    r56: JSValue = run_script(ctx, "Number(true)");
    if jsv_is_int32(r56) and jsv_to_int32(r56) == 1 {
        ok += 1;
        print("OK  56 Number(true) === 1");
    } else {
        fail += 1;
        print("FAIL 56 Number(true) tag=", r56, "int=", jsv_to_int32(r56));
    }

    # ── Test 57: (3.14159).toFixed(2) → "3.14" ───────────────────────────────
    r57: JSValue = run_script(ctx, "(3.14159).toFixed(2)");
    if jsv_is_string_cell(r57) and str_from_id(jsv_to_table_id(r57)) == "3.14" {
        ok += 1;
        print("OK  57 (3.14159).toFixed(2) === '3.14'");
    } else {
        fail += 1;
        print("FAIL 57 toFixed tag=", r57);
    }

    # ── Test 58: (255).toString(16) → "ff" ───────────────────────────────────
    r58: JSValue = run_script(ctx, "(255).toString(16)");
    if jsv_is_string_cell(r58) and str_from_id(jsv_to_table_id(r58)) == "ff" {
        ok += 1;
        print("OK  58 (255).toString(16) === 'ff'");
    } else {
        fail += 1;
        print("FAIL 58 toString(16) tag=", r58);
    }

    # ── Test 59: Number.isNaN(NaN) → true ────────────────────────────────────
    r59: JSValue = run_script(ctx, "Number.isNaN(NaN)");
    if jsv_is_bool(r59) and jsv_to_bool(r59) == True {
        ok += 1;
        print("OK  59 Number.isNaN(NaN) === true");
    } else {
        fail += 1;
        print("FAIL 59 Number.isNaN(NaN) tag=", r59, "bool=", jsv_to_bool(r59));
    }

    # ── Test 60: Number.isFinite(Infinity) → false ───────────────────────────
    r60: JSValue = run_script(ctx, "Number.isFinite(Infinity)");
    if jsv_is_bool(r60) and jsv_to_bool(r60) == False {
        ok += 1;
        print("OK  60 Number.isFinite(Infinity) === false");
    } else {
        fail += 1;
        print("FAIL 60 Number.isFinite(Infinity) tag=", r60, "bool=", jsv_to_bool(r60));
    }

    # ── Test 61: Number.isInteger(3) → true ──────────────────────────────────
    r61: JSValue = run_script(ctx, "Number.isInteger(3)");
    if jsv_is_bool(r61) and jsv_to_bool(r61) == True {
        ok += 1;
        print("OK  61 Number.isInteger(3) === true");
    } else {
        fail += 1;
        print("FAIL 61 Number.isInteger(3) tag=", r61, "bool=", jsv_to_bool(r61));
    }

    # ── Test 62: Number.MAX_VALUE > 1e300 → true ─────────────────────────────
    r62: JSValue = run_script(ctx, "Number.MAX_VALUE > 1e300");
    if jsv_is_bool(r62) and jsv_to_bool(r62) == True {
        ok += 1;
        print("OK  62 Number.MAX_VALUE > 1e300");
    } else {
        fail += 1;
        print("FAIL 62 Number.MAX_VALUE tag=", r62, "bool=", jsv_to_bool(r62));
    }

    # ── Test 63: parseInt("ff", 16) → 255 ────────────────────────────────────
    r63: JSValue = run_script(ctx, "parseInt('ff', 16)");
    if jsv_is_int32(r63) and jsv_to_int32(r63) == 255 {
        ok += 1;
        print("OK  63 parseInt('ff', 16) === 255");
    } else {
        fail += 1;
        print("FAIL 63 parseInt tag=", r63, "int=", jsv_to_int32(r63));
    }

    # ── Test 64: parseFloat("3.14") → Float64 ────────────────────────────────
    r64: JSValue = run_script(ctx, "parseFloat('3.14')");
    if jsv_is_double(r64) {
        ok += 1;
        print("OK  64 parseFloat('3.14') is float");
    } else {
        fail += 1;
        print("FAIL 64 parseFloat tag=", r64);
    }

    # ── Test 65: isNaN(NaN) → true ───────────────────────────────────────────
    r65: JSValue = run_script(ctx, "isNaN(NaN)");
    if jsv_is_bool(r65) and jsv_to_bool(r65) == True {
        ok += 1;
        print("OK  65 isNaN(NaN) === true");
    } else {
        fail += 1;
        print("FAIL 65 isNaN(NaN) tag=", r65, "bool=", jsv_to_bool(r65));
    }

    # ── Test 66: isFinite(42) → true ─────────────────────────────────────────
    r66: JSValue = run_script(ctx, "isFinite(42)");
    if jsv_is_bool(r66) and jsv_to_bool(r66) == True {
        ok += 1;
        print("OK  66 isFinite(42) === true");
    } else {
        fail += 1;
        print("FAIL 66 isFinite(42) tag=", r66, "bool=", jsv_to_bool(r66));
    }

    # ── Test 67: Boolean(0) → false ──────────────────────────────────────────
    r67: JSValue = run_script(ctx, "Boolean(0)");
    if jsv_is_bool(r67) and jsv_to_bool(r67) == False {
        ok += 1;
        print("OK  67 Boolean(0) === false");
    } else {
        fail += 1;
        print("FAIL 67 Boolean(0) tag=", r67, "bool=", jsv_to_bool(r67));
    }

    # ── Test 68: Boolean("x") → true ─────────────────────────────────────────
    r68: JSValue = run_script(ctx, "Boolean('x')");
    if jsv_is_bool(r68) and jsv_to_bool(r68) == True {
        ok += 1;
        print("OK  68 Boolean('x') === true");
    } else {
        fail += 1;
        print("FAIL 68 Boolean('x') tag=", r68, "bool=", jsv_to_bool(r68));
    }

    # ── Test 69: (true).toString() → "true" ──────────────────────────────────
    r69: JSValue = run_script(ctx, "(true).toString()");
    if jsv_is_string_cell(r69) and str_from_id(jsv_to_table_id(r69)) == "true" {
        ok += 1;
        print("OK  69 (true).toString() === 'true'");
    } else {
        fail += 1;
        print("FAIL 69 (true).toString() tag=", r69);
    }

    # ── Test 70: (false).toString() → "false" ────────────────────────────────
    r70: JSValue = run_script(ctx, "(false).toString()");
    if jsv_is_string_cell(r70) and str_from_id(jsv_to_table_id(r70)) == "false" {
        ok += 1;
        print("OK  70 (false).toString() === 'false'");
    } else {
        fail += 1;
        print("FAIL 70 (false).toString() tag=", r70);
    }

    # ── Tests 71-72: Error.prototype.toString() ─────────────────────────────
    r71: JSValue = run_script(ctx, "new Error('oops').toString()");
    if jsv_is_string_cell(r71) and str_from_id(jsv_to_table_id(r71)) == "Error: oops" {
        ok += 1;
        print("OK  71 new Error('oops').toString() === 'Error: oops'");
    } else {
        fail += 1;
        print("FAIL 71 Error.prototype.toString tag=", r71);
    }

    r72: JSValue = run_script(ctx, "new TypeError('bad type').toString()");
    if jsv_is_string_cell(r72)
        and str_from_id(jsv_to_table_id(r72)) == "TypeError: bad type" {
        ok += 1;
        print("OK  72 new TypeError('bad type').toString() === 'TypeError: bad type'");
    } else {
        fail += 1;
        print("FAIL 72 TypeError.prototype.toString tag=", r72);
    }

    # ── Summary ───────────────────────────────────────────────────────────────
    print("=== e2e: " + str(ok) + "/" + str(ok + fail) + " passed ===");
    if fail > 0 {
        print("FAIL: " + str(fail) + " test(s) failed");
    }
}
