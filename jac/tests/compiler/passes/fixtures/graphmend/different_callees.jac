"""Conservatism: branches call DIFFERENT functions, so they cannot be reconciled
into a single torch.where -- GraphMend must leave this control flow intact."""
import torch;

@torch.compile()
def f(x: any, p: any, q: any) -> any {
    if (x.sum() > 0) {
        foo(p);
    } else {
        bar(q);
    }
    return x;
}
