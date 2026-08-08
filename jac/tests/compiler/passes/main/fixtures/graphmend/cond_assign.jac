"""Asymmetric data-dependent branches whose values call different functions.

`torch.where` would run BOTH calls; GraphMend emits `torch.cond` so only the
selected branch executes (paper's torch.cond path for asymmetric branches)."""
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
