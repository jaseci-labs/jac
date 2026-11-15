"""Scheduling gate for the native LLVM backend (#7367).

`NaIRGenPass` + `NativeCompilePass` -- and the ~130 MB `libjacllvm.so` ctypes
binding they pull in -- are only scheduled when a module actually needs native
codegen. These tests pin the two building blocks the compile scheduler relies
on so the gate cannot silently drift from `NaIRGenPass.transform`'s own trigger:

1. `codegen_lane(native=...)` includes the native passes iff `native=True`.
2. `ModuleFacts.has_native_context_stmts` -- the shared predicate the gate
   and the pass share -- is False for a plain Python module and True for a
   module carrying an inline `na {}` block.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pipeline { product_passes }
import from jaclang.compiler.driver.pipeline_types {
    CompilationProduct,
    ProductRequest
}

"""The passes a module's codegen requests, in order: the shared lowering, the Python IR, the structure freeze."""
def codegen_lane(native: bool) -> list[type] {
    lane: list[type] = [];
    for product in (
        CompilationProduct.CODEGEN,
        CompilationProduct.PY_IR,
        CompilationProduct.FROZEN
    ) {
        lane.extend(product_passes(product, ProductRequest(native=native)));
    }
    return lane;
}

import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
import from jaclang.compiler.backends.native.na_compile_pass { NativeCompilePass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "importing the native package does not initialize code generation" {
    import subprocess;
    import sys;
    result = subprocess.run(
        [
            sys.executable,
            "-c",
            "import sys; import jaclang.compiler.backends.native; "
            "assert 'jaclang.compiler.backends.native.na_compile_pass' not in sys.modules; "
            "assert 'jaclang.compiler.backends.native.na_ir_gen_pass' not in sys.modules"
        ],
        capture_output=True,
        text=True
    );
    assert result.returncode == 0 , result.stderr;
}


test "the codegen lane omits the native passes when native=False" {
    without_native = codegen_lane(False);
    assert NaIRGenPass not in without_native;
    assert NativeCompilePass not in without_native;
}


test "the codegen lane schedules the native passes when native=True" {
    with_native = codegen_lane(True);
    assert NaIRGenPass in with_native;
    assert NativeCompilePass not in with_native;
}


test "plain Python module carries no native-context statements" {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "gate_python_only.jac"),
        options=CompileOptions(default_codespace='server')
    );
    assert not ModuleFacts.has_native_context_stmts(ir);
}


test "module with an inline na block needs native codegen" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "mixed_contexts.jac"));
    assert ModuleFacts.has_native_context_stmts(ir);
}
