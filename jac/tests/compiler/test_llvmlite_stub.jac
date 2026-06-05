"""Tests for the hand-written `llvmlite.ir` type stub.

llvmlite ships no type information, so the type checker falls back to its
unannotated source and infers `object` / missing attributes for the API the
native pass uses. The bundled stub (jaclang/vendor/stubs/llvmlite) fixes that.
This guards that the stub resolves and the API surface type-checks cleanly.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent), "tests", "compiler", "fixtures"
     );

test "llvmlite ir API type-checks cleanly with the bundled stub" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "llvmlite_stub_check.jac"));
    errs = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"llvmlite stub did not resolve cleanly: {errs}";
}
