"""Regression coverage for issue #7471.

When the vendored typeshed stdlib stubs are absent (e.g. a source checkout that
has not yet run `zig build` / `fetch-typeshed`), type inference cannot run, so
`get_inference_sched` returns `[]`. The type-check schedule, however, still
listed `OwnershipCheckPass`, which declares `REQUIRES = ('cfg', 'inference')`.
The pass scheduler then hard-aborted with a misleading, fatal

    RuntimeError: scheduling error: pass OwnershipCheckPass requires analysis
    'inference' which has not run for module ...

instead of degrading gracefully.

The fix drops any pass whose declared REQUIRES cannot be satisfied by the
analyses that have (or will) run for the module, iterating to a fixed point so
a dropped provider also drops its dependents. These tests pin both halves of
that behavior by simulating the missing-stubs precondition (so they are
independent of whether the host environment has actually fetched the stubs).
"""

import unittest.mock;
import jaclang.jac0core.compiler as _comp;
import from jaclang.jac0core.program { JacProgram }


glob _SRC: str = "with entry { x = 1; }\n";


def _stubs_unavailable -> bool {
    return False;
}


test "type-check degrades gracefully when typeshed stubs are absent (#7471)" {
    # Simulate the bug precondition: the vendored typeshed stdlib stubs are
    # missing, so inference is skipped. The type-check schedule must drop
    # OwnershipCheckPass (REQUIRES 'inference') rather than raising a fatal,
    # misleading "scheduling error". Patching the module global is seen by
    # get_inference_sched's same-module lookup of typeshed_stubs_available().
    with unittest.mock.patch.object(
        _comp, "typeshed_stubs_available", _stubs_unavailable
    ) {
        prog = JacProgram();
        mod = prog.compile(
            file_path="issue7471_absent.jac", use_str=_SRC, type_check=True
        );
        # The defining assertion: compiling must not raise.
        analyses = prog._analyses_run.get(id(mod), set());
        assert 'inference' not in analyses , analyses;
        assert 'ownership' not in analyses , analyses;
        sched_msgs = [
            str(e)
            for e in prog.errors_had
            if 'scheduling error' in str(e)
        ];
        assert sched_msgs == [] , sched_msgs;
    }
}


test "ownership check still runs when typeshed stubs are present (#7471)" {
    # Guard against the fix over-dropping: when inference IS available, the
    # ownership pass must remain in the schedule. This is only meaningful where
    # the vendored stubs are actually fetched (e.g. CI); it no-ops otherwise so
    # it can never fail purely due to an unfetched checkout.
    if not _comp.typeshed_stubs_available() {
        return;
    }
    prog = JacProgram();
    mod = prog.compile(
        file_path="issue7471_present.jac", use_str=_SRC, type_check=True
    );
    analyses = prog._analyses_run.get(id(mod), set());
    assert 'inference' in analyses , analyses;
    assert 'ownership' in analyses , analyses;
}
