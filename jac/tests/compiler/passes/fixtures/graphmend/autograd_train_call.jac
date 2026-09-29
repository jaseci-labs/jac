"""Decline: a train() call puts the module into training mode."""
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

def fit(net: any) {
    net.train();
}
