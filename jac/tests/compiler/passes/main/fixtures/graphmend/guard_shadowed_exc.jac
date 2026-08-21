"""Validation guard raising a shadowed builtin exception name: the source
binds `ValueError` to something else, so the boundary guard's builtins lookup
would reconstruct the wrong class. Must decline."""
import torch;

glob ValueError = RuntimeError;

@torch.compile()
def f(x: any, mask: torch.Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("bad mask");
    }
    return torch.sin(x) * 2.0;
}
