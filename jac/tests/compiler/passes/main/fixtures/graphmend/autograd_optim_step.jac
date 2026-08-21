"""Decline: a step() on an optimizer-spelled receiver is a training step."""
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

def advance(optimizer: any) {
    optimizer.step();
}
