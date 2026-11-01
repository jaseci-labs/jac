"""C functions that return twice (vfork, setjmp) are declared returns_twice."""

import from pathlib { Path }
import from tests.support { compile_native_ir, write_case }
import from jaclang.compiler.driver.compile_options { CompileOptions }

def _declaration(source: str, name: str) -> str {
    path = Path(write_case(source, "returns_twice.jac"));
    text = compile_native_ir(
        path.name,
        str(path.parent),
        CompileOptions(aot_mode=True, native_required=True)
    ).llvm_ir();
    for line in text.split("\n") {
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
