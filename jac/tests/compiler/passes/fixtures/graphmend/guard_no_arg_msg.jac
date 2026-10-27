"""Validation guards raising argument-less exceptions: reconstruction from a
marker would produce exc('') with args ('',) where the original had args (),
so the trap pass must decline both the bare-name and the empty-call shape."""
import torch;

@torch.compile()
def f_bare(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError;
    }
    return torch.sin(x) * 2.0;
}

@torch.compile()
def f_empty(x: any, mask: any) -> any {
    x = torch.relu(x);
    if not mask.all() {
        raise ValueError();
    }
    return torch.sin(x) * 2.0;
}
