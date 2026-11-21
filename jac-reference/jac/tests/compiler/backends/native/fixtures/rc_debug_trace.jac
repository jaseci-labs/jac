"""RC debug trace fixture for the JAC_RC_DEBUG_CODEGEN compile-time gate.

Turns the runtime trace switch on, churns through short-lived string and
list allocations (each loop iteration mallocs fresh buffers and frees the
previous iteration's temporaries), turns the switch back off, and prints a
deterministic total. Compiled with JAC_RC_DEBUG_CODEGEN=1 the run emits
RC MALLOC / RC FREE lines on stdout; compiled without it the same source
must produce only the final total.
"""

def churn(n: int) -> int {
    total = 0;
    i = 0;
    while i < n {
        s: str = "item-" + str(i);
        picks: list[int] = [i, i + 1, i + 2];
        total = total + len(s) + len(picks);
        i = i + 1;
    }
    return total;
}

with entry {
    __rc_debug_enable();
    result: int = churn(50);
    __rc_debug_disable();
    print(result);
}
