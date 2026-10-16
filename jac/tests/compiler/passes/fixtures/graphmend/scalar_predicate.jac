"""Soundness: a predicate that materializes a Python scalar.

`torch.where` takes a tensor condition; `.item()`, `torch.equal` and
`torch.allclose` produce a Python bool, and passing one raises TypeError. The
materializing call is itself the graph break, so predication could not remove
it in any case. All three shapes are detected and then declined: the direct
one, the one reached through a use-def chain, and the one behind a bare
alias."""
import torch;

@torch.compile()
def direct(x: any, m: any, n: any) -> any {
    if (x.item() > 5) {
        return m;
    } else {
        return n;
    }
}

@torch.compile()
def traced(x: any, m: any, n: any) -> any {
    hits = x.sum().item();
    if (hits > 5) {
        return m;
    } else {
        return n;
    }
}

@torch.compile()
def aliased(x: any, m: any, n: any) -> any {
    hits = x.item();
    same = hits;
    if (x.sum() > 0) and (same > 5) {
        return m;
    } else {
        return n;
    }
}
