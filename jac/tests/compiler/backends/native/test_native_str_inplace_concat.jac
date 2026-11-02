"""In-place `s += t` never treats a string literal as a growable heap block.

A string literal is a static `{refcount sentinel, tagged length, bytes}`
global: two header words, where a heap string carries four. The in-place
append has to look at the allocation word, the fourth word back, to learn
the buffer's capacity, and behind a literal that word lies outside the
global. Appending in place to a string that started as a literal must
therefore never treat the literal as a growable heap buffer.
"""

import os;
import ctypes;
import from tests.support {
    TESTS_DIR,
    compile_native,
    get_func,
    native_force_opts,
    native_str_func,
    remember_native_unit
}
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "in-place str append grows a literal-initialised string without touching the literal" {
    prog = JacProgram();
    mod = prog.compile(
        file_path=os.path.join(FIXTURES, "_inplace_concat_probe.jac"),
        use_str="def grow(n: int) -> str {\n"
        "    s = \"lit\";\n"
        "    i: int = 0;\n"
        "    while i < n {\n"
        "        s += \"x\";\n"
        "        i += 1;\n"
        "    }\n"
        "    return s;\n"
        "}\n",
        options=native_force_opts()
    );
    assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
    eng = mod.gen.native_engine;
    assert eng is not None , "no JIT engine for the probe";
    remember_native_unit(eng, mod);
    grow = native_str_func(eng, "grow", ctypes.c_char_p, ctypes.c_int64);
    for n in [0, 1, 8, 100, 0, 3] {
        got = grow(n);
        assert got == b"lit" + b"x" * n , (
            f"grow({n}) answered {got!r}; an append in place behind a static "
            f"literal must not read or write past the literal"
        );
    }
}

test "in-place str append keeps the ASCII flag honest" {
    (eng, _) = compile_native("inplace_concat_ascii.jac");
    grow_ascii = get_func(eng, "grow_ascii", ctypes.c_int64, ctypes.c_int64);
    grow_then_wide = get_func(eng, "grow_then_wide", ctypes.c_int64, ctypes.c_int64);
    assert grow_ascii(8) == 1 , "appending ASCII in place must keep the string ASCII";
    assert grow_then_wide(8) == 22 , (
        f"a non-ASCII append in place clears the flag and len counts codepoints: "
        f"{grow_then_wide(8)}"
    );
}

"""On wasm there is no floor to ask for the block's usable size; the module
must still verify."""
test "in-place str append verifies on wasm" {
    import from jaclang.compiler.driver.compile_options {
        CompileOptions,
        push_native_target,
        pop_native_target
    }
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    prev = push_native_target("wasm32-unknown-unknown");
    txt = "";
    try {
        prog = JacProgram();
        mod = prog.compile(
            file_path=os.path.join(FIXTURES, "_inplace_concat_wasm_probe.jac"),
            use_str="def grow(n: int) -> str {\n"
            "    s = \"lit\";\n"
            "    i: int = 0;\n"
            "    while i < n {\n"
            "        s += \"x\";\n"
            "        i += 1;\n"
            "    }\n"
            "    return s;\n"
            "}\n",
            options=CompileOptions(force_codespace="native", aot_mode=True)
        );
        assert not prog.errors_had , f"{[str(e) for e in prog.errors_had]}";
        txt = str(mod.gen.llvm_ir);
    } finally {
        pop_native_target(prev);
    }
    assert 'target triple = "wasm32-unknown-unknown"' in txt;
    llvm.parse_assembly(txt).verify();
}
