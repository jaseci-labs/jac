"""In-place `s += t` reads the allocation header only behind a heap block.

A string literal is a static `{refcount sentinel, tagged length, bytes}`
global: two header words, where a heap string carries four. The in-place
append has to look at the allocation word, the fourth word back, to learn
the buffer's capacity, and behind a literal that word lies outside the
global. The lowering therefore reads the refcount first, which both layouts
have, and reaches the allocation word only for a uniquely owned buffer; a
literal's sentinel refcount never passes that test, so a literal is never
appended to in place.
"""

import ctypes;
import from pathlib { Path }
import from tests.support {
    compile_native,
    compile_native_ir,
    get_func,
    native_str_func,
    write_case
}

glob GROW_SOURCE: str = (
         "def grow(n: int) -> str {\n"
         "    s = \"lit\";\n"
         "    i: int = 0;\n"
         "    while i < n {\n"
         "        s += \"x\";\n"
         "        i += 1;\n"
         "    }\n"
         "    return s;\n"
         "}\n"
     );

test "in-place str append never writes into a literal" {
    probe = Path(write_case(GROW_SOURCE, "_inplace_concat_probe.jac"));
    (eng, _) = compile_native(probe.name, str(probe.parent));
    grow = native_str_func(eng, "grow", ctypes.c_char_p, ctypes.c_int64);
    assert grow(5) == b"litxxxxx" , grow(5);
    assert grow(3) == b"litxxx" , "a second append run must start from the literal again";
    assert grow(0) == b"lit" , (
        "appending in place behind the literal overwrote its static bytes"
    );
    assert grow(64) == b"lit" + b"x" * 64 , "growing past the first buffer";
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
    probe = Path(write_case(GROW_SOURCE, "_inplace_concat_wasm_probe.jac"));
    prev = push_native_target("wasm32-unknown-unknown");
    txt = "";
    try {
        txt = compile_native_ir(
            probe.name,
            str(probe.parent),
            CompileOptions(force_codespace="native", aot_mode=True)
        ).llvm_ir();
    } finally {
        pop_native_target(prev);
    }
    assert 'target triple = "wasm32-unknown-unknown"' in txt;
    llvm.parse_assembly(txt).verify();
}
