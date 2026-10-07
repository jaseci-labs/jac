"""
Smoke tests: String built-in

Covers: constructor, static methods, prototype methods, auto-boxing.
Run with: jac run tests/test_builtin_string.na.jac
"""

import from engine.src.runtime.global { global_context_create, init_global }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.builtins.string {
    js_String_call,
    js_String_new,
    is_string_object,
    string_value_of,
    js_string_autobox,
    js_to_string_prim,
    js_String_fromCharCode,
    js_String_fromCodePoint,
    js_String_raw,
    js_str_length,
    js_str_charAt,
    js_str_charCodeAt,
    js_str_codePointAt,
    js_str_at,
    js_str_indexOf,
    js_str_lastIndexOf,
    js_str_includes,
    js_str_startsWith,
    js_str_endsWith,
    js_str_slice,
    js_str_substring,
    js_str_toLowerCase,
    js_str_toUpperCase,
    js_str_trim,
    js_str_trimStart,
    js_str_trimEnd,
    js_str_split,
    js_str_replace,
    js_str_replaceAll,
    js_str_padStart,
    js_str_padEnd,
    js_str_repeat,
    js_str_concat,
    js_str_match,
    js_str_search,
    js_str_toString
}
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_int,
    js_number,
    js_true,
    js_false,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_from_id }
import from engine.src.runtime.jsobject { KEY_LENGTH, js_object_get }

