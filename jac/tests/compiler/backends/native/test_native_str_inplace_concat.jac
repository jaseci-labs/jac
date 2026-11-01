"""In-place `s += t` reads the allocation header only behind a heap block.

A string literal is a static `{refcount sentinel, tagged length, bytes}`
global: two header words, where a heap string carries four. The in-place
append has to look at the allocation word, the fourth word back, to learn
the buffer's capacity, and behind a literal that word lies outside the
global. The lowering therefore reads the refcount first, which both layouts
have, and reaches the allocation word only for a uniquely owned buffer; a
literal's sentinel refcount never passes that test.
"""

import os;
import ctypes;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""The instructions of one basic block of the printed module."""
def _block(txt: str, label: str) -> str {
    at = txt.find("\n" + label + ":\n");
    assert at >= 0 , f"no block {label!r} in the emitted IR";
    lines: list[str] = [];
    for line in txt[at + len(label) + 3:].split("\n") {
        if not line.startswith("  ") {
            break;
        }
        lines.append(line);
    }
    return "\n".join(lines);
}

test "in-place str append reads the refcount before the allocation word" {
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
    txt = str(mod.gen.llvm_ir);
    rc_blk = _block(txt, "cat.rc");
    hdr_blk = _block(txt, "cat.hdr");
    assert '%"ip.rc" = load i64' in rc_blk , (
        f"the refcount word is the first header read: {rc_blk}"
    );
    assert '%"ip.aw" = load i64' in hdr_blk , (
        f"the allocation word is read once the buffer is known unique: {hdr_blk}"
    );
    assert txt.count('%"ip.aw" = load i64') == 1 , (
        "the allocation word must not also be read ahead of the refcount test"
    );
    assert txt.count('label %"cat.hdr"') == 1 and 'label %"cat.hdr"' in rc_blk , (
        "only the refcount test may lead to the allocation-word read; a "
        "literal, whose refcount is the immortal sentinel, must never get there"
    );
    assert 'label %"cat.fresh"' in rc_blk , (
        "a shared or static string falls back to a fresh allocation"
    );
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

"""On wasm there is no floor to ask for the block's usable size, so the
capacity probe always grows the buffer; the module must still verify."""
test "in-place str append verifies on wasm, which skips the capacity probe" {
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
    assert "cat.capcall" in txt , "the probe compiled the in-place append";
    llvm.parse_assembly(txt).verify();
}
