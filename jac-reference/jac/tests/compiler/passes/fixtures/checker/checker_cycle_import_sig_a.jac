"""Bug #CYCLE-IMPORT-1 fixture, module A: imports B while B imports A back.

B uses A's `AThing` in a function signature, so type-checking this module
walks into B and B's signatures walk right back into A while A is still
being resolved. The whole pair must check clean.
"""

import from checker_cycle_import_sig_b { BThing, make_b }

obj AThing {
    has label: str = "a";
    has partner: BThing | None = None;
}

def describe_a() -> str {
    bt = make_b();
    return bt.tag;
}

with entry {
    print(describe_a());
}
