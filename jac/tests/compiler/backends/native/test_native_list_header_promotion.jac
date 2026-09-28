"""Loop-carried list headers stay in SSA values, not memory round-trips.

`__list_append_<elem>` used to re-load `data` after the grow check and to
write `cap`/`data` back into the header inside the grow block before the
allocation calls were even done. Once the append helper is inlined into a
caller loop, LLVM could not prove the element store `data[len] = v` does
not alias the header, so every iteration paid a full len/cap/data reload
plus header stores.

The helper now loads `data` once in the entry block, merges it through a
phi in the store block, moves the `cap`/`data` header stores behind the
malloc/memcpy/free calls, and tags header accesses with `!alias.scope`
against `!noalias` element-buffer accesses. A `!prof` branch weight marks
the grow edge cold. With all of that in place LLVM promotes all three
header fields into loop phis even when the list escapes through a global.

These tests pin the emitted IR shape (phi merge, tag placement, store
ordering, branch weights) and the runtime result against the sv/bytecode
answer for both scalar and managed element lists, since a mistagged
access would be a silent wrong answer rather than a compile error.
"""

import ctypes;
import from tests.support { NATIVE_FIXTURES, compile_native, get_func }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.compiler.frontend.codeinfo {
    get_effective_default_codespace_override,
    set_effective_default_codespace
}

glob FIXTURE = "list_header_churn.jac",
     _CACHE: dict[str, any] = {};


"""Compile the fixture natively; return (engine, llvm_ir_text)."""
def _compile -> tuple[any, str] {
    if _CACHE {
        return (_CACHE["eng"], _CACHE["ir"]);
    }
    (eng, res) = compile_native(FIXTURE);
    gi_addr = eng.get_function_address("__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    ir_text = str(res.gen.llvm_ir);
    _CACHE["eng"] = eng;
    _CACHE["ir"] = ir_text;
    return (eng, ir_text);
}


"""Import the same fixture through the sv/bytecode pathway."""
def _sv_module -> object {
    prev = get_effective_default_codespace_override();
    set_effective_default_codespace("server");
    try {
        mods = JacRuntime.jac_import(
            target=FIXTURE[:-4], base_path=NATIVE_FIXTURES, reload_module=True
        );
    } finally {
        set_effective_default_codespace(prev);
    }
    assert mods , "sv import of the fixture produced no module";
    return mods[0];
}


"""The body of a `define ... @"name"(...) { ... }` function in the IR."""
def _fn_body(ir_text: str, name: str) -> str {
    needle = f'@"{name}"';
    pos = 0;
    idx = -1;
    while pos >= 0 {
        idx = ir_text.find(needle, pos);
        if idx < 0 {
            break;
        }
        line_start = ir_text.rfind("\n", 0, idx);
        if "define" in ir_text[line_start:idx] {
            break;
        }
        pos = idx + 1;
    }
    assert idx >= 0 , f"{name} not present in emitted IR";
    body_start = ir_text.find("{", idx);
    body_end = ir_text.find("\n}\n", idx);
    assert body_start >= 0 and body_end > body_start , f"{name} body not found";
    return ir_text[body_start:body_end];
}


test "append merges data through a phi and stores headers after the calls" {
    (_, ir_text) = _compile();
    body = _fn_body(ir_text, "__list_append_i64");
    want_phi = 'phi  i64* [%"old.data", %"entry"], [%"new.data", %"grow"]';
    assert want_phi in body , "data pointer is not merged through a phi";
    grow_pos = body.find("grow:");
    store_pos = body.find("store:", grow_pos);
    assert grow_pos >= 0 and store_pos > grow_pos , "grow block not found";
    grow_block = body[grow_pos:store_pos];
    free_pos = grow_block.find("__rc_safe_free");
    if free_pos < 0 {
        free_pos = grow_block.find('"free"');
    }
    cap_store = grow_block.find('store i64 %"new.cap"');
    data_store = grow_block.find('store i64* %"new.data"');
    assert free_pos >= 0 , "grow block has no free call";
    stores_after = cap_store > free_pos and data_store > free_pos;
    assert stores_after , "cap/data header stores must come after alloc/copy/free";
}


test "append tags header scope, element noalias, and cold grow branch" {
    (_, ir_text) = _compile();
    body = _fn_body(ir_text, "__list_append_i64");
    assert "alias.scope" in body , "header accesses missing !alias.scope";
    assert "noalias" in body , "element store missing !noalias";
    has_prof = "!prof" in body and "branch_weights" in ir_text;
    assert has_prof , "grow edge missing !prof branch_weights";
    elem_store = body.find('%"slot"');
    tagged = elem_store >= 0 and "noalias" in body[elem_store:elem_store + 120];
    assert tagged , "element store is not tagged !noalias";
    assert "__list_grow" not in ir_text , "growth must stay inline, no helper";
}


test "header scope is shared across get set and len helpers" {
    (_, ir_text) = _compile();
    for name in ["__list_get_i64", "__list_set_i64", "__list_len_i64"] {
        body = _fn_body(ir_text, name);
        assert "alias.scope" in body , f"{name} header access untagged";
    }
    get_body = _fn_body(ir_text, "__list_get_i64");
    assert "noalias" in get_body , "element load in __list_get_i64 untagged";
}


test "churn returns the same answer as the sv runtime" {
    (eng, _) = _compile();
    sv = _sv_module();
    churn_sv = getattr(sv, "churn");
    for n in [0, 1, 63, 64, 65, 500, 5000] {
        native = get_func(eng, "churn", ctypes.c_int64, ctypes.c_int64)(n);
        expected = churn_sv(n);
        assert native == expected , f"churn({n}): native={native} sv={expected}";
    }
}


test "managed-element churn returns the same answer as the sv runtime" {
    (eng, _) = _compile();
    sv = _sv_module();
    churn_sv = getattr(sv, "churn_str");
    for n in [0, 1, 63, 64, 65, 500, 5000] {
        native = get_func(eng, "churn_str", ctypes.c_int64, ctypes.c_int64)(n);
        expected = churn_sv(n);
        assert native == expected , f"churn_str({n}): native={native} sv={expected}";
    }
}
