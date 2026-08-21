"""Decline: a grad attribute read consumes what the backward pass produces."""
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

def grad_of(w: any) -> any {
    return w.grad;
}
