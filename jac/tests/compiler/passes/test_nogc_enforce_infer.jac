"""Regression tests for --memory nogc local ownership inference (issue #7466
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
`jac build --native --memory nogc`.
"""

import os;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "fixtures", "nogc_infer"
     );

"""Compile a fixture as a headerless nogc-enforced module; return its unique,
sorted diagnostic codes."""
def enforced_codes(fixture: str) -> list[str] {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    opts = CompileOptions(aot_mode=True, memory_profile="nogc");
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
    assert enforced_codes("scalar_call_range.jac") == [];
}

test "heap call-result local is still move-tracked (E1301 on reuse)" {
    assert enforced_codes("heap_call_still_tracked.jac") == ["E1301"];
}

test "slice of a borrowed param infers an owned local" {
    assert enforced_codes("slice_of_borrow.jac") == [];
}

test "typed-base enum members are scalar constants under enforcement" {
    assert enforced_codes("int_enum_members.jac") == [];
}

test "read-only method calls borrow their owned receiver and args" {
    assert enforced_codes("readonly_borrows.jac") == [];
}

test "native stdlib sinks borrow named owned arguments" {
    assert enforced_codes("stdlib_sink_borrows.jac") == [];
}

test "compiler-internal modules are exempt from ambient enforcement" {
    import jaclang;
    path = os.path.join(
        os.path.dirname(jaclang.__file__), "compiler", "passes", "dataflow.jac"
    );
    prog = JacProgram();
    opts = CompileOptions(memory_profile="nogc");
    prog.compile(file_path=path, options=opts);
    e14 = [
        a.code.code
        for a in prog.errors_had
        if a.code is not None and a.code.code.startswith("E14")
    ];
    assert e14 == [] , f"jaclang's own modules must never be nogc-enforced: {e14}";
}
