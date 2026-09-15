"""flow for + else across memory profiles.

An else-bearing `flow for` must keep for-else semantics in every gc
mode: the else body runs when the loop exhausts, including the
zero-iteration case. Under `--memory rc` the parallel worker/join
outline engages, and it has no else machinery -- else-bearing loops
take the sequential fallback instead, and these probes fail if the
parallel path ever consumes them again. The bodies stay empty on
purpose: a local accumulator write is not a licensed reduction shape
under the rc sendability check (E1308), and the else flag alone is
what discriminates a dropped else suite."""
def flow_else_exhausts() -> bool {
    ran: bool = False;
    xs: list[int] = [1, 2, 3];
    flow for v in &xs {} else {
        ran = True;
    }
    return ran;
}

def flow_else_zero_iter() -> bool {
    ran: bool = False;
    xs: list[int] = [];
    flow for v in &xs {} else {
        ran = True;
    }
    return ran;
}
