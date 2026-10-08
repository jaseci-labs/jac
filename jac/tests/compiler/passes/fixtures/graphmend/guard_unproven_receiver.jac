"""Soundness: a `.all()` guard whose receiver has no tensor proof. The match
on `.all`/`.any`/`.allclose` is structural; nothing shows `mask` is a tensor,
and a duck-typed receiver returning a Python bool would turn a graph-native
assert into a type error. Without a proof the guard must DECLINE and keep its
original semantics."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return torch.sin(x) * 2.0;
}
