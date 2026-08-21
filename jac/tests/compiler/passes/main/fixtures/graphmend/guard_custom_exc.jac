"""Validation guards raising non-builtin exception types: the boundary guard
restores by builtin name, so an aliased or qualified type would degrade to
RuntimeError. Both shapes must decline instead."""
import torch;

glob MaskError = RuntimeError;

@torch.compile()
def f_alias(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise MaskError("bad mask");
    }
    return torch.sin(x) * 2.0;
}

@torch.compile()
def f_qualified(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise torch.MaskError("bad mask");
    }
    return torch.sin(x) * 2.0;
}
