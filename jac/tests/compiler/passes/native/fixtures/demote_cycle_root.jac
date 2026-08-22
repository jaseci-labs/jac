"""A native root whose closure contains a demotion/emission ordering cycle.

Import order matters and is the point: the walk reaches the callee module
first, the callee's own walk compiles the caller while the callee is
inflight, and the caller's emission runs ahead of the callee's demotion
verdict. The linked unit must still resolve every symbol it declares.
"""

import from .demote_cycle_helpers { cycle_ok }
import from .demote_cycle_caller { CycleReporter }

def probe_cycle(n: int) -> int {
    r = CycleReporter();
    r.bump();
    return cycle_ok(n) + r.count;
}
