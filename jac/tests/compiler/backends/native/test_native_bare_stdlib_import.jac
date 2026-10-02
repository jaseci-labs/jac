"""Bare-name stdlib imports reach the native stdlib emitters.

`from os import getcwd; getcwd()` carries no module qualifier, so the
`module.func(...)` intercepts in `_codegen_module_member_call` never saw it:
the call fell through to the unsupported-builtin path, demoted its caller,
and dragged the module to the server codespace. The import scan now records
each bare binding that names a natively-lowered stdlib function, and the call
emitter routes it to that module's emitter.
"""

import os;
import from tests.support { TESTS_DIR, names_global, native_force_opts, source_spelled }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     _MEMO: list[any] = [];

def bare_fixture -> uni.Module {
    if _MEMO {
        return _MEMO[0];
    }
    prog = JacProgram();
    ir = prog.compile(
        file_path=str(os.path.join(FIXTURES, "bare_stdlib_from_import.jac")),
        options=native_force_opts()
    );
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors: {errors}";
    _MEMO.append(ir);
    return ir;
}


test "every bare-imported stdlib caller lowers natively" {
    ir = bare_fixture();
    assert ir.gen.llvm_ir is not None , "the fixture produced no native IR";
    text = source_spelled(str(ir.gen.llvm_ir));
    for name in (
        "cwd_nonempty",
        "pid_positive",
        "base_of",
        "joined",
        "rolled",
        "q_size"
    ) {
        assert names_global(text, name) , (
            f"'{name}' demoted: its bare stdlib call never reached the "
            f"native emitter"
        );
    }
}


test "the bare names lower to the same externs the qualified calls use" {
    ir = bare_fixture();
    text = source_spelled(str(ir.gen.llvm_ir));
    assert "getcwd" in text , "os.getcwd never lowered to its libc extern";
    assert "getpid" in text , "os.getpid never lowered to its libc extern";
}
