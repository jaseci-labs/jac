"""
tests/test_cell_header.na.jac — A2.1 smoke tests for JSCell header fields.

Verifies:
  1. CELL_KIND_* constants have the correct integer values.
  2. FLAG_* constants are correct bitmasks.
  3. Each cell-bearing type has the right cell_kind default, and cell_flags /
     structure_id both default to 0.
  4. cell_flags can be set and read back (basic read/write sanity).

Types covered directly:
  NativeFn, BuiltinFn, JSFunctionMeta, JSMapStorage, JSSetStorage,
  JSObject, JSRegExpState.

Types not directly constructed here (require CompiledFunction — complex struct):
  JSClosure, JSGeneratorState — exercised via the full 64/64 JS test suite.

Phase: A2.1
"""

import from engine.src.runtime.jscell {
    CELL_KIND_OBJECT,
    CELL_KIND_CLOSURE,
    CELL_KIND_FUNCTION,
    CELL_KIND_BUILTIN,
    CELL_KIND_NATIVE,
    CELL_KIND_MAP,
    CELL_KIND_SET,
    CELL_KIND_GENERATOR,
    CELL_KIND_REGEXP,
    CELL_KIND_SYMBOL,
    CELL_KIND_STRING,
    FLAG_MARKED,
    FLAG_HAS_WEAK,
    FLAG_FROZEN,
    FLAG_SEALED
}
import from engine.src.builtins.native_type { NativeFn }
import from engine.src.builtins.function_type { BuiltinFn, JSFunctionMeta }
import from engine.src.builtins.map_type { JSMapStorage }
import from engine.src.builtins.set_type { JSSetStorage }
import from engine.src.builtins.regexp_type { JSRegExpState }
import from engine.src.runtime.jsobj_type { JSObject }
import from engine.src.runtime.jsvalue { JSValue, js_undefined }

