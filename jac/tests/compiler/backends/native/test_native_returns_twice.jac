"""C functions that return twice (vfork, setjmp) are declared returns_twice."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def _declaration(source: str, name: str) -> str {
    program = JacProgram();
    module = program.compile(
        file_path="returns_twice.jac",
        use_str=source,
        options=CompileOptions(
            aot_mode=True,
            no_ir_cache=True,
            skip_native_engine=True,
            native_required=True
        )
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    assert module is not None and module.gen.llvm_ir is not None;
    for line in str(module.gen.llvm_ir).split("\n") {
        if line.startswith("declare")
            and (f'@"{name}"(' in line or f"@{name}(" in line) {
            return line;
        }
    }
    return "";
}

test "a vfork declaration returns twice and plain externs do not" {
    source = "import from c { def vfork -> i32; def getpid -> i32; }\n"
        + "def:pub start_child -> i32 { pid = vfork(); if pid == 0 { return getpid(); } return pid; }\n";
    assert "returns_twice" in _declaration(source, "vfork");
    assert "returns_twice" not in _declaration(source, "getpid");
}
