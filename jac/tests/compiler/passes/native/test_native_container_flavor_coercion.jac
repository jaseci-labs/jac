"""Every container kind crosses the jacval seam through the coercion authority.

A homogeneous container stores its elements in a specialized slot array --
`i64`, `f64`, or a pointer -- while a container whose element type is `any` (or
any union that mixes representations) stores each element as a self-describing
`{ i8 tag, i64 payload }` jacval. The element-storage authority picks between
them, and the two layouts are different widths, so a value that walks from one
into the other must be rebuilt element by element. A pointer cast reinterprets
it instead: the payload of one slot is read as the whole of another.

`_coerce_type_inner` knew that, but only for `list`. It asked
`_spec_from_list_slot_type` for both sides, reflavored through
`_reflavor_list`, and emitted `E5092` when no reflavor existed. `dict` was not
in that table, so a `Dict.str.i64` handed to a `Dict.str.jacval` parameter fell
through to the function's closing `bitcast` and every value came back garbage
-- silently, in the one direction the documented authority says must never
exist ("no code path boxes a managed pointer into an integer slot where memory
management cannot see it").

That is what corrupted `json.dumps`: the shim's `_dump_value(value: any)`
narrows to `d: dict[str, any] = value`, so an ordinary `dict[str, int]`
argument crosses exactly this seam. `dumps({"k": 7, "j": 42})` rendered
`{"k": 42, "j": ""}` -- values shifted one slot, the last one garbage.

The fix makes the rule container-kind-agnostic: one flavor lookup over the
list, set, and dict type tables, one reflavor dispatch that rebuilds through
the same insertion helpers the literal path already uses, and the same `E5092`
when a faithful rebuild does not exist. The list behavior is pinned here too,
since it is the case the old rule covered and must not move. `set` is covered
by the same lookup but has no test: `set[any]` is not a lowerable signature
type, so no Jac source can reach that seam today.
"""

import ctypes;
import os;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.program { JacProgram }
import from tests.support { TESTS_DIR }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );


"""Forced-native options that skip the IR cache."""
def _opts -> CompileOptions {
    return CompileOptions(
        type_check=False,
        force_codespace='native',
        force_target_program=True,
        no_ir_cache=True
    );
}


"""Compile a fixture on the native pathway; return (program, module)."""
def _compile_native(fixture: str) -> tuple {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, fixture), options=_opts());
    return (prog, ir, );
}


"""The error codes a compiled program reported."""
def _codes(prog: any) -> list[str] {
    return [
        str(alrt.code.code)
        for alrt in prog.errors_had
        if alrt.code is not None
    ];
}


"""A JIT-resolved `int()` function from a compiled fixture."""
def _native_int_fn(ir: any, name: str) -> any {
    eng = ir.gen.native_engine;
    assert eng is not None , f"no native engine for '{name}'";
    addr = eng.get_function_address(name);
    assert addr != 0 , f"'{name}' is absent from the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr);
}


"""Compile the seam fixture once and return its JIT engine holder."""
def _seam_ir -> any {
    (prog, ir) = _compile_native("container_flavor_seam.jac");
    assert _codes(prog) == [] , (
        f"the seam fixture must compile clean, got: {[str(e) for e in prog.errors_had]}"
    );
    return ir;
}


test "a dict crossing the any seam keeps its values" {
    fn = _native_int_fn(_seam_ir(), "dict_seam_na");
    assert fn() == 49 , (
        "`dict[str, int]` handed to a `dict[str, any]` parameter was pointer "
        "cast, so each i64 value slot was read as a jacval tag+payload pair "
        "and every value came back garbage"
    );
}


test "the list seam the rule already covered does not move" {
    fn = _native_int_fn(_seam_ir(), "list_seam_na");
    assert fn() == 49 , (
        "`list` is the one kind `_coerce_type_inner` reflavored before this "
        "change; generalizing the rule must leave it exactly as it was"
    );
}


test "json.dumps renders a homogeneous dict faithfully" {
    (prog, ir) = _compile_native("container_flavor_json.jac");
    assert _codes(prog) == [] , (
        f"the json fixture must compile clean, got: {[str(e) for e in prog.errors_had]}"
    );
    fn = _native_int_fn(ir, "dumps_int_dict_na");
    assert fn() == 1 , (
        "the shim's `_dump_value(value: any)` narrows to `dict[str, any]`, "
        "so an ordinary `dict[str, int]` argument crossed the corrupting "
        "seam and `{\"k\": 7, \"j\": 42}` rendered as `{\"k\": 42, \"j\": \"\"}`"
    );
}
