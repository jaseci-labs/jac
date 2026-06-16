"""Data-dependent control flow: both branches return -> torch.where."""
import torch;

@torch.compile()
def with_breaks(a: any, b: any) -> any {
    x = a / (torch.abs(a) + 1);
    b = x * 1.414;
    if (b.sum() < 0) {
        return x * (b * -1);
    } else {
        return x * (b * -2);
    }
}