with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # ── 1: String(v) primitive coercion ──────────────────────────────────
    s1: JSValue = js_String_call([js_int(42)]);
    if jsv_is_string_cell(s1) and str_from_id(jsv_to_table_id(s1)) == "42" {
        ok += 1;
        print("OK  String(42) = '42'");
    } else {
        fail += 1;
        print("FAIL String(42) got tag=", s1);
    }

    # ── 2: String(undefined) → "undefined" ───────────────────────────────
    s2: JSValue = js_String_call([js_undefined()]);
    if str_from_id(jsv_to_table_id(s2)) == "undefined" {
        ok += 1;
        print("OK  String(undefined) = 'undefined'");
    } else {
        fail += 1;
        print("FAIL String(undefined) got='", str_from_id(jsv_to_table_id(s2)), "'");
    }

    # ── 3: String() with no args → "" ────────────────────────────────────
    s3: JSValue = js_String_call([]);
    if jsv_is_string_cell(s3) and str_from_id(jsv_to_table_id(s3)) == "" {
        ok += 1;
        print("OK  String() = ''");
    } else {
        fail += 1;
        print("FAIL String() got='", str_from_id(jsv_to_table_id(s3)), "'");
    }

    # ── 4: new String(v) returns Object ──────────────────────────────────
    s4: JSValue = js_String_new([js_String_call([])]);
    s4v: JSValue = js_String_call([]);
    wrapped4: JSValue = js_String_new([s4v]);
    if is_string_object(wrapped4) {
        ok += 1;
        print("OK  new String('') is a String object");
    } else {
        fail += 1;
        print("FAIL new String object tag=", wrapped4);
    }

    # ── 5: string_value_of extracts primitive ─────────────────────────────
    inner5: JSValue = js_String_call([js_int(99)]);
    wrapped5: JSValue = js_String_new([inner5]);
    prim5: JSValue = string_value_of(wrapped5);
    if jsv_is_string_cell(prim5) and str_from_id(jsv_to_table_id(prim5)) == "99" {
        ok += 1;
        print("OK  string_value_of(new String(99)) = '99'");
    } else {
        fail += 1;
        print("FAIL string_value_of got='", str_from_id(jsv_to_table_id(prim5)), "'");
    }

    # ── 6: String.fromCharCode ────────────────────────────────────────────
    fcc6: JSValue = js_String_fromCharCode([js_int(65), js_int(66), js_int(67)]);
    if str_from_id(jsv_to_table_id(fcc6)) == "ABC" {
        ok += 1;
        print("OK  String.fromCharCode(65,66,67) = 'ABC'");
    } else {
        fail += 1;
        print("FAIL fromCharCode='", str_from_id(jsv_to_table_id(fcc6)), "'");
    }

    # ── 7: String.fromCodePoint ───────────────────────────────────────────
    fcp7: JSValue = js_String_fromCodePoint([js_int(9731)]);  # ☃ snowman
    if jsv_is_string_cell(fcp7) and str_from_id(jsv_to_table_id(fcp7)) == "☃" {
        ok += 1;
        print("OK  String.fromCodePoint(9731) = '☃'");
    } else {
        fail += 1;
        print("FAIL fromCodePoint got='", str_from_id(jsv_to_table_id(fcp7)), "'");
    }

    # ── 8: length ─────────────────────────────────────────────────────────
    hello: JSValue = js_String_call([]);
    h_str: JSValue = js_String_call([js_String_call([])]);
    hv: JSValue = js_String_call([]);
    hw: JSValue = js_String_call([js_int(0)]);
    # use a literal
    sv8: JSValue = js_String_call([]);
    sv8 = js_String_call([]);
    sv8 = js_String_fromCharCode(
        [js_int(104), js_int(101), js_int(108), js_int(108), js_int(111)]
    );
    len8: JSValue = js_str_length(sv8);
    if jsv_is_int32(len8) and jsv_to_int32(len8) == 5 {
        ok += 1;
        print("OK  'hello'.length = 5");
    } else {
        fail += 1;
        print("FAIL length got=", jsv_to_int32(len8));
    }

    # ── 9: charAt ─────────────────────────────────────────────────────────
    c9: JSValue = js_str_charAt(sv8, js_int(1));
    if str_from_id(jsv_to_table_id(c9)) == "e" {
        ok += 1;
        print("OK  'hello'.charAt(1) = 'e'");
    } else {
        fail += 1;
        print("FAIL charAt='", str_from_id(jsv_to_table_id(c9)), "'");
    }

    # ── 10: charCodeAt ────────────────────────────────────────────────────
    cc10: JSValue = js_str_charCodeAt(sv8, js_int(0));
    if jsv_is_int32(cc10) and jsv_to_int32(cc10) == 104 {
        ok += 1;
        print("OK  'hello'.charCodeAt(0) = 104");
    } else {
        fail += 1;
        print("FAIL charCodeAt=", jsv_to_int32(cc10));
    }

    # ── 11: at() with negative index ──────────────────────────────────────
    at11: JSValue = js_str_at(sv8, js_int(-1));
    if str_from_id(jsv_to_table_id(at11)) == "o" {
        ok += 1;
        print("OK  'hello'.at(-1) = 'o'");
    } else {
        fail += 1;
        print("FAIL at(-1)='", str_from_id(jsv_to_table_id(at11)), "'");
    }

    # ── 12: indexOf ───────────────────────────────────────────────────────
    world: JSValue = js_String_fromCharCode(
        [
            js_int(104),
            js_int(101),
            js_int(108),
            js_int(108),
            js_int(111),
            js_int(32),
            js_int(119),
            js_int(111),
            js_int(114),
            js_int(108),
            js_int(100)
        ]
    );
    idx12: JSValue = js_str_indexOf(world, js_String_call([]), js_int(0));
    # index of "world" in "hello world"
    needle12: JSValue = js_String_fromCharCode(
        [js_int(119), js_int(111), js_int(114), js_int(108), js_int(100)]
    );
    idx12 = js_str_indexOf(world, needle12, js_int(0));
    if jsv_is_int32(idx12) and jsv_to_int32(idx12) == 6 {
        ok += 1;
        print("OK  'hello world'.indexOf('world') = 6");
    } else {
        fail += 1;
        print("FAIL indexOf=", jsv_to_int32(idx12));
    }

    # ── 13: includes ──────────────────────────────────────────────────────
    inc13: JSValue = js_str_includes(world, needle12, js_undefined());
    if jsv_is_bool(inc13) and jsv_to_bool(inc13) {
        ok += 1;
        print("OK  'hello world'.includes('world') = true");
    } else {
        fail += 1;
        print("FAIL includes");
    }

    # ── 14: startsWith ────────────────────────────────────────────────────
    sw14: JSValue = js_str_startsWith(world, sv8, js_undefined());
    if jsv_is_bool(sw14) and jsv_to_bool(sw14) {
        ok += 1;
        print("OK  'hello world'.startsWith('hello') = true");
    } else {
        fail += 1;
        print("FAIL startsWith");
    }

    # ── 15: endsWith ──────────────────────────────────────────────────────
    ew15: JSValue = js_str_endsWith(world, needle12, js_undefined());
    if jsv_is_bool(ew15) and jsv_to_bool(ew15) {
        ok += 1;
        print("OK  'hello world'.endsWith('world') = true");
    } else {
        fail += 1;
        print("FAIL endsWith");
    }

    # ── 16: slice ─────────────────────────────────────────────────────────
    sl16: JSValue = js_str_slice(world, js_int(6), js_int(11));
    if str_from_id(jsv_to_table_id(sl16)) == "world" {
        ok += 1;
        print("OK  'hello world'.slice(6,11) = 'world'");
    } else {
        fail += 1;
        print("FAIL slice='", str_from_id(jsv_to_table_id(sl16)), "'");
    }

    # ── 17: slice with negative index ─────────────────────────────────────
    sl17: JSValue = js_str_slice(world, js_int(-5), js_int(11));
    if str_from_id(jsv_to_table_id(sl17)) == "world" {
        ok += 1;
        print("OK  'hello world'.slice(-5) = 'world'");
    } else {
        fail += 1;
        print("FAIL slice(-5)='", str_from_id(jsv_to_table_id(sl17)), "'");
    }

    # ── 18: substring ─────────────────────────────────────────────────────
    sub18: JSValue = js_str_substring(world, js_int(0), js_int(5));
    if str_from_id(jsv_to_table_id(sub18)) == "hello" {
        ok += 1;
        print("OK  'hello world'.substring(0,5) = 'hello'");
    } else {
        fail += 1;
        print("FAIL substring='", str_from_id(jsv_to_table_id(sub18)), "'");
    }

    # ── 19: toUpperCase ───────────────────────────────────────────────────
    up19: JSValue = js_str_toUpperCase(sv8);
    if str_from_id(jsv_to_table_id(up19)) == "HELLO" {
        ok += 1;
        print("OK  'hello'.toUpperCase() = 'HELLO'");
    } else {
        fail += 1;
        print("FAIL toUpperCase='", str_from_id(jsv_to_table_id(up19)), "'");
    }

    # ── 20: toLowerCase ───────────────────────────────────────────────────
    lo20: JSValue = js_str_toLowerCase(up19);
    if str_from_id(jsv_to_table_id(lo20)) == "hello" {
        ok += 1;
        print("OK  'HELLO'.toLowerCase() = 'hello'");
    } else {
        fail += 1;
        print("FAIL toLowerCase='", str_from_id(jsv_to_table_id(lo20)), "'");
    }

    # ── 21: trim ──────────────────────────────────────────────────────────
    padded: JSValue = js_String_fromCharCode(
        [js_int(32), js_int(32), js_int(104), js_int(105), js_int(32), js_int(32)]
    );
    tr21: JSValue = js_str_trim(padded);
    if str_from_id(jsv_to_table_id(tr21)) == "hi" {
        ok += 1;
        print("OK  '  hi  '.trim() = 'hi'");
    } else {
        fail += 1;
        print("FAIL trim='", str_from_id(jsv_to_table_id(tr21)), "'");
    }

    # ── 22: trimStart ─────────────────────────────────────────────────────
    ts22: JSValue = js_str_trimStart(padded);
    if str_from_id(jsv_to_table_id(ts22)) == "hi  " {
        ok += 1;
        print("OK  '  hi  '.trimStart() = 'hi  '");
    } else {
        fail += 1;
        print("FAIL trimStart='", str_from_id(jsv_to_table_id(ts22)), "'");
    }

    # ── 23: trimEnd ───────────────────────────────────────────────────────
    te23: JSValue = js_str_trimEnd(padded);
    if str_from_id(jsv_to_table_id(te23)) == "  hi" {
        ok += 1;
        print("OK  '  hi  '.trimEnd() = '  hi'");
    } else {
        fail += 1;
        print("FAIL trimEnd='", str_from_id(jsv_to_table_id(te23)), "'");
    }

    # ── 24: replace ───────────────────────────────────────────────────────
    r24_in: JSValue = js_String_call([]);
    r24_in = js_String_fromCharCode(
        [js_int(97), js_int(98), js_int(99), js_int(97), js_int(98), js_int(99)]
    );
    r24_search: JSValue = js_String_fromCharCode([js_int(97)]);
    r24_rep: JSValue = js_String_fromCharCode([js_int(120)]);
    r24: JSValue = js_str_replace(r24_in, r24_search, r24_rep);
    if str_from_id(jsv_to_table_id(r24)) == "xbcabc" {
        ok += 1;
        print("OK  'abcabc'.replace('a','x') = 'xbcabc'");
    } else {
        fail += 1;
        print("FAIL replace='", str_from_id(jsv_to_table_id(r24)), "'");
    }

    # ── 25: replaceAll ────────────────────────────────────────────────────
    r25: JSValue = js_str_replaceAll(r24_in, r24_search, r24_rep);
    if str_from_id(jsv_to_table_id(r25)) == "xbcxbc" {
        ok += 1;
        print("OK  'abcabc'.replaceAll('a','x') = 'xbcxbc'");
    } else {
        fail += 1;
        print("FAIL replaceAll='", str_from_id(jsv_to_table_id(r25)), "'");
    }

    # ── 26: split ─────────────────────────────────────────────────────────
    csv: JSValue = js_String_fromCharCode(
        [js_int(97), js_int(44), js_int(98), js_int(44), js_int(99)]
    );
    comma: JSValue = js_String_fromCharCode([js_int(44)]);
    sp26: JSValue = js_str_split(csv, comma, js_undefined());
    len_v26: JSValue = js_object_get(sp26, KEY_LENGTH);
    if jsv_is_int32(len_v26) and jsv_to_int32(len_v26) == 3 {
        ok += 1;
        print("OK  'a,b,c'.split(',') length = 3");
    } else {
        fail += 1;
        print("FAIL split length=", jsv_to_int32(len_v26));
    }

    # ── 27: padStart ──────────────────────────────────────────────────────
    ps27_in: JSValue = js_String_fromCharCode([js_int(53)]);
    pad27: JSValue = js_String_fromCharCode([js_int(48)]);
    ps27: JSValue = js_str_padStart(ps27_in, js_int(3), pad27);
    if str_from_id(jsv_to_table_id(ps27)) == "005" {
        ok += 1;
        print("OK  '5'.padStart(3,'0') = '005'");
    } else {
        fail += 1;
        print("FAIL padStart='", str_from_id(jsv_to_table_id(ps27)), "'");
    }

    # ── 28: padEnd ────────────────────────────────────────────────────────
    pe28: JSValue = js_str_padEnd(ps27_in, js_int(3), pad27);
    if str_from_id(jsv_to_table_id(pe28)) == "500" {
        ok += 1;
        print("OK  '5'.padEnd(3,'0') = '500'");
    } else {
        fail += 1;
        print("FAIL padEnd='", str_from_id(jsv_to_table_id(pe28)), "'");
    }

    # ── 29: repeat ────────────────────────────────────────────────────────
    re29_in: JSValue = js_String_fromCharCode([js_int(97), js_int(98)]);
    re29: JSValue = js_str_repeat(re29_in, js_int(3));
    if str_from_id(jsv_to_table_id(re29)) == "ababab" {
        ok += 1;
        print("OK  'ab'.repeat(3) = 'ababab'");
    } else {
        fail += 1;
        print("FAIL repeat='", str_from_id(jsv_to_table_id(re29)), "'");
    }

    # ── 30: concat ────────────────────────────────────────────────────────
    x30: JSValue = js_String_fromCharCode([js_int(102), js_int(111), js_int(111)]);
    bar30: JSValue = js_String_fromCharCode([js_int(98), js_int(97), js_int(114)]);
    co30: JSValue = js_str_concat(x30, [bar30]);
    if str_from_id(jsv_to_table_id(co30)) == "foobar" {
        ok += 1;
        print("OK  'foo'.concat('bar') = 'foobar'");
    } else {
        fail += 1;
        print("FAIL concat='", str_from_id(jsv_to_table_id(co30)), "'");
    }

    # ── 31: toString / valueOf round-trip ─────────────────────────────────
    ts31: JSValue = js_str_toString(sv8);
    if jsv_is_string_cell(ts31) and str_from_id(jsv_to_table_id(ts31)) == "hello" {
        ok += 1;
        print("OK  'hello'.toString() = 'hello'");
    } else {
        fail += 1;
        print("FAIL toString='", str_from_id(jsv_to_table_id(ts31)), "'");
    }

    # ── 32: autobox wraps primitive ───────────────────────────────────────
    ab32: JSValue = js_string_autobox(sv8);
    if is_string_object(ab32) {
        ok += 1;
        print("OK  autobox('hello') is String object");
    } else {
        fail += 1;
        print("FAIL autobox tag=", ab32);
    }

    # ── 33: match stub returns null ───────────────────────────────────────
    m33: JSValue = js_str_match(sv8, js_null());
    if jsv_is_null(m33) {
        ok += 1;
        print("OK  match stub returns null");
    } else {
        fail += 1;
        print("FAIL match tag=", m33);
    }

    # ── 34: search stub returns -1 ────────────────────────────────────────
    se34: JSValue = js_str_search(sv8, js_null());
    if jsv_is_int32(se34) and jsv_to_int32(se34) == -1 {
        ok += 1;
        print("OK  search stub returns -1");
    } else {
        fail += 1;
        print("FAIL search=", jsv_to_int32(se34));
    }

    # ── 35: lastIndexOf ───────────────────────────────────────────────────
    li35: JSValue = js_str_lastIndexOf(r24_in, r24_search, js_undefined());
    if jsv_is_int32(li35) and jsv_to_int32(li35) == 3 {
        ok += 1;
        print("OK  'abcabc'.lastIndexOf('a') = 3");
    } else {
        fail += 1;
        print("FAIL lastIndexOf=", jsv_to_int32(li35));
    }

    print("string smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
