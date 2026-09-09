"""Scheduling gate for the native LLVM backend (#7367).

`NaIRGenPass` + `NativeCompilePass` -- and the ~130 MB `libjacllvm.so` ctypes
binding they pull in -- are only scheduled when a module actually needs native
codegen. These tests pin the two building blocks the compile scheduler relies
on so the gate cannot silently drift from `NaIRGenPass.transform`'s own trigger:

1. `get_py_code_gen(native=...)` includes the native passes iff `native=True`.
2. `ModuleFacts.has_native_context_stmts` -- the shared predicate the gate
   and the pass share -- is False for a plain Python module and True for a
   module carrying an inline `na {}` block.
"""

import os;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.schedules {
    get_analysis_sched,
    get_boundary_analysis_sched,
    get_ir_gen_sched,
    get_py_code_gen,
    providers_of
}
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.backends.native { NaIRGenPass, NativeCompilePass }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );


test "get_py_code_gen omits the native passes when native=False" {
    without_native = get_py_code_gen(native=False);
    assert NaIRGenPass not in without_native;
    assert NativeCompilePass not in without_native;
}


test "get_py_code_gen schedules the native passes when native=True" {
    # Codegen runs after the analysis stage in the single pipeline, so the
    # standalone schedule is constructed against its provides.
    with_native = get_py_code_gen(
        native=True,
        provided=providers_of(
            get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched()
        )
    );
    assert NaIRGenPass in with_native;
    assert NativeCompilePass in with_native;
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
