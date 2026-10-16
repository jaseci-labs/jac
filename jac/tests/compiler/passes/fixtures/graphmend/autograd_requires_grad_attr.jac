"""Decline: requires_grad_(True) flips gradient tracking on in the module."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    if (x.sum() > 0) {
        z = x + y;
    } else {
        z = x * y;
    }
    return z;
}

def prep(t: any) -> any {
    t.requires_grad_(True);
    return t;
}
