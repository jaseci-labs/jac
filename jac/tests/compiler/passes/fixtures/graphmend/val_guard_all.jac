"""Validation guard between tensor ops: a tensor-bool guard (.all()) whose
receiver is provably a tensor (the parameter annotation) lowers to a direct
graph-native torch._assert_async, keeping the forward pass a single contiguous
FX graph."""
import torch;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x) * 2.0;
}
