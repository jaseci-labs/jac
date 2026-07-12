"""Scheduling gate for the native LLVM backend (#7367).

`NaIRGenPass` + `NativeCompilePass` -- and the ~130 MB `libjacllvm.so` ctypes
binding they pull in -- are only scheduled when a module actually needs native
codegen. These tests pin the two building blocks the compile scheduler relies
on so the gate cannot silently drift from `NaIRGenPass.transform`'s own trigger:

1. `get_py_code_gen(native=...)` includes the native passes iff `native=True`.
2. `ModuleCodegenPass.has_native_context_stmts` -- the shared predicate the gate
   and the pass share -- is False for a plain Python module and True for a
   module carrying an inline `na {}` block.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compiler { get_py_code_gen }
import from jaclang.jac0core.passes.module_codegen_pass { ModuleCodegenPass }
import from jaclang.compiler.passes.native { NaIRGenPass, NativeCompilePass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );


test "get_py_code_gen omits the native passes when native=False" {
    without_native = get_py_code_gen(native=False);
    assert NaIRGenPass not in without_native;
    assert NativeCompilePass not in without_native;
}


test "get_py_code_gen schedules the native passes when native=True" {
    with_native = get_py_code_gen(native=True);
    assert NaIRGenPass in with_native;
    assert NativeCompilePass in with_native;
}


test "plain Python module carries no native-context statements" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "gate_python_only.jac"));
    assert not ModuleCodegenPass.has_native_context_stmts(ir);
}


test "module with an inline na block needs native codegen" {
    prog = JacProgram();
    ir = prog.compile(file_path=os.path.join(FIXTURES, "mixed_contexts.jac"));
    assert ModuleCodegenPass.has_native_context_stmts(ir);
}
