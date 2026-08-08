"""Validation guard between tensor ops: a tensor-bool guard (.all()) lowers to
torch._assert_async, keeping the forward pass a single contiguous FX graph."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x) * 2.0;
}
