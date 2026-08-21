"""Decline: a training-flag read means behavior forks on train mode."""
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

def mode_of(net: any) -> any {
    return net.training;
}
