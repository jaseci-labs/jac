"""Decline: a requires_grad keyword in the module marks tensors for tracking."""
import torch;

glob W = torch.ones(4, requires_grad=True);

@torch.compile()
def f(x: any) -> any {
    if (x.sum() > 0) {
        z = x + W;
    } else {
        z = x - W;
    }
    return z;
}
