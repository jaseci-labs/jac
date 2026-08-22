"""E0082: assigning a client component's `has` state field during render.

The client state contract makes writes immediately visible, so a write in
the component body (which runs on every render) would re-render forever.
The validator rejects direct body writes -- including ones nested in
control flow -- while writes inside abilities, methods, and lambdas stay
legal because they only run after commit.
"""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     );

test "render-phase state writes are rejected, deferred writes are legal" {
    prog = JacProgram();
    prog.compile(os.path.join(FIXTURES, "render_phase_state_write.jac"));
    hits = [
        e
        for e in prog.errors_had
        if "E0082" in e.pretty_print()
    ];
    assert len(hits) == 2 , (
        f"expected exactly the two direct body writes to E0082, got "
        f"{len(hits)}: {[e.pretty_print() for e in prog.errors_had]}"
    );
    lines = sorted([e.loc.first_line for e in hits]);
    assert lines == [13, 15] , (
        f"E0082 must anchor the two body writes (lines 13 and 15), got {lines}"
    );
}
