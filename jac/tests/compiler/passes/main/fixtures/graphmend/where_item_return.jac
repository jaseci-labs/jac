"""Generality: dynamic signal via .item() (not sum/max) in a return-shaped
data-dependent branch."""
import torch;

@torch.compile()
def f(x: any, m: any, n: any) -> any {
    if (x.item() > 5) {
        return m;
    } else {
        return n;
    }
}
