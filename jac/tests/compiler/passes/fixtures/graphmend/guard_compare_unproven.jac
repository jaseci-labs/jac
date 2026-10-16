"""Soundness: a comparison guard that IS detected (`.sum()` is data-dependent)
but whose receiver has no tensor proof. Without one the negation would hand
torch._assert_async a Python bool, so the guard must DECLINE."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if mask.sum() != 4 {
        raise ValueError("mask must have four set entries");
    }
    return torch.sin(x) * 2.0;
}
