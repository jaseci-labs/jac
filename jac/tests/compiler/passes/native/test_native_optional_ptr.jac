"""Behavioral, diagnostic, and IR-shape tests for tagged pointer optionals (#7871 A).

`str | None`, obj refs, tuples, and container elements all lower through the
one JacOptional rule: a tagged {i8, T} value whose tag is the only authority
on None-ness (container slots hold optional elements as jacval). Equality is
tag arithmetic plus a payload compare only when both sides carry values;
truthiness and f-strings follow Python (`None` renders, "" is falsy); explicit
unwrap flows through the single coerce emitter. Un-narrowed use where the
unwrapped value is required is an E1121 check-time diagnostic. On old main a
None `str` used as a dict key or strcmp operand dereferenced NULL and
segfaulted; these tests pin the diagnostic and the guard-free IR shape.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a .jac fixture and return the JIT engine."""
def compile_native(fixture: str) -> tuple[ExecutionEngine, uni.Module] {
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    return (eng, ir);
}

"""Compile a fixture expected to carry diagnostics; return error strings."""
def compile_errors(fixture: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path=str(os.path.join(FIXTURES, fixture)), options=native_force_opts()
    );
    return [str(e) for e in prog.errors_had];
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: type | None, *argtypes: type) -> object {
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

test "pointer optional: construct, narrow, and unwrap at every seam" {
    (eng, _) = compile_native("optional_ptr.jac");
    ol = get_func(eng, "opt_local_str", ctypes.c_int64, ctypes.c_int64);
    assert ol(1) == 4 , "narrowed local unwraps to len('beta')";
    assert ol(0) == -1 , "None local stays None";
    up = get_func(eng, "use_opt_param", ctypes.c_int64, ctypes.c_int64);
    assert up(1) == 5 , "value flows through the optional param";
    assert up(0) == -1 , "explicit None selects the None branch";
    oo = get_func(eng, "obj_opt_flow", ctypes.c_int64, ctypes.c_int64);
    assert oo(1) == 7 , "narrowed obj optional reads its field";
    assert oo(0) == -1 , "None obj optional narrows to the None branch";
}

test "pointer optional equality is tag arithmetic matching Python" {
    (eng, _) = compile_native("optional_ptr.jac");
    assert get_func(eng, "eq_matrix", ctypes.c_int64)() == 11101 , (
        "None == None, None != '', None != 'alpha', value equality, self-equality"
    );
    assert get_func(eng, "field_flow", ctypes.c_int64)() == 111 , (
        "field None -> value -> None round-trip through the tagged slot"
    );
}

test "pointer optional truthiness and f-string follow Python" {
    (eng, _) = compile_native("optional_ptr.jac");
    assert get_func(eng, "truthy_flow", ctypes.c_int64)() == 100 , (
        "None and '' are falsy; a value is truthy"
    );
    assert get_func(eng, "fstr_flow", ctypes.c_int64)() == 1 , (
        "f-string renders None as 'None' and a value as itself"
    );
}

test "narrowed optionals reach str helpers, concat, and dict keys" {
    (eng, _) = compile_native("optional_ptr.jac");
    hn = get_func(eng, "helper_after_narrow", ctypes.c_int64, ctypes.c_int64);
    assert hn(1) == 1 , "s.upper() on the narrowed payload";
    assert hn(0) == 0 , "None side never reaches the helper";
    assert get_func(eng, "concat_after_narrow", ctypes.c_int64)() == 1;
    assert get_func(eng, "dict_key_narrowed", ctypes.c_int64)() == 5 , (
        "narrowed optional key inserts and reads back"
    );
}

test "optional container elements ride jacval slots" {
    (eng, _) = compile_native("optional_ptr.jac");
    assert get_func(eng, "list_of_opt", ctypes.c_int64)() == 111 , (
        "list[str | None]: tag read, equality, narrowed element"
    );
    assert get_func(eng, "matrix_flow", ctypes.c_int64)() == 111 , (
        "nested list[list[int | None]]: read, narrow, overwrite"
    );
    assert get_func(eng, "unpack_flow", ctypes.c_int64)() == 34 , (
        "tuple | None narrows then unpacks"
    );
}

test "optional operands in container membership ride tagged slots" {
    # The sealed-binary build hit this shape in the jac0core lexer
    # (`prev_token_kind: TokenKind | None` tested with `in [TokenKind...]`):
    # the optional operand makes the literal a jacval-element list, and the
    # membership loop used to emit a raw integer icmp on the JacVal struct
    # (E5020 LLVM IR parse failure). A None operand must also mean plain
    # False membership, never an unwrap raise or a NULL strcmp.
    (eng, _) = compile_native("optional_ptr.jac");
    assert get_func(eng, "marker_membership", ctypes.c_int64)() == 1110 , (
        "None is in nothing; a carried value matches by payload"
    );
    assert get_func(eng, "opt_str_membership", ctypes.c_int64)() == 10 , (
        "None-string membership is False, value matches by strcmp"
    );
}

test "un-narrowed optional use at strict sites is E1121, never runtime UB" {
    msgs = compile_errors("optional_ptr_diag.jac");
    ordering = [
        m
        for m in msgs
        if "used where an ordered operand is required" in m
    ];
    subscript = [
        m
        for m in msgs
        if "used where a subscript index is required" in m
    ];
    assert len(ordering) == 2 , (
        f"expected E1121 for the str and int ordering vectors, got: {msgs}"
    );
    assert len(subscript) == 1 , (
        f"expected E1121 for the dict-key vector (segfaulted on old main), got: {msgs}"
    );
}

test "IR shape: tagged optionals, jacval slots, no NULL-guarded strcmp" {
    (_, ir) = compile_native("optional_ptr.jac");
    text = str(ir.gen.llvm_ir);
    assert "JacOpt." in text , "pointer optionals did not lower to JacOpt";
    assert "List.jacval" in text , "optional elements did not lower to jacval slots";
    for guard in (
        "strcmp.lnull",
        "strcmp.rnull",
        "strcmp.anynull",
        "strcmp.lsafe",
        "strcmp.rsafe"
    ) {
        assert guard not in text , (
            f"deleted #7851 NULL-guard '{guard}' reappeared at a strcmp site"
        );
    }
    assert "tobool.str.null" not in text , ("deleted truthiness NULL-guard reappeared");
}
