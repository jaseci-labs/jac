"""Decline: a backward() call in the module makes gradient tracking reachable,
and torch.where would route the untaken operand into the backward pass."""
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

def run_epoch(x: any, y: any) {
    loss = f(x, y).sum();
    loss.backward();
}
