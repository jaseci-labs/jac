"""Fixture: a lowered importer calling a callee that demotes only at emit time.

`call_dyn` calls `from_code`, whose demotion in `xmod_demote_dyn_lib.jac`
no static check can predict; the caller must still demote in cascade with a
reason naming the callee. `call_double` stays natively lowered.
"""

import from xmod_demote_dyn_lib { from_code, double }

def call_dyn(x: str) -> int {
    return from_code(x) + 1;
}

def call_double(x: int) -> int {
    return double(x) + 1;
}

with entry {
    print(call_double(2));
}