with entry {
    ok: bool = True;

    # ── 1. CELL_KIND constants ────────────────────────────────────────────────
    if CELL_KIND_OBJECT != 1 {
        ok = False;
        print("FAIL: CELL_KIND_OBJECT != 1");
    }
    if CELL_KIND_CLOSURE != 2 {
        ok = False;
        print("FAIL: CELL_KIND_CLOSURE != 2");
    }
    if CELL_KIND_FUNCTION != 3 {
        ok = False;
        print("FAIL: CELL_KIND_FUNCTION != 3");
    }
    if CELL_KIND_BUILTIN != 4 {
        ok = False;
        print("FAIL: CELL_KIND_BUILTIN != 4");
    }
    if CELL_KIND_NATIVE != 5 {
        ok = False;
        print("FAIL: CELL_KIND_NATIVE != 5");
    }
    if CELL_KIND_MAP != 6 {
        ok = False;
        print("FAIL: CELL_KIND_MAP != 6");
    }
    if CELL_KIND_SET != 7 {
        ok = False;
        print("FAIL: CELL_KIND_SET != 7");
    }
    if CELL_KIND_GENERATOR != 8 {
        ok = False;
        print("FAIL: CELL_KIND_GENERATOR != 8");
    }
    if CELL_KIND_REGEXP != 9 {
        ok = False;
        print("FAIL: CELL_KIND_REGEXP != 9");
    }
    if CELL_KIND_SYMBOL != 10 {
        ok = False;
        print("FAIL: CELL_KIND_SYMBOL != 10");
    }
    if CELL_KIND_STRING != 11 {
        ok = False;
        print("FAIL: CELL_KIND_STRING != 11");
    }
    if ok {
        print("OK: CELL_KIND constants");
    }

    # ── 2. FLAG constants ─────────────────────────────────────────────────────
    ok = True;
    if FLAG_MARKED != 1 {
        ok = False;
        print("FAIL: FLAG_MARKED != 1");
    }
    if FLAG_HAS_WEAK != 2 {
        ok = False;
        print("FAIL: FLAG_HAS_WEAK != 2");
    }
    if FLAG_FROZEN != 4 {
        ok = False;
        print("FAIL: FLAG_FROZEN != 4");
    }
    if FLAG_SEALED != 8 {
        ok = False;
        print("FAIL: FLAG_SEALED != 8");
    }
    if ok {
        print("OK: FLAG constants");
    }

    # ── 3. NativeFn header ────────────────────────────────────────────────────
    nf: NativeFn = NativeFn(name="test_native", arity=1, kind=99);
    ok = True;
    if nf.cell_kind != CELL_KIND_NATIVE {
        ok = False;
        print("FAIL: NativeFn cell_kind");
    }
    if nf.cell_flags != 0 {
        ok = False;
        print("FAIL: NativeFn cell_flags");
    }
    if nf.structure_id != 0 {
        ok = False;
        print("FAIL: NativeFn structure_id");
    }
    if ok {
        print("OK: NativeFn header");
    }

    # ── 4. BuiltinFn header ───────────────────────────────────────────────────
    bf: BuiltinFn = BuiltinFn(name="test_builtin", arity=0, kind=1);
    ok = True;
    if bf.cell_kind != CELL_KIND_BUILTIN {
        ok = False;
        print("FAIL: BuiltinFn cell_kind");
    }
    if bf.cell_flags != 0 {
        ok = False;
        print("FAIL: BuiltinFn cell_flags");
    }
    if bf.structure_id != 0 {
        ok = False;
        print("FAIL: BuiltinFn structure_id");
    }
    if ok {
        print("OK: BuiltinFn header");
    }

    # ── 5. JSFunctionMeta header ──────────────────────────────────────────────
    fm: JSFunctionMeta = JSFunctionMeta(
        name="f", arg_count=2, prototype_obj=js_undefined(), source=""
    );
    ok = True;
    if fm.cell_kind != CELL_KIND_FUNCTION {
        ok = False;
        print("FAIL: JSFunctionMeta cell_kind");
    }
    if fm.cell_flags != 0 {
        ok = False;
        print("FAIL: JSFunctionMeta cell_flags");
    }
    if fm.structure_id != 0 {
        ok = False;
        print("FAIL: JSFunctionMeta structure_id");
    }
    if ok {
        print("OK: JSFunctionMeta header");
    }

    # ── 6. JSMapStorage header ────────────────────────────────────────────────
    ms: JSMapStorage = JSMapStorage(nodes=[], key_index={}, keys=[], vals=[]);
    ok = True;
    if ms.cell_kind != CELL_KIND_MAP {
        ok = False;
        print("FAIL: JSMapStorage cell_kind");
    }
    if ms.cell_flags != 0 {
        ok = False;
        print("FAIL: JSMapStorage cell_flags");
    }
    if ms.structure_id != 0 {
        ok = False;
        print("FAIL: JSMapStorage structure_id");
    }
    if ok {
        print("OK: JSMapStorage header");
    }

    # ── 7. JSSetStorage header ────────────────────────────────────────────────
    ss: JSSetStorage = JSSetStorage(nodes=[], key_index={}, items=[]);
    ok = True;
    if ss.cell_kind != CELL_KIND_SET {
        ok = False;
        print("FAIL: JSSetStorage cell_kind");
    }
    if ss.cell_flags != 0 {
        ok = False;
        print("FAIL: JSSetStorage cell_flags");
    }
    if ss.structure_id != 0 {
        ok = False;
        print("FAIL: JSSetStorage structure_id");
    }
    if ok {
        print("OK: JSSetStorage header");
    }

    # ── 8. JSObject header ────────────────────────────────────────────────────
    # Properties, accessors and elements are lazily allocated (nullable) since
    # the object-footprint work; only the prototype link is required.
    jobj: JSObject = JSObject(prototype_idx=-1);
    ok = True;
    if jobj.cell_kind != CELL_KIND_OBJECT {
        ok = False;
        print("FAIL: JSObject cell_kind");
    }
    if jobj.cell_flags != 0 {
        ok = False;
        print("FAIL: JSObject cell_flags");
    }
    if jobj.structure_id != 0 {
        ok = False;
        print("FAIL: JSObject structure_id");
    }
    if ok {
        print("OK: JSObject header");
    }

    # ── 9. JSRegExpState header ───────────────────────────────────────────────
    re: JSRegExpState = JSRegExpState(
        pattern=".*",
        flags="g",
        last_index=0,
        pcre2_code_ptr=0,
        num_groups=0,
        group_names=[],
        flag_g=True,
        flag_i=False,
        flag_m=False,
        flag_s=False,
        flag_u=False,
        flag_y=False,
        flag_d=False,
        flag_v=False
    );
    ok = True;
    if re.cell_kind != CELL_KIND_REGEXP {
        ok = False;
        print("FAIL: JSRegExpState cell_kind");
    }
    if re.cell_flags != 0 {
        ok = False;
        print("FAIL: JSRegExpState cell_flags");
    }
    if re.structure_id != 0 {
        ok = False;
        print("FAIL: JSRegExpState structure_id");
    }
    if ok {
        print("OK: JSRegExpState header");
    }

    # ── 10. cell_flags read/write ─────────────────────────────────────────────
    nf2: NativeFn = NativeFn(name="flagtest", arity=0, kind=0);
    nf2.cell_flags = FLAG_MARKED;
    ok = True;
    if (nf2.cell_flags & FLAG_MARKED) == 0 {
        ok = False;
        print("FAIL: FLAG_MARKED not set");
    }
    nf2.cell_flags = nf2.cell_flags | FLAG_FROZEN;
    if (nf2.cell_flags & FLAG_FROZEN) == 0 {
        ok = False;
        print("FAIL: FLAG_FROZEN not set");
    }
    nf2.cell_flags = nf2.cell_flags & (FLAG_MARKED | FLAG_FROZEN);
    if (nf2.cell_flags & FLAG_HAS_WEAK) != 0 {
        ok = False;
        print("FAIL: FLAG_HAS_WEAK should be clear");
    }
    if ok {
        print("OK: cell_flags read/write");
    }

    print("A2.1 cell header tests done");
}
