"""Validation guard raising a multi-argument exception: the trap marker can
carry only one string literal, so lowering would truncate the exception's args.
The trap pass must decline instead."""
import torch;

@torch.compile()
def f(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError("mask must be all true", 42);
    }
    return torch.sin(x) * 2.0;
}
