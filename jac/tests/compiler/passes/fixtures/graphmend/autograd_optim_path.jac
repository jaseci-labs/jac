"""Decline: a torch.optim import means an optimizer, hence a training loop."""
import torch;
import torch.optim as topt;

@torch.compile()
def f(x: any, y: any) -> any {
    if (x.sum() > 0) {
        z = x + y;
    } else {
        z = x * y;
    }
    return z;
}

def make_opt(params: any) -> any {
    return topt.SGD(params);
}
