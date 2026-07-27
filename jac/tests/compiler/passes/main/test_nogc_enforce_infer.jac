"""Regression tests for --enforce-nogc local ownership inference (issue #7466
bug 5).

`_nogc_infer_locals` auto-stamps `own` on locals whose initializer produces
an owned result so unannotated code is still move-checked under enforcement.
It stamped every call-result local, including scalars: an `int` local
initialized from a call became move-tracked, and passing it to `range()` in
a for-header (whose CFG node sits on the loop back edge) reported a bogus
E1301 use-after-move. Scalars are copied by value and must never participate
in move tracking; heap call results must still be stamped so real
use-after-move on them keeps firing.

Each fixture is compiled through the real type-check schedule with
enforcement enabled via CompileOptions, matching
`jac nacompile --enforce-nogc --gc none`.
"""

import os;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "nogc_infer"
     );

"""Compile a fixture as a headerless nogc-enforced module; return its unique,
sorted diagnostic codes."""
def enforced_codes(fixture: str) -> list[str] {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    opts = CompileOptions(
        aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
    );
    prog.compile(file_path=path, options=opts);
    codes: set[str] = set();
    for alert in list(prog.errors_had) {
        if alert.code is not None {
            codes.add(alert.code.code);
        }
    }
    return sorted(codes);
}

test "scalar call-result local reused in a for-range header is clean" {
    assert enforced_codes("scalar_call_range.na.jac") == [];
}

test "heap call-result local is still move-tracked (E1301 on reuse)" {
    assert enforced_codes("heap_call_still_tracked.na.jac") == ["E1301"];
}
