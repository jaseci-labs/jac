"""E0082: assigning a client component's `has` state field during render.

The client state contract makes writes immediately visible, so a write in
the component body (which runs on every render) would re-render forever.
The validator rejects direct body writes -- including ones nested in
control flow -- while writes inside abilities, methods, and lambdas stay
legal because they only run after commit.
"""

import os;
import from tests.support { JAC_ROOT }
import from tests.support { diagnostics_text, kernel_check_file }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "passes", "fixtures");

test "render-phase state writes are rejected, deferred writes are legal" {
    result = kernel_check_file(os.path.join(FIXTURES, "render_phase_state_write.jac"));
    hits = [
        diag
        for diag in result.errors
        if diag.code == "E0082"
    ];
    assert len(hits) == 2 , (
        f"expected exactly the two direct body writes to E0082, got "
        f"{len(hits)}: {diagnostics_text(result)}"
    );
    lines = sorted([diag.span.line for diag in hits]);
    assert lines == [13, 15] , (
        f"E0082 must anchor the two body writes (lines 13 and 15), got {lines}"
    );
}
