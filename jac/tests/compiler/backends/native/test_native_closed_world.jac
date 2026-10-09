"""#9782 step 1: native externs must have a declared provider.

Before the closed-world link, a native call to a bare `from os { getppid }`
looked the name up in the interop manifest, found a "server" binding whose
boundary scan had never marked a NATIVE caller, and declared a bare-name
extern anyway. No callback was generated for it, so the JIT resolved the
symbol against every symbol loaded in the process -- `getppid` answered with
libc's real pid, which is correct only by accident of name and ABI.

Two rules now hold:

- a server-context binding with no declared native caller is a compile
  error (E5092), not an extern declaration;
- interop symbols are module-qualified (`__jac_na_import_*`), so qualified,
  bare, and aliased spellings of the same server function resolve to the
  same symbol -- one mechanism.
"""

import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }


"""Write a tiny multi-file project into a temp dir; return its path."""
def _write_mods(mods: dict[str, str]) -> str {
    tmp = tempfile.mkdtemp(prefix="jac_closed_world_");
    for (fname, src) in mods.items() {
        with open(os.path.join(tmp, fname), "w") as f {
            f.write(src);
        }
    }
    return tmp;
}


test "a server binding with no declared native caller is a compile error" {
    prog = JacProgram();
    prog.compile(
        file_path="closed_world_getppid.jac",
        use_str="import from os { getppid }\n"
            + "def:pub pid -> i64 { return i64(getppid()); }\n",
        options=CompileOptions(native_required=True)
    );
    assert prog.errors_had , (
        "import from os { getppid } must not lower: its stub-resolved "
        "binding has no declared provider"
    );
    msgs = " ".join(str(e) for e in prog.errors_had);
    assert "getppid" in msgs , (f"the error must name the callee; got: {msgs[:300]}");
    codes = [
        str(e.code.code)
        for e in prog.errors_had
        if e.code is not None
    ];
    assert "E5092" in codes , (
        f"the refusal must be a codegen error, not silent codegen; got: {msgs[:300]}"
    );
}


test "bare and aliased spellings resolve to one interop symbol" {
    # `import helper` itself is refused earlier on the native pathway (a
    # module object cannot cross the boundary), so the spellings that reach
    # the emit are the bare and aliased `from` forms of one export -- and
    # they must emit a single qualified extern.
    tmp = _write_mods(
        {
            "jac.toml": ('[placement.pins]\nhelper = "server"\n'),
            "helper.jac": ("def:pub answer -> int {\n" "    return 42;\n" "}\n"),
            "main.jac": (
                "import from helper { answer }\n"
                + "import from helper { answer as ans }\n\n"
                + "def:pub two_ways -> int {\n"
                + "    return answer() + ans();\n"
                + "}\n"
            )
        }
    );
    prog = JacProgram();
    mod = prog.compile(
        os.path.join(tmp, "main.jac"),
        options=CompileOptions(
            aot_mode=True, default_codespace='native', skip_native_engine=True
        )
    );
    assert not prog.errors_had , (
        f"both spellings of the pinned function must lower; "
        f"errors: {[str(e) for e in prog.errors_had]}"
    );
    assert mod.gen.llvm_ir is not None , (
        "main.jac must lower for the native codespace"
    );
    ir_text = str(mod.gen.llvm_ir);
    import re;
    decls = re.findall(r"declare [^\n]*@\"?__jac_na_import_\w+", ir_text);
    all_decls = re.findall(r"declare [^\n]*@[^(\s]+", ir_text);
    assert len(decls) == 1 , (
        f"bare/aliased spellings must emit one extern, "
        f"got {decls}; all declares: {all_decls[:20]}"
    );
    assert "answer" in decls[0] , (f"the extern keeps the export name, got {decls[0]}");
    bare_name = re.search(r'@"answer"', ir_text);
    assert bare_name is None , ("no bare-name extern may survive the closed world");
}
