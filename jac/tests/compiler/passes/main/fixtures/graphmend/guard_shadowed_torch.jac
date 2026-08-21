"""Validation guard whose receiver is provable, in a function that shadows the
`torch` name: the lowered assert would bind `torch._assert_async` to the local
parameter rather than the module, so the trap pass must decline."""
import torch;
import from torch { Tensor }

@torch.compile()
def f(x: any, mask: Tensor, torch: any) -> any {
    if not mask.all() {
        raise ValueError("mask must be all true");
    }
    return x * 2.0;
}
