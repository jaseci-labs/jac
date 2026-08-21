"""Soundness: a scalar predicate one rung past the use-def trace bound.

Detection and the scalar query share the bound but not a safe answer when it
runs out. The direct `.sum()` licenses detection by itself, so only the
scalar query giving up safely keeps `a11`, a Python bool, out of
`torch.where`."""
import torch;

@torch.compile()
def f(x: any, m: any, n: any) -> any {
    a0 = x.item();
    a1 = a0 + 1;
    a2 = a1 + 1;
    a3 = a2 + 1;
    a4 = a3 + 1;
    a5 = a4 + 1;
    a6 = a5 + 1;
    a7 = a6 + 1;
    a8 = a7 + 1;
    a9 = a8 + 1;
    a10 = a9 + 1;
    a11 = a10 + 1;
    if (x.sum() > 0) and (a11 > 5) {
        return m;
    } else {
        return n;
    }
}
