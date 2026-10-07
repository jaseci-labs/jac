import from engine.src.runtime.global { global_context_create, init_global, run_script }
import from engine.src.ffi.libc { fflush, _exit }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    js_undefined,
    jsv_from_string_id,
    jsv_hole,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_undefined,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.runtime.jsobject { js_object_create_null }
import from engine.src.builtins.array {
    js_array_create,
    js_array_create_with_length,
    js_array_has_index,
    js_array_get,
    js_array_set,
    js_array_len,
    js_is_array,
    js_Array,
    js_Array_isArray,
    js_Array_of,
    js_Array_from,
    js_Array_push,
    js_Array_pop,
    js_Array_shift,
    js_Array_unshift,
    js_Array_splice,
    js_Array_reverse,
    js_Array_fill,
    js_Array_concat,
    js_Array_slice,
    js_Array_join,
    js_Array_indexOf,
    js_Array_lastIndexOf,
    js_Array_includes,
    js_Array_at,
    js_Array_flat,
    js_Array_toString,
    js_Array_toLocaleString,
    js_Array_toReversed,
    js_Array_toSorted,
    js_Array_toSpliced,
    js_Array_with
}

def _ut_str(s: str) -> JSValue {
    return jsv_from_string_id(str_intern(s));
}

# ══════════════════════════════════════════════════════════════════════════════
# 11.  Smoke tests
# ══════════════════════════════════════════════════════════════════════════════

"""String value of a script result, or "<not a string>"."""
def _ut_js_str(v: JSValue) -> str {
    if not jsv_is_string_cell(v) {
        return "<not a string>";
    }
    return str_from_id(jsv_to_table_id(v));
}

