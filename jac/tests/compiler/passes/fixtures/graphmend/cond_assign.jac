"""Asymmetric data-dependent branches whose values contain calls.

`torch.where` would run BOTH calls, and `torch.cond` requires branch callees
proven pure and capturable, which the analysis does not yet validate; the
conditional must stay intact."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    if (x.sum() > 0) {
        z = torch.relu(x) + y;
    } else {
        z = torch.sigmoid(y) - x;
    }
    return z;
}
