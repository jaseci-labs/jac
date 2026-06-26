"""Native backend robustness: graceful demotion instead of hard crashes.

The native (.na.jac) backend is best-effort -- a construct it cannot lower must
fall back to the Python implementation, never crash the whole compile with an
uncaught Python exception. These tests pin two guarantees:

1. A void-typed value bound to a variable surfaces E5090 (the "native pathway
   does not yet support ..." diagnostic) instead of asserting deep in
   `_entry_alloca` -> `PointerType.as_pointer()`.
2. A method whose body raises a hard error in the emitter is demoted to
   Python-only (workstream A4, #6930), so sibling methods in the same module
   still compile natively rather than the whole module aborting.
"""

import os;
import from pathlib { Path }
import from tests.support { TESTS_DIR }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

# --- Fix B: void binding is a diagnostic, not a crash ---
test "void binding surfaces E5090 instead of crashing" {
    prog = JacProgram();
    # Previously raised AssertionError in PointerType.as_pointer (void pointee).
    prog.compile(file_path=os.path.join(FIXTURES, "void_binding.na.jac"));
    assert prog.errors_had , "expected an E5090 diagnostic for the void binding";
    _msgs = [str(e) for e in prog.errors_had];
    assert any("void" in m for m in _msgs) , f"no void-binding diagnostic in {_msgs}";
}

# --- Fix A: a hard emitter error in one method does not abort the module ---
test "hard codegen error in one method demotes it, keeps siblings native" {
    prog = JacProgram();
    # Previously raised TypeError (i64 != void) and aborted the whole compile.
    ir = prog.compile(file_path=os.path.join(FIXTURES, "method_codegen_crash.na.jac"));
    layout = ir.gen.native_layout;
    assert layout is not None , "no native layout -- whole-module native compile aborted";
    assert "C.good" in layout.methods , (
        f"clean sibling method was lost: {list(layout.methods)}"
    );
    assert "C.bad" not in layout.methods , "un-lowerable method should be demoted/skipped";
    assert ir.gen.native_engine is not None , "no native engine produced after demotion";
}