with entry {
    # Engine startup: wire every module's realm singleton and install the
    # builtin prototypes, as the runtime does before running any script.
    ctx = global_context_create();
    init_global(ctx);

    ok: int = 0;
    fail: int = 0;

    # 1: create empty array
    a1: JSValue = js_array_create([]);
    if jsv_is_object_cell(a1) and js_array_len(a1) == 0 {
        ok += 1;
        print("OK  create empty array");
    } else {
        fail += 1;
        print("FAIL create empty");
    }

    # 2: create with elements, get
    a2: JSValue = js_array_create([js_int(10), js_int(20), js_int(30)]);
    g2: JSValue = js_array_get(a2, 1);
    if js_array_len(a2) == 3 and jsv_is_int32(g2) and jsv_to_int32(g2) == 20 {
        ok += 1;
        print("OK  create [10,20,30] get[1]=20");
    } else {
        fail += 1;
        print("FAIL create/get jsv_to_int32(g2)=", jsv_to_int32(g2));
    }

    # 3: set element (in-bounds)
    js_array_set(a2, 1, js_int(99));
    g3: JSValue = js_array_get(a2, 1);
    if jsv_is_int32(g3) and jsv_to_int32(g3) == 99 {
        ok += 1;
        print("OK  set in-bounds");
    } else {
        fail += 1;
        print("FAIL set in-bounds g3=", jsv_to_int32(g3));
    }

    # 4: set element (extends array)
    a4: JSValue = js_array_create([js_int(1)]);
    js_array_set(a4, 2, js_int(5));
    if js_array_len(a4) == 3 {
        ok += 1;
        print("OK  set extends length");
    } else {
        fail += 1;
        print("FAIL set extends len=", js_array_len(a4));
    }

    # 5: push
    a5: JSValue = js_array_create([js_int(1), js_int(2)]);
    r5: JSValue = js_Array_push(a5, [js_int(3), js_int(4)]);
    if js_array_len(a5) == 4 and jsv_is_int32(r5) and jsv_to_int32(r5) == 4 {
        ok += 1;
        print("OK  push returns 4");
    } else {
        fail += 1;
        print("FAIL push len=", js_array_len(a5));
    }

    # 6: pop
    last6: JSValue = js_Array_pop(a5);
    if jsv_is_int32(last6) and jsv_to_int32(last6) == 4 and js_array_len(a5) == 3 {
        ok += 1;
        print("OK  pop returns 4");
    } else {
        fail += 1;
        print("FAIL pop got=", jsv_to_int32(last6));
    }

    # 7: shift
    a7: JSValue = js_array_create([js_int(7), js_int(8), js_int(9)]);
    first7: JSValue = js_Array_shift(a7);
    if jsv_is_int32(first7) and jsv_to_int32(first7) == 7 and js_array_len(a7) == 2 {
        ok += 1;
        print("OK  shift");
    } else {
        fail += 1;
        print("FAIL shift got=", jsv_to_int32(first7));
    }

    # 8: unshift
    js_Array_unshift(a7, [js_int(5), js_int(6)]);
    u8: JSValue = js_array_get(a7, 0);
    if js_array_len(a7) == 4 and jsv_is_int32(u8) and jsv_to_int32(u8) == 5 {
        ok += 1;
        print("OK  unshift");
    } else {
        fail += 1;
        print("FAIL unshift first=", jsv_to_int32(u8), " len=", js_array_len(a7));
    }

    # 9: reverse
    a9: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    js_Array_reverse(a9);
    r9: JSValue = js_array_get(a9, 0);
    if jsv_is_int32(r9) and jsv_to_int32(r9) == 3 {
        ok += 1;
        print("OK  reverse");
    } else {
        fail += 1;
        print("FAIL reverse first=", jsv_to_int32(r9));
    }

    # 10: slice
    a10: JSValue = js_array_create([js_int(10), js_int(20), js_int(30), js_int(40)]);
    s10: JSValue = js_Array_slice(a10, js_int(1), js_int(3));
    s10_0: JSValue = js_array_get(s10, 0);
    s10_1: JSValue = js_array_get(s10, 1);
    if js_array_len(s10) == 2
        and jsv_to_int32(s10_0) == 20
        and jsv_to_int32(s10_1) == 30 {
        ok += 1;
        print("OK  slice [1:3]");
    } else {
        fail += 1;
        print("FAIL slice len=", js_array_len(s10));
    }

    # 11: join
    a11: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    j11: JSValue = js_Array_join(a11, _ut_str("-"));
    j11s: str = str_from_id(jsv_to_table_id(j11));
    if jsv_is_string_cell(j11) and j11s == "1-2-3" {
        ok += 1;
        print("OK  join '1-2-3'");
    } else {
        fail += 1;
        print("FAIL join got=", j11s);
    }

    # 12: indexOf / lastIndexOf
    a12: JSValue = js_array_create([js_int(1), js_int(2), js_int(3), js_int(2)]);
    idx12: JSValue = js_Array_indexOf(a12, js_int(2), js_undefined());
    lidx12: JSValue = js_Array_lastIndexOf(a12, js_int(2), js_undefined(), False);
    if jsv_to_int32(idx12) == 1 and jsv_to_int32(lidx12) == 3 {
        ok += 1;
        print("OK  indexOf=1 lastIndexOf=3");
    } else {
        fail += 1;
        print(
            "FAIL indexOf=", jsv_to_int32(idx12), " lastIndexOf=", jsv_to_int32(lidx12)
        );
    }

    # 13: includes
    a13: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    inc_t: JSValue = js_Array_includes(a13, js_int(2), js_undefined());
    inc_f: JSValue = js_Array_includes(a13, js_int(9), js_undefined());
    if jsv_is_bool(inc_t)
        and jsv_to_bool(inc_t)
        and jsv_is_bool(inc_f)
        and not jsv_to_bool(inc_f) {
        ok += 1;
        print("OK  includes");
    } else {
        fail += 1;
        print("FAIL includes");
    }

    # 14: at (negative index)
    a14: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    at14: JSValue = js_Array_at(a14, js_int(-1));
    if jsv_is_int32(at14) and jsv_to_int32(at14) == 3 {
        ok += 1;
        print("OK  at(-1)=3");
    } else {
        fail += 1;
        print("FAIL at(-1)=", jsv_to_int32(at14));
    }

    # 15: concat
    a15a: JSValue = js_array_create([js_int(1), js_int(2)]);
    a15b: JSValue = js_array_create([js_int(3), js_int(4)]);
    a15c: JSValue = js_Array_concat(a15a, [a15b, js_int(5)]);
    c15_4: JSValue = js_array_get(a15c, 4);
    if js_array_len(a15c) == 5 and jsv_to_int32(c15_4) == 5 {
        ok += 1;
        print("OK  concat length=5");
    } else {
        fail += 1;
        print("FAIL concat len=", js_array_len(a15c));
    }

    # 16: fill
    a16: JSValue = js_array_create([js_int(0), js_int(0), js_int(0), js_int(0)]);
    js_Array_fill(a16, js_int(7), js_int(1), js_int(3));
    f16_0: JSValue = js_array_get(a16, 0);
    f16_1: JSValue = js_array_get(a16, 1);
    f16_3: JSValue = js_array_get(a16, 3);
    if jsv_to_int32(f16_0) == 0
        and jsv_to_int32(f16_1) == 7
        and jsv_to_int32(f16_3) == 0 {
        ok += 1;
        print("OK  fill [1:3] with 7");
    } else {
        fail += 1;
        print(
            "FAIL fill", jsv_to_int32(f16_0), jsv_to_int32(f16_1), jsv_to_int32(f16_3)
        );
    }

    # 17: flat
    inner: JSValue = js_array_create([js_int(3), js_int(4)]);
    a17: JSValue = js_array_create([js_int(1), js_int(2), inner]);
    flat17: JSValue = js_Array_flat(a17, js_int(1));
    if js_array_len(flat17) == 4 and jsv_to_int32(js_array_get(flat17, 3)) == 4 {
        ok += 1;
        print("OK  flat depth=1");
    } else {
        fail += 1;
        print("FAIL flat len=", js_array_len(flat17));
    }

    # 18: sort. Array.prototype.sort re-enters the VM to call the comparator,
    # so its native entry point (js_Array_sort) only throws a TypeError when
    # called without one — and that pending exception would make every later
    # builtin in this test bail out. Exercise it the way JS reaches it.
    a18: JSValue = js_array_create(
        [js_int(3), js_int(1), js_int(4), js_int(1), js_int(5)]
    );
    s18a: str = _ut_js_str(run_script(ctx, "[3,1,4,1,5].sort().join(',')"));
    s18b: str = _ut_js_str(run_script(ctx, "[10,9,1].sort().join(',')"));
    s18c: str = _ut_js_str(
        run_script(ctx, "[10,9,1].sort(function(a,b){ return a - b; }).join(',')")
    );
    if s18a == "1,1,3,4,5" {
        ok += 1;
        print("OK  sort [1,1,3,4,5]");
    } else {
        fail += 1;
        print("FAIL sort got", s18a);
    }
    # Without a comparator elements compare as strings.
    if s18b == "1,10,9" {
        ok += 1;
        print("OK  sort default order is by string");
    } else {
        fail += 1;
        print("FAIL sort default order got", s18b);
    }
    if s18c == "1,9,10" {
        ok += 1;
        print("OK  sort with numeric comparator");
    } else {
        fail += 1;
        print("FAIL sort comparator got", s18c);
    }

    # 19: Array.isArray
    arr_obj: JSValue = js_object_create_null();
    ia_yes: JSValue = js_Array_isArray(a18);
    ia_no: JSValue = js_Array_isArray(arr_obj);
    if jsv_to_bool(ia_yes) and not jsv_to_bool(ia_no) {
        ok += 1;
        print("OK  Array.isArray");
    } else {
        fail += 1;
        print("FAIL isArray yes=", jsv_to_bool(ia_yes), " no=", jsv_to_bool(ia_no));
    }

    # 20: Array.of
    a20: JSValue = js_Array_of([js_int(10), js_int(20), js_int(30)]);
    if js_array_len(a20) == 3 and jsv_to_int32(js_array_get(a20, 2)) == 30 {
        ok += 1;
        print("OK  Array.of length=3");
    } else {
        fail += 1;
        print("FAIL Array.of");
    }

    # 21: Array.from (from array)
    a21: JSValue = js_Array_from(a20);
    if js_array_len(a21) == 3 and jsv_to_int32(js_array_get(a21, 0)) == 10 {
        ok += 1;
        print("OK  Array.from(array)");
    } else {
        fail += 1;
        print("FAIL Array.from");
    }

    # 22: R15 keys/values/entries are VM-threaded (CreateArrayIterator);
    # covered by test262 / smoke tests that run under init_global.
    a22: JSValue = js_array_create([js_int(5), js_int(6)]);
    if js_array_len(a22) == 2 and jsv_to_int32(js_array_get(a22, 0)) == 5 {
        ok += 1;
        print("OK  array baseline (iterators VM-threaded)");
    } else {
        fail += 1;
        print("FAIL array baseline");
    }

    # 23: splice
    a23: JSValue = js_array_create([js_int(1), js_int(2), js_int(3), js_int(4)]);
    removed23: JSValue = js_Array_splice(a23, js_int(1), js_int(2), [js_int(9)], True);
    r23_0: JSValue = js_array_get(removed23, 0);
    a23_1: JSValue = js_array_get(a23, 1);
    if js_array_len(removed23) == 2
        and jsv_to_int32(r23_0) == 2
        and js_array_len(a23) == 3
        and jsv_to_int32(a23_1) == 9 {
        ok += 1;
        print("OK  splice");
    } else {
        fail += 1;
        print(
            "FAIL splice rem_len=",
            js_array_len(removed23),
            " a23_len=",
            js_array_len(a23)
        );
    }

    # 24: Array constructor single-int creates sparse
    a24: JSValue = js_Array([js_int(5)]);
    if js_array_len(a24) == 5 {
        ok += 1;
        print("OK  Array(5) sparse length=5");
    } else {
        fail += 1;
        print("FAIL Array(5) len=", js_array_len(a24));
    }

    # 25: pop empty
    pop_empty: JSValue = js_Array_pop(js_array_create([]));
    if jsv_is_undefined(pop_empty) {
        ok += 1;
        print("OK  pop empty = undefined");
    } else {
        fail += 1;
        print("FAIL pop empty");
    }

    # 26: toReversed — non-mutating
    a26_src: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    a26_rev: JSValue = js_Array_toReversed(a26_src);
    first26: JSValue = js_array_get(a26_rev, 0);
    orig26: JSValue = js_array_get(a26_src, 0);
    if jsv_to_int32(first26) == 3 and jsv_to_int32(orig26) == 1 {
        ok += 1;
        print("OK  toReversed");
    } else {
        fail += 1;
        print(
            "FAIL toReversed first=",
            jsv_to_int32(first26),
            " orig=",
            jsv_to_int32(orig26)
        );
    }

    # 27: toSorted — non-mutating
    a27_src: JSValue = js_array_create([js_int(3), js_int(1), js_int(2)]);
    a27_srt: JSValue = js_Array_toSorted(a27_src, js_undefined());
    first27: JSValue = js_array_get(a27_srt, 0);
    orig27_0: JSValue = js_array_get(a27_src, 0);
    if jsv_to_int32(first27) == 1 and jsv_to_int32(orig27_0) == 3 {
        ok += 1;
        print("OK  toSorted");
    } else {
        fail += 1;
        print(
            "FAIL toSorted first=",
            jsv_to_int32(first27),
            " src0=",
            jsv_to_int32(orig27_0)
        );
    }

    # 28: toSpliced — non-mutating (remove 1 element at index 1)
    a28_src: JSValue = js_array_create([js_int(10), js_int(20), js_int(30)]);
    a28_new: JSValue = js_Array_toSpliced(
        a28_src, js_int(1), js_int(1), [], True, True
    );
    len28: int = js_array_len(a28_new);
    orig28: int = js_array_len(a28_src);
    if len28 == 2 and orig28 == 3 {
        ok += 1;
        print("OK  toSpliced");
    } else {
        fail += 1;
        print("FAIL toSpliced new_len=", len28, " orig_len=", orig28);
    }

    # 29: with — non-mutating element replacement
    a29_src: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    a29_new: JSValue = js_Array_with(a29_src, js_int(1), js_int(99));
    mid29: JSValue = js_array_get(a29_new, 1);
    orig29: JSValue = js_array_get(a29_src, 1);
    if jsv_to_int32(mid29) == 99 and jsv_to_int32(orig29) == 2 {
        ok += 1;
        print("OK  with");
    } else {
        fail += 1;
        print(
            "FAIL with new[1]=", jsv_to_int32(mid29), " orig[1]=", jsv_to_int32(orig29)
        );
    }

    # 30: toLocaleString (fallback = join with comma)
    a30: JSValue = js_array_create([js_int(1), js_int(2), js_int(3)]);
    s30: JSValue = js_Array_toLocaleString(a30);
    if jsv_is_string_cell(s30) {
        ok += 1;
        print("OK  toLocaleString");
    } else {
        fail += 1;
        print("FAIL toLocaleString tag=", s30);
    }

    # 31: hole sentinel — js_array_create skips holes
    a31: JSValue = js_array_create([_ut_str("a"), jsv_hole(), _ut_str("c")]);
    if js_array_len(a31) == 3
        and js_array_has_index(a31, 0)
        and not js_array_has_index(a31, 1)
        and js_array_has_index(a31, 2) {
        ok += 1;
        print("OK  sparse create skips holes");
    } else {
        fail += 1;
        print("FAIL sparse create holes");
    }

    # 32: js_array_create_with_length — length only, no indices
    a32: JSValue = js_array_create_with_length(4);
    if js_array_len(a32) == 4
        and not js_array_has_index(a32, 0)
        and not js_array_has_index(a32, 3) {
        ok += 1;
        print("OK  create_with_length sparse");
    } else {
        fail += 1;
        print("FAIL create_with_length len=", js_array_len(a32));
    }

    # 33: slice preserves holes
    a33: JSValue = js_array_create([js_int(1), jsv_hole(), js_int(3)]);
    sl33: JSValue = js_Array_slice(a33, js_int(0), js_undefined());
    if js_array_len(sl33) == 3
        and js_array_has_index(sl33, 0)
        and not js_array_has_index(sl33, 1)
        and js_array_has_index(sl33, 2) {
        ok += 1;
        print("OK  slice preserves holes");
    } else {
        fail += 1;
        print("FAIL slice holes");
    }

    print("array smoke: passed=" + str(ok) + " failed=" + str(fail));
    if fail > 0 {
        fflush(0);
        _exit(1);
    }
}
