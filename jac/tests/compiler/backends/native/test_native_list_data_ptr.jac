"""`__list_data_ptr(lst)`: the element buffer of an `int` or `float` list, for the `__mem_*` accessors.

The intrinsic is the address of the list's `data` field, as an integer: a
write through it is the list's element, with no bounds check, so code that
owns its indices (an interpreter's register file) reads and writes a
register with one load or store. It is refused (E5095) for a list of
objects, whose elements a raw word store would take out of the reference
count, and for a temporary list, which is freed with the statement; a
non-list operand is a type error.
"""

import ctypes;
import os;
import tempfile;
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    NATIVE_FIXTURES
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.na_coverage { na_coverage_begin, na_coverage_end }
import from jaclang.compiler.frontend.diagnostics { DiagnosticInfo, E1053 }

glob FIXTURE: str = "list_data_ptr.jac",
     REFUSALS: str = "list_data_ptr_refusals.jac";

"""Compile `source` in a tempdir; return the (code, message) of each error."""
def compile_errors(source: str) -> list[tuple[DiagnosticInfo | None, str]] {
    with tempfile.TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "list_data_probe.jac");
        with open(src, "w") as f {
            f.write(source);
        }
        prog = JacProgram();
        prog.compile(file_path=src, options=CompileOptions(force_codespace="native"));
        return [(e.code, str(e)) for e in prog.errors_had];
    }
}

"""The refusal fixture's demotion seams, by function."""
def refusal_seams -> dict[str, str] {
    path = os.path.join(NATIVE_FIXTURES, REFUSALS);
    na_coverage_begin();
    try {
        JacProgram().compile(
            file_path=path, options=CompileOptions(force_codespace="native")
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(path));
    seams: dict[str, str] = {};
    for seam in ((rec.get("seams") or []) if rec is not None else []) {
        text = str(seam);
        seams[text.split(": ")[0]] = text;
    }
    return seams;
}

test "writes through the buffer are the list's elements, and the other way" {
    (eng, _mod) = compile_native(FIXTURE);
    for (name, x, want) in [
        ("int_roundtrip", 4, 41),
        ("float_roundtrip", 4, 18),
        ("field_operand", 4, 4),
        ("element_operand", 4, 4),
        ("after_growth", 100, 297)
    ] {
        fn = get_func(eng, name, ctypes.c_int64, ctypes.c_int64);
        got = fn(x);
        assert got == want , f"{name}({x}) = {got}, want {want}";
    }
}

test "the call lowers to a load of the list's data field" {
    text = str(compile_native_ir(FIXTURE).gen.llvm_ir);
    lines = [line.strip() for line in text.splitlines()];
    # field 2 of `{ len, cap, data* }`, loaded and turned into an integer
    assert any(
        '%"list.data.pp" = getelementptr' in line and "i32 0, i32 2" in line
        for line in lines
    ) , "no GEP of the list's data field";
    assert any(line.startswith('%"list.data.p" = load') for line in lines);
    assert any(line.startswith('%"list.data.i64" = ptrtoint') for line in lines);
    # the intrinsic is lowered, never called
    assert not any("__list_data_ptr" in line for line in lines) , "a call of __list_data_ptr was left in the IR";
}

test "a list of objects or strings is refused: its elements are reference counted" {
    seams = refusal_seams();
    for name in ["objects_list", "str_list"] {
        seam = seams.get(name, "");
        assert "[E5095]" in seam and "holds managed elements" in seam , f"{name}: {seams}";
    }
}

test "a temporary list is refused: it is freed with the statement" {
    seams = refusal_seams();
    for name in ["call_result", "literal_list"] {
        seam = seams.get(name, "");
        assert "[E5095]" in seam
            and "a temporary list is freed with the statement" in seam , f"{name}: {seams}";
    }
    # the function that makes the temporary lowers: only the call site is refused
    assert "make" not in seams , seams;
}

test "a non-list operand is a type error" {
    errors = compile_errors(
        "def probe(x: int) -> int { return __list_data_ptr(x); }\n"
    );
    assert any(code is E1053 for (code, _msg) in errors) , errors;
}
