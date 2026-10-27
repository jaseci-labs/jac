"""Validation guard chaining a cause (`raise ... from`): the boundary guard
re-raises without the chain, so the cause cannot be reconstructed and the trap
pass must decline."""
import torch;

glob upstream = RuntimeError("upstream failure");

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true") from upstream;
    }
    return torch.sin(x) * 2.0;
}
