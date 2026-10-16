"""Data-dependent control flow: both branches assign same var -> torch.where."""
import torch;

@torch.compile()
def f(x: any, y: any) -> any {
    if (x.sum() > 10) {
        z = x + y;
    } else {
        z = x * y;
    }
    return z;
}
