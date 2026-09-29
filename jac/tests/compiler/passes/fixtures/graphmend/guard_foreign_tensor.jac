"""Soundness: a bare `Tensor` annotation bound by a NON-torch import. The
spelling matches, but the binding proves the receiver is not a torch tensor,
so the guard must decline and keep its original semantics."""
import torch;
import from mylib { Tensor }

@torch.compile()
def f(x: any, mask: Tensor) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x) * 2.0;
}
